extends "res://tools/gameplay_media.gd"
## --standout-shots --shots-dir=<dir> (needs a renderer): how well Hunters stand off the ground at the match camera.
## Kael (you) with Vex and Sparkle beside him and Grimble and Neve as rivals, in a row on a meadow, a storm and a
## gloom island, at the match's own start camera, 1920x1080. Per ground: <ground>.png (as played) and
## <ground>_key.png (the same frame with each body flat in its own KEY colour: rings and shadows as played), so
## tools/standout_measure.py masks each body exactly; standout.json holds each Hunter's screen box and key.

const SIZE := Vector2i(1920, 1080)
const GROUNDS := ["meadow", "storm", "gloom"]
const CAST := [["gunslinger", 0], ["mage", 0], ["juggernaut", 0], ["dredge", 1], ["rimewright", 1]]
const GAP := 2.8  # m between the Hunters in the row
const SPOT_R := 9  # cells round a spot that must all be the same island for it to count
const SKIP := ["Glider", "TeamRing"]  # not body: they stay as played in the key frame
const KEY := [Color(1, 0, 1), Color(0, 1, 1), Color(1, 1, 0), Color(0, 0, 1), Color(1, 0, 0)]


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	main.get_window().size = SIZE
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Settings.v["tips"] = false
	await _start("juggernaut", "cindle")
	var row: Array[Hunter] = []
	for i in CAST.size():
		var arch: String = CAST[i][0]
		row.append(m.player if arch == "juggernaut" else _hunter("s%d" % i, CAST[i][1], arch, "pebbit", m.player.pos))
	for h in row:
		h.ctrl = "idle"
	var out := {}
	for g in GROUNDS:
		var at := _spot(g)
		if at == Vector3.INF:
			print("STANDOUT no %s island" % g)
			continue
		out[g] = await _shoot(g, at, row)
	var f := FileAccess.open(dir.path_join("standout.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("STANDOUT done %s" % dir)
	main.get_tree().quit(0)


## The cell of biome `g` with the most same-island land round it, as a world point on the ground.
func _spot(g: String) -> Vector3:
	var w := m.world
	var best := Vector3.INF
	var best_n := -1
	for x in range(SPOT_R, w.w - SPOT_R, 3):
		for z in range(SPOT_R, w.h - SPOT_R, 3):
			if w.biome_at(x, z) != g or _bushy(x, z):
				continue
			var ii := w.island_of(x, z)
			var n := 0
			for dx in range(-SPOT_R, SPOT_R + 1, 3):
				for dz in range(-SPOT_R, SPOT_R + 1, 3):
					n += int(w.island_of(x + dx, z + dz) == ii)
			if n > best_n:
				best_n = n
				best = Vector3(x + 0.5, w.ground_at(x + 0.5, z + 0.5), z + 0.5)
	return best


## Any bush in the row's strip (a Hunter in one is drawn see-through).
func _bushy(x: int, z: int) -> bool:
	for dx in range(-8, 9):
		for dz in range(-3, 4):
			if m.world.in_bush(x + dx, z + dz):
				return true
	return false


func _shoot(g: String, at: Vector3, row: Array[Hunter]) -> Dictionary:
	for i in row.size():
		var p := _ground(at + Vector3((i - 2) * GAP, 0, 0))
		row[i].teleport(p)
		row[i].face = PI * 0.85  # three-quarter toward the camera
	for _i in 30:
		_purge()
		m.step(STEP)
	m.hud.msgs.clear()  # (the island's name card would cover the right of the row)
	m.cam.snap(row[2].pos)
	for _i in 8:
		m.cam.follow(row[2].pos, FRAME, false)
		for h in row:
			h.render(FRAME, 1.0)
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("%s.png" % g))
	var boxes := {}
	var was := {}
	for i in row.size():
		var key := StandardMaterial3D.new()
		key.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		key.albedo_color = KEY[i]
		boxes[row[i].arch] = {"box": _box(row[i]), "team": row[i].team, "key": KEY[i].to_html(false)}
		_key(row[i].model, key, was)
	await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("%s_key.png" % g))
	for gi in was:
		(gi as GeometryInstance3D).material_override = was[gi]
	return {"hunters": boxes, "cam_m": m.cam.dist * m.cam.zoom}


## Every body mesh under `n` drawn flat in `key`; `was` keeps the overrides they had.
func _key(n: Node, key: Material, was: Dictionary) -> void:
	for c in n.get_children():
		if c.name in SKIP:
			continue
		if c is GeometryInstance3D:
			was[c] = (c as GeometryInstance3D).material_override
			(c as GeometryInstance3D).material_override = key
		_key(c, key, was)


## The model's screen box at 1080p (its meshes' bounds; the viewport is content-scaled, hence `k`).
func _box(h: Hunter) -> Array:
	var k := 1080.0 / main.get_viewport().get_visible_rect().size.y
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for mi in h.model.find_children("*", "MeshInstance3D", true, false):
		if mi.get_parent().name in SKIP or mi.name in SKIP:
			continue
		var aabb: AABB = (mi as MeshInstance3D).get_aabb()
		for q in 8:
			var sp := m.cam.unproject_position(mi.global_transform * aabb.get_endpoint(q)) * k
			lo = lo.min(sp)
			hi = hi.max(sp)
	return [lo.x, lo.y, hi.x, hi.y]
