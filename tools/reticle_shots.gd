extends RefCounted
## Review screenshots in a live match (xvfb with a renderer), into --shots-dir=<dir>:
##   --reticle-shots: the reticle in three styles (the default and two custom ones), each as the full frame
##     and a 3x crop round the cursor
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
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1500.0, "seed": 4242, "no_drop": true})
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

## A few frames with the cursor held at AT, then the frame as an image.
func _frame() -> Image:
	var vp := main.get_viewport()
	for i in 20:
		vp.warp_mouse(vp.get_visible_rect().size * AT)
		await main.get_tree().process_frame
	return vp.get_texture().get_image()
