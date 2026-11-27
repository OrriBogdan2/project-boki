extends RefCounted
## --garden-carry-film [--gc-dir=<dir>]: film of the real farm carry (HomeCarry) for a friend: Sable runs across the
## garden, four Boki hop over, she lifts one (the real lift and arms hold), spins and jumps with it, runs on with the
## others at her heels, sets it down, pats it. Close third-person farm view, golden hour, no HUD, 1920x1080 at 60 fps.
## Private film tool (GPU worker, not shipped). It re-runs itself as a child Godot under the movie writer; the child
## prints "GC SHOT <name> <start_s> <end_s>" for each take (the encode step dissolves them) and saves the stills.

const FPS := 60
const SIZE := "1920x1080"
const ISLAND_SEED := 11
const DAY_T := 0.72  # farm clock: golden hour (low honey sun)
const DEADLINE_S := 1500.0
const HUNTER_CLASS := "medium"
const RUN_OFF := 1.25  # rad off her back-line in the run shot: a three-quarter side view, her face turned to us
const CARRY_PACE := 0.8  # stick in the carry run: the followers keep up
const HEAD_S := 0.55  # s of each take that the dissolve eats at its start and at its end
const CLEAR_MARGIN := 0.45  # m of bare ground kept round a bed or building (grass blades are wide)
const DNA_PARTS := ["Tuft", "TailTuft", "Birthmark"]  # plain sphere parts of a Boki's unique look
const SPECS := [["burrlet", "Moss"], ["cindle", "Ash"], ["puddlet", "Dew"], ["heatherhorn", "Haggis"]]

var main: Node
var hunter_arch := "thief"  # Sable, on her live v95 glb (WardenGlb.ART); --gc-arch=ostra films Motley
var h
var dir := "gc"
var _frames := 0
var _take_from := 0.0
var _zoom_goal := -1.0
var _zoom_rate := 0.0
var _yaw_goal := NAN  # the view turns toward this over time (rad/s _yaw_rate)
var _yaw_rate := 0.0
var _heartbeat := {}  # the Boki that cling to the hunter (kept in the greet run)


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--gc-dir="):
			dir = String(a).substr(9)
		if String(a).begins_with("--gc-arch="):
			hunter_arch = String(a).substr(10)
	DirAccess.make_dir_recursive_absolute(dir)
	if "--gc-child" not in OS.get_cmdline_user_args():
		_record()
		return
	Save.no_write = true
	Content.rules("farm_build")["base_mode"] = true
	seed(ISLAND_SEED)
	_make_save()
	main.get_tree().create_timer(DEADLINE_S).timeout.connect(main.get_tree().quit.bind(1))
	await _open()
	await _film()
	print("GC DONE")
	main.get_tree().quit()


# ------------------------------------------------------------------ the garden
func _make_save() -> void:
	var d := Save.fresh()
	for i in SPECS.size():
		var rec := Save.new_kin(SPECS[i][0], SPECS[i][1], 700 + i)
		rec["uid"] = "gc%d" % i
		rec["trust"] = 95.0
		for need in Care.NEEDS:
			rec["needs"][need] = 95.0
		Unique.of(rec)["size"] = 0.0  # an average one: its weight is its species' weight
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["cls"] = HUNTER_CLASS
	d["arch"] = hunter_arch
	d["tutorial"] = {"home": true, "hatched": true, "intro": true, "day1_done": true}
	var crops: Array = Data.CROPS.keys()
	for i in 4:
		d["plots"][i] = {"crop": crops[i % crops.size()], "stage": 1 + i % 3, "care": 0, "wt": 0.0}
	HomeLayout.new_fs(d, ISLAND_SEED)
	HomeLayout.ensure(d)
	Save.d = d


func _open() -> void:
	h = await main._hb_home()
	h.day_t = DAY_T
	Settings.set_v("tips", false)
	h._close_panel()
	h.ui.visible = false
	if main.get("fade") != null:  # the boot splash stays up until told to go
		await main.fade.reveal(0.01)
	_dress_hunter()
	_tidy_scene()
	RenderingServer.frame_pre_draw.connect(_hide_marks)
	await _wait(1.0)


