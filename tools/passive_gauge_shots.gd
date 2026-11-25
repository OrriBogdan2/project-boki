extends RefCounted
## --passive-gauge-shots --shots-dir=<dir> [--res=1920x1080] (GPU): the HUD for each kind of passive.
## Gauge (fill-up meter): Kael's Rage at half and full, Motley's Swell. No gauge: Vex with Fever lit (buff icon on
## the right edge) and Tenzo with Rocks standing (buff icon with its count). Files: gauge_<label>.png (the whole frame).

var main: Node
var dir := ""
var res := "1920x1080"


func _frames(m: Match, n: int) -> void:
	for i in n:
		await main.get_tree().process_frame


func _shot(label: String) -> void:
	await main.get_tree().create_timer(0.25).timeout
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("gauge_%s.png" % label))
	print("GAUGESHOT ", label)


func _match(arch: String) -> Match:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true, "arch": arch,
		"cls": Arch.weight(arch), "weapon": Arch.signature(arch)})
	return m


func _done(m: Match) -> void:
	m.over = true
	m.queue_free()
	await main.get_tree().process_frame


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--res="):
			res = String(a).substr(6)
	DirAccess.make_dir_recursive_absolute(dir)
	var wh := res.split("x")
	main.get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	for spec in [["juggernaut", "kael_half"], ["juggernaut", "kael_full"], ["ostra", "motley_swell"],
			["gunslinger", "vex_fever"], ["dolm", "tenzo_rocks"]]:
		var m := _match(spec[0])
		var P: Hunter = m.player
		await _frames(m, 20)
		for o in m.hunters:
			if o != P:
				o.teleport(P.pos + Vector3(60, 0, 60))
		var K: ArchKit = P.ak
		match String(spec[1]):
			"kael_half":
				K.res = 50.0
				K.res_wait = 30.0
			"kael_full":
				K.call("gain_rage", K.res_max())
			"motley_swell":
				K.res = 60.0
				K.res_wait = 30.0
			"vex_fever":
				K.res = 1.0
				K.res_wait = 30.0
			"tenzo_rocks":
				P.inp["aim"] = P.pos + Vector3(0, 0, 8)
				K.cast_e()
				await _frames(m, 90)
		await _frames(m, 6)
		await _shot(String(spec[1]))
		await _done(m)
	main.get_tree().quit()
