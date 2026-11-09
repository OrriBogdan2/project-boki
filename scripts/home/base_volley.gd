class_name BaseVolley
extends RefCounted
## Spark Volley (briefs/design/GARDEN.md section 5.4), the Boki base's fourth minigame; only with
## farm_build.json base_mode on. A log lies by the Training post. Press interact at it and two rested
## Boki out on the base (your partner and the next one) bat a glowing seed over it, first to 5 points;
## a Boki that misses gives the other the point. A Boki returns the seed by chance from its strength:
## Speed and Focus, mood (joy) and trust, and a 10% type edge from the same element table as the Stump
## Shove, over the hitter's. You back your partner and call one spike on the Training post's timing
## bar: its next hit is hard to return. The winner gains joy, trust and you a few gems; the loser
## sulks and remembers (a memory line). Tuning: content/rules/base_volley.json.
##
## The match is one explicit state machine (briefs/STATE_MACHINES.md), Run.state: only Run.go() writes
## it, and a move the TABLE lacks is refused and counted (--volley-check asserts none). No Run means
## no match on the base.
##   SERVE  -> FLIGHT  the server hits the seed over the log
##   FLIGHT -> POINT   a Boki misses: the other side scores
##   POINT  -> SERVE   the winner of the point serves
##          -> DONE    a side reached the target (or time ran out)
## A return keeps FLIGHT: the seed just changes direction (Run.to).
## Run has no nodes, so --volley-check (tools/volley_check.gd) plays whole matches headless.

const LOG_OFF := Vector3(0.0, 0, -2.8)      # m from the Training post to the log's middle
const LOG_LEN := 2.4                         # m, the log's length (across the court)
const LOG_R := 0.22                          # m, its radius
const HALF := 1.5                            # m from the log to each player
const ARC := 1.0                             # m the seed rises on a normal hit
const SPIKE_ARC := 0.35                      # m the seed rises on a spike
const SEED_R := 0.1                          # m, the seed's radius
const REACH := 1.8                           # m from the log to start a match

static func rules() -> Dictionary:
	return Content.rules("base_volley")

## How well a Boki gets under the seed and reads it, before the hitter's: 1.0 for no points and a plain mood.
static func strength(rec: Dictionary, foe: Dictionary) -> float:
	var R := rules()
	var st: Dictionary = rec.get("stats", {})
	var s := (1.0 + float(st.get("speed", 0)) * float(R["speed_per_point"])) \
			* (1.0 + float(st.get("focus", 0)) * float(R["focus_per_point"]))
	var mood: Array = R["mood"]
	s *= lerpf(float(mood[0]), float(mood[1]), Care.need(rec, "joy") / 100.0)
	s *= lerpf(1.0, float(R["trust_max"]), float(rec.get("trust", 0.0)) / 100.0)
	return s * (float(R["edge"]) if BaseShove.has_edge(rec, foe) else 1.0)

## The chance recv returns a seed hit by hitter, before any spike.
static func p_return(recv: Dictionary, hitter: Dictionary) -> float:
	var R := rules()
	return clampf(float(R["base_return"]) * strength(recv, hitter) / strength(hitter, recv),
			float(R["min_return"]), float(R["max_return"]))

## a's chance over b's to take a point from a level start: above 0.5 the expected winner is a.
static func expected(a: Dictionary, b: Dictionary) -> float:
	var pa := p_return(a, b)
	var pb := p_return(b, a)
	return (1.0 - pb) / ((1.0 - pa) + (1.0 - pb))

