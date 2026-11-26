extends "res://tools/vv_shots.gd"
## --boki-size-shots --shots-dir=<dir> [--view=3840x2160]: the hero and one average-size Vespyx, Mycroll, Prismander and
## Heatherhorn side by side on flat ground at the match camera's closest zoom. Writes <dir>/size.png (the frame, HUD
## hidden) and <dir>/size.json: each one's foot px, its real height in cm, the px that height spans on screen (vpx) and
## the px its projected mesh vertices span (px; taller than vpx where the camera looks down).

const SPECIES := ["cindle", "burrlet", "puddlet", "heatherhorn"]
const GAP := 1.7


func run(main_node: Node) -> void:
	main = main_node
	var view := Vector2i(3840, 2160)
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--view="):
			view = Vector2i(int(arg.get_slice("x", 0).substr(7)), int(arg.get_slice("x", 1)))
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = view
	await _setup()
	m.cam.user_zoom = CamWheel.near(true)
	T.teleport(home + Vector3(-30, 0, 30))
	var ks: Array = []
	for i in SPECIES.size():
		var rec := Save.new_kin(String(SPECIES[i]), "", 7)
		(rec["dna"] as Dictionary)["size"] = 0.0
		ks.append(m.spawn_wild(rec, home + Vector3(GAP * (i + 1), 0, 0.0), true))
	cam_at = home + Vector3(GAP * 2.0, 0, 0)
	await _go(1.0, Callable(), [], 3.0)
	for k in ks:
		k.teleport(k.home)
	await _go(0.5, Callable(), [], 3.0)
	_hide_ui()
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("size.png"))
	var cam := main.get_viewport().get_camera_3d()
	var out := {"size": [img.get_width(), img.get_height()], "rows": []}
	out["rows"].append(_row("hunter", P, cam))
	for k in ks:
		out["rows"].append(_row(String(k.species), k, cam))
	var f := FileAccess.open(dir.path_join("size.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("BOKISIZE ", JSON.stringify(out))
	main.get_tree().quit(0)


func _row(label: String, node: Node3D, cam: Camera3D) -> Dictionary:
	var lo := INF
	var hi := -INF
	var left := INF
	var right := -INF
	var low_y := INF
	var high_y := -INF
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or not mi.mesh is ArrayMesh:
			continue
		for v in mi.mesh.get_faces():
			var w := mi.global_transform * v
			low_y = minf(low_y, w.y)
			high_y = maxf(high_y, w.y)
			var p := cam.unproject_position(w)
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
			left = minf(left, p.x)
			right = maxf(right, p.x)
	var foot := cam.unproject_position(node.global_position)
	var up := cam.unproject_position(node.global_position + Vector3(0, high_y - low_y, 0))
	return {
		"who": label,
		"foot": [foot.x, foot.y],
		"top": lo,
		"px": hi - lo,
		"box": [left, right],
		"cm": (high_y - low_y) * 100.0,
		"vpx": foot.y - up.y,
	}


## Every 2D layer and top-level control off, so the frame is the world alone.
func _hide_ui() -> void:
	for n in main.get_tree().root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	for n in main.get_children():
		if n is Control:
			(n as Control).visible = false
