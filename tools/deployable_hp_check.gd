extends "res://tools/hero_pair_check.gd"
## --deployable-hp-check: how placed objects die (docs/heroes/deployables.md). One break case per object, each
## through the real path: a foe's LMB shots into a rock / ice wall / aegis, the timer for the others.
##   Tenzo: Stone Row rock (45 hp, 9 s), Basalt Spine rock (45 hp, 7 s)
##   Neve: Rink Wall (70 hp, 4.5 s; frozen 6 s)       Albert: Aegis (160 hp, lock 3 s), Mending Ground (4 s, no hp)
##   Motley: Brimseed (no hp, fizzles)                  Meeko: Hearthlight (2.5 s, no hp)
##   Sable: Shadow Knife (6 s, no hp)                   Kael: Warchain anchor on a rock (5 s)

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	await _tenzo()
	await _neve()
	await _albert()
	await _motley()
	await _meeko()
	await _sable()
	await _kael()
	print("PAIRCHECK deployable-hp DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func press_e(m: Match, P: Hunter) -> void:
	P.inp["sig"] = true
	m.step(DT)
	P.inp["sig"] = false

## T fires at P with the real weapon until `gone` is true (at most `secs`); returns the seconds it took, or -1.
func shoot_until(m: Match, T: Hunter, P: Hunter, gone: Callable, secs := 20.0) -> float:
	var t := 0.0
	while t < secs:
		T.ammo = 99
		T.fire_cd = 0.0
		T.warm_t = 0.0
		aim_at(T, P.pos)
		T.fire()
		step(m, 0.1)
		t += 0.1
		T.hp = T.max_hp
		if gone.call():
			return t
	return -1.0

## A fresh wall: this max hp and a timer between lo and hi seconds.
func stands(w: Dictionary, hp: float, lo: float, hi: float) -> bool:
	return is_equal_approx(float(w["max_hp"]), hp) and float(w["t"]) > lo and float(w["t"]) <= hi

## The foe's gun is empty so the wall under test is not shot by accident.
func clear_walls(m: Match) -> void:
	for w in m.verbs.walls.duplicate(): m.verbs._break_wall(w)

func _tenzo() -> void:
	var r := setup("dolm", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	var K: DolmKit = P.ak
	T.team = 5
	press_e(m, P)
	step(m, 0.7)
	var rk := rocks(m)
	var row := rk.size() == 3 and rk.all(func(w): return stands(w, 45.0, 8.0, 9.0))
	ok("tenzo row: three rocks, 45 hp, 9 s", row, "%d" % rk.size())
	var rd: Dictionary = K.rock_def()
	ok("tenzo row: data rock.hp 45, rock.time 9", float(rd["hp"]) == 45.0 and float(rd["time"]) == 9.0)
	var took := shoot_until(m, T, P, func(): return rocks(m).size() < 3)
	ok("tenzo row: a foe's LMB breaks one rock", took > 0.0 and rocks(m).size() == 2, "%.1fs" % took)
	step(m, 9.0)
	ok("tenzo row: the rest crumble at 9 s", rocks(m).is_empty())
	clear_walls(m)
	K.cd["x"] = 0.0
	P.teleport(home)
	spine_across(m, P, home)
	step(m, 0.6)
	rk = rocks(m)
	var nine := rk.size() == 9 and rk.all(func(w): return stands(w, 45.0, 6.0, 7.0))
	ok("tenzo spine: nine rocks, 45 hp, 7 s", nine, "%d" % rk.size())
	step(m, 7.2)
	ok("tenzo spine: all gone at 7 s", rocks(m).is_empty())
	await done(m)

func _neve() -> void:
	var r := setup("rimewright", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: RimewrightKit = P.ak
	press_e(m, P)
	step(m, 0.4)
	var w: Dictionary = K.wall.get("w", {})
	ok("neve wall: raised, 70 hp, 4.5 s", not w.is_empty() and stands(w, 70.0, 3.8, 4.5))
	P.teleport(r[3] - Vector3(4.0, 0, 0))
	var took := shoot_until(m, T, P, func(): return not m.verbs.walls.has(w), 6.0)
	ok("neve wall: a foe's LMB breaks it", took > 0.0 and took < 4.0, "%.1fs" % took)
	clear_walls(m)
	K.cd["e"] = 0.0
	P.teleport(r[3])
	T.teleport(r[3] + Vector3(0, 0, 9.0))
	press_e(m, P)
	step(m, 0.5)
	w = K.wall.get("w", {})
	press_e(m, P)
	var frozen := not w.is_empty() and not bool(K.wall.get("sliding", true))
	ok("neve wall: E while it slides freezes it 6 s", frozen and absf(float(w["t"]) - 6.0) < 0.1)
	step(m, 6.3)
	ok("neve wall: the frozen wall is gone at 6 s", not m.verbs.walls.has(w))
	await done(m)

func _albert() -> void:
	var r := setup("bulwark", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: BulwarkKit = P.ak
	T.team = 5
	aim_at(P, T.pos)
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.5, func():
		P.inp["sec_hold"] = true
		aim_at(P, T.pos))
	var w: Dictionary = K.wall
	ok("albert aegis: up, 160 hp, no timer", not w.is_empty() and is_equal_approx(float(w["max_hp"]), 160.0))
	var held := func():
		P.inp["sec_hold"] = true
		return not m.verbs.walls.has(w)
	var took := shoot_until(m, T, P, held, 12.0)
	step(m, 0.1)
	var locked: bool = K.wall.is_empty() and K.lock_t > 2.0 and K.lock_t <= 3.0
	ok("albert aegis: LMB breaks it, 3 s lockout", took > 0.0 and locked, "%.1fs lock %.1f" % [took, K.lock_t])
	P.inp["sec_hold"] = false
	clear_walls(m)
	K.cd["e"] = 0.0
	press_e(m, P)
	step(m, 0.3)
	ok("albert mending ground: a zone, not a wall (nothing to shoot)", K.in_e() and m.verbs.walls.is_empty())
	step(m, float(K.e_def()["delay"]) + float(K.e_def()["time"]) + 0.3)
	ok("albert mending ground: ends by its timer", not K.in_e())
	await done(m)

func _motley() -> void:
	var r := setup("ostra", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: OstraKit = P.ak
	T.teleport(r[3] + Vector3(0, 0, 9.0))
	P.inp["aim"] = r[3] + Vector3(5.0, 0.9, 0)
	press_e(m, P)
	step(m, 0.5)
	ok("motley seed: planted, not a wall", not K.seed.is_empty() and m.verbs.walls.is_empty())
	var sid := String(K.seed["sid"])
	T.teleport(r[3] + Vector3(14.0, 0, 0))
	shoot_until(m, T, P, func(): return false, 1.0)
	ok("motley seed: a foe's LMB does not touch it", not K.seed.is_empty() and String(K.seed["sid"]) == sid)
	step(m, float(K.e_def()["grow"]) + float(K.e_def()["hold_full"]) + 0.5)
	ok("motley seed: fizzles out unpopped after grow + hold_full", K.seed.is_empty())
	await done(m)

func _meeko() -> void:
	var r := setup("tender", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: TenderKit = P.ak
	P.hp = P.max_hp * 0.5
	press_e(m, P)
	step(m, 0.3)
	var lit: bool = K.in_e() and m.verbs.walls.is_empty()
	ok("meeko hearthlight: lit, not a wall, 2.5 s", lit and is_equal_approx(float(K.e_def()["time"]), 2.5))
	step(m, float(K.e_def()["time"]) + 0.2)
	ok("meeko hearthlight: ends by its timer with the burst", not K.in_e())
	await done(m)

func _sable() -> void:
	var r := setup("thief", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: ThiefKit = P.ak
	T.teleport(r[3] + Vector3(0, 0, 9.0))
	P.inp["aim"] = r[3] + Vector3(8.0, 0.9, 0)
	press_e(m, P)
	step(m, 0.7)
	var stuck: bool = not K.knife.is_empty()
	ok("sable knife: stuck in the ground, 6 s", stuck and is_equal_approx(float(K.e_def()["time"]), 6.0))
	var at: Vector3 = K.knife.get("pos", Vector3.ZERO)
	step(m, float(K.e_def()["time"]) + 0.3)
	var away := Vector2(P.pos.x - at.x, P.pos.z - at.z).length()
	ok("sable knife: at 6 s she is brought to it", K.knife.is_empty() and away < 3.0, "%.1f m" % away)
	await done(m)

func _kael() -> void:
	var r := setup("juggernaut", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: JuggernautKit = P.ak
	T.teleport(r[3] + Vector3(0, 0, 9.0))
	var rock := HeroZones.rock(m, T, r[3] + Vector3(6.0, 0, 0), Vector2(0, 1), "chk", 3.0, 30.0, 45.0, false)
	T.team = 5
	rock["team"] = 5
	P.inp["aim"] = r[3] + Vector3(6.0, 0.9, 0)
	press_e(m, P)
	step(m, 1.0)
	var hooked: bool = K.warchain.state == "hooked" and m.verbs.walls.has(rock)
	ok("kael chain: hooks a foe's rock, which stays up (the hook does no damage)", hooked and float(rock["hp"]) == 45.0)
	step(m, float(K.e_def()["time"]) + 0.2)
	ok("kael chain: breaks by its 5 s timer", K.warchain.state != "hooked")
	await done(m)
