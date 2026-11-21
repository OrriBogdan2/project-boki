class_name WardenHeld
extends Node3D
## A Meshy-native Hunter's weapon as its own piece (warden_native.json "weapon", docs/art/wardens/MESHY_NATIVE.md):
## Meshy's model of Kael and Grimble has no weapon, so the live weapon is cut out of the contract model's .glb (its
## surfaces by material), unskinned, and held rigidly in Meshy's hand bone. In Meshy's idle it sits in the hand as the
## contract model holds it at rest; from there it turns and moves with Meshy's hand through every clip.

static var _meshes := {}  # art name -> the weapon at the contract model's rest (model space), cut once a session

var grip: Transform3D  # the weapon's frame in Meshy's hand bone's frame (model space)
var pivot: Vector3  # the contract hand bone's rest pivot (the grip), in the weapon's own space


## The held weapon of `model` from data `w` ({"bone": contract hand bone, "materials": [...]}), added under it;
## `hand_idle`: Meshy's hand bone in model space at the start of its idle. null when the contract weapon is missing.
static func make(model: Node3D, arch: String, w: Dictionary, hand_idle: Transform3D) -> WardenHeld:
	var nm := WardenGlb.art(arch)
	var bone := String(w.get("bone", "hand.R"))
	if not _meshes.has(nm):
		_meshes[nm] = _cut(nm, w.get("materials", []), bone)
	var rest := WardenGlb.neutral_rest(arch)
	if _meshes[nm] == null or not rest.has(bone):
		return null
	var held := WardenHeld.new()
	held.name = "Held"
	var mi := MeshInstance3D.new()
	mi.name = "Weapon"
	mi.mesh = _meshes[nm]
	held.add_child(mi)
	held.pivot = (rest[bone] as Transform3D).origin
	held.grip = (
		hand_idle.affine_inverse() * Transform3D(Basis.IDENTITY, hand_idle.origin - held.pivot)
	)
	model.add_child(held)
	return held


## Placed for this frame from Meshy's hand bone (model space).
func follow(hand: Transform3D) -> void:
	transform = hand * grip


## The contract .glb's surfaces whose material is in `keep`, posed at rest in model space with no skin (their
## vertices all ride `bone`).
static func _cut(nm: String, keep: Array, bone: String) -> ArrayMesh:
	var glb := (
		(load("%s/%s/%s.glb" % [WardenGlb.DIR, nm, nm]) as PackedScene).instantiate() as Node3D
	)
	var out := ArrayMesh.new()
	for node in glb.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var to_rest := _to_rest(glb, mi, bone)
		for si in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(si)
			if mat == null or not keep.has(mat.resource_name):
				continue
			var arr := mi.mesh.surface_get_arrays(si)
			arr[Mesh.ARRAY_VERTEX] = to_rest * (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			if arr[Mesh.ARRAY_NORMAL] != null:
				var turn := Transform3D(to_rest.basis.orthonormalized(), Vector3.ZERO)  # (rest and bind are rigid)
				arr[Mesh.ARRAY_NORMAL] = turn * (arr[Mesh.ARRAY_NORMAL] as PackedVector3Array)
			arr[Mesh.ARRAY_TANGENT] = null
			arr[Mesh.ARRAY_BONES] = null
			arr[Mesh.ARRAY_WEIGHTS] = null
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			out.surface_set_material(out.get_surface_count() - 1, mat)
	glb.free()
	return out if out.get_surface_count() > 0 else null


## A skinned vertex riding `bone` back to the model space of the contract model at rest (bone rest times its bind).
static func _to_rest(glb: Node3D, mi: MeshInstance3D, bone: String) -> Transform3D:
	var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	if sk == null or mi.skin == null:
		return WardenGlb.model_xf(glb, mi)
	var bi := WardenSkeleton.find(sk, bone)
	for b in mi.skin.get_bind_count():
		if mi.skin.get_bind_name(b) == bone or (bi >= 0 and mi.skin.get_bind_bone(b) == bi):
			return (
				WardenGlb.model_xf(glb, sk) * sk.get_bone_global_rest(bi) * mi.skin.get_bind_pose(b)
			)
	return WardenGlb.model_xf(glb, mi)
