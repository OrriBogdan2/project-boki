extends RefCounted
## --flyby-check: a rival's shot passing within 2 m of the local Hunter plays one flyby cue (3 m: none),
## your own and your team's shots never do, at most 3 play in 200 ms, one per shot, and every family has
## its sound, pitched higher by a faster shot (Flyby).

var main: Node
var fails := 0
var n := 0

func ok(cond: bool, what: String) -> void:
	n += 1
	print("FLYBY %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func _shot(where: Vector3, team: int, speed := 40.0, radius := 0.14, tint := Color("d9ff66"), x := {}) -> Dictionary:
	return {"team": team, "x": x, "prev": where, "pos": where, "vel": Vector2(speed, 0), "col": tint, "r": radius}

func run(main_node: Node) -> void:
	main = main_node
	var setup := {"autoplay": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true}
	Game.goto("match", setup)
	for i in 6:
		await main.get_tree().process_frame
	var m: Match = main.current
	m.set_process(false)
	var P: Hunter = m.player
	var chest := P.pos + Vector3(0, Flyby.CHEST, 0)
	var rival := P.team + 1
	var fb := m.flyby
	m.shots = []
	m.shots.append(_shot(chest + Vector3(1.5, 0, 0), rival))
	fb.tick(m)
	ok(fb.played == 1, "a rival shot 1.5 m away plays one cue (%d)" % fb.played)
	fb.tick(m)
	ok(fb.played == 1, "...and only once for that shot (%d)" % fb.played)
	m.shots = [_shot(chest + Vector3(3.0, 0, 0), rival)]
	fb.tick(m)
	ok(fb.played == 1, "a rival shot 3 m away plays none (%d)" % fb.played)
	m.shots = [_shot(chest + Vector3(1.0, 0, 0), P.team), _shot(chest + Vector3(0.5, 0, 0), P.team, 60.0)]
	fb.tick(m)
	ok(fb.played == 1, "your own and your team's shots play none (%d)" % fb.played)
	m.shots = [_shot(chest + Vector3(1, 0, 0), rival, 40.0, 0.14, Color.WHITE, {"melee": true})]
	fb.tick(m)
	ok(fb.played == 1, "a melee strike plays none (%d)" % fb.played)
	m.time += 1.0
	m.shots = []
	for i in 6:
		m.shots.append(_shot(chest + Vector3(0, 0, 1.0 + 0.1 * i), rival))
	fb.tick(m)
	ok(fb.played == 4, "six at once: at most 3 within 200 ms (%d)" % (fb.played - 1))
	m.time += Flyby.WINDOW + 0.05
	m.shots = [_shot(chest + Vector3(1.0, 0, 0), rival)]
	fb.tick(m)
	ok(fb.played == 5, "after the window the next one plays (%d)" % fb.played)
	_families()
	print("FLYBY DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _families() -> void:
	var cases := {
		"rock": _shot(Vector3.ZERO, 1, 20.0, 0.3, Color("c8a060"), {"lob": 2.0}),
		"orb": _shot(Vector3.ZERO, 1, 20.0, 0.45, Color("c080ff")),
		"ice": _shot(Vector3.ZERO, 1, 16.0, 0.26, Color("bff7ef")),
		"fire": _shot(Vector3.ZERO, 1, 30.0, 0.2, Color("ffb04a")),
		"arrow": _shot(Vector3.ZERO, 1, 60.0, 0.18, Color("e8f7c0")),
		"bullet": _shot(Vector3.ZERO, 1, 72.0, 0.14, Color("d9ff66")),
		"bolt": _shot(Vector3.ZERO, 1, 34.0, 0.18, Color("e8d0ff")),
	}
	for f in cases:
		ok(Flyby.family(cases[f]) == f, "family %s (%s)" % [f, Flyby.family(cases[f])])
		ok(ResourceLoader.exists("res://audio/flyby_%s.wav" % f), "the %s cue exists" % f)
	var p := [20.0, 40.0, 70.0].map(Flyby.pitch_of)
	ok(p[0] < p[1] and p[1] < p[2], "a faster shot pitches higher")
