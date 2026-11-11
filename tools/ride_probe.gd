class_name RideProbe
extends RefCounted
## Where a rider's hands and feet are on the squad rocket, in the rocket's own frame (--drop-rocket-check and
## --remote-anim-check measure the ride pose with it).

const GRIP_M := 0.4              # m: a hand may be this far off the grab bar (a held staff pulls one off it)
const HULL_SLACK_M := 0.02       # m: a foot may be this close to the hull's skin (it never goes inside)
const PEG_M := 0.15              # m: a foot's height off the peg's top, up or down
const BAR_LEN_MAX := 1.0         # the hands are no further apart than this many body sizes (arms out sideways: 1.2+)
const BAR_UP := Vector2(0.3, 1.6)      # m: the bar a rider holds is between these heights over its peg

## [left hand, right hand, left foot, right foot] of `h` riding `r`, as the player sees them (rocket frame).
static func limbs(h: Hunter, r: DropRocket) -> Array:
	var a := h.anim
	var to_r := r.node.global_transform.affine_inverse()
	var sole := Vector3(0, -HunterAnim.SHIN, 0)
	return [to_r * DropRocket.seen_at(h, "hand.L", a.hand_l), to_r * DropRocket.seen_at(h, "hand.R", a.hand_r),
		to_r * DropRocket.seen_at(h, "foot.L", a.knee_l if a.knee_l != null else a.leg_l, sole),
		to_r * DropRocket.seen_at(h, "foot.R", a.knee_r if a.knee_r != null else a.leg_r, sole)]

## How far `p` (rocket frame) is from the bar over `h`'s peg, as drawn (it is sized to the rider's hands).
static func off_bar(h: Hunter, r: DropRocket, p: Vector3) -> float:
	var bar: Node3D = r.bars[h]
	var tang := Vector3(cos(bar.rotation.y), 0, -sin(bar.rotation.y))
	var rod := bar.get_node("Len") as Node3D
	var centre := bar.position + tang * rod.position.x
	var half := rod.scale.x * 0.5
	return p.distance_to(centre + tang * clampf((p - centre).dot(tang), -half, half))

## The pose against the rocket: {"grip": the hands' worst distance off the bar, "hull": the feet's smallest gap to the
## hull's skin, "peg": the feet's worst height off the peg's top, "up": the hands' height over the peg, "len": the bar's
## length over the body's size (the gap between the hands and a little more: a T-pose is well over BAR_LEN_MAX)}.
static func fit(h: Hunter, r: DropRocket) -> Dictionary:
	var p := limbs(h, r)
	var hull := 9.0
	var peg := 0.0
	for i in [2, 3]:
		hull = minf(hull, Vector2(p[i].x, p[i].z).length() - DropRocket.HULL_R)
		peg = maxf(peg, absf(p[i].y - DropRocket.SEAT_Y))
	return {"grip": maxf(off_bar(h, r, p[0]), off_bar(h, r, p[1])), "hull": hull, "peg": peg,
		"up": ((p[0] as Vector3).y + (p[1] as Vector3).y) * 0.5 - DropRocket.SEAT_Y,
		"len": (r.bars[h].get_node("Len") as Node3D).scale.x / h.model.scale.x}
