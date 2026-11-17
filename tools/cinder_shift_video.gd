extends RefCounted
## --cinder-shift-video --shots-dir=<dir> [--cinder-before]: Cinder's Shift for the owner (playtest 11-17), through
## the game's own camera held still over a flat lane, posts on the ground at the start, 3.4 m and 6.8 m. Twice: a
## running Shift on the ground (the Soot Ram), then a running jump with a Shift in it (the poof). --cinder-before
## plays the poof at main's old 6.8 m. Recorded like tools/gameplay_media.gd (a child Godot under the movie writer,
## 30 fps, <dir>/clip1.avi); run it on a GPU worker (jobq --needs gpu). Prints MEDIA_CSHIFT lines with the metres.

const RUN_UP := 2.4  # m of run before the start post
const POSTS := [0.0, 3.4, 6.8]  # m past the start post
const POST_COL := ["ffffff", "ffb040", "ff4040"]
const LANE := 15.0  # m of flat ground needed along +x
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
	await _film("--cinder-before" in OS.get_cmdline_user_args())
	print("MEDIA_DONE clip=1")
	main.get_tree().quit(0)


func _film(before: bool) -> void:
	await gm._start("ashwick", "cindle")
	var m: Match = gm.m
	var hero: Hunter = m.player
	if before:
		hero.ak.dash_def()["air_dist"] = 6.8  # main's poof before this fix
	if hero.kin:
		(hero.kin as Kin).stow()
	if m.hud:
		m.hud.visible = false
	var x0 := _lane(m.world, hero.pos)
	_posts(m, x0)
	var mid := x0 + Vector3(3.4, 0, 0)
	gm._zoom(ZOOM)
	var tag := "before (main): air poof 6.8 m" if before else "after: air poof 3.4 m"
	_label(m, "Cinder Shift  %s   posts 0 / 3.4 / 6.8 m" % tag)
	for k in 2:
		for jump in [false, true]:
			await _take(hero, x0, mid, jump)


## One run past the start post: Shift there (on the ground) or 0.2 s into a jump taken just before it.
func _take(hero: Hunter, x0: Vector3, mid: Vector3, jump: bool) -> void:
	hero.teleport(x0 - Vector3(RUN_UP, 0, 0))
	hero.vel = Vector3.ZERO
	hero.roll_t = 0.0
	hero.dashes = hero.max_dashes()
	hero.ex_cd = 0.0
	hero.inp["move"] = Vector2.ZERO
	hero.inp["aim"] = x0 + Vector3(20, 0.9, 0)
	await gm._go(0.6, func(_t): pass, func(_t): return mid)
	# phase 0 run up, 1 jumped (jump take), 2 Shift pressed, 3 the dash or the landing done: keys let go
	var st := {"phase": 0, "press": Vector3.ZERO, "air": 0, "end": Vector3.ZERO}
	var each := func(_t: float) -> void:
		var phase := int(st["phase"])
		hero.inp["move"] = Vector2(1, 0) if phase < 3 else Vector2.ZERO
		hero.inp["aim"] = hero.pos + Vector3(20, 0.9, 0)
		hero.inp["jump"] = false
		hero.inp["dash"] = false
		if phase == 0 and hero.pos.x >= x0.x - (1.0 if jump else 0.0):
			hero.inp["jump"] = jump
			hero.inp["dash"] = not jump
			st["press"] = hero.pos
			st["phase"] = 1 if jump else 2
		elif phase == 1:
			st["air"] = int(st["air"]) + 1
			if int(st["air"]) == 6:  # 2 sim steps a frame: 0.2 s into the jump
				hero.inp["dash"] = true
				st["press"] = hero.pos
				st["phase"] = 2
		elif (
			phase == 2
			and hero.roll_t <= 0.0
			and (hero.grounded or not jump)
			and (hero.ak.get("bash") as Dictionary).is_empty()
		):
			st["end"] = hero.pos
			st["phase"] = 3
	await gm._go(1.6, each, func(_t): return mid)
	var press: Vector3 = st["press"]
	var end: Vector3 = st["end"]
	print(
		(
			"MEDIA_CSHIFT %s: Shift pressed %.2f m past the start post, he %s %.2f m past it"
			% [
				"jump+Shift" if jump else "ground Shift",
				press.x - x0.x,
				"lands" if jump else "stops dashing",
				end.x - x0.x
			]
		)
	)
	await gm._go(0.5, func(_t): pass, func(_t): return mid)


## A spot with LANE m of flat, open ground east of it (and the run-up west), near `near`.
func _lane(w: World, near: Vector3) -> Vector3:
	for k in 4000:
		var g: Vector3 = near if k == 0 else w.random_ground()
		var good := true
		for i in 40:
			var x := g.x - RUN_UP - 1.0 + (LANE + RUN_UP + 1.0) * i / 39.0
			for dz in [-1.0, 0.0, 1.0]:
				if w.is_void(x, g.z + dz) or w.is_block(x, g.z + dz) or absf(w.ground_at(x, g.z + dz) - g.y) > 0.01:
					good = false
		if good:
			return Vector3(floor(g.x) + 0.5, g.y, floor(g.z) + 0.5)
	return near


func _posts(m: Match, x0: Vector3) -> void:
	for i in POSTS.size():
		var post := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.07
		mesh.bottom_radius = 0.07
		mesh.height = 1.6
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(String(POST_COL[i]))
		mesh.material = mat
		post.mesh = mesh
		m.add_child(post)
		post.global_position = x0 + Vector3(float(POSTS[i]), 0.8, -0.9)


func _label(m: Match, text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var lb := Label.new()
	lb.text = text
	lb.position = Vector2(40, 30)
	lb.add_theme_font_size_override("font_size", 40)
	lb.add_theme_color_override("font_outline_color", Color.BLACK)
	lb.add_theme_constant_override("outline_size", 10)
	layer.add_child(lb)
	m.add_child(layer)
