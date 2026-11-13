extends RefCounted
## --garden-zone-shots --zone=<id> --shots-dir=<dir>: the zone by day, by night and from far away (zone_day.png,
## zone_night.png, zone_wide.png), with the base's six Boki out. Needs a renderer (jobq --needs gpu).

const NavCheck := preload("res://tools/garden_nav_check.gd")
const DAY := 0.5          # day_t at noon
const NIGHT := 0.97       # day_t in the small hours
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
