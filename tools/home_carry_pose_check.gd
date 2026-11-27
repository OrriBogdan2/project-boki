extends RefCounted
## --home-carry-pose-check: at home every Hunter (Meshy's own skeleton or the contract one) holds a Boki the way
## HomeCarry asks (state "act" "carry" in the arms, "pack" on the back): both wrists come to the socket the Boki rides
## at (left on the model for HomeCarry), the weapon in the hand is not drawn, a garden verb ("holster") puts the
## weapon away without bringing the arms in, and it all lets go afterwards. Headless; never touches the save.

const DT := 1.0 / 30.0
const SETTLE := 20  # frames: the layer eases in over WardenCarry.FADE
const HAND_PIECE_M := 0.12  # m: the longest piece left riding a hand alone (a weapon); WardenCarry.HAND_REACH + slack
const WRIST_K := 0.3  # of the body's height: the most a wrist may be from the socket in the arms hold
const BACK_BEHIND := 0.0  # m: the back socket lies at least this far behind the hips

var bad := 0
var holder: Node


func ok(cond: bool, what: String) -> void:
	print("HOMECARRYPOSE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	WardenNative.contract_only = false
	holder = Node3D.new()
	main.add_child(holder)
	for id in [
		"gunslinger",
		"archer",
		"bulwark",
		"ashwick",
		"dolm",
		"dredge",
		"gil",
		"juggernaut",
		"mage",
		"ostra",
		"rimewright",
		"tender",
		"thief"
	]:
		await _hero(id)
	print("HOMECARRYPOSE done, %d failures" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _hero(id: String) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var layer := m.get_node_or_null("Warden/Native")
	if layer == null:
		layer = m.get_node_or_null("Warden/Sync")
	if layer == null:
		ok(false, "%s: no Hero layer" % id)
		return
	layer.set_process(false)
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var s := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true, "fired": 99.0}
	m.set_meta(WardenClips.STATE, s)
	var bare := _hand_piece(sk)
	var tris_rest := _drawn(sk)
	s["act"] = "carry"
	_step(layer)
	var socket: Vector3 = m.get_meta(WardenCarry.SOCKET, Vector3.INF)
	ok(socket != Vector3.INF, "%s: the arms hold leaves a socket on the model" % id)
	if socket != Vector3.INF:
		var height := 1.6 * absf(m.scale.y)
		var worst := 0.0
		for side in ["L", "R"]:
			var wrist := sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, "hand." + side)).origin
			worst = maxf(worst, wrist.distance_to(socket))
		ok(worst <= WRIST_K * height, "%s: both wrists reach the Boki (%.2f m from the socket)" % [id, worst])
	var held := _hand_piece(sk)
	ok(held <= HAND_PIECE_M, "%s: no weapon rides a hand into the Boki (%.2f m, %.2f at rest)" % [id, held, bare])
	var dd: Dictionary = WardenClips.data(WardenGlb.art(id))
	var props: Dictionary = WardenNative.entry(WardenGlb.art(id)).get("props", {})
	if dd.has("carry_drop_surfaces") or dd.has("carry_hide") or dd.has("carry_drop_far") or props.has("hand.R"):
		ok(
			_drawn(sk) < tris_rest,
			"%s: the weapon in the hand is not drawn (%d of %d triangles)" % [id, _drawn(sk), tris_rest]
		)
	s["act"] = "pack"
	_step(layer)
	var back: Vector3 = m.get_meta(WardenCarry.SOCKET, Vector3.INF)
	var hips := sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, "hips")).origin
	ok(back != Vector3.INF and back.z > hips.z + BACK_BEHIND, "%s: the back hold keeps the Boki behind the hips" % id)
	s.erase("act")
	s["holster"] = true
	_step(layer)
	ok(not m.has_meta(WardenCarry.SOCKET), "%s: a garden verb alone brings no arms in" % id)
	ok(_hand_piece(sk) <= HAND_PIECE_M, "%s: and puts the weapon away (%.2f m on a hand)" % [id, _hand_piece(sk)])
	s.erase("holster")
	_step(layer)
	ok(
		not m.has_meta(WardenCarry.SOCKET) and _hand_piece(sk) >= bare - 0.001,
		"%s: it lets go (no socket, weapon back: %.2f m on a hand, %.2f at rest)" % [id, _hand_piece(sk), bare]
	)
	m.free()


func _step(layer: Node) -> void:
	for i in SETTLE:
		layer.call("_process", DT)


## The triangles the Hero's visible meshes draw (an emptied surface keeps one degenerate triangle).
func _drawn(sk: Skeleton3D) -> int:
	var n := 0
	for mi: MeshInstance3D in sk.get_parent().find_children("*", "MeshInstance3D", true, false):
		if mi.is_visible_in_tree() and mi.mesh is ArrayMesh:
			for si in mi.mesh.get_surface_count():
				n += mi.mesh.surface_get_array_index_len(si) / 3
	return n


## The longest piece a visible skinned mesh draws riding a hand alone (a weapon): WardenCarry.on_hands.
func _hand_piece(sk: Skeleton3D) -> float:
	var most := 0.0
	for n in sk.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.skin == null or not mi.visible or not mi.mesh is ArrayMesh:
			continue
		var head := WardenCarry.hand_heads(mi.skin, sk, ["hand.L", "hand.R"])
		for si in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(si)
			if arrays[Mesh.ARRAY_BONES] == null:
				continue
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var piece := WardenCarry.pieces(idx, arrays[Mesh.ARRAY_VERTEX])
			var reach := WardenCarry.on_hands(arrays, head, piece)
			for t in range(0, idx.size(), 3):  # (a stripped mesh keeps the weapon's vertices: count drawn triangles)
				if idx[t] != idx[t + 1]:
					most = maxf(most, float(reach.get(piece[idx[t]], 0.0)))
	return most
