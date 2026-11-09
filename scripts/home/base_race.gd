class_name BaseRace
extends RefCounted
## The Dash (briefs/design/GARDEN.md 5.1 and 9.4), the Boki base's first minigame; only with
## farm_build.json base_mode on. A race post stands by the Training post with a 6 x 3 m loop beside
## it: a straight, a water stretch, a climb and a jump. Press interact at the post and 2 to 4 rested
## Boki out on the base run one lap; you back your partner and cheer at three marks with the
## Training post's timing bar (TimingBar). Pace comes from trained Speed, joy, and a lean on its own
## stretch (the Tide knack swims, wings glide the gap); friends run side by side, rivals bump.
## The result card: the winner gains joy and trust, the last one home sulks, you get a few gems,
## both remember it, and the two grow apart while close finishers grow closer (rec["bonds"]).
## Tuning: content/rules/base_race.json. Run is the race itself (no nodes), so --race-check
## (tools/race_check.gd) runs it headless.
##
## On the save: rec["bonds"] = {uid: -1..1} (missing = 0, so old saves need no migration).

const POST_OFF := Vector3(2.2, 0, 0.4)      # m from the Training post to the race post
const LOOP_OFF := Vector3(0.9, 0, -0.6)     # m from the race post to the loop's start line
const LOOP_W := 6.0                          # m, the loop's long side (the straight and the climb)
const CLIMB_H := 0.7                         # m, the top of the climb
const JUMP_H := 0.6                          # m, the top of the jump's arc
const SWIM_DIP := 0.15                       # m the runners sink in the water stretch
const TRACK_W := 1.4                         # m, the track's width (four lanes)
const REACH := 1.6                           # m from the post to start a race
const STRETCH_COL := {
	"straight": Color("c9b48a"), "water": Color("4ab0ff"), "climb": Color("8a6a4a"), "jump": Color("f2c84a"),
}

static func rules() -> Dictionary:
	return Content.rules("base_race")

static func lap() -> float:
	var out := 0.0
	for s in rules()["stretches"]:
		out += float(s["len"])
	return out

static func bond(a: Dictionary, b: Dictionary) -> float:
	return float(a.get("bonds", {}).get(String(b["uid"]), 0.0))

## Both ways: bonds are mutual.
static func nudge_bond(a: Dictionary, b: Dictionary, amt: float) -> void:
	for pair in [[a, b], [b, a]]:
		var me: Dictionary = pair[0]
		if not me.has("bonds"):
			me["bonds"] = {}
		var uid := String(pair[1]["uid"])
		me["bonds"][uid] = clampf(float(me["bonds"].get(uid, 0.0)) + amt, -1.0, 1.0)

static func winged(rec: Dictionary) -> bool:
	return Data.KIN.get(String(rec.get("species", "")), {}).has("wing")

## Its pace on stretch i before the wobble and your cheers (m/s).
static func stretch_pace(rec: Dictionary, i: int) -> float:
	var R := rules()
	var s: Dictionary = R["stretches"][i]
	var speed := float(rec.get("stats", {}).get("speed", 0))
	var mood: Array = R["mood"]
	var p := float(R["pace"]) * float(s["mult"]) * (1.0 + speed * float(R["speed_per_point"]))
	p *= lerpf(float(mood[0]), float(mood[1]), Care.need(rec, "joy") / 100.0)
	var lean: Dictionary = rec.get("lean", {})
	match String(s["kind"]):
		"water":
			var tide := maxf(Work.level(rec, "tide"), 4.0 * float(lean.get("water", 0.0)))
			p *= 1.0 + float(R["swim_per_tide"]) * tide
		"jump":
			var g := 1.0 if winged(rec) else clampf(float(lean.get("flying", 0.0)), 0.0, 1.0)
			p *= lerpf(1.0, float(R["glide"]), g)
	return p

## Seconds for one lap with no wobble and no cheers: the lowest is the favourite.
static func expected_time(rec: Dictionary) -> float:
	var out := 0.0
	var st: Array = rules()["stretches"]
	for i in st.size():
		out += float(st[i]["len"]) / stretch_pace(rec, i)
	return out

