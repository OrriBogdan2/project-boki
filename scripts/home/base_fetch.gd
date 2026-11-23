class_name BaseFetch
extends RefCounted
## Fetch Cup (docs/GARDEN_GAMES.md), a Boki vs Boki garden game; only with farm_build.json base_mode on.
## A toss mat lies by the Training post. Press interact at it and two rested Boki out on the base (your
## partner and the next one) chase a tossed seed for a 60 s round; the first back with it scores.
## A trip takes distance over pace: Speed, mood and trust set the pace, Focus keeps the pick-up from
## fumbling, and each trip is rolled within +-25%. You call one head start for the Boki you back on the
## Training post's timing bar. The winner gains joy, trust and you a few gems; the loser sulks and
## remembers. Tuning: content/rules/base_fetch.json.
##
## The round is one explicit state machine (briefs/STATE_MACHINES.md), Run.state: only Run.go() writes
## it, and a move the TABLE lacks is refused and counted (--fetch-check asserts none).
##   TOSS  -> CHASE  the seed leaves the mat
##   CHASE -> BRING  the quicker Boki has it: the point
##   BRING -> TOSS   the next seed        -> DONE   the round's 60 s are up
## Run has no nodes, so --fetch-check (tools/fetch_check.gd) plays whole rounds headless.

const MAT_OFF := Vector3(2.8, 0, -2.2)  # m from the Training post to the toss mat
const MAT_R := 0.5  # m, the mat's radius
const LANE := 0.9  # m each runner stands off the line of the toss
const SEED_R := 0.1  # m, the seed's radius
const ARC := 1.2  # m the seed rises in flight
const REACH := 1.8  # m from the mat to start a round

# ------------------------------------------------------------------ on the base
var h  # the Home screen
var mat: Node3D = null
var seed_node: MeshInstance3D = null
var run: Run = null
var pair: Array = []  # the home's kin entries: a, b
var bar: TimingBar = null
var card: Control = null
var card_t := 0.0
var cue: GardenCues.VolleyCue = null  # the landing ring and head-start flash while a round runs


static func rules() -> Dictionary:
	return Content.rules("base_fetch")


## Metres a second a Boki runs: 1.0 x the rules' pace for no Speed points and a plain mood.
static func pace(rec: Dictionary) -> float:
	var r_v := rules()
	var st: Dictionary = rec.get("stats", {})
	var p := float(r_v["pace"]) * (1.0 + float(st.get("speed", 0)) * float(r_v["speed_per_point"]))
	var mood: Array = r_v["mood"]
	p *= lerpf(float(mood[0]), float(mood[1]), Care.need(rec, "joy") / 100.0)
	return p * lerpf(1.0, float(r_v["trust_max"]), float(rec.get("trust", 0.0)) / 100.0)


## The chance a Boki fumbles the pick-up: less with Focus points.
static func p_fumble(rec: Dictionary) -> float:
	var r_v := rules()
	return float(r_v["fumble"]) / (1.0 + float(rec.get("stats", {}).get("focus", 0)) * float(r_v["focus_per_point"]))


## The round itself, stepped in time. Sides are indexes 0 and 1 into recs.
class Run:
	enum S { TOSS, CHASE, BRING, DONE }
	const TABLE := {S.TOSS: [S.CHASE], S.CHASE: [S.BRING], S.BRING: [S.TOSS, S.DONE], S.DONE: []}

	var r_x: Dictionary
	var recs: Array  # two records
	var backed := 0  # index in recs: the Boki you back
	var rng: RandomNumberGenerator
	var state := S.TOSS
	var state_t := 0.0  # s in this state
	var refused := 0  # moves the TABLE turned down
	var t := 0.0
	var score: Array = [0, 0]
	var last := 0  # the side that scored last
	var dist := 0.0  # m the seed in play went
	var go: Array = [0.0, 0.0]  # s each side runs out to the seed
	var lag: Array = [0.0, 0.0]  # s each side loses fumbling it (0 or fumble_s)
	var head := ""  # your call, "" until you press, then its grade until the next trip uses it
	var called := false  # your one call is used
	var tosses := 0  # seeds thrown in the round

	func _init(pair: Array, back: int, r: RandomNumberGenerator) -> void:
		r_x = BaseFetch.rules()
		recs = pair
		backed = back
		rng = r
		_toss()

	## The only writer of `state`: false (and counted) when the TABLE lacks the move.
	func move(next: S) -> bool:
		if not TABLE[state].has(next):
			refused += 1
			return false
		state = next
		state_t = 0.0
		return true

	func can_call() -> bool:
		return not called and not over()

	func call_head(grade: String) -> void:
		called = true
		head = grade

	func over() -> bool:
		return state == S.DONE

	## The side that has the seed first this toss.
	func quicker() -> int:
		return 0 if go[0] + lag[0] <= go[1] + lag[1] else 1

	## 0 or 1: the side on the higher score (the one that scored last on a tie).
	func winner() -> int:
		if score[0] == score[1]:
			return last
		return 0 if score[0] > score[1] else 1

	func step(dt: float) -> void:
		t += dt
		state_t += dt
		match state:
			S.TOSS:
				if state_t >= float(r_x["toss_s"]):
					move(S.CHASE)
			S.CHASE:
				if state_t >= minf(go[0] + lag[0], go[1] + lag[1]):
					last = quicker()
					score[last] += 1
					move(S.BRING)
			S.BRING:
				if state_t >= float(r_x["bring_s"]):
					if t >= float(r_x["round_s"]):
						move(S.DONE)
					else:
						move(S.TOSS)
						_toss()

	## Rolls the next seed: how far, and each side's trip.
	func _toss() -> void:
		tosses += 1
		var d: Array = r_x["dist"]
		dist = rng.randf_range(float(d[0]), float(d[1]))
		for i in 2:
			var rec: Dictionary = recs[i]
			var wob := float(r_x["wobble"])
			go[i] = dist / BaseFetch.pace(rec) * (1.0 + rng.randf_range(-wob, wob))
			lag[i] = float(r_x["fumble_s"]) if rng.randf() < BaseFetch.p_fumble(rec) else 0.0
		if head != "":
			go[backed] *= float(r_x["head_start"][head])
			head = ""


