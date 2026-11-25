extends RefCounted
## --farm-cam-clip [--clip-dir=farm_cam_clip]: film the farm's third-person view (FarmCam) on a made-up garden (never
## the real save): you walk with the real keys (W is away from the camera) to the garden beds, drag the view round,
## to a roaming Boki, to the house, then back up to a wall so the camera is pulled in. With --fc-games it films the
## Boki minigames (Spark Volley, Fetch Cup, Kite Tow, Echo Steps) played from the third-person view
## instead. PNG frames (cam_NN_<what>.png) and the movie (farm_cam.avi) go to <tree>/<clip-dir>. Like
## tools/farm_greet_clip.gd it re-runs itself as a child Godot under the movie writer (GPU worker). Prints FCCLIP lines.

const FPS := 30
const SIZE := "1600x900"
const ISLAND_SEED := 11  # the farm's trees and rocks
const DAY_T := 0.45  # farm clock: mid-morning all film long
const LEG_S := 5.0  # s at most to a goal
const DEADLINE_S := 150.0  # s of film at most
const BUILDINGS := [
	["house", 33, 28, 0], ["crop_patch", 42, 31, 0], ["cook_pot", 36, 35, 0], ["market_stall", 44, 37, 0]
]  # id, x, z, turns
const GAMES := [  # member on Home, its fixture, zone ("" the classic base), shots (s into the game), key held
	["hvolley", "log_node", "glasswater", [1.0, 5.0], ""],
	["hfetch", "mat", "", [1.0, 6.0], ""],
	["hkite", "stand", "ridge", [1.5, 4.0], "right"],
	["hecho", "middle", "", [2.0, 9.0], ""]
]
const GAME_FROM := Vector3(0.0, 0, 1.6)  # m south of a game's fixture: where you stand to start it
const SPECS := [["cindle", "Ash", 95.0], ["burrlet", "Moss", 60.0], ["zapple", "Pip", 30.0]]  # species, name, trust

var main: Node
var h
var dir := "farm_cam_clip"
var shot_n := 0


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--clip-dir="):
			dir = String(a).substr(11)
	if "--fc-child" not in OS.get_cmdline_user_args():
		_record()
		return
	Save.no_write = true
	Content.rules("farm_build")["base_mode"] = true
	seed(ISLAND_SEED)
	var d := Save.fresh()
	for i in SPECS.size():
		var rec := Save.new_kin(SPECS[i][0], SPECS[i][1], 700 + i)
		rec["uid"] = "fc%d" % i
		rec["trust"] = SPECS[i][2]
		for need in Care.NEEDS:
			rec["needs"][need] = 90.0
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"home": true, "hatched": true, "intro": true, "day1_done": true}
	var crops: Array = Data.CROPS.keys()
	for i in 4:
		d["plots"][i] = {"crop": crops[i % crops.size()], "stage": 1 + i % 3, "care": 0, "wt": 0.0}
	HomeLayout.new_fs(d, ISLAND_SEED)
	var lay := HomeLayout.ensure(d)
	for b in BUILDINGS:
		(lay["deco"] as Array).append({"u": HomeLayout._next_uid(lay), "id": b[0], "x": b[1], "z": b[2], "r": b[3]})
	Save.d = d
	main.get_tree().create_timer(DEADLINE_S).timeout.connect(main.get_tree().quit.bind(1))  # never hang a worker
	if "--fc-games" in OS.get_cmdline_user_args():
		await _games()
	else:
		await _open("")
		await _beds()
		await _open(GardenZones.HUB)
		await _hub()
	print("FCCLIP DONE shots=%d" % shot_n)
	main.get_tree().quit()


## A fresh farm in `zone` ("" the start zone with the beds, GardenZones.HUB the house and waystone).
func _open(zone: String) -> void:
	if h != null:
		h.queue_free()
		await main.get_tree().process_frame
	h = load("res://scripts/home/home.gd").new()
	h.set("zone", zone)
	main.add_child(h)
	main.set("current", h)
	for i in 3:
		await main.get_tree().process_frame
	while h.building:
		await main.get_tree().process_frame
	h.day_t = DAY_T
	Settings.set_v("tips", false)
	h._close_panel()
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	await _wait(1.0)


func _beds() -> void:
	await _shot("start")
	var bed: Vector3 = (h.plots[0] as Node3D).global_position
	await _walk(bed + Vector3(0.0, 0, 1.6))
	await _wait(0.6)
	await _shot("beds")
	await _orbit(-1.6)
	await _wait(0.4)
	await _shot("orbit_beds")
	await _orbit(1.6)
	var kin: Node3D = h.kins[1]["node"]
	await _walk(kin.global_position, kin)
	await _wait(0.5)
	await _shot("boki")


func _hub() -> void:
	print("FCCLIP hub spots=%s" % [h.spots])
	await _shot("hub")
	var house: Vector3 = HomeLayout.deco_center(HubLayout.template()["deco"][0])
	await _walk(house + Vector3(0, 0, 5.0))
	await _wait(0.4)
	await _shot("house")
	await _walk(house + Vector3(0, 0, 3.0))
	await _orbit(3.1)  # turn the view round so it looks into the house wall: the camera comes in
	await _wait(0.5)
	await _shot("wall")


