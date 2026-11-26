extends RefCounted
## Review screenshots in a live match (xvfb with a renderer), into --shots-dir=<dir>:
##   --reticle-shots: the reticle in three styles (the default and two custom ones), each as the full frame
##     and a 3x crop round the cursor
##   --reticle-hunters-shots: every Hunter in the Training Area (title-screen Arena), the reticle at rest, mid-bloom,
##     on a hit and on a crit, as one 3x crop round the cursor per hunter (a row of four per hunter)
##   --reticle-looks-shots: every Hunter's own look (ReticleLooks) at rest at 4x on dark, light and grass swatch
##     rows with row labels, one column per hunter (reticle_looks_1126b_swatches.png)
##   --reticle-proof-shots: for the owner, on a real GPU at 1920x1080 (set --resolution): every Hunter's full frame
##     at rest and firing over the match's grass, and contact sheets of 3 tiles a row with a 2x zoom
##   --ping-shots: your ping on an enemy (red, "Enemy") and a teammate's loot ping off screen (edge arrow),
##     with the minimap
##   --hit-marker-shots: the hit tick on a landed hit and the knock tick, each full frame and 3x crop
## Never touches the save; the settings it sets live in the run's own XDG_DATA_HOME.

const STYLES := [
	["reticle_default", {}],
	["reticle_cross_yellow", {"reticle_shape": "cross", "reticle_col": "yellow", "reticle_size": 1.4}],
	[
		"reticle_circle_dot_cyan",
		{"reticle_shape": "circle_dot", "reticle_col": "cyan", "reticle_alpha": 0.8, "reticle_outline": false}
	],
]
const AT := Vector2(0.62, 0.42)  # where the cursor rests, as a fraction of the window
const CROP := Vector2i(160, 110)  # px round the cursor, scaled 3x
const LOOK_CELL := 96.0  # px: one look's tile on the swatch sheet
const LOOK_LABEL_W := 130.0  # px: the row labels' column on the swatch sheet
const LOOK_ZOOM := 3.6  # the swatch sheet draws each reticle this many times its size
const LOOK_ROWS := [["dark ground", "1b1f1c"], ["light ground", "ece6cc"], ["grass", "5f8f4a"]]  # [label, ground]
const PROOF_AT := Vector2(0.6, 0.5)  # the proof's cursor: mid-screen, just off the Hunter the camera follows
const PROOF_SCAN := 600  # world units each way the meadow search covers, in steps of PROOF_STEP
const PROOF_STEP := 6
const PROOF_RES := Vector2i(1920, 1080)  # the full-screen proof frames
const TILES_PER_SHEET := 6  # Hunters on one contact sheet (rows of 3)
const TILE_W := 640  # px: one tile of the contact sheet
const TILE_GAP := 8
const TILE_NAME_H := 60  # px: the Hunter's name band
const ZOOM_CROP := Vector2i(160, 100)  # px round the cursor, shown 2x under the tile
const TILE_ZOOM_H := 200  # px: ZOOM_CROP at 2x
const TILE_H := TILE_NAME_H + 360 + TILE_ZOOM_H  # name, the 16:9 frame at tile width, the zoom crops

var main: Node
var m: Match
var dir := "user://shots"
var cursor_at := AT  # where the cursor rests, as a fraction of the window


func run(main_node: Node, what: String) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	if what == "looks" or what == "proof":
		main.get_window().size = PROOF_RES
	if what == "looks":
		await _reveal()
		await _looks()
		main.get_tree().quit(0)
		return
	if what == "proof":
		cursor_at = PROOF_AT
	m = Match.new()
	main.add_child(m)
	var opts := {"teams": 2, "squad": 2, "tier": 0, "length": 1500.0, "seed": 4242, "no_drop": true}
	if what == "hunters":
		opts = Match.arena_opts()
	m.start(opts)
	await _reveal()
	m.cam.lead = 0.0
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	for h in m.hunters:
		if h != m.player:
			h.ctrl = "idle"
	if what == "ping":
		await _pings()
	elif what == "hunters":
		await _hunters()
	elif what == "proof":
		await _proof()
	elif what == "hit":
		await _hits()
	else:
		await _reticles()
	main.get_tree().quit(0)


func _reticles() -> void:
	for st in STYLES:
		Settings.reset_all()
		for key in st[1]:
			Settings.set_v(key, st[1][key])
		_save(await _frame(), String(st[0]))
		print("RETICLESHOTS %s" % st[0])


