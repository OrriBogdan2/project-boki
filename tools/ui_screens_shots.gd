extends "res://tools/first15_shots.gd"
## --ui-screens-shots --shots-dir=<dir> [--size=WxH]: the nine screens of the UI style audit (docs/UI_STYLE.md),
## one .jpg each plus layout.txt (the same edge scan as --first15-shots): title, home, Hunter pick, settings,
## results, tutorial, match HUD in a fight, the full map, the Training Grounds' L page. Made-up save, never written.

const FIGHT_STEPS := 600      # match steps (DT each, about 10 s) next to a bot so the fight HUD shows

func run(main_node: Node) -> void:
	main = main_node
	tree = main.get_tree()
	var win := Vector2i(1920, 1080)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--size="):
			var p := String(a).substr(7).split("x")
			win = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	_made_up_save()
	tree.root.size = win
	await _wait(1.0)
	main.show_screen("title", {})
	await _wait(3.5)
	await _shot("title")
	await _farm_screens()
	await _results()
	await _tutorial_screen()
	await _fight()
	await _lpage()
	var f := FileAccess.open(dir.path_join("layout.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("UI_SCREENS %d shots in %s (%dx%d)" % [n, dir, win.x, win.y])
	tree.quit(0)

func _farm_screens() -> void:
	main.show_screen("home", {})
	var guard := 0
	while guard < 600 and (_screen() == null or _screen().get("player") == null):
		guard += 1
		await _wait(0.5)
	await _wait(3.0)
	await _shot("home")
	var h := _screen()
	HomeClasses.open(h, Arch.of_save())
	await _wait(1.2)
	await _shot("hunter_select")
	h._close_panel()
	Overlay.open_settings()
	await _wait(1.0)
	await _shot("settings")
	Overlay.close()

func _results() -> void:
	main.show_screen("results", {"extracted": true, "gems": 42, "seeds": {"sunroot": 1},
		"caught": [Save.new_kin("zapple")], "knocks": 3, "damage": 512, "taken": 388, "kills": 1, "downs": 1,
		"deaths": 0, "revives": 2, "armor_tier": 3, "time": 201.0, "kin_trust": 57.0, "tonics": 1})
	await _wait(3.0)
	await _shot("results")

func _new_match(opts: Dictionary) -> void:
	if main.current:
		main.current.queue_free()
	await _frames(2)
	m = Match.new()
	main.add_child(m)
	main.current = m
	await m.start(opts)
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)

func _steps(k: int) -> void:
	for i in k:
		m.step(Match.DT)
		if i % 4 == 0:
			await _frames(1)

func _tutorial_screen() -> void:
	await _new_match({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0})
	m.tut.ack()
	for i in 400:
		TutorialDrive.drive(m)
		m.step(Match.DT)
		if i % 4 == 0:
			await _frames(1)
	await _shot("tutorial")

## A full bot lobby: land, stand next to the nearest bot until it fights, then open the full map.
func _fight() -> void:
	await _new_match({"teams": Data.MATCH_PLAYERS, "squad": 1, "total": Data.MATCH_PLAYERS, "tier": 0, "seed": 7})
	var guard := 0
	while guard < 3000 and m.skydrop.planning:
		guard += 1
		m.step(Match.DT)
	m.ship_jump(m.player, true)
	m.player.teleport(m.world.spawns[0])
	guard = 0
	while guard < 2400 and not (m.player.grounded and not m.player.dropping):
		guard += 1
		m.step(Match.DT)
	var foe = null
	for hn in m.hunters:
		if hn != m.player and (foe == null or hn.pos.distance_to(m.player.pos) < foe.pos.distance_to(m.player.pos)):
			foe = hn
	if foe:
		foe.teleport(m.player.pos + Vector3(4.0, 0.0, 2.0))
	await _steps(FIGHT_STEPS)
	m.cam.snap(m.player.pos)
	await _shot("match_hud")
	m.hud.full_map.open()
	await _wait(0.6)
	await _shot("full_map")

func _lpage() -> void:
	await _new_match(Match.arena_opts(""))
	await _steps(120)
	m.arena.open_menu()
	await _wait(1.0)
	await _shot("l_page")