## The race itself: runners' distance along the lap, stepped in time.
class Run:
	var R: Dictionary
	var recs: Array
	var backed := 0                 # index in recs: the Boki you cheer for
	var rng: RandomNumberGenerator
	var t := 0.0
	var dist: Array = []            # m along the lap
	var stretch: Array = []         # which stretch each one is on
	var pace: Array = []            # m/s rolled for its stretch
	var bump_t: Array = []          # s of bump left
	var done_t: Array = []          # finish time, -1 while running
	var ends: Array = []            # m along the lap where each stretch ends
	var cheered := 0                # marks cheered for (or missed), 0..3
	var cheer_mult := 1.0           # your last cheer, for the backed Boki's next stretch
	var bumped := {}                # "i-j-stretch": rivals already bumped there

	func _init(runners: Array, back: int, r: RandomNumberGenerator) -> void:
		R = BaseRace.rules()
		recs = runners
		backed = back
		rng = r
		var at := 0.0
		for s in R["stretches"]:
			at += float(s["len"])
			ends.append(at)
		for i in recs.size():
			dist.append(0.0)
			stretch.append(0)
			pace.append(0.0)
			bump_t.append(0.0)
			done_t.append(-1.0)
			_roll(i)

	func _roll(i: int) -> void:
		var w := float(R["wobble"])
		var p := BaseRace.stretch_pace(recs[i], int(stretch[i])) * rng.randf_range(1.0 - w, 1.0 + w)
		if i == backed and int(stretch[i]) > 0:
			p *= cheer_mult
			cheer_mult = 1.0
			cheered = maxi(cheered, int(stretch[i]))      # a mark passed with no press is a miss
		pace[i] = p

	## One press a mark, while your Boki runs the stretch before it.
	func can_cheer() -> bool:
		return float(done_t[backed]) < 0.0 and cheered == int(stretch[backed]) and cheered < ends.size() - 1

	func cheer(grade: String) -> void:
		cheer_mult = float(R["cheer"][grade])
		cheered += 1

	func over() -> bool:
		return not done_t.has(-1.0)

	## Indices, first home first.
	func order() -> Array:
		var out: Array = range(recs.size())
		out.sort_custom(func(a, b): return float(done_t[a]) < float(done_t[b]))
		return out

	func friends(i: int, j: int) -> bool:
		return BaseRace.bond(recs[i], recs[j]) >= float(R["friend_at"])

	func rivals(i: int, j: int) -> bool:
		return BaseRace.bond(recs[i], recs[j]) <= float(R["rival_at"])

	func step(dt: float) -> void:
		t += dt
		var eff: Array = []
		for i in recs.size():
			eff.append(float(pace[i]) * (float(R["bump_slow"]) if float(bump_t[i]) > 0.0 else 1.0))
			bump_t[i] = maxf(0.0, float(bump_t[i]) - dt)
		var pulled := eff.duplicate()
		for i in recs.size():
			for j in recs.size():
				if i != j and _running(i) and _running(j) and friends(i, j) and _gap(i, j) < float(R["friend_near"]):
					pulled[i] = lerpf(float(pulled[i]), float(eff[j]), float(R["friend_pull"]))
		for i in recs.size():
			if _running(i):
				_advance(i, float(pulled[i]), dt)
		_bumps()

	func _running(i: int) -> bool:
		return float(done_t[i]) < 0.0

	func _gap(i: int, j: int) -> float:
		return absf(float(dist[i]) - float(dist[j]))

	func _advance(i: int, p: float, dt: float) -> void:
		dist[i] = float(dist[i]) + p * dt
		while _running(i) and float(dist[i]) >= float(ends[stretch[i]]):
			if int(stretch[i]) == ends.size() - 1:
				done_t[i] = t - (float(dist[i]) - float(ends[-1])) / maxf(p, 0.01)
				dist[i] = float(ends[-1])
			else:
				stretch[i] = int(stretch[i]) + 1
				_roll(i)

	func _bumps() -> void:
		for i in recs.size():
			for j in range(i + 1, recs.size()):
				var key := "%d-%d-%d" % [i, j, int(stretch[i])]
				if _running(i) and _running(j) and stretch[i] == stretch[j] and not bumped.has(key) \
						and rivals(i, j) and _gap(i, j) < float(R["bump_near"]):
					bumped[key] = true
					bump_t[i] = float(R["bump_s"])
					bump_t[j] = float(R["bump_s"])

