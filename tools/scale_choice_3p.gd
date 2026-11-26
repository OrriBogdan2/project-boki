extends "res://tools/vv_shots.gd"
## --scale-choice-3p --shots-dir=<dir> [--view=2560x1440]: camera B of the scale-choice sheet. Sparkle (mage) with one
## average Vespyx, Mycroll, Prismander, Crofthorn 2.5 m in front of her, at the match camera's start zoom (the normal
## combat view), HUD hidden. Per column (v5, v5 x1.5, v5 x2.0) writes <dir>/B_<col>.png and the heights.
const SPECIES := ["cindle", "burrlet", "puddlet", "heatherhorn"]
const XS := [-4.0, -1.6, 1.6, 4.0]
const ZS := [2.5, 2.5, 2.5, 2.5]
const COLS := [["v5", 1.0], ["x15", 1.5], ["x20", 2.0]]
var ks: Array = []
var fits: Array = []
var mult := 1.0

func run(main_node: Node) -> void:
	main = main_node
	var view := Vector2i(2560, 1440)
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--view="):
			view = Vector2i(int(arg.get_slice("x", 0).substr(7)), int(arg.get_slice("x", 1)))
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = view
	extra_opts = {"arena": false, "training": false}  # a real expedition frame, as boki_size_shots
	await _setup()
	m.cam.user_zoom = CamWheel.far(true)
	T.teleport(home + Vector3(-30, 0, 30))
	for i in SPECIES.size():
		var rec := Save.new_kin(String(SPECIES[i]), "", 7)
		(rec["dna"] as Dictionary)["size"] = 0.0
		var k := m.spawn_wild(rec, home + Vector3(XS[i], 0, ZS[i]))
		k.speed = 0.0
		ks.append(k)
	cam_at = home + Vector3(0, 0, 1.2)
	P.inp["aim"] = home + Vector3(0, 0, 8)
	await _go(1.0, _each, [], 3.0)
	for k in ks:
		fits.append(_fit_of(k))
	var out := {"cols": {}}
	for c in COLS:
		mult = float(c[1])
		await _go(0.6, _each, [], 3.0)
		await main.get_tree().process_frame
		_hide_ui()
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		main.get_viewport().get_texture().get_image().save_png(dir.path_join("B_%s.png" % c[0]))
		var rows := {"hunter": _tall(P)}
		for i in ks.size():
			rows[SPECIES[i]] = _tall(ks[i])
		var cam := main.get_viewport().get_camera_3d()
		rows["foot_px"] = {"hunter": _foot(cam, P)}
		for i in ks.size():
			rows["foot_px"][SPECIES[i]] = _foot(cam, ks[i])
		out["cols"][c[0]] = rows
		print("SC3P ", c[0], " ", JSON.stringify(rows))
	var f := FileAccess.open(dir.path_join("B_heights.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	main.get_tree().quit(0)

func _fit_of(k: Node) -> float:
	for n in [k] + k.find_children("*", "Node3D", true, false):
		if n.has_meta("fit"):
			return float(n.get_meta("fit"))
	return 1.0

func _each(_t: float) -> void:
	if fits.is_empty():
		return
	for i in ks.size():
		var k: Node = ks[i]
		k.teleport(home + Vector3(XS[i], 0, ZS[i]))
		k.ring.visible = false  # the type cue's quad would count in the height
		k.face = PI + [0.3, -0.2, 0.2, -0.3][i]
		for n in [k] + k.find_children("*", "Node3D", true, false):
			if n.has_meta("fit"):
				n.set_meta("fit", fits[i] * mult)
	P.face = PI

func _foot(cam: Camera3D, n: Node3D) -> Array:
	var p := cam.unproject_position(n.global_position)
	return [p.x, p.y]

## Visible mesh height (cm) of a node, ground to top.
func _tall(node: Node3D) -> float:
	var lo := INF
	var hi := -INF
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var b := mi.global_transform * mi.get_aabb()
		lo = minf(lo, b.position.y)
		hi = maxf(hi, b.end.y)
	return (hi - lo) * 100.0

## Every 2D layer and top-level control off, so the frame is the world alone.
func _hide_ui() -> void:
	if m.aim_line:
		m.aim_line.visible = false
		m.aim_line.layers = 0
	for n in main.get_tree().root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	for n in m.find_children("*", "Label3D", true, false):
		(n as Label3D).visible = false
	for n in main.get_children():
		if n is Control:
			(n as Control).visible = false