## The match itself, stepped in time. Sides are indexes 0 and 1 into recs.
class Run:
	enum S { SERVE, FLIGHT, POINT, DONE }
	const TABLE := {S.SERVE: [S.FLIGHT], S.FLIGHT: [S.POINT], S.POINT: [S.SERVE, S.DONE], S.DONE: []}

	var R: Dictionary
	var recs: Array                 # two records
	var backed := 0                 # index in recs: the Boki you back
	var rng: RandomNumberGenerator
	var state := S.SERVE
	var state_t := 0.0              # s in this state
	var refused := 0                # moves the TABLE turned down
	var t := 0.0
	var score: Array = [0, 0]
	var server := 0                 # the side hitting the next serve
	var to := 1                     # the side the seed is flying to
	var hitter := 0                 # the side that last hit it
	var fly_t := 0.0                # s until the seed arrives
	var fly_total := 1.0            # s this flight takes in all (for the arc)
	var hard := 1.0                 # the spike on the seed in the air: the receiver's chance is times this
	var spike := ""                 # your call, "" until you press, then its grade until the next backed hit uses it
	var called := false             # your one call is used
	var last_miss := -1             # the side that dropped the last seed, -1 before the first point
	var rally := 0                  # hits since the serve

	func _init(pair: Array, back: int, r: RandomNumberGenerator) -> void:
		R = BaseVolley.rules()
		recs = pair
		backed = back
		rng = r

	## The only writer of `state`: false (and counted) when the TABLE lacks the move.
	func go(next: S) -> bool:
		if not TABLE[state].has(next):
			refused += 1
			return false
		state = next
		state_t = 0.0
		return true

	func can_call() -> bool:
		return not called and not over()

	func call_spike(grade: String) -> void:
		called = true
		spike = grade

	func over() -> bool:
		return state == S.DONE

	## 0 or 1: the side on the higher score (the server on a tie, after a timeout).
	func winner() -> int:
		if score[0] == score[1]:
			return server
		return 0 if score[0] > score[1] else 1

	func step(dt: float) -> void:
		t += dt
		state_t += dt
		match state:
			S.SERVE:
				if state_t >= float(R["serve_s"]):
					rally = 0
					_hit(server)
					go(S.FLIGHT)
			S.FLIGHT:
				fly_t -= dt
				if fly_t <= 0.0:
					_arrive()
			S.POINT:
				if state_t >= float(R["point_s"]):
					go(S.DONE if _finished() else S.SERVE)

	func _finished() -> bool:
		return maxi(score[0], score[1]) >= int(R["to_win"]) or t >= float(R["max_s"])

	## side hits the seed to the other side; your call makes the backed Boki's hit a spike.
	func _hit(side: int) -> void:
		hitter = side
		to = 1 - side
		hard = 1.0
		fly_total = float(R["fly_s"])
		if side == backed and spike != "":
			hard = float(R["spike"][spike])
			if hard < 1.0:
				fly_total = float(R["spike_fly_s"])
			spike = ""
		fly_t = fly_total
		rally += 1

	func _arrive() -> void:
		var p := BaseVolley.p_return(recs[to], recs[hitter]) * hard
		if rng.randf() < p:
			_hit(to)
			return
		last_miss = to
		score[hitter] += 1
		server = hitter
		go(S.POINT)

## Pays out a finished match: joy, trust, a memory each, energy and gems. Returns what the card shows.
static func settle(run: Run) -> Dictionary:
	var R := rules()
	var win: Dictionary = run.recs[run.winner()]
	var lose: Dictionary = run.recs[1 - run.winner()]
	for rec in run.recs:
		Care.change(rec, "energy", -float(R["energy"]))
	Care.change(win, "joy", float(R["win_joy"]))
	Care.change(lose, "joy", float(R["lose_joy"]))
	var wp: int = run.score[run.winner()]
	var lp: int = run.score[1 - run.winner()]
	Save.remember(win, "volley", "beat %s %d to %d at Spark Volley" % [lose["name"], wp, lp], float(R["win_trust"]))
	Save.remember(lose, "volley", "lost Spark Volley to %s, %d to %d" % [win["name"], lp, wp])
	var backed_won: bool = run.recs[run.backed] == win
	var gems := int(R["gems_win"]) if backed_won else int(R["gems_ran"])
	Save.d["gems"] = int(Save.d["gems"]) + gems
	return {"win": win, "lose": lose, "gems": gems, "backed_won": backed_won, "score": [wp, lp]}

# ------------------------------------------------------------------ on the base
var h                          # the Home screen
var log_node: Node3D = null
var seed_node: MeshInstance3D = null
var run: Run = null
var pair: Array = []           # the home's kin entries: a, b
var bar: TimingBar = null
var card: Control = null
var card_t := 0.0

func _init(home) -> void:
	h = home

