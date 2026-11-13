class_name ShotOrigin
extends RefCounted
## Where a shot starts hitting, kept apart from where it is drawn (docs/WEAPON_FIRING_DATA.md, "Where shots
## start"). Kits spawn their shots at a muzzle a little ahead of the body; the hit sweep starts at the body's
## centre instead, at the muzzle's height, so a shot fired flush against a wall stops at the wall's face (its
## miss puff in view) and a foe touching you takes the hit. The muzzle flash and the drawn shot stay at the
## muzzle.

## m: a shot spawned this close to its shooter's centre, out along its own flight line, left the body.
## Covers every kit's muzzle (0.6 m) and melee strike (0.25 m); a launch point placed further out (a rock
## landing 0.9 m ahead, a punched rock, a split) keeps its own origin.
const BODY_REACH := 0.7

## The point the hit sweep starts from: `at` pulled back along the flight line to the body's centre.
static func hit_from(by: Ent, at: Vector3, v2: Vector2, x: Dictionary) -> Vector3:
	if by == null or x.get("cos", false) or x.has("lob") or x.get("cos_free", false):
		return at
	var lead := Vector2(at.x - by.pos.x, at.z - by.pos.z)
	var reach := lead.length()
	if reach < 0.01 or reach > BODY_REACH or v2.length() < 0.01 or lead.dot(v2.normalized()) < reach * 0.9:
		return at
	return body(by, at)

## The shooter's centre at the height of `at` (the muzzle).
static func body(by: Ent, at: Vector3) -> Vector3:
	return Vector3(by.pos.x, at.y, by.pos.z)

## The flight time added so a shot pulled back to the body still reaches as far as the kit asked.
static func extra_life(at: Vector3, from: Vector3, v2: Vector2) -> float:
	return Vector2(at.x - from.x, at.z - from.z).length() / maxf(0.01, v2.length())

## Where to draw shot `s` whose swept point is `p`: never behind its muzzle (once past it, as swept).
static func drawn(s: Dictionary, p: Vector3) -> Vector3:
	if not s.has("muzzle"):
		return p
	var mz: Vector3 = s["muzzle"]
	var st: Vector3 = s["start"]
	if Vector2(p.x - st.x, p.z - st.z).length_squared() >= Vector2(mz.x - st.x, mz.z - st.z).length_squared():
		s.erase("muzzle")
		return p
	return Vector3(mz.x, p.y, mz.z)
