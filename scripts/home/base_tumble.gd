class_name BaseTumble
extends RefCounted
## Tumble (briefs/design/GARDEN_MODERN.md 4.2 game 1), a duel in a ring beside the Stump Shove's stump; only with
## farm_build.json base_mode on. Your partner meets your next rested Boki, or a garden visitor when it is alone.
## Each exchange the rival shows a tell ("probably Rush"), your Boki shows what it wants, and you pick Rush (Power),
## Brace (Guard) or Dodge (Speed) with 1, 2, 3 or a click; Rush beats Dodge beats Brace beats Rush. Then one press
## on the drill bar as they meet. The winner pushes the loser back a step, two on a big lead; out of the ring, or
## further back after five, loses. Focus makes the tells you see more honest; following your Boki pushes harder.
## Tuning: content/rules/base_tumble.json. Run is the bout itself (no nodes), so --tumble-check runs it headless.

static func rules() -> Dictionary:
	return Content.rules("base_tumble")

static func stat(rec: Dictionary, s: String) -> float:
	return float(rec.get("stats", {}).get(s, 0))

## The move that beats m.
static func counter(m: String) -> String:
	var moves: Dictionary = rules()["moves"]
	for k in moves:
		if moves[k]["beats"] == m:
			return k
	return m

## The bout: an explicit state machine, intro, then tell -> pick -> resolve -> push and the next tell or the result.
## Side 0 is yours (you pick and press), side 1 the rival (its nature picks). pos runs from -depth (you are out)
## to depth (the rival is out).
class Run:
	var R: Dictionary
	var recs: Array                 # [yours, the rival]
	var rng: RandomNumberGenerator
	var visitor := false            # the rival is a garden visitor, not one of yours
	var state := "intro"            # intro, tell, pick, resolve, push, result, done
	var left := 0.0                 # s left in this state
	var t := 0.0                    # s since the bout began
	var pos := 0.0                  # steps: above 0 the rival is pushed back
	var played := 0                 # exchanges resolved
	var wins: Array = [0, 0]        # exchanges won by each side
	var follows := 0                # exchanges you went with what your Boki wanted
	var want := ""                  # what your Boki wants this exchange
	var plan := ""                  # what the rival will do
	var tell := ""                  # what the rival's tell shows you
	var pick := ""                  # your move ("" until picked)
	var grade := ""                 # your press ("" until pressed)
	var last: Dictionary = {}       # the last exchange: moves, winner (-1 on a dead clash), steps

	func _init(pair: Array, r: RandomNumberGenerator) -> void:
		R = BaseTumble.rules()
		recs = pair
		rng = r
		left = float(R["intro_s"])

	## Chance the tell side i sees is honest: higher Focus reads truer.
	func honest(i: int) -> float:
		var h: Array = R["honest"]
		return float(h[0]) if BaseTumble.stat(recs[i], "focus") > BaseTumble.stat(recs[1 - i], "focus") else float(h[1])

	## A move this Boki wants, weighed by its traits.
	func nature(i: int) -> String:
		var moves: Dictionary = R["moves"]
		var traits: Dictionary = recs[i].get("traits", {})
		var w := {}
		var total := 0.0
		for m in moves:
			var tr := String(moves[m]["trait"])
			var lean := float(R["lean_floor"]) + float(traits.get(tr, 0.5)) - float(R["lean_centre"][tr])
			w[m] = maxf(float(R["lean_min"]), lean)
			total += w[m]
		var roll := rng.randf() * total
		for m in moves:
			roll -= w[m]
			if roll <= 0.0:
				return m
		return moves.keys()[-1]

	## What side `viewer` sees of a planned move: the move itself, or by its honesty one of the other two.
	func shown(move: String, viewer: int) -> String:
		if rng.randf() < honest(viewer):
			return move
		var others: Array = R["moves"].keys().filter(func(m): return m != move)
		return others[rng.randi() % others.size()]

	func _tell() -> void:
		want = nature(0)
		plan = BaseTumble.counter(shown(want, 1)) if rng.randf() < float(R["rival_read"]) else nature(1)
		tell = shown(plan, 0)
		pick = ""
		grade = ""
		_to("tell", float(R["tell_s"]))

	func _to(s: String, secs: float) -> void:
		state = s
		left = secs

	## Your move, from the tell on; picking after the tell starts the charge at once.
	func choose(move: String) -> void:
		if pick != "" or not (state == "tell" or state == "pick"):
			return
		pick = move
		if state == "pick":
			_to("resolve", float(R["impact_s"]))

	## Your press during the charge; the hit lands when the charge ends.
	func press(g: String) -> void:
		if state == "resolve" and grade == "":
			grade = g

	func over() -> bool:
		return state == "done"

	func out() -> bool:
		return absf(pos) >= float(R["depth"])

	## 0 or 1: who is further forward, then who won more exchanges (the rival on a full tie).
	func winner() -> int:
		if pos != 0.0:
			return 0 if pos > 0.0 else 1
		return 0 if wins[0] > wins[1] else 1

	func step(dt: float) -> void:
		if state == "done":
			return
		t += dt
		left -= dt
		if left > 0.0:
			return
		match state:
			"intro": _tell()
			"tell":
				if pick != "":
					_to("resolve", float(R["impact_s"]))
				else:
					_to("pick", float(R["pick_s"]))
			"pick": choose(want)
			"resolve": _resolve()
			"push":
				var n := int(R["exchanges"])
				if out() or (played >= n and (pos != 0.0 or played >= n + int(R["extra_max"]))):
					_to("result", float(R["result_s"]))
				else:
					_tell()
			"result": state = "done"

	## Side i's push for a stat this exchange: base plus the stat, times the type edge, the press and following.
	func push(i: int, s: String, press_grade: String) -> float:
		var p := (float(R["base"]) + BaseTumble.stat(recs[i], s)) * float(R["press"][press_grade])
		if BaseShove.has_edge(recs[i], recs[1 - i]):
			p *= float(R["edge"])
		if i == 0 and pick == want:
			p *= float(R["follow"])
		return p

	func _rival_grade() -> String:
		var roll := rng.randf()
		var rp: Dictionary = R["rival_press"]
		if roll < float(rp["great"]):
			return "great"
		return "good" if roll < float(rp["great"]) + float(rp["good"]) else "miss"

	func _resolve() -> void:
		var moves: Dictionary = R["moves"]
		if grade == "":
			grade = "miss"
		var grades := [grade, _rival_grade()]
		var w := -1
		var steps := 0.0
		if pick == plan:
			var s := String(moves[pick]["stat"])
			var p0 := push(0, s, grades[0])
			var p1 := push(1, s, grades[1])
			if p0 != p1:
				w = 0 if p0 > p1 else 1
				steps = float(R["clash_step"])
		else:
			w = 0 if moves[pick]["beats"] == plan else 1
			var s := String(moves[[pick, plan][w]]["stat"])
			var lead := push(w, s, grades[w]) - push(1 - w, s, grades[1 - w])
			steps = 2.0 if lead >= float(R["lead"]) else 1.0
		if w >= 0:
			wins[w] += 1
			pos = clampf(pos + (steps if w == 0 else -steps), -float(R["depth"]), float(R["depth"]))
		if pick == want:
			follows += 1
		played += 1
		last = {"moves": [pick, plan], "winner": w, "steps": steps, "grades": grades}
		_to("push", float(R["push_s"]))

