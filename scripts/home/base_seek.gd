class_name BaseSeek
extends RefCounted
## Seek (briefs/design/GARDEN.md section 5.3), the Boki base's third minigame; only with farm_build.json
## base_mode on. Take the scent from the basket by the Training post, carry it anywhere on the base and
## hide it there: where you hide it is your whole input. Two rested Boki (your partner and the next one)
## then hunt for it. A hunter walks at a speed set by Focus and sniffs every sniff_s seconds; how often a
## sniff points the right way comes from Focus and curiosity, and at night Spore and Dark Boki (and the
## nocturnal species) sniff better. Friends hunt as a pair (a friend's good sniff helps), rivals shoulder
## each other. The winner gains joy, trust and you a few gems; the loser sulks and remembers.
## Tuning: content/rules/base_seek.json. The hunt itself (Hunt) has no nodes, so --seek-check runs it headless.
##
## The flow is one explicit state machine (briefs/STATE_MACHINES.md): only go() writes `state`, and a move
## the TABLE lacks is refused and counted.
##   IDLE   -> CARRY   use at the basket: you hold the scent
##   CARRY  -> HUNT    use anywhere free: the scent is hidden there and the pair set off
##          -> IDLE    menu: you put it back
##   HUNT   -> RESULT  one hunter finds it (or time runs out): the result card shows
##          -> IDLE    menu: the hunt is called off
##   RESULT -> IDLE    the card's time is up

enum S { IDLE, CARRY, HUNT, RESULT }
const TABLE := {S.IDLE: [S.CARRY], S.CARRY: [S.IDLE, S.HUNT], S.HUNT: [S.RESULT, S.IDLE], S.RESULT: [S.IDLE]}

const BASKET_OFF := Vector3(0.0, 0, 2.6)     # m from the Training post to the scent basket
const BASKET_R := 0.28                        # m, the basket's radius
const BASKET_H := 0.3                         # m, its height
const SCENT_R := 0.14                         # m, the hidden scent's glow
const REACH := 1.6                            # m from the basket to pick the scent up
const TURN := 6.0                             # rad/s a hunter turns to its heading

static func rules() -> Dictionary:
	return Content.rules("base_seek")

static func theme(rec: Dictionary) -> String:
	return String(Data.KIN.get(String(rec.get("species", "")), {}).get("theme", ""))

## Does the dark favour this Boki (a Spore or Dark type, or a nocturnal species)?
static func night_type(rec: Dictionary) -> bool:
	return rules()["night_themes"].has(theme(rec)) or Work.NOCTURNAL.has(String(rec.get("species", "")))

## m/s: from Focus.
static func speed(rec: Dictionary) -> float:
	var R := rules()
	return float(R["speed"]) * (1.0 + float(rec.get("stats", {}).get("focus", 0)) * float(R["speed_per_focus"]))

## The chance a sniff points the right way: Focus, curiosity, and the night for night types.
static func right_p(rec: Dictionary, night: bool) -> float:
	var R := rules()
	var p := float(R["right"]) + float(rec.get("stats", {}).get("focus", 0)) * float(R["right_per_focus"])
	p += (float(rec.get("traits", {}).get("curiosity", 0.5)) - 0.5) * float(R["curiosity_gain"])
	if night and night_type(rec):
		p += float(R["night_right"])
	return clampf(p, float(R["right_min"]), float(R["right_max"]))

