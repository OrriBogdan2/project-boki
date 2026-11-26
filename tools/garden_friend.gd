extends RefCounted
## --garden-friend --gf-mode=<faces|reel> [--gf-dir=<dir>] [--gf-species=a,b,c,d]: clean friend-pitch footage of the farm
## (private film tool, not shipped). faces: front close-up of every Boki on main, for the eye check. reel: the garden
## in its close third-person view, golden hour, Motley (ostra, the best in-game model) as the hunter, no HUD, 1600x900 at 30 fps; the child
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
	if "--gf-probe" in OS.get_cmdline_user_args():
		_probe()
		main.get_tree().quit()
		return
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
	fr["dist_max"] = 11.0
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
	_tidy_scene()
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
	for q in h.player.find_children("*", "MeshInstance3D", true, false):  # the hunter's glow haze quads and orbiting cards
		var mi := q as MeshInstance3D
		if mi.mesh is QuadMesh or String(mi.name).begins_with("orbit_cards") or String(mi.name).begins_with("Halo"):
			mi.visible = false
	for k in h.kins:  # the DNA tufts, tail tufts and birthmarks (plain sphere parts of each Boki's unique look)
		for part in (k["node"] as Node3D).find_children("*", "MeshInstance3D", true, false):
			if String(part.name) in _DNA_PARTS:
				(part as MeshInstance3D).visible = false
	for pt in h.find_children("*", "GPUParticles3D", true, false):
		(pt as GPUParticles3D).visible = false
	for pt in h.find_children("*", "CPUParticles3D", true, false):
		(pt as CPUParticles3D).visible = false


const _DNA_PARTS := ["Tuft", "TailTuft", "Birthmark"]
const _CLEAR_MARGIN := 0.45  # m of bare ground kept round a bed or building (grass blades are wide)


## Film only: no crops (the game's crop models are plain primitives), the sun's shadow sharpened.
func _tidy_scene() -> void:
	for pl in h.plots:
		(pl.get_node("Crop") as Node3D).visible = false
	RenderingServer.directional_shadow_atlas_set_size(16384, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
	var sun := h.sun_l as DirectionalLight3D
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 24.0
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.2
	sun.directional_shadow_split_3 = 0.5
	sun.shadow_blur = 2.0
	sun.shadow_normal_bias = 1.5
	_clear_grass()


func _clear_grass() -> void:
	var rects: Array[Rect2] = []
	for pl in h.plots:
		var c: Vector3 = (pl as Node3D).position
		rects.append(Rect2(c.x - 0.85 - _CLEAR_MARGIN, c.z - 0.85 - _CLEAR_MARGIN, 1.7 + 2.0 * _CLEAR_MARGIN, 1.7 + 2.0 * _CLEAR_MARGIN))
	for e in (HomeLayout.ensure(Save.d)["deco"] as Array):
		var sz := HomeLayout.size_of(String(e["id"]), int(e.get("r", 0)))
		var c := HomeLayout.deco_center(e)
		rects.append(Rect2(c.x - sz.x * 0.5 - _CLEAR_MARGIN, c.z - sz.y * 0.5 - _CLEAR_MARGIN, sz.x + 2.0 * _CLEAR_MARGIN, sz.y + 2.0 * _CLEAR_MARGIN))
	var cleared := 0
	if "--gf-probe" in OS.get_cmdline_user_args():
		print("GF rects %s plots=%d" % [str(rects), h.plots.size()])
	for n in h.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		if mmi.multimesh == null or mmi.multimesh.transform_format != MultiMesh.TRANSFORM_3D:
			continue
		var nm := String(mmi.name)
		if "--gf-probe" in OS.get_cmdline_user_args():
			print("GF mmi %s n=%d first=%s" % [nm, mmi.multimesh.instance_count, str(mmi.global_transform * mmi.multimesh.get_instance_transform(0).origin)])
		if not (nm.begins_with("Grass") or nm.begins_with("Flowers") or nm.begins_with("Pebbles") or nm.begins_with("Bushes")):
			continue
		var mm := mmi.multimesh
		for i in mm.instance_count:
			var t := mm.get_instance_transform(i)
			var o := mmi.global_transform * t.origin
			for r in rects:
				if r.has_point(Vector2(o.x, o.z)):
					mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), t.origin))
					cleared += 1
					break
	print("GF grass cleared %d" % cleared)