## Pays out a finished bout: joy, trust (with what following earned), a memory, energy and gems. A visitor is
## not yours, so only your Boki change. Returns what the card shows.
static func settle(run: Run) -> Dictionary:
	var R := rules()
	var wi := run.winner()
	var win: Dictionary = run.recs[wi]
	var lose: Dictionary = run.recs[1 - wi]
	var own: Array = [run.recs[0]] if run.visitor else run.recs
	var bonus := float(run.follows) * float(R["follow_trust"])
	for rec in own:
		Care.change(rec, "energy", -float(R["energy"]))
		var won: bool = rec == win
		Care.change(rec, "joy", float(R["win_joy"] if won else R["lose_joy"]))
		var text := "tumbled %s out of the ring" % lose["name"] if won else "lost a Tumble to %s" % win["name"]
		var trust := float(R["win_trust"]) if won else 0.0
		Save.remember(rec, "tumble", text, trust + (bonus if rec == run.recs[0] else 0.0))
	var gems := int(R["gems_win"]) if wi == 0 else int(R["gems_ran"])
	Save.d["gems"] = int(Save.d["gems"]) + gems
	return {"win": win, "lose": lose, "gems": gems, "backed_won": wi == 0}

# ------------------------------------------------------------------ on the base
var h                          # the Home screen
var ring: MeshInstance3D = null
var run: Run = null
var pair: Array = []           # [your kin entry, the rival's] (a visitor's entry is ours to free)
var seen := ""                 # the run state the screen last showed
var shown_pos := 0.0           # steps: the push as drawn, catching up with run.pos
var bar: TimingBar = null
var panel: Control = null
var tell_lbl: Label = null
var want_lbl: Label = null
var score_lbl: Label = null
var buttons: Array = []
var card: Control = null
var card_t := 0.0

func _init(home) -> void:
	h = home

