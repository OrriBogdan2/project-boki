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
## The Training post folds in (GARDEN.md 5, "training is practising a minigame alone"): with base_mode
## on, "Train" runs a solo lap of the same loop (solo()); each cheer adds to Speed, see settle_solo().
## The Relay Cup (BaseRelay) runs on the same loop from its own stand; this script hosts it.
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

## Weeks since 1970 by the real clock.
static func week_now() -> int:
	return int(Time.get_unix_time_from_system() / float(rules()["week_s"]))

## The weekly event format for a week number (default this week): {id, game, name, note, plus its tweak:
## mult?, wobble?, swap?, night?, to_win?}.
static func twist(week := -1) -> Dictionary:
	var list: Array = rules()["twists"]
	return list[(week if week >= 0 else week_now()) % list.size()]

## This week's format when it is for this game ("dash", "seek", "volley"), else {}: the game plays as usual.
static func tweak(game: String) -> Dictionary:
	var f := twist()
	return f if String(f["game"]) == game else {}

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

## The lap's stretches under a tweak: its 'swap' changes one stretch's kind and mult (a second water stretch).
static func stretches(tw := {}) -> Array:
	var out: Array = rules()["stretches"]
	if tw.has("swap"):
		out = out.duplicate(true)
		out[int(tw["swap"]["at"])].merge(tw["swap"], true)
	return out

## Its pace on stretch i before the wobble and your cheers (m/s).
static func stretch_pace(rec: Dictionary, i: int, tw := {}) -> float:
	var R := rules()
	var s: Dictionary = stretches(tw)[i]
	var speed := float(rec.get("stats", {}).get("speed", 0))
	var mood: Array = R["mood"]
	var p := float(R["pace"]) * float(s["mult"]) * (1.0 + speed * float(R["speed_per_point"]))
	p *= lerpf(float(mood[0]), float(mood[1]), Care.need(rec, "joy") / 100.0)
	p *= float(tw.get("mult", {}).get(String(s["kind"]), 1.0))
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
static func expected_time(rec: Dictionary, tw := {}) -> float:
	var out := 0.0
	var st := stretches(tw)
	for i in st.size():
		out += float(st[i]["len"]) / stretch_pace(rec, i, tw)
	return out

## The race itself: runners' distance along the lap, stepped in time.
class Run:
	var R: Dictionary
	var recs: Array
	var backed := 0                 # index in recs: the Boki you cheer for
	var rng: RandomNumberGenerator
	var tw: Dictionary              # this week's format tweak for the Dash (empty when it is another game's)
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
	var duo := {}                   # runner index -> duo friend's index it handed off cleanly with

	func _init(runners: Array, back: int, r: RandomNumberGenerator, twist := {}) -> void:
		R = BaseRace.rules()
		tw = twist
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
		var w := float(tw.get("wobble", R["wobble"]))
		var p := BaseRace.stretch_pace(recs[i], int(stretch[i]), tw) * rng.randf_range(1.0 - w, 1.0 + w)
		if i == backed and int(stretch[i]) > 0:
			p *= cheer_mult
			cheer_mult = 1.0
			cheered = maxi(cheered, int(stretch[i]))      # a mark passed with no press is a miss
		var mate := _duo_mate(i) if int(stretch[i]) > 0 else -1
		if mate >= 0:
			p *= float(BaseDuo.rules()["handoff_pace"])
			duo[i] = mate
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

	## A duo friend running alongside runner i (-1 if none): the hand-off into the next stretch is clean.
	func _duo_mate(i: int) -> int:
		for j in recs.size():
			if j != i and _running(j) and _gap(i, j) < float(R["friend_near"]) and BaseDuo.friends(recs[i], recs[j]):
				return j
		return -1

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
	MinigameHub.record("race", String(win["name"]))     # best Boki on the title's picker
	Save.remember(win, "race", "won the Dash ahead of %s" % lose["name"], float(R["win_trust"]))
	Save.remember(lose, "race", "came last in the Dash, behind %s" % win["name"])
	nudge_bond(win, lose, -float(R["rival_step"]))
	for n in range(1, order.size()):
		var a: Dictionary = run.recs[order[n - 1]]
		var b: Dictionary = run.recs[order[n]]
		var close := float(run.done_t[order[n]]) - float(run.done_t[order[n - 1]]) < float(R["close_s"])
		if close and bond(a, b) > float(R["rival_at"]) and not (a == win and b == lose):
			nudge_bond(a, b, float(R["friend_step"]))
	for i in run.duo:
		BaseDuo.note_first(run.recs[i], run.recs[run.duo[i]], "handed off cleanly with")
	var backed_won: bool = order[0] == run.backed
	var gems := int(R["gems_win"]) if backed_won else int(R["gems_ran"])
	Save.d["gems"] = int(Save.d["gems"]) + gems
	var mine: Dictionary = run.recs[run.backed]
	var prize := GardenPrizes.settle("dash", mine, GardenPrizes.strongest(run.recs, mine), backed_won)
	return {"win": win, "lose": lose, "gems": gems, "backed_won": backed_won, "prize": prize}

