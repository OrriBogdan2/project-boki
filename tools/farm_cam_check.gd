extends RefCounted
## --farm-cam-check: the farm's close third-person view (FarmCam, content/rules/camera.json "farm").
##   0. in the farm it settles at the rules' pitch, lens and distance, behind you, and the bodies are not leaned back
##   1. W walks away from the camera at every orbit angle (keys turned to the view)
##   2. a wall behind you pulls the camera in (and nothing it passes is inside the ground or the wall), and it backs
##      out again when the wall goes
##   3. build mode blends back to the Settings view (pitch, lens, north up); leaving it comes back
##   4. "third_person": false leaves the Settings view and the plain keys, and a match camera is not touched

const FRAMES := 900
var bad := 0
var main: Node
var home


func ok(cond: bool, what: String) -> void:
	print("FARMCAM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _settle(want_k: float) -> void:
	for i in FRAMES:
		await main.get_tree().process_frame
		if absf(home.farm_cam.k - want_k) < 0.001:
			break
	for i in 30:
		await main.get_tree().process_frame


func _zoomed() -> void:
	for i in FRAMES:
		await main.get_tree().process_frame
		if absf(home.cam.zoom - home.cam.zoom_to) < 0.005:
			break


func _back() -> float:
	return home.cam.global_position.distance_to(home.cam.focus + Vector3(0, home.cam.rise, 0))


func _style_pitch() -> float:
	return deg_to_rad(float(CamRig.styles[home.cam.style_id]["pitch"]))


func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	home = await main._hb_home()
	home._close_panel()
	var r := FarmCam.rules()
	var on0 := bool(r["third_person"])
	home.ppos = HomeLayout.LANDING + Vector3(-6, 0, -3)
	home.py = 0.0
	home.pvy = 0.0
	home.cam.zoom_to = CamWheel.far()
	home.cam.zoom = CamWheel.far()
	home.cam.snap(home.ppos)
	await _settle(1.0)
	_third_part(r)
	_keys_part()
	await _wheel_part(r)
	await _wall_part()
	await _prop_part()
	await _game_part()
	await _build_part()
	await _flag_part()
	r["third_person"] = on0
	print("FARMCAM CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _third_part(r: Dictionary) -> void:
	var cam: CamRig = home.cam
	ok(home.farm_cam.third(), "the farm opens in the third-person view (k %.2f)" % home.farm_cam.k)
	ok(
		absf(cam.pitch - deg_to_rad(float(r["pitch_deg"]))) < 0.01,
		"pitch %.1f deg is the rules' %.1f" % [rad_to_deg(cam.pitch), float(r["pitch_deg"])]
	)
	var d := _back()
	ok(
		d > float(r["dist_min"]) - 0.1 and d < float(r["dist_max"]) + 0.1,
		"the camera is %.1f m back (%.1f..%.1f)" % [d, float(r["dist_min"]), float(r["dist_max"])]
	)
	ok(cam.global_position.z > cam.focus.z, "the camera is south of you with the view at yaw 0 (looking north)")
	ok(cam.char_lean() == Basis(), "bodies are not tipped back at this low angle")
	ok(home.cam.get_viewport().get_camera_3d() == cam, "it is the farm's current camera")


func _keys_part() -> void:
	var cam: CamRig = home.cam
	var all_ok := true
	for deg in [0, 40, 90, 180, -135]:
		cam.yaw = deg_to_rad(deg)
		cam.yaw_to = cam.yaw
		cam._apply(Vector3.ZERO)
		var fwd: Vector3 = (cam.focus - cam.global_position) * Vector3(1, 0, 1)
		var w: Vector2 = home.farm_cam.keys(Vector2(0, -1), cam)
		var walk := Vector3(w.x, 0, w.y)
		all_ok = all_ok and walk.dot(fwd.normalized()) > 0.99
		var s: Vector2 = home.farm_cam.keys(Vector2(1, 0), cam)  # D: to the right of the view
		all_ok = all_ok and Vector3(s.x, 0, s.y).dot(fwd.normalized().cross(Vector3.UP)) > 0.99
	ok(all_ok, "W goes away from the camera and D to its right at yaw 0, 40, 90, 180 and -135 deg")
	cam.yaw = 0.0
	cam.yaw_to = 0.0


func _wheel_part(r: Dictionary) -> void:
	var cam: CamRig = home.cam
	var far := _back()
	cam.zoom_to = CamWheel.near()
	await _zoomed()
	var near := _back()
	ok(near < far - 1.0 and near < float(r["dist_min"]) + 0.6, "wheel in: %.1f m back, from %.1f m" % [near, far])
	cam.zoom_to = CamWheel.ctrl_zoom()
	await _zoomed()
	var wide := _back()
	ok(wide > far + 0.5 and wide < float(r["dist_max"]) * 2.0, "the Ctrl look: %.1f m back" % wide)
	cam.zoom_to = CamWheel.far()
	await _zoomed()
	ok(absf(_back() - far) < 0.2, "wheel out again: %.1f m back" % _back())


func _wall_part() -> void:
	var w: World = home.world
	var cam: CamRig = home.cam
	await _settle(1.0)
	var free := _back()
	var tiles: Array = []
	var px := int(floor(home.ppos.x))
	var pz := int(floor(home.ppos.z))
	for dx in range(-2, 3):
		for dz in range(2, 5):
			tiles.append([w.idx(px + dx, pz + dz), w.kind[w.idx(px + dx, pz + dz)]])
			w.kind[w.idx(px + dx, pz + dz)] = World.T_BLOCK
	for i in 120:
		await main.get_tree().process_frame
	var near := _back()
	var aim: Vector3 = cam.focus + Vector3(0, cam.rise, 0)
	var rise_deg := rad_to_deg(asin((cam.global_position.y - aim.y) / near))
	ok(
		near > float(FarmCam.rules()["wall_min_m"]) - 0.3 and rise_deg > float(FarmCam.rules()["pitch_deg"]) + 10.0,
		(
			"a wall 2 m behind: the camera keeps %.1f m from you and tips up (%.0f deg, from %.0f)"
			% [near, rise_deg, float(FarmCam.rules()["pitch_deg"])]
		)
	)
	var inside := false
	var s := 0.0
	while s <= near - 0.1:
		var p: Vector3 = aim + (cam.global_position - aim).normalized() * s
		inside = inside or FarmCam._blocked(home, p, 0.0)
		s += 0.1
	ok(
		not inside and cam.global_position.y > w.ground_at(cam.global_position.x, cam.global_position.z),
		(
			"no point of the view is inside a wall or the ground (inside %s, %.2f m back, y %.2f)"
			% [inside, near, cam.global_position.y]
		)
	)
	for t in tiles:
		w.kind[t[0]] = t[1]
	for i in FRAMES:
		await main.get_tree().process_frame
		if _back() > free - 0.05:
			break
	ok(_back() > free - 0.1, "the wall gone, it backs out to %.1f m again" % _back())


## The portal ring and the glider rack stand off the tile grid: with one between you and the camera, the camera comes
## in front of it (never inside it) rather than looking through it.
func _prop_part() -> void:
	var cam: CamRig = home.cam
	for nm in ["portal", "rack"]:
		var at: Vector3 = home.spots[nm]
		home.ppos = at + Vector3(0.0, 0.0, -2.0)  # you stand north of it, the camera south
		home.cam.snap(home.ppos)
		for i in 90:
			await main.get_tree().process_frame
		var aim: Vector3 = cam.focus + Vector3(0, cam.rise, 0)
		var through := false
		var s := 0.0
		var dist := _back()
		while s <= dist:
			through = through or FarmCam._in_prop(home, aim + (cam.global_position - aim).normalized() * s, 0.0)
			s += 0.1
		ok(
			not through,
			(
				"the %s: nothing of the view is inside it (%.1f m back, camera z %.1f, it at %.1f)"
				% [nm, dist, cam.global_position.z, at.z]
			)
		)
	home.ppos = HomeLayout.LANDING + Vector3(-6, 0, -3)
	home.cam.snap(home.ppos)
	await _settle(1.0)


class Round:
	extends RefCounted

	func playing() -> bool:
		return true

	func tick(_d: float) -> void:
		pass

	func input(_e: InputEvent) -> bool:
		return false

	func find(_p: Vector2) -> Dictionary:
		return {}


## A minigame round tips the view up and draws it back (to show the court), and eases it back after.
func _game_part() -> void:
	var cam: CamRig = home.cam
	home.ppos = HomeLayout.LANDING + Vector3(-6, 0, -3)
	cam.snap(home.ppos)
	await _settle(1.0)
	await _zoomed()
	var before := float(FarmCam.rules()["dist_max"])
	var games: Array = home.games
	home.games = [Round.new()]
	for i in 150:
		await main.get_tree().process_frame
	var rise := rad_to_deg(cam.pitch)
	ok(
		rise > float(FarmCam.rules()["game_pitch_deg"]) - 3.0 and _back() > before + 1.0,
		"a minigame round: the view tips up (%.0f deg) and draws back (%.1f m, from %.1f)" % [rise, _back(), before]
	)
	home.games = games
	for i in 150:
		await main.get_tree().process_frame
	ok(absf(_back() - before) < 0.3, "the round over, the view comes back to %.1f m" % _back())


func _build_part() -> void:
	var cam: CamRig = home.cam
	home.building_now = true
	await _settle(0.0)
	ok(
		absf(cam.pitch - _style_pitch()) < 0.01 and absf(cam.yaw) < 0.01,
		"build mode: the Settings view, north up (pitch %.0f deg)" % rad_to_deg(cam.pitch)
	)
	ok(not home.farm_cam.third(), "build mode: the keys and facing are the top-down ones")
	home.building_now = false
	await _settle(1.0)
	ok(home.farm_cam.third() and cam.pitch < deg_to_rad(40.0), "leaving build mode: third person again")


func _flag_part() -> void:
	var cam: CamRig = home.cam
	FarmCam.rules()["third_person"] = false
	home.farm_cam.k = 0.0
	cam.yaw = 0.0
	cam.yaw_to = 0.0
	cam.lean_scale = 1.0
	cam.use_style(cam.style_id)  # (a start with the flag off: nothing ever wrote the view)
	for i in 40:
		await main.get_tree().process_frame
	ok(
		absf(cam.pitch - _style_pitch()) < 0.01,
		"flag off: the farm keeps the Settings view (pitch %.0f deg)" % rad_to_deg(cam.pitch)
	)
	ok(
		not home.farm_cam.third() and home.farm_cam.keys(Vector2(0, -1), cam).is_equal_approx(Vector2(0, -1)),
		"flag off: plain keys"
	)
	var match_cam := CamRig.new()
	match_cam.use_style("default")
	ok(
		match_cam.lean_scale == 1.0 and match_cam.char_lean() != Basis(),
		"a match camera still leans its bodies and is top-down"
	)
	match_cam.free()
