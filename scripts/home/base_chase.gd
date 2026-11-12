class_name BaseChase
extends RefCounted
## Friend chase (BaseLife, content/rules/garden_sim.json "chase"): two friends play a toy-free tag in the PLAY_WITH
## state. The more outgoing one (pers.social) starts as the chaser; the runner flees to spots the zone's ground
## allows (never off the island, never through deep water unless it paddles: BokiWade); a catch swaps the roles
## (the new runner hops); both run at a pace that grows with their Speed stat; after secs seconds they lie down
## side by side. One chase at a time per zone (per_zone). k["life_chase"] marks a Boki in one, k["life_it"] the
## chaser, k["tag_pace"] its run scale (home.gd _move_kin), k["chase_leg"] s the chaser has been after the runner.

const DIRS := [0.0, 0.785, -0.785, 1.571, -1.571, 2.356, -2.356, 3.1416]      # rad off "straight away"
const STEP_M := 1.0      # m between ground samples along a flee line

static func rules() -> Dictionary:
	return Content.rules("garden_sim")["chase"]

## Takes the chase marks off a Boki (BaseLife: leaving PLAY_WITH).
static func clear(k: Dictionary) -> void:
	for key in ["life_chase", "life_it", "tag_pace", "chase_leg", "chase_goal"]:
		k.erase(key)

## Chases running in this zone (one chaser each).
static func running(life: BaseLife) -> int:
	return life.h.kins.filter(func(k): return k.has("life_chase") and k.has("life_it")).size()

## The friend `k` starts a chase with, or {} (not outgoing enough, no free friend near, or the zone is at its cap).
static func pick(life: BaseLife, k: Dictionary, near: Array) -> Dictionary:
	if running(life) >= int(rules()["per_zone"]):
		return {}
	var social := float(k["pers"].get("social", 0.22))
	for o in near:
		var friends := BaseLife.bond(k["rec"], o["rec"]) >= float(life.R["friend_at"])
		var loose := (o["life"] as Fsm).is_in(BaseLife.S.ROAM) and not o.has("play")
		if friends and loose and social >= float(o["pers"].get("social", 0.22)) and randf() < social:
			return o
	return {}

## `k` starts chasing `o`: both go to PLAY_WITH for secs seconds. False when a machine refuses.
static func begin(life: BaseLife, k: Dictionary, o: Dictionary) -> bool:
	var m := life.machine(k)
	var om := life.machine(o)
	if not m.can(BaseLife.S.PLAY_WITH) or not om.can(BaseLife.S.PLAY_WITH):
		return false
	m.go(BaseLife.S.PLAY_WITH, "chase")
	om.go(BaseLife.S.PLAY_WITH, "chased")
	var secs := randf_range(rules()["secs"][0], rules()["secs"][1])
	for pair in [[k, o], [o, k]]:
		pair[0]["life_at"] = pair[1]
		pair[0]["life_for"] = secs
		pair[0]["t"] = secs
		pair[0]["life_chase"] = true
	_roles(k, o)
	life.h._emote(k, "★")
	return true

## `k` is the chaser, `o` the runner: their paces (Speed stat; the runner is a little slower) and the leg clock.
static func _roles(k: Dictionary, o: Dictionary) -> void:
	k["life_it"] = true
	o.erase("life_it")
	k["tag_pace"] = _pace(k["rec"], 1.0)
	o["tag_pace"] = _pace(o["rec"], float(rules()["flee_mul"]))
	k["chase_leg"] = 0.0
	o.erase("chase_leg")

static func _pace(rec: Dictionary, share: float) -> float:
	var R := rules()
	var speed := clampf(float(rec["stats"]["speed"]) / float(maxi(Care.stat_cap(rec), 1)), 0.0, 1.0)
	return float(R["run"]) * (1.0 + float(R["speed_gain"]) * speed) * share

## One 10 Hz step for `k`: the chaser runs at the runner and tags it on contact; the runner flees.
static func tick(life: BaseLife, k: Dictionary, m: Fsm, dt: float) -> void:
	var o: Dictionary = k["life_at"]
	var om: Fsm = o.get("life", null)
	if om == null or not om.is_in(BaseLife.S.PLAY_WITH) or BaseLife._taken(o):
		m.go(BaseLife.S.ROAM, "chase over")
		return
	if m.since >= float(k["life_for"]):
		_rest(life, k, o)
		return
	if k.has("life_it"):
		k["chase_leg"] = float(k["chase_leg"]) + dt
		k["goal"] = o["pos"]
		if BaseLife._dist(k, o) < BaseLife.CATCH:
			_swap(life, k, o)
	else:
		_flee(life, k, o)

static func _swap(life: BaseLife, k: Dictionary, o: Dictionary) -> void:
	BaseLife.add_bond(k["rec"], o["rec"], float(life.R["bond_tag"]))
	_roles(o, k)
	o["goal"] = o["pos"]
	for who in [k, o]:
		who["joy_t"] = float(rules()["hop_s"])      # the rig's hop: there is no tag clip
		who.erase("chase_goal")
	life.h._emote(o, "★")

## The runner heads for the first clear spot flee_m m off, turning from straight away from the chaser; it stops
## to be caught once the chaser has been after it for leg_s seconds.
static func _flee(life: BaseLife, k: Dictionary, it: Dictionary) -> void:
	if float(it["chase_leg"]) > float(rules()["leg_s"]):
		k["goal"] = k["pos"]
		return
	var goal: Vector3 = k.get("chase_goal", Vector3.INF)
	if goal != Vector3.INF and BaseLife._dist(k, {"pos": goal}) > 1.0 and _clear(life, k, goal):
		k["goal"] = goal
		return
	var away: Vector3 = (k["pos"] - it["pos"]) * Vector3(1, 0, 1)
	away = away.normalized() if away.length() > 0.01 else Vector3.RIGHT
	for turn in DIRS:
		var to: Vector3 = k["pos"] + away.rotated(Vector3.UP, turn) * float(rules()["flee_m"])
		if _clear(life, k, to):
			k["chase_goal"] = to
			k["goal"] = to
			return
	k["goal"] = k["pos"]

## Can `k` walk the straight line to `to` on this zone's ground: same island, no void, deep water only if it paddles.
static func _clear(life: BaseLife, k: Dictionary, to: Vector3) -> bool:
	var from: Vector3 = k["pos"]
	var island: int = life.h.world.island_of(from.x, from.z)
	var swims: bool = life.h.wade.kind(k["rec"]) == "paddle"
	var steps := ceili(from.distance_to(to) / STEP_M)
	for i in range(1, steps + 1):
		var p := from.lerp(to, float(i) / float(steps))
		if life.h.world.is_void(p.x, p.z) or life.h.world.island_of(p.x, p.z) != island \
				or (not swims and life.h.water.depth(p.x, p.z) > 1):
			return false
	return true

## Time's up: the chaser lies down where it is and the runner comes to lie beside it.
static func _rest(life: BaseLife, k: Dictionary, o: Dictionary) -> void:
	var chaser: Dictionary = k if k.has("life_it") else o
	var runner: Dictionary = o if k.has("life_it") else k
	life._nap(chaser, "chase over")
	if life.machine(runner).go(BaseLife.S.NAP, "chase over"):
		runner["life_pile"] = chaser
		runner["t"] = BaseLife.PILE_WALK