## Pays out a solo training lap (grades: three of great/good/miss). Returns the Speed gained.
static func settle_solo(rec: Dictionary, grades: Array) -> int:
	var T: Dictionary = rules()["train"]
	var pts := 0
	for g in grades:
		if g != "miss":
			pts += int(T[g]) + (int(T["dojo"]) if Save.has_building("dojo") else 0)
	var mult := float(T["happy_mult"]) if Care.need(rec, "joy") >= float(T["happy_at"]) else 1.0
	var gained := Care.add_stat(rec, "speed", int(round(pts * mult)))
	Care.change(rec, "energy", -float(rules()["energy"]))
	Care.change(rec, "food", -float(T["food"]))
	Care.change(rec, "joy", float(T["joy_great"]) if grades.has("great") else float(T["joy_else"]))
	Evo.add(rec, "swift", 2.0)
	if gained > 0:
		Save.remember(rec, "trained", "ran a training lap of the Dash with you", 1.0)
	return gained

# ------------------------------------------------------------------ on the base
var h                          # the Home screen
var post: Node3D = null
var wall: Node3D = null        # the showcase wall (BaseShowcase) by the post, when there is no hub
var start := Vector3.ZERO      # the loop's start line
var run: Run = null
var runners: Array = []        # the home's kin entries, in run order
var bar: TimingBar = null
var solo_rec := {}             # the Boki on a solo training lap ({} in a race)
var cheers: Array = []         # the grades of your presses this lap
var card: Control = null
var card_t := 0.0
var held: Array = []           # the winner and the loser, kept on the spot until the card goes
var heard: Array = []          # per runner: the stretch last heard, plus the stretch count once home
var cue: GardenCues.DashCue = null   # the cheer marks and finish line while a lap runs
var relay: BaseRelay           # the Relay Cup on this loop, from its stand at the far corner

func _init(home) -> void:
	h = home
	relay = BaseRelay.new(self)

## The post and loop beside the Training post (none without one); called when fixtures move.
func place() -> void:
	for n in [post, wall]:
		if is_instance_valid(n):
			n.queue_free()
	post = null
	wall = null
	if h.YARD_AT.x < -100.0:
		relay.place()
		return
	var at: Vector3 = h.YARD_AT + POST_OFF
	if h.zone == "":       # with the hub on, the wall hangs by its games board (HubWaystone)
		wall = BaseShowcase.build(at + BaseShowcase.WALL_OFF, Save.d.get("showcase", []))
		h.add_child(wall)
	post = Node3D.new()
	post.name = "RacePost"
	post.position = at
	h.add_child(post)
	start = post.position + LOOP_OFF
	_post_model()
	var st: Array = stretches(tweak("dash"))
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
		strip.position = (a + b) * 0.5 - post.position + Vector3(0, ground(a) + 0.02, 0)
		post.add_child(strip)
	relay.place()