## The farm wears your Unmasked (a cloaked Empty); the film shows a finished hunter, built as Home does on a hero swap.
func _dress_hunter() -> void:
	var at: Vector3 = h.player.position
	var rot: Vector3 = h.player.rotation
	h.player.queue_free()
	h.player = Models.hunter(HUNTER_CLASS, Data.TEAM_COLORS[0], h._weapon(), "", {}, hunter_arch)
	h.player.position = at
	h.player.rotation = rot
	h.add_child(h.player)
	print("GC hunter arch=%s glb=%s" % [hunter_arch, WardenGlb.ART.get(hunter_arch, "?")])


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
	for q in h.player.find_children("*", "MeshInstance3D", true, false):  # glow haze quads and orbiting cards
		var mi := q as MeshInstance3D
		if mi.mesh is QuadMesh or String(mi.name).begins_with("orbit_cards") or String(mi.name).begins_with("Halo"):
			mi.visible = false
	for k in h.kins:
		for part in (k["node"] as Node3D).find_children("*", "MeshInstance3D", true, false):
			if part.name in DNA_PARTS:
				(part as MeshInstance3D).visible = false
	for sp in h.find_children("*", "Sprite3D", true, false):
		(sp as Sprite3D).visible = false
	for pt in h.find_children("*", "GPUParticles3D", true, false):
		(pt as GPUParticles3D).visible = false


## Film only: no crop models (plain primitives), soft sun shadows, bare ground in the beds.
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
	var rects: Array[Rect2] = []
	for pl in h.plots:
		var c: Vector3 = (pl as Node3D).position
		var w := 1.7 + 2.0 * CLEAR_MARGIN
		rects.append(Rect2(c.x - w * 0.5, c.z - w * 0.5, w, w))
	for e in HomeLayout.ensure(Save.d)["deco"] as Array:
		var sz := HomeLayout.size_of(String(e["id"]), int(e.get("r", 0)))
		var c := HomeLayout.deco_center(e)
		rects.append(
			Rect2(
				c.x - sz.x * 0.5 - CLEAR_MARGIN,
				c.z - sz.y * 0.5 - CLEAR_MARGIN,
				sz.x + 2.0 * CLEAR_MARGIN,
				sz.y + 2.0 * CLEAR_MARGIN
			)
		)
	for ch in h.get_children():  # the Ferry and Expeditions stands and the portal ring fill the meadow: not in this film
		var ring := ch.get_node_or_null("Ring") as MeshInstance3D
		if ring != null and ring.mesh is TorusMesh:
			(ch as Node3D).visible = false
		for l in ch.find_children("*", "Label3D", true, false):
			if (l as Label3D).text in ["Ferry", "Expeditions"]:
				(ch as Node3D).visible = false
	var cleared := 0
	for n in h.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		var nm := String(mmi.name)
		if mmi.multimesh == null or mmi.multimesh.transform_format != MultiMesh.TRANSFORM_3D:
			continue
		if not (
			nm.begins_with("Grass")
			or nm.begins_with("Flowers")
			or nm.begins_with("Pebbles")
			or nm.begins_with("Bushes")
		):
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
	print("GC grass cleared %d" % cleared)


# ------------------------------------------------------------------ the film helpers
func _wait(secs: float) -> void:
	for _i in maxi(1, roundi(secs * FPS)):
		await main.get_tree().process_frame
		_frames += 1
		h.day_t = DAY_T
		if _zoom_goal >= 0.0:
			h.cam.zoom_to = move_toward(h.cam.zoom_to, _zoom_goal, _zoom_rate / FPS)
		if not is_nan(_yaw_goal):
			h.farm_cam.yaw = lerp_angle(h.farm_cam.yaw, _yaw_goal, minf(_yaw_rate / FPS, 1.0))


