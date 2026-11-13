extends RefCounted
## --dash-momentum-shots --shots-dir=<dir> [--wardens=<id>]: one Hunter (Vex by default) on a flat training patch
## does the dashes --dash-momentum-check measures, each from the same start, filmed by a fixed camera over a lane
## with a post every 2 m: <dir>/<take>/f000.png... at 30 fps. Takes: a ground dash, a jump then a dash at its apex,
## the same with no charge left (the long dash), and a dash then a jump out of it. Prints one DASHMOM_SHOT line a
## take: how far the hunter got from the start by the time it stood still on the ground. Needs a renderer.

const EVERY := 2             # sim steps (60 Hz) per frame: 30 fps
const TAKE_S := 2.0          # s filmed per take
const POSTS := 12            # lane posts, one every POST_GAP m along +x
const POST_GAP := 2.0
const CAM_AT := Vector3(8.0, 0.0, 0.0)        # m from the start: the middle of the lane
const CAM_FROM := Vector3(0.0, 8.0, 9.0)      # m off that middle: high and to the south, the lane across the frame
const CAM_FOV := 60.0
const TAKES := ["ground", "jump", "jump_ex", "dash_jump"]

var tree: SceneTree

func run(main: Node) -> void:
	tree = main.get_tree()
	Save.no_write = true
	var out := ""
	var hero := "gunslinger"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): hero = a.substr(10)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(960, 540)
	main.get_viewport().size = Vector2i(960, 540)
	var flow = load("res://tools/dash_flow_check.gd").new()
	var m: Match = flow._match(main, hero)
	for layer in main.get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false        # the HUD, the drill card: the lane only
	var h: Hunter = m.player
	var home := h.pos
	_lane(m, home)
	var cam := Camera3D.new()
	m.add_child(cam)
	cam.fov = CAM_FOV
	cam.global_position = home + CAM_AT + CAM_FROM
	cam.look_at(home + CAM_AT)
	cam.make_current()
	for take in TAKES:
		DirAccess.make_dir_recursive_absolute(out.path_join(take))
		flow._fresh(m)
		h.teleport(home)
		flow._steps(m, 10)
		await _take(m, h, take, out.path_join(take), home)
	print("DASHMOM_SHOTS_DONE")
	tree.quit()

## A floor under the flattened patch (the check flattens the data only) and posts along the lane, so the distance
## reads in the frame.
func _lane(m: Match, home: Vector3) -> void:
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(48, 48)
	floor_mi.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("5d7a46")
	floor_mi.material_override = floor_mat
	m.add_child(floor_mi)
	floor_mi.global_position = home + Vector3(0, 0.01, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f2e6c8")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in POSTS + 1:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.12, 0.6 if i % 5 == 0 else 0.3, 0.12)
		post.mesh = box
		post.material_override = mat
		m.add_child(post)
		post.global_position = home + Vector3(i * POST_GAP, box.size.y * 0.5, -1.2)

func _take(m: Match, h: Hunter, take: String, dir: String, home: Vector3) -> void:
	if take.ends_with("_ex"):
		h.dashes = 0.0
	var n := 0
	var pressed := take == "ground" or take == "dash_jump"
	var jump_at := 3 if take == "dash_jump" else -1
	if not pressed:
		h.inp["jump"] = true
	for i in int(TAKE_S / Match.DT):
		h.inp["aim"] = h.pos + Vector3(40, 0, 0)
		if not pressed and i > 1 and h.vel.y <= 0.0:
			h.inp["dash"] = true
			pressed = true
			jump_at = -1
		elif i == 0 and (take == "ground" or take == "dash_jump"):
			h.inp["dash"] = true
		if i == jump_at:
			h.inp["jump"] = true
		m.step(Match.DT)
		h.render(Match.DT, 1.0)
		h.inp["dash"] = false
		h.inp["jump"] = false
		if i % EVERY == 0:
			await RenderingServer.frame_post_draw
			tree.root.get_texture().get_image().save_png(dir.path_join("f%03d.png" % n))
			n += 1
	print("DASHMOM_SHOT %s: %.2fm from the start" % [take, Vector2(h.pos.x - home.x, h.pos.z - home.z).length()])
