extends RefCounted
## --kin-type-sheet --shots-dir=<dir> (under xvfb with a renderer): the contact sheet of all 18 Boki type
## cast accents side by side at the match camera, each type's name above it, captured a few times through
## their lives: <dir>/types_<n>.png.

const SLOW := 0.05             # Engine.time_scale while capturing
const GAP := 3.0               # m between types
const PER_ROW := 6
const SHOTS := [0.1, 0.25, 0.5, 0.9]    # s after the casts start

func run(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	if m.hud: m.hud.visible = false
	m.player.ctrl = "idle"
	var types: Array = KinTypeFx.LOOKS.keys()
	var rows := int(ceil(types.size() / float(PER_ROW)))
	var base: Vector3 = m.player.pos + Vector3(-GAP * (PER_ROW - 1) * 0.5, 0, -2.0)
	m.cam.snap(m.player.pos + Vector3(0, 0, GAP * (rows - 1) * 0.5 - 2.0))
	for i in types.size():
		var at := base + Vector3(GAP * (i % PER_ROW), 0, GAP * (i / PER_ROW))
		var col := Color(String(KinTypeFx.LOOKS[types[i]]["col"]))
		m.fx.word(at + Vector3(0, 2.2, 0), String(types[i]).capitalize(), col, false)
		KinTypeFx.play(m.fx, types[i], at, Vector2(1, 0))
	print("SHEET types: %s" % ", ".join(types))
	# (a software renderer draws a frame in ~0.5 s: game time slows so the captures land inside the looks)
	Engine.time_scale = SLOW
	var t := 0.0
	var shot := 0
	while shot < SHOTS.size():
		await main.get_tree().process_frame
		t += main.get_process_delta_time()
		if t >= float(SHOTS[shot]):
			main.get_viewport().get_texture().get_image().save_png(dir.path_join("types_%d.png" % shot))
			shot += 1
	Engine.time_scale = 1.0
	print("SHEET done %s" % dir)
	main.get_tree().quit(0)
