class_name WardenHeld
extends Node3D
## A Meshy-native Hunter's weapon as its own piece (warden_native.json "weapon", docs/art/wardens/MESHY_NATIVE.md):
## Meshy's model of Kael and Grimble has no weapon, so the live weapon is cut out of the contract model's .glb (its
## surfaces by material), unskinned, and held rigidly in Meshy's hand bone. In Meshy's idle it sits in the hand as the
## contract model holds it at rest; from there it turns and moves with Meshy's hand through every clip.
## "mirror": the contract model holds it in the other hand than the splash: cut it mirrored across the model's middle
## (x = 0), so the contract's right-hand grip becomes a left-hand one (Kael: sword in the dark-veined left hand).
## "hold" {"palm": bone, "grip": [grip anchor, muzzle anchor], "aim": [x, y, z]}: seated by its own grip instead of
## the contract's wrist: the grip anchor in the palm (halfway from Meshy's hand bone to `palm`), the grip-to-muzzle line
## turned onto `aim` (model space, -z ahead) in the idle (Grimble's blunderbuss in his iron fist, barrel ahead).
## "tilt": game state -> degrees the weapon turns on the body's side axis (model x) about the grip, from its seat in
## the idle (+ tips it forward and up), eased over TILT_RATE as the state changes: a long weapon held off the floor
## in every clip (Kael's sword tip dragged in the idle and the crouch; Grimble's blunderbuss in the jump).

const MIRROR := Transform3D(Vector3(-1.0, 0.0, 0.0), Vector3.UP, Vector3.BACK, Vector3.ZERO)

const TILT_RATE := 900.0  # deg/s: the weapon turns to the next state's tilt (a 120-degree raise in ~0.13 s)

static var _meshes := {}  # art name -> the weapon at the contract model's rest (model space), cut once a session
static var _anchors := {}  # art name -> {anchor empty name: its rest frame (model space)} (data "anchors")

var grip: Transform3D  # the weapon's frame in Meshy's hand bone's frame (model space), at this frame's tilt
var seat: Transform3D  # the weapon's frame (model space) on Meshy's idle hand, untilted
var hand_idle: Transform3D  # Meshy's hand bone (model space) at the start of its idle
var tilts := {}  # game state -> degrees (data "tilt")
var tilt := 0.0  # degrees now
var tilt_to := 0.0  # degrees the state wants
var pivot: Vector3  # the grip in the weapon's own space: the contract hand bone's rest pivot, or "hold"'s grip anchor
var palm := Vector3.ZERO  # where the grip sits in Meshy's hand bone's frame (the bone itself unless "hold")


## The held weapon of `model` from data `w` ({"bone": contract hand bone, "materials": [...]}), added under it;
## `hand_idle`: Meshy's hand bone in model space at the start of its idle. null when the contract weapon is missing.
## `palm_idle`: data "hold"'s palm bone in model space at the start of the idle (unused without "hold").
static func make(
	model: Node3D, arch: String, w: Dictionary, hand_idle: Transform3D, palm_idle := Vector3.ZERO
) -> WardenHeld:
	var nm := WardenGlb.art(arch)
	var bone := String(w.get("bone", "hand.R"))
	var mirror := bool(w.get("mirror", false))
	if not _meshes.has(nm):
		_anchors[nm] = {}
		_meshes[nm] = _cut(nm, w.get("materials", []), bone, w.get("anchors", []), _anchors[nm])
		if mirror and _meshes[nm]:
			_meshes[nm] = _mirrored(_meshes[nm])
			for an in _anchors[nm]:
				_anchors[nm][an] = MIRROR * (_anchors[nm][an] as Transform3D) * MIRROR
	var rest := WardenGlb.neutral_rest(arch)
	if _meshes[nm] == null or not rest.has(bone):
		return null
	var held := WardenHeld.new()
	held.name = "Held"
	var mi := MeshInstance3D.new()
	mi.name = "Weapon"
	mi.mesh = _meshes[nm]
	held.add_child(mi)
	for an in _anchors[nm]:
		var at := Node3D.new()
		at.name = String(an)
		at.transform = _anchors[nm][an]
		held.add_child(at)
	held.pivot = (rest[bone] as Transform3D).origin
	if mirror:
		held.pivot.x = -held.pivot.x
	held.hand_idle = hand_idle
	held.seat = Transform3D(Basis.IDENTITY, hand_idle.origin - held.pivot)
	var hold: Dictionary = w.get("hold", {})
	var ends: Array = hold.get("grip", [])
	if ends.size() == 2 and _anchors[nm].has(ends[0]) and _anchors[nm].has(ends[1]):
		var root := (_anchors[nm][ends[0]] as Transform3D).origin
		var line := (_anchors[nm][ends[1]] as Transform3D).origin - root
		var aim := Vector3(hold.get("aim", [0.0, 0.0, -1.0])[0], hold["aim"][1], hold["aim"][2]).normalized()
		var at := (hand_idle.origin + palm_idle) * 0.5
		var turn := Basis(Quaternion(line.normalized(), aim))
		held.pivot = root
		held.seat = Transform3D(turn, at) * Transform3D(Basis.IDENTITY, -root)
		held.palm = hand_idle.affine_inverse() * at
	held.tilts = w.get("tilt", {})
	held.tilt = float(held.tilts.get("idle", 0.0))
	held.tilt_to = held.tilt
	held.grip = held.grip_at(held.tilt)
	model.add_child(held)
	return held