func _post_model() -> void:
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.08
	cm.height = 1.6
	pole.mesh = cm
	pole.material_override = mat(Color("8a6a4a"))
	pole.position = Vector3(0, ground(post.position) + 0.8, 0)
	post.add_child(pole)
	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.6, 0.36, 0.03)
	flag.mesh = fm
	flag.material_override = mat(UI.ACCENT)
	flag.position = Vector3(0.32, ground(post.position) + 1.4, 0)
	post.add_child(flag)
	var sign_t := Label3D.new()
	sign_t.text = "This week, %s: %s\n%s" % [String(twist()["game"]).capitalize(), twist()["name"], twist()["note"]]
	sign_t.font_size = 28
	sign_t.pixel_size = 0.004
	sign_t.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_t.position = Vector3(0.3, ground(post.position) + 1.85, 0)
	post.add_child(sign_t)

static func mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

func ground(p: Vector3) -> float:
	var g: float = h._ground_h(p.x, p.z)
	return g if g > -50.0 else 0.0

## Corner i of the loop: 0 the start, then round the 6 x 3 rectangle back to it.
func _corner(i: int) -> Vector3:
	var deep := float(rules()["stretches"][1]["len"])
	return start + [Vector3.ZERO, Vector3(LOOP_W, 0, 0), Vector3(LOOP_W, 0, -deep), Vector3(0, 0, -deep)][i % 4]

func find(p2: Vector2) -> Dictionary:
	if run != null or relay.run != null or not is_instance_valid(post):
		return {}
	if p2.distance_to(Vector2(post.position.x, post.position.z)) > REACH:
		return relay.find(p2)
	return {"kind": "race"}

func label() -> String:
	var fmt := String(tweak("dash").get("name", ""))
	var back := "back %s" % Save.active_kin().get("name", "your partner")
	return "Start a Dash, %s (%s)" % [fmt, back] if fmt else "Start a Dash (%s)" % back

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
	release()
	var ks := entrants()
	if ks.size() < 2:
		h._toast("The Dash needs two rested Boki out on the base")
		return
	_begin(ks)

## The Training post: your Boki runs the loop alone while you cheer at the three marks.
func solo(rec: Dictionary) -> void:
	release()
	var k: Dictionary = h._kin_entry(rec)
	var T: Dictionary = rules()["train"]
	if k.is_empty() or k.get("busy", false) or k.has("indoors"):
		h._toast("%s is not out on the base" % rec["name"])
	elif Care.need(rec, "energy") < float(rules()["min_energy"]) or Care.need(rec, "food") < float(T["min_food"]):
		h._toast("%s is too tired or hungry to train. Nap or feed it first" % rec["name"])
	elif int(rec["stats"]["speed"]) >= Care.stat_cap(rec):
		h._toast("%s can't train Speed any further until it levels up" % rec["name"])
	else:
		h._care_start(k)
		solo_rec = rec
		_begin([k])

func _begin(ks: Array) -> void:
	runners = ks
	cheers = []
	var recs: Array = []
	for k in ks:
		k["busy"] = true
		recs.append(k["rec"])
	var back := maxi(0, recs.find(Save.active_kin()))
	run = Run.new(recs, back, RandomNumberGenerator.new(), tweak("dash"))
	run.rng.randomize()
	bar = TimingBar.new()
	bar.open(h.root_ui, "Press %s at each mark to cheer" % Settings.key_cap("interact"))
	_bar_label("")
	_place_runners()
	var marks: Array = []
	for i in range(1, 4):
		marks.append(_corner(i) + Vector3(0, ground(_corner(i)), 0))
	cue = GardenCues.DashCue.new(h, marks, _corner(0) + Vector3(0, ground(_corner(0)), 0), TRACK_W)
	heard = []
	heard.resize(runners.size())
	heard.fill(0)
	GardenSfx.countdown(h, start)

func _bar_label(last: String) -> void:
	var who: String = run.recs[run.backed]["name"]
	bar.lbl.text = "Cheer for %s  ·  mark %d of 3%s" % [who, mini(run.cheered + 1, 3), last]