## Pays out a finished race: joy, trust, memories, gems and bonds. Returns what the card shows.
static func settle(run: Run) -> Dictionary:
	var R := rules()
	var order := run.order()
	var win: Dictionary = run.recs[order[0]]
	var lose: Dictionary = run.recs[order[-1]]
	for rec in run.recs:
		Care.change(rec, "energy", -float(R["energy"]))
	Care.change(win, "joy", float(R["win_joy"]))
	Care.change(lose, "joy", float(R["lose_joy"]))
	Save.remember(win, "race", "won the Dash ahead of %s" % lose["name"], float(R["win_trust"]))
	Save.remember(lose, "race", "came last in the Dash, behind %s" % win["name"])
	nudge_bond(win, lose, -float(R["rival_step"]))
	for n in range(1, order.size()):
		var a: Dictionary = run.recs[order[n - 1]]
		var b: Dictionary = run.recs[order[n]]
		var close := float(run.done_t[order[n]]) - float(run.done_t[order[n - 1]]) < float(R["close_s"])
		if close and bond(a, b) > float(R["rival_at"]) and not (a == win and b == lose):
			nudge_bond(a, b, float(R["friend_step"]))
	var backed_won: bool = order[0] == run.backed
	var gems := int(R["gems_win"]) if backed_won else int(R["gems_ran"])
	Save.d["gems"] = int(Save.d["gems"]) + gems
	return {"win": win, "lose": lose, "gems": gems, "backed_won": backed_won}

# ------------------------------------------------------------------ on the base
var h                          # the Home screen
var post: Node3D = null
var start := Vector3.ZERO      # the loop's start line
var run: Run = null
var runners: Array = []        # the home's kin entries, in run order
var bar: TimingBar = null
var card: Control = null
var card_t := 0.0

func _init(home) -> void:
	h = home

## The post and loop beside the Training post (none without one); called when fixtures move.
func place() -> void:
	if is_instance_valid(post):
		post.queue_free()
	post = null
	if h.YARD_AT.x < -100.0:
		return
	post = Node3D.new()
	post.name = "RacePost"
	post.position = h.YARD_AT + POST_OFF
	h.add_child(post)
	start = post.position + LOOP_OFF
	_post_model()
	var st: Array = rules()["stretches"]
	for i in st.size():
		var a := _corner(i)
		var b := _corner(i + 1)
		var strip := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var span := Vector3(absf(b.x - a.x), 0.04, absf(b.z - a.z))
		if span.x > span.z:
			span.z = TRACK_W
		else:
			span.x = TRACK_W
		bm.size = span
		strip.mesh = bm
		strip.material_override = mat(STRETCH_COL[String(st[i]["kind"])])
		strip.position = (a + b) * 0.5 - post.position + Vector3(0, _ground(a) + 0.02, 0)
		post.add_child(strip)

func _post_model() -> void:
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.08
	cm.height = 1.6
	pole.mesh = cm
	pole.material_override = mat(Color("8a6a4a"))
	pole.position = Vector3(0, _ground(post.position) + 0.8, 0)
	post.add_child(pole)
	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.6, 0.36, 0.03)
	flag.mesh = fm
	flag.material_override = mat(UI.ACCENT)
	flag.position = Vector3(0.32, _ground(post.position) + 1.4, 0)
	post.add_child(flag)

static func mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

func _ground(p: Vector3) -> float:
	var g: float = h._ground_h(p.x, p.z)
	return g if g > -50.0 else 0.0

## Corner i of the loop: 0 the start, then round the 6 x 3 rectangle back to it.
func _corner(i: int) -> Vector3:
	var deep := float(rules()["stretches"][1]["len"])
	return start + [Vector3.ZERO, Vector3(LOOP_W, 0, 0), Vector3(LOOP_W, 0, -deep), Vector3(0, 0, -deep)][i % 4]

func find(p2: Vector2) -> Dictionary:
	if run != null or not is_instance_valid(post) or p2.distance_to(Vector2(post.position.x, post.position.z)) > REACH:
		return {}
	return {"kind": "race"}

func label() -> String:
	return "Start a Dash (back %s)" % Save.active_kin().get("name", "your partner")

## Up to 4 rested Boki out on the base, your partner first.
func entrants() -> Array:
	var R := rules()
	var out: Array = []
	var ak := Save.active_kin()
	for k in h.kins:
		var rec: Dictionary = k["rec"]
		if k.get("busy", false) or k.has("indoors") or Care.need(rec, "energy") < float(R["min_energy"]):
			continue
		if rec == ak:
			out.push_front(k)
		else:
			out.append(k)
	return out.slice(0, 4)

