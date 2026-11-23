class_name WardenProps
extends RefCounted
## Parts of a Hunter's contract model that its Meshy mesh does not have (Kael's sword, Cinder's heel jets), hung on
## Meshy's own bones on the native path (WardenNative; warden_native.json "props": contract bone -> material names).
## Each part is cut out of the contract .glb's skinned body by material, only the triangles that bone carries, made
## rigid in that bone's rest frame, and hung on the Meshy bone that plays the bone (WardenSkeleton.find) by `carry`:
## the part keeps its place and turn against the limb, the contract's parent -> bone line swung onto Meshy's, so the
## sword gripped in the contract's hanging hand sits in Meshy's A-pose hand. The contract's anchor empties on that bone
## ride the part (the blade tip on the blade). Data "stretch" {"kmove", "y", "rest"}: the parts' length along their
## bone while that kit move plays and otherwise (the contract's clips key the jet bones' scale: Flue Flight's long
## flames, small ones at rest).

const PREFIX := "prop_"  # MeshInstance3D name: prop_<contract bone> ("jet.0" -> prop_jet_0: node names have no ".")
const EASE := 10.0  # 1/s: how fast a part eases to its stretch

static var _cut := {}  # "art bones" -> {"sk_m": contract skeleton -> its model, "parts": {bone: [mesh, rest, anchors,
# line]}}

var nodes: Array = []  # the parts (MeshInstance3D) riding Meshy's bones
var stretch: Dictionary = {}


## Hangs `art`'s contract parts (data `d` "props": contract bone -> material names; "tilt", "scale", "grip" {contract
## bone: {part: [x,y,z] in the part's frame, bone: [x,y,z] in the Meshy bone's, turn: [x,y,z] rad}}, "stretch")
## on `skel` (Meshy's; `to_m`: it -> the Hunter's model). Returns the live parts (empty when the contract .glb has
## none of them).
static func carry(art: String, skel: Skeleton3D, to_m: Transform3D, d: Dictionary) -> WardenProps:
	var want: Dictionary = d.get("props", {})
	var stretch_d: Dictionary = d.get("stretch", {})
	var wp := WardenProps.new()
	wp.stretch = stretch_d
	var parts: Dictionary = contract(art, want).get("parts", {}) if not want.is_empty() else {}  # (none: no .glb load)
	for cb: String in parts:
		var p: Array = parts[cb]
		var onto := _onto(skel, to_m, p[3], deg_to_rad(float((d.get("tilt", {}) as Dictionary).get(cb, 0.0))))
		var nb := WardenSkeleton.find(skel, cb)
		if nb < 0 or onto.basis.determinant() == 0.0:
			continue
		var at := BoneAttachment3D.new()
		at.name = "bone_" + PREFIX + cb.validate_node_name()
		at.bone_name = skel.get_bone_name(nb)
		skel.add_child(at)
		var mi := MeshInstance3D.new()
		mi.name = PREFIX + cb.validate_node_name()
		mi.mesh = p[0]
		# (data "scale": the part grown about its bone)
		var grow := _grow((d.get("scale", {}) as Dictionary).get(cb, 1.0))
		mi.transform = ((to_m * skel.get_bone_global_rest(nb)).affine_inverse() * onto * (p[1] as Transform3D)
			* Transform3D(Basis.from_scale(grow)))
		# (data "grip": a point of the part into the fist)
		var grip: Dictionary = (d.get("grip", {}) as Dictionary).get(cb, {})
		if not grip.is_empty():
			var at_part := Vector3(grip["part"][0], grip["part"][1], grip["part"][2])
			var in_bone := Vector3(grip["bone"][0], grip["bone"][1], grip["bone"][2])
			# (a rotation vector, rad, in the bone's frame, applied to the part before it is pinned)
			if grip.has("turn"):
				var tv := Vector3(grip["turn"][0], grip["turn"][1], grip["turn"][2])
				if tv.length() > 0.0001:
					mi.transform.basis = Basis(tv.normalized(), tv.length()) * mi.transform.basis
			mi.transform.origin += in_bone - mi.transform * at_part
		mi.set_meta("base", mi.transform)
		mi.set_meta("y", float(stretch_d.get("rest", 1.0)))
		mi.transform = mi.transform * Transform3D(Basis.from_scale(Vector3(1.0, mi.get_meta("y"), 1.0)))
		at.add_child(mi)
		for an: Array in p[2]:  # [name, in the bone's rest frame]
			var e := Node3D.new()
			e.name = String(an[0])
			e.transform = an[1]
			mi.add_child(e)
		wp.nodes.append(mi)
	return wp


