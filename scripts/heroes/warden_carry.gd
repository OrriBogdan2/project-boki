class_name WardenCarry
extends RefCounted
## The rescue carry on a Hero's .glb (KinDowned, pose id "rs_carry"): one upper-body layer over whatever the legs play
## (the walk and run clips at the carry's 90% speed). Both arms come in to cradle the Boki at a chest socket, the
## torso leans back a little under the weight, and the weapon bones the Hero's data names ("carry_stow") are put away
## where the hands are needed. Two-bone arm IK on the contract bones (RIG_CONTRACT), so one layer fits all 12 bodies;
## no clip is authored for it. The socket (world position) is left on the model for KinDowned.scoop_pose.

const MOVE := "rs_carry"           # HunterAnim pose id (KinDowned.rescue_pose) that carries; "rs_done" eases it out
const MOVES := [MOVE, "rs_done"]   # the pose ids the clips leave to this layer, legs and torso stay on the loco clips
const SOCKET := "carry_socket"     # model meta: world position the Boki rides at
const FADE := 0.25                 # s: the layer eases in and out
const LEAN := 0.13                 # rad: the torso leans back about the hips
const REACH_FWD := 0.55            # arm lengths: how far in front of the shoulders the cradle sits
const REACH_DOWN := 0.5            # arm lengths: and how far below them
const HANDS_APART := 0.34          # arm lengths: the two wrists, apart under the Boki
const SOCKET_UP := 0.12            # arm lengths: the Boki sits this far above the wrists
const POLE_DOWN := 0.7             # the elbow bends down ...
const POLE_OUT := 0.5              # ... and a little out
const STOW_SCALE := 0.001          # a stowed weapon bone shrinks to this
const ARMS := ["upper_arm", "forearm", "hand"]

## Does this pose id hand the arms to the layer?
static func owns(km: String) -> bool:
	return km in MOVES

## Lays the carry over the skeleton's current pose at weight w (0..1) and returns the socket in world space.
static func apply(skel: Skeleton3D, root: Node3D, w: float) -> Vector3:
	var to_skel := skel.global_transform.affine_inverse().basis * root.global_basis
	to_skel = to_skel.orthonormalized()
	var fwd := to_skel * Vector3.FORWARD
	var up := to_skel * Vector3.UP
	var hips := WardenSkeleton.find(skel, "hips")
	var keep := {}      # bone index -> its local rotation before the layer
	var idx := {}       # "upper_arm.L" -> bone index
	for s in ["L", "R"]:
		for b in ARMS:
			idx["%s.%s" % [b, s]] = WardenSkeleton.find(skel, "%s.%s" % [b, s])
	for bi in idx.values():
		keep[bi] = skel.get_bone_pose_rotation(bi)
	keep[hips] = skel.get_bone_pose_rotation(hips)
	_lean(skel, hips, to_skel * Vector3.RIGHT)
	var sh_l := skel.get_bone_global_pose(idx["upper_arm.L"]).origin
	var sh_r := skel.get_bone_global_pose(idx["upper_arm.R"]).origin
	var mid := (sh_l + sh_r) * 0.5
	var across := (sh_r - sh_l).normalized()
	var reach := _reach(skel, idx)
	var cradle := mid + fwd * REACH_FWD * reach - up * REACH_DOWN * reach
	for s in ["L", "R"]:
		var out := across * (-1.0 if s == "L" else 1.0)
		var wrist := cradle + out * HANDS_APART * 0.5 * reach
		_arm(skel, idx, s, wrist, -up * POLE_DOWN + out * POLE_OUT)
	for bi in keep:
		skel.set_bone_pose_rotation(bi, (keep[bi] as Quaternion).slerp(skel.get_bone_pose_rotation(bi), w))
	return skel.global_transform * (cradle + up * SOCKET_UP * reach)

## The torso tips back about the hips' own point (right is the model's right in skeleton space).
static func _lean(skel: Skeleton3D, hips: int, right: Vector3) -> void:
	var pose := skel.get_bone_global_pose(hips)
	pose.basis = Basis(right, LEAN) * pose.basis
	skel.set_bone_global_pose(hips, pose)

## Mean arm length (shoulder to elbow to wrist), the unit every offset above is in.
static func _reach(skel: Skeleton3D, idx: Dictionary) -> float:
	var total := 0.0
	for s in ["L", "R"]:
		var sh := skel.get_bone_global_pose(idx["upper_arm." + s]).origin
		var el := skel.get_bone_global_pose(idx["forearm." + s]).origin
		var wr := skel.get_bone_global_pose(idx["hand." + s]).origin
		total += sh.distance_to(el) + el.distance_to(wr)
	return total * 0.5

## One arm to a wrist target: the elbow where the pole points, then each bone turned the shortest way to it.
static func _arm(skel: Skeleton3D, idx: Dictionary, s: String, target: Vector3, pole: Vector3) -> void:
	var ua: int = idx["upper_arm." + s]
	var fa: int = idx["forearm." + s]
	var ha: int = idx["hand." + s]
	var shoulder := skel.get_bone_global_pose(ua).origin
	var elbow := skel.get_bone_global_pose(fa).origin
	var wrist := skel.get_bone_global_pose(ha).origin
	var l1 := shoulder.distance_to(elbow)
	var l2 := elbow.distance_to(wrist)
	var along := target - shoulder
	var dist := clampf(along.length(), absf(l1 - l2) + 0.01, (l1 + l2) * 0.98)
	along = along.normalized()
	var cos_s := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var bend := (pole - along * along.dot(pole)).normalized()
	var new_elbow := shoulder + along * (l1 * cos_s) + bend * (l1 * sqrt(1.0 - cos_s * cos_s))
	_turn(skel, ua, (elbow - shoulder).normalized(), (new_elbow - shoulder).normalized())
	var from := (skel.get_bone_global_pose(ha).origin - skel.get_bone_global_pose(fa).origin).normalized()
	_turn(skel, fa, from, (shoulder + along * dist - new_elbow).normalized())

## Bone bi turned the shortest way from one direction to another about its own head (its children follow).
static func _turn(skel: Skeleton3D, bi: int, from: Vector3, to: Vector3) -> void:
	var pose := skel.get_bone_global_pose(bi)
	pose.basis = Basis(Quaternion(from, to)) * pose.basis
	skel.set_bone_global_pose(bi, pose)

## Puts the named weapon bones away (w = how far the layer is in).
static func stow(skel: Skeleton3D, bones: Array, w: float) -> void:
	for nm in bones:
		var bi := WardenSkeleton.find(skel, String(nm))
		if bi >= 0:
			skel.set_bone_pose_scale(bi, Vector3.ONE * lerpf(1.0, STOW_SCALE, clampf(w * 2.0, 0.0, 1.0)))
