extends "res://tools/hero_pair_check.gd"
## --tenzo-feel-check: Tenzo (dolm), owner playtest 2026-11-08 (content/rules/tuning.json, tenzo).
##   R floor: the press raises rock ground under him on the same frame over the abyss; he stands on it at once,
##     it is ground for everyone (over_void, landing, a mantle onto its edge), goes out over Net, cracks and
##     shakes before it crumbles, then is abyss again; over solid ground it changes nothing.
##   RMB hop: a planted wind-up, an eased lob that lands on the circle, falls faster than it rose, never moves
##     a body's width in one step, stops short at a body instead of shoving it; the air plunge hangs a beat and
##     then gathers speed.

func run(main_node: Node) -> void:
	main = main_node
	await _floor()
	await _floor_net_and_ground()
	await _hop()
	await _hop_body()
	await _dive()
	print("PAIRCHECK tenzo-feel DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func fd() -> Dictionary: return Tuning.of("tenzo")["r_floor"]

## R over the abyss strip (abyss from 4m to 12m ahead), Tenzo dropped in falling.
func _floor() -> void:
	var r := setup("dolm", 9.0, 4)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	var K: DolmKit = P.ak
	T.teleport(home + Vector3(0, 0, 5))
	P.teleport(home + Vector3(7.5, -0.5, 0))
	P.grounded = false
	P.vel = Vector3(0, -3.0, 0)
	aim_at(P, home + Vector3(12, 0, 0))
	ok("setup: Tenzo is falling over the abyss", P.over_void() and not P.grounded)
	HunterKeys.ult_pressed(P)
	var g := m.world.ground_at(P.pos.x, P.pos.z)
	ok(
		"R floor: the press turns the abyss under him to ground on the same frame, and he stands on its top",
		K.spine.floors == 1 and g > World.VOID + 1.0 and not P.over_void() and absf(P.pos.y - g) < 0.01
			and P.vel.y >= 0.0 and K.spine.running(),
		"floors %d ground %.2f y %.2f void %s" % [K.spine.floors, g, P.pos.y, str(P.over_void())]
	)
	m.step(DT)
	ok("R floor: the next step he is grounded on it", P.grounded and absf(P.pos.y - g) < 0.01, "y %.2f" % P.pos.y)
	step(m, 0.5)
	ok("R floor: the rest of R carries on (the ridge goes up)", K.spine.casts == 1 and rocks(m).size() > 0)
	# everyone: a foe dropped onto it stands; a foe hanging off its edge mantles up
	var side := Vector3(P.pos.x, g, P.pos.z + float(fd()["r"]) - 0.3)
	T.teleport(side + Vector3(0, 0.5, 0))
	T.vel = Vector3.ZERO
	step(m, 0.4)
	ok(
		"R floor: walkable for everyone (a foe lands and stands on it, not over the abyss)",
		T.grounded and not T.over_void() and absf(T.pos.y - g) < 0.05, "y %.2f g %.2f" % [T.pos.y, g]
	)
	var tiles: Array = m.verbs.terrain[0]["tiles"]
	var edge_z := -INF
	for td in tiles:
		edge_z = maxf(edge_z, float(int(td[0]) / m.world.w) + 1.0)
	T.teleport(Vector3(P.pos.x, g - 0.6, edge_z + T.r + 0.15))
	T.grounded = false
	T.vel = Vector3.ZERO
	T.last_gy = g
	var t := 0.0
	while t < 0.8 and not (T.grounded and absf(T.pos.y - g) < 0.05):
		T.inp["move"] = Vector2(0, -1)
		m.step(DT)
		t += DT
	T.inp["move"] = Vector2.ZERO
	ok(
		"R floor: a body below its edge, pushing in, mantles onto it",
		T.grounded and absf(T.pos.y - g) < 0.05, "y %.2f g %.2f after %.2fs" % [T.pos.y, g, t]
	)
	# the warning, then the crumble
	var tz: Dictionary = m.verbs.terrain[0]
	var node: Node3D = tz["node"]
	var calm := node.get_node_or_null("Cracks") == null
	step(m, float(tz["t"]) - float(fd()["warn"]) + 0.3)
	m.verbs.render(1.0)
	var cracked := node.get_node_or_null("Cracks") != null
	var p0 := node.position
	step(m, 0.1)
	m.verbs.render(1.0)
	ok(
		"R floor: no warning early; in its last seconds it shows cracks and shakes",
		calm and cracked and node.position.distance_to(p0) > 0.001, "calm %s cracked %s" % [str(calm), str(cracked)]
	)
	P.teleport(Vector3(P.pos.x, g, P.pos.z))
	step(m, float(fd()["warn"]))
	ok(
		"R floor: then it crumbles: the abyss is back and whoever stood on it falls",
		m.verbs.terrain.is_empty() and m.world.is_void(P.pos.x, P.pos.z) and (not P.grounded or P.out or P.dead),
		"terrain %d grounded %s" % [m.verbs.terrain.size(), str(P.grounded)]
	)
	await done(m)

## The floor goes out over Net and a second game lays the same ground; over solid ground nothing is laid.
func _floor_net_and_ground() -> void:
	var r := setup("dolm", 9.0, 4)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[3]
	var K: DolmKit = P.ak
	HeroZones.capture = true
	HeroZones.sent.clear()
	HunterKeys.ult_pressed(P)
	var tiles0 := m.verbs.terrain.size()
	ok(
		"R floor: over solid ground the press lays nothing and R is unchanged",
		K.spine.floors == 0 and tiles0 == 0 and K.spine.running(), "floors %d" % K.spine.floors
	)
	await done(m)
	r = setup("dolm", 9.0, 4)
	m = r[0]
	P = r[1]
	P.teleport(home + Vector3(6.5, 0, 0))
	P.grounded = false
	HeroZones.sent.clear()
	HunterKeys.ult_pressed(P)
	HeroZones.capture = false
	var evs: Array = HeroZones.sent.filter(func(e): return e[1] == "bridge")
	var r2 := setup("dolm", 9.0, 4)
	var m2: Match = r2[0]
	var remote := m2.make_hunter("p1", 0, "medium", "Remote", "idle", {}, r2[3] + Vector3(0, 0, 3), {"arch": "none"})
	remote.nid = "p1"
	m2.ents_by_id["p1"] = remote
	remote.remote = true
	for e in evs: HeroZones.net_in(m2, e)
	var a: Array = m.verbs.terrain[0]["tiles"] if not m.verbs.terrain.is_empty() else []
	var b: Array = m2.verbs.terrain[0]["tiles"] if not m2.verbs.terrain.is_empty() else []
	var same := a.size() > 0 and a.size() == b.size()
	for i in mini(a.size(), b.size()):
		same = same and int(a[i][0]) == int(b[i][0]) and m.world.level[int(a[i][0])] == m2.world.level[int(b[i][0])]
	ok(
		"R floor: Net: one event, and the other game lays the same ground with the same warning",
		evs.size() == 1 and same and float(m2.verbs.terrain[0]["warn"]) == float(fd()["warn"]),
		"events %d tiles %d / %d" % [evs.size(), a.size(), b.size()]
	)
	await done(m2)
	await done(m)

## The held hop from standing: wind-up, ease, landing on the circle, the harder fall, no big steps.
func _hop() -> void:
	var r := setup("dolm", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[3]
	var K: DolmKit = P.ak
	var feel := K.slam.feel()
	aim_at(P, home + Vector3(10, 0, 0))
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.25, func(): P.inp["sec_hold"] = true)
	var aim_c := K.slam.center()
	P.inp["sec_hold"] = false
	m.step(DT)
	var start := P.pos
	var still := true
	var t := 0.0
	while t < float(feel["windup"]) - DT * 2.5:
		m.step(DT)
		t += DT
		still = still and P.grounded and Vector2(P.pos.x - start.x, P.pos.z - start.z).length() < 0.01
	ok(
		"RMB: the release winds up planted in a deep crouch before the hop (the tell)",
		still and K.anim_id == "breah_windup" and K.slam.hops == 0, "anim %s hops %d" % [K.anim_id, K.slam.hops]
	)
	var path: Array = []
	var prev := P.pos
	var s0 := K.slams
	var up_t := -1.0
	var air_t := 0.0
	var big := 0.0
	while K.slams == s0 and air_t < 2.0:
		m.step(DT)
		air_t += DT
		var d := P.pos - prev
		big = maxf(big, d.length())
		path.append(Vector2(d.x, d.z).length())
		if up_t < 0.0 and P.vel.y < 0.0 and K.slam.hops == 1:
			up_t = air_t
		prev = P.pos
	var n_ := path.size()
	var early := 0.0
	var late := 0.0
	for i in n_ / 5:
		early += float(path[i + 1])
		late += float(path[n_ - 2 - i])
	ok(
		"RMB: the hop's ground speed eases (fast off the ground, settling into the landing)",
		early > late * 2.0, "first fifth %.2fm last fifth %.2fm" % [early, late]
	)
	var off := Vector2(P.pos.x - aim_c.x, P.pos.z - aim_c.z).length()
	ok(
		"RMB: a weighty lob: it falls faster than it rose, and lands on the circle it showed",
		up_t > 0.0 and air_t - up_t < up_t and off < 0.3,
		"up %.2fs down %.2fs off the circle %.2fm" % [up_t, air_t - up_t, off]
	)
	ok("RMB: no step moves him more than 0.15m (no skipped frames or snaps)", big < 0.15, "biggest %.3fm" % big)
	await done(m)

## A body in the hop's way: he comes down in front of it and slams it, never through it or shoving it along;
## then the same at a speed that would cross a body in a step without the swept test.
func _hop_body() -> void:
	for fast in [false, true]:
		var r := setup("dolm", 1.9)
		var m: Match = r[0]
		var P: Hunter = r[1]
		var T: Hunter = r[2]
		var home: Vector3 = r[3]
		var K: DolmKit = P.ak
		aim_at(P, home + Vector3(10, 0, 0))
		var t0 := T.pos
		var hp0 := T.hp
		P.inp["sec_hold"] = true
		P.ak.press_rmb()
		step(m, 0.25, func(): P.inp["sec_hold"] = true)
		P.inp["sec_hold"] = false
		m.step(DT)
		if fast:
			K.slam.wind_run = Vector2(60.0, 0.0)      # a 1m-per-step hop: only a swept test catches the body
		var s0 := K.slams
		var shoved := 0.0
		var t := 0.0
		while K.slams == s0 and t < 2.0:
			m.step(DT)
			t += DT
			if K.slams == s0:
				shoved = maxf(shoved, T.pos.distance_to(t0))
		ok(
			"RMB%s: a body in the way stops the hop short: he lands in front and slams it, no shove, no pass" % (
				" (60 m/s)" if fast else ""
			),
			K.slam.stops > 0 and P.pos.x < T.pos.x and shoved < 0.1 and T.hp < hp0,
			"stops %d his x %.2f its x %.2f shoved %.2f dmg %.0f" % [K.slam.stops, P.pos.x, T.pos.x, shoved, hp0 - T.hp]
		)
		await done(m)

## The air press: a beat hanging at the top, then the plunge gathers speed (no 26 m/s from the first frame).
func _dive() -> void:
	var r := setup("dolm", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: DolmKit = P.ak
	var feel := K.slam.feel()
	P.teleport(P.pos + Vector3(0, 6.0, 0))
	P.grounded = false
	P.vel = Vector3.ZERO
	m.step(DT)
	P.inp["sec"] = true
	m.step(DT)
	P.inp["sec"] = false
	var y0 := P.pos.y
	step(m, float(feel["dive_hang"]) - DT * 1.5)
	var hung := absf(P.pos.y - y0) < 0.05 and K.dive and K.dive_fall
	var vys: Array = []
	var s0 := K.slams
	var t := 0.0
	while K.slams == s0 and t < 2.0:
		m.step(DT)
		t += DT
		vys.append(-P.vel.y)
	var cap := float(K.slam_def()["dive_speed"])
	var ramps := vys.size() > 4 and float(vys[1]) < float(vys[3]) and float(vys[0]) < cap * 0.5
	ok(
		"RMB air: it hangs a beat, then the plunge gathers speed and slams where he lands",
		hung and ramps and K.slams == s0 + 1, "hung %s ramps %s first %.1f m/s" % [
			str(hung), str(ramps), float(vys[0]) if vys.size() > 0 else 0.0
		]
	)
	await done(m)
