extends RefCounted
## Review screenshots in a live match (xvfb with a renderer), into --shots-dir=<dir>:
##   --reticle-shots: the reticle in three styles (the default and two custom ones), each as the full frame
##     and a 3x crop round the cursor
##   --reticle-hunters-shots: every Hunter in the Training Area (title-screen Arena), the reticle at rest, mid-bloom,
##     on a hit and on a crit, as one 3x crop round the cursor per hunter (a row of four per hunter)
##   --ping-shots: your ping on an enemy (red, "Enemy") and a teammate's loot ping off screen (edge arrow),
##     with the minimap
## Never touches the save; the settings it sets live in the run's own XDG_DATA_HOME.

const STYLES := [
	["reticle_default", {}],
	["reticle_cross_yellow", {"reticle_shape": "cross", "reticle_col": "yellow", "reticle_size": 1.4}],
	["reticle_circle_dot_cyan",
		{"reticle_shape": "circle_dot", "reticle_col": "cyan", "reticle_alpha": 0.8, "reticle_outline": false}],
]
const AT := Vector2(0.62, 0.42)      # where the cursor rests, as a fraction of the window
const CROP := Vector2i(160, 110)     # px round the cursor, scaled 3x

var main: Node
var m: Match
var dir := "user://shots"

func run(main_node: Node, what: String) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	m = Match.new()
	main.add_child(m)
	var opts := {"teams": 2, "squad": 2, "tier": 0, "length": 1500.0, "seed": 4242, "no_drop": true}
	if what == "hunters":
		opts = Match.arena_opts()
	await m.start(opts)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)      # (the screen fade from start-up still covers the view)
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
	else:
		await _reticles()
	main.get_tree().quit(0)

func _reticles() -> void:
	for st in STYLES:
		Settings.reset_all()
		for key in st[1]:
			Settings.set_v(key, st[1][key])
		var img := await _frame()
		img.save_png(dir.path_join(String(st[0]) + ".png"))
		var c := Vector2i(Vector2(img.get_size()) * AT)
		var crop := img.get_region(Rect2i(c - CROP / 2, CROP))
		crop.resize(CROP.x * 3, CROP.y * 3, Image.INTERPOLATE_NEAREST)
		crop.save_png(dir.path_join(String(st[0]) + "_zoom.png"))
		print("RETICLESHOTS %s" % st[0])

## Each Hunter, picked in the Training Area: rest, bloom, hit, crit; one strip per hunter and the cursor
## full frame of the first. Hits go through the HUD the way real ones do (hitmarker), a beat before the shot.
func _hunters() -> void:
	Settings.reset_all()
	Settings.set_v("tips", false)
	_pin_reticle()
	main.get_viewport().gui_disable_input = true      # (no tooltip pops up under the real cursor)
	var strip_w := CROP.x * 3 * 4
	for id in Arch.ids():
		m.arena.set_arch(String(id), Arch.signature(String(id)))
		for pn in m.hud.ui_extra:      # (the practice bar: its tooltips and its hide-the-reticle hover follow
			if pn is Control:          # a desktop worker's real cursor, wherever that rests)
				pn.visible = false
		var tiles := []
		for st in ["rest", "bloom", "hit", "crit"]:
			# (the state is held every frame up to the shot: a 0.14 s flash or a decaying bloom would be gone
			# by the capture on a slow renderer)
			var hold := func():
				m.player.recoil = 1.0 if st == "bloom" else 0.0
				if st == "hit" or st == "crit":
					m.hud.hitmarker(st == "crit")
			var img := await _frame(12, hold)
			var crop := img.get_region(Rect2i(_cursor_px(img) - CROP / 2, CROP))
			crop.resize(CROP.x * 3, CROP.y * 3, Image.INTERPOLATE_NEAREST)
			tiles.append(crop)
		var strip := Image.create(strip_w, CROP.y * 3, false, Image.FORMAT_RGBA8)
		for i in tiles.size():
			strip.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, tiles[i].get_size()), Vector2i(i * CROP.x * 3, 0))
		strip.save_png(dir.path_join("hunter_%s.png" % id))
		print("RETICLESHOTS hunter_%s" % id)

func _pings() -> void:
	var P := m.player
	Settings.set_v("tips", false)      # (the kit card and tips would cover the markers)
	var foe: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	var mate: Hunter = m.hunters.filter(func(h): return h != P and h.team == P.team)[0]
	foe.teleport(_level_spot(P.pos, [Vector3(-5, 0, 3), Vector3(-3, 0, 5), Vector3(0, 0, 5), Vector3(-5, 0, -2)]))
	mate.teleport(m.world.free_spot_near(P.pos + Vector3(3, 0, 4), [], 1.0, 0.5, 8.0))
	foe.reveal_t = 30.0      # (in plain sight whatever the grass and your view cone)
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
		var at := main.get_viewport().get_visible_rect().size * AT
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
	var half := Vector2(CROP / 2)
	return Vector2i(px.clamp(half, Vector2(img.get_size()) - half))

## A few frames with the cursor held at AT, then the frame as an image.
func _frame(frames := 20, hold := Callable()) -> Image:
	var vp := main.get_viewport()
	for i in frames:
		vp.warp_mouse(vp.get_visible_rect().size * AT)
		if hold.is_valid():
			hold.call()
		await main.get_tree().process_frame
	return vp.get_texture().get_image()
