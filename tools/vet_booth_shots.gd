extends RefCounted
## --vet-booth-shots --shots-dir=<dir>: full frames of the vet booth beside the market stall at the close third-person
## farm camera (needs a renderer): vet_booth.png (your sick partner waits at the booth, you stand in front) and
## vet_panel.png (the check-up panel). Never touches the real save.

const SECS := 25.0  # s before a frame is taken anyway

var main: Node
var home: Node
var dir := ""


func _grab(file: String) -> void:
	for _i in 4:
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	print("VETSHOT ", file)


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = true
	var d := Save.fresh()
	var rec := Save.new_kin("cindle", "Ash")
	Care.ensure(rec)
	rec["starter"] = true
	rec["starve"] = (Care.STARVE["sick"] + 1.0) * 3600.0
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["gems"] = 80
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	HomeLayout.new_fs(d, 5)
	Save.d = d
	home = load("res://scripts/home/home.gd").new()
	home.zone = GardenZones.HUB  # the booth stands in the hub, by the market stall
	main.add_child(home)
	main.current = home
	await main.get_tree().process_frame
	while home.building:
		await main.get_tree().process_frame
	main.fade.reveal(0.01)
	home._close_panel()
	var mid := HomeLayout.deco_center(VetBooth.entry(home))
	home.ppos = mid + Vector3(0.6, 0, 3.4)
	home.player.position = home.ppos
	home.cam.snap(home.ppos)
	print("VETFIND ", VetBooth.find(home, Vector2(mid.x, mid.z)).get("kind", "none"))
	for k in home.kins:
		k["pos"] = home.world.free_spot_near(mid + Vector3(-1.4, 0, 2.0), [], 0.5)
		(k["node"] as Node3D).position = k["pos"]
		k["t"] = 99.0
	await main.get_tree().create_timer(5.0).timeout
	await _grab("vet_booth")
	VetBooth.open(home)
	await _grab("vet_panel")
	FarmUnlocks.rules()["base_mode"] = false