## Each Hunter, picked in the Training Area: rest, bloom, hit, crit; one strip per hunter and the cursor
## full frame of the first. The hit tick is raised on the HUD's Reticle the way a landed hit does, held up to the shot.
func _hunters() -> void:
	Settings.reset_all()
	Settings.set_v("tips", false)
	_pin_reticle()
	main.get_viewport().gui_disable_input = true  # (no tooltip pops up under the real cursor)
	var strip_w := CROP.x * 3 * 4
	for id in Arch.ids():
		m.arena.set_arch(String(id), Arch.signature(String(id)))
		for pn in m.hud.ui_extra:  # (the practice bar: its tooltips and its hide-the-reticle hover follow
			if pn is Control:  # a desktop worker's real cursor, wherever that rests)
				pn.visible = false
		await main.get_tree().create_timer(2.5).timeout  # (the swap's kit card fades out first)
		var tiles := []
		for st in ["rest", "bloom", "hit", "crit"]:
			# (the state is held every frame up to the shot: a 0.14 s flash or a decaying bloom would be gone
			# by the capture on a slow renderer)
			var hold := func():
				m.player.recoil = 1.0 if st == "bloom" else 0.0
				if st == "hit" or st == "crit":
					m.hud.reticle.raise(false)
					m.hud.reticle.flavour(st == "crit", false)
			var img := await _frame(12, hold)
			var crop := img.get_region(Rect2i(_cursor_px(img) - Vector2i(CROP / 2.0), CROP))
			crop.resize(CROP.x * 3, CROP.y * 3, Image.INTERPOLATE_NEAREST)
			tiles.append(crop)
		var strip := Image.create(strip_w, CROP.y * 3, false, Image.FORMAT_RGBA8)
		for i in tiles.size():
			strip.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, tiles[i].get_size()), Vector2i(i * CROP.x * 3, 0))
		strip.save_png(dir.path_join("hunter_%s.png" % id))
		print("RETICLESHOTS hunter_%s" % id)


## Lifts the screen fade from start-up, which still covers the view.
func _reveal() -> void:
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)


## Every Hunter's own look at rest on the grounds of LOOK_ROWS, drawn at LOOK_ZOOM: a small sheet with a
## label on each row and each Hunter's name under its column.
func _looks() -> void:
	Settings.reset_all()
	var ids := Arch.ids()
	var size := Vector2i(int(LOOK_LABEL_W + LOOK_CELL * ids.size()), int(LOOK_CELL) * LOOK_ROWS.size() + 22)
	var img := await _compose(size, _draw_looks)
	img.save_png(dir.path_join("reticle_looks_1126b_swatches.png"))
	print("RETICLESHOTS reticle_looks_1126b_swatches %d hunters" % ids.size())


func _draw_looks(cv: Control) -> void:
	var ids := Arch.ids()
	var font := ThemeDB.fallback_font
	cv.draw_rect(Rect2(Vector2.ZERO, cv.size), Color.BLACK)
	for row in LOOK_ROWS.size():
		var label_at := Vector2(6.0, (row + 0.5) * LOOK_CELL + 5.0)
		cv.draw_string(font, label_at, String(LOOK_ROWS[row][0]), HORIZONTAL_ALIGNMENT_LEFT, LOOK_LABEL_W, 16)
	for i in ids.size():
		var id := String(ids[i])
		for row in LOOK_ROWS.size():
			var origin := Vector2(LOOK_LABEL_W + i * LOOK_CELL, row * LOOK_CELL)
			var tile := Rect2(origin, Vector2.ONE * LOOK_CELL)
			cv.draw_rect(tile.grow(-1.0), Color(String(LOOK_ROWS[row][1])))
			cv.draw_set_transform(tile.get_center(), 0.0, Vector2.ONE * LOOK_ZOOM)
			Reticle.draw(cv, Vector2.ZERO, 0.0, Reticle.accent(id), Color(0, 0, 0, 0), Reticle.look_of(id))
			cv.draw_set_transform(Vector2.ZERO)
		var name_at := Vector2(LOOK_LABEL_W + i * LOOK_CELL, LOOK_CELL * LOOK_ROWS.size() + 16.0)
		var label := String(Arch.def(id).get("base_name", id))
		cv.draw_string(font, name_at, label, HORIZONTAL_ALIGNMENT_CENTER, LOOK_CELL, 13, Arch.color(id).lightened(0.3))


