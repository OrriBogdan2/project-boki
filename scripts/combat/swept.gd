class_name Swept
extends RefCounted
## Swept hit tests (docs/decisions/0022-swept-hits.md). At 30 fps a 40 m/s shot or dash moves 1.3 m a frame,
## more than a Hunter is wide, so testing only where it ends up can skip a body or a thin wall. These test
## the segment from the last position to the new one. Shots already walk their segment in STEP slices
## (Match._update_shots); dashes use these.

const STEP := 0.25        # m between terrain samples along a segment (a block is 1 m, a body 0.8 m)

## Flat (x, z) distance from `p` to the segment a..b.
static func dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), Vector2(a.x, a.z), Vector2(b.x, b.z))
	return Vector2(p.x - q.x, p.z - q.y).length()

## `b`, or the last open point on the way to it when a block that is taller than `a`'s feet is in the way.
static func clip(w: World, a: Vector3, b: Vector3) -> Vector3:
	var n := int(ceil(a.distance_to(b) / STEP))
	var last := a
	for i in range(1, n + 1):
		var p := a.lerp(b, float(i) / n)
		if w.is_block(p.x, p.z) and w.ground_at(p.x, p.z) + World.BLOCK_H > a.y + World.STEP:
			return last
		last = p
	return b
