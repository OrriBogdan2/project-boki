extends RefCounted
## --hitbox-size-shots --shots-dir=<dir>: all twelve Wardens standing in a row at gameplay zoom, each
## with the ground circle that is its hitbox (run under xvfb with a renderer). Writes <dir>/row.png
## and <dir>/captions.txt.

const DT := 1.0 / 60.0
const GAP := 2.0       # m between neighbours (two rows of six)

func run(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for b in m.breaks:
		b["dead"] = true
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	var W: World = m.world
	var home := Vector3.ZERO
	for z in range(8, W.h - 8, 3):
		for x in range(14, W.w - 24, 3):
			if home == Vector3.ZERO and _flat(W, x, z):
				home = Vector3(x + 0.5, int(W.level[W.idx(x, z)]) * World.LEVEL, z + 0.5)
	var ids := Arch.ORDER
	var names := []
	var row: Array = []
	for i in ids.size():
		var a: String = ids[i]
		var at := home + Vector3((float(i % 6) - 2.5) * GAP, 0, 1.0 + 2.6 * float(i / 6))
		var h := m.make_hunter("S%d" % i, i + 1, Arch.weight(a), Arch.bare_title(a), "idle", {}, at, {"arch": a})
		h.face = PI
		row.append(h)
		names.append("%s %.3f" % [Arch.bare_title(a), h.r])
	m.player.teleport(home + Vector3(0, 0, 30))
	if m.hud:
		m.hud.visible = false
	for k in 20:
		m.step(DT)
		for h in row:
			h.teleport(h.pos)
			h.vel = Vector3.ZERO
		for h in m.hunters: h.render(DT, 1.0)
		m.cam.snap(home + Vector3(0, 0, 2.3))
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	var cam := main.get_viewport().get_camera_3d()
	var tl := cam.unproject_position(home + Vector3(-6.5, 2.0, 0.0))
	var br := cam.unproject_position(home + Vector3(6.5, 0.0, 4.2))
	var rg := Rect2i(Vector2i(tl), Vector2i(br - tl)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(rg)
	crop.resize(1280, int(crop.get_height() * 1280.0 / crop.get_width()), Image.INTERPOLATE_LANCZOS)
	crop.save_png(dir.path_join("row.png"))
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	f.store_line("row.png: twelve Wardens, two rows, on hitbox circles. In order (hit_r m): %s." % ", ".join(names))
	f.close()
	print("HBSHOTS ", crop.get_size(), " ", dir)
	main.get_tree().quit(0)

func _flat(W: World, x: int, z: int) -> bool:
	var lv: int = int(W.level[W.idx(x, z)])
	for dz in range(-3, 8):
		for dx in range(-9, 10):
			var i: int = W.idx(x + dx, z + dz)
			var odd: bool = W.stairs.has(i) or W.walls.has(i) or W.props.has(i) or W.bridge.has(i) or W.bush.has(i)
			if W.kind[i] != World.T_GROUND or int(W.level[i]) != lv or odd:
				return false
	return true
