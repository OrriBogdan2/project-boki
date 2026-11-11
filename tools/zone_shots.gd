extends RefCounted
## --zone-shots --shots-dir=<dir> [--shots-zone=<garden zone id>|all]: each garden zone (default all) at noon
## and at midnight on the day clock (<id>_day.png, <id>_night.png), three Boki living there, with its ambient
## layer (ZoneAir). Hushwood's sky stays at dusk, so its two should match. Needs a real renderer.

const SETTLE_S := 1.5      # s the scene runs before each shot (the air fills, the sky blends)

func run(main: Node) -> void:
	var dir := "/tmp/zone_shots"
	var zones: Array = GardenZones.rules()["zones"].keys()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): dir = a.substr(12)
		if a.begins_with("--shots-zone=") and a.substr(13) != "all": zones = [a.substr(13)]
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = true
	for zone in zones:
		await _shoot(main, zone, dir)
	main.get_tree().quit()

func _shoot(main: Node, zone: String, dir: String) -> void:
	var d := Save.fresh()
	for i in 3:
		var rec := Save.new_kin(["zapple", "cindle", "burrlet"][i], "B%d" % i)
		Care.ensure(rec)
		rec["zone"] = zone
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	d["zones"][zone] = {"open": true}
	Save.d = d
	var home = load("res://scripts/home/home.gd").new()
	home.zone = zone
	main.add_child(home)
	main.current = home
	for i in 900:
		if home.root_ui != null and home.player != null and home.hb != null:
			break
		await main.get_tree().process_frame
	home._close_panel()
	if main.fade: main.fade.reveal(0.05)
	for shot in [["day", 0.5], ["night", 0.0]]:
		home.day_t = shot[1]
		await main.get_tree().create_timer(SETTLE_S).timeout
		var img := main.get_viewport().get_texture().get_image()
		img.save_png(dir.path_join("%s_%s.png" % [zone, shot[0]]))
		print("ZONE_SHOT %s %s" % [zone, shot[0]])
	home.queue_free()
	await main.get_tree().process_frame