## Every Hunter in a normal match at the default match camera, 1920x1080 on a real GPU: the reticle mid-screen over
## grass at rest and then firing (the fire action held, bloom open). Each full frame is saved
## (reticle_looks_1126b_<id>_rest.png, _fire.png) and then the contact sheets, TILES_PER_SHEET Hunters each.
func _proof() -> void:
	Settings.reset_all()
	Settings.set_v("tips", false)
	_pin_reticle()
	main.get_viewport().gui_disable_input = true
	m.player.teleport(_meadow_spot())
	var tiles := []
	for id in Arch.ids():
		m.player.reclass(Arch.weight(String(id)), String(id), Arch.signature(String(id)))
		Match._trim_shadows(m.player)
		await main.get_tree().create_timer(2.5).timeout
		var rest := await _frame(12)
		var fire := await _frame(12, _hold_fire)
		Input.action_release("fire")
		for st in [["rest", rest], ["fire", fire]]:
			var img: Image = st[1]
			if img.get_size() != PROOF_RES:
				push_error("RETICLESHOTS frame is %s, not %s" % [img.get_size(), PROOF_RES])
				main.get_tree().quit(1)
				return
			img.save_png(dir.path_join("reticle_looks_1126b_%s_%s.png" % [id, st[0]]))
		tiles.append([String(Arch.def(id).get("base_name", id)), Arch.color(String(id)), rest, fire])
		tiles[-1].append_array([ImageTexture.create_from_image(rest), ImageTexture.create_from_image(fire)])
		print("RETICLESHOTS proof %s ammo %d" % [id, m.player.ammo])
	for part in ceili(tiles.size() / float(TILES_PER_SHEET)):
		var chunk := tiles.slice(part * TILES_PER_SHEET, (part + 1) * TILES_PER_SHEET)
		var rows := ceili(chunk.size() / 3.0)
		var size := Vector2i(TILE_W * 3 + TILE_GAP * 2, rows * TILE_H + (rows - 1) * TILE_GAP)
		var sheet := await _compose(size, _draw_tiles.bind(chunk))
		sheet.save_png(dir.path_join("reticle_looks_1126b_sheet%d.png" % (part + 1)))
	print("RETICLESHOTS proof sheets done")


## A free spot well inside a meadow island (the match's plain grass), the first found on a coarse scan.
func _meadow_spot() -> Vector3:
	var w := m.world
	for x in range(-PROOF_SCAN, PROOF_SCAN, PROOF_STEP):
		for z in range(-PROOF_SCAN, PROOF_SCAN, PROOF_STEP):
			var inside := true
			for d in [Vector2.ZERO, Vector2(12, 0), Vector2(-12, 0), Vector2(0, 12), Vector2(0, -12)]:
				var q := Vector2(x, z) + d
				inside = inside and not w.is_void(q.x, q.y) and w.biome_at(q.x, q.y) == "meadow"
			if inside:
				return w.free_spot_near(Vector3(x, w.ground_at(x, z), z), [], 1.0, 0.5, 4.0)
	push_error("RETICLESHOTS no meadow spot found")
	return m.player.pos


## Holds the fire action and the weapon's bloom, so the frame shows the reticle in use.
func _hold_fire() -> void:
	Input.action_press("fire")
	m.player.recoil = 1.0


## One tile per Hunter: its name large, the rest frame scaled to the tile width, and under it 2x crops round the
## reticle at rest and firing (a tile is [name, colour, rest image, fire image, rest texture, fire texture]).
func _draw_tiles(cv: Control, tiles: Array) -> void:
	var font := ThemeDB.fallback_font
	cv.draw_rect(Rect2(Vector2.ZERO, cv.size), Color(0.07, 0.07, 0.08))
	for i in tiles.size():
		var t: Array = tiles[i]
		var o := Vector2(i % 3 * (TILE_W + TILE_GAP), i / 3 * (TILE_H + TILE_GAP))
		cv.draw_string(font, o + Vector2(12, 46), String(t[0]), HORIZONTAL_ALIGNMENT_LEFT, TILE_W, 44, t[1])
		var shot := Vector2(TILE_W, TILE_W * 9.0 / 16.0)
		cv.draw_texture_rect(t[4], Rect2(o + Vector2(0, TILE_NAME_H), shot), false)
		var cursor := Vector2(PROOF_RES) * cursor_at
		for j in 2:
			var at := o + Vector2(j * TILE_W / 2.0, TILE_NAME_H + shot.y)
			var src := Rect2(cursor - Vector2(ZOOM_CROP) / 2.0, Vector2(ZOOM_CROP))
			cv.draw_texture_rect_region(t[4 + j], Rect2(at, Vector2(TILE_W / 2.0, TILE_ZOOM_H)), src)
			cv.draw_string(font, at + Vector2(8, 22), ["rest", "firing"][j], HORIZONTAL_ALIGNMENT_LEFT, -1, 20)


