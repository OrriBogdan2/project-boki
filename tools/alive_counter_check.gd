extends RefCounted
## --alive-counter-check [--shots-dir=<dir>]: the top-right counter (scripts/ui/alive_counter.gd).
##   1. squads left counts squads with a Hunter still in the match; players left counts the Hunters
##   2. an out or extracted Hunter leaves both counts; a squad with nobody left drops out of the squad count
##   3. a solo match (squad 1) shows players only; a squad match shows both
##   4. the real HUD draws it (with --shots-dir, saves the frame: GPU run)
## Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("ALIVE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _start(main: Node, teams: int, squad: int) -> Match:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": teams, "squad": squad, "tier": 0, "length": 1e9, "seed": 7302,
		"no_drop": true, "god": true})
	for h in m.hunters:
		h.ctrl = "idle"
	return m

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots = String(a).substr(12)
	var m := await _start(main, 4, 3)
	ok(AliveCounter.squads_left(m) == 4 and AliveCounter.players_left(m) == 12, "4 squads of 3: 4 squads, 12 players")
	var foes: Array = m.hunters.filter(func(h): return h.team != m.player.team)
	var one_team: Array = foes.filter(func(h): return h.team == foes[0].team)
	one_team[0].out = true
	ok(AliveCounter.squads_left(m) == 4 and AliveCounter.players_left(m) == 11, "one Hunter out: 4 squads, 11 players")
	one_team[1].extracted = true
	one_team[2].out = true
	ok(AliveCounter.squads_left(m) == 3 and AliveCounter.players_left(m) == 9,
		"a squad with nobody left: 3 squads, 9 players")
	ok(AliveCounter.shows_squads(m), "a squad match shows both counters")
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
		await main.fade.reveal(0.01)
		for i in 20:
			await main.get_tree().process_frame
		main.get_viewport().get_texture().get_image().save_png(shots.path_join("alive_squads.png"))
	m.queue_free()
	var solo := await _start(main, 9, 1)
	ok(AliveCounter.players_left(solo) == 9 and not AliveCounter.shows_squads(solo),
		"solos: 9 players, players only")
	for i in 3:
		await main.get_tree().process_frame
	if shots != "":
		main.get_viewport().get_texture().get_image().save_png(shots.path_join("alive_solo.png"))
	ok(true, "the real HUD draws both layouts")
	solo.queue_free()
	print("ALIVE DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)
