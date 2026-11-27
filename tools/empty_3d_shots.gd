extends RefCounted
## --empty-3d-shots --shots-dir=<dir> [--part=locker|motion|tabs|home]: GPU stills of the Empty's 3D models (EmptyGlb) at
## 1920x1080. locker: the look locker's model of each sex from the front, three-quarters and back, and the hood
## down (procedural) with a colour dye; tabs: the locker's four tabs with their tile grids; motion: each sex
## idle, running and jumping on the shared rig (Warden/Sync fed the match's state) from the three-quarter and the
## side, whole and close on the shoulders, hips and knees; home: each sex standing in the hub, as the player
## sees it. Never writes the save.

const SIZE := Vector2i(1920, 1080)
const SEXES := ["f", "m"]  # Unmasked "gender" 0 and 1
const YAWS := {"back": 0.0, "q": 2.5, "front": PI}  # the locker turntable's turn (0 shows the back)
## [state name, the match's state for it, s of it before the first still]
const STATES := [
	["idle", {"grounded": true}, 0.6],
	["run", {"grounded": true, "vel": Vector3(0.0, 0.0, -4.6)}, 1.2],
	["jump", {"grounded": false, "vel": Vector3(0.0, 2.0, -4.0)}, 0.5],
]
## [view, camera distance (m), the height it looks at (m)]
const VIEWS := [["whole", 4.4, 0.8], ["shoulders", 1.7, 1.15], ["hips", 1.7, 0.7], ["knees", 1.7, 0.35]]
const MOTION_YAWS := {"q": 35.0, "side": 90.0}  # deg: the model's turn to the camera
const FPS := 30.0

var main: Node
var tree: SceneTree
var dir := "shots/empty3d"


func run(main_node: Node) -> void:
	main = main_node
	tree = main.get_tree()
	var part := "all"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--part="):
			part = String(a).substr(7)
	if dir.is_relative_path():
		dir = ProjectSettings.globalize_path("res://").path_join(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = SIZE
	if main.fade != null:
		main.fade.reveal(0.05)
	Save.no_write = true
	Save.d = Save.fresh()
	Save.d["tutorial"]["intro"] = true
	if part in ["all", "locker", "tabs"]:
		await _locker(part)
	if part in ["all", "motion"]:
		await _motion()
	if part in ["all", "home"]:
		await _home()
	print("EMPTY_3D_SHOTS done in %s" % dir)
	tree.quit(0)


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func _grab(name: String) -> void:
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_jpg(dir.path_join(name + ".jpg"), 0.93)


## The locker: the cut the model wears (Hooded Cloak, hood up, plain trim, no accessory), then the hood down.
func _locker(part: String) -> void:
	Save.d["look"] = Unmasked.default_look()
	var hx: Node = load("res://scripts/ui/hatch.gd").new()
	hx.edit_only = true
	main.add_child(hx)
	await _frames(40)
	var locker: LookLocker = hx.locker
	for kv in [["shroud", 0], ["hood", 1], ["trim", 0], ["accessory", 0]]:
		locker.pick(kv[0], kv[1])
	for sex in 2:
		locker.pick("gender", sex)
		if part == "tabs":
			for t in ["Body", "Hollow", "Shroud", "Glider"]:
				locker.show_tab(t)
				await _frames(80)
				await _grab("tab_%s_%s" % [SEXES[sex], t.to_lower()])
			continue
		locker.show_tab("Body")
		for yaw in YAWS:
			locker.set_yaw(YAWS[yaw])
			await _frames(60)
			await _grab("locker_%s_%s" % [SEXES[sex], yaw])
		locker.pick("colour", 5)
		locker.pick("hood", 0)
		locker.set_yaw(YAWS["q"])
		await _frames(60)
		await _grab("locker_%s_hood_down_dyed" % SEXES[sex])
		locker.pick("hood", 1)
		await _frames(60)
		await _grab("locker_%s_dyed_3d" % SEXES[sex])
		locker.pick("colour", int(Unmasked.default_look()["colour"]))
	hx.queue_free()
	await _frames(5)


## Each sex on the stage: the model posed by its poser frame by frame.
func _motion() -> void:
	var holder := Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	env.environment = Look.environment(
		{"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"), "stars": 0.0}
	)
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	var cam := Camera3D.new()
	cam.fov = 30.0
	holder.add_child(cam)
	cam.make_current()
	for sex in 2:
		var lk := Unmasked.default_look()
		lk["gender"] = sex
		var model := Models.hunter("medium", Data.TEAM_COLORS[0], "", "", lk)
		model.set_meta("anim_seed", 1)
		holder.add_child(model)
		print("EMPTY_3D sex %s glb=%s" % [SEXES[sex], model.get_meta("glb", false)])
		var poser := model.get_node("Warden/Sync")
		poser.set_process(false)
		var poser := model.get_node("Warden/Sync")
		poser.set_process(false)
		for yaw in MOTION_YAWS:
			model.rotation.y = deg_to_rad(float(MOTION_YAWS[yaw]))
			for st in STATES:
				var s: Dictionary = (st[1] as Dictionary).duplicate()
				s["face"] = model.rotation.y
				model.set_meta(WardenClips.STATE, s)
				for k in int(float(st[2]) * FPS):
					poser.call("_process", 1.0 / FPS)
				for view in VIEWS:
					cam.position = Vector3(0.0, float(view[2]) + 0.1, float(view[1]))
					cam.look_at(Vector3(0.0, float(view[2]), 0.0))
					await _grab("motion_%s_%s_%s_%s" % [SEXES[sex], st[0], yaw, view[0]])
		model.queue_free()
	holder.queue_free()


## The hub: the player is built from the saved look, so each sex is a save.
func _home() -> void:
	for sex in 2:
		var d := Save.fresh()
		d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
		var lk := Unmasked.default_look()
		lk["gender"] = sex
		d["look"] = lk
		Save.d = d
		HomeLayout.ensure(d)
		var home = await main._hb_home()
		for i in 900:
			if home.root_ui != null and home.player != null:
				break
			await tree.process_frame
		home._close_panel()
		await _frames(90)
		await _grab("home_%s" % SEXES[sex])
		home.cam.zoom_to = 0.55
		home.cam.zoom = 0.55
		await _frames(30)
		await _grab("home_%s_close" % SEXES[sex])
		home.queue_free()
		await _frames(10)
