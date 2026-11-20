class_name HitContact
extends RefCounted
## Where a hit lands on its target, for the impact spark (Juice.hit). A shot, a melee strike's sweep, a blast
## or a zone tick puts its real contact point in the hit's options as `at`; the point is clamped to the
## target's collider (its hurtbox circle and its height, Arch.hit_h) so a tall Hunter is struck high and a small
## one low, not at one fixed chest height. A hit with no `at` lands on the near side at the attacker's own height.

## m: a contact is kept this far inside the collider's top and bottom.
const EDGE := 0.1
## Share of the hurtbox radius a hit with no contact point lands in from the surface (the near side).
const NEAR_SIDE := 0.8


## The collider's height (m): a Hunter's hurtbox (Arch.hit_h), else the band Match.shot_band uses for a monster.
static func height(target: Ent) -> float:
	return Arch.hit_h(target.arch) if target is Hunter else maxf(0.9, target.r * 2.2)


## `p` pulled inside the target's collider: within its hurtbox circle, between its feet and the top of its head.
static func clamp_to(target: Ent, p: Vector3) -> Vector3:
	var fy := target.hit_y()
	var flat := Vector2(p.x - target.pos.x, p.z - target.pos.z).limit_length(target.r)
	return Vector3(target.pos.x + flat.x, clampf(p.y, fy + EDGE, fy + height(target) - EDGE), target.pos.z + flat.y)


## The contact point of a hit on `target` by `by`: `o["at"]` clamped to the collider, else the near side at the
## attacker's height (a body-high strike), else mid-height when nobody struck it (a burn, a fall).
static func point(target: Ent, by: Ent, o: Dictionary) -> Vector3:
	if o.get("at", null) is Vector3:
		return clamp_to(target, o["at"])
	var mid := target.hit_y() + height(target) * 0.5
	if by == null or not is_instance_valid(by) or by == target:
		return Vector3(target.pos.x, mid, target.pos.z)
	var near := Vector2(by.pos.x - target.pos.x, by.pos.z - target.pos.z).limit_length(target.r * NEAR_SIDE)
	var strike_y := by.hit_y() + height(by) * 0.5
	return clamp_to(target, Vector3(target.pos.x + near.x, strike_y, target.pos.z + near.y))