func _wait(secs: float) -> void:
	for _i in maxi(1, roundi(secs * FPS)):
		await main.get_tree().process_frame
		_frames += 1
		h.day_t = DAY_T
		if face_all:
			for j in h.kins.size():
				(h.kins[j]["node"] as Node3D).rotation.y = _face_yaw + [0.3, -0.2, 0.2, -0.3][j]
		if face_cam != -1:
			(h.kins[face_cam]["node"] as Node3D).rotation.y = _face_yaw
		if drift != 0.0:
			h.farm_cam.yaw += drift / FPS
		if _zoom_goal >= 0.0:
			h.cam.zoom_to = move_toward(h.cam.zoom_to, _zoom_goal, _zoom_rate / FPS)


var face_all := false
var face_cam := -1  # a Boki held turned toward the lens (its close-up)
var _face_yaw := 0.0
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


func _dbg(tag: String) -> void:
	var line := "GF DBG %s player=%s" % [tag, str(h.player.global_position)]
	for k in h.kins:
		var n := k["node"] as Node3D
		line += " | %s %s vis=%s sc=%s" % [k["rec"]["species"], str(n.global_position), n.is_visible_in_tree(), str(n.scale)]
	var cam := main.get_viewport().get_camera_3d()
	line += " || cam=%s fov=%.1f" % [str(cam.global_position), cam.fov]
	for k in h.kins:
		line += " %s" % str(cam.unproject_position((k["node"] as Node3D).global_position))
	print(line)


func _still(name: String) -> void:
	_dbg(name)
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name))
	print("GF STILL %s" % name)


# ------------------------------------------------------------------ the shots
## A framed view: lens (deg), pitch (deg, half the lens + 8 keeps the far island edge out of frame), the view's yaw turn and zoom.
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


func _probe() -> void:
	for i in h.kins.size():
		var n := (h.kins[i]["node"] as Node3D)
		print("GF PROBE kin %d %s children=%d" % [i, species[i], n.get_child_count()])
		for c in n.find_children("*", "Node3D", true, false):
			var line := "GF PROBE   %s [%s] vis=%s" % [n.get_path_to(c), c.get_class(), (c as Node3D).visible]
			if c is MeshInstance3D:
				var mi := c as MeshInstance3D
				var m := mi.mesh
				line += " mesh=%s %s mat=%s ov=%s aabb=%s" % [m.get_class() if m else "-", m.resource_path if m else "", mi.get_active_material(0).get_class() if m and mi.get_active_material(0) else "-", mi.material_override.get_class() if mi.material_override else "-", mi.get_aabb().size]
			print(line)


## The hunter stands at `at` turned 3/4 to a camera that sits `cam_dir` (a ground direction) away from him,
## facing `turn` rad off the camera line; the four Boki are placed by `_row` in the camera's own frame.
func _front(at: Vector3, cam_dir: Vector2, turn: float) -> void:
	_stand(at, at + Vector3(-cam_dir.x, 0, -cam_dir.y) * 8.0, false)  # camera behind a hunter facing away from it
	var to_cam := cam_dir.normalized().rotated(turn)
	h.pface = atan2(-to_cam.x, -to_cam.y)
	h.player.rotation.y = h.pface


## Boki at `rel` = (across, toward camera) metres from the hunter, in the camera's frame.
func _row(at: Vector3, cam_dir: Vector2, rel: Array) -> void:
	var fwd := cam_dir.normalized()
	var side := Vector2(-fwd.y, fwd.x)
	for i in rel.size():
		var r: Vector2 = rel[i]
		var o := side * r.x + fwd * r.y
		_put(i, at + Vector3(o.x, 0, o.y))
		var k: Dictionary = h.kins[i]
		k.erase("job")


## A close-up of Boki `i` alone: the hunter's spot (and body, hidden) is where the Boki stands, so the view frames it.
func _closeup(i: int, spot: Vector3, cd: Vector2, turn: float) -> void:
	_front(spot, cd, 0.0)
	h.player.visible = false
	_view([24.0, 22.0, 21.0, 22.0][i], 19.0, 0.12)
	CamRig.rules["farm"]["rise"] = 0.65  # the steeper view looks a little higher, so a knee-high Boki sits mid-frame
	for j in h.kins.size():
		_put(j, spot + (Vector3.ZERO if j == i else Vector3(-30 - j, 0, -30)))
		h.kins[j].erase("job")
	var to_cam := cd.normalized().rotated(turn)
	_face_yaw = atan2(-to_cam.x, -to_cam.y)
	face_cam = i


