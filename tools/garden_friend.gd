extends RefCounted
## --garden-friend --gf-mode=<faces|reel> [--gf-dir=<dir>] [--gf-species=a,b,c,d]: clean friend-pitch footage of the farm
## (private film tool, not shipped). faces: front close-up of every Boki on main, for the eye check. reel: the garden
## in its close third-person view, golden hour, the finished Sable as the hunter, no HUD, 1600x900 at 30 fps; the child
## run (under the movie writer) prints "GF TAKE <start_s> <end_s>" and saves the stills.

const Shots := preload("res://tools/boki_rig_shots.gd")
const FPS := 30
const SIZE := "1600x900"
const ISLAND_SEED := 11
const DAY_T := 0.72  # farm clock: golden hour (low honey sun)
const DEADLINE_S := 900.0
const BUILDINGS := [
	["house", 33, 28, 0], ["crop_patch", 42, 31, 0], ["cook_pot", 36, 35, 0], ["market_stall", 44, 37, 0]
]  # id, x, z, turns
const HUNTER_ARCH := "ostra"  # Motley's archetype (WardenGlb.ART): the best in-game model (r1 used Sable: off-model face)
const HUNTER_CLASS := "medium"
const MEAD := Vector3(53.0, 0, 29.5)  # open ground east of the beds
const FACE_COLS := 6
const FACES_PER_SHEET := 18

var main: Node
var h
var mode := "reel"
var dir := "gf"
var species: PackedStringArray = ["cindle", "burrlet", "puddlet", "heatherhorn"]
var names := ["Ash", "Moss", "Dew", "Haggis"]
var face_px := 320
var _frames := 0
var _take_from := 0.0


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--gf-mode="):
			mode = String(a).substr(10)
		if String(a).begins_with("--gf-dir="):
			dir = String(a).substr(9)
		if String(a).begins_with("--gf-px="):
			face_px = int(String(a).substr(8))
		if String(a).begins_with("--gf-species="):
			species = String(a).substr(13).split(",")
	DirAccess.make_dir_recursive_absolute(dir)
	if mode == "faces":
		await _faces()
		main.get_tree().quit()
		return
	if "--gf-child" not in OS.get_cmdline_user_args():
		_record()
		return
	Save.no_write = true
	Content.rules("farm_build")["base_mode"] = true
	seed(ISLAND_SEED)
	_make_save()
	main.get_tree().create_timer(DEADLINE_S).timeout.connect(main.get_tree().quit.bind(1))
	await _open()
	await _film()
	print("GF DONE")
	main.get_tree().quit()


# ------------------------------------------------------------------ the face check
func _faces() -> void:
	var s := Shots.new()
	s.main = main
	s.px = face_px
	var ids: Array = []
	for f in DirAccess.get_directories_at("res://art/kin"):
		if BokiRig.FRAME.has(f) and FileAccess.file_exists("res://art/kin/%s/%s.glb" % [f, f]):
			ids.append(f)
	ids.sort()
	if "--gf-all" not in OS.get_cmdline_user_args():
		ids = Array(species)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var vp := s._stage(Vector2i(face_px, face_px), false)
	var cam := s._close_cam(vp)
	var sheets: Array = []
	for i in ids.size():
		if i % FACES_PER_SHEET == 0:
			sheets.append(Image.create(face_px * FACE_COLS, face_px * 2 * ceili(float(mini(FACES_PER_SHEET, ids.size() - i)) / FACE_COLS), false, Image.FORMAT_RGBA8))
		var cell := i % FACES_PER_SHEET
		s.species = ids[i]
		var kr := s._kin(vp)
		(kr[0] as Node3D).rotation.y = PI
		var rig := kr[1] as BokiRig
		rig.set_face("neutral")
		rig.seek(0.5)
		var head: Vector3 = BokiRig.FRAME[ids[i]]["head"]
		var close := [13.0, head.y + 0.16, 3.3, head.y + 0.01]  # fov, cam y, cam z, look y (as the rig shots' face strip)
		cam.fov = close[0]
		cam.position = Vector3(0.0, close[1], close[2])
		cam.look_at(Vector3(0, close[3], -0.1))
		await RenderingServer.frame_post_draw
		var a: Image = await s._grab(vp)
		cam.fov = 24.0  # the mid-distance view of the same Boki
		cam.position = Vector3(0, 0.95, 4.2)
		cam.look_at(Vector3(0, 0.45, 0))
		var b: Image = await s._grab(vp)
		var sheet: Image = sheets[i / FACES_PER_SHEET]
		var at := Vector2i((cell % FACE_COLS) * face_px, (cell / FACE_COLS) * face_px * 2)
		a.convert(Image.FORMAT_RGBA8)
		b.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(a, Rect2i(0, 0, face_px, face_px), at)
		sheet.blit_rect(b, Rect2i(0, 0, face_px, face_px), at + Vector2i(0, face_px))
		print("GF FACE %d %s" % [i, ids[i]])
		(kr[0] as Node3D).free()
	for n in sheets.size():
		(sheets[n] as Image).save_png(dir.path_join("faces_%d.png" % n))
	var list := FileAccess.open(dir.path_join("faces_order.txt"), FileAccess.WRITE)
	list.store_string("\n".join(PackedStringArray(ids)))
	print("GF FACES DONE %d" % ids.size())


