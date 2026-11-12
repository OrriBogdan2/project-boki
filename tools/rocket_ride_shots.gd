extends RefCounted
## --rocket-ride-shots --shots-dir=<dir>: each Hunter riding the squad rocket (DropRocket) at the game's own
## skydive camera, the pose settled, for the animation review. <dir>/<arch>.jpg is the frame round the rider,
## enlarged; <dir>/sheet.jpg has them all. <dir>/<arch>_side.jpg is the same moment from the rider's side, close
## (the skydive camera looks straight down the rocket, so it hides the pose); sheet_side.jpg has those.
## Needs a renderer: run it on a GPU worker (jobq --needs gpu).

const SHOT_AT := 3.0         # s after the launch: the nose is down, the pose is in, the camera has come in a little
const CROP := 220            # px: the part of the frame round the rider that is kept
const SCALE := 3             # the crop is enlarged this much
const COLS := 4
const SIDE_DIST := 4.0       # m: the side camera's distance from a rider of size 1 (further for a bigger one)
const SIDE_FOV := 32.0       # degrees

var main: Node

func run(main_node: Node) -> void:
	main = main_node
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	if dir.is_relative_path():
		dir = ProjectSettings.globalize_path("res://").path_join(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Settings.v["tips"] = false
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1500.0, "seed": 4242, "no_plan": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	if m.hud:
		m.hud.set("visible", false)      # (the HUD would cover the rider)
	var shots: Array = []
	var sides: Array = []
	for arch in Arch.ORDER:
		var pair: Array = await _shot(m, String(arch), dir)
		shots.append(pair[0])
		sides.append(pair[1])
	_sheet(shots, dir.path_join("sheet.jpg"))
	_sheet(sides, dir.path_join("sheet_side.jpg"))
	print("RIDE_SHOTS_DONE ", shots.size())
	main.get_tree().quit()

## The player as `arch`, launched from the top of the ship's run, photographed SHOT_AT s into the ride.
func _shot(m: Match, arch: String, dir: String) -> Array:
	var P: Hunter = m.player
	P.reclass(Arch.weight(arch), arch)
	P.riding = true
	P.dropping = false
	m.ship["t0"] = m.time           # (the ship starts its run again: the same height and heading every time)
	m.skydrop.planning = false
	await main.get_tree().process_frame
	m.ship_jump(P)
	var t0 := m.time
	while m.time - t0 < SHOT_AT:
		await main.get_tree().process_frame
	var img := await _grab(m, P, dir.path_join(arch + ".jpg"))
	var side := Camera3D.new()          # (beside the rider, level with its chest, looking across the rocket's seat)
	m.add_child(side)
	side.fov = SIDE_FOV
	var big := maxf(1.0, P.model.scale.y)
	var across := P.model.global_basis.x.normalized() * SIDE_DIST
	side.global_position = P.global_position + (across + Vector3(0, 1.2, 0)) * big
	side.look_at(P.global_position + Vector3(0, 0.9, 0) * big)
	side.make_current()
	await main.get_tree().process_frame
	var close := await _grab(m, P, dir.path_join(arch + "_side.jpg"), true)
	m.cam.make_current()
	side.queue_free()
	var r: DropRocket = P.rocket
	if r != null:
		r._end()
	print("RIDE_SHOT %s riding=%s k=%.2f" % [arch, P.riding, P.anim.ride_k])
	return [img, close]

## The frame (or the part of it round the rider, `whole`: the whole frame, square) saved to `path`.
func _grab(m: Match, P: Hunter, path: String, whole := false) -> Image:
	await RenderingServer.frame_post_draw
	var full := main.get_viewport().get_texture().get_image()
	var half := CROP / 2
	var at := m.cam.unproject_position(P.global_position + Vector3(0, 0.9, 0))
	var lo := Vector2i(half, half)
	var c := Vector2i(at).clamp(lo, full.get_size() - lo)
	var img := full.get_region(Rect2i(c - Vector2i(half, half), Vector2i(CROP, CROP)))
	if whole:      # (the side camera frames the rider itself: the middle square)
		var edge := mini(full.get_width(), full.get_height())
		img = full.get_region(Rect2i((full.get_size() - Vector2i(edge, edge)) / 2, Vector2i(edge, edge)))
		img.resize(CROP, CROP, Image.INTERPOLATE_LANCZOS)
	img.resize(CROP * SCALE, CROP * SCALE, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGB8)      # (the sheet is RGB8: blit_rect skips an image of another format)
	img.save_jpg(path, 0.92)
	return img

func _sheet(shots: Array, path: String) -> void:
	var px := CROP * SCALE
	var rows := ceili(float(shots.size()) / COLS)
	var sheet := Image.create(px * COLS, px * rows, false, Image.FORMAT_RGB8)
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, px, px), Vector2i(i % COLS * px, i / COLS * px))
	sheet.resize(sheet.get_width() / 2, sheet.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	sheet.save_jpg(path, 0.9)
