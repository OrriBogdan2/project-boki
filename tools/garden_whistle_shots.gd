extends RefCounted
## --garden-whistle-shots --shots-dir=<dir>: two full frames of the garden whistle on a base_mode farm (needs a
## renderer): whistle_run.png (the partner running up to you after the call) and whistle_here.png (it has
## arrived), and whistle_answer.png: the first second of a happy answer (top) and a sulky one (bottom), one
## close crop of the Boki per mark, its back to you at the whistle. Never touches the real save.

const FAR := Vector3(14.0, 0.0, 6.0)      # m from the landing where the partner starts
const NEAR_M := 4.5                       # m: the run frame is taken when it is this close
const SECS := 8.0                         # s before the run gives up
const NEAR := Vector3(3.5, 0.0, 2.0)      # m from the landing: the Boki that answers in the strip
const MARKS := [0.0, 0.12, 0.25, 0.4, 0.55, 0.8]      # s after the whistle, one crop each
const CROP := 300                         # px square each frame of the strip
const ZOOM := 2.0                         # the Boki crop is CROP / ZOOM px square before it is enlarged

var main: Node
var dir := ""

func _grab(file: String) -> void:
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	print("WHISTLESHOT ", file)

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = true
	var d := Save.fresh()
	for spec in [["zapple", "Pip"], ["burrlet", "Moss"], ["cindle", "Ash"]]:
		var rec := Save.new_kin(spec[0], spec[1])
		Care.ensure(rec)
		rec["trust"] = 90.0
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	HomeLayout.new_fs(d, 5)
	Save.d = d
	var home = await main._hb_home()
	while home.building:      # the farm builds over several frames under the ink wipe
		await main.get_tree().process_frame
	main.fade.reveal(0.01)
	home.ppos = HomeLayout.LANDING + Vector3(0, 0, 1.0)
	home.player.position = home.ppos
	var k: Dictionary = home.kins[0]
	k["pos"] = home.world.free_spot_near(HomeLayout.LANDING + FAR, [], 0.8)
	(k["node"] as Node3D).position = k["pos"]
	k["goal"] = k["pos"]
	for o in home.kins:
		o["t"] = 1e9
	home.life.whistle.press()
	home.life.whistle.release()
	var t := 0.0
	while t < SECS and Vector2(k["pos"].x - home.ppos.x, k["pos"].z - home.ppos.z).length() > NEAR_M:
		await main.get_tree().process_frame
		t += main.get_process_delta_time()
	await _grab("whistle_run")
	while t < SECS and k.has("called_t"):
		await main.get_tree().process_frame
		t += main.get_process_delta_time()
	await main.get_tree().create_timer(0.3).timeout
	await _grab("whistle_here")
	var rows := [await _answer(home, k, 90.0, 80.0), await _answer(home, k, 90.0, 10.0)]
	var strip := Image.create(CROP * MARKS.size(), CROP * rows.size(), false, Image.FORMAT_RGBA8)
	for r in rows.size():
		for c in MARKS.size():
			strip.blit_rect(rows[r][c], Rect2i(0, 0, CROP, CROP), Vector2i(c * CROP, r * CROP))
	strip.save_png(dir.path_join("whistle_answer.png"))
	print("WHISTLESHOT whistle_answer")
	FarmUnlocks.rules()["base_mode"] = false
	main.get_tree().quit()

## Puts Boki k near you with its back turned, whistles, and returns one crop of it per mark in MARKS.
func _answer(home, k: Dictionary, trust: float, joy: float) -> Array:
	for key in ["called_t", "call_slot", "call_pace", "hold_t"]:
		k.erase(key)
	k["emote_t"] = 0.0
	k["joy_t"] = 0.0
	k["rec"]["trust"] = trust
	k["rec"]["needs"]["joy"] = joy
	k["pos"] = home.world.free_spot_near(HomeLayout.LANDING + NEAR, [], 0.8)
	k["vel"] = Vector3.ZERO
	k["goal"] = k["pos"]
	k.erase("path")
	var node := k["node"] as Node3D
	node.position = k["pos"]
	node.rotation.y = atan2(-(home.ppos.x - k["pos"].x), -(home.ppos.z - k["pos"].z)) + PI
	for _i in 6:
		await main.get_tree().process_frame
	home.life.whistle.press()
	home.life.whistle.release()
	var crops := []
	var t := 0.0
	for m in MARKS:
		while t < m:
			await main.get_tree().process_frame
			t += main.get_process_delta_time()
		var at := main.get_viewport().get_camera_3d().unproject_position(node.global_position + Vector3(0, 0.4, 0))
		var shot := main.get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		var side := int(CROP / ZOOM)
		var crop := shot.get_region(Rect2i(Vector2i(at) - Vector2i(side, side) / 2, Vector2i(side, side)))
		crop.resize(CROP, CROP, Image.INTERPOLATE_NEAREST)
		crops.append(crop)
	return crops
