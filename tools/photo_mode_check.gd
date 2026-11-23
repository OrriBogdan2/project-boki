extends RefCounted
## --photo-mode-check: farm photo mode. Enter (HUD hidden, farm clock stopped), orbit with the mouse,
## Capture writes a real PNG to the user folder, exit puts the HUD and the camera back. Needs a
## renderer for the PNG (run it through `jobq submit --needs gpu`, not --headless).

const SETTLE_FRAMES := 30
var fails := 0
var checks := 0

func ok(label: String, cond: bool, info := "") -> void:
	checks += 1
	printerr("PHOTOMODE %-48s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func run(main: Node) -> void:
	var tree := main.get_tree()
	Game.goto("home")
	for i in SETTLE_FRAMES:
		await tree.process_frame
	var home: Node3D = main.current
	var cam: CamRig = home.cam
	var yaw0 := cam.yaw
	var pitch0 := cam.pitch
	var zoom0 := cam.zoom_to
	ok("farm has a photo mode", home.photo != null)
	home._close_panel()      # the fresh farm opens on its welcome panel
	ok("enter works at home", home.photo.enter())
	ok("HUD hidden", not home.ui.visible)
	var still := _kin_spots(home)
	var orbit := InputEventMouseMotion.new()
	orbit.relative = Vector2(120, 40)
	orbit.button_mask = MOUSE_BUTTON_MASK_LEFT
	ok("drag is taken as an orbit", home.photo.input(orbit))
	ok("orbit turns the camera", not is_equal_approx(cam.yaw, yaw0) and not is_equal_approx(cam.pitch, pitch0))
	for i in SETTLE_FRAMES:
		await tree.process_frame
	ok("Boki stand still while it is on", _kin_spots(home) == still)
	var path: String = await home.photo.capture()
	ok("capture returns a path", path != "", path)
	var shot := Image.load_from_file(path) if path != "" else null
	ok("the PNG loads", shot != null and not shot.is_empty())
	if shot != null and not shot.is_empty():
		var win := home.get_viewport().get_visible_rect().size
		ok("the PNG is the window's size", Vector2(shot.get_size()) == win, "%s vs %s" % [shot.get_size(), win])
	ok("HUD still hidden after capture", not home.ui.visible)
	var leave := InputEventAction.new()
	leave.action = "menu"
	leave.pressed = true
	ok("Esc leaves", home.photo.input(leave) and not home.photo.active)
	ok("HUD back", home.ui.visible)
	var camera_back := is_equal_approx(cam.yaw, yaw0) and is_equal_approx(cam.pitch, pitch0)
	ok("camera back", camera_back and is_equal_approx(cam.zoom_to, zoom0))
	if path != "":
		DirAccess.remove_absolute(path)
	print("PHOTOMODE DONE, %d checks, failures: %d" % [checks, fails])
	tree.quit(1 if fails > 0 else 0)

func _kin_spots(home: Node3D) -> Array:
	var spots := []
	for k in home.kins:
		spots.append((k["node"] as Node3D).global_position)
	return spots