func _keys(mv: Vector2) -> void:
	for a in ["right", "left", "down", "up"]:
		Input.action_release(a)
	Input.action_press("right", maxf(mv.x, 0.0))
	Input.action_press("left", maxf(-mv.x, 0.0))
	Input.action_press("down", maxf(mv.y, 0.0))
	Input.action_press("up", maxf(-mv.y, 0.0))
	if mv == Vector2.ZERO:
		for a in ["right", "left", "down", "up"]:
			Input.action_release(a)


## The view stands at `off` rad off the line behind the hunter facing `toward` (PI: in front of him).
func _view_behind(toward: Vector2, off := 0.0) -> float:
	return -PI / 2.0 - toward.angle() + off


func _stand(at: Vector3, toward: Vector3, cam_off := 0.0) -> void:
	at = h.world.free_spot_near(at, [], 0.8)
	h.ppos = at
	h.player.position = at
	var d := Vector2(toward.x - at.x, toward.z - at.z)
	h.pface = atan2(-d.x, -d.y)
	h.player.rotation.y = h.pface
	h.farm_cam.yaw = _view_behind(d, cam_off)
	_yaw_goal = NAN
	h.cam.zoom = h.cam.zoom_to
	h.cam.snap(at)


func _put(i: int, at: Vector3) -> void:
	var k: Dictionary = h.kins[i]
	k["pos"] = h.world.free_spot_near(at, [], 0.8)
	k["goal"] = k["pos"]
	k["t"] = 60.0
	k.erase("job")
	(k["node"] as Node3D).position = k["pos"]


## One take: where the hunter stands, where he faces, where the view starts.
func _view(fov: float, pitch_deg: float, zoom: float, rise := 0.85) -> void:
	CamRig.rules["farm"]["fov"] = fov
	CamRig.rules["farm"]["rise"] = rise
	h.farm_cam.pitch = deg_to_rad(pitch_deg)
	h.cam.zoom_to = CamWheel.near() + zoom * (CamWheel.far() - CamWheel.near())
	h.cam.zoom = h.cam.zoom_to
	_zoom_goal = -1.0


func _ease_zoom(zoom: float, secs: float) -> void:
	_zoom_goal = CamWheel.near() + zoom * (CamWheel.far() - CamWheel.near())
	_zoom_rate = absf(_zoom_goal - float(h.cam.zoom_to)) / secs


## The view turns to `yaw` over about `secs`.
func _turn_view(yaw: float, secs: float) -> void:
	_yaw_goal = yaw
	_yaw_rate = 1.0 / (secs * 0.5)


## The hunter runs for `secs` toward `goal` (ground point), the view keeping `off` rad off the back-line; `pace` scales
## the stick; the Boki in `pull` keep running (not walking) at the hunter's heels.
func _run(goal: Vector3, secs: float, off: float, stop_at := 0.6, pace := 1.0, pull: Array = []) -> void:
	var left := int(secs * FPS)
	while left > 0:
		var to := Vector2(goal.x - h.ppos.x, goal.z - h.ppos.z)
		if to.length() < stop_at:
			break
		_yaw_goal = _view_behind(to, off)
		_yaw_rate = 1.8
		_keys(to.normalized().rotated(h.cam.yaw) * pace)
		var was: Vector3 = h.ppos
		await _wait(1.0 / FPS)
		var mine := Vector2(h.ppos.x - was.x, h.ppos.z - was.z).length() * FPS
		for i in pull:  # as HomeCarry._lead: a led Boki goes at your pace, never under its gallop
			h.kins[i]["led"] = maxf(mine, BokiRig.RUN_SPEED) * 1.1
		left -= 1
	_keys(Vector2.ZERO)


func _jump() -> void:
	Input.action_press("jump")
	await _wait(1.0 / FPS)
	Input.action_release("jump")


## The real greeting run (BaseGreet): the Boki hops over to a spot beside the hunter and follows him a while.
func _call_over(i: int, follow_s: float) -> void:
	var k: Dictionary = h.kins[i]
	for key in ["play", "eat", "nap_t", "life_at", "life_it", "notice_away", "led", "job"]:
		k.erase(key)
	k["nap_t"] = 0.0
	h.life.machine(k).go(BaseLife.S.ROAM, "film")
	k["life_greet"] = {"runs": true, "reached": -1.0}
	BaseGreet.rules()["follow_s"] = follow_s
	h.life.machine(k).go(BaseLife.S.GREET, "film")
	k["life_greet"] = {"runs": true, "reached": -1.0}