## A press: true when the race took it.
func input(event: InputEvent) -> bool:
	if relay.input(event):
		return true
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
		cheers.append(r)
		GardenSfx.crowd(r, runners[run.backed]["pos"])
		if r != "miss" and "verbs" in h:
			h.verbs.play("cheer")       # your Hunter's cheer clip (warden_anim "act")
		h._emote(runners[run.backed], {"great": "★", "good": "♪", "miss": "?"}[r], true)
		_bar_label("  " + {"great": "★", "good": "●", "miss": "✕"}[r])
	return true

func tick(d: float) -> void:
	if card_t > 0.0:
		card_t -= d
		if card_t <= 0.0 and is_instance_valid(card):
			card.queue_free()
		if card_t <= 0.0:
			let_go(held)
			held = []
	relay.tick(d)
	if run == null:
		return
	run.step(d)
	bar.step(d)
	_place_runners()
	var home_done: bool = float(run.done_t[run.backed]) >= 0.0
	cue.update(3 if home_done else int(run.stretch[run.backed]), run.can_cheer(), d)
	_hear_laps()
	if run.over():
		_end(true)

## A pat as a runner starts each stretch, a swish at the line, and the crowd for the first one home.
func _hear_laps() -> void:
	var stretches: int = run.ends.size()
	for i in runners.size():
		var mark: int = int(run.stretch[i]) + (stretches if float(run.done_t[i]) >= 0.0 else 0)
		if mark == heard[i]:
			continue
		heard[i] = mark
		if mark < stretches:
			GardenSfx.cue("garden_lap", runners[i]["pos"])
			continue
		GardenSfx.cue("garden_finish", runners[i]["pos"])
		if heard.filter(func(m): return m >= stretches).size() == 1:
			GardenSfx.cue("garden_crowd", runners[i]["pos"])

func _place_runners() -> void:
	var st: Array = stretches(run.tw)
	var lane := float(rules()["lane"])
	for i in runners.size():
		var s := int(run.stretch[i])
		var into := float(run.dist[i]) - (float(run.ends[s - 1]) if s > 0 else 0.0)
		var p := track_at(s, clampf(into / float(st[s]["len"]), 0.0, 1.0), lane * (i - (runners.size() - 1) * 0.5))
		gait(runners[i], "leap" if String(st[s]["kind"]) == "jump" else "")
		var n: Node3D = runners[i]["node"]
		n.position = p
		n.rotation.y = heading(s)
		runners[i]["pos"] = p

## A point on the loop: fraction f along stretch s, `side` m right of its middle line, on the ground.
func track_at(s: int, f: float, side: float) -> Vector3:
	var a := _corner(s)
	var fwd := (_corner(s + 1) - a).normalized()
	var p := a.lerp(_corner(s + 1), f) + Vector3(-fwd.z, 0, fwd.x) * side
	p.y = ground(p) + _lift(String(rules()["stretches"][s]["kind"]), f)
	return p

## The facing (rotation.y) of a runner on stretch s.
func heading(s: int) -> float:
	var fwd := (_corner(s + 1) - _corner(s)).normalized()
	return atan2(-fwd.x, -fwd.z)

func _lift(kind: String, f: float) -> float:
	match kind:
		"climb": return CLIMB_H * sin(PI * f)
		"jump": return JUMP_H * sin(PI * f)
		"water": return -SWIM_DIP
	return 0.0

func _end(finished: bool) -> void:
	var res := {}
	if finished and solo_rec.is_empty():
		res = settle(run)
	for k in runners:
		k["busy"] = false
		k["t"] = 1.5
		gait(k, "")
	bar.close()
	cue.clear()
	cue = null
	if finished:
		GardenFirstDay.mark("race", h)
		if solo_rec.is_empty():
			_race_card(res, pin(res["win"], "dash"))
			GardenSfx.result(h, res)
			h._emote(h._kin_entry(res["win"]), "♥", true)
			h._emote(h._kin_entry(res["lose"]), "…", true)
			held = hold(h, res)
		else:
			_solo_card(settle_solo(solo_rec, _grades()))
		Save.save_game()
	run = null
	runners = []
	solo_rec = {}