## The open spot for the film: least trees, rocks or edge in the strip the lens looks across (8 m west to 3 m east).
func _clear_spot(near: Vector3) -> Vector3:
	var best := near
	var best_n := 99999
	for cx in range(int(near.x) - 8, int(near.x) + 9):
		for cz in range(int(near.z) - 8, int(near.z) + 9):
			var n := 0
			for sx in range(cx - 9, cx + 5):
				for sz in range(cz - 4, cz + 5):
					if h.world.is_block(sx + 0.5, sz + 0.5) or h.world.is_void(sx + 0.5, sz + 0.5):
						n += 1
			n = n * 10 + int(Vector2(cx - near.x, cz - near.z).length())
			if n < best_n:
				best_n = n
				best = Vector3(cx + 0.5, 0, cz + 0.5)
	print("GF spot %s score %d" % [str(best), best_n])
	return best


func _mark(name: String) -> void:
	print("GF SHOT %s %.3f" % [name, float(Engine.get_frames_drawn()) / FPS])


func _film() -> void:
	var H := _clear_spot(Vector3(56.0, 0, 29.0))
	var cd := Vector2(-1.0, 0.35).normalized()  # the camera sits west, a little south: looking east over open meadow
	# shot 1 (wide): the meadow, hunter in 3/4 front, the four Boki round him
	_mark("wide_1")
	_front(H, cd, 0.6)
	CamRig.rules["farm"]["rise"] = 0.7
	_view(34.0, 31.0, 0.3)
	_row(H, cd, [Vector2(-1.9, -0.5), Vector2(-0.8, 1.2), Vector2(0.6, 1.3), Vector2(1.7, 0.7)])  # the fox (0) back, its tail-tip glow small
	await _wait(1.2)
	_take_from = float(_frames) / FPS
	_ease_zoom(CamWheel.near() + 0.2 * (CamWheel.far() - CamWheel.near()), 4.5)
	await _stills("w", 3, 1.5)
	if "--gf-quick" in OS.get_cmdline_user_args():
		return
	# shot 2 (hunter, hard cut): 3/4 face, the view turned off the trees; he walks a few steps toward the lens
	_mark("hunter")
	_front(H, cd, -0.25)
	_view(21.0, 25.0, 0.45)
	h.farm_cam.yaw += 0.45
	_row(H, cd, [Vector2(-9, 14), Vector2(-9, 15), Vector2(9, 14), Vector2(9, 15)])
	await _wait(0.8)
	await _still("raw_h_0.png")
	await _wait(0.4)
	var fd := Vector2(-sin(h.pface), -cos(h.pface))  # the way he faces, on the ground
	for _i in 30:
		_keys(fd * 0.3)
		await _wait(1.0 / FPS)
		if _i == 15:
			await _still("raw_h_walk.png")
	_keys(Vector2.ZERO)
	await _wait(0.6)
	await _still("raw_h_1.png")
	# shot 2b (the four Boki in a row, hunter out of the picture, all turned to the lens)
	_mark("bokis")
	CamRig.rules["farm"]["rise"] = 0.4
	_front(H, cd, 0.0)
	h.player.visible = false
	_view(28.0, 26.0, 0.5)
	_row(H, cd, [Vector2(-0.9, 1.6), Vector2(0.05, 1.6), Vector2(1.0, 1.6), Vector2(1.95, 1.6)]  # +x is screen left)
	face_all = true
	_face_yaw = atan2(-cd.x, -cd.y)
	await _wait(0.6)
	await _stills("r", 3, 0.7)
	face_all = false
	h.player.visible = true
	CamRig.rules["farm"]["rise"] = 0.85
	# shot 3 (Boki close-ups, hard cuts): each one alone, 3/4 to the lens, upright
	var spot := H + Vector3(cd.x, 0, cd.y) * 2.5
	for i in 4:
		_mark("closeup_%d" % i)
		_closeup(i, spot, cd, [0.35, -0.3, 0.3, -0.35][i])
		await _wait(0.5)
		await _stills("c%d" % i, 2, 0.6)
	face_cam = -1
	h.player.visible = true
	CamRig.rules["farm"]["rise"] = 0.85
	# shot 4 (wide again, slow turn)
	_mark("wide_2")
	_front(H, cd, 0.6)
	_view(34.0, 31.0, 0.26)
	_row(H, cd, [Vector2(1.9, -0.4), Vector2(0.6, 1.1), Vector2(-0.7, 1.0), Vector2(-1.8, 0.6)])
	h.farm_cam.yaw += 0.7
	drift = -0.12
	await _wait(0.4)
	await _stills("w2", 4, 1.0)
	drift = 0.0
	_mark("end")
	print("GF TAKE %.2f %.2f" % [_take_from, float(Engine.get_frames_drawn()) / FPS])


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