func _mark(name: String, start: bool) -> void:
	print("GC %s %s %.3f" % ["START" if start else "END", name, float(Engine.get_frames_drawn()) / FPS])


func _still(name: String) -> void:
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(name))
	print("GC STILL %s" % name)


func _dbg(tag: String) -> void:
	var line := "GC DBG %s hunter=%s" % [tag, str(h.player.global_position)]
	for k in h.kins:
		line += (
			" | %s %s %s"
			% [k["rec"]["name"], str((k["node"] as Node3D).global_position), h.life.machine(k).state_name()]
		)
	print(line)


## The open ground near `near` with the fewest trees, rocks and edge in the strip the lens looks across.
func _clear_spot(near: Vector3, wide: int) -> Vector3:
	var best := near
	var best_n := 99999
	for cx in range(int(near.x) - 8, int(near.x) + 9):
		for cz in range(int(near.z) - 8, int(near.z) + 9):
			var n := 0
			for sx in range(cx - wide, cx + wide + 1):
				for sz in range(cz - wide, cz + wide + 1):
					if h.world.is_block(sx + 0.5, sz + 0.5) or h.world.is_void(sx + 0.5, sz + 0.5):
						n += 1
			n = n * 10 + int(Vector2(cx - near.x, cz - near.z).length())
			if n < best_n:
				best_n = n
				best = Vector3(cx + 0.5, 0, cz + 0.5)
	print("GC spot %s score %d" % [str(best), best_n])
	return best


# ------------------------------------------------------------------ the shots
func _film() -> void:
	print("GC start %s plots=%d deco=%s" % [str(h.ppos), h.plots.size(), str(HomeLayout.ensure(Save.d)["deco"])])
	var meadow := _clear_spot(h.ppos + Vector3(6.0, 0, 0), 5)  # the meadow the Boki gather on
	var kind: String = HomeCarry.mode_for(h.kins[0]["rec"])
	print("GC carry mode of %s: %s" % [h.kins[0]["rec"]["species"], kind])
	await _shot_run(meadow)
	await _shot_lift(meadow)
	await _shot_carry(meadow)
	await _shot_set_down(meadow)
	print("GC FILM %.2f" % (float(_frames) / FPS))


## 1: the hunter runs across the garden toward the group; the Boki see him and hop over.
func _shot_run(meadow: Vector3) -> void:
	var from := meadow + Vector3(-12.0, 0, 5.0)  # the corridor the carry shot also runs: no prop pulls the lens in
	for i in 4:
		_put(i, meadow + Vector3([0.0, 1.6, -1.2, 0.4][i], 0, [0.0, 1.3, 1.5, -1.6][i]))
	_stand(from, meadow, RUN_OFF)
	_view(34.0, 16.0, 0.75, 0.9)
	_mark("run", true)
	await _wait(HEAD_S)
	h.life.machine(h.kins[0]).go(BaseLife.S.ROAM, "film")
	await _run(meadow + Vector3(-4.5, 0, 1.0), 6.0, RUN_OFF)
	for i in 4:
		_call_over(i, 8.0)
	await _run(meadow + Vector3(-1.8, 0, 0.4), 3.0, RUN_OFF)
	await _wait(1.5)
	await _still("run_end.png")
	_dbg("run")
	await _wait(HEAD_S)
	_mark("run", false)


