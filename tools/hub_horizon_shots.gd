extends RefCounted
## --hub-horizon-shots --shots-dir=<dir>: the hub with Bramblebank and Cinderstep open and the other
## three zones locked (GARDEN.md 10.7 step 9). <dir>/hub_horizon.png shows lit and misty islands.
## Needs a renderer. Never touches the real save.

func run(m: Node) -> void:
	var out := "/tmp/hub_horizon"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = true
	Save.d["tutorial"] = {"hatched": true, "intro": true, "home": true}
	Save.d["zones"]["cinderstep"] = {"open": true}
	Game.goto("home", {"zone": GardenZones.HUB})
	for i in 90:
		await m.get_tree().process_frame
	m.current.cam.zoom_to = 2.4      # pulled back: the whole sky round the hub
	m.current.cam.zoom = 2.4
	m.fade.reveal(0.05)
	await m.get_tree().create_timer(0.5).timeout
	m.get_viewport().get_texture().get_image().save_png(out.path_join("hub_horizon.png"))
	print("HUB_HORIZON_SHOTS_DONE")
	m.get_tree().quit()
