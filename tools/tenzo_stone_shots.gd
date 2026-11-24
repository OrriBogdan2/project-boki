extends RefCounted
## --tenzo-stone-shots --shots-dir=<dir>: stills of Tenzo's stone on the real GPU, through the game's own camera, for
## the colour audit (cobalt + teal, never grey): <dir>/clipN.png with the MEDIA_TSV map printed
## (N -> what). Stone Row (E), Basalt Spine (R), a thrown boulder at a foe, Rock Hop, and his arm eye-level.
## Recorded like tools/tenzo_stone_video.gd (a child Godot under the movie writer; run it with jobq --needs gpu).

const LANE := 16.0  # m of flat ground along +x
const ZOOM := 0.45

var main: Node
var gm


func run(main_node: Node) -> void:
	main = main_node
	gm = load("res://tools/gameplay_media.gd").new()
	gm.main = main
	var child := false
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		child = child or arg == "--media-child"
		if arg.begins_with("--shots-dir="):
			gm.dir = arg.substr(12)
	if String(gm.dir).is_relative_path():
		gm.dir = ProjectSettings.globalize_path("res://").path_join(gm.dir)
	DirAccess.make_dir_recursive_absolute(gm.dir)
	if not child:
		gm._record("1920x1080")
		return
	Save.no_write = true
	Settings.v["tips"] = false
	await _film()
	print("MEDIA_DONE clip=1")
	main.get_tree().quit(0)


## A still `at` s into the next take, saved as clip<n>.png.
func _snap(n: int, what: String, at: float) -> void:
	gm.clip = n
	gm.still_at = at
	print("MEDIA_TSV clip%d = %s" % [n, what])


func _film() -> void:
	await gm._start("dolm", "cindle")
	var m: Match = gm.m
	var hero: Hunter = m.player
	var kit: DolmKit = hero.ak
	if hero.kin:
		(hero.kin as Kin).stow()
	if m.hud:
		m.hud.visible = false
	hero.lvl = maxi(hero.lvl, int(Hunter.ULT_AT[0]))
	var at := _lane(m.world, hero.pos)
	hero.teleport(at)
	var foe: Hunter = gm._hunter("foe", 1, "juggernaut", "pebbit", gm._ground(at + Vector3(9.0, 0, 0)))
	foe.teleport(foe.pos)
	var mid := at + Vector3(4.0, 0, 0)
	gm._zoom(ZOOM)
	var look := func(_t: float) -> void:
		foe.hp = foe.max_hp
		hero.inp["aim"] = foe.pos + Vector3(0, 0.9, 0)
		hero.inp["move"] = Vector2.ZERO
	await gm._go(0.8, look, func(_t): return mid)
	# Stone Row (E)
	hero.ak.cd["e"] = 0.0
	_snap(1, "Stone Row (E) rising, game camera", 0.5)
	hero.ak.use_e()
	await gm._go(1.0, look, func(_t): return mid)
	_snap(2, "Stone Row standing", 0.6)
	await gm._go(1.2, look, func(_t): return mid)
	# the thrown boulder at the foe
	_snap(3, "thrown boulder in flight", 0.55)
	kit._boulder()
	await gm._go(1.1, look, func(_t): return mid)
	# Basalt Spine (R)
	var ult_look := func(_t: float) -> void:
		foe.hp = foe.max_hp
		hero.inp["aim"] = hero.pos + Vector3(6.0, 0.9, 0)
		hero.inp["move"] = Vector2.ZERO
	hero.ak.cd["x"] = 0.0
	ult_look.call(0.0)
	_snap(4, "Basalt Spine (R) rising", 0.8)
	HunterKeys.ult_pressed(hero)
	await gm._go(3.0, ult_look, func(_t): return mid)
	print("MEDIA_TSV rocks standing after R: %d" % m.verbs.walls.filter(func(w): return w.get("rock", false)).size())
	# Rock Hop (dash): the slab
	var hop_look := func(_t: float) -> void:
		foe.hp = foe.max_hp
		hero.inp["aim"] = hero.pos + Vector3(10, 0.9, 0)
		hero.inp["move"] = Vector2(1, 0)
	hero.dashes = maxf(hero.dashes, 2.0)
	_snap(5, "Rock Hop", 0.5)
	kit.on_dash(false)
	await gm._go(1.6, hop_look, func(_t): return hero.pos)
	# the same close: rocks and arm
	gm._zoom(0.9)
	_snap(6, "close game camera", 0.3)
	await gm._go(0.8, look, func(_t): return hero.pos + Vector3(2.0, 0.8, 0))
	# his arm eye-level: a free camera 2.4 m off, side-on, at chest height
	var cam: Camera3D = m.cam
	var eye := func(_t: float) -> void:
		hero.inp["aim"] = hero.pos + Vector3(0, 0.9, 6)
		hero.inp["move"] = Vector2.ZERO
	_snap(7, "arm eye-level (left side)", 0.5)
	await gm._go(0.9, eye, func(_t): return hero.pos)
	cam.global_position = hero.pos + Vector3(2.4, 1.3, 0.3)
	cam.look_at(hero.pos + Vector3(0, 1.1, 0))
	cam.fov = 45.0
	for _i in 4:
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(gm.dir.path_join("clip7.png"))
	print("MEDIA_TSV clip7 forced at eye level")


## A spot with LANE m of flat, open ground east of it, near `near`.
func _lane(w: World, near: Vector3) -> Vector3:
	for k in 4000:
		var g: Vector3 = near if k == 0 else w.random_ground()
		var good := true
		for i in 40:
			var x := g.x - 1.0 + (LANE + 1.0) * i / 39.0
			for dz in [-3.0, 0.0, 3.0]:
				if w.is_void(x, g.z + dz) or w.is_block(x, g.z + dz) or absf(w.ground_at(x, g.z + dz) - g.y) > 0.01:
					good = false
		if good:
			return Vector3(floor(g.x) + 0.5, g.y, floor(g.z) + 0.5)
	return near