## Data "scale" value `v`: one number (all axes) or [x, y, z] in the part's own frame (its length runs along x).
static func _grow(v: Variant) -> Vector3:
	if v is Array and (v as Array).size() == 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ONE * float(v)


## Eases the parts to their stretch for kit move `kmove`.
func step(dt: float, kmove: String) -> void:
	var on := kmove != "" and kmove == String(stretch.get("kmove", ""))
	var y := float(stretch.get("y", 1.0)) if on else float(stretch.get("rest", 1.0))
	for mi: MeshInstance3D in nodes:
		var now := move_toward(float(mi.get_meta("y", 1.0)), y, EASE * dt * maxf(y, 1.0))
		mi.set_meta("y", now)
		mi.transform = (mi.get_meta("base") as Transform3D) * Transform3D(Basis.from_scale(Vector3(1.0, now, 1.0)))


## The part contract bone `bone` carries on Meshy's skeleton `sk` (its MeshInstance3D, posed in the bone's frame), or
## null.
static func part(sk: Skeleton3D, bone: String) -> MeshInstance3D:
	return sk.find_child(PREFIX + bone.validate_node_name(), true, false) as MeshInstance3D if sk else null


## How far contract bone `bone` is stretched along itself on `model`: the bone's pose scale on a contract rig, the
## part's on Meshy's (1.0 when neither is there).
static func stretch_of(model: Node3D, bone: String) -> float:
	var sk := WardenGlb.skeleton(model.get_node_or_null(^"Warden"))
	var bi := WardenSkeleton.own(sk, bone) if sk else -1
	if bi >= 0:
		return sk.get_bone_pose_scale(bi).y
	var mi := model.find_child(PREFIX + bone.validate_node_name(), true, false)
	return float(mi.get_meta("y", 1.0)) if mi else 1.0


## Contract model space -> Meshy's model space for a part of contract bone `cb`: its limb (`line`: the contract bone's
## anatomical bone and its parent's head, model space) turned onto Meshy's same limb, the contract's ahead (the
## model's -Z: a hanging hand's thumb side, a foot's toes) onto Meshy's thumb or toe, the part first bent `tilt` rad
## back toward the limb (data "tilt": the wrist bend the contract's own clips keyed and Meshy's do not). A zero basis
## when Meshy has no such limb.
static func _onto(skel: Skeleton3D, to_m: Transform3D, line: Array, tilt: float) -> Transform3D:
	var na := WardenSkeleton.find(skel, String(line[0]))
	var np := skel.get_bone_parent(na) if na >= 0 else -1
	if np < 0:
		return Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	var hm := (to_m * skel.get_bone_global_rest(na)).origin
	var ahead := Vector3.FORWARD
	for c in skel.get_bone_children(na):  # (a hand's thumb points the way a hanging arm's knuckles face: ahead)
		if skel.get_bone_name(c).contains("Thumb") or skel.get_bone_name(c).contains("Toe"):
			ahead = (to_m * skel.get_bone_global_rest(c)).origin - hm
	var hc: Vector3 = line[1]
	var mine := _frame(hm - (to_m * skel.get_bone_global_rest(np)).origin, ahead)
	var theirs := _frame(hc - (line[2] as Vector3), Vector3.FORWARD)
	var bend := Basis(theirs.x, tilt)
	return Transform3D(mine * theirs.transposed() * bend, hm) * Transform3D(Basis.IDENTITY, -hc)


## The limb's frame: y along `along`, -z the way `ahead` points off it.
static func _frame(along: Vector3, ahead: Vector3) -> Basis:
	var y := along.normalized()
	var z := -(ahead - y * ahead.dot(y)).normalized()
	return Basis(y.cross(z), y, z)


