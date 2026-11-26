class_name WardenGunProp
extends RefCounted
## Grimble's one gun on the Meshy-native path (WardenHolster's rule: never on the hip and in the hand together). His
## Meshy body carries no gun; the prop is a separate .glb that rides the hip socket at rest and the hand socket while he
## aims or fires (HunterAnim's aim_k, model meta WardenHolster.DRAW). Data (warden_native.json "holster"): {"glb",
## "hip": SOCKET, "hand": SOCKET}, SOCKET = {"bone", "pos" (m, off the bone's rest head, or off "grip_at"'s bone head),
## "muzzle" + "up" (directions in the rest pose, skeleton space; "muzzle": "bone" = along the bone's first child),
## "mirror" (x flips to the side the "side" bone is on)}.

var node: Node3D
var skel: Skeleton3D
var sockets: Array = []  # [hip bone, hip local, hand bone, hand local]
var k := 1.0  # skeleton units per metre
var root: Node3D


static func make(model: Node3D, sk: Skeleton3D, to_m: Transform3D, d: Dictionary) -> WardenGunProp:
	var path := String(d.get("glb", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var gp := WardenGunProp.new()
	gp.root = model
	gp.skel = sk
	gp.k = 1.0 / maxf(to_m.basis.get_scale().y, 0.0001)
	for side in ["hip", "hand"]:
		var s: Dictionary = d.get(side, {})
		var bone := sk.find_bone(String(s.get("bone", "")))
		if bone < 0:
			return null
		gp.sockets.append(bone)
		gp.sockets.append(gp._socket(bone, s))
	gp.node = (load(path) as PackedScene).instantiate() as Node3D
	gp.node.name = "DredgeGun"
	sk.add_child(gp.node)
	return gp


func _socket(bone: int, s: Dictionary) -> Transform3D:
	var rest := skel.get_bone_global_rest(bone)
	var at := rest.origin
	var grip := skel.find_bone(String(s.get("grip_at", "")))
	if grip >= 0:
		at = skel.get_bone_global_rest(grip).origin
	var pos := _v(s.get("pos", [0, 0, 0]))
	var side := skel.find_bone(String(s.get("side", "")))
	if s.get("mirror", false) and side >= 0 and skel.get_bone_global_rest(side).origin.x < 0.0:
		pos.x = -pos.x
	var muzzle: Vector3
	if s.get("muzzle") is String:
		var kids := skel.get_bone_children(grip if grip >= 0 else bone)
		muzzle = (skel.get_bone_global_rest(kids[0]).origin - at) if kids.size() > 0 else Vector3.DOWN
		if grip >= 0:  # (the grip bone is the finger root: the arm's direction is the wrist's to it)
			muzzle = at - rest.origin
	else:
		muzzle = _v(s.get("muzzle", [0, -1, 0]))
	var z := -muzzle.normalized()
	var up := _v(s.get("up", [0, 1, 0]))
	var y := (up - z * up.dot(z)).normalized()
	var xf := Transform3D(Basis(y.cross(z), y, z), at + pos * k)
	return rest.affine_inverse() * xf


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## One frame, after the clips posed the bones.
func step() -> void:
	var t := smoothstep(0.0, 1.0, float(root.get_meta(WardenHolster.DRAW, 0.0)))
	var hip: Transform3D = skel.get_bone_global_pose(int(sockets[0])) * (sockets[1] as Transform3D)
	var hand: Transform3D = skel.get_bone_global_pose(int(sockets[2])) * (sockets[3] as Transform3D)
	var xf := hip.interpolate_with(hand, t)
	xf.basis = xf.basis.orthonormalized() * Basis.from_scale(Vector3.ONE * k)
	node.transform = xf
