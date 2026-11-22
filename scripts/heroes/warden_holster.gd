class_name WardenHolster
extends RefCounted
## One gun prop for a Warden whose body carries no gun (Grimble's blunderbuss): it rides a hip socket at rest and
## goes to the hand while he aims or fires, so it is never on the hip and in the hand together. The prop is a mesh
## skinned to the weapon's own bone (warden_anim "blade" bone, e.g. "gun"); each frame, after the clips and the
## aim, that bone is set to the hip socket, the hand socket, or between (HunterAnim's aim_k: quick draw, slow holster).
## Data (content/rules/warden_anim/<art>.json "holster"): {"hip": SOCKET, "hand": SOCKET}, SOCKET = {"bone", "pos"
## (m, in that bone's space), "rot" (euler rad)}.

const DRAW := "gun_draw"  # model meta: 0 on the hip, 1 in the hand (HunterAnim.aim_k)

var root: Node3D
var skel: Skeleton3D
var gun := -1
var sockets: Array = []  # [hip bone, hip offset, hand bone, hand offset]


static func make(model: Node3D, sk: Skeleton3D, data: Dictionary, gun_bone: String) -> WardenHolster:
	var h := WardenHolster.new()
	h.root = model
	h.skel = sk
	h.gun = WardenSkeleton.find(sk, gun_bone)
	for side in ["hip", "hand"]:
		var d: Dictionary = data.get(side, {})
		var bone := WardenSkeleton.find(sk, String(d.get("bone", "")))
		if bone < 0 or h.gun < 0:
			return null
		var rot: Array = d.get("rot", [0.0, 0.0, 0.0])
		var pos: Array = d.get("pos", [0.0, 0.0, 0.0])
		h.sockets.append(bone)
		var at := Basis.from_euler(Vector3(rot[0], rot[1], rot[2]))
		h.sockets.append(Transform3D(at, Vector3(pos[0], pos[1], pos[2])))
	return h


## One frame, after the clips posed the bones.
func step() -> void:
	var k := smoothstep(0.0, 1.0, float(root.get_meta(DRAW, 0.0)))
	var hip: Transform3D = skel.get_bone_global_pose(int(sockets[0])) * (sockets[1] as Transform3D)
	var hand: Transform3D = skel.get_bone_global_pose(int(sockets[2])) * (sockets[3] as Transform3D)
	skel.set_bone_global_pose(gun, hip.interpolate_with(hand, k))
