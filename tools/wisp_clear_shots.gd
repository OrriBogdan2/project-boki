extends RefCounted
## --wisp-clear-shots --shots-dir=<dir>: the Boki wisp rules (BokiWispClear) at the match camera, GPU shots.
## A bare stage (ground, capsule Hunters, an aim ribbon with AimDraw's material, a hit circle, plates and the
## cursor drawn the way the HUD does): your Hunter aiming four ways, one while firing, and 30 Hunters in a fight.
## Writes aim_<deg>.png, fire.png and crowd.png. Never touches the save.

const CAM := [66.0, 23.0, 32.0]      # the Supervive camera style: pitch deg, distance m, fov deg
const AIMS := [0, 90, 180, 270]      # deg; 90 aims at the camera, 270 away from it
const AIM_LEN := 8.0                 # m
const SETTLE := 90                   # frames before a shot: the trail fills in
const CROWD := 30
const SPACING := 2.4                 # m between the crowd's Hunters
const SPECIES := ["cindle", "puddlet", "zapple", "pebbit"]

var main: Node
var stage := Node3D.new()
var hud := Control.new()
var view: BokiWispClear.View
var hunters: Array[Dictionary] = []   # {feet, aim, wisp, line}
var dir := ""
var clock := 0.0
var firing := false

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	_stage()
	for deg in AIMS:
		await _shot(1, deg, false, "aim_%d.png" % deg)
	await _shot(1, 0, true, "fire.png")
	await _shot(CROWD, 0, false, "crowd.png")
	print("WISPCLEARSHOTS in ", dir)
	main.get_tree().quit(0)

func _stage() -> void:
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("1b2030")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b9c4e6")
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	(ground.mesh as PlaneMesh).size = Vector2(80, 80)
	ground.material_override = Models.toon(Color("5f8d45"), false)
	stage.add_child(ground)
	var cam := Camera3D.new()
	var back := Vector3(0, sin(deg_to_rad(CAM[0])), cos(deg_to_rad(CAM[0]))) * float(CAM[1])
	cam.transform = Transform3D(Basis.looking_at(-back, Vector3.UP), back)
	cam.fov = CAM[2]
	stage.add_child(cam)
	cam.make_current()
	var layer := CanvasLayer.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	layer.add_child(hud)
	stage.add_child(layer)
	view = BokiWispClear.View.new(cam.global_transform, cam.fov, main.get_viewport().get_visible_rect().size)

## One shot: count Hunters (the first is yours, aiming aim_deg), run SETTLE frames, save.
func _shot(count: int, aim_deg: int, fire: bool, file: String) -> void:
	_clear()
	firing = fire
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in count:
		var col := i % 6
		var feet := Vector3((col - 2.5) * SPACING, 0, (i / 6 - 2) * SPACING) if count > 1 else Vector3.ZERO
		var deg := float(aim_deg) if i == 0 else rng.randf() * 360.0
		if i == 0 and count > 1:
			feet = Vector3(SPACING * 0.5, 0, 0)
		_add_hunter(i, feet, Vector2.RIGHT.rotated(deg_to_rad(deg)))
	for f in SETTLE:
		clock += 1.0 / 60.0
		_step()
		await main.get_tree().process_frame
	hud.queue_redraw()
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file))
	print("WISPCLEARSHOT ", file)

func _clear() -> void:
	for h in hunters:
		(h["body"] as Node).queue_free()
		(h["wisp"] as Node).queue_free()
	hunters.clear()

func _add_hunter(i: int, feet: Vector3, aim: Vector2) -> void:
	var body := MeshInstance3D.new()
	body.mesh = CapsuleMesh.new()
	(body.mesh as CapsuleMesh).radius = 0.4
	(body.mesh as CapsuleMesh).height = 1.7
	body.material_override = Models.toon(Color("c0504d") if i > 0 else Color("4d7cc0"))
	body.position = feet + Vector3(0, 0.85, 0)
	stage.add_child(body)
	var wisp := BokiWispLook.build(SPECIES[i % SPECIES.size()], {})
	stage.add_child(wisp)
	hunters.append({"feet": feet, "aim": aim, "wisp": wisp, "body": body})
	if i == 0:
		var line := MeshInstance3D.new()           # the aim ribbon, in AimDraw's material
		line.mesh = Models.flat_quad(1.0)
		line.scale = Vector3(AIM_LEN, 1, 0.3)
		line.rotation.y = -aim.angle()
		line.position = feet + Vector3(aim.x, 0, aim.y) * AIM_LEN * 0.5 + Vector3(0, AimGeo.LIFT, 0)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.9, 0.3, 0.55)
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.render_priority = 2
		line.material_override = mat
		hunters[0]["line_mesh"] = line
		body.add_child(line)
		line.top_level = true
		var ring := MeshInstance3D.new()
		ring.mesh = Models.flat_quad(2.0 * 0.48)
		ring.material_override = Models.ring_mat(Color(1, 1, 1, 0.9), 0.1)
		ring.position = feet + Vector3(0, AimGeo.LIFT, 0)
		body.add_child(ring)
		ring.top_level = true

## The rules, every frame: place each wisp, dim it, shorten or stop its trail.
func _step() -> void:
	var rects: Array[Rect2] = []
	for h in hunters:
		rects.append(BokiWispClear.plate_rect(view, h["feet"]))
	var mine: Dictionary = hunters[0]
	var line_me := BokiWispClear.aim_line(view, mine["feet"], mine["aim"], AIM_LEN)
	rects.append(BokiWispClear.ground_rect(view, mine["feet"], 0.48))
	rects.append(BokiWispClear.cursor_rect(line_me[1]))
	var dists := PackedFloat32Array()
	for h in hunters:
		dists.append((h["feet"] as Vector3).distance_to(mine["feet"]))
	var sparkly := BokiWispClear.sparkly(dists)
	for i in hunters.size():
		var h: Dictionary = hunters[i]
		var w: Node3D = h["wisp"]
		var line := BokiWispClear.aim_line(view, h["feet"], h["aim"], AIM_LEN)
		w.position = BokiWispClear.place(view, h["feet"], 1.45, h["aim"], AIM_LEN, w, clock)
		BokiWispLook.pose(w, clock)
		BokiWispClear.apply(w, BokiWispClear.alpha(view, w.position, line, rects), firing and i == 0, sparkly[i] == 1)

func _draw_hud() -> void:
	if hunters.is_empty():
		return
	for h in hunters:
		var r := BokiWispClear.plate_rect(view, h["feet"])
		var bars := r.grow_individual(0, -BokiWispClear.PLATE_ABOVE, 0, 0)
		HudStyle.plate_frame(hud, bars, Color(1, 1, 1, 0.55))
		hud.draw_rect(bars.grow(-HudStyle.PLATE_PAD), Color("5fd16a"))
	var mine: Dictionary = hunters[0]
	var at := BokiWispClear.aim_line(view, mine["feet"], mine["aim"], AIM_LEN)[1]
	hud.draw_arc(at, AimReticle.R, 0.0, TAU, 40, Color(1, 1, 1, 0.9), 2.0, true)
	hud.draw_circle(at, 3.0, Color(1, 1, 1, 0.9))