## A win in this week's event game goes on the showcase wall with a snapshot of the winner.
## Shared with Seek and Spark Volley. False when this week's format is another game's.
func pin(win: Dictionary, game: String) -> bool:
	var fmt := tweak(game)
	if fmt.is_empty():
		return false
	var node: Node3D = h._kin_entry(win)["node"]
	BaseShowcase.add(win, fmt, BaseShowcase.snap(h.get_viewport(), h.cam, node.global_position + Vector3(0, 0.5, 0)))
	if wall == null:
		return true
	wall.queue_free()
	wall = BaseShowcase.build(post.position + BaseShowcase.WALL_OFF, Save.d["showcase"])
	h.add_child(wall)
	return true

## The three marks' grades: a mark with no press is a miss.
func _grades() -> Array:
	var out := cheers.duplicate()
	while out.size() < 3:
		out.append("miss")
	return out

func _race_card(res: Dictionary, pinned: bool) -> void:
	var win: Dictionary = res["win"]
	var lose: Dictionary = res["lose"]
	var why := " for backing the winner" if res["backed_won"] else ""
	show_card("%s wins the Dash!" % win["name"], [
		["%s is beaming (+joy, +trust)" % win["name"], UI.INK],
		["%s sulks: \"came last in the Dash, behind %s\"" % [lose["name"], win["name"]], UI.MUTED],
		["+%d gems%s" % [res["gems"], why], UI.GOLD]] + pin_rows(pinned) + GardenPrizes.rows(res["prize"]))

## The result-card row for a win that went on the wall (none when it did not).
static func pin_rows(pinned: bool) -> Array:
	return [["%s: pinned to the showcase wall" % twist()["name"], UI.MUTED]] if pinned else []

func _solo_card(gained: int) -> void:
	var speed := int(solo_rec["stats"]["speed"])
	var marks := ""
	for g in _grades():
		marks += {"great": " ★", "good": " ●", "miss": " ✕"}[g]
	var line := "No gain this time. Try again after a rest"
	if gained > 0:
		line = "+%d Speed  (%d of %d)" % [gained, speed, Care.stat_cap(solo_rec)]
	show_card("%s ran a training lap!" % solo_rec["name"], [[marks.strip_edges(), UI.INK], [line, UI.GOLD]])

## The result card at the top of the screen: a headline and a coloured line each.
func show_card(title: String, lines: Array) -> void:
	if is_instance_valid(card):
		card.queue_free()
	var rows := [[title, 18, UI.ACCENT_HI]]
	for l in lines:
		rows.append([l[0], 14, l[1]])
	card = result_card(h, rows)
	card_t = float(rules()["card_s"])

## Plays a BokiRig clip (win, sulk, push, bat; "" stops it) on a kin's Boki: rigged ones only, the rest ignore it.
static func act(k: Dictionary, which: String) -> void:
	tag(k, "kact", which)

## Sets the gait a rigged Boki moves in (sniff, leap; "" for its own walk and run).
static func gait(k: Dictionary, which: String) -> void:
	tag(k, "kgait", which)

static func tag(k: Dictionary, key: String, which: String) -> void:
	var n := k["node"] as Node3D
	if which == "":
		n.remove_meta(key)
	else:
		n.set_meta(key, which)

## The result of a minigame ({win, lose}): the winner shows it, the loser sulks, both stay put until `let_go`.
static func hold(home, res: Dictionary) -> Array:
	var ks: Array = []
	for who in [["win", "win"], ["lose", "sulk"]]:
		var k: Dictionary = home._kin_entry(res[who[0]])
		k["busy"] = true
		act(k, who[1])
		ks.append(k)
	return ks

## A new Dash, lap or Shove ends the last result pose early, so its winner and loser can play again.
func release() -> void:
	let_go(held)
	held = []
	for game in [h.get("hshove"), h.get("hvolley"), h.get("hseek")]:
		if game != null:
			let_go(game.held)
			game.held = []

static func let_go(ks: Array) -> void:
	for k in ks:
		k["busy"] = false
		k["t"] = 1.5
		act(k, "")

## A minigame's result card at the top of the screen: rows of [text, size, colour]. Shared with the Stump Shove,
## Seek and Spark Volley.
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
