extends RefCounted
## --garden-zone-shots --zone=<id> --shots-dir=<dir>: the zone by day, by night and from far away (zone_day.png,
## zone_night.png, zone_wide.png), with the base's six Boki out. Needs a renderer (jobq --needs gpu).
## --third [--res=1920x1080]: instead the farm's close third-person view (FarmCam) at four spots (arrive, boki, building,
## slope): <spot>.png and GZ3P lines. Flags: clip (camera inside a wall or tree), hidden-you/-boki (a wall between),
## offscreen-*, small (Boki under SMALL_FRAC of the screen high), hud-* (a HUD control over the chest).

const NavCheck := preload("res://tools/garden_nav_check.gd")
const DAY := 0.5          # day_t at noon
const NIGHT := 0.97       # day_t in the small hours
const SMALL_FRAC := 0.07  # a Boki shorter than this share of the screen height is too small to read
const SETTLE := 20        # frames to let the light and the Boki settle before a grab

func run(main: Node) -> void:
	var zone := "glasswater"
	var dir := "shots"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--zone="): zone = a.substr(7)
		if a.begins_with("--shots-dir="): dir = a.substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = true
	var nav := NavCheck.new()
	nav.main = main
	nav.zone = zone
	nav._save()
	var home = await nav._open_home()
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	if "--third" in OS.get_cmdline_user_args():
		await _third(main, home, zone, dir)
		return
	await _grab(main, home, DAY, dir, "zone_day")
	await _grab(main, home, NIGHT, dir, "zone_night")
	home.cam.zoom_to = 2.6
	home.cam.zoom = 2.6
	await _grab(main, home, DAY, dir, "zone_wide")
	print("GARDENZONESHOTS DONE %s" % zone)
	main.get_tree().quit()

func _grab(main: Node, home, day_t: float, dir: String, file: String) -> void:
	home.day_t = day_t
	for i in SETTLE:
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))

## ---- --third: the farm's close view at four spots ----
func _third(main: Node, home, zone: String, dir: String) -> void:
	var res := Vector2i(1920, 1080)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--res="):
			var p := a.substr(6).split("x")
			res = Vector2i(int(p[0]), int(p[1]))
	main.get_window().size = res
	for i in 10:
		await main.get_tree().process_frame
	home.day_t = DAY
	var kin: Node3D = home.kins[1]["node"]
	if home.cam.k <= 0.5:
		print("GZ3P %s warn third person is off (cam.k %.2f)" % [zone, home.cam.k])
	await _spot(main, home, dir, "arrive", home.ppos, NAN, kin, false)  # walking in: where you land
	var kp: Vector3 = kin.global_position
	await _spot(main, home, dir, "boki", _free(home, kp + Vector3(1.6, 0, 1.2)), NAN, kin, true)  # next to a Boki
	var b := _tall(home)  # a building close behind you
	if b.x > -1000.0:
		var at := _free(home, b + Vector3(0.0, 0, 3.0))
		await _spot(main, home, dir, "building", at, atan2(b.x - at.x, b.z - at.z), kin, false)
	else:
		print("GZ3P %s building none (no tall block in this zone)" % zone)
	var sl := _slope(home)  # a slope
	if sl.size() == 2:
		await _spot(main, home, dir, "slope", sl[0], atan2(sl[1].x - sl[0].x, sl[1].z - sl[0].z), kin, false)
	else:
		print("GZ3P %s slope none (flat zone)" % zone)
	print("GZ3P DONE %s %dx%d" % [zone, res.x, res.y])
	main.get_tree().quit()

## A walkable spot at/near p.
func _free(home, p: Vector3) -> Vector3:
	return home.world.free_spot_near(p, [], 0.8)

## Centre of the tall block (a building) nearest the landing, or (-1e9) when there is none.
func _tall(home) -> Vector3:
	var w: World = home.world
	var best := Vector3(-1.0e9, 0, 0)
	var bd := 1.0e18
	var need := float(FarmCam.rules()["building_m"]) - 0.01
	for z in w.h:
		for x in w.w:
			var i := w.idx(x, z)
			if w.is_block(x + 0.5, z + 0.5) and FarmCam._top(home, i) - w.level[i] * World.LEVEL >= need:
				var d := Vector2(x + 0.5 - HomeLayout.LANDING.x, z + 0.5 - HomeLayout.LANDING.z).length_squared()
				if d < bd:
					bd = d
					best = Vector3(x + 0.5, 0, z + 0.5)
	return best