## The contract model's parts `want` of `art` (read once per art): the skeleton's model transform and, per bone,
## [rigid mesh in the bone's rest frame, the bone's model rest, its anchors, [anatomical bone, its head, its parent's
## head]]. The anatomical bone is the first of the bone and its parents that Meshy has (WardenSkeleton.NATIVE).
static func contract(art: String, want := {}) -> Dictionary:
	var key := "%s %s" % [art, want.keys()]
	if _cut.has(key):
		return _cut[key]
	var out := {}
	_cut[key] = out
	var path := "%s/%s/%s.glb" % [WardenGlb.DIR, art, art]
	if not ResourceLoader.exists(path):
		return out
	var con := (load(path) as PackedScene).instantiate() as Node3D
	var csk := WardenGlb.skeleton(con)
	if csk == null:
		con.free()
		return out
	var sk_m := WardenGlb.model_xf(con, csk)
	out["sk_m"] = sk_m
	var parts := {}
	for cb: String in want:
		var bi := WardenSkeleton.own(csk, cb)
		if bi < 0:
			continue
		var mesh := _cut_part(csk, bi, want[cb])
		if mesh.get_surface_count() == 0:
			continue
		var ab := bi
		while ab >= 0 and _native_name(csk, ab) == "":
			ab = csk.get_bone_parent(ab)
		var apar := csk.get_bone_parent(ab) if ab >= 0 else -1
		if apar < 0:
			continue
		var rest := sk_m * csk.get_bone_global_rest(bi)
		var line := [
			_native_name(csk, ab),
			(sk_m * csk.get_bone_global_rest(ab)).origin,
			(sk_m * csk.get_bone_global_rest(apar)).origin
		]
		parts[cb] = [mesh, rest, _anchors(con, csk, bi), line]
	out["parts"] = parts
	con.free()
	return out


## The contract name (WardenSkeleton.NATIVE key) of contract bone `bi`, or "" when Meshy has no such bone.
static func _native_name(csk: Skeleton3D, bi: int) -> String:
	for k: String in WardenSkeleton.NATIVE:
		if WardenSkeleton.own(csk, k) == bi:
			return k
	return ""


## The anchor empties (anchor_*, weapon_muzzle*) on contract bone `bi`: [name, in its rest frame].
static func _anchors(con: Node3D, csk: Skeleton3D, bi: int) -> Array:
	var out: Array = []
	for at in con.find_children("*", "BoneAttachment3D", true, false):
		if csk.find_bone((at as BoneAttachment3D).bone_name) != bi:
			continue
		for nd in at.get_children():
			var nm := String(nd.name)
			var empty := nd is Node3D and not (nd is MeshInstance3D)
			if empty and (nm.begins_with("anchor_") or nm.begins_with("weapon_muzzle")):
				out.append([nm, (nd as Node3D).transform])
	return out


## The triangles of surfaces `mats` (material names) whose three corners bone `bi` carries most, rigid in its rest
## frame (the skin's bind pose).
static func _cut_part(csk: Skeleton3D, bi: int, mats: Array) -> ArrayMesh:
	var am := ArrayMesh.new()
	for mi: MeshInstance3D in csk.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or mi.mesh == null:
			continue
		var bind := -1
		for j in mi.skin.get_bind_count():
			var b := mi.skin.get_bind_bone(j)
			if (b if b >= 0 else csk.find_bone(mi.skin.get_bind_name(j))) == bi:
				bind = j
		if bind < 0:
			continue
		for si in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(si)
			if mat == null or not String(mat.resource_name) in mats:
				continue
			var arr := _rigid(mi.mesh.surface_get_arrays(si), bind, mi.skin.get_bind_pose(bind))
			if not arr.is_empty():
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				am.surface_set_material(am.get_surface_count() - 1, mat)
	return am


## Surface arrays `arr` cut to the triangles bind `bind` carries most at every corner, moved by `pose` (the bind pose:
## mesh -> the bone's rest frame) and unskinned; [] when no triangle is left.
static func _rigid(arr: Array, bind: int, pose: Transform3D) -> Array:
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / maxi(pos.size(), 1)
	var mine := PackedByteArray()
	mine.resize(pos.size())
	for i in pos.size():
		var top := 0
		for j in per:
			if wts[i * per + j] > wts[i * per + top]:
				top = j
		mine[i] = 1 if per > 0 and bones[i * per + top] == bind else 0
	var idx := PackedInt32Array(range(pos.size()))
	if arr[Mesh.ARRAY_INDEX] != null:
		idx = arr[Mesh.ARRAY_INDEX]
	var keep := PackedInt32Array()
	for t in range(0, idx.size() - 2, 3):
		if mine[idx[t]] == 1 and mine[idx[t + 1]] == 1 and mine[idx[t + 2]] == 1:
			for c in 3:
				keep.append(idx[t + c])
	if keep.is_empty():
		return []
	for i in pos.size():
		pos[i] = pose * pos[i]
	arr[Mesh.ARRAY_VERTEX] = pos
	if arr[Mesh.ARRAY_NORMAL] != null:
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i in nrm.size():
			nrm[i] = (pose.basis * nrm[i]).normalized()
		arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TANGENT] = null
	arr[Mesh.ARRAY_INDEX] = keep
	arr[Mesh.ARRAY_BONES] = null
	arr[Mesh.ARRAY_WEIGHTS] = null
	return arr
