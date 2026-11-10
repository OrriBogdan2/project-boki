extends RefCounted
## --garden-cue-shots --shots-dir=<dir> [--px=480]: the garden minigames' world cues, in the engine, on the real
## base. dash.png (marks unlit, one lit, all lit), shove.png (level, leaning, nearly over), seek.png (the trail
## over time) and volley.png (spike flash, then the landing ring closing in). Needs a renderer and `--fixed-fps 30`.

const SETTLE_FRAMES := 600
const COLS := 3
const MAX_FRAMES := 2400          # frames; the longest wait for one game
const ZOOM := 1.0                 # the home camera's wheel
const ASPECT := 0.5               # each frame is px wide and px * this tall

var main: Node
var out := ""
var px := 480

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
	home.cam.zoom_to = ZOOM
	home.cam.zoom = ZOOM
	for k in home.kins:
		k.erase("indoors")
	await _dash(home)
	await _shove(home)
	await _seek(home)
	await _volley(home)
	print("GARDEN_CUE_SHOTS_DONE")
	main.get_tree().quit()

## One frame of the live view, centred on `at`, into column `col` of the sheet.
func _grab(home, sheet: Image, col: int, at: Vector3) -> void:
	home.cam.snap(at)
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	var view := img.get_size()
	var crop := img.get_region(Rect2i(view.x / 6, view.y / 6, view.x * 2 / 3, view.y * 2 / 3))
	crop.resize(px, int(px * ASPECT), Image.INTERPOLATE_BILINEAR)
	crop.convert(Image.FORMAT_RGBA8)
	sheet.blit_rect(crop, Rect2i(0, 0, px, int(px * ASPECT)), Vector2i(col * px, 0))

func _sheet() -> Image:
	return Image.create(px * COLS, int(px * ASPECT), false, Image.FORMAT_RGBA8)

## Waits frames until `ready` is true (false when the game ends first or the wait runs out).
func _until(ready: Callable, alive: Callable) -> bool:
	var f := 0
	while f < MAX_FRAMES and alive.call():
		if ready.call():
			return true
		await main.get_tree().process_frame
		f += 1
	return false

func _dash(home) -> void:
	var race: BaseRace = home.hrace
	race.use()
	var sheet := _sheet()
	var mid := (race._corner(0) + race._corner(2)) * 0.5
	var alive := func(): return race.run != null
	for col in COLS:
		var want := [0, 1, 3][col]
		if want > 0:
			await _until(func(): return race.cue != null and race.cue.lit >= want, alive)
		else:
			await main.get_tree().process_frame
		if race.cue != null:
			await _grab(home, sheet, col, mid)
	sheet.save_png(out.path_join("dash.png"))
	print("GARDEN_DASH lit=%d" % (race.cue.lit if race.cue != null else -1))
	_stop(home, race)

func _shove(home) -> void:
	var sh: BaseShove = home.hshove
	sh.use()
	var sheet := _sheet()
	var alive := func(): return sh.run != null
	for col in COLS:
		var want := [0.0, 0.3, 0.7][col]
		if want > 0.0:
			await _until(func(): return sh.cue != null and sh.cue.power >= want, alive)
		else:
			await main.get_tree().process_frame
		if sh.cue != null:
			await _grab(home, sheet, col, sh.stump.position)
	sheet.save_png(out.path_join("shove.png"))
	_stop(home, sh)

func _seek(home) -> void:
	var sk: BaseSeek = home.hseek
	sk.use()
	home.ppos = home.kins[0]["pos"] + Vector3(7, 0, 0)
	sk.use()
	var sheet := _sheet()
	var alive := func(): return sk.state == BaseSeek.S.HUNT
	for col in COLS:
		for f in 45:
			await main.get_tree().process_frame
		if sk.state == BaseSeek.S.HUNT:
			var at := Vector3(sk.hunt.item.x, 0, sk.hunt.item.y)
			var p: Vector2 = sk.hunt.pos[0]
			await _grab(home, sheet, col, (at + Vector3(p.x, 0, p.y)) * 0.5)
	sheet.save_png(out.path_join("seek.png"))
	print("GARDEN_SEEK dots=%d" % (sk.cue.shown[0] if sk.cue != null else -1))
	_stop(home, sk)

func _volley(home) -> void:
	var vb: BaseVolley = home.hvolley
	vb.use()
	vb.bar.m = vb.bar.zone
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	vb.input(press)
	var sheet := _sheet()
	var alive := func(): return vb.run != null
	for col in COLS:
		if col > 0:
			await _until(func(): return vb.run.state == BaseVolley.Run.S.FLIGHT and vb.run.fly_t < 0.3, alive)
		await main.get_tree().process_frame
		if vb.run != null:
			await _grab(home, sheet, col, vb.log_node.position)
		for f in 20:
			await main.get_tree().process_frame
	sheet.save_png(out.path_join("volley.png"))
	_stop(home, vb)

## Calls the game off with the menu key and frees its Boki for the next one.
func _stop(home, game) -> void:
	var esc := InputEventAction.new()
	esc.action = "menu"
	esc.pressed = true
	game.input(esc)
	home.hrace.release()
	for k in home.kins:
		k.erase("busy")
