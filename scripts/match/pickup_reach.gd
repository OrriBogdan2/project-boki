class_name PickupReach
extends RefCounted
## Ground pickup reach (content/rules/pickup.json): how far a walk-over pickup flies to you, how
## close you stand to take gear with the interact key, which of several the key takes (the one
## nearest the cursor), and that no wall stands between you and any of them.

const EYE := 1.0      # m above the feet the line to a pickup runs at: a one-terrace step hides nothing, a rock does

static func rules() -> Dictionary:
	return Content.rules("pickup")

## Seconds a dropped pickup lies before anyone can take it, so it is seen to land.
static func settle() -> float:
	return float(rules()["walk"]["settle"])

## Is `at` within `rule`'s reach of the hunter: inside its radius and height, with nothing in the way.
static func near(m: Match, h: Hunter, at: Vector3, rule: String) -> bool:
	var r: Dictionary = rules()[rule]
	if h.flat_dist(at) >= float(r["radius"]) or absf(h.pos.y - at.y) >= float(r["height"]):
		return false
	return clear(m, h, at)

## No rock, higher ground or kit wall between the hunter and the thing. A thing lying inside a rock's
## own cell is reached from any side, so loot that bounced into one is never stranded.
static func clear(m: Match, h: Hunter, at: Vector3) -> bool:
	if m.world.is_block(at.x, at.z):
		return true
	return m.world.los(h.pos, at, h.pos.y + EYE)

## The speed a walk-over pickup flies at the hunter's chest: faster the closer it is.
static func pull(h: Hunter, at: Vector3) -> Vector3:
	var r: Dictionary = rules()["walk"]
	var dir := _chest(h, r) - at
	return dir.normalized() * (float(r["pull_speed"]) + (float(r["radius"]) - h.flat_dist(at)) * float(r["pull_gain"]))

## Has a walk-over pickup reached the hunter's body?
static func grabbed(h: Hunter, at: Vector3) -> bool:
	var r: Dictionary = rules()["walk"]
	return (_chest(h, r) - at).length() < float(r["grab"])

## The ground item the interact key takes: of the gear (and, for the player, treasure) in reach, the
## one nearest the cursor. Tunings are taken by walking over them.
static func under_cursor(m: Match, h: Hunter) -> Dictionary:
	var aim: Vector3 = h.inp["aim"] if h == m.player else h.pos
	var best := {}
	var best_d := INF
	for wp in m.wpicks:
		if wp.has("tune") or (wp.has("val") and h != m.player):
			continue
		if not near(m, h, wp["pos"], "interact"):
			continue
		var d: float = Vector2(aim.x - wp["pos"].x, aim.z - wp["pos"].z).length()
		if d < best_d:
			best_d = d
			best = wp
	return best

static func _chest(h: Hunter, r: Dictionary) -> Vector3:
	return h.pos + Vector3(0, float(r["grab"]), 0)
