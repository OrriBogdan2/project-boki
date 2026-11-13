class_name BaseRival
extends RefCounted
## The farm's rivalry beat (GARDEN.md section 4, DECISIONS 11-09): two free roaming rivals (BaseLife bond at or
## below rival_at) that pass within pass_m turn to face each other, huff, and walk on (BaseLife's React state,
## the growl pose, the garden huff sound). Rivals never play tag together (BaseLife._mate). A garden game two
## Boki win together raises their bond (won_together), so a rivalry can turn into a friendship over days.
## Numbers: content/rules/garden_sim.json "rivalry".

static func rules() -> Dictionary:
	return Content.rules("garden_sim")["rivalry"]

## Counts a Boki's pair cooldown down (10 Hz, from BaseLife._tick).
static func cool(k: Dictionary, dt: float) -> void:
	if k.has("rival_cd"):
		k["rival_cd"] = float(k["rival_cd"]) - dt
		if float(k["rival_cd"]) <= 0.0:
			k.erase("rival_cd")

## k is roaming: starts the beat with the first free rival that is close enough. True when it began.
static func pass_by(life: BaseLife, k: Dictionary) -> bool:
	if k.has("rival_cd"):
		return false
	var R := rules()
	for o in life.h.kins:
		if o == k or not o.has("life") or o.has("rival_cd") or BaseLife._taken(o):
			continue
		var rivals := BaseLife.bond(k["rec"], o["rec"]) <= float(life.R["rival_at"])
		var here: int = life.h.world.island_of(k["pos"].x, k["pos"].z)
		if rivals and BaseLife._dist(k, o) < float(R["pass_m"]) and life.machine(o).is_in(BaseLife.S.ROAM) \
				and life.h.world.island_of(o["pos"].x, o["pos"].z) == here:
			_turn(life, k, o)
			_turn(life, o, k)
			return true
	return false

static func _turn(life: BaseLife, k: Dictionary, at: Dictionary) -> void:
	if not life.machine(k).go(BaseLife.S.REACT, "rival pass"):
		return
	var R := rules()
	k["life_at"] = at
	k["life_rival"] = true
	k["life_for"] = float(R["beat_s"])
	k["t"] = float(k["life_for"])
	k["rival_cd"] = float(R["cooldown_s"])
	k["huff_t"] = HomeToys.HUFF_SECS
	life._huff(k)
	GardenSfx.huff(k["rec"], k["pos"])

## The beat is over: it walks on, away from the other Boki.
static func walk_on(life: BaseLife, k: Dictionary, at: Dictionary) -> void:
	var R := rules()
	var off := Vector3(k["pos"].x - at["pos"].x, 0, k["pos"].z - at["pos"].z).normalized()
	var away: Vector3 = k["pos"] + off * float(R["walk_m"])
	if not life.h.world.is_void(away.x, away.z):
		k["goal"] = away
	k["t"] = float(R["walk_s"])

## A garden game these Boki won together: each pair's bond rises by win_step.
static func won_together(team: Array) -> void:
	for i in team.size():
		for j in range(i + 1, team.size()):
			BaseLife.add_bond(team[i], team[j], float(rules()["win_step"]))
