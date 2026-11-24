extends RefCounted
## --tenzo-stone-video --shots-dir=<dir>: Tenzo's Stone Row (E) and Basalt Spine (R), through the game's own camera
## on a flat lane, for the owner's before/after (11-13: his stone matches the new arm, blue slate and teal). Recorded
## like tools/gameplay_media.gd (a child Godot under the movie writer, 30 fps, <dir>/clip1.avi); run it on a GPU
## worker (jobq --needs gpu). Run it the same on main (the "before" take) and on the branch.

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


func _film() -> void:
	await gm._start("dolm", "cindle")
	var m: Match = gm.m
	var hero: Hunter = m.player
	if hero.kin:
		(hero.kin as Kin).stow()
	if m.hud:
		m.hud.visible = false
	hero.lvl = maxi(hero.lvl, int(Hunter.ULT_AT[0]))
	var at := _lane(m.world, hero.pos)
	hero.teleport(at)
	var mid := at + Vector3(4.0, 0, 0)
	gm._zoom(ZOOM)
	var look := func(_t: float) -> void:
		hero.inp["aim"] = hero.pos + Vector3(20, 0.9, 0)
		hero.inp["move"] = Vector2.ZERO
	await gm._go(0.8, look, func(_t): return mid)
	# Basalt Spine first, aimed a few metres out so the whole ridge sits in frame (not hidden behind E's rocks)
	var ult_look := func(_t: float) -> void:
		hero.inp["aim"] = hero.pos + Vector3(6.0, 0.9, 0)
		hero.inp["move"] = Vector2.ZERO
	hero.ak.cd["x"] = 0.0
	ult_look.call(0.0)
	HunterKeys.ult_pressed(hero)  # Basalt Spine (a tap: the ridge centres at the cursor)
	await gm._go(3.0, ult_look, func(_t): return mid)
	print("MEDIA_TSV rocks standing after R: %d" % m.verbs.walls.filter(func(w): return w.get("rock", false)).size())
	for k in 2:  # Stone Row, twice: the first rises, the second a step on
		hero.ak.cd["e"] = 0.0
		hero.ak.use_e()
		await gm._go(2.2, look, func(_t): return mid)
		var rocks: int = m.verbs.walls.filter(func(w): return w.get("rock", false)).size()
		print("MEDIA_TSV rocks standing after E %d: %d" % [k + 1, rocks])
	# the same from a close camera: the rocks and the arm side by side
	gm._zoom(0.9)
	await gm._go(1.5, look, func(_t): return hero.pos + Vector3(2.0, 0.8, 0))


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