## 2: close, in front of him: he lifts a Boki, spins and jumps with it.
func _shot_lift(meadow: Vector3) -> void:
	var k: Dictionary = h.kins[0]
	_mark("lift", true)
	_stand(meadow + Vector3(-1.0, 0, 0.0), meadow + Vector3(4.0, 0, 0.0), PI + 0.75)
	_put(1, meadow + Vector3(1.0, 0, 2.4))
	_put(2, meadow + Vector3(0.0, 0, -2.4))
	_put(3, meadow + Vector3(1.6, 0, 1.4))
	_put(0, h.ppos + Vector3(-sin(h.pface), 0, -cos(h.pface)) * 1.0)
	_view(32.0, 14.0, 0.55, 0.9)
	await _wait(HEAD_S + 0.5)
	h.carry.press_hold(k)
	await _wait(1.6)
	await _still("lift_hold.png")
	# spin once on the spot, the Boki in his arms
	_turn_view(h.farm_cam.yaw + 1.2, 2.4)
	for i in 60:
		h.pface += TAU / 60.0
		h.player.rotation.y = h.pface
		await _wait(1.0 / FPS)
	await _wait(0.3)
	await _jump()
	await _wait(1.1)
	await _still("lift_jump.png")
	await _wait(HEAD_S)
	_mark("lift", false)


## 3: he runs on with it past the beds, the others at his heels, the view in front of him.
func _shot_carry(meadow: Vector3) -> void:
	_mark("carry", true)
	var start := meadow + Vector3(7.0, 0, 5.0)
	var goal := meadow + Vector3(-12.0, 0, 5.0)
	_stand(start, goal, PI + 0.4)
	_view(34.0, 15.0, 0.55, 0.85)
	for i in range(1, 4):
		_put(i, h.ppos + Vector3(2.0 + i, 0, 0.5 * i))
		_call_over(i, 20.0)
	await _wait(HEAD_S)
	for leg in 3:  # the followers are called over again each leg so they stay at his heels
		await _run(goal, 3.4 / CARRY_PACE, PI + 0.4, 1.0, CARRY_PACE, [1, 2, 3])
		for i in range(1, 4):
			_call_over(i, 20.0)
		if leg == 1:
			await _still("carry_mid.png")
	_dbg("carry")
	await _wait(HEAD_S)
	_mark("carry", false)


## 4: he sets it down; it hops and settles; the others play round; he pats it.
func _shot_set_down(meadow: Vector3) -> void:
	var k: Dictionary = h.kins[0]
	_mark("down", true)
	# behind and aside: the Boki that face him face the lens too
	_stand(meadow + Vector3(1.0, 0, 6.0), meadow + Vector3(3.0, 0, 6.0), 1.1)
	_put(1, h.ppos + Vector3(2.5, 0, -1.5))
	_put(2, h.ppos + Vector3(2.0, 0, 1.8))
	_put(3, h.ppos + Vector3(3.2, 0, 0.2))
	_view(32.0, 15.0, 0.85, 1.0)
	await _wait(HEAD_S + 0.5)
	h.carry.drop()
	await _wait(0.8)
	k["joy_t"] = 1.2
	await _still("down_set.png")
	await _wait(3.0)
	h._pet_kin(k)
	await _wait(3.0)
	await _still("down_pet.png")
	await _wait(HEAD_S)
	_mark("down", false)


func _record() -> void:
	var root := ProjectSettings.globalize_path("res://")
	var cfg := root.path_join("override.cfg")
	var f := FileAccess.open(cfg, FileAccess.WRITE)
	f.store_string("[display]\n\nwindow/size/viewport_width=1920\nwindow/size/viewport_height=1080\n\n")
	f.store_string("[editor]\n\nmovie_writer/mjpeg_quality=0.9\n")
	f.close()
	var args := ["--path", root, "--rendering-driver", "vulkan", "--audio-driver", "Dummy", "--resolution", SIZE]
	var avi := dir.path_join("gc_reel.avi") if dir.is_absolute_path() else root.path_join(dir).path_join("gc_reel.avi")
	args.append_array(["--fixed-fps", str(FPS), "--write-movie", avi, "--"])
	args.append_array(OS.get_cmdline_user_args())
	args.append("--gc-child")
	var out: Array = []
	var rc := OS.execute(OS.get_executable_path(), args, out, true)
	DirAccess.remove_absolute(cfg)
	for line in (String(out[0]) if out.size() > 0 else "").split("\n"):
		if line.begins_with("GC") or line.contains("SCRIPT ERROR") or line.contains("ERROR:"):
			print(line)
	print("GC child rc=%d" % rc)
	main.get_tree().quit(rc)