## The hunt itself: two hunters on the ground plane (x, z in metres) after a scent.
class Hunt:
	var R: Dictionary
	var recs: Array                 # two records: a (index 0) and b (index 1)
	var item: Vector2               # where the scent is hidden
	var pos: Array = []             # each hunter's position
	var head: Array = []            # each hunter's heading (unit vector)
	var sniff_t: Array = [0.0, 0.0] # s until each hunter's next sniff
	var right: Array = [false, false]   # each hunter's last sniff pointed the right way
	var night: bool
	var rng: RandomNumberGenerator
	var can_walk: Callable          # (Vector2) -> bool: is this ground walkable (empty: everywhere)
	var t := 0.0
	var found := -1                 # index of the hunter that reached it, -1 while nobody has

	func _init(pair: Array, starts: Array, at: Vector2, is_night: bool, r: RandomNumberGenerator,
			walk := Callable()) -> void:
		R = BaseSeek.rules()
		recs = pair
		item = at
		night = is_night
		rng = r
		can_walk = walk
		for i in 2:
			pos.append(starts[i])
			head.append(Vector2.RIGHT)

	func friends() -> bool:
		return BaseRace.bond(recs[0], recs[1]) >= float(BaseRace.rules()["friend_at"])

	func rivals() -> bool:
		return BaseRace.bond(recs[0], recs[1]) <= float(BaseRace.rules()["rival_at"])

	func over() -> bool:
		return found >= 0 or t >= float(R["max_s"])

	## 0 or 1: who found it, else who is nearer (a on a dead level).
	func winner() -> int:
		if found >= 0:
			return found
		return 0 if pos[0].distance_to(item) <= pos[1].distance_to(item) else 1

	func _sniff(i: int) -> void:
		sniff_t[i] = float(R["sniff_s"])
		var p := BaseSeek.right_p(recs[i], night)
		if friends() and right[1 - i]:
			p = minf(p + float(R["friend_share"]), float(R["right_max"]))
		right[i] = rng.randf() < p
		var aim: float = (item - pos[i]).angle() + rng.randf_range(-float(R["aim"]), float(R["aim"]))
		head[i] = Vector2.from_angle(aim if right[i] else rng.randf_range(0.0, TAU))

	func step(dt: float) -> void:
		t += dt
		var rate: Array = [BaseSeek.speed(recs[0]), BaseSeek.speed(recs[1])]
		if rivals() and pos[0].distance_to(pos[1]) < float(R["rival_near"]):
			rate[0 if rate[0] < rate[1] else 1] *= float(R["rival_slow"])
		for i in 2:
			sniff_t[i] -= dt
			if sniff_t[i] <= 0.0:
				_sniff(i)
			var to: Vector2 = pos[i] + head[i] * float(rate[i]) * dt
			if can_walk.is_null() or can_walk.call(to):
				pos[i] = to
			else:
				sniff_t[i] = 0.0                     # blocked: sniff again at once
		var best := -1
		var best_d := float(R["find_r"])
		for i in 2:
			var d: float = pos[i].distance_to(item)
			if d < best_d:
				best = i
				best_d = d
		found = best

## Pays out a finished hunt: joy, trust, memories, energy, gems, bonds. Returns what the card shows.
static func settle(hunt: Hunt) -> Dictionary:
	var R := rules()
	var win: Dictionary = hunt.recs[hunt.winner()]
	var lose: Dictionary = hunt.recs[1 - hunt.winner()]
	var friends := hunt.friends()
	for rec in hunt.recs:
		Care.change(rec, "energy", -float(R["energy"]))
	Care.change(win, "joy", float(R["win_joy"]))
	Care.change(lose, "joy", float(R["lose_joy"]) * (float(R["friend_sulk"]) if friends else 1.0))
	Save.remember(win, "seek", "sniffed out the scent before %s" % lose["name"], float(R["win_trust"]))
	Save.remember(lose, "seek", "lost the Seek to %s" % win["name"])
	var step := float(BaseRace.rules()["friend_step"]) if friends else -float(BaseRace.rules()["rival_step"])
	BaseRace.nudge_bond(win, lose, step)
	Save.d["gems"] = int(Save.d["gems"]) + int(R["gems"])
	return {"win": win, "lose": lose, "gems": int(R["gems"]), "friends": friends}

# ------------------------------------------------------------------ on the base
var h                          # the Home screen
var state := S.IDLE
var refused := 0               # moves the TABLE turned down
var state_t := 0.0             # s in the state
var basket: Node3D = null
var scent: MeshInstance3D = null
var hunt: Hunt = null
var pair: Array = []           # the home's kin entries: a, b
var card: Control = null

func _init(home) -> void:
	h = home

## The only writer of `state`: false (and counted) when the TABLE lacks the move.
func go(to: S) -> bool:
	if not TABLE[state].has(to):
		refused += 1
		return false
	state = to
	state_t = 0.0
	return true

## The scent basket beside the Training post (none without one); called when fixtures move.
func place() -> void:
	if is_instance_valid(basket):
		basket.queue_free()
	basket = null
	if h.YARD_AT.x < -100.0:
		return
	basket = Node3D.new()
	basket.name = "ScentBasket"
	basket.position = h.YARD_AT + BASKET_OFF
	h.add_child(basket)
	var cup := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = BASKET_R
	cm.bottom_radius = BASKET_R * 0.8
	cm.height = BASKET_H
	cup.mesh = cm
	cup.material_override = BaseRace.mat(Color("a8844f"))
	cup.position.y = BASKET_H * 0.5
	basket.add_child(cup)
	basket.add_child(_glow(Vector3(0, BASKET_H + SCENT_R * 0.5, 0)))