## The log and the seed beside the Training post (none without one); called when fixtures move.
func place() -> void:
	if is_instance_valid(log_node):
		log_node.queue_free()
	log_node = null
	if h.YARD_AT.x < -100.0:
		return
	log_node = Node3D.new()
	log_node.name = "VolleyLog"
	log_node.position = h.YARD_AT + LOG_OFF
	h.add_child(log_node)
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = LOG_R
	cm.bottom_radius = LOG_R
	cm.height = LOG_LEN
	trunk.mesh = cm
	trunk.material_override = BaseRace.mat(Color("7a5638"))
	trunk.rotation.x = PI * 0.5
	trunk.position.y = LOG_R
	log_node.add_child(trunk)
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
	log_node.add_child(seed_node)

func find(p2: Vector2) -> Dictionary:
	if run != null or not is_instance_valid(log_node):
		return {}
	if p2.distance_to(Vector2(log_node.position.x, log_node.position.z)) > REACH:
		return {}
	return {"kind": "volley"}

func label() -> String:
	return "Play Spark Volley (back %s)" % Save.active_kin().get("name", "your partner")

func use() -> void:
	var ks: Array = h.hrace.entrants()
	if ks.size() < 2:
		h._toast("Spark Volley needs two rested Boki out on the base")
		return
	pair = ks.slice(0, 2)
	for k in pair:
		k["busy"] = true
	var back := maxi(0, [pair[0]["rec"], pair[1]["rec"]].find(Save.active_kin()))
	run = Run.new([pair[0]["rec"], pair[1]["rec"]], back, RandomNumberGenerator.new())
	run.rng.randomize()
	bar = TimingBar.new()
	bar.open(h.root_ui, "Press %s once, with the marker in the gold, to call a spike" % Settings.key_cap("interact"))
	bar.lbl.text = "Call %s's spike" % run.recs[run.backed]["name"]
	seed_node.visible = true
	_place()
	Sfx.play("whoosh", null, -8.0)

## A press: true when the match took it.
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
		run.call_spike(r)
		bar.close()
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
		h._emote(pair[run.last_miss], "!", true)
		h._toast("%s %d : %d %s" % [run.recs[0]["name"], run.score[0], run.score[1], run.recs[1]["name"]])
	_place()
	if run.over():
		_end(true)

## The two players face each other across the log; the seed rides an arc between them.
func _place() -> void:
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var p: Vector3 = log_node.position + Vector3(0, 0, side * HALF)
		var g: float = h._ground_h(p.x, p.z)
		p.y = g if g > -50.0 else 0.0
		var n: Node3D = pair[i]["node"]
		n.position = p
		n.rotation.y = atan2(0.0, -side)
		pair[i]["pos"] = p
	seed_node.position = _seed_at()

## m along the court from the log toward a side (side 0 is on -z), k of the way to the player.
static func _side_z(side: int, k: float) -> float:
	return (-1.0 if side == 0 else 1.0) * HALF * k

## Where the seed is, relative to the log: held by the server before the serve, on an arc in flight,
## on the floor by whoever dropped it after a point.
func _seed_at() -> Vector3:
	if run.state == Run.S.FLIGHT:
		var u := 1.0 - clampf(run.fly_t / run.fly_total, 0.0, 1.0)
		var arc := ARC if run.hard >= 1.0 else SPIKE_ARC
		return Vector3(0, 0.5 + sin(u * PI) * arc, _side_z(run.hitter, 1.0 - 2.0 * u))
	if run.state == Run.S.POINT:
		return Vector3(0, SEED_R, _side_z(run.last_miss, 0.9))
	return Vector3(0, 0.6, _side_z(run.server, 1.0))

func _end(finished: bool) -> void:
	var res := settle(run) if finished else {}
	for k in pair:
		k["busy"] = false
		k["t"] = 1.5
	bar.close()
	seed_node.visible = false
	if finished:
		_card(res)
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
	card = BaseRace.result_card(h, [
		["%s wins Spark Volley, %d to %d!" % [win["name"], res["score"][0], res["score"][1]], 18, UI.ACCENT_HI],
		["%s is beaming (+joy, +trust)" % win["name"], 14, UI.INK],
		["%s sulks: \"lost Spark Volley to %s\"" % [lose["name"], win["name"]], 14, UI.MUTED],
		["+%d gems%s" % [res["gems"], why], 14, UI.GOLD]])
	card_t = float(rules()["card_s"])