## The ring beside the Stump Shove's stump (none without one); called when fixtures move.
func place() -> void:
	if is_instance_valid(ring):
		ring.queue_free()
	ring = null
	if h.hshove == null or not is_instance_valid(h.hshove.stump):
		return
	var R := rules()
	var off: Array = R["ring_off"]
	var r := float(R["depth"]) * float(R["step_m"]) + float(R["gap_m"])
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.04
	tm.outer_radius = r + 0.04
	ring = MeshInstance3D.new()
	ring.name = "TumbleRing"
	ring.mesh = tm
	ring.scale.y = 0.3
	ring.material_override = BaseRace.mat(Color("d9b98a"))
	ring.position = h.hshove.stump.position + Vector3(float(off[0]), float(off[1]), float(off[2]))
	var g: float = h._ground_h(ring.position.x, ring.position.z)
	ring.position.y = (g if g > -50.0 else 0.0) + 0.02
	h.add_child(ring)

func find(p2: Vector2) -> Dictionary:
	if run != null or not is_instance_valid(ring):
		return {}
	if p2.distance_to(Vector2(ring.position.x, ring.position.z)) > float(rules()["reach_m"]):
		return {}
	return {"kind": "tumble"}

func label() -> String:
	return "Start a Tumble (%s)" % Save.active_kin().get("name", "your partner")

func use() -> void:
	var ks: Array = h.hrace.entrants()
	if ks.is_empty():
		h._toast("Tumble needs a rested Boki out on the base")
		return
	pair = [ks[0], ks[1] if ks.size() >= 2 else _visitor(ks[0]["rec"])]
	for k in pair:
		k["busy"] = true
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	run = Run.new([pair[0]["rec"], pair[1]["rec"]], rng)
	run.visitor = ks.size() < 2
	seen = ""
	shown_pos = 0.0
	_open_panel()
	_place_pair(0.0)
	GardenSfx.countdown(h, ring.position)

## A garden visitor of a random species, its stats near yours; a temporary entry, never saved.
func _visitor(mine: Dictionary) -> Dictionary:
	var kinds: Array = Data.common_kin()
	var rec := Save.new_kin(kinds[randi() % kinds.size()])
	rec["level"] = int(mine.get("level", 1))
	var spread := int(rules()["visitor_spread"])
	for s in rec["stats"]:
		rec["stats"][s] = clampi(int(stat(mine, s)) + randi_range(-spread, spread), 0, 100)
	var n := Models.kin(rec["species"], rec)
	h.add_child(n)
	return {"rec": rec, "node": n, "pos": ring.position, "visitor": true}

## A key or press: true when the bout took it.
func input(event: InputEvent) -> bool:
	if run == null:
		return false
	if event.is_action_pressed("menu"):
		_end(false)
		return true
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode >= KEY_1 and key.physical_keycode <= KEY_3:
		_choose(int(key.physical_keycode - KEY_1))
		return true
	if not TimingBar.is_press(event) or run.state != "resolve" or bar == null:
		return false
	if run.grade != "":
		return true
	var r := bar.press()
	run.press(r)
	GardenSfx.crowd(r, ring.position)
	h._emote(pair[0], {"great": "★", "good": "♪", "miss": "?"}[r], true)
	return true

func _choose(i: int) -> void:
	run.choose(rules()["moves"].keys()[i])
	_sync_panel()

func tick(d: float) -> void:
	if card_t > 0.0:
		card_t -= d
		if card_t <= 0.0 and is_instance_valid(card):
			card.queue_free()
	if run == null:
		return
	run.step(d)
	if run.state != seen:
		_enter(run.state)
	if run.state == "resolve" and bar != null and run.grade == "":
		bar.step(d)
	_place_pair(d)
	if run.over():
		_end(true)

## What the screen does on entering a state.
func _enter(s: String) -> void:
	seen = s
	var moves: Dictionary = rules()["moves"]
	match s:
		"intro":
			_sync_panel()
		"tell":
			_clips("", run.tell)
			_sync_panel()
		"pick":
			_clips("", "")
		"resolve":
			bar = TimingBar.new()
			bar.open(h.root_ui, "Press %s with the marker in the gold for a clean hit" % Settings.key_cap("interact"))
			bar.lbl.text = "%s goes for a %s!" % [run.recs[0]["name"], moves[run.pick]["name"]]
			_clips(run.pick, run.plan)
			_sync_panel()
		"push":
			_close_bar()
			var w := int(run.last["winner"])
			GardenSfx.clash(h, run.last["moves"][maxi(w, 0)], ring.position, w >= 0)
			if w >= 0 and not pair[w].has("visitor"):
				h._emote(pair[w], "♪", true)
			_sync_panel()
		"result":
			_clips("", "")
			if run.out():
				GardenSfx.cue("tumble_ringout", pair[1 - run.winner()]["pos"])

