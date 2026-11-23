extends "res://tools/stretch_check.gd"
## --pose-dump --dump=<file> --wardens=dredge [--warden-variant=..]: the game's skeleton global poses at every
## stretch_check sample (render-tree helper, not shipped).

var fh: FileAccess
var cur := ""

func run(main: Node) -> void:
	var path := "user://pose_dump.txt"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dump="): path = a.substr(7)
	fh = FileAccess.open(path, FileAccess.WRITE)
	await super.run(main)

func _collect(glb: Node) -> void:
	super._collect(glb)
	var names := PackedStringArray()
	for b in skel.get_bone_count():
		names.append(skel.get_bone_name(b))
	fh.store_line("B " + " ".join(names))
	for mi in glb.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.skin == null:
			continue
		for i in inst.skin.get_bind_count():
			fh.store_line("S %s %s %s" % [inst.name, inst.skin.get_bind_name(i), _tf(inst.skin.get_bind_pose(i))])
		fh.store_line("M %s %s" % [inst.name, _tf(skel.global_transform.affine_inverse() * inst.global_transform)])
	fh.flush()

func _clip(clips: WardenClips, nm: String) -> Array:
	cur = nm
	return await super._clip(clips, nm)

func _measure() -> Array:
	var vals := PackedStringArray()
	for b in skel.get_bone_count():
		vals.append(_tf(skel.get_bone_global_pose(b)))
	fh.store_line("P %s %s" % [cur, " ".join(vals)])
	return [0.0, ""]

func _tf(t: Transform3D) -> String:
	return "%f %f %f %f %f %f %f %f %f %f %f %f" % [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
		t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]
