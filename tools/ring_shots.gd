extends RefCounted
## --ring-shots --shots-dir=<dir> (under xvfb with a renderer): three Fx.ring bursts and the team markers of a squad at
## the match camera, captured through the bursts' lives: <dir>/ring_<n>.png.

const SLOW := 0.05             # Engine.time_scale while capturing
const SHOTS := [0.03, 0.08, 0.14, 0.22, 0.32]    # s after the bursts start (game time)

func run(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	for mb in m.mobs:
		mb.visible = false
	if m.hud: m.hud.visible = false
	var P: Hunter = m.player
	P.ctrl = "idle"
	m.cam.snap(P.pos)
	Sfx.listener = P.pos
	var spots := [Vector3(-3.5, 0, -3.0), Vector3(0, 0, -4.0), Vector3(3.5, 0, -3.0)]
	var cols := [Color(1.0, 0.85, 0.3, 0.85), Color("9ad0ff"), Color(0.5, 1.0, 0.5, 0.9)]
	var radii := [2.4, 3.4, 1.6]
	for i in spots.size():
		m.fx.ring(P.pos + spots[i], radii[i], cols[i], 0.45)
	Engine.time_scale = SLOW
	var t := 0.0
	var shot := 0
	while shot < SHOTS.size():
		await main.get_tree().process_frame
		t += main.get_process_delta_time()
		if t >= float(SHOTS[shot]):
			main.get_viewport().get_texture().get_image().save_png(dir.path_join("ring_%d.png" % shot))
			shot += 1
	Engine.time_scale = 1.0
	print("RINGSHOTS done %s" % dir)
	main.get_tree().quit(0)
