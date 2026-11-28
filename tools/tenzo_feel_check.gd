extends "res://tools/hero_pair_check.gd"
## --tenzo-feel-check: Tenzo (dolm), owner playtest 2026-11-08 (content/rules/tuning.json, tenzo).
##   R floor: the press raises rock ground under him on the same frame over the abyss; he stands on it at once,
##     it is ground for everyone (over_void, landing, a mantle onto its edge), goes out over Net, cracks and
##     shakes before it crumbles, then is abyss again; over solid ground it changes nothing.
##   RMB hop: a planted wind-up, an eased lob that lands on the circle, falls faster than it rose, never moves
##     a body's width in one step, stops short at a body instead of shoving it; the air press pops a beat and
##     then its fall gathers speed.


func run(main_node: Node) -> void:
	main = main_node
	await _floor()
	await _floor_net_and_ground()
	await _hop()
	await _hop_body()
	await _dive()
	print("PAIRCHECK tenzo-feel DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)


func fd() -> Dictionary:
	return Loco.T["tenzo"]["r_floor"]


## R over the abyss strip (abyss from 4m to 12m ahead), Tenzo dropped in falling.
func _floor() -> void:
	var r := setup("dolm", 9.0, 4)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[3]
	var k: DolmKit = p.ak
	t_v.teleport(home + Vector3(0, 0, 5))
	p.teleport(home + Vector3(7.5, -0.5, 0))
	p.grounded = false
	p.vel = Vector3(0, -3.0, 0)
	aim_at(p, home + Vector3(12, 0, 0))
	ok("setup: Tenzo is falling over the abyss", p.over_void() and not p.grounded)
	HunterKeys.ult_pressed(p)
	var g := m.world.ground_at(p.pos.x, p.pos.z)
	ok(
		"R floor: the press turns the abyss under him to ground on the same frame, and he stands on its top",
		(
			k.spine.floors == 1
			and g > World.VOID + 1.0
			and not p.over_void()
			and absf(p.pos.y - g) < 0.01
			and p.vel.y >= 0.0
			and k.spine.running()
		),
		"floors %d ground %.2f y %.2f void %s" % [k.spine.floors, g, p.pos.y, str(p.over_void())]
	)
	m.step(DT)
	ok("R floor: the next step he is grounded on it", p.grounded and absf(p.pos.y - g) < 0.01, "y %.2f" % p.pos.y)
	step(m, 0.5)
	ok("R floor: the rest of R carries on (the ridge goes up)", k.spine.casts == 1 and rocks(m).size() > 0)
	# everyone: a foe dropped onto it stands; a foe hanging off its edge mantles up
	var side := Vector3(p.pos.x, g, p.pos.z + float(fd()["r"]) - 0.3)
	t_v.teleport(side + Vector3(0, 0.5, 0))
	t_v.vel = Vector3.ZERO
	step(m, 0.4)
	ok(
		"R floor: walkable for everyone (a foe lands and stands on it, not over the abyss)",
		t_v.grounded and not t_v.over_void() and absf(t_v.pos.y - g) < 0.05,
		"y %.2f g %.2f" % [t_v.pos.y, g]
	)
	var tiles: Array = m.verbs.terrain[0]["tiles"]
	var edge_z := -INF
	for td in tiles:
		edge_z = maxf(edge_z, float(int(int(td[0]) / float(m.world.w))) + 1.0)
	t_v.teleport(Vector3(p.pos.x, g - 0.6, edge_z + t_v.r + 0.15))
	t_v.grounded = false
	t_v.vel = Vector3.ZERO
	t_v.last_gy = g
	var t := 0.0
	while t < 0.8 and not (t_v.grounded and absf(t_v.pos.y - g) < 0.05):
		t_v.inp["move"] = Vector2(0, -1)
		m.step(DT)
		t += DT
	t_v.inp["move"] = Vector2.ZERO
	ok(
		"R floor: a body below its edge, pushing in, mantles onto it",
		t_v.grounded and absf(t_v.pos.y - g) < 0.05,
		"y %.2f g %.2f after %.2fs" % [t_v.pos.y, g, t]
	)
	# the warning, then the crumble
	var tz: Dictionary = m.verbs.terrain[0]
	var node: Node3D = tz["node"]
	var calm := not SpanLooks.cracked(node)
	step(m, float(tz["t"]) - float(fd()["warn"]) + 0.3)
	m.verbs.render(1.0)
	var cracked := SpanLooks.cracked(node)
	var p0 := node.position
	step(m, 0.1)
	m.verbs.render(1.0)
	ok(
		"R floor: no warning early; in its last seconds it shows cracks and shakes",
		calm and cracked and node.position.distance_to(p0) > 0.001,
		"calm %s cracked %s" % [str(calm), str(cracked)]
	)
	p.teleport(Vector3(p.pos.x, g, p.pos.z))
	step(m, float(fd()["warn"]))
	ok(
		"R floor: then it crumbles: the abyss is back and whoever stood on it falls",
		m.verbs.terrain.is_empty() and m.world.is_void(p.pos.x, p.pos.z) and (not p.grounded or p.out or p.dead),
		"terrain %d grounded %s" % [m.verbs.terrain.size(), str(p.grounded)]
	)
	await done(m)


## The floor goes out over Net and a second game lays the same ground; over solid ground nothing is laid.
func _floor_net_and_ground() -> void:
	var r := setup("dolm", 9.0, 4)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var home: Vector3 = r[3]
	var k: DolmKit = p.ak
	HeroZones.capture = true
	HeroZones.sent.clear()
	HunterKeys.ult_pressed(p)
	var tiles0 := m.verbs.terrain.size()
	ok(
		"R floor: over solid ground the press lays nothing and R is unchanged",
		k.spine.floors == 0 and tiles0 == 0 and k.spine.running(),
		"floors %d" % k.spine.floors
	)
	await done(m)
	r = setup("dolm", 9.0, 4)
	m = r[0]
	p = r[1]
	p.teleport(home + Vector3(6.5, 0, 0))
	p.grounded = false
	HeroZones.sent.clear()
	HunterKeys.ult_pressed(p)
	HeroZones.capture = false
	var evs: Array = HeroZones.sent.filter(func(e): return e[1] == "bridge")
	var r2 := setup("dolm", 9.0, 4)
	var m2: Match = r2[0]
	var remote := m2.make_hunter("p1", 0, "medium", "Remote", "idle", {}, r2[3] + Vector3(0, 0, 3), {"arch": "none"})
	remote.nid = "p1"
	m2.ents_by_id["p1"] = remote
	remote.remote = true
	for e in evs:
		HeroZones.net_in(m2, e)
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
	var p: Hunter = r[1]
	var home: Vector3 = r[3]
	var k: DolmKit = p.ak
	var feel := k.slam.feel()
	aim_at(p, home + Vector3(10, 0, 0))
	p.inp["sec_hold"] = true
	p.ak.press_rmb()
	step(m, 0.25, func(): p.inp["sec_hold"] = true)
	var aim_c := k.slam.center()
	p.inp["sec_hold"] = false
	m.step(DT)
	var start := p.pos
	var still := true
	var t := 0.0
	while t < float(feel["windup"]) - DT * 2.5:
		m.step(DT)
		t += DT
		still = still and p.grounded and Vector2(p.pos.x - start.x, p.pos.z - start.z).length() < 0.01
	ok(
		"RMB: the release winds up planted in a deep crouch before the hop (the tell)",
		still and k.anim_id == "breah_windup" and k.slam.hops == 0,
		"anim %s hops %d" % [k.anim_id, k.slam.hops]
	)
	var path: Array = []
	var prev := p.pos
	var s0 := k.slams
	var up_t := -1.0
	var air_t := 0.0
	var big := 0.0
	while k.slams == s0 and air_t < 2.0:
		m.step(DT)
		air_t += DT
		var d := p.pos - prev
		big = maxf(big, d.length())
		path.append(Vector2(d.x, d.z).length())
		if up_t < 0.0 and p.vel.y < 0.0 and k.slam.hops == 1:
			up_t = air_t
		prev = p.pos
	var n_v := path.size()
	var early := 0.0
	var late := 0.0
	for i in int(n_v / 5.0):
		early += float(path[i + 1])
		late += float(path[n_v - 2 - i])
	ok(
		"RMB: the hop's ground speed eases (fast off the ground, settling into the landing)",
		early > late * 2.0,
		"first fifth %.2fm last fifth %.2fm" % [early, late]
	)
	var off := Vector2(p.pos.x - aim_c.x, p.pos.z - aim_c.z).length()
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
		var p: Hunter = r[1]
		var t_v: Hunter = r[2]
		var home: Vector3 = r[3]
		var k: DolmKit = p.ak
		aim_at(p, home + Vector3(10, 0, 0))
		var t0 := t_v.pos
		var hp0 := t_v.hp
		p.inp["sec_hold"] = true
		p.ak.press_rmb()
		step(m, 0.25, func(): p.inp["sec_hold"] = true)
		p.inp["sec_hold"] = false
		m.step(DT)
		if fast:
			k.slam.wind_run = Vector2(60.0, 0.0)  # a 1m-per-step hop: only a swept test catches the body
		var s0 := k.slams
		var shoved := 0.0
		var t := 0.0
		while k.slams == s0 and t < 2.0:
			m.step(DT)
			t += DT
			if k.slams == s0:
				shoved = maxf(shoved, t_v.pos.distance_to(t0))
		ok(
			(
				"RMB%s: a body in the way stops the hop short: he lands in front and slams it, no shove, no pass"
				% (" (60 m/s)" if fast else "")
			),
			k.slam.stops > 0 and p.pos.x < t_v.pos.x and shoved < 0.1 and t_v.hp < hp0,
			(
				"stops %d his x %.2f its x %.2f shoved %.2f dmg %.0f"
				% [k.slam.stops, p.pos.x, t_v.pos.x, shoved, hp0 - t_v.hp]
			)
		)
		await done(m)


## The air press over ground: a beat at the top (a small pop), then the fall gathers speed (no 26 m/s from the
## first frame) onto the spot it arcs to.
func _dive() -> void:
	var r := setup("dolm", 30.0)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var k: DolmKit = p.ak
	var feel := k.slam.feel()
	p.teleport(p.pos + Vector3(0, 6.0, 0))
	p.grounded = false
	p.vel = Vector3.ZERO
	m.step(DT)
	p.inp["sec"] = true
	m.step(DT)
	p.inp["sec"] = false
	var y0 := p.pos.y
	step(m, float(feel["air_up"]) / Hunter.H_GRAV - DT * 1.5)
	var hung := p.pos.y > y0 and k.dive and k.slam.air_on()
	var vys: Array = []
	var s0 := k.slams
	var t := 0.0
	while k.slams == s0 and t < 2.0:
		m.step(DT)
		t += DT
		vys.append(-p.vel.y)
	var cap := float(k.slam_def()["dive_speed"])
	var ramps := vys.size() > 4 and float(vys[1]) < float(vys[3]) and float(vys[0]) < cap * 0.5
	ok(
		"RMB air: a beat at the top, then the fall gathers speed and slams where he lands",
		hung and ramps and k.slams == s0 + 1,
		"hung %s ramps %s first %.1f m/s" % [str(hung), str(ramps), float(vys[0]) if vys.size() > 0 else 0.0]
	)
	await done(m)
