extends RefCounted
## --day-night-shots --shots-dir=<dir>: the game camera at a night camp by day, at dusk and at night, with
## the HUD (phase row, minimap icons), then the full map at night. Run under a renderer; files are
## <dir>/dn_<name>.png.

var main: Node
var dir := ""


func _grab(file: String) -> void:
	for i in 6:
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("dn_%s.png" % file))
	print("DNSHOT ", file)


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	Settings.v["hud_full"] = true  # (the whole HUD, not the first-run reveal)
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1800.0, "seed": 21, "no_drop": true, "day_night": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var me: Hunter = m.player
	for o in m.hunters:
		if o != me:
			o.teleport(me.pos + Vector3(80, 0, 80))
	var dn := m.day_night
	var camp: Dictionary = dn.spawns.phase_spots().filter(func(s): return s["mode"] == "night")[0]
	var at: Vector3 = camp["pos"]
	me.teleport(Vector3(at.x + 9.0, m.world.ground_at(at.x + 9.0, at.z), at.z))
	var p := dn.phase_len()
	for shot in [["day", 0.5 * p], ["dusk", p], ["night", 1.5 * p]]:
		m.time = float(shot[1]) - m.sess_t0
		dn.tick()
		me.hp = me.max_hp
		await _grab(String(shot[0]))
	m.hud.open_map(false)
	await _grab("map_night")
	m.hud.close_map()
	m.over = true
	main.get_tree().quit(0)
