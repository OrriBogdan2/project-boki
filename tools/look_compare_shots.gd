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
	for _i in 60:
		_purge()
		m.step(STEP)
	var kin_at := _ground(base + Vector3(2.4, 0, 1.4))
	p.kin.state = "active"  # out beside the hero (the sim sends it back to the shoulder when stepped, so no more steps)
	p.kin.teleport(kin_at)
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
		m.cam.zoom_to = v[2]
		m.cam.follow(p.pos, FRAME, false)
		for h in m.hunters:
			h.render(FRAME, 1.0)
		p.kin.render(FRAME, 1.0)
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("shot_%s.png" % v[0]))
	var east := (m.cam.unproject_position(p.pos + Vector3(10, 0, 0)) - m.cam.unproject_position(p.pos)) * 1080.0 / main.get_viewport().get_visible_rect().size.y
	for h in m.hunters:
		var r := _measure(h)
		r["variant"] = v[0]
		r["ppm_10m"] = east.x
		r["cam_dist"] = m.cam.dist * m.cam.zoom
		rows.append(r)
		print("LOOKCMP %s %s" % [v[0], str(r)])


const WARDEN_SKIN := preload("res://tools/warden_skin.gd")
const SKIP := ["Glider", "Gun", "Shield", "TeamRing"]


## The body's (no weapon, glider or ring) height in metres with the lean and turn taken out, and the px its
## skinned points cover on screen at 1080p (the viewport is content-scaled, hence `k`).
func _measure(h: Hunter) -> Dictionary:
	var k := 1080.0 / main.get_viewport().get_visible_rect().size.y
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	var ylo := 1e9
	var yhi := -1e9
	var un := h.model.global_transform.basis.orthonormalized().inverse()
	var stack: Array = [h.model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.name in SKIP:
			continue
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D and (n as MeshInstance3D).is_visible_in_tree():
			var mi := n as MeshInstance3D
			var pts := PackedVector3Array()
			if mi.skin:
				pts = WARDEN_SKIN.points(mi)
			else:
				for q in 8:
					pts.append(mi.global_transform * mi.get_aabb().get_endpoint(q))
			for wp in pts:
				var sp := m.cam.unproject_position(wp) * k
				lo = lo.min(sp)
				hi = hi.max(sp)
				var u := un * wp
				ylo = minf(ylo, u.y)
				yhi = maxf(yhi, u.y)
	return {
		"hunter": str(m.hunters.find(h)),
		"vis_k": h.vis_k,
		"body_h_m": yhi - ylo,
		"body_px_h": hi.y - lo.y,
		"body_px_w": hi.x - lo.x,
		"bbox": [lo.x, lo.y, hi.x, hi.y],
	}
