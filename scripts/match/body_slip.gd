class_name BodySlip
extends RefCounted
## Getting a body unstuck from the map's walls: round a terrace corner the axis moves can't pass, and
## out of a wall or prop the body ended up inside. Hunter's corner slip uses both (docs/MOVEMENT_FEEL.md,
## snag audit).

const EJECT_RINGS := 15        # rings of 0.1 m: eject looks this far out (1.5 m)
const ROUND_SKIN := 0.01       # m: a rounded body ends this far off the wall, so the spot it gives is free

## Where a body of radius r with feet at y at `from`, wanting to move by `step`, gets to round a terrace
## corner: running or gliding at one, the corner pokes in between the body's wall samples and meets both
## axis moves, so the body sat on it. Out of the corner first, then the step pushed out of the walls, the
## way a round body slides round; `from` when that doesn't go the step's way.
static func round_corner(w: World, from: Vector2, step: Vector2, r: float, y: float) -> Vector2:
	var out := _out_of_walls(w, from, r, y)
	var to := _out_of_walls(w, out + step, r, y)
	return to if (to - out).dot(step) > 0.0 else from

## p pushed straight out of the terrain walls (tiles whose top is over y + World.STEP) a circle of radius r
## there overlaps.
static func _out_of_walls(w: World, p: Vector2, r: float, y: float) -> Vector2:
	for tz in range(int(floor(p.y - r)), int(floor(p.y + r)) + 1):
		for tx in range(int(floor(p.x - r)), int(floor(p.x + r)) + 1):
			if not w.inb(tx, tz) or w.kind[w.idx(tx, tz)] == World.T_VOID:
				continue
			if w.level[w.idx(tx, tz)] * World.LEVEL <= y + World.STEP:
				continue
			var d := p - Vector2(clampf(p.x, tx, tx + 1.0), clampf(p.y, tz, tz + 1.0))
			if d.length() < r and d.length() > 0.0001:
				p += d.normalized() * (r + ROUND_SKIN - d.length())
	return p

## The nearest spot to (x, z) where a body of radius r with feet at y is free of walls and props: a body
## that dropped past a terrace edge or glided down into a prop is inside one, and every step it tries is
## blocked. Rings of 0.1 m out to 1.5 m; the spot itself when nothing near is free.
static func eject(w: World, x: float, z: float, r: float, y: float) -> Vector2:
	for ring in range(1, EJECT_RINGS + 1):
		for k in 16:
			var a := TAU * k / 16.0
			var q := Vector2(x + cos(a) * ring * 0.1, z + sin(a) * ring * 0.1)
			if w.occupy(q.x, q.y, r, y, false) == 0.0:
				return q
	return Vector2(x, z)
