extends RefCounted
## --garden-whistle-shots --shots-dir=<dir>: two full frames of the garden whistle on a base_mode farm (needs a
## renderer): whistle_run.png (the partner running up to you after the call) and whistle_here.png (it has
## arrived). Never touches the real save.

const FAR := Vector3(14.0, 0.0, 6.0)      # m from the landing where the partner starts
const NEAR_M := 4.5                       # m: the run frame is taken when it is this close
const SECS := 8.0                         # s before the run gives up

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
	FarmUnlocks.rules()["base_mode"] = false
	main.get_tree().quit()
