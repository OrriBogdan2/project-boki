extends RefCounted
## --charge-hint-shots --shots-dir=<dir>: the uplink's yard on screen at 0.6 s, 3.6 s and 5.5 s after
## you start charging it alone (run on a real GPU; see jobq). Uses only the exits' own entry points, so
## the same tool runs on a tree without ZoneHint for the "before" set. Files: <dir>/t<seconds>.png.

var main: Node
var m: Match

func _frames(secs: float, at: Vector3) -> void:
	for i in int(secs / Match.DT):
		m.player.teleport(at)
		m.player.vel = Vector3.ZERO
		for mb in m.mobs:
			mb.dead = true
			mb.visible = false
		m.step(Match.DT)
		m.cam.snap(at)
		for h in m.hunters:
			h.render(Match.DT, 1.0)
		await main.get_tree().process_frame

func run(main_node: Node) -> void:
	main = main_node
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for h in m.hunters:
		h.ctrl = "idle"
		h.max_hp = 5000.0
		h.hp = 5000.0
	var up: Dictionary = m.exits.of_kind("outpost")[0]
	var yard: Vector3 = up["pos"] + Vector3(0.9, 0, 0.9)
	m.time = float(up["open_at"]) + 1.0
	await _frames(0.2, yard)
	m.exits._start(up, m.player)
	var shown := 0.0
	for t in [0.6, 3.6, 5.5]:
		await _frames(t - shown, yard)
		shown = t
		main.get_viewport().get_texture().get_image().save_png(dir.path_join("t%.1f.png" % t))
		print("CHARGESHOT t=%.1f" % t)
	m.flow.finish("check done")
	main.get_tree().quit(0)
