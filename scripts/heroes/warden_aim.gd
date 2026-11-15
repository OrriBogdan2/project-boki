class_name WardenAim
extends RefCounted
## Aiming across terraces on a .glb's bones (scripts/match/aim/aim_pitch.gd): the clips key a flat aim, so after
## them the hips bone (the spine: the arms and head ride it, the thighs do not, so the feet stay planted) and both
## upper arms pitch about the model's right axis. HunterAnim's eased pitch comes in as the model's meta PITCH; the
## share the retargeted rig already carries (clips.proc_w) is left out so it is never counted twice.

const PITCH := "aim_pitch"      # root meta: rad the body aims up (+) or down, already eased and weighted

var root: Node3D
var skel: Skeleton3D
var hips := -1
var arms: Array = []
var held := -1                  # the weapon's bone when no arm carries it (Pip's lantern on a pauldron, Grimble's gun)
var held_on_hips := false       # ...and the hips carry it (else it hangs off the root and swings about the hips)

## weapon: the Hero's data "blade" bone ("": the weapon rides an arm's bones).
static func make(model: Node3D, sk: Skeleton3D, weapon := "") -> WardenAim:
	var a := WardenAim.new()
	a.root = model
	a.skel = sk
	a.hips = WardenSkeleton.find(sk, "hips")
	for b in ["upper_arm.L", "upper_arm.R"]:
		var bi := WardenSkeleton.find(sk, b)
		if bi >= 0:
			a.arms.append(bi)
	var wb := WardenSkeleton.find(sk, weapon) if weapon != "" else -1
	if wb >= 0 and not a._under(wb, a.arms):
		a.held = wb
		a.held_on_hips = a._under(wb, [a.hips])
	return a

## Whether bone bi is one of `of` or hangs below one.
func _under(bi: int, of: Array) -> bool:
	while bi >= 0:
		if bi in of:
			return true
		bi = skel.get_bone_parent(bi)
	return false

## One frame, after the clips posed the bones. w: how much of the pose is the clips' (1 - clips.proc_w).
func step(w: float) -> void:
	var p := float(root.get_meta(PITCH, 0.0)) * w
	if hips < 0 or absf(p) < 0.0005 or not root.is_inside_tree():
		return
	var axis := (skel.global_basis.inverse() * root.global_basis.x).normalized()
	_turn(hips, axis, p * AimPitch.SPINE)
	for bi in arms:
		_turn(int(bi), axis, p * (1.0 - AimPitch.SPINE))
	if held_on_hips:
		_turn(held, axis, p * (1.0 - AimPitch.SPINE))
	elif held >= 0:
		var rot := Basis(axis, p)
		var pivot := skel.get_bone_global_pose(hips).origin
		var g := skel.get_bone_global_pose(held)
		skel.set_bone_global_pose(held, Transform3D(rot * g.basis, pivot + rot * (g.origin - pivot)))

## Bone bi turned by ang about its own head.
func _turn(bi: int, axis: Vector3, ang: float) -> void:
	var g := skel.get_bone_global_pose(bi)
	g.basis = Basis(axis, ang) * g.basis
	skel.set_bone_global_pose(bi, g)