## Draws `painter` on a Control in a SubViewport of `size` and returns what it drew.
func _compose(size: Vector2i, painter: Callable) -> Image:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cv := Control.new()
	cv.size = Vector2(size)
	cv.draw.connect(painter.bind(cv))
	vp.add_child(cv)
	main.add_child(vp)
	for i in 4:
		await main.get_tree().process_frame
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


## The tick a landed hit raises and the knock one (the rival's hp at 0 for that frame), slowed to
## a twentieth so the shot lands while it shows.
func _hits() -> void:
	var foe: Hunter = m.hunters.filter(func(h): return h.team != m.player.team)[0]
	for row in [["hit_tick", false], ["hit_tick_knock", true]]:
		await _frame()
		var hp := foe.hp
		if row[1]:
			foe.hp = 0.0
		Engine.time_scale = 0.05
		CombatBus.hit_landed.emit(m.player, foe, 10.0, ["primary"])
		foe.hp = hp
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		_save(main.get_viewport().get_texture().get_image(), String(row[0]))
		Engine.time_scale = 1.0
		print("HITSHOTS %s" % row[0])


func _save(img: Image, file: String) -> void:
	img.save_png(dir.path_join(file + ".png"))
	var c := Vector2i(Vector2(img.get_size()) * AT)
	var crop := img.get_region(Rect2i(c - Vector2i(Vector2(CROP) / 2.0), CROP))
	crop.resize(CROP.x * 3, CROP.y * 3, Image.INTERPOLATE_NEAREST)
	crop.save_png(dir.path_join(file + "_zoom.png"))


func _pings() -> void:
	var P := m.player
	Settings.set_v("tips", false)  # (the kit card and tips would cover the markers)
	var foe: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	var mate: Hunter = m.hunters.filter(func(h): return h != P and h.team == P.team)[0]
	foe.teleport(_level_spot(P.pos, [Vector3(-5, 0, 3), Vector3(-3, 0, 5), Vector3(0, 0, 5), Vector3(-5, 0, -2)]))
	mate.teleport(m.world.free_spot_near(P.pos + Vector3(3, 0, 4), [], 1.0, 0.5, 8.0))
	foe.reveal_t = 30.0  # (in plain sight whatever the grass and your view cone)
	await _frame()
	var kind := PingInput.place_world(m, m.cam.unproject_position(foe.pos + Vector3(0, 0.9, 0)))
	print("PINGSHOTS on the rival: %s" % kind)
	var far: Vector3 = P.pos + Vector3(-40, 0, 25)
	if not m.chests.is_empty():
		far = m.chests[0]["pos"]
	m.squad_ping(mate, far, false, "loot")
	var img := await _frame()
	img.save_png(dir.path_join("ping_enemy_and_loot.png"))
	print("PINGSHOTS ping_enemy_and_loot")


## The first of `offsets` from `at` on the same ground level (a rival placed off a ledge falls out of sight).
func _level_spot(at: Vector3, offsets: Array) -> Vector3:
	for off in offsets:
		var p: Vector3 = at + off
		if not m.world.is_void(p.x, p.z) and absf(m.world.ground_at(p.x, p.z) - at.y) < 0.3:
			return p
	return at + offsets[0]


## Pins the HUD reticle at AT (a desktop worker's real cursor may not take the warp, and wherever it sits
## the HUD would draw there, under whatever panel covers it). Older HUDs without the pin keep the mouse.
func _pin_reticle() -> void:
	if "ret" in m.hud and "pin" in m.hud.ret:
		var at := main.get_viewport().get_visible_rect().size * cursor_at
		m.hud.ret.pin = m.hud.c.get_global_transform_with_canvas().affine_inverse() * at


## Where the HUD drew the reticle, in image pixels (the pin or the HUD canvas's mouse, through the canvas
## transform, scaled to the image size).
func _cursor_px(img: Image) -> Vector2i:
	var vp := main.get_viewport()
	var local: Vector2 = m.hud.c.get_local_mouse_position()
	if "ret" in m.hud and "pin" in m.hud.ret and m.hud.ret.pin != Vector2.INF:
		local = m.hud.ret.pin
	var at: Vector2 = m.hud.c.get_global_transform_with_canvas() * local
	var px := at * Vector2(img.get_size()) / vp.get_visible_rect().size
	var half := Vector2(CROP) / 2.0
	return Vector2i(px.clamp(half, Vector2(img.get_size()) - half))


## A few frames with the cursor held at AT, then the frame as an image.
func _frame(frames := 20, hold := Callable()) -> Image:
	var vp := main.get_viewport()
	for i in frames:
		vp.warp_mouse(vp.get_visible_rect().size * cursor_at)
		if hold.is_valid():
			hold.call()
		await main.get_tree().process_frame
	return vp.get_texture().get_image()
