extends RefCounted
## --see-through-check: renders a tree and a stand-in hunter from the match camera's angle, with
## see-through (SeeThrough) on and off. A tree beside the
## hunter or behind them stays pixel-for-pixel solid; a tree between the camera and the hunter
## dithers only a small patch (the hunter shows through) and keeps most of itself. Needs a renderer
## (the suite's xvfb + opengl3), not --headless.

const SIZE := Vector2i(320, 240)
const CAM_OFF := Vector3(0, 27.0, 17.5)      # m: the match camera's height and pull-back (Cam.HEIGHT, BACK)
const FOV := 16.0                            # degrees: framed tight on the hunter and the tree
const KEEP := 0.75                           # share of a blocking tree's pixels that must stay solid

var fails := 0
var vp: SubViewport
var cam: Camera3D

func ok(cond: bool, what: String) -> void:
	print("SEETHROUGH %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main: Node) -> void:
	if DisplayServer.get_name() == "headless":
		ok(false, "needs a renderer (run under xvfb, not --headless)")
		_done(main)
		return
	_stage(main)
	var beside := await _case(Vector3(2.2, 0, 0.3))
	ok(beside[0] > 400, "the tree beside the hunter is in frame (%d px)" % beside[0])
	ok(beside[1] == 0, "a tree beside the hunter stays fully solid (%d px change)" % beside[1])
	var behind := await _case(Vector3(0.2, 0, -2.2))
	ok(behind[1] == 0, "a tree behind the hunter stays fully solid (%d px change)" % behind[1])
	var front := await _case(Vector3(0.1, 0, 2.6))
	var kept := 1.0 - float(front[1]) / maxf(1.0, float(front[0]))
	ok(front[1] > 0, "a tree between the camera and the hunter thins (%d px)" % front[1])
	ok(front[2] > 0, "the hunter shows through it (%d px)" % front[2])
	ok(kept >= KEEP, "it keeps %.0f%% of itself (at least %.0f%%)" % [kept * 100.0, KEEP * 100.0])
	SeeThrough.off()
	vp.queue_free()
	_done(main)

func _done(main: Node) -> void:
	print("SEETHROUGH DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

## A small world of its own: plain blue sky, a sun, the camera on the hunter at the origin and a red
## box standing in for the hunter.
func _stage(main: Node) -> void:
	vp = SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 1)
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.fov = FOV
	vp.add_child(cam)
	cam.look_at_from_position(CAM_OFF, Vector3(0, 0.9, 0))
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 1.7, 0.6)
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1, 0, 0)
	box.material = red
	body.mesh = box
	body.position = Vector3(0, 0.85, 0)
	vp.add_child(body)

## [tree pixels with see-through off, pixels that change when it's on, red pixels that show only when on]
## for a tree at `at` (the hunter at the origin).
func _case(at: Vector3) -> Array:
	var tree := MeshInstance3D.new()
	tree.mesh = Flora.mesh("tree", "meadow", 0)
	var mat := Flora.material("tree").duplicate() as ShaderMaterial
	mat.set_shader_parameter("sway", 0.0)       # still, so the two frames match where nothing thins
	mat.set_shader_parameter("flutter", 0.0)
	tree.material_override = mat
	tree.position = at
	tree.scale = Vector3.ONE * 1.15
	vp.add_child(tree)
	SeeThrough.off()
	var solid := await _frame()
	SeeThrough.update(cam, Vector3.ZERO)
	var seen := await _frame()
	tree.queue_free()
	var sky := solid.get_pixel(0, 0)
	var tree_px := 0
	var changed := 0
	var through := 0
	for y in SIZE.y:
		for x in SIZE.x:
			var a := solid.get_pixel(x, y)
			var b := seen.get_pixel(x, y)
			var is_tree := not _near(a, sky) and not _red(a)
			if is_tree: tree_px += 1
			if not _near(a, b): changed += 1
			if is_tree and _red(b): through += 1
	return [tree_px, changed, through]

func _frame() -> Image:
	for i in 3:
		await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()

func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.02

func _red(c: Color) -> bool:
	return c.r > 0.7 and c.g < 0.3 and c.b < 0.3