## Pays out a finished round: joy, trust, a memory each, energy and gems. Returns what the card shows.
static func settle(run_v: Run) -> Dictionary:
	var r_v := rules()
	var win: Dictionary = run_v.recs[run_v.winner()]
	var lose: Dictionary = run_v.recs[1 - run_v.winner()]
	for rec in run_v.recs:
		Care.change(rec, "energy", -float(r_v["energy"]))
	Care.change(win, "joy", float(r_v["win_joy"]))
	Care.change(lose, "joy", float(r_v["lose_joy"]))
	var wp: int = run_v.score[run_v.winner()]
	var lp: int = run_v.score[1 - run_v.winner()]
	MinigameHub.record("fetch", String(win["name"]))  # best Boki on the title's picker
	Save.remember(win, "fetch", "beat %s %d to %d at Fetch Cup" % [lose["name"], wp, lp], float(r_v["win_trust"]))
	Save.remember(lose, "fetch", "lost Fetch Cup to %s, %d to %d" % [win["name"], lp, wp])
	var backed_won: bool = run_v.recs[run_v.backed] == win
	var gems := int(r_v["gems_win"]) if backed_won else int(r_v["gems_ran"])
	Save.d["gems"] = int(Save.d["gems"]) + gems
	return {"win": win, "lose": lose, "gems": gems, "backed_won": backed_won, "score": [wp, lp]}


func _init(home) -> void:
	h = home


## True while a round is on (GardenMusic ducks the music for it).
func playing() -> bool:
	return run != null


## The mat and the seed beside the Training post (none without one); called when fixtures move.
func place() -> void:
	if is_instance_valid(mat):
		mat.queue_free()
	mat = null
	if h.YARD_AT.x < -100.0:
		return
	mat = Node3D.new()
	mat.name = "FetchMat"
	mat.position = h.YARD_AT + MAT_OFF
	h.add_child(mat)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = MAT_R
	cm.bottom_radius = MAT_R
	cm.height = 0.05
	disc.mesh = cm
	disc.material_override = BaseRace.mat(Color("8a6a3a"))
	disc.position.y = 0.03
	mat.add_child(disc)
	seed_node = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = SEED_R
	sm.height = SEED_R * 2.0
	seed_node.mesh = sm
	var glow := BaseRace.mat(Color("ffe28a"))
	glow.emission_enabled = true
	glow.emission = Color("ffd24a")
	seed_node.material_override = glow
	seed_node.visible = false
	mat.add_child(seed_node)


func find(p2: Vector2) -> Dictionary:
	if run != null or not is_instance_valid(mat):
		return {}
	if p2.distance_to(Vector2(mat.position.x, mat.position.z)) > REACH:
		return {}
	return {"kind": "fetch"}


func label() -> String:
	return "Play Fetch Cup (back %s)" % Save.active_kin().get("name", "your partner")


func use() -> void:
	var ks: Array = h.hrace.entrants()
	if ks.size() < 2:
		h._toast("Fetch Cup needs two rested Boki out on the base")
		return
	pair = ks.slice(0, 2)
	for k in pair:
		k["busy"] = true
	var back := maxi(0, [pair[0]["rec"], pair[1]["rec"]].find(Save.active_kin()))
	run = Run.new([pair[0]["rec"], pair[1]["rec"]], back, RandomNumberGenerator.new())
	run.rng.randomize()
	bar = TimingBar.new()
	var key := Settings.key_cap("interact")
	bar.open(h.root_ui, "Press %s once, with the marker in the gold, to call a head start" % key)
	bar.lbl.text = "Call %s's head start" % run.recs[run.backed]["name"]
	seed_node.visible = true
	cue = GardenCues.VolleyCue.new(h)
	_place()
	GardenSfx.countdown(h, mat.position)