func use() -> void:
	var ks := entrants()
	if ks.size() < 2:
		h._toast("The Dash needs two rested Boki out on the base")
		return
	runners = ks
	var recs: Array = []
	for k in ks:
		k["busy"] = true
		recs.append(k["rec"])
	var back := maxi(0, recs.find(Save.active_kin()))
	run = Run.new(recs, back, RandomNumberGenerator.new())
	run.rng.randomize()
	bar = TimingBar.new()
	bar.open(h.root_ui, "Press %s at each mark to cheer" % Settings.key_cap("interact"))
	_bar_label("")
	_place_runners()
	Sfx.play("whoosh", null, -8.0)

func _bar_label(last: String) -> void:
	var who: String = run.recs[run.backed]["name"]
	bar.lbl.text = "Cheer for %s  ·  mark %d of 3%s" % [who, mini(run.cheered + 1, 3), last]

## A press: true when the race took it.
func input(event: InputEvent) -> bool:
	if run == null:
		return false
	if event.is_action_pressed("menu"):
		_end(false)
		return true
	if not TimingBar.is_press(event):
		return false
	if run.can_cheer():
		var r := bar.press()
		run.cheer(r)
		h._emote(runners[run.backed], {"great": "★", "good": "♪", "miss": "?"}[r], true)
		_bar_label("  " + {"great": "★", "good": "●", "miss": "✕"}[r])
	return true

func tick(d: float) -> void:
	if card_t > 0.0:
		card_t -= d
		if card_t <= 0.0 and is_instance_valid(card):
			card.queue_free()
	if run == null:
		return
	run.step(d)
	bar.step(d)
	_place_runners()
	if run.over():
		_end(true)

func _place_runners() -> void:
	var st: Array = rules()["stretches"]
	var lane := float(rules()["lane"])
	for i in runners.size():
		var s := int(run.stretch[i])
		var into := float(run.dist[i]) - (float(run.ends[s - 1]) if s > 0 else 0.0)
		var f := clampf(into / float(st[s]["len"]), 0.0, 1.0)
		var a := _corner(s)
		var b := _corner(s + 1)
		var fwd := (b - a).normalized()
		var p := a.lerp(b, f) + Vector3(-fwd.z, 0, fwd.x) * lane * (i - (runners.size() - 1) * 0.5)
		p.y = _ground(p) + _lift(String(st[s]["kind"]), f)
		var n: Node3D = runners[i]["node"]
		n.position = p
		n.rotation.y = atan2(-fwd.x, -fwd.z)
		runners[i]["pos"] = p

func _lift(kind: String, f: float) -> float:
	match kind:
		"climb": return CLIMB_H * sin(PI * f)
		"jump": return JUMP_H * sin(PI * f)
		"water": return -SWIM_DIP
	return 0.0

func _end(finished: bool) -> void:
	var res := settle(run) if finished else {}
	for k in runners:
		k["busy"] = false
		k["t"] = 1.5
	bar.close()
	if finished:
		_card(res)
		h._emote(h._kin_entry(res["win"]), "♥", true)
		h._emote(h._kin_entry(res["lose"]), "…", true)
		Save.save_game()
	run = null
	runners = []

func _card(res: Dictionary) -> void:
	var win: Dictionary = res["win"]
	var lose: Dictionary = res["lose"]
	var why := " for backing the winner" if res["backed_won"] else ""
	if is_instance_valid(card):
		card.queue_free()
	card = result_card(h, [
		["%s wins the Dash!" % win["name"], 18, UI.ACCENT_HI],
		["%s is beaming (+joy, +trust)" % win["name"], 14, UI.INK],
		["%s sulks: \"came last in the Dash, behind %s\"" % [lose["name"], win["name"]], 14, UI.MUTED],
		["+%d gems%s" % [res["gems"], why], 14, UI.GOLD]])
	card_t = float(rules()["card_s"])

## A minigame's result card at the top of the screen: rows of [text, size, colour]. Shared with the Stump Shove.
static func result_card(home, rows: Array) -> Control:
	var c := UI.card(Color(0.06, 0.07, 0.1, 0.92), 14, 14)
	c.set_anchors_preset(Control.PRESET_CENTER_TOP)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.offset_top = 90
	var v := UI.vbox(6)
	c.add_child(v)
	for r in rows:
		v.add_child(UI.label(r[0], r[1], r[2]))
	home.root_ui.add_child(c)
	return c
