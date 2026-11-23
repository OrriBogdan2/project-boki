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

const CHEST := 0.9                    # m above the feet where the decal goes
const NONE := Vector3.INF             # "no wall" from contact()

## A wall within `reach` m of the body's edge, straight along `dir`.
static func behind(m: Match, e: Ent, dir: Vector2, reach: float) -> bool:
	return contact(m, e, dir, reach) != NONE

## About to stun `e` against a wall: true if one stands within `reach` m along `dir`, and then says where it
## was hit (CombatBus.wall_stunned: the decal and puff in WallImpact). `by` is whoever drove it there.
static func hit(m: Match, e: Ent, dir: Vector2, reach: float, by: Node) -> bool:
	var at := contact(m, e, dir, reach)
	if at == NONE:
		return false
	announce(e, at, dir, by)
	return true

## The body is already against a wall (its slam): say so at its edge, along `dir`.
static func slammed(e: Ent, dir: Vector2, by: Node) -> void:
	announce(e, e.pos + Vector3(dir.x, 0, dir.y) * e.r, dir, by)

static func announce(e: Ent, at: Vector3, dir: Vector2, by: Node) -> void:
	CombatBus.wall_stunned.emit(e, at + Vector3(0, CHEST, 0), Vector3(-dir.x, 0, -dir.y), by)

## Where the body's edge first touches a wall within `reach` along `dir` (at the feet), else NONE.
static func contact(m: Match, e: Ent, dir: Vector2, reach: float) -> Vector3:
	var step := Vector3(dir.x, 0, dir.y)
	var k := STRIDE
	while k <= reach:
		if tall(m, e, _top_at(m, e.pos + step * k, e)):
			var lo := k - STRIDE
			for _i in 4:
				var mid := (lo + k) * 0.5
				if tall(m, e, _top_at(m, e.pos + step * mid, e)):
					k = mid
				else:
					lo = mid
			return e.pos + step * (k + e.r)
		k += STRIDE
	return NONE

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