## The weapon's frame in the hand bone's frame, turned `deg` about the grip on the body's side axis.
func grip_at(deg: float) -> Transform3D:
	var about := Transform3D(Basis.IDENTITY, hand_idle * palm)
	var turn := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(deg)), Vector3.ZERO)
	return hand_idle.affine_inverse() * about * turn * about.affine_inverse() * seat


## The game state now playing: the weapon eases to its tilt (data "tilt", 0 when the state has none).
func state(st: String) -> void:
	tilt_to = float(tilts.get(st, 0.0))


## Eases the tilt on by `dt` s.
func ease_tilt(dt: float) -> void:
	if tilt != tilt_to:
		tilt = move_toward(tilt, tilt_to, TILT_RATE * dt)
		grip = grip_at(tilt)


## Placed for this frame from Meshy's hand bone (model space).
func follow(hand: Transform3D) -> void:
	transform = hand * grip


## The contract .glb's surfaces whose material is in `keep`, posed at rest in model space with no skin (their
## vertices all ride `bone`); the weapon's anchor empties named in `names` (its bloom and FX points) into `anchors`,
## at rest in model space the same way.
static func _cut(nm: String, keep: Array, bone: String, names: Array, anchors: Dictionary) -> ArrayMesh:
	var glb := (load("%s/%s/%s.glb" % [WardenGlb.DIR, nm, nm]) as PackedScene).instantiate() as Node3D
	var sk := WardenGlb.skeleton(glb)
	for an in names:
		var e := glb.find_child(String(an), true, false) as Node3D
		var att := e.get_parent() as BoneAttachment3D if e else null
		if att and sk:
			var at_rest := sk.get_bone_global_rest(sk.find_bone(att.bone_name))
			anchors[an] = WardenGlb.model_xf(glb, sk) * at_rest * e.transform
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


## `mesh` mirrored across x = 0: positions and normals flipped on x, each triangle's winding turned back.
static func _mirrored(mesh: ArrayMesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		arr[Mesh.ARRAY_VERTEX] = MIRROR * (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array)
		if arr[Mesh.ARRAY_NORMAL] != null:
			arr[Mesh.ARRAY_NORMAL] = MIRROR * (arr[Mesh.ARRAY_NORMAL] as PackedVector3Array)
		if arr[Mesh.ARRAY_INDEX] != null:
			var idx := arr[Mesh.ARRAY_INDEX] as PackedInt32Array
			for t in range(0, idx.size() - 2, 3):
				var k := idx[t + 1]
				idx[t + 1] = idx[t + 2]
				idx[t + 2] = k
			arr[Mesh.ARRAY_INDEX] = idx
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(si, mesh.surface_get_material(si))
	return out


## A skinned vertex riding `bone` back to the model space of the contract model at rest (bone rest times its bind).
static func _to_rest(glb: Node3D, mi: MeshInstance3D, bone: String) -> Transform3D:
	var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	if sk == null or mi.skin == null:
		return WardenGlb.model_xf(glb, mi)
	var bi := WardenSkeleton.find(sk, bone)
	for b in mi.skin.get_bind_count():
		if mi.skin.get_bind_name(b) == bone or (bi >= 0 and mi.skin.get_bind_bone(b) == bi):
			return WardenGlb.model_xf(glb, sk) * sk.get_bone_global_rest(bi) * mi.skin.get_bind_pose(b)
	return WardenGlb.model_xf(glb, mi)
