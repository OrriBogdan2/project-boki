extends "res://tools/gameplay_media.gd"
## LOCAL ONLY, never committed: --look-compare-shots --shots-dir=<dir>. One staged match (Kael + Vex vs Motley,
## Boki beside Kael), shot at 1920x1080 under several camera / Hunter-size settings; prints model heights and
## each Hunter's on-screen height in px.

const SIZE := Vector2i(1920, 1080)
const THEIRS := {"pitch": 66.0, "dist": 30.2, "fov": 35.3, "rise": 1.2, "name": "theirs"}
# [file tag, style id, zoom, hunter scale]
const VARIANTS := [
	["now", "default", 1.6, 1.0],
	["now_x110", "default", 1.6, 1.10],
	["theirs", "theirs", 1.0, 1.0],
	["theirs_x110", "theirs", 1.0, 1.10],
	["near", "default", 1.0, 1.0],
	["near_x110", "default", 1.0, 1.10],
]


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	main.get_window().size = SIZE
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Settings.v["tips"] = false
	CamRig.styles["theirs"] = THEIRS
	await _start("juggernaut", "cindle")
	var p := m.player
	p.ctrl = "idle"
	var base := _ground(p.pos)
	var mate := _hunter("a1", 0, "gunslinger", "zapple", _ground(base + Vector3(-2.6, 0, 2.2)))
	var foe := _hunter("b0", 1, "ostra", "pebbit", _ground(base + Vector3(6.0, 0, -1.0)))
	var foe2 := _hunter("b1", 1, "rimewright", "wisplet", _ground(base + Vector3(3.2, 0, 5.0)))
	for h in [mate, foe, foe2]:
		h.ctrl = "idle"
	p.teleport(base)
	for _i in 90:
		_purge()
		m.step(STEP)
	var rows := []
	for v in VARIANTS:
		await _variant(v, p, rows)
	var f := FileAccess.open(dir.path_join("measure.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, "\t"))
	f.close()
	print("LOOKCMP done %s" % dir)
	main.get_tree().quit(0)


func _variant(v: Array, p: Hunter, rows: Array) -> void:
	m.cam.use_style(v[1])
	m.cam.hunter_scale = v[3]
	for h in m.hunters:
		h.fit_scale()
	m.cam.zoom = v[2]
	m.cam.zoom_to = v[2]
	m.cam.user_zoom = v[2]
	m.cam.snap(p.pos)
	for _i in 6:
		for _j in 2:
			m.step(STEP)
		m.cam.zoom_to = v[2]
		m.cam.follow(p.pos, FRAME, false)
		for h in m.hunters:
			h.render(FRAME, 1.0)
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("shot_%s.png" % v[0]))
	var east := m.cam.unproject_position(p.pos + Vector3(10, 0, 0)) - m.cam.unproject_position(p.pos)
	for h in m.hunters:
		var r := _measure(h)
		r["variant"] = v[0]
		r["ppm_10m"] = east.x
		r["cam_dist"] = m.cam.dist * m.cam.zoom
		rows.append(r)
		print("LOOKCMP %s %s" % [v[0], str(r)])


## The model's mesh box in metres and the px its projected corners cover on screen.
func _measure(h: Hunter) -> Dictionary:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	var mlo := Vector3(1e9, 1e9, 1e9)
	var mhi := Vector3(-1e9, -1e9, -1e9)
	var inv := h.model.global_transform.affine_inverse()
	for n in h.model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.visible or "Ring" in String(mi.name):
			continue
		var bb := mi.get_aabb()
		for c in 8:
			var q := bb.position + bb.size * Vector3(c & 1, (c >> 1) & 1, (c >> 2) & 1)
			var g := mi.global_transform * q
			var s := m.cam.unproject_position(g)
			lo = lo.min(s)
			hi = hi.max(s)
			var loc := inv * g
			mlo = mlo.min(loc)
			mhi = mhi.max(loc)
	var feet := m.cam.unproject_position(h.global_position)
	var top := m.cam.unproject_position(h.global_position + Vector3(0, 1.76 * h.vis_k, 0))
	var sc := h.model.global_transform.basis.get_scale()
	return {
		"hunter": String(h.name),
		"model_h_local": mhi.y - mlo.y,
		"model_scale_y": sc.y,
		"model_h_m": (mhi.y - mlo.y) * sc.y,
		"vis_k": h.vis_k,
		"bbox_px_h": hi.y - lo.y,
		"bbox_px_w": hi.x - lo.x,
		"bbox": [lo.x, lo.y, hi.x, hi.y],
		"stand176_px": feet.y - top.y,
		"feet": [feet.x, feet.y],
	}