# ------------------------------------------------------------------ the garden
func _make_save() -> void:
	var d := Save.fresh()
	for i in species.size():
		var rec := Save.new_kin(species[i], names[i], 700 + i)
		rec["uid"] = "gf%d" % i
		rec["trust"] = 95.0
		for need in Care.NEEDS:
			rec["needs"][need] = 95.0
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["cls"] = HUNTER_CLASS
	d["arch"] = HUNTER_ARCH
	d["tutorial"] = {"home": true, "hatched": true, "intro": true, "day1_done": true}
	var crops: Array = Data.CROPS.keys()
	for i in 4:
		d["plots"][i] = {"crop": crops[i % crops.size()], "stage": 1 + i % 3, "care": 0, "wt": 0.0}
	HomeLayout.new_fs(d, ISLAND_SEED)
	var lay := HomeLayout.ensure(d)
	for b in BUILDINGS:
		(lay["deco"] as Array).append({"u": HomeLayout._next_uid(lay), "id": b[0], "x": b[1], "z": b[2], "r": b[3]})
	Save.d = d


func _open() -> void:
	var fr: Dictionary = CamRig.rules["farm"]
	fr["dist_min"] = 3.0
	fr["dist_max"] = 4.8
	fr["rise"] = 0.85
	h = load("res://scripts/home/home.gd").new()
	h.set("zone", "")
	main.add_child(h)
	main.set("current", h)
	for i in 3:
		await main.get_tree().process_frame
	while h.building:
		await main.get_tree().process_frame
	Settings.set_v("tips", false)
	h._close_panel()
	h.ui.visible = false
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	h.day_t = DAY_T
	_dress_hunter()
	RenderingServer.frame_pre_draw.connect(_hide_marks)
	await _wait(1.0)


## The farm wears your Unmasked (a cloaked Empty); the film shows a finished hunter, built as Home does on a hero swap.
func _dress_hunter() -> void:
	var at: Vector3 = h.player.position
	var rot: Vector3 = h.player.rotation
	h.player.queue_free()
	h.player = Models.hunter(HUNTER_CLASS, Data.TEAM_COLORS[0], h._weapon(), "", {}, HUNTER_ARCH)
	h.player.position = at
	h.player.rotation = rot
	h.add_child(h.player)
	print("GF hunter arch=%s glb=%s" % [HUNTER_ARCH, WardenGlb.ART.get(HUNTER_ARCH, "?")])
	for n in h.player.find_children("*", "", true, false):
		if n is MeshInstance3D or n is GPUParticles3D or n is CPUParticles3D or n is OmniLight3D or n is Sprite3D or n is Label3D:
			var m := ""
			if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
				m = "%s/%s" % [(n as MeshInstance3D).mesh.get_class(), (n as MeshInstance3D).mesh.resource_name]
			print("GF NODE %s [%s] %s vis=%s" % [h.player.get_path_to(n), n.get_class(), m, n.visible])