func _glow(at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = SCENT_R
	sm.height = SCENT_R * 2.0
	m.mesh = sm
	m.material_override = BaseRace.mat(Color("f2a8e8"))
	m.position = at
	return m

func find(p2: Vector2) -> Dictionary:
	match state:
		S.IDLE:
			if is_instance_valid(basket) and p2.distance_to(Vector2(basket.position.x, basket.position.z)) <= REACH:
				return {"kind": "seek"}
		S.CARRY:
			return {"kind": "seek"}
	return {}

func label() -> String:
	if state == S.CARRY:
		return "Hide the scent here"
	return "Take the scent to hide (%s and the next Boki will hunt it)" % Save.active_kin().get("name", "your partner")

func use() -> void:
	if state == S.IDLE:
		if h.hrace.entrants().size() < 2:
			h._toast("Seek needs two rested Boki out on the base")
			return
		go(S.CARRY)
		h._toast("You hold the scent: walk anywhere on the base and hide it")
	elif state == S.CARRY:
		_hide(Vector2(h.ppos.x, h.ppos.z))

func _hide(at: Vector2) -> void:
	var ks: Array = h.hrace.entrants()
	if ks.size() < 2:
		h._toast("Seek needs two rested Boki out on the base")
		go(S.IDLE)
		return
	pair = ks.slice(0, 2)
	var starts: Array = []
	for k in pair:
		starts.append(Vector2(k["pos"].x, k["pos"].z))
	if at.distance_to(starts[0]) < float(rules()["min_hide"]) or at.distance_to(starts[1]) < float(rules()["min_hide"]):
		h._toast("Too close: hide it farther from your Boki")
		pair = []
		return
	go(S.HUNT)
	for k in pair:
		k["busy"] = true
	hunt = Hunt.new([pair[0]["rec"], pair[1]["rec"]], starts, at, HomeWork.is_night(h.day_t),
			RandomNumberGenerator.new(), _walkable)
	hunt.rng.randomize()
	scent = _glow(Vector3(at.x, _ground(at) + SCENT_R, at.y))
	h.add_child(scent)
	Sfx.play("whoosh", null, -8.0)

func _walkable(p: Vector2) -> bool:
	return h._ground_h(p.x, p.y) > -50.0

func _ground(p: Vector2) -> float:
	var g: float = h._ground_h(p.x, p.y)
	return g if g > -50.0 else 0.0

## True when the hunt took the key (menu calls it off, or puts the scent back).
func input(event: InputEvent) -> bool:
	if state != S.CARRY and state != S.HUNT:
		return false
	if not event.is_action_pressed("menu"):
		return false
	if state == S.HUNT:
		_end(false)
	else:
		go(S.IDLE)
	return true

func tick(d: float) -> void:
	state_t += d
	match state:
		S.HUNT:
			hunt.step(d)
			_move_pair(d)
			if hunt.over():
				_end(true)
		S.RESULT:
			if state_t >= float(rules()["card_s"]):
				if is_instance_valid(card):
					card.queue_free()
				go(S.IDLE)

func _move_pair(d: float) -> void:
	for i in 2:
		var n: Node3D = pair[i]["node"]
		var p: Vector2 = hunt.pos[i]
		n.position = Vector3(p.x, _ground(p), p.y)
		var want := atan2(hunt.head[i].x, hunt.head[i].y)
		n.rotation.y = lerp_angle(n.rotation.y, want, minf(1.0, TURN * d))
		pair[i]["pos"] = n.position

func _end(finished: bool) -> void:
	var res := settle(hunt) if finished else {}
	for k in pair:
		k["busy"] = false
		k["t"] = 1.5
	if is_instance_valid(scent):
		scent.queue_free()
	if finished:
		go(S.RESULT)
		_card(res)
		h._emote(h._kin_entry(res["win"]), "♥", true)
		h._emote(h._kin_entry(res["lose"]), "…", true)
		Save.save_game()
	else:
		go(S.IDLE)
	hunt = null
	pair = []

func _card(res: Dictionary) -> void:
	var win: Dictionary = res["win"]
	var lose: Dictionary = res["lose"]
	var sulk := "%s is a good sport" if res["friends"] else "%s sulks"
	if is_instance_valid(card):
		card.queue_free()
	card = BaseRace.result_card(h, [
		["%s sniffs out the scent!" % win["name"], 18, UI.ACCENT_HI],
		["%s is beaming (+joy, +trust)" % win["name"], 14, UI.INK],
		[(sulk % lose["name"]) + ": \"lost the Seek to %s\"" % win["name"], 14, UI.MUTED],
		["+%d gems" % res["gems"], 14, UI.GOLD]])
