extends RefCounted
## --photo-check [--shots-dir=<dir>]: photo mode at home (HomePhoto). The HUD goes (recording mode's
## no-HUD level) and comes back, the camera stays inside the garden, Tab picks a Boki and the caption names
## it, a PNG lands in user://photos and latest() finds it, and the key is rebindable. With --shots-dir
## (needs a renderer, so run it through jobq on a GPU) it also writes the review shots there.
## Never touches the real save.

const SHOT_SETTLE_FRAMES := 90     # the camera eases in and the picked Boki wanders: let both settle
const READY_FRAMES := 600      # a renderer builds the farm over several frames

var bad := 0
var main: Node
var shots_dir := ""

func ok(cond: bool, what: String) -> void:
	print("PHOTOCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

func _shot(label: String) -> void:
	if shots_dir == "":
		return
	await _frames(SHOT_SETTLE_FRAMES)
	main.get_viewport().get_texture().get_image().save_png(shots_dir.path_join("photo_%s.png" % label))

func _new_save() -> void:
	var d := Save.fresh()
	var first := Save.new_kin("zapple", "Pip")
	first["starter"] = true
	d["roster"].append(first)
	d["roster"].append(Save.new_kin("zapple", "Mochi"))
	d["active"] = first["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true}
	Save.d = d
	HomeLayout.ensure(d)

## Both Boki out on the lawn (a fresh farm may send one in for a nap), so the shots show who the caption names.
func _bring_out(home: Node) -> void:
	for k in home.kins:
		k.erase("indoors")
		(k["node"] as Node3D).visible = true

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots_dir = String(a).substr(12)
			DirAccess.make_dir_recursive_absolute(shots_dir)
	Save.no_write = true
	_new_save()
	var home = await main._hb_home()
	for i in READY_FRAMES:
		if home.cam != null and home.kins.size() >= 2:
			break
		await _frames(1)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	await _frames(30)
	var photo: HomePhoto = home.photo
	var yaw0: float = home.cam.yaw_to
	ok(InputMap.has_action("photo") and Settings.ACTIONS.any(func(row): return row[0] == "photo"),
		"the photo key is a bound action and shows in Settings > Controls to rebind")
	await _shot("0_normal")
	photo.toggle(home)
	await _frames(3)
	ok(photo.active and Record.cinema() and not home.ui.visible, "on: the HUD is hidden")
	photo.focus = Vector3(-900.0, 0.0, 900.0)
	photo.tick(home, 0.016)
	var inside := photo.bounds.grow(-photo.EDGE_MARGIN + 0.001).has_point(Vector2(photo.focus.x, photo.focus.z))
	ok(inside and photo.bounds.size.x > 10.0, "the free camera is held inside the garden (%s)" % photo.bounds)
	_bring_out(home)
	var spot: Vector3 = home.kins[1]["pos"]
	photo.pick_next(home, 1)
	photo.pick_next(home, 1)
	ok(photo.picked == 1, "Tab picks the next Boki and wraps round (%d)" % photo.picked)
	home.kins[0]["indoors"] = 999.0
	photo.pick_next(home, 1)
	ok(photo.picked == 1, "Tab skips a Boki napping indoors (%d)" % photo.picked)
	home.kins[0].erase("indoors")
	for i in 120:
		photo.tick(home, 0.05)
	ok(photo.focus.distance_to(Vector3(spot.x, photo.focus.y, spot.z)) < 0.5, "the camera glides to the picked Boki")
	home.cam.snap(photo.focus)      # headless frames are too short for the camera to ease over
	await _frames(3)
	var on_screen: Vector2 = home.cam.unproject_position(home.kins[1]["node"].global_position + Vector3(0, 0.5, 0))
	var middle: Vector2 = main.get_viewport().get_visible_rect().size * 0.5
	var shown: bool = home.kins[1]["node"].is_visible_in_tree()
	var framed := on_screen.distance_to(middle) < middle.y * 0.5
	ok(framed and shown, "and it is out and near the middle of the frame (%s, shown %s)" % [on_screen, shown])
	var caption := photo.caption_text(home)
	ok(caption == "Mochi the %s" % Data.KIN["zapple"]["name"], "the caption: %s" % caption)
	await _shot("1_picked_no_caption")
	photo.caption_on = true
	photo.tick(home, 0.016)
	ok(photo._caption.visible and photo._caption.text != "", "C: the caption shows")
	home.cam.yaw_to = 0.9
	await _shot("2_picked_caption_orbit")
	ok(photo.picked == 1 and photo._caption.visible, "the captioned Boki is still out after the orbit")
	var path: String = await photo.take(home)
	var img := Image.load_from_file(path) if path != "" else null
	var window := Vector2i(main.get_viewport().get_visible_rect().size)
	ok(img != null and not img.is_empty() and Vector2i(img.get_size()) == window,
		"Enter: a PNG of the view is saved (%s)" % path)
	ok(HomePhoto.latest() == path, "latest() hands the saved photo back for the race post")
	photo.toggle(home)
	await _frames(3)
	ok(not photo.active and Record.level == 0 and home.ui.visible and is_equal_approx(home.cam.yaw_to, yaw0),
		"off: the HUD and the camera are back as they were")
	home.queue_free()
	print("PHOTOCHECK done, %d failed" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