## Before each frame is drawn: no words, no billboard icon (hearts, z, work marks, name tags), no UI layer.
func _hide_marks() -> void:
	if not is_instance_valid(h):
		return
	h.ui.visible = false
	var ring := h.player.get_node_or_null("TeamRing") as Node3D
	if ring != null:
		ring.visible = false
	for l in h.find_children("*", "Label3D", true, false):
		(l as Label3D).visible = false
	for sp in h.find_children("*", "Sprite3D", true, false):
		(sp as Sprite3D).visible = false
	for pt in h.find_children("*", "GPUParticles3D", true, false):
		(pt as GPUParticles3D).visible = false
	for pt in h.find_children("*", "CPUParticles3D", true, false):
		(pt as CPUParticles3D).visible = false


func _wait(secs: float) -> void:
	for _i in maxi(1, roundi(secs * FPS)):
		await main.get_tree().process_frame
		_frames += 1
		h.day_t = DAY_T
		if drift != 0.0:
			h.farm_cam.yaw += drift / FPS
		if _zoom_goal >= 0.0:
			h.cam.zoom_to = move_toward(h.cam.zoom_to, _zoom_goal, _zoom_rate / FPS)


var drift := 0.0  # rad/s the view turns on its own
var _zoom_goal := -1.0
var _zoom_rate := 0.0  # wheel units/s toward _zoom_goal


func _stand(at: Vector3, toward: Vector3, near := true) -> void:
	at = h.world.free_spot_near(at, [], 0.8)
	h.ppos = at
	h.player.position = at
	var d := Vector2(toward.x - at.x, toward.z - at.z)
	h.pface = atan2(-d.x, -d.y)
	h.player.rotation.y = h.pface
	h.farm_cam.yaw = -PI / 2.0 - atan2(d.y, d.x)
	h.cam.zoom_to = CamWheel.near() if near else CamWheel.far()
	h.cam.zoom = h.cam.zoom_to
	h.cam.snap(at)


func _put(i: int, at: Vector3, hold := 60.0) -> void:
	var k: Dictionary = h.kins[i]
	k["pos"] = h.world.free_spot_near(at, [], 0.8)
	k["goal"] = k["pos"]
	k["t"] = hold
	(k["node"] as Node3D).position = k["pos"]


func _keys(mv: Vector2) -> void:
	Input.action_press("right", maxf(mv.x, 0.0))
	Input.action_press("left", maxf(-mv.x, 0.0))
	Input.action_press("down", maxf(mv.y, 0.0))
	Input.action_press("up", maxf(-mv.y, 0.0))
	if mv == Vector2.ZERO:
		for a in ["right", "left", "down", "up"]:
			Input.action_release(a)


func _walk(goal: Vector3, secs: float) -> void:
	var left := int(secs * FPS)
	while left > 0 and Vector2(goal.x - h.ppos.x, goal.z - h.ppos.z).length() > 0.5:
		var to := Vector2(goal.x - h.ppos.x, goal.z - h.ppos.z)
		h.farm_cam.yaw = lerp_angle(h.farm_cam.yaw, -PI / 2.0 - to.angle(), 1.6 / FPS)
		_keys(to.normalized().rotated(h.cam.yaw))
		await _wait(1.0 / FPS)
		left -= 1
	_keys(Vector2.ZERO)


## The view's distance eases to `to` over `secs` while the clip goes on (_wait steps it).
func _ease_zoom(to: float, secs: float) -> void:
	_zoom_goal = to
	_zoom_rate = absf(to - float(h.cam.zoom_to)) / secs


func _still(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name))
	print("GF STILL %s" % name)


# ------------------------------------------------------------------ the shots
## A framed view: lens (deg), pitch (deg, 29+ keeps the far island edge out of frame), the view's yaw turn and zoom.
func _view(fov: float, pitch_deg: float, zoom: float) -> void:
	CamRig.rules["farm"]["fov"] = fov
	h.farm_cam.pitch = deg_to_rad(pitch_deg)
	h.cam.zoom_to = CamWheel.near() + zoom * (CamWheel.far() - CamWheel.near())
	h.cam.zoom = h.cam.zoom_to
	_zoom_goal = -1.0


func _group(at: Vector3, offs: Array) -> void:
	for i in offs.size():
		_put(i, at + (offs[i] as Vector3))
	for k in h.kins:
		k.erase("job")


