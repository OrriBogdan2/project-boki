extends RefCounted
## --arena-check: the Arena boots on its own map with its practice tools, dummies take damage and
## show it, reset works, archetype / weapon / Boki / glove swaps apply, the toggles work, the kit
## card builds for all six archetypes, the expedition loadout shows the card, and the training area
## gets the same tools. Prints ARENACHECK PASS/FAIL.

var main: Node
var fails := 0
var n := 0
const DT := 1.0 / 60.0

func ok(name: String, cond: bool, info := "") -> void:
	n += 1
	printerr("ARENACHECK %-40s %s  %s" % [name, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT); t += DT

func run(main_node: Node) -> void:
	main = main_node
	await _arena()
	await _cards()
	await _loadout()
	printerr("ARENACHECK (training match next)")
	await _training()
	print("ARENACHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()

func _arena() -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts("thief"))
	m.set_process(false)
	var P: Hunter = m.player
	ok("arena boots on its own map", m.world.layout_id == "arena" and m.arena != null and m.arena.layout == "arena", "layout %s" % m.world.layout_id)
	ok("arena: no monsters, chests or train", m.mobs.is_empty() and m.chests.is_empty() and m.skytrain == null, "mobs %d chests %d" % [m.mobs.size(), m.chests.size()])
	ok("arena: player is a thief on the floor", P.arch == "thief" and m.world.island_id(P.pos.x, P.pos.z) == "floor", "%s on %s" % [P.arch, m.world.island_id(P.pos.x, P.pos.z)])
	var A: Arena = m.arena
	ok("arena: three dummies", A.dummies.size() == 3)
	ok("arena: ult unlocked by default", int(P.slot_lv["ult"]) >= 1 and P.lvl >= 6)
	# dummies take damage and show it
	var D: Hunter = A.dummies[0]["h"]
	step(m, 0.2)
	var hp0 := D.hp
	D.hurt(25.0, P, {"src": "shot"})
	step(m, 0.1)
	ok("dummy takes damage", D.hp < hp0 - 20.0, "%.0f -> %.0f" % [hp0, D.hp])
	ok("dummy meter counts it", float(A.dummies[0]["total"]) >= 25.0 and A.dealt >= 25.0, "total %.0f" % float(A.dummies[0]["total"]))
	A.tick(DT)
	ok("dummy label shows DPS", String((A.dummies[0]["label"] as Label3D).text).begins_with("DPS"), String((A.dummies[0]["label"] as Label3D).text))
	# a real knife lands on a dummy
	P.teleport(D.pos + Vector3(0, 0, 4.0)); P.inp["aim"] = D.pos + Vector3(0, 0.9, 0); P.inp["aim_y"] = D.pos.y
	P.ak.cd["rmb"] = 0.0; P.ak.ch_rmb = 1.0
	var tot0 := float(A.dummies[0]["total"])
	P.inp["sec_hold"] = false; P.ak.press_rmb()
	step(m, 0.5)
	ok("thief knife hits a dummy and Marks it", float(A.dummies[0]["total"]) > tot0 and (P.ak as ThiefKit).marks_on(D) >= 1, "total %.0f marks %d" % [float(A.dummies[0]["total"]), (P.ak as ThiefKit).marks_on(D)])
	(P.ak as ThiefKit).add_mark(D, 3, true)
	step(m, 0.05)
	ok("three Marks: pips over the dummy, knife ready", (P.ak as ThiefKit).pips.size() >= 1 and P.ak.ch_rmb >= 1.0)
	# reset: everyone back, healed, meters cleared
	P.teleport(P.pos + Vector3(3, 0, 0)); P.hp = 10.0
	A.reset()
	ok("reset: you're home and healed", P.flat_dist(A.home) < 0.2 and P.hp >= P.max_hp - 0.1)
	ok("reset: dummies full and meters clear", D.hp >= Arena.DUMMY_HP - 0.1 and float(A.dummies[0]["total"]) == 0.0 and A.dealt == 0.0)
	# cooldowns off: E and R come straight back, and the glove
	A.cd_off = true
	P.ak.use_e()
	step(m, 0.1)
	ok("cooldowns off: E ready again", float(P.ak.cd["e"]) <= 0.0)
	A.give_glove("blink")
	ok("glove picker: blink on Q", String(P.gear[0].get("id", "")) == "blink")
	P.gear_cd[0] = 9.0
	A.tick(DT)
	ok("cooldowns off covers the glove", float(P.gear_cd[0]) <= 0.0)
	A.cd_off = false
	A.toggle_ult()
	ok("ult toggle: locked", int(P.slot_lv["ult"]) == 0)
	A.toggle_ult()
	ok("ult toggle: unlocked", int(P.slot_lv["ult"]) >= 1)
	# swaps: archetype (with its weight class), weapon, Boki
	A.set_arch("juggernaut")
	ok("swap to juggernaut: heavy, rage kit", P.arch == "juggernaut" and P.cls == "heavy" and P.ak is JuggernautKit and P.max_hp >= 180.0, "%s %s hp %.0f" % [P.arch, P.cls, P.max_hp])
	ok("swap keeps the glove", String(P.gear[0].get("id", "")) == "blink")
	A.set_weapon("shotgun")
	ok("weapon swap within the family", P.wid == "shotgun")
	A.set_kin("cindle")
	ok("Boki swap: cindle on your shoulder", P.kin != null and (P.kin as Kin).species == "cindle")
	A.set_kin("")
	ok("Boki swap: none", P.kin == null)
	for a in Arch.ids():
		A.set_arch(a)
		step(m, 0.05)
		ok("swap to %s" % a, P.arch == a and P.ak != null and P.cls == Arch.weight(a))
	# every hold has the wind-up feel: a charge that fills (ring + glow), a full tick, a release
	for a in Arch.ids():
		A.set_arch(a)
		P.teleport(A.home); P.inp["aim"] = D.pos + Vector3(0, 0.9, 0); P.inp["aim_y"] = D.pos.y
		P.ak.cd["rmb"] = 0.0; P.ak.ch_rmb = float(P.ak.rmb_charges()); P.fire_cd = 0.0
		step(m, 0.1)
		var f0: int = P.ak.charge_fulls
		var mid := -1.0
		var ring_ok := false
		if a == "mage":
			# the Guided Bolt's hold is a steer: the bolt flies and hums while you hold
			P.ak.bot_hold["rmb"] = 0.8; P.ak.press_rmb()
			step(m, 0.3)
			ok("hold: mage RMB steers a live bolt", not (P.ak as MageKit).bolts.is_empty() and P.ak.rmb_down)
			step(m, 0.8)
			continue
		var t := 0.0
		while t < 1.45:
			if a == "bulwark": P.inp["fire"] = true            # the Crushing Blow is the Bulwark's charge
			elif t < 0.02: P.ak.bot_hold["rmb"] = 1.45; P.ak.press_rmb()
			m.step(DT); t += DT
			if t > 0.4 and mid < 0.0:
				mid = P.ak.charge_k()
				ring_ok = P.ak.chg.get("ring") != null and is_instance_valid(P.ak.chg.get("ring"))
		P.inp["fire"] = false
		step(m, 0.3)
		ok("hold: %s winds up (ring), ticks full, releases" % a, mid > 0.1 and ring_ok and P.ak.charge_fulls > f0 and P.ak.charge_last > 0.9 and P.ak.chg.is_empty(), "mid %.2f fulls +%d last %.2f" % [mid, P.ak.charge_fulls - f0, P.ak.charge_last])
	# Rage on dummies: the juggernaut fills up and gets Enraged
	A.set_arch("juggernaut")
	var JK: JuggernautKit = P.ak
	for i in 14:
		JK.on_deal(D, 10.0, {"src": "shot"})
		JK.hit_at = -9.0
	step(m, 0.3)
	ok("juggernaut: Rage fills to Enraged, the form grows", JK.enraged_t > 0.0 and JK.aura != null and P.model.scale.x > 1.05, "enraged %.1f scale %.2f" % [JK.enraged_t, P.model.scale.x])
	# R fuse: winds up first, then fires
	P.ak.cd["r"] = 0.0
	P.ak.use_r()
	ok("R: fuse first", P.ak.fusing() and float(P.ak.cd["r"]) > 60.0)
	step(m, P.ak.fuse_time() + 0.1)
	ok("R: then Avalanche", not P.ak.fusing() and P.ak.r_t > 0.0)
	# the sparring bot
	A.cycle_bot()
	ok("bot: idle", A.bot != null and A.bot_mode == "idle")
	A.bot_mode = "fighting"; A.set_bot_arch("thief")
	step(m, 0.5)
	ok("bot: fights as a thief", A.bot != null and A.bot.arch == "thief")
	A.bot_mode = "off"; A._spawn_bot()
	ok("bot: off", A.bot == null)
	# the panels build
	A.open_menu()
	ok("loadout panel opens (fixed size)", A.menu_layer != null and m.paused)
	A.close_menu()
	A.toggle_card()
	ok("kit card opens in the arena", A.card_layer != null)
	A.toggle_card()
	ok("kit card closes", A.card_layer == null and not m.paused)
	A.teardown()
	m.queue_free()
	printerr("ARENACHECK (arena match freed)")
	await main.get_tree().process_frame
	printerr("ARENACHECK (next frame)")

func _training() -> void:
	var m := Match.new()
	main.add_child(m)
	printerr("ARENACHECK starting the training match")
	await m.start({"training": true, "practice": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	printerr("ARENACHECK training match up")
	var P: Hunter = m.player
	ok("training gets the practice tools", m.arena != null and m.arena.layout == "practice" and m.arena.dummies.size() == 3)
	ok("training: ult open from the start", int(P.slot_lv["ult"]) >= 1)
	m.arena.set_arch("thief")
	ok("training: archetype swap", P.arch == "thief")
	# every ability goes off in training
	P.inp["aim"] = P.pos + Vector3(3, 0.9, 0)
	P.ak.use_e()
	ok("training: E casts", float(P.ak.cd["e"]) > 0.0)
	P.ak.ch_rmb = 1.0; P.inp["sec_hold"] = false; P.ak.press_rmb()
	step(m, 0.1)        # a tap fires on release
	ok("training: RMB casts", P.ak.last_variant != "", P.ak.last_variant)
	var dsh := P.dashes
	P.do_dash()
	ok("training: dash", P.dashes < dsh or P.roll_t > 0.0)
	m.queue_free()
	await main.get_tree().process_frame

func _cards() -> void:
	printerr("ARENACHECK (kit cards)")
	var host := Control.new()
	main.add_child(host)
	for a in Arch.ids():
		var c := KitCard.make(a, "cindle")
		host.add_child(c)
		await main.get_tree().process_frame
		ok("kit card builds: %s" % a, c.grid != null and c.grid.get_child_count() == 6 and c.size.x <= KitCard.SIZE.x + 1.0, "size %s" % str(c.size))
		var s0 := c.size
		c._show_detail("rmb")
		await main.get_tree().process_frame
		ok("kit card sub-page keeps its size: %s" % a, c.page == "rmb" and c.size.is_equal_approx(s0), "%s -> %s" % [str(s0), str(c.size)])
		for s in KitCard.SLOTS:
			var info := KitCard.slot_text(a, s)
			if String(info["line"]) == "" or String(info["name"]) == "":
				ok("kit card text %s.%s" % [a, s], false)
		c.queue_free()
	var inf := KitCard.infusion_lines("thief", KinLib.kin("cindle"))
	ok("kit card: Boki infusion lines", inf.size() == 3, " | ".join(inf))
	host.queue_free()

func _loadout() -> void:
	var st := KitCard.strip("juggernaut", func(): pass)
	main.add_child(st)
	await main.get_tree().process_frame
	var tiles := 0
	for ch in (st.get_child(0) as HBoxContainer).get_children():
		if ch is Button: tiles += 1
	ok("loadout strip: six kit tiles", tiles == 6)
	st.queue_free()
	# the real expedition panel at home carries the strip
	var Home = load("res://scripts/home/home.gd")
	ok("home has the kit card", Home != null and (Home as Script).get_script_method_list().any(func(md): return String(md["name"]) == "_open_kit_card"))
	var src := FileAccess.get_file_as_string("res://scripts/home/home.gd")
	ok("expedition panel uses KitCard.strip", src.contains("KitCard.strip(cur_a"))
