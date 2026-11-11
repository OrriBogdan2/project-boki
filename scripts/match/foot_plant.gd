class_name FootPlant
extends RefCounted
## Where the lowest point of a boot sits for a leg pose, so HunterAnim can drop or lift the hips until the
## sole just touches the ground (the Empty, whose boots are the Models.hunter ones). Leg space: x right,
## y up, z back.

const HIP := 0.44                  # m: the hip joint's height in Models.hunter's rest pose
const KNEE := 0.2                  # m: knee below the hip joint
## The sole's heel, middle and toe in the knee's space (m): HeroKit.sole's centre line plus half its thickness.
const SOLE := [Vector3(0.0, -0.263, 0.03), Vector3(0.0, -0.268, -0.06), Vector3(0.0, -0.264, -0.16)]

## A sole point `p` (knee space) in the leg's space with the hip joint at the origin: down the thigh, the knee's
## bend (x), then the leg node's own z scale `zk` (a woman's legs are 0.9 in x and z, Unmasked._shape).
static func at(p: Vector3, knee: float, zk: float) -> Vector3:
	var v := Vector3(0.0, -KNEE, 0.0) + Basis(Vector3.RIGHT, knee) * p
	v.z *= zk
	return v

## How far below the hip joint the boot's lowest point hangs, for the hip's turn (x forward, z out) and the
## knee's bend (x), all in radians, on a leg of z scale `zk`.
static func reach(hip: float, knee: float, out: float, zk: float) -> float:
	var leg := Basis.from_euler(Vector3(hip, 0.0, out))
	var low := 0.0
	for p in SOLE:
		low = maxf(low, -(leg * at(p, knee, zk)).y)
	return low
