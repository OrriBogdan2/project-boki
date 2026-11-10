extends RefCounted
## --garden-motion-shots --shots-dir=<dir> [--px=360]: the garden minigames' body motion, in the engine, on the
## real base. race.png: a Dash lap (row 1, one frame per second) and the leap over the gap (row 2, every 0.1 s);
## shove.png: two Boki pushing the stump, then the result hold. Needs a renderer and `--fixed-fps 30` so the
## clips and the race advance at the same pace.

const SETTLE_FRAMES := 600
const FPS := 30
const LAP_ROW := 6
const LAP_EVERY := 30             # frames between the lap's frames: one per second
const LEAP_ROW := 6
const LEAP_EVERY := 3             # frames between the leap's frames: every 0.1 s
const SHOVE_ROW := 6
const SHOVE_EVERY := 15
const MAX_FRAMES := 1800          # frames; the longest wait for a lap to reach the gap
const FRAMING := Vector2(1.5, 1.1)   # m of ground beside and above the pair that the crop keeps
const CLOSE := 0.8                   # the home camera's wheel all the way in

var main: Node
var out := ""
var px := 360

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): out = String(a).substr(12)
		if String(a).begins_with("--px="): px = int(String(a).substr(5))
	DirAccess.make_dir_recursive_absolute(out)
	Save.no_write = true
	var d := Save.fresh()
	for i in 3:
		var k := Save.new_kin(["zapple", "cindle", "kestrike"][i], ["Pip", "Ash", "Bo"][i])
		k["level"] = 5
		Care.ensure(k)
		k["stats"]["speed"] = 10
		k["needs"]["energy"] = 90.0
		k["needs"]["joy"] = 70.0
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	FarmUnlocks.rules()["base_mode"] = true
	var home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	home._close_panel()
	home.root_ui.visible = false
	home.player.visible = false
	home.cam.zoom_to = CLOSE
	home.cam.zoom = CLOSE
	for k in home.kins:
		k.erase("indoors")
	await _race(home)
	await _shove(home)
	print("GARDEN_MOTION_SHOTS_DONE")
	main.get_tree().quit()

func _mid(ks: Array) -> Vector3:
	var mid := Vector3.ZERO
	for k in ks:
		mid += (k["node"] as Node3D).global_position / ks.size()
	return mid

## The crop around the pair, from the live viewport.
func _crop(ks: Array) -> Image:
	var vp := main.get_viewport()
	var cam := vp.get_camera_3d()
	var img := vp.get_texture().get_image()
	var mid := _mid(ks)
	var a := cam.unproject_position(mid + Vector3(-FRAMING.x, 0, 0))
	var b := cam.unproject_position(mid + Vector3(FRAMING.x, FRAMING.y, 0))
	var c := (a + b) * 0.5
	var half := maxf(absf(b.x - a.x), absf(a.y - b.y)) * 0.5
	var r := Rect2i(Vector2i(c - Vector2(half, half)), Vector2i(Vector2(half, half) * 2.0))
	var crop := img.get_region(r.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	crop.resize(px, px, Image.INTERPOLATE_BILINEAR)
	crop.convert(Image.FORMAT_RGBA8)
	return crop

func _frames(sheet: Image, row: int, col: int, ks: Array) -> void:
	await RenderingServer.frame_post_draw
	sheet.blit_rect(_crop(ks), Rect2i(0, 0, px, px), Vector2i(col * px, row * px))

func _race(home) -> void:
	var race: BaseRace = home.hrace
	race.use()
	var sheet := Image.create(px * maxi(LAP_ROW, LEAP_ROW), px * 2, false, Image.FORMAT_RGBA8)
	var lap := 0
	var leap := 0
	var seen := false
	var f := 0
	while race.run != null and f < MAX_FRAMES and leap < LEAP_ROW:
		await main.get_tree().process_frame
		f += 1
		home.cam.snap(_mid(race.runners))
		var gap := race.runners.any(func(k): return (k["node"] as Node3D).get_meta("kgait", "") == "leap")
		if gap and (not seen or f % LEAP_EVERY == 0):
			seen = true
			await _frames(sheet, 1, leap, race.runners)
			leap += 1
		elif not gap and f % LAP_EVERY == 0 and lap < LAP_ROW and not seen:
			await _frames(sheet, 0, lap, race.runners)
			lap += 1
	sheet.save_png(out.path_join("race.png"))
	print("GARDEN_RACE lap=%d leap=%d frames=%d" % [lap, leap, f])
	race.release()
	race.run = null
	for k in home.kins:
		k.erase("busy")
	await main.get_tree().process_frame

func _shove(home) -> void:
	var shove: BaseShove = home.hshove
	shove.use()
	await main.get_tree().process_frame
	print("GARDEN_SHOVE pair=%d entrants=%d" % [shove.pair.size(), home.hrace.entrants().size()])
	var sheet := Image.create(px * SHOVE_ROW, px, false, Image.FORMAT_RGBA8)
	var col := 0
	var f := 0
	while col < SHOVE_ROW and f < MAX_FRAMES:
		await main.get_tree().process_frame
		f += 1
		if shove.pair.size() >= 2:
			home.cam.snap(_mid(shove.pair))
		if shove.pair.size() < 2:
			break
		if f % SHOVE_EVERY == 0:
			await _frames(sheet, 0, col, shove.pair)
			col += 1
	sheet.save_png(out.path_join("shove.png"))
	print("GARDEN_SHOVE cols=%d frames=%d" % [col, f])
