extends RefCounted
## --scoreboard-shots --shots-dir=<dir>: one review frame of the Tab board mid-match, under xvfb with a
## renderer. Ten squads of three. Your squad has fought (kills, a death, an assist, damage, worn gear),
## a mate is downed, and one rival squad has been wiped. Writes <dir>/tab_board.png.

const DT := 1.0 / 60.0

func run(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 10, "squad": 3, "tier": 0, "length": 1e9, "seed": 31, "no_drop": true})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P: Hunter = m.player
	var mates: Array = m.hunters.filter(func(x): return x.team == P.team and x != P)
	var foes: Array = m.hunters.filter(func(x): return x.team != P.team)
	for h in m.hunters:
		h.ctrl = "idle"
		h.lives = 1
	for h in m.hunters.filter(func(x): return x.team == foes[0].team):
		m.eliminate(h, P, "finished")
	P.deaths = 1
	P.assists = 2
	P.dmg_done = 1840.0
	mates[0].kills = 1
	mates[0].assists = 1
	mates[0].dmg_done = 960.0
	for i in Gear.SLOTS.size():
		P.gear[i] = {"id": Gear.ids_for(i)[0], "rar": i}
	mates[0].gear[2] = {"id": Gear.ids_for(2)[0], "rar": 1}
	m.knock(mates[1], foes[5], {})
	Input.action_press("scores")
	for k in 30:
		m.step(DT)
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("tab_board.png"))
	Input.action_release("scores")
	print("SCOREBOARD SHOTS in %s" % dir)
	main.get_tree().quit(0)
