extends RefCounted
## Part of --hero-vfx-check: where each ability's effect leaves the slice Hunters (Vex, Kael, Lace, Cinder) and
## Albert and Meeko on their swapped models. Each emitter must come from the model (a .glb anchor empty, or a point
## on a bone), not the body-offset fallback, and through every clip of the Hero it stays within REACH of its bone:
## of the bone itself or of the mesh that bone carries (a sword's tip rides hand.R with the blade). Measured in the
## bone's own space, so an anchor left behind by a mesh swap shows as far off the bone whatever the pose. A "bone"
## that is a floating companion's id (Meeko's sun, WardenCompanions) is measured against that companion's mesh.

const REACH := 0.15             # m: the most an emitter may sit off its bone (or off the mesh it carries)
const OWN := 0.5                # a vertex belongs to the bone with this much of its weight or more
## arch -> [label, emitter, bone]. An emitter is one of the Hero's FX anchors (content/vfx/<arch>.json) or
## "node:<empty>", a .glb anchor its kit reads by name.
const EMITTERS := {
	"gunslinger": [["LMB rounds", "node:weapon_muzzle", "forearm.R"],
		["RMB Burr Charge", "node:launcher_fire", "forearm.R"],
		["RMB Burr Charge bell", "node:launcher_muzzle", "forearm.R"]],
	"juggernaut": [["LMB slash", "blade_tip", "hand.R"], ["RMB Smash", "blade_tip", "hand.R"],
		["E Warchain throw", "hand_chain", "hand.R"], ["E Warchain line", "node:anchor_chain", "hand.R"],
		["X Gilded Riposte", "blade_tip", "hand.R"]],
	"archer": [["LMB arrow", "bow_root", "bow"], ["RMB Heavy Shot nock", "nock", "bow_s"],
		["E Hail Wall", "bow_root", "bow"], ["X Starpiercer", "bow_root", "bow"]],
	"ashwick": [["LMB lance (right palm)", "nozzle", "hand.R"], ["RMB Cinder Shot", "nozzle", "hand.R"],
		["left palm", "node:weapon_muzzle_l", "hand.L"], ["E Furnace Cloak", "chest", "hips"],
		["X Flue Flight jet L", "heel_l", "jet.0"], ["X Flue Flight jet R", "heel_r", "jet.1"]],
	"bulwark": [["LMB swing", "hammer_head", "x_weapon"], ["RMB Aegis", "shield_face", "x_shield"],
		["hammer catch", "hammer_grip", "x_weapon"]],
	"tender": [["RMB Burrseed", "lantern", "sun"], ["E Hearthlight", "lantern", "sun"],
		["X Hearth Call", "lantern", "sun"], ["dash", "chest", "hips"]]}
const DT := 1.0 / 60.0

var owner_check: RefCounted

func run(main: Node, check: RefCounted) -> void:
	owner_check = check
	var holder := Node3D.new()
	main.add_child(holder)
	for arch: String in EMITTERS:
		await _hero(main, holder, arch)
	holder.free()

func _hero(main: Node, holder: Node3D, arch: String) -> void:
	var m := Models.hunter(Arch.weight(arch), Data.TEAM_COLORS[0], Arch.signature(arch), "", PlayerLook.neutral(), arch)
	holder.add_child(m)
	var w := m.get_node_or_null("Warden")
	var sk := WardenGlb.skeleton(w)
	owner_check.ok(sk != null, "%s wears its .glb" % arch)
	if sk == null:
		m.free()
		return
	var sync := w.get_node("Sync") as WardenGlb.Sync
	var an := HunterAnim.new(m)
	var worst := {}
	var st := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true}
	var moves: Dictionary = WardenClips.data(WardenGlb.art(arch)).get("kmoves", {})
	var poses: Array = [{}]
	for k in moves:
		for t in [0.0, 0.25, 0.5]:
			poses.append({"kmove": k, "kmove_t": t})
	var verts := {}
	for row: Array in EMITTERS[arch]:
		verts[row[2]] = _bone_verts(w, sk, String(row[2]))
	for pose: Dictionary in poses:
		var s2 := st.duplicate()
		s2.merge(pose, true)
		an.update(DT, s2)
		sync._process(DT)
		await main.get_tree().process_frame      # the anchor empties ride their bones from the next frame
		for row: Array in EMITTERS[arch]:
			var d := _off_bone(m, sk, arch, row, verts[row[2]])
			worst[row[0]] = maxf(float(worst.get(row[0], 0.0)), d)
	for row: Array in EMITTERS[arch]:
		var d := float(worst[row[0]])
		owner_check.ok(d <= REACH, "%s %s: within %.2f m of %s through every clip (worst %.3f m)"
				% [arch, row[0], REACH, row[2], d])
	m.free()

## How far the emitter is off its bone now: from the bone or the nearest vertex it carries, whichever is closer;
## INF when the emitter is not on the model at all.
func _off_bone(m: Node3D, sk: Skeleton3D, arch: String, row: Array, verts: PackedVector3Array) -> float:
	var at := _emitter(m, sk, arch, String(row[1]))
	var bi := WardenSkeleton.find(sk, String(row[2]))
	var part := sk.get_node_or_null(WardenCompanions.PREFIX + String(row[2])) as Node3D
	if at == Vector3.INF or (bi < 0 and part == null):
		return INF
	var frame := part.global_transform if part else sk.global_transform * sk.get_bone_global_pose(bi)
	var local := frame.affine_inverse() * at
	var d := local.length()
	for v in verts:
		d = minf(d, v.distance_to(local))
	return d

## The emitter's world point the way HeroVfx.anchor_pos finds it on the model (anchor empties, then a bone point);
## INF where it would fall back to the Gun or the body.
func _emitter(m: Node3D, sk: Skeleton3D, arch: String, emitter: String) -> Vector3:
	if emitter.begins_with("node:"):
		var nd := WardenGlb.anchor(m, emitter.trim_prefix("node:"))
		return nd.global_position if nd else Vector3.INF
	var a: Dictionary = (HeroVfx.data(arch).get("anchors", {}) as Dictionary).get(emitter, {})
	for n in a.get("nodes", []):
		var nd := WardenGlb.anchor(m, String(n))
		if nd:
			return nd.global_position
	var bi := WardenSkeleton.find(sk, String(a.get("bone", "")))
	if bi < 0:
		return Vector3.INF
	var off: Array = a.get("off", [0.0, 0.0, 0.0])
	return sk.global_transform * (sk.get_bone_global_pose(bi) * Vector3(off[0], off[1], off[2]))

## The vertices `bone` carries (OWN of their weight or more), in the bone's own space (the skin's bind pose).
func _bone_verts(w: Node, sk: Skeleton3D, bone: String) -> PackedVector3Array:
	var part := sk.get_node_or_null(WardenCompanions.PREFIX + bone) as MeshInstance3D
	if part != null:
		return part.mesh.get_faces()
	var out := PackedVector3Array()
	var bi := WardenSkeleton.find(sk, bone)
	for mi: MeshInstance3D in w.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or mi.mesh == null:
			continue
		var binds := {}
		for j in mi.skin.get_bind_count():
			var b := mi.skin.get_bind_bone(j)
			if (b if b >= 0 else sk.find_bone(mi.skin.get_bind_name(j))) == bi:
				binds[j] = mi.skin.get_bind_pose(j)
		if binds.is_empty():
			continue
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / maxi(pos.size(), 1)
			for i in pos.size():
				for j in per:
					var bind := bones[i * per + j]
					if binds.has(bind) and wts[i * per + j] >= OWN:
						out.append((binds[bind] as Transform3D) * pos[i])
	return out
