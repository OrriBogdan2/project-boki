class_name KnockWall
extends RefCounted
## "Driven into a wall": the one test every wall stun asks (Heavy Shot's pin, the Crush, Burr's cone, Tenzo's
## punch, the Storm Rod and a plain knock's slam). A wall is whatever stops a knocked body's walk and stands
## taller than a terrace step: terrain cliffs, rocks, trees, placed barriers, the train's engine. Ground it
## walks up, a flat car deck and the soft props (crates, pots, barrels, kegs) are not walls. What counts and
## why: docs/KNOCK_WALLS.md. Checked by --wall-stun-check.

# m: a body walks up a rise this tall (the Hunter's step-up); anything higher is a wall
const RISE := World.LEVEL + 0.05
const STRIDE := 0.3                   # m between the probe points along the knock

## A wall within `reach` m of the body's edge, straight along `dir`.
static func behind(m: Match, e: Ent, dir: Vector2, reach: float) -> bool:
	var k := STRIDE
	while k <= reach:
		var q := e.pos + Vector3(dir.x, 0, dir.y) * k
		if tall(m, e, _top_at(m, q, e)):
			return true
		k += STRIDE
	return false

## The body is stopped by something whose top is at `top`, and that is a wall to it (not a step up).
static func tall(m: Match, e: Ent, top: float) -> bool:
	# (a knock lifts it: measure from the floor)
	var feet := maxf(m.world.ground_at(e.pos.x, e.pos.z), e.pos.y - RISE)
	return top > feet + RISE

static func _top_at(m: Match, q: Vector3, e: Ent) -> float:
	var top := m.world.occupy(q.x, q.z, e.r, e.pos.y, false)
	if m.skytrain != null:
		top = maxf(top, m.skytrain.solid_at(q.x, q.z, e.pos.y, e.r))
	return top
