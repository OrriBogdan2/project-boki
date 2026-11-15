extends RefCounted
## --wild-boki-states-shots --shots-dir=<dir> [--species=cindle,zapple,zephyrak]: one row per species at match
## zoom: wander, startle, bolt, charge, dazed (two moments of the sway), lifted by the scan. <dir>/wild_states.png.
## Needs a renderer.

const Shots := preload("res://tools/boki_rig_shots.gd")
const STEP := 1.0 / 60.0
## [label, pose, speed (m/s), clip time (s)]; the lifted Boki is scaled and raised as Capture.dissolve does at 50%.
const FRAMES := [["wander", "", 1.0, 0.2], ["startle", "alert", 0.0, 0.5], ["bolt", "whine", 4.0, 0.1],
	["charge", "growl", 4.0, 0.25], ["dazed", "dazed", 0.0, 0.5], ["dazed later", "dazed", 0.0, 1.4],
	["scan", "scan", 0.0, 0.3]]
const LIFT := Vector3(0, 0.45, 0)
const LIFT_SCALE := 0.56
const SPACING := 1.5
const CROP := Vector2i(120, 140)
const ENLARGE := 3

var main: Node
var out := ""
var species := ["cindle", "zapple", "zephyrak"]

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--species="): species = Array(a.substr(10).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var rows: Array[Image] = []
	for id in species:
		rows.append(await _row(String(id)))
	var sheet := Image.create(rows[0].get_width(), rows[0].get_height() * rows.size(), false, Image.FORMAT_RGBA8)
	for i in rows.size():
		sheet.blit_rect(rows[i], Rect2i(Vector2i.ZERO, rows[i].get_size()), Vector2i(0, i * rows[i].get_height()))
	sheet.save_png(out.path_join("wild_states.png"))
	print("WILD_BOKI_SHOTS_DONE")
	main.get_tree().quit()

func _row(id: String) -> Image:
	var shots := Shots.new()
	shots.main = main
	var vp := shots._stage(Vector2i(1920, 1080))
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.fov = Shots.MATCH_FOV
	var p := deg_to_rad(Shots.MATCH_PITCH)
	cam.position = Vector3(0, sin(p), cos(p)) * Shots.MATCH_DIST
	cam.rotation = Vector3(-p, 0, 0)
	for i in FRAMES.size():
		var rig_kin := Shots.rigged_kin(id)
		var rig := rig_kin.get_node("Body/Flex/BokiRig") as BokiRig
		rig.manual = true
		vp.add_child(rig_kin)
		var f: Array = FRAMES[i]
		rig_kin.position = Vector3((i - (FRAMES.size() - 1) * 0.5) * SPACING, 0, 0)
		rig_kin.basis = Basis(Vector3.RIGHT, -Shots.LEAN) * Basis(Vector3.UP, PI * 0.8)
		if f[1] == "scan":
			rig_kin.position += LIFT
			rig_kin.scale = Vector3.ONE * LIFT_SCALE
		await RenderingServer.frame_post_draw
		rig_kin.set_meta("pose", f[1])
		rig._speed = float(f[2])
		for s in 90:
			rig._pos_prev = rig_kin.global_position - Vector3(0, 0, float(f[2]) * STEP)
			rig._pick_clip(STEP)
			rig._keep_flex()
		rig._face_step(1.0)
		rig.seek(float(f[3]))
	for k in 3:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var row := Image.create(CROP.x * ENLARGE * FRAMES.size(), CROP.y * ENLARGE, false, Image.FORMAT_RGBA8)
	row.fill(Color.BLACK)
	for i in FRAMES.size():
		var at := Vector2i(cam.unproject_position(Vector3((i - (FRAMES.size() - 1) * 0.5) * SPACING, 0.45, 0)))
		var crop := img.get_region(Rect2i(at - CROP, CROP * 2))
		crop.resize(CROP.x * ENLARGE, CROP.y * ENLARGE, Image.INTERPOLATE_NEAREST)
		crop.convert(Image.FORMAT_RGBA8)
		row.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(i * CROP.x * ENLARGE, 0))
	vp.queue_free()
	return row
