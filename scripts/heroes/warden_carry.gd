class_name WardenCarry
extends RefCounted
## The rescue carry on a Hero's .glb (KinDowned, pose id "rs_carry"): one upper-body layer over whatever the legs play
## (the walk and run clips at the carry's 90% speed). Both arms come in to cradle the Boki at a chest socket, the
## torso leans back a little under the weight, and the weapon bones the Hero's data names ("carry_stow") are put away
## where the hands are needed; a weapon modelled straight into a hand ("carry_drop": the hands; "carry_drop_surfaces":
## a weapon fused into the hand by blended weights, named by its surface) leaves the shown mesh for the carry (held,
## hold). Two-bone arm IK on the contract bones (RIG_CONTRACT), so one layer fits all 12 bodies;
## no clip is authored for it. The socket (world position) is left on the model for KinDowned.scoop_pose.

const MOVE := "rs_carry"           # HunterAnim pose id (KinDowned.rescue_pose) that carries; "rs_done" eases it out
const MOVES := [MOVE, "rs_done"]   # the pose ids the clips leave to this layer, legs and torso stay on the loco clips
const SOCKET := "carry_socket"     # model meta: world position the Boki rides at
const MOTE := "heart_mote"         # model meta: world position of the Heartspark held in the off hand
const MOTE_REACH := 0.12           # arm lengths: the mote floats this far above the held wrist
const FADE := 0.25                 # s: the layer eases in and out
const LEAN := 0.13                 # rad: the torso leans back about the hips
const REACH_FWD := 0.55            # arm lengths: how far in front of the shoulders the cradle sits (data "carry_fwd")
const REACH_DOWN := 0.5            # arm lengths: and how far below them
const HANDS_APART := 0.34          # arm lengths: the two wrists, apart under the Boki
const SOCKET_UP := 0.12            # arm lengths: the Boki sits this far above the wrists
const POLE_DOWN := 0.7             # the elbow bends down ...
const POLE_OUT := 0.5              # ... and a little out
const STOW_SCALE := 0.001          # a stowed weapon bone shrinks to this
const ARMS := ["upper_arm", "forearm", "hand"]
const HAND_REACH := 0.1            # m: a hand's skin lies this near its head; a piece on it reaching past is a weapon
const RIGID := 0.99                # a vertex with this much weight on one hand moves with it alone
const KEEP_FLAGS := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS | Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES

static var _bare := {}             # a body mesh -> the same mesh without the weapons modelled into its hands

## Does this pose id hand the arms to the layer?
static func owns(km: String) -> bool:
	return km in MOVES

## Lays the carry over the skeleton's current pose at weight w (0..1) and returns the socket in world space; fwd is
## how far in front of the shoulders the cradle sits (arm lengths: a broad body's own, from its data).
static func apply(skel: Skeleton3D, root: Node3D, w: float, fwd := REACH_FWD) -> Vector3:
	var to_skel := skel.global_transform.affine_inverse().basis * root.global_basis
	to_skel = to_skel.orthonormalized()
	var ahead := to_skel * Vector3.FORWARD
	var up := to_skel * Vector3.UP
	var hips := WardenSkeleton.find(skel, "hips")
	var keep := {}      # bone index -> its local rotation before the layer
	var idx := _arms(skel)
	for bi in idx.values():
		keep[bi] = skel.get_bone_pose_rotation(bi)
	keep[hips] = skel.get_bone_pose_rotation(hips)
	_lean(skel, hips, to_skel * Vector3.RIGHT)
	var sh_l := skel.get_bone_global_pose(idx["upper_arm.L"]).origin
	var sh_r := skel.get_bone_global_pose(idx["upper_arm.R"]).origin
	var mid := (sh_l + sh_r) * 0.5
	var across := (sh_r - sh_l).normalized()
	var reach := _reach(skel, idx)
	var cradle := mid + ahead * fwd * reach - up * REACH_DOWN * reach
	for s in ["L", "R"]:
		var out := across * (-1.0 if s == "L" else 1.0)
		var wrist := cradle + out * HANDS_APART * 0.5 * reach
		_arm(skel, idx, s, wrist, -up * POLE_DOWN + out * POLE_OUT)
	for bi in keep:
		skel.set_bone_pose_rotation(bi, (keep[bi] as Quaternion).slerp(skel.get_bone_pose_rotation(bi), w))
	return skel.global_transform * (cradle + up * SOCKET_UP * reach)

## The Heartspark carry: the off hand (side "L" or "R") lifts to the cradle's height and holds the mote at the chest,
## the other arm and the legs stay on the clips so the main arm still fires and casts. Returns the mote in world space.
static func hold_mote(skel: Skeleton3D, root: Node3D, w: float, side: String, fwd := REACH_FWD) -> Vector3:
	var to_skel := (skel.global_transform.affine_inverse().basis * root.global_basis).orthonormalized()
	var ahead := to_skel * Vector3.FORWARD
	var up := to_skel * Vector3.UP
	var idx := _arms(skel)
	var keep := {}
	for b in ARMS:
		keep[idx["%s.%s" % [b, side]]] = skel.get_bone_pose_rotation(idx["%s.%s" % [b, side]])
	var sh_l := skel.get_bone_global_pose(idx["upper_arm.L"]).origin
	var sh_r := skel.get_bone_global_pose(idx["upper_arm.R"]).origin
	var across := (sh_r - sh_l).normalized()
	var out := across * (-1.0 if side == "L" else 1.0)
	var reach := _reach(skel, idx)
	var wrist := (sh_l + sh_r) * 0.5 + ahead * fwd * reach - up * REACH_DOWN * reach + out * HANDS_APART * 0.5 * reach
	_arm(skel, idx, side, wrist, -up * POLE_DOWN + out * POLE_OUT)
	for bi in keep:
		skel.set_bone_pose_rotation(bi, (keep[bi] as Quaternion).slerp(skel.get_bone_pose_rotation(bi), w))
	return skel.global_transform * (wrist + up * MOTE_REACH * reach)