func _stills(tag: String, n: int, gap: float) -> void:
	for i in n:
		await _wait(gap)
		await _still("raw_%s_%d.png" % [tag, i])


func _film() -> void:
	var from := Vector3(36.5, 0, 28.8)
	# shot 1 (wide): the hunter walks east toward the beds, the Bokis ahead and to the sides, the garden leads
	_stand(from, from + Vector3(8, 0, 0.0), false)
	_view(46.0, 27.0, 0.5)
	_group(from, [Vector3(3.4, 0, -2.6), Vector3(4.6, 0, 2.2), Vector3(2.4, 0, 3.4), Vector3(6.5, 0, -0.6)])
	await _wait(0.8)
	_take_from = float(_frames) / FPS
	await _walk(Vector3(40.5, 0, 28.8), 5.0)
	await _stills("s1", 3, 0.5)
	# shot 2 (mid, hard cut): the view turns slowly round the hunter's back and the group in front of him
	var m2 := MEAD + Vector3(1.0, 0, -3.0)
	_stand(m2, m2 + Vector3(1, 0, -0.1), false)
	_view(42.0, 27.0, 0.45)
	h.farm_cam.yaw -= 0.7
	_group(m2, [Vector3(2.8, 0, -2.4), Vector3(2.4, 0, 2.2), Vector3(4.0, 0, 0.3), Vector3(-0.5, 0, 3.6)])
	drift = 0.12
	await _wait(0.5)
	await _stills("s2", 8, 0.75)
	drift = 0.0
	# shot 3 (Boki hero, hard cut): two Bokis between the lens and the hunter, close and readable, hunter soft behind
	_stand(m2, m2 + Vector3(1, 0, 0.0), true)
	var at := h.ppos as Vector3
	_view(36.0, 24.0, 0.1)
	h.farm_cam.yaw += 0.3
	_group(at, [Vector3(4.5, 0, -3.0), Vector3(-1.2, 0, 0.9), Vector3(-0.7, 0, -1.2), Vector3(4.2, 0, 3.4)])
	drift = -0.05
	await _wait(0.4)
	await _stills("s3", 7, 0.6)
	drift = 0.0
	# shot 4 (hunter from behind): he walks away toward the beds, Bokis ahead
	var f4 := Vector3(37.0, 0, 30.2)
	_stand(f4, f4 + Vector3(8, 0, 0.0), true)
	_view(40.0, 26.0, 0.3)
	_group(f4, [Vector3(5.0, 0, -2.8), Vector3(3.6, 0, 2.5), Vector3(5.4, 0, 3.4), Vector3(7.0, 0, 0.6)])
	await _wait(0.4)
	await _walk(Vector3(43.0, 0, 29.8), 4.5)
	await _stills("s4", 3, 0.4)
	print("GF TAKE %.2f %.2f" % [_take_from, float(_frames) / FPS - 0.2])


func _record() -> void:
	var root := ProjectSettings.globalize_path("res://")
	var cfg := root.path_join("override.cfg")
	var f := FileAccess.open(cfg, FileAccess.WRITE)
	f.store_string("[display]\n\nwindow/size/viewport_width=1600\nwindow/size/viewport_height=900\n\n")
	f.store_string("[editor]\n\nmovie_writer/mjpeg_quality=0.9\n")
	f.close()
	var args := ["--path", root, "--rendering-driver", "vulkan", "--audio-driver", "Dummy", "--resolution", SIZE]
	var avi := ProjectSettings.globalize_path(dir).path_join("gf_reel.avi") if dir.is_absolute_path() else root.path_join(dir).path_join("gf_reel.avi")
	args.append_array(["--fixed-fps", str(FPS), "--write-movie", avi, "--"])
	args.append_array(OS.get_cmdline_user_args())
	args.append("--gf-child")
	var out: Array = []
	var rc := OS.execute(OS.get_executable_path(), args, out, true)
	DirAccess.remove_absolute(cfg)
	for line in (String(out[0]) if out.size() > 0 else "").split("\n"):
		if line.begins_with("GF") or line.contains("SCRIPT ERROR") or line.contains("ERROR:"):
			print(line)
	print("GF child rc=%d" % rc)
	main.get_tree().quit(rc)
