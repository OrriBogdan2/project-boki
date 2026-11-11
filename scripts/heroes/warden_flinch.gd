class_name WardenFlinch
extends RefCounted
## The hit flinch of a Hero with hand-keyed clips: a spring on the torso that rides over whatever clip plays (a run,
## a cast, a held shot) and never replaces it, so a chip hit never stops you shooting or walking. It leans away from
## where the hit came from (front, back, left or right); a harder hit (Hunter.hit_k, Oomph) leans further. Only a
## stagger (hit_k at Oomph.HEAVY_FLINCH) also plays the hit clip (WardenClips). Runs after the clips each frame.

const KICK := 6.3            # rad/s of lean speed per unit of hit_k (a chip hit peaks near 0.15 rad, 0.05 s in)
const STIFF := 484.0         # 1/s^2: the spring's pull back (it settles in about 0.3 s)
const DAMP := 24.0           # 1/s
const LIMIT := 0.5           # radians at most
const STEP := 1.0 / 60.0     # s: the longest spring step

var root: Node3D
var skel: Skeleton3D
var bone := -1
var lean := Vector2.ZERO     # radians, in the model's frame: x his right, y back
var rate := Vector2.ZERO
var hit_prev := 99.0

static func make(model: Node3D, sk: Skeleton3D) -> WardenFlinch:
	var f := WardenFlinch.new()
	f.root = model
	f.skel = sk
	f.bone = WardenSkeleton.find(sk, "hips")
	return f

## A new hit is the hit clock jumping back (the same test HunterAnim's own flinch uses).
func _kicked(s: Dictionary) -> bool:
	var t := float(s.get("hit_t", 99.0))
	var fresh := t < hit_prev - 0.02 or (t < 0.05 and hit_prev > 0.2)
	hit_prev = t
	return fresh

func step(dt: float) -> void:
	if bone < 0 or dt <= 0.0 or not root.is_inside_tree():
		return
	var s: Dictionary = root.get_meta(WardenClips.STATE, {})
	if _kicked(s):
		var away: Vector2 = s.get("hit_dir", Vector2.ZERO)
		var local := root.global_basis.inverse().orthonormalized() * Vector3(away.x, 0.0, away.y)
		var dir := Vector2(local.x, local.z)
		dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector2(0.0, 1.0)
		rate += dir * KICK * float(s.get("hit_k", 1.0))
	var left := dt
	while left > 0.0001:
		var k := minf(STEP, left)
		rate += (-lean * STIFF - rate * DAMP) * k
		lean += rate * k
		left -= k
	lean = lean.limit_length(LIMIT)
	if lean.length_squared() < 0.00001:
		return
	var turn := Quaternion(Vector3(lean.y, 0.0, -lean.x).normalized(), lean.length())
	skel.set_bone_pose_rotation(bone, turn * skel.get_bone_pose_rotation(bone))