## Each minigame on the classic base (it holds them all round its Training post), started from where you would stand.
func _games() -> void:
	for g in GAMES:
		for rec in Save.d["roster"]:
			rec["zone"] = g[2] if g[2] != "" else GardenZones.start()
		if g[2] == "":
			await _open_base()
		else:
			await _open(g[2])
		var game: Object = h.get(g[0])
		var fixture: Node3D = game.get(g[1])
		h.ppos = fixture.position + GAME_FROM
		h.player.position = h.ppos
		h.cam.snap(h.ppos)
		await _wait(1.2)
		game.use()
		var t := 0.0
		for at in g[3]:
			if g[4] != "":
				Input.action_press(g[4])
			await _wait(float(at) - t)
			t = float(at)
			await _shot(String(g[0]).substr(1) + "_%d" % int(at))
		for a in ["left", "right"]:
			Input.action_release(a)


## The classic island with two rested Boki out and the minigames on (a made-up save, never the real one).
func _open_base() -> void:
	if h != null:
		h.queue_free()
		await main.get_tree().process_frame
	Save.d["layout"] = HomeLayout.fresh()
	HomeLayout.ensure(Save.d)
	h = await main._hb_home()
	for k in h.kins:
		k.erase("indoors")
	h.day_t = DAY_T
	Settings.set_v("tips", false)
	h._close_panel()
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	await _wait(0.5)


## Walks to `goal` (xz) with the real keys, each frame held in the view's own terms.
func _walk(goal: Vector3, chase: Node3D = null) -> void:
	var left := LEG_S * FPS
	while left > 0 and Vector2(goal.x - h.ppos.x, goal.z - h.ppos.z).length() > 0.5:
		if chase != null:
			goal = chase.global_position + Vector3(1.8, 0, 1.8)  # (a Boki that wanders: keep heading for it)
		var way := Vector2(goal.x - h.ppos.x, goal.z - h.ppos.z).normalized().rotated(h.cam.yaw)
		_keys(way)
		await _wait(1.0 / FPS)
		left -= 1
	_keys(Vector2.ZERO)


func _keys(mv: Vector2) -> void:
	Input.action_press("right", maxf(mv.x, 0.0))
	Input.action_press("left", maxf(-mv.x, 0.0))
	Input.action_press("down", maxf(mv.y, 0.0))
	Input.action_press("up", maxf(-mv.y, 0.0))
	if mv == Vector2.ZERO:
		for a in ["right", "left", "down", "up"]:
			Input.action_release(a)


## A right-button drag across `turn` radians of the view, over about a second.
func _orbit(turn: float) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	h._unhandled_input(press)
	var n := FPS
	for i in n:
		var move := InputEventMouseMotion.new()
		move.relative = Vector2(-turn / float(FarmCam.rules()["orbit_per_px"]) / n, 0.0)
		h._unhandled_input(move)
		await _wait(1.0 / FPS)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	h._unhandled_input(release)


func _wait(secs: float) -> void:
	for _i in maxi(1, roundi(secs * FPS)):
		await main.get_tree().process_frame
		h.day_t = DAY_T


func _shot(what: String) -> void:
	await _wait(0.3)
	shot_n += 1
	var file := "cam_%02d_%s.png" % [shot_n, what]
	var path := ProjectSettings.globalize_path("res://").path_join(dir).path_join(file)
	if main.get_viewport().get_texture().get_image().save_png(path) != OK:
		print("FCCLIP could not save %s" % path)
	var cam: CamRig = h.cam
	print(
		(
			"FCCLIP shot %s: camera %.1f m back, pitch %.0f deg, yaw %.0f deg, at %s"
			% [
				file,
				cam.global_position.distance_to(cam.focus + Vector3(0, cam.rise, 0)),
				rad_to_deg(cam.pitch),
				rad_to_deg(cam.yaw),
				h.ppos.snapped(Vector3(0.1, 0.1, 0.1))
			]
		)
	)


func _record() -> void:
	var root := ProjectSettings.globalize_path("res://")
	DirAccess.make_dir_recursive_absolute(root.path_join(dir))
	var args := ["--path", root, "--rendering-driver", "vulkan", "--audio-driver", "Dummy", "--resolution", SIZE]
	var avi := root.path_join(dir).path_join("farm_cam.avi")
	args.append_array(["--fixed-fps", str(FPS), "--write-movie", avi, "--"])
	args.append_array(OS.get_cmdline_user_args())
	args.append("--fc-child")
	var out: Array = []
	var rc := OS.execute(OS.get_executable_path(), args, out, true)
	for line in (String(out[0]) if out.size() > 0 else "").split("\n"):
		if line.begins_with("FCCLIP") or line.contains("SCRIPT ERROR"):
			print(line)
	print("FCCLIP child rc=%d" % rc)
	main.get_tree().quit(rc)