## [spot on the low side of the step nearest the landing, a point on its high side], or [].
func _slope(home) -> Array:
	var w: World = home.world
	var best := []
	var bd := 1.0e18
	for z in range(1, w.h - 1):
		for x in range(1, w.w - 1):
			var a: float = w.ground_at(x + 0.5, z + 0.5)
			var c: float = w.ground_at(x + 1.5, z + 0.5)
			if a < -1000.0 or c < -1000.0 or w.is_block(x + 0.5, z + 0.5) or w.is_block(x + 1.5, z + 0.5):
				continue
			if absf(c - a) > 0.3 and absf(c - a) < 1.0:
				var lo := Vector3(x + 0.5, 0, z + 0.5) if a < c else Vector3(x + 1.5, 0, z + 0.5)
				var hi := Vector3(x + 1.5, 0, z + 0.5) if a < c else Vector3(x + 0.5, 0, z + 0.5)
				var d := Vector2(lo.x - HomeLayout.LANDING.x, lo.z - HomeLayout.LANDING.z).length_squared()
				if d < bd:
					bd = d
					best = [lo + (lo - hi) * 0.6, hi]
	return best

func _settle(main: Node, home) -> void:
	for i in 40:
		await main.get_tree().process_frame
		home.day_t = DAY

## Stands you at `at`; `toward` (radians, NAN = keep the view) is the way to the wall or the high ground, which the
## camera is put on. Grabs the frame and prints the flags.
func _spot(main: Node, home, dir: String, spot: String, at: Vector3, toward: float, kin: Node3D, kin_subject: bool) -> void:
	home.ppos = at
	home.py = home._ground_h(at.x, at.z)
	home.player.position = at + Vector3(0, home.py, 0)
	home.cam.snap(at)
	if not is_nan(toward):
		home.cam.yaw = toward + PI
	await _settle(main, home)
	if not is_nan(toward):
		var to := Vector2(sin(toward), cos(toward))
		var side := Vector2(home.cam.global_position.x - at.x, home.cam.global_position.z - at.z).normalized()
		if side.dot(to) < 0.0:
			home.cam.yaw += PI
			await _settle(main, home)
	var vp: Viewport = main.get_viewport()
	var cam: Camera3D = vp.get_camera_3d()
	var size := vp.get_visible_rect().size
	var flags: PackedStringArray = []
	var me: Vector3 = home.player.global_position
	var cp: Vector3 = cam.global_position
	if FarmCam._blocked(home, cp, 0.05):
		flags.append("clip")
	var kp: Vector3 = kin.global_position
	var subj: Array = [[me, "you"]]
	var kscreen := 0.0
	if not cam.is_position_behind(kp + Vector3(0, 0.5, 0)):
		kscreen = absf(cam.unproject_position(kp).y - cam.unproject_position(kp + Vector3(0, 1.0, 0)).y) / size.y
	if kin_subject:
		if kscreen < SMALL_FRAC:
			flags.append("small")
		subj.append([kp, "boki"])
	for s in subj:
		var chest: Vector3 = (s[0] as Vector3) + Vector3(0, 0.9, 0)
		for i in range(1, 12):
			var q := cp.lerp(chest, float(i) / 12.0)
			if q.distance_to(chest) > 0.7 and FarmCam._blocked(home, q, 0.0):
				flags.append("hidden-" + String(s[1]))
				break
		if cam.is_position_behind(chest) or not Rect2(Vector2.ZERO, size).has_point(cam.unproject_position(chest)):
			flags.append("offscreen-" + String(s[1]))
		elif _hud_over(main.get_tree().root, cam.unproject_position(chest), size):
			flags.append("hud-" + String(s[1]))
	var file := dir.path_join(spot + ".png")
	vp.get_texture().get_image().save_png(file)
	print("GZ3P %s %s back=%.1f boki_px=%.3f flags=%s" % [spot, file, cp.distance_to(home.cam.focus + Vector3(0, home.cam.rise, 0)), kscreen, ",".join(flags) if flags.size() > 0 else "ok"])

## Does a visible HUD control (not a full-screen layer) cover screen point p?
func _hud_over(n: Node, p: Vector2, size: Vector2) -> bool:
	if n is Control:
		var c := n as Control
		if c.is_visible_in_tree() and (c is Label or c is Button or c is TextureRect or c is PanelContainer or c is Panel or c is RichTextLabel or c is ProgressBar):
			var r := c.get_global_rect()
			if r.has_point(p) and r.size.x < size.x * 0.6 and r.size.y < size.y * 0.6 and c.modulate.a > 0.1:
				return true
	for ch in n.get_children():
		if _hud_over(ch, p, size):
			return true
	return false
