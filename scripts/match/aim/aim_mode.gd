class_name AimMode
extends RefCounted
## Where a shot or a placed ability goes (docs/AIMKIT.md): "cursor" lands at the cursor point, clamped to
## the max range (and to a short minimum so point-blank clicks still travel); "max" always flies the
## full range in the aim direction. Also the membership tests that match the AimKit telegraph shapes, so
## a kit's hit test and its drawing agree.
##
## Per shot: a kit sets `h.shot_aim` before the shot leaves (Hunter._emit_shot takes it once, like
## shot_range_k). Per weapon: content/weapons/<id>.json "aim": "cursor" | "max". With neither, a weapon
## with "boom" (a lobbed round) lands at the cursor and every other weapon flies its full range.

const CURSOR := "cursor"
const MAX := "max"
const MIN_D := 1.5      # m: a cursor-placed shot still travels at least this far (the old boom clamp)

## The mode the next shot will use, without taking the per-shot override (reticles, previews).
static func mode_of(h: Hunter) -> String:
	if h.shot_aim != "":
		return h.shot_aim
	return String(h.wpn.get("aim", CURSOR if h.wpn.has("boom") else MAX))

## The mode for the shot leaving now: takes the per-shot override (Hunter._emit_shot).
static func take(h: Hunter) -> String:
	var md := mode_of(h)
	h.shot_aim = ""
	return md

## Flat distance from the hunter to the cursor point (m).
static func cursor_dist(h: Hunter) -> float:
	var a: Vector3 = h.inp.get("aim", h.pos)
	return Vector2(a.x - h.pos.x, a.z - h.pos.z).length()

## How far a shot or placement travels: the cursor distance clamped to [min_d, max_range] in "cursor"
## mode, max_range in "max" mode.
static func dist(h: Hunter, max_range: float, mode := CURSOR, min_d := MIN_D) -> float:
	if mode == MAX:
		return max_range
	return clampf(cursor_dist(h), minf(min_d, max_range), max_range)

## The ground point a shot or placement lands on (y on the ground there when there is ground, else the
## hunter's height).
static func point(h: Hunter, max_range: float, mode := CURSOR, min_d := MIN_D) -> Vector3:
	var d := h.aim_dir()
	var r := dist(h, max_range, mode, min_d)
	return ground(h.m, Vector3(h.pos.x + d.x * r, h.pos.y, h.pos.z + d.y * r))

## p with y moved onto the ground under it (unchanged over the abyss or off the map).
static func ground(m: Node, p: Vector3) -> Vector3:
	if m == null or m.get("world") == null:
		return p
	var g: float = m.world.ground_at(p.x, p.z)
	return Vector3(p.x, g if g > World.VOID + 1.0 else p.y, p.z)

# ------------------------------------------------------------------ membership (flat, XZ)
## The height rule for every ability shape (docs/COMBAT.md): a body is in reach when its feet are within this
## of the shape's own level (m): two tiers (World.LEVEL, the mantle ledge) plus a jump's slack. A wall's top
## (3 m and up) is out, so a cliff face ends a shape the way it ends a walk.
const REACH_Y := 2.2

## Are two feet heights in each other's reach (the shape's level and the body's)?
static func in_reach(shape_y: float, body_y: float) -> bool:
	return absf(body_y - shape_y) < REACH_Y

## Inside a lane of `length` x `width` starting at `from` along `dir` (the AimKit.lane footprint).
static func in_lane(from: Vector3, dir: Vector2, length: float, width: float, p: Vector3, pad := 0.0) -> bool:
	var v := Vector2(p.x - from.x, p.z - from.z)
	var along := v.dot(dir)
	var side := absf(v.x * dir.y - v.y * dir.x)
	return along >= -pad and along <= length + pad and side <= width * 0.5 + pad

## Inside a cone of half-angle deg/2 from `from` along `dir`, between `inner` and `length`.
static func in_cone(from: Vector3, dir: Vector2, length: float, deg: float, p: Vector3, inner := 0.0, pad := 0.0) -> bool:
	var v := Vector2(p.x - from.x, p.z - from.z)
	var l := v.length()
	if l < inner - pad or l > length + pad:
		return false
	if l < 0.001:
		return true
	return absf(dir.angle_to(v)) <= deg_to_rad(deg) * 0.5 + atan2(pad, l)

## Inside a curved wall: a band of `thick` around `radius` from `center`, deg wide around `dir`
## (the AimKit.arc_wall footprint).
static func in_arc(center: Vector3, dir: Vector2, radius: float, deg: float, thick: float, p: Vector3, pad := 0.0) -> bool:
	var v := Vector2(p.x - center.x, p.z - center.z)
	if absf(v.length() - radius) > thick * 0.5 + pad:
		return false
	return absf(dir.angle_to(v)) <= deg_to_rad(deg) * 0.5 + atan2(pad, maxf(0.1, radius))

static func in_circle(at: Vector3, r: float, p: Vector3, pad := 0.0) -> bool:
	return Vector2(p.x - at.x, p.z - at.z).length() <= r + pad
