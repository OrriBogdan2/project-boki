extends RefCounted
## --feed-bowl-shots --shots-dir=<dir>: full frames of the feeding bowl on a base_mode farm (needs a renderer):
## bowl_three.png (three hungry Boki at the bowl: one eating, the others queued in the ring) and bowl_next.png
## (the next one's turn). Never touches the real save.

const AT := Vector3(3.0, 0.0, -2.5)      # m from the landing where the bowl goes
const SECS := 25.0                       # s before a frame is taken anyway

var main: Node
var dir := ""

func _grab(file: String) -> void:
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	print("BOWLSHOT ", file)

## Waits real frames until `done` holds or the time is up.
func _until(done: Callable) -> void:
	var t := 0.0
	while t < SECS and not done.call():
		await main.get_tree().process_frame
		t += main.get_process_delta_time()

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = true
	var d := Save.fresh()
	for spec in [["cindle", "Ash", 0.9, 20.0], ["pebbit", "Pebble", 0.6, 5.0], ["puddlet", "Drip", 0.1, 10.0]]:
		var rec := Save.new_kin(spec[0], spec[1])
		Care.ensure(rec)
		rec["traits"]["bravery"] = spec[2]
		rec["needs"]["food"] = spec[3]
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	d["crops"]["emberberry"] = 3
	HomeLayout.new_fs(d, 5)
	Save.d = d
	var home = await main._hb_home()
	while home.building:      # the farm builds over several frames under the ink wipe
		await main.get_tree().process_frame
	main.fade.reveal(0.01)
	var c: Vector3 = home.world.free_spot_near(HomeLayout.LANDING + AT, [], 1.0)
	var bowl := {"id": FeedBowl.ID, "u": 990003, "x": int(c.x), "z": int(c.z), "r": 0}
	d["layout"]["deco"].append(bowl)
	home.hb._sync_deco()
	home.ppos = FeedBowl.at(bowl) + Vector3(0.5, 0, 4.0)
	home.player.position = home.ppos
	for k in home.kins:
		k["t"] = 0.0
	for _i in 3: FeedBowl.drop(home, bowl)
	var at_bowl := func() -> bool:
		var phases: Array = home.kins.map(func(k): return FeedBowl.phase(k))
		return phases.has("eat") and phases.all(func(p): return p in ["wait", "huff", "eat"])
	await _until(at_bowl)
	await _grab("bowl_three")
	await _until(func() -> bool: return FeedBowl.snacks(bowl).size() < 3 and home.kins.any(
		func(k): return FeedBowl.phase(k) == "eat"))
	await main.get_tree().create_timer(0.8).timeout
	await _grab("bowl_next")
	FarmUnlocks.rules()["base_mode"] = false
	main.get_tree().quit()
