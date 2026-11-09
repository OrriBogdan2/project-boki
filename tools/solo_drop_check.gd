extends RefCounted
## --solo-drop-check: the expedition panel's Solo / Trios pick (ExpMode). The options each pick starts
## a match with, the team and squad counts that match really builds (solo 20x1, trios 7x3), no allies
## and 19 rivals in a solo drop, the rolling session sizing its waves for either, and a solo match
## running 30 s with the player and the bots still sane.

var bad := 0
var main: Node
var m: Match

func ok(cond: bool, what: String) -> void:
	print("SOLODROP %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func _start(mode: String, extra := {}) -> void:
	if m: m.queue_free()
	Save.d["exp_mode"] = mode
	var o := ExpMode.opts()
	o["total"] = Data.MATCH_PLAYERS
	o.merge({"tier": 0, "seed": 4242}, true)
	o.merge(extra, true)
	m = Match.new()
	main.add_child(m)
	m.start(o)
	m.set_process(false)

func _counts(mode: String, teams: int, squad: int) -> void:
	_start(mode)
	var sizes := {}
	for h in m.hunters: sizes[h.team] = int(sizes.get(h.team, 0)) + 1
	ok(m.hunters.size() == teams * squad or mode == "trio", "%s: %d hunters" % [mode, m.hunters.size()])
	ok(sizes.size() == teams, "%s: %d teams (got %d)" % [mode, teams, sizes.size()])
	ok(sizes.values().all(func(n): return n <= squad), "%s: no squad above %d" % [mode, squad])
	var mates := m.hunters.filter(func(h): return h.team == m.player.team and h != m.player).size()
	ok(mates == squad - 1, "%s: %d squadmates (got %d)" % [mode, squad - 1, mates])

func _solo_run() -> void:
	_start("solo", {"autoplay": true})      # (the player is bot-driven: a plain jump falls in the abyss)
	ok(m.hunters.filter(func(h): return h != m.player and h.team != m.player.team).size() == 19, "solo: 19 enemy bots")
	var t := 0.0
	while t < 30.0:
		if m.player.riding: m.ship_jump(m.player, true)
		m.step(Match.DT)
		t += Match.DT
	ok(is_instance_valid(m.player) and m.hunters.size() == Data.MATCH_PLAYERS, "solo: 30 s on, everyone still in the list")
	ok(m.result.is_empty() and not m.player.out, "solo: still in the match, nothing ended it (result %s, hp %.0f, out %s)" % [m.result, m.player.hp, m.player.out])

func _rolling() -> void:
	for mode in ["solo", "trio"]:
		_start(mode, {"rolling": true})
		var sz := 1 if mode == "solo" else 3
		ok(m.rolling != null and m.rolling.size == sz, "rolling %s: waves of squads of %d" % [mode, sz])
		for i in 20: m.step(Match.DT)

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	ok(not ExpMode.is_solo(), "trios are the default")
	_counts("trio", 7, 3)
	_counts("solo", 20, 1)
	_solo_run()
	_rolling()
	print("SOLODROP DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
