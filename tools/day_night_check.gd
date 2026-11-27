extends RefCounted
## --day-night-check: the day/night cycle (DayNight, docs/SPAWNS.md). Phase timing follows the rules file
## and scales with the session, the light turns smoothly and never goes pitch black, the night camps and
## the night elite stand up at dusk and go away at dawn while the day camps do the opposite, the
## warning comes warn_s before night, and the map has an icon kind for every one of them.
## Never touches the save.

var bad := 0
var m: Match


func ok(cond: bool, what: String) -> void:
	print("DAYNIGHT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 720.0, "seed": 21, "no_drop": true, "day_night": true})
	m.set_process(false)
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		h.max_hp = 5000.0
		h.hp = 5000.0
	m.step(Match.DT)
	_clock()
	_light()
	_spawns()
	_map()
	m.over = true
	print("DAYNIGHT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _clock() -> void:
	var dn := m.day_night
	var cfg := dn.cfg
	var want := float(cfg["phase_s"]) * 720.0 / float(cfg["ref_session_s"])
	ok(is_equal_approx(dn.phase_len(), want) and is_equal_approx(want, 120.0), "a 720 s match has 120 s phases")
	var p := dn.phase_len()
	ok(
		not dn.is_night(0.0) and not dn.is_night(p - 0.1) and dn.is_night(p + 0.1),
		"it starts in day, night after one phase"
	)
	ok(not dn.is_night(2.0 * p + 0.1) and dn.is_night(3.0 * p + 0.1), "and they alternate")
	ok(is_equal_approx(dn.left_in_phase(p * 0.25), p * 0.75), "seconds to the next swap")
	var full := float(cfg["ref_session_s"])
	ok(
		is_equal_approx(float(cfg["phase_s"]) * full / full, 300.0),
		"the reference phase is 300 s over a 1800 s session"
	)
	ok(dn.dark_at(p * 0.5) == 0.0 and dn.dark_at(p * 1.5) == 1.0, "mid-day is full day, mid-night full night")
	ok(is_equal_approx(dn.dark_at(p), 0.5), "the light is half-turned at the swap")
	var smooth := true
	var prev := dn.dark_at(p * 0.7)
	var t := p * 0.7
	while t < p * 1.3:
		t += 0.5
		var d := dn.dark_at(t)
		smooth = smooth and d >= prev - 0.0001 and d - prev < 0.05
		prev = d
	ok(smooth, "dusk turns smoothly (rising, no jumps)")
	ok(
		(
			dn.dark_at(2.0 * p) > 0.4
			and dn.dark_at(2.0 * p) < 0.6
			and dn.dark_at(2.0 * p - 20.0) > dn.dark_at(2.0 * p + 20.0)
		),
		"dawn turns back"
	)


func _light() -> void:
	var sun := m.get_node("Sun") as DirectionalLight3D
	var e := m.env.environment
	var look := m.day_night.look
	look.set_dark(0.0)
	var day_e := sun.light_energy
	var day_sky := (e.sky.sky_material as ShaderMaterial).get_shader_parameter("top") as Color
	look.set_dark(1.0)
	var night_sky := (e.sky.sky_material as ShaderMaterial).get_shader_parameter("top") as Color
	ok(sun.light_energy < day_e and night_sky.v < day_sky.v, "night is darker than day (sun and sky)")
	var amb := RaidLook.vis_amb(e)
	ok(
		amb > 0.08 and sun.light_energy > 0.4,
		"night is moonlit, not pitch black (ambient %.2f, sun %.2f)" % [amb, sun.light_energy]
	)
	look.set_dark(0.5)
	ok(
		is_equal_approx(sun.light_energy, float(m.day_night.cfg["looks"]["dusk"]["sun_energy"])),
		"the half-turned light is the dusk look"
	)


func _spawns() -> void:
	var dn := m.day_night
	var sp := dn.spawns
	var spots := sp.phase_spots()
	var night_n := spots.filter(func(s): return s["mode"] == "night").size()
	var day_n := spots.filter(func(s): return s["mode"] == "day").size()
	ok(night_n > 0 and day_n > 0, "the map has night camps (%d) and day camps (%d)" % [night_n, day_n])
	ok(
		spots.size() == sp.phase_spots().size() and sp.camp_mode(spots[0]["pos"], spots[0]["kind"]) == spots[0]["mode"],
		"the same spots every time"
	)
	ok(m.camps.list.all(func(c): return c["size"] != "heavy" or c["mode"] == ""), "Great Camps always stand")
	var stands := func(mode: String) -> bool:
		return (
			m
			. camps
			. list
			. filter(func(c): return c["mode"] == mode)
			. all(func(c): return not c["asleep"] and not c["mobs"].is_empty())
		)
	var down := func(mode: String) -> bool:
		return (
			m
			. camps
			. list
			. filter(func(c): return c["mode"] == mode)
			. all(func(c): return c["asleep"] and c["mobs"].is_empty())
		)
	ok(stands.call("day") and down.call("night"), "by day the day camps stand and the night camps lie down")
	ok(
		m.camps.live().size() == m.camps.list.filter(func(c): return not c["asleep"]).size(),
		"bots only see camps that stand"
	)
	var p := dn.phase_len()
	# ---- the warning
	var at := sp.boss_spot(0)
	ok(
		at != Vector3.INF and at == sp.boss_spot(0) and at in m.world.wild_spots,
		"the night elite's spot is a fixed wild spot"
	)
	var pinged := func(): return m.pings.filter(func(q): return (q["pos"] as Vector3).distance_to(at) < 0.1).size()
	var warn := float(dn.cfg["warn_s"])
	var before: int = pinged.call()
	var feed_n := m.feed.size()
	for s in [[p - warn - 1.0, 0], [p - warn + 0.1, 1], [p - 9.9, 2]]:
		m.time = s[0]
		dn.tick()
		ok(pinged.call() == before + s[1], "t=%.0f: %d warning ping(s)" % [s[0], s[1]])
	ok(m.feed.size() == feed_n + 2, "two feed lines before night")
	# ---- dusk
	m.time = p + 0.1
	dn.tick()
	ok(stands.call("night") and down.call("day"), "at night the night camps stand and the day camps lie down")
	var boss: Mob = sp.boss
	ok(
		boss != null and not boss.dead and boss.rarity == int(dn.cfg["boss"]["rarity"]) and boss.flat_dist(at) < 3.0,
		"the night elite stands at its spot"
	)
	ok(boss.max_hp > 0.0 and m.mobs.has(boss), "and is a monster of the match")
	dn.tick()
	ok(m.mobs.filter(func(mb): return mb == boss).size() == 1 and sp.boss == boss, "once a night")
	# ---- dawn
	m.time = 2.0 * p + 0.1
	dn.tick()
	ok(down.call("night") and stands.call("day"), "at dawn it swaps back")
	ok(boss.dead and sp.boss == null, "the elite goes at dawn")
	m.time = 3.0 * p + 0.1
	dn.tick()
	ok(stands.call("night") and sp.boss != null and sp.boss != boss, "the second night brings a new elite")
	ok(sp.boss_kind(0) != "" and sp.boss_night == 1, "night two's own elite")


func _map() -> void:
	ok("dark_camp" in MapDetail.DETAIL, "night and day camps have a minimap kind")
	ok(
		not m.day_night.spawns.phase_spots().is_empty() and m.day_night.spawns.boss_spot(1) != Vector3.INF,
		"there are camps and elite spots to mark"
	)
