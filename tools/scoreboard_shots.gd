extends RefCounted
## --scoreboard-shots --shots-dir=<dir>: the Tab board mid-match (run under xvfb with a renderer). Ten squads
## of three, your Boki a level 6 Pip. Once the arrival banners are gone: you get a kill with a mate's assist
## and wear gear, one mate is knocked and one rival squad is wiped. Tab is held and <dir>/tab_board.png
## (the whole screen) is written.

const DT := 1.0 / 60.0
const SETTLE_S := 7.0      # s played before the events: the region banner and arrival toasts are gone by then
const RUN_S := 0.5         # s played with Tab held before the picture

func run(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	var pk := Save.new_kin("zapple", "Pip")
	pk["level"] = 6
	Save.d["roster"] = [pk]
	Save.d["active"] = pk["uid"]
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 10, "squad": 3, "tier": 0, "length": 1e9, "seed": 31, "no_drop": true})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	for h in m.hunters:
		h.lives = 1
		h.ctrl = "idle"
	await _play(m, main, SETTLE_S)
	var P: Hunter = m.player
	var foes: Array = m.hunters.filter(func(x): return x.team != P.team)
	var mates: Array = m.hunters.filter(func(x): return x.team == P.team and x != P)
	for i in 3:
		P.gear[i + 1] = {"id": Gear.ids_for(i + 1)[0], "rar": i + 1}
	DashReset.note(foes[0], mates[0])
	m.knock(foes[0], P, {})
	m.eliminate(foes[0], P, "finished")
	m.knock(mates[1], foes[3], {})
	for h in m.hunters.filter(func(x): return x.team == foes[0].team):
		m.eliminate(h, P, "finished")
	P.dmg_done = 1240.0
	mates[0].dmg_done = 610.0
	Input.action_press("scores")
	await _play(m, main, RUN_S)
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("tab_board.png"))
	Input.action_release("scores")
	print("SCOREBOARDSHOTS ", dir)
	main.get_tree().quit(0)

func _play(m: Match, main: Node, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		for h in m.hunters: h.render(DT, 1.0)
		await main.get_tree().process_frame
		t += DT
