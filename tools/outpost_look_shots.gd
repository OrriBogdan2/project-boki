extends RefCounted
## --outpost-look-shots --shots-dir=<dir>: the outpost's review screenshots (run under xvfb with a renderer).
## One outpost at match zoom neutral, with you in the yard, capturing (half charged) and owned (lift open);
## then three outposts with a fight beside them, to judge the clutter. Files: <dir>/outpost_<name>.png.

var main: Node
var m: Match
var dir := ""
var focus := Vector3.ZERO

func _frames(n: int) -> void:
	for i in n:
		m.step(Match.DT)
		m.cam.snap(focus)
		for h in m.hunters:
			h.render(Match.DT, 1.0)
		await main.get_tree().process_frame

func _grab(file: String) -> void:
	await _frames(6)
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("outpost_%s.png" % file))
	print("OUTPOSTSHOT ", file)

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 3, "squad": 1, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var o: Dictionary = m.exits.of_kind("outpost")[0]
	var at: Vector3 = o["pos"]
	for h in m.hunters:
		h.ctrl = "idle"
		h.max_hp = 5000.0
		h.hp = 5000.0
		h.teleport(at + Vector3(60, 0, 60))
	m.time = float(o["open_at"]) + 1.0
	focus = at + Vector3(0, 1.5, 3.0)
	await _grab("1_neutral")
	P.teleport(at + Vector3(2.6, 0, 2.2))
	await _grab("2_neutral_you_inside")
	m.exits._start(o, P)
	await _frames(300)
	o["prog"] = 0.5
	await _grab("3_capturing_half")
	o["prog"] = 0.999
	await _frames(300)
	await _grab("4_owned_lift_open")
	# three outposts and a fight beside them
	var extra: Array = []
	for off in [Vector3(-8.5, 0, 4), Vector3(8.5, 0, 3)]:
		var d := {"kind": "outpost", "pos": m.world.free_spot_near(at + off, [], 1.0, 0.9, 3.0), "walled": false}
		m.exits._add_outpost(d, false)
		var added: Dictionary = m.exits.list.back()
		added["i"] = m.exits.list.size() - 1
		extra.append(added)
		print("OUTPOSTSHOT extra outpost %.1f m from the first" % added["pos"].distance_to(at))
	extra[0]["state"] = "idle"
	m.exits._start(extra[1], P)
	extra[1]["prog"] = 0.35
	P.teleport(at + Vector3(30, 0, 30))
	var fighters: Array = m.hunters.slice(0, 3)
	for i in fighters.size():
		var f: Hunter = fighters[i]
		f.ctrl = "bot"
		f.teleport(at + Vector3(-6 + 3 * i, 0, 7))
	focus = at + Vector3(0, 1.0, 3.0)
	await _frames(90)
	await _grab("5_three_outposts_fight")
	main.get_tree().quit(0)