## A press: true when the round took it.
func input(event: InputEvent) -> bool:
	if run == null:
		return false
	if event.is_action_pressed("menu"):
		_end(false)
		return true
	if not TimingBar.is_press(event):
		return false
	if run.can_call():
		var r := bar.press()
		run.call_head(r)
		GardenSfx.crowd(r, pair[run.backed]["pos"])
		bar.close()
		cue.call_flash(pair[run.backed]["pos"])
		h._emote(pair[run.backed], {"great": "★", "good": "♪", "miss": "?"}[r], true)
	return true


func tick(d: float) -> void:
	if card_t > 0.0:
		card_t -= d
		if card_t <= 0.0 and is_instance_valid(card):
			card.queue_free()
	if run == null:
		return
	var points: int = run.score[0] + run.score[1]
	run.step(d)
	if not run.called:
		bar.step(d)
	if run.score[0] + run.score[1] != points:
		h._emote(pair[run.last], "!", true)
		h._toast("%s %d : %d %s" % [run.recs[0]["name"], run.score[0], run.score[1], run.recs[1]["name"]])
	_place()
	cue.step(d)
	if run.over():
		_end(true)


## Metres out along the toss that a side has run: out while chasing, back with the seed after.
func along(side: int) -> float:
	match run.state:
		Run.S.CHASE:
			return run.dist * clampf(run.state_t / run.go[side], 0.0, 1.0)
		Run.S.BRING:
			var out: float = run.dist * clampf((run.go[side] + run.lag[side]) / maxf(run.go[side], 0.01), 0.0, 1.0)
			return out * (1.0 - clampf(run.state_t / float(run.R["bring_s"]), 0.0, 1.0))
	return 0.0


## The runners stand either side of the line of the toss; the seed flies out, waits, then rides home.
func _place() -> void:
	for i in 2:
		var p: Vector3 = mat.position + Vector3(-LANE if i == 0 else LANE, 0, along(i))
		var g: float = h._ground_h(p.x, p.z)
		p.y = g if g > -50.0 else 0.0
		var n: Node3D = pair[i]["node"]
		n.position = p
		n.rotation.y = 0.0 if run.state != Run.S.BRING else PI
		pair[i]["pos"] = p
	seed_node.position = _seed_at()
	_aim_cue()


## The ring sits where the seed lands; hidden once someone has it.
func _aim_cue() -> void:
	if run.state != Run.S.TOSS:
		cue.hide_landing()
		return
	var land: Vector3 = mat.position + Vector3(0, 0, run.dist)
	var g: float = h._ground_h(land.x, land.z)
	land.y = g if g > -50.0 else 0.0
	cue.aim(land, clampf(run.state_t / float(run.R["toss_s"]), 0.0, 1.0), run.head != "")


## Where the seed is, relative to the mat: in the air on the toss, on the ground while chased, in the
## winner's mouth coming home.
func _seed_at() -> Vector3:
	match run.state:
		Run.S.TOSS:
			var u := clampf(run.state_t / float(run.R["toss_s"]), 0.0, 1.0)
			return Vector3(0, 0.5 + sin(u * PI) * ARC, run.dist * u)
		Run.S.CHASE:
			return Vector3(0, SEED_R, run.dist)
	return Vector3(0, 0.4, along(run.quicker()))


func _end(finished: bool) -> void:
	var res := settle(run) if finished else {}
	for k in pair:
		k["busy"] = false
		k["t"] = 1.5
	bar.close()
	seed_node.visible = false
	cue.clear()
	cue = null
	if finished:
		_card(res)
		GardenSfx.result(h, res)
		h._emote(h._kin_entry(res["win"]), "♥", true)
		h._emote(h._kin_entry(res["lose"]), "…", true)
		Save.save_game()
	run = null
	pair = []


func _card(res: Dictionary) -> void:
	var win: Dictionary = res["win"]
	var lose: Dictionary = res["lose"]
	var why := " for backing the winner" if res["backed_won"] else ""
	if is_instance_valid(card):
		card.queue_free()
	card = BaseRace.result_card(
		h,
		[
			["%s wins Fetch Cup, %d to %d!" % [win["name"], res["score"][0], res["score"][1]], 18, UI.ACCENT_HI],
			["%s is beaming (+joy, +trust)" % win["name"], 14, UI.INK],
			['%s sulks: "lost Fetch Cup to %s"' % [lose["name"], win["name"]], 14, UI.MUTED],
			["+%d gems%s" % [res["gems"], why], 14, UI.GOLD]
		]
	)
	card_t = float(rules()["card_s"])
