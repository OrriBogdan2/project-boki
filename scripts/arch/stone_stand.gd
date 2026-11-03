class_name StoneStand
extends RefCounted
## Low walls you can stand on (Breah's rocks; any Verbs wall with a "top" height in metres). Only the
## rock's own caster climbs it (docs/heroes/dolm.md, Rock ownership): walking into her own rock
## lifts her smoothly onto it, no jump needed, and she walks over the top. For everyone else a rock is a
## full wall: no climbing, no jumping over it. Anyone dropped onto a rock from above stands on it and can
## walk off. Pieces:
##   - Verbs.wall_blocks asks top_for(): the rock's top for its caster (and for a body standing on it), a
##     full wall for anyone else; Hunter's move step sets `mover` so the rule knows who is asking;
##   - Ent.ground() reads top_under(), so a body over a rock lands and stands on it;
##   - Hunter's move step calls climb(): the caster pushing into her own rock rises onto it.
## Walking off the top drops you (the ground falls away like any ledge). A launched or broken rock is
## removed from Verbs.walls, so whoever stood on it falls.

const CLIMB_MAX := 1.75        # m: how far below the top you can still climb it from a jump
const LAND_SLACK := 0.6        # m: a body this far under the top while falling still lands on it
const FOOT_K := 0.55           # share of the body radius that must be over the rock to stand on it
const RISE_V := 5.0            # m/s: the caster's lift up her own rock's face (1.25m in about a quarter second)
const CARRY_K := 0.9          # share of her run speed kept pressing into the face while she rises
const ON_TOP := 0.05           # m: feet this close to the top count as standing on it

## The hunter whose move step is asking World.occupy (set and cleared around it by Hunter); null for any
## other query (bot paths, ability probes), which treat rocks as full walls.
static var mover: Hunter = null

## The height a standable wall blocks the current mover up to: its top for the rock's own caster and for a
## body already standing on it, else the full Verbs wall height (nobody else climbs or jumps over it).
static func top_for(w: Dictionary) -> float:
	var top := float(w["top"])
	if mover == null:
		return Verbs.WALL_H
	if w.get("by") == mover:
		return top
	if mover.grounded and mover.pos.y >= float(w["y"]) + top - ON_TOP:
		return top
	return Verbs.WALL_H

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

## The caster pushing into her own rock's face rises onto its top: a steady lift, from the ground with no
## jump or from a jump. blk: the height occupy() reported this step. Anyone else's rock never lifts you.
static func climb(h: Hunter, blk: float) -> bool:
	if blk <= 0.0 or h.dropping or h.vel.y >= RISE_V:
		return false
	var rise := blk - h.pos.y
	if rise <= 0.0 or rise > CLIMB_MAX:
		return false
	var w := face(h.m.world.dyn_walls, h.pos, h.r, blk)
	if w.is_empty() or w.get("by") != h:
		return false
	var p2 := Vector2(h.pos.x, h.pos.z)
	var into := Geometry2D.get_closest_point_to_segment(p2, w["a"], w["b"]) - p2
	if into.length() < 0.01 or (h.inp["move"] as Vector2).dot(into.normalized()) < 0.3:
		return false
	h.vel.y = RISE_V
	h.grounded = false
	var push := into.normalized() * h.base_speed * CARRY_K      # her walk carries on as she rises: no hard stop
	h.vel.x = push.x
	h.vel.z = push.y
	return true
