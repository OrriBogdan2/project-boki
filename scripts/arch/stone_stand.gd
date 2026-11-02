class_name StoneStand
extends RefCounted
## Low walls you can stand on and climb (Breah's rocks; any Verbs wall with a "top" height in metres).
## The owner's rule: raised rocks give verticality. Three pieces, all small:
##   - Verbs.wall_blocks lets a body whose feet are at the top walk over it (and blocks below it at
##     the rock's own height, so the hop and ledge numbers stay honest);
##   - Ent.ground() reads top_under(), so a body over a rock lands and stands on it;
##   - Hunter's move step calls climb(): jumping into a rock face carries you up onto it (the same
##     feel as the rock-tile hop: you must be rising and pushing into it).
## Walking off the top drops you (the ground falls away like any ledge). A launched or broken rock is
## removed from Verbs.walls, so whoever stood on it falls.

const CLIMB_MAX := 1.75        # m: how far below the top you can still climb it from a jump
const LAND_SLACK := 0.6        # m: a body this far under the top while falling still lands on it
const FOOT_K := 0.55           # share of the body radius that must be over the rock to stand on it

## The ground height under a body at p: g, or the top of a standable wall under its feet when higher.
static func top_under(list: Array, p: Vector3, r: float, g: float) -> float:
	if list.is_empty():
		return g
	var p2 := Vector2(p.x, p.z)
	for w in list:
		if not w.has("top"):
			continue
		var top := float(w["y"]) + float(w["top"])
		if top <= g or p.y < top - LAND_SLACK:
			continue
		var c := Geometry2D.get_closest_point_to_segment(p2, w["a"], w["b"])
		if p2.distance_to(c) < float(w["th"]) + r * FOOT_K:
			g = top
	return g

## The standable wall a body at p is pressing into at height `blk` (occupy's answer), or {}.
static func face(list: Array, p: Vector3, r: float, blk: float) -> Dictionary:
	var p2 := Vector2(p.x, p.z)
	for w in list:
		if not w.has("top") or absf(float(w["y"]) + float(w["top"]) - blk) > 0.05:
			continue
		var c := Geometry2D.get_closest_point_to_segment(p2, w["a"], w["b"])
		if p2.distance_to(c) < r + float(w["th"]) + 0.35:
			return w
	return {}

## A jump into a rock's face lifts you onto its top. blk: the height occupy() reported this step.
static func climb(h: Hunter, blk: float) -> bool:
	if blk <= 0.0 or h.grounded or h.dropping or h.vel.y <= 0.3 or h.mantle_cd > 0.0:
		return false
	var rise := blk - h.pos.y
	if rise <= 0.0 or rise > CLIMB_MAX:
		return false
	if face(h.m.world.dyn_walls, h.pos, h.r, blk).is_empty():
		return false
	h.vel.y = maxf(h.vel.y, sqrt(2.0 * Hunter.H_GRAV * (rise + 0.3)))
	h.mantle_cd = 0.45
	return true
