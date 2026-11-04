extends RefCounted
## --warden-rig-json [--warden=<id>] [--out=<path>]: writes a Warden's contract armature and the landmarks the
## Blender build (tools/blender/) models against, as JSON in Godot model space (metres, +Y up, facing -Z):
## each bone's head, its parent, the joint it points at; the soles, knees, crown; the held weapon's space
## (the Gun node at rest, its Muzzle, the procedural weapon's bounds). Default out: art/wardens/src/<name>_rig.json.

func run(main: Node) -> void:
	var arch := "gunslinger"
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--warden="):
			arch = a.substr(9)
		if a.begins_with("--out="):
			out = a.substr(6)
	if out == "":
		out = "res://art/wardens/src/%s_rig.json" % WardenGlb.ART.get(arch, arch)
	var rest := WardenGlb.neutral_rest(arch)
	var sk := WardenSkeleton.build(rest)
	var bones := {}
	for bi in sk.get_bone_count():
		var b := sk.get_bone_name(bi)
		var g := sk.get_bone_global_rest(bi)
		bones[b] = {"head": _v(g.origin), "y": _v(g.basis.y), "z": _v(g.basis.z),
			"parent": String(WardenSkeleton.PARENT[b])}
	sk.free()
	var m := Models.hunter(Arch.weight(arch), Data.TEAM_COLORS[0], Arch.signature(arch), "", PlayerLook.neutral(), arch)
	var head := m.get_node("Rig/Torso/HeadPivot/Head") as MeshInstance3D
	var land := {
		"crown": ((rest["head"] as Transform3D) * head.transform * head.mesh.get_aabb()).end.y,
		"knee": (rest["shin.L"] as Transform3D).origin.y,
		"sole": 0.0,
	}
	var gun := m.get_node("Rig/Torso/Aim/Gun") as Node3D
	var box := AABB()
	var first := true
	for mi in gun.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh == null:
			continue      # (a .glb weapon modelled whole empties the procedural Mag)
		var b := WardenGlb.model_xf(gun, mi) * (mi as MeshInstance3D).mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var weapon := {"muzzle": _v((gun.get_node("Muzzle") as Node3D).position), "box_pos": _v(box.position),
		"box_size": _v(box.size), "wid": Arch.signature(arch)}
	m.free()
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"arch": arch, "bones": bones, "land": land, "weapon": weapon}, "\t"))
	f.close()
	print("WARDENRIG wrote %s (%d bones)" % [out, bones.size()])
	main.get_tree().quit()

func _v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.0001), snappedf(p.y, 0.0001), snappedf(p.z, 0.0001)]