## Bone indices of both arms, keyed "upper_arm.L".
static func _arms(skel: Skeleton3D) -> Dictionary:
	var idx := {}
	for s in ["L", "R"]:
		for b in ARMS:
			idx["%s.%s" % [b, s]] = WardenSkeleton.find(skel, "%s.%s" % [b, s])
	return idx

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

## The skinned meshes on this skeleton whose weapon is modelled into one of `hands` or is one of `surfaces` (by name):
## [[MeshInstance3D, its mesh, the mesh without that weapon]]. The bare copy is built once a session per mesh.
static func held(skel: Skeleton3D, hands: Array, surfaces: Array = []) -> Array:
	var out: Array = []
	if hands.is_empty() and surfaces.is_empty():
		return out
	for n in skel.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var m := mi.mesh as ArrayMesh
		if m == null or mi.skin == null:
			continue
		if not _bare.has(m):
			_bare[m] = _strip(m, mi.skin, skel, hands, surfaces)
		if _bare[m] != m:
			out.append([mi, m, _bare[m]])
	return out

## Shows each held() mesh without its weapon (on) or whole.
static func hold(meshes: Array, on: bool) -> void:
	for h in meshes:
		(h[0] as MeshInstance3D).mesh = h[2] if on else h[1]

## A copy of m without its hand-held pieces and the named surfaces' triangles (m itself when it has none): same
## vertices, same surfaces, fewer triangles.
static func _strip(m: ArrayMesh, skin: Skin, skel: Skeleton3D, hands: Array, surfaces: Array) -> ArrayMesh:
	var head := hand_heads(skin, skel, hands)
	var out := ArrayMesh.new()
	var dropped := false
	for si in m.get_surface_count():
		var arrays := m.surface_get_arrays(si)
		if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_BONES] != null:
			var tris := PackedInt32Array() if m.surface_get_name(si) in surfaces else _keep(arrays, head)
			dropped = dropped or tris.size() < (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
			arrays[Mesh.ARRAY_INDEX] = tris if not tris.is_empty() else PackedInt32Array([0, 0, 0])
		var flags := m.surface_get_format(si) & KEEP_FLAGS
		out.add_surface_from_arrays(m.surface_get_primitive_type(si), arrays, [], {}, flags)
		out.surface_set_material(si, m.surface_get_material(si))
		out.surface_set_name(si, m.surface_get_name(si))
	return out if dropped else m

## The skin bind index of each named hand -> the hand's head in mesh space.
static func hand_heads(skin: Skin, skel: Skeleton3D, hands: Array) -> Dictionary:
	var head := {}
	for b in skin.get_bind_count():
		var nm := skin.get_bind_name(b)
		var bone := skel.find_bone(nm) if nm != &"" else skin.get_bind_bone(b)
		for h in hands:
			if bone >= 0 and bone == WardenSkeleton.find(skel, String(h)):
				head[b] = skin.get_bind_pose(b).affine_inverse().origin
	return head

## The surface's triangles minus each piece that rides one of the hands alone and reaches past HAND_REACH from it.
static func _keep(arrays: Array, head: Dictionary) -> PackedInt32Array:
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var piece := pieces(idx, arrays[Mesh.ARRAY_VERTEX])
	var reach := on_hands(arrays, head, piece)
	var out := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		if float(reach.get(piece[idx[t]], 0.0)) <= HAND_REACH:
			out.append_array([idx[t], idx[t + 1], idx[t + 2]])
	return out

## The pieces of a surface that ride the hands in `head` (hand_heads) alone, each -> how far it reaches from its hand
## (m). A piece with a vertex on anything else is part of the body.
static func on_hands(arrays: Array, head: Dictionary, piece: Array[int]) -> Dictionary:
	var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var wts: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / pos.size()
	var tied := {}
	var reach := {}
	for v in pos.size():
		var on := -1
		for k in per:
			if wts[v * per + k] >= RIGID and head.has(bones[v * per + k]):
				on = bones[v * per + k]
		if on < 0:
			tied[piece[v]] = true
		else:
			reach[piece[v]] = maxf(float(reach.get(piece[v], 0.0)), pos[v].distance_to(head[on]))
	for p in tied:
		reach.erase(p)
	return reach

## Each vertex's piece (union-find over the triangles' edges and over vertices at the same point: a UV seam splits
## the vertices, not the piece).
static func pieces(idx: PackedInt32Array, pos: PackedVector3Array) -> Array[int]:
	var up: Array[int] = []       # (an Array, not a packed one: _join writes into it)
	up.assign(range(pos.size()))
	var at := {}
	for v in pos.size():
		if at.has(pos[v]):
			_join(up, v, at[pos[v]])
		else:
			at[pos[v]] = v
	for t in range(0, idx.size(), 3):
		_join(up, idx[t], idx[t + 1])
		_join(up, idx[t], idx[t + 2])
	for v in pos.size():
		up[v] = _top(up, v)
	return up

static func _join(up: Array[int], a: int, b: int) -> void:
	up[_top(up, a)] = _top(up, b)

static func _top(up: Array[int], v: int) -> int:
	while up[v] != v:
		up[v] = up[up[v]]
		v = up[v]
	return v
