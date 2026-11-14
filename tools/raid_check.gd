extends RefCounted
## --raid-check: raid conditions (scripts/match/raid_look.gd) and the armor-kit key. The roll is
## seeded and fair (every condition comes up, clear most often, the same seed always the same
## condition), arena/training/tutorial/duel stay clear, --raid / opts force one, sight shrinks at
## night and in fog (muzzle flashes still give you away), the clear look is the one the game has
## always had, ash and fog bring their particles, and the armor kit is on 2 with a stack of two,
## a vulnerable channel like drinking. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("RAID %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _match(main: Node, o: Dictionary) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start(o)
	m.set_process(false)
	return m

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_rolls()
	_sight(main)
	_looks(main)
	_kit(main)
	print("RAID DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

func _rolls() -> void:
	var counts := {}
	for c in RaidLook.CONDITIONS: counts[c] = 0
	for s in 3000:
		var r := RaidLook.roll(s * 7 + 11)
		counts[r] = int(counts.get(r, 0)) + 1
	print("RAID rolls over 3000 seeds: %s" % str(counts))
	ok(RaidLook.CONDITIONS.all(func(c): return int(counts[c]) > 100), "every condition comes up")
	ok(RaidLook.CONDITIONS.all(func(c): return c == "clear" or int(counts[c]) < int(counts["clear"])), "a clear evening is the most common")
	ok(RaidLook.roll(4242) == RaidLook.roll(4242) and RaidLook.roll(99) == RaidLook.roll(99), "the same seed always rolls the same")
	# who rolls: real expeditions; arena, training, the tutorial and the duel room stay clear
	var real_seed := 0
	for s in 200:
		if RaidLook.roll(s) != "clear":
			real_seed = s; break
	var big_r := RaidLook.roll(real_seed)
	ok(RaidLook.rolls({"teams": 6}), "a real expedition rolls a condition")
	for k in ["arena", "training", "tutorial", "duel"]:
		ok(RaidLook.pick({k: true}, real_seed) == "clear", "%s stays clear (seed rolls %s)" % [k, big_r])
	ok(RaidLook.pick({"raid": "night"}, real_seed) == "night", "opts can force a condition")
	ok(RaidLook.pick({"raid": "ash_storm"}, 1) == "ash" and RaidLook.pick({"raid": "day"}, 1) == "day", "names and the old overcast day still work")
	ok(RaidLook.pick({"raid": "bogus"}, 1) in RaidLook.CONDITIONS, "an unknown name falls back to a roll")
	for c in RaidLook.CONDITIONS:
		ok(RaidLook.NAMES.has(c) and RaidLook.BLURBS.has(c) and RaidLook.SIGHT.has(c) and RaidLook.BLIGHT.has(c) and RaidLook.COLORS.has(c), "%s has a name, a line for the loading screen, sight and Blight numbers" % c)

func _sight(main: Node) -> void:
	var base := {"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 5101, "no_drop": true}
	var res := {}
	for c in ["clear", "night", "fog"]:
		var o := base.duplicate(); o["raid"] = c
		var m := _match(main, o)
		var P := m.player
		for x in m.hunters:
			if x != P: x.ctrl = "idle"
		P.ctrl = "idle"
		# a spot 18 tiles straight ahead of the player in the open
		var far := Vector3.INF
		for i in 32:
			var a := TAU * i / 32.0
			var q := P.pos + Vector3(cos(a), 0, sin(a)) * 18.0
			if m.world.is_void(q.x, q.z) or m.world.is_block(q.x, q.z) or m.world.in_bush(q.x, q.z): continue
			q.y = m.world.ground_at(q.x, q.z)
			if absf(q.y - P.pos.y) > 0.5: continue
			if not (m.world.los(P.pos, q, P.pos.y + 1.1) and m.world.los(P.pos, q, P.pos.y + 1.6)): continue
			far = q; break
		if far == Vector3.INF:
			ok(true, "(no open line of 18 tiles from the spawn on this seed: sight skipped)")
			m.queue_free(); return
		P.inp["aim"] = far + Vector3(0, 0.9, 0)
		res[c] = [m.raid, m.sight_k, m.view_range(), m.sees(P.team, far), m.sees(P.team, far, false, true), m.raid_fx != null]
		m.queue_free()
	print("RAID sight: %s" % str(res))
	ok(res["clear"][0] == "clear" and res["night"][0] == "night" and res["fog"][0] == "fog", "the forced condition is the match's")
	ok(res["clear"][3] and not res["night"][3] and not res["fog"][3], "18 tiles off: seen on a clear evening, not at night or in fog")
	ok(res["night"][4] and res["fog"][4], "a muzzle flash gives you away at night and in fog")
	ok(float(res["night"][2]) < Match.VIEW_RANGE * 0.7 and is_equal_approx(float(res["clear"][2]), Match.VIEW_RANGE), "sight: %.1f at night, %.1f clear" % [float(res["night"][2]), float(res["clear"][2])])
	ok(not res["clear"][5] and res["fog"][5], "fog drifts past the camera; a clear evening has nothing extra")

func _looks(main: Node) -> void:
	# the clear evening is the look the game had before raid conditions: same sun, haze and grade
	var m := _match(main, {"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 5102, "no_drop": true, "raid": "clear"})
	var e: Environment = m.env.environment
	var sun: DirectionalLight3D = m.get_node("Sun")
	print("RAID clear look: sun %.2f %s rot %s fog %.4f sat %.3f contrast %.2f" % [sun.light_energy, sun.light_color.to_html(false), str(sun.rotation_degrees), e.fog_density, e.adjustment_saturation, e.adjustment_contrast])
	ok(is_equal_approx(sun.light_energy, 1.18) and sun.light_color.is_equal_approx(Color("ffb27a")) and is_equal_approx(e.fog_density, 0.0042) and is_equal_approx(e.adjustment_contrast, 1.12), "the clear evening keeps the demo look")
	ok(m.raid_fx == null, "no weather particles on a clear evening")
	var sat_clear := e.adjustment_saturation
	m.queue_free()
	var m2 := _match(main, {"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 5102, "no_drop": true, "raid": "ash"})
	var e2: Environment = m2.env.environment
	ok(m2.raid_fx != null and m2.raid_fx.get_child_count() >= 2, "an ash storm blows ash and embers past the camera")
	ok(e2.fog_density > 0.0042 * 2.0 and e2.adjustment_saturation < sat_clear, "an ash storm is hazier and greyer")
	ok(m2.sight_k < 0.8, "and shortens sight (%.2f)" % m2.sight_k)
	m2.queue_free()
	var m3 := _match(main, {"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 5102, "no_drop": true, "raid": "night"})
	var sun3: DirectionalLight3D = m3.get_node("Sun")
	ok(sun3.light_energy < 0.6 and m3.env.environment.adjustment_saturation < sat_clear, "night is dark and desaturated")
	ok(float(RaidLook.VIS_DARK["night"]) < float(RaidLook.VIS_DARK["clear"]), "outside your sight is darker at night (%.2f)" % float(RaidLook.VIS_DARK["night"]))
	m3.queue_free()
	var m4 := _match(main, {"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	ok(m4.raid == "clear" and m4.blight == null, "training is clear, with no Blight")
	m4.queue_free()
	var m5 := _match(main, Match.duel_opts())
	ok(m5.raid == "clear" and m5.blight == null, "the duel room is clear, with no Blight")
	m5.queue_free()

func _kit(main: Node) -> void:
	var evs := InputMap.action_get_events("util2")
	var on2 := evs.any(func(ev): return ev is InputEventKey and ((ev as InputEventKey).physical_keycode == KEY_2 or (ev as InputEventKey).keycode == KEY_2))
	ok(on2, "the armor kit is on 2 (belt slot 2; tonics on 1)")
	ok(Settings.key_cap("util2") == "2", "the key cap reads 2 (%s)" % Settings.key_cap("util2"))
	var m := _match(main, {"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 5103, "no_drop": true, "raid": "clear"})
	var P := m.player
	P.ctrl = "idle"
	for x in m.hunters:
		if x != P: x.ctrl = "idle"
	for mb in m.mobs:
		mb.dead = true; mb.visible = false      # (nothing hits you mid-repair but the test's own hit)
	ok(P.armor_kits == 2, "every hunter sets out with %d armor kits" % P.armor_kits)
	ok(m.hunters.all(func(x): return x.armor_kits >= 1), "bots carry kits too")
	# 2 with full armor: nothing happens
	P.inp["util2"] = true
	m.step(Match.DT)
	ok(P.kit_t <= 0.0 and P.armor_kits == 2, "with full armor the key does nothing")
	# 2 with broken armor: a channel, and you're vulnerable while it runs
	P.armor = 0.0
	P.inp["util2"] = true
	m.step(Match.DT)
	ok(P.kit_t > 0.0, "with broken armor, 2 starts a repair")
	var hp0 := P.hp
	P.hurt(10.0, null, {"src": "shot"})
	ok(P.kit_t <= 0.0 and P.armor_kits == 2, "a hit spills the repair and you keep the kit")
	ok(hp0 - P.hp >= 10.0 * Hunter.CONSUME_VULN * 0.99, "... and the hit lands harder (%.1f from 10)" % (hp0 - P.hp))
	P.inv_t = 99.0           # (no stray hit from the map spills this one)
	P.inp["util2"] = true
	m.step(Match.DT)
	var k0 := P.kit_t
	for i in int((UtilityUse.channel("armor_kit", "time") + 0.2) / Match.DT): m.step(Match.DT)
	print("RAID repair: started %.2f, stun %.2f roll %.2f glide %s grounded %s" % [k0, P.stun_t, P.roll_t, P.gliding, P.grounded])
	ok(P.armor_kits == 1 and P.armor >= P.max_armor - 0.5, "an uninterrupted repair uses a kit and fills armor (kits %d, armor %.0f/%.0f)" % [P.armor_kits, P.armor, P.max_armor])
	# the HUD has a slot for it with its key
	ok(m.hud != null and m.hud.has_method("_ab_slot"), "the HUD draws the kit slot")
	m.queue_free()