## Rig clips for the two moves ("" for none): Rush lunges, Dodge hops, Brace holds the guard pose.
func _clips(mine: String, theirs: String) -> void:
	var moves: Dictionary = rules()["moves"]
	for i in 2:
		var m: String = [mine, theirs][i]
		var n: Node3D = pair[i]["node"]
		if m == "":
			n.remove_meta("kact")
			n.remove_meta("pose")
			continue
		n.set_meta("kact", String(moves[m]["clip"]))
		n.set_meta("pose", "guard" if m == "brace" else "")

## The pair face off along the ring's line; the contact point slides with the push.
func _place_pair(d: float) -> void:
	var R := rules()
	shown_pos = lerpf(shown_pos, run.pos, minf(1.0, d * float(R["slide_rate"])))
	var gap := float(R["gap_m"]) - (float(R["charge_m"]) if run.state == "resolve" else 0.0)
	var mid := ring.position + Vector3(shown_pos * float(R["step_m"]), 0, 0)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var p := mid + Vector3(side * gap, 0, 0)
		var g: float = h._ground_h(p.x, p.z)
		p.y = g if g > -50.0 else 0.0
		var n: Node3D = pair[i]["node"]
		n.position = p
		n.rotation.y = atan2(side, 0.0)
		pair[i]["pos"] = p

func _open_panel() -> void:
	panel = UI.card(Color(0.06, 0.07, 0.1, 0.92), 12, 14)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = -170
	panel.offset_bottom = -170
	var col := UI.vbox(6)
	panel.add_child(col)
	tell_lbl = UI.label("", 16, UI.ACCENT_HI)
	want_lbl = UI.label("", 14, UI.INK)
	score_lbl = UI.label("", 12, UI.MUTED)
	var row := UI.hbox(8)
	buttons.clear()
	var moves: Dictionary = rules()["moves"]
	for i in moves.size():
		var m: String = moves.keys()[i]
		var b := UI.button("%d %s (%s %d)" % [i + 1, moves[m]["name"], String(moves[m]["stat"]).capitalize(),
				int(stat(run.recs[0], String(moves[m]["stat"])))], _choose.bind(i))
		buttons.append(b)
		row.add_child(b)
	for c in [tell_lbl, want_lbl, row, score_lbl]:
		col.add_child(c)
	h.root_ui.add_child(panel)

func _sync_panel() -> void:
	var moves: Dictionary = rules()["moves"]
	var picking := run.pick == "" and (run.state == "tell" or run.state == "pick")
	for i in buttons.size():
		var btn: Button = buttons[i]
		btn.disabled = not picking
		btn.modulate = Color(1, 1, 1) if picking or moves.keys()[i] == run.pick else Color(1, 1, 1, 0.45)
	var mine: String = run.recs[0]["name"]
	var theirs: String = run.recs[1]["name"]
	if run.want == "":
		tell_lbl.text = "%s and %s square up..." % [mine, theirs]
		return
	tell_lbl.text = "%s: probably %s" % [theirs, moves[run.tell]["name"]]
	want_lbl.text = "%s wants to %s" % [mine, moves[run.want]["name"]]
	var ahead := mine if run.pos > 0.0 else theirs
	var lead := "level" if run.pos == 0.0 else "%s %.1f steps up" % [ahead, absf(run.pos)]
	var n := int(rules()["exchanges"])
	score_lbl.text = "Exchange %d of %d, %s" % [mini(run.played + 1, n), n, lead]

func _close_bar() -> void:
	if bar != null:
		bar.close()
	bar = null

func _end(finished: bool) -> void:
	var res := settle(run) if finished else {}
	_clips("", "")
	_close_bar()
	if is_instance_valid(panel):
		panel.queue_free()
	for k in pair:
		k["busy"] = false
		k["t"] = 1.5
	if finished:
		_card(res)
		var wi := run.winner()
		GardenSfx.fanfare(h, pair[wi], pair[1 - wi])
		for i in 2:
			if not pair[i].has("visitor"):
				h._emote(pair[i], "♥" if i == wi else "…", true)
		Save.save_game()
	if pair[1].has("visitor"):
		pair[1]["node"].queue_free()
	run = null
	pair = []

func _card(res: Dictionary) -> void:
	var win: Dictionary = res["win"]
	var lose: Dictionary = res["lose"]
	if is_instance_valid(card):
		card.queue_free()
	var how := "out of the ring" if run.out() else "back after %d exchanges" % run.played
	card = BaseRace.result_card(h, [
		["%s wins the Tumble!" % win["name"], 18, UI.ACCENT_HI],
		["%s is pushed %s" % [lose["name"], how], 14, UI.INK],
		["%s went with what it wanted %d of %d times (+trust)" % [run.recs[0]["name"], run.follows, run.played],
				14, UI.MUTED],
		["+%d gems" % res["gems"], 14, UI.GOLD]])
	card_t = float(rules()["card_s"])
