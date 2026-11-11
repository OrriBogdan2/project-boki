extends RefCounted
## --sting-check: the run's musical beats. In a headless match, each outcome starts exactly one sting
## (extracted, taken out, the last squad standing is yours) and the score's stems fall away under it;
## the sting never runs on into the results screen; coming home from a run plays the garden's once.

var main: Node
var fails := 0
var n := 0
var heard: Array[String] = []
const DT := 1.0 / 60.0
const SETTLE := 2.6        # real seconds: the run ends 1.6-2.2 s after the outcome

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	printerr("STING %-58s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Sfx.stung.connect(func(which: String): heard.append(which))
	await _extract()
	await _taken_out()
	await _last_squad()
	await _home()
	print("STING DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func go(screen: String, opts := {}) -> Node:
	var was: Node = main.current
	Game.goto(screen, opts)
	for i in 6:
		await main.get_tree().process_frame
	while main.current == was:      # (with a window the old screen stays current until the 0.3 s fade covers it)
		await main.get_tree().process_frame
	return main.current

func start_match(seed_n: int, teams := 2) -> Match:
	var opts := {"autoplay": true, "teams": teams, "squad": 1, "tier": 0, "length": 1e9, "seed": seed_n,
		"no_drop": true}
	var m: Match = await go("match", opts)
	m.set_process(false)
	return m

func step(m: Match, secs: float) -> void:
	for i in int(secs / DT):
		m.step(DT)

## Every stem wanted at most `top`.
func stems_under(top: float) -> bool:
	return Sfx.layer_want.values().all(func(v): return v <= top + 0.001)

## The results screen is up, its music is playing and no sting runs into it.
func at_results() -> bool:
	return not (main.current is Match) and not Sfx.sting_on() and Sfx.music_name == "title"

func rivals(m: Match) -> Array:
	return m.hunters.filter(func(h): return h.team != m.player.team)

## The match runs on by hand for a few seconds, the way the game does, so its music director ticks.
func play_out(m: Match, secs: float) -> void:
	m.set_process(true)
	await main.get_tree().create_timer(secs).timeout

func _extract() -> void:
	var m := await start_match(31)
	step(m, 2.0)
	heard.clear()
	m._extract(m.player, "skiff", "test")
	await play_out(m, 0.6)
	ok("extracted: one 'extract' sting", heard == ["extract"], str(heard))
	ok("extracted: the stems fall away under it", stems_under(0.0), str(Sfx.layer_want))
	await main.get_tree().create_timer(SETTLE).timeout
	ok("extracted: results screen, no sting running into it", at_results(), Sfx.music_name)
	ok("extracted: still just the one sting", heard == ["extract"], str(heard))

func _taken_out() -> void:
	var m := await start_match(32)
	step(m, 2.0)
	heard.clear()
	m.eliminate(m.player, null, "test", true)
	await play_out(m, 0.6)
	ok("taken out: one 'out' sting", heard == ["out"], str(heard))
	await main.get_tree().create_timer(SETTLE).timeout
	ok("taken out: results screen, no sting running into it", at_results(), Sfx.music_name)
	ok("taken out: still just the one sting", heard == ["out"], str(heard))

func _last_squad() -> void:
	var m := await start_match(33, 3)
	step(m, 2.0)
	heard.clear()
	var rs := rivals(m)
	for h in rs.slice(0, rs.size() - 1):
		m.eliminate(h, m.player, "test", true)
	step(m, 1.0)
	ok("two squads left: no sting yet", heard.is_empty(), str(heard))
	m.eliminate(rs[rs.size() - 1], m.player, "test", true)
	step(m, 2.0)
	m.set_process(true)
	await main.get_tree().create_timer(0.5).timeout
	ok("last squad standing: one 'last' sting", heard == ["last"], str(heard))
	ok("last squad standing: the stems dip under it", stems_under(MusicDir.UNDER), str(Sfx.layer_want))
	await main.get_tree().create_timer(3.0).timeout
	var back: bool = Sfx.layer_want.get("calm", 0.0) > 0.5
	ok("last squad standing: once, and the score comes back", heard == ["last"] and back, str(heard))
	m.set_process(false)

func _home() -> void:
	heard.clear()
	Game.last_result = {"extracted": true}
	await go("home")
	ok("home from a run: one 'home' sting", heard == ["home"] and Game.last_result.is_empty(), str(heard))
	await go("title")
	await go("home")
	ok("home again with no run: no sting", heard == ["home"], str(heard))
