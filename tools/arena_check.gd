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
	await _breaker_whirl()
	await _cards()
	await _loadout()
	printerr("ARENACHECK (training match next)")
	await _training()
	print("ARENACHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()

## Mossy's LMB hold in the Arena, both ways in (opened as him, swapped to him from the menu), with the effect
## ticking on real frames: his own 3D hammer stays in the hand, it whirls at the data's rate and it is big enough
## to read at the match camera. The release slams.
func _breaker_whirl() -> void:
	for start in ["bulwark", "thief"]:
		var m := Match.new()
		main.add_child(m)
		await m.start(Match.arena_opts(start))
		m.set_process(false)
		var P: Hunter = m.player
		if start != "bulwark":
			m.arena.set_arch("bulwark")
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		var K: BulwarkKit = P.ak
		var how := "opened as him" if start == "bulwark" else "swapped to him"
		var pv: Node3D = K.fx._pivot()
		var mesh := pv.get_node_or_null(WardenGlb.WEAPON) as MeshInstance3D
		var warden := P.model.get_node_or_null("Warden")
		var skinned := warden != null and warden.find_child("hammer", true, false) != null
		if skinned:      # (skinned in the .glb, item 76b: on its bone, the pivot stays as the reference)
			mesh = warden.find_child("hammer", true, false) as MeshInstance3D
		ok("arena Mossy (%s): his 3D hammer is %s" % [how, "skinned on him" if skinned else "on the swing's pivot"],
			mesh != null and mesh.is_visible_in_tree())
		P.fire_cd = 0.0
		var last := Vector3.ZERO
		var turns := 0.0
		var long_m := 0.0
		for i in 90:
			P.inp["fire"] = true
			P.inp["aim"] = P.pos + Vector3(6, 0, 0)
			m.step(DT)
			await main.get_tree().process_frame
			var v: Vector3 = K.fx._pivot().global_basis * Vector3.FORWARD
			if i > 30 and last != Vector3.ZERO:
				turns += absf(angle_difference(atan2(last.x, last.z), atan2(v.x, v.z)))
			last = v
			if mesh and is_instance_valid(mesh):
				var box := mesh.get_aabb()
				var k := mesh.global_basis.get_scale().x * float(P.model.get_meta(WardenClips.WEAPON_K, 1.0))
				long_m = maxf(long_m, k * box.size[box.get_longest_axis_index()])
		var rate := turns / TAU / (59.0 * DT)
		ok("arena Mossy (%s): held, the hammer whirls at the data's rate" % how,
			K.fx.held and K.anim_id == "bul_smash_wind" and rate >= float(K.lmb_def()["spin_turns"][0]) - 0.1,
			"%.2f turns/s" % rate)
		# (item 137: a skinned hammer is true to the sheet, 0.79 of his height; the pinned one is scaled up to read)
		var want := 1.5 if skinned else 2.5
		ok("arena Mossy (%s): the whirled hammer reads at the match camera (>= %.1f m long)" % [how, want],
			long_m >= want,
			"%.2f m" % long_m)
		var s0 := K.slams
		P.inp["fire"] = false
		m.step(DT)
		ok("arena Mossy (%s): the release slams" % how, K.slams == s0 + 1 and not K.fx.held,
			"slams +%d" % (K.slams - s0))
		# the usual order in play: throw it, then press and keep holding: it comes back and he goes into the whirl
		step(m, 1.0)
		P.inp["fire"] = true
		m.step(DT)
		P.inp["fire"] = false
		step(m, 0.8)
		var out := not K.mace.is_empty()
		P.inp["fire"] = true
		step(m, 2.0)
		ok("arena Mossy (%s): held through a recall, the catch goes into the whirl" % how,
			out and K.mace.is_empty() and K.fx.held, "out %s back %s held %s" % [out, K.mace.is_empty(), K.fx.held])
		P.inp["fire"] = false
		m.queue_free()
		await main.get_tree().process_frame

func _arena() -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts("thief"))
	m.set_process(false)
	var P: Hunter = m.player
	ok(
		"arena boots on its own map", m.world.layout_id == "arena" and m.arena != null and m.arena.layout == "arena",
		"layout %s" % m.world.layout_id
	)
	ok(
		"arena: no monsters, chests or train", m.mobs.is_empty() and m.chests.is_empty() and m.skytrain == null,
		"mobs %d chests %d" % [m.mobs.size(), m.chests.size()]
	)
	ok(
		"arena: player is a thief on the floor", P.arch == "thief" and m.world.island_id(P.pos.x, P.pos.z) == "floor",
		"%s on %s" % [P.arch, m.world.island_id(P.pos.x, P.pos.z)]
	)
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
	ok(
		"dummy meter counts it", float(A.dummies[0]["total"]) >= 25.0 and A.dealt >= 25.0,
		"total %.0f" % float(A.dummies[0]["total"])
	)
	A.tick(DT)
	ok(
		"dummy label shows DPS", String((A.dummies[0]["label"] as Label3D).text).begins_with("DPS"),
		String((A.dummies[0]["label"] as Label3D).text)
	)
	# a real Bola lands on a dummy: Grounded, a Mark; SMG hits on it stack Marks (the pips)
	P.teleport(D.pos + Vector3(0, 0, 4.0)); P.inp["aim"] = D.pos + Vector3(0, 0.9, 0); P.inp["aim_y"] = D.pos.y
	P.ak.cd["rmb"] = 0.0; P.ak.ch_rmb = 1.0
	var tot0 := float(A.dummies[0]["total"])
	P.inp["sec_hold"] = false; P.ak.press_rmb()
	step(m, 0.75)          # (the Bola's 0.4s wind-up with the lane, then its flight)
	var tk := P.ak as ThiefKit
	ok("thief Bola hits a dummy, Grounds and Marks it", float(A.dummies[0]["total"]) > tot0 and tk.marks_on(D) >= 1,
		"total %.0f marks %d" % [float(A.dummies[0]["total"]), tk.marks_on(D)])
	(P.ak as ThiefKit).add_mark(D, 4, true)
	step(m, 0.05)
	ok("five Marks: diamonds over the dummy", tk.pips.size() >= 1 and tk.marks_on(D) >= 5,
		"marks %d pips %d" % [tk.marks_on(D), tk.pips.size()])
	# reset: everyone back, healed, meters cleared
	P.teleport(P.pos + Vector3(3, 0, 0)); P.hp = 10.0
	var bk := InputEventKey.new(); bk.physical_keycode = KEY_BACKSPACE; bk.keycode = KEY_BACKSPACE; bk.pressed = true
	var xk := InputEventKey.new(); xk.physical_keycode = KEY_X; xk.keycode = KEY_X; xk.pressed = true
	A.keys_node._unhandled_input(xk)      # X is the Merge key: it must not reset the arena
	ok("X doesn't reset the arena (it is the Merge key)", P.flat_dist(A.home) > 1.0)
	A.keys_node._unhandled_input(bk)      # Backspace resets
	ok("Backspace resets the arena", P.flat_dist(A.home) < 0.2)
	P.teleport(P.pos + Vector3(3, 0, 0)); P.hp = 10.0
	A.reset()
	ok("reset: you're home and healed", P.flat_dist(A.home) < 0.2 and P.hp >= P.max_hp - 0.1)
	ok(
		"reset: dummies full and meters clear",
		D.hp >= Arena.DUMMY_HP - 0.1 and float(A.dummies[0]["total"]) == 0.0 and A.dealt == 0.0
	)
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
	# item 69: two glove slots, Q and V, picked and fired independently
	var gid0 := func(i: int) -> String: return String(P.gear[i].get("id", ""))
	A.give_glove("grapple", 1)
	ok("two gloves: blink stays on Q, grapple goes to V", gid0.call(0) == "blink" and gid0.call(1) == "grapple")
	P.gear_cd[0] = 9.0
	P.gear_cd[1] = 9.0
	A.tick(DT)
	ok("cooldowns off covers both gloves", float(P.gear_cd[0]) <= 0.0 and float(P.gear_cd[1]) <= 0.0)
	A.cd_off = false
	P.gear_cd[0] = 0.0
	P.gear_cd[1] = 0.0
	m.use_gear(P, 1)
	ok("the V glove fires alone: V on cooldown, Q ready", float(P.gear_cd[1]) > 0.0 and float(P.gear_cd[0]) <= 0.0)
	m.use_gear(P, 0)
	ok("then the Q glove fires too", float(P.gear_cd[0]) > 0.0)
	A.give_glove("blink", 1)
	ok("one glove can't be worn twice: blink to V empties Q", A.gloves[0] == "" and gid0.call(1) == "blink")
	A.give_glove("grapple", 0)
	ok("two gloves again: grapple Q, blink V", gid0.call(0) == "grapple" and gid0.call(1) == "blink")
	A.give_glove("blink", 0)
	A.give_glove("grapple", 1)
	A.cd_off = false
	A.toggle_ult()
	ok("ult toggle: locked", int(P.slot_lv["ult"]) == 0)
	A.toggle_ult()
	ok("ult toggle: unlocked", int(P.slot_lv["ult"]) >= 1)
	# swaps: archetype (with its weight class), weapon, Boki
	A.set_arch("juggernaut")
	ok(
		"swap to juggernaut: heavy, rage kit",
		P.arch == "juggernaut" and P.cls == "heavy" and P.ak is JuggernautKit and P.max_hp >= 180.0,
		"%s %s hp %.0f" % [P.arch, P.cls, P.max_hp]
	)
	ok("swap keeps both gloves", gid0.call(0) == "blink" and gid0.call(1) == "grapple")
	ok("the swap brings the archetype's one weapon", P.wid == Arch.signature("juggernaut"))
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
		# (the support pair's RMBs are taps)
		if not (Arch.def(a)["rmb"].get("variants", {}) as Dictionary).has("hold"): continue
		# a kit with no hold input (Motley: his orb pauses, nothing is held)
		if Arch.def(a).get("no_hold", false): continue
		A.set_arch(a)
		P.teleport(A.home); P.inp["aim"] = D.pos + Vector3(0, 0.9, 0); P.inp["aim_y"] = D.pos.y
		P.ak.cd["rmb"] = 0.0; P.ak.ch_rmb = float(P.ak.rmb_charges()); P.fire_cd = 0.0
		step(m, 0.1)
		if float(P.ak.rmb_def().get("hold", 0.0)) <= 0.0:
			continue      # no RMB hold variant (Grimble, Cinder: their hold is the lance, see --ashwick-combo-check)
		var f0: int = P.ak.charge_fulls
		var mid := -1.0
		var ring_ok := false
		if a == "gunslinger":
			# Vex's hold is Longneedle's charge (E): a ring, a full tick, the shot
			P.ak.cd["e"] = 0.0; P.ak.use_e()
			step(m, 0.5)
			ok(
				"hold: gunslinger Longneedle winds up (ring)",
				not P.ak.chg.is_empty() and is_instance_valid(P.ak.chg.get("ring"))
			)
			step(m, 0.7)
			ok("hold: gunslinger Longneedle ticks full and fires", P.ak.charge_fulls > f0 and P.ak.chg.is_empty())
			continue
		var t := 0.0
		while t < 1.45:
			# the Crushing Blow / the blades' spin are the charge
			if a in ["bulwark", "thief"]: P.inp["fire"] = true
			elif t < 0.02: P.ak.bot_hold["rmb"] = 1.45; P.ak.press_rmb()
			m.step(DT); t += DT
			if t > 0.4 and mid < 0.0:
				mid = P.ak.charge_k()
				ring_ok = P.ak.chg.get("ring") != null and is_instance_valid(P.ak.chg.get("ring"))
		P.inp["fire"] = false
		step(m, 0.3)
		ok(
			"hold: %s winds up (ring), ticks full, releases" % a,
			mid > 0.1 and ring_ok and P.ak.charge_fulls > f0 and P.ak.charge_last > 0.9 and P.ak.chg.is_empty(),
			"mid %.2f fulls +%d last %.2f" % [mid, P.ak.charge_fulls - f0, P.ak.charge_last]
		)
	# the Juggernaut's second hold: the greatsword's Searing Wave
	A.set_arch("juggernaut", "greatsword")
	P.teleport(A.home); P.inp["aim"] = D.pos + Vector3(0, 0.9, 0); P.fire_cd = 0.0
	step(m, 0.1)
	var wf0: int = P.ak.charge_fulls
	var wmid := {"k": -1.0, "ring": false}
	var tw := 0.0
	while tw < 1.2:
		P.inp["fire"] = true
		m.step(DT); tw += DT
		if tw > 0.55 and float(wmid["k"]) < 0.0:
			wmid["k"] = P.ak.charge_k(); wmid["ring"] = P.ak.chg.get("ring") != null
	P.inp["fire"] = false
	step(m, 0.3)
	ok(
		"hold: juggernaut greatsword winds up a Searing Wave",
		float(wmid["k"]) > 0.1 and bool(wmid["ring"]) and P.ak.charge_fulls > wf0 and (
			P.ak as JuggernautKit
		).waves >= 1,
		"mid %.2f fulls +%d waves %d" % [float(wmid["k"]), P.ak.charge_fulls - wf0, (P.ak as JuggernautKit).waves]
	)
	# Rage on dummies: the juggernaut fills up and gets Enraged
	A.set_arch("juggernaut")
	var JK: JuggernautKit = P.ak
	for i in 14:
		JK.on_deal(D, 16.0, {"src": "shot"})
	step(m, 0.3)
	ok("juggernaut: Rage fills to Enraged, the form grows",
		JK.enraged_t > 0.0 and JK.aura != null and P.model.scale.x > 1.05,
		"enraged %.1f scale %.2f" % [JK.enraged_t, P.model.scale.x])
	# X is Kael's own ultimate (the Arena opens it with the ult toggle at level 6); R stays the Merge
	ok("juggernaut: his own ultimate is on X (Gilded Riposte)",
		String(Arch.def("juggernaut")["x"]["name"]) == "Gilded Riposte")
	# the sparring bot
	A.cycle_bot()
	ok("bot: idle", A.bot != null and A.bot_mode == "idle")
	A.bot_mode = "fighting"; A.set_bot_arch("thief")
	step(m, 0.5)
	ok("bot: fights as a thief", A.bot != null and A.bot.arch == "thief")
	# kits2: the sparring bot really uses the Thief's and the Juggernaut's kits on you
	# (their ultimates on X open at level 6, and the sparring bot is level 1: its kit here is RMB, E and the dash)
	for ba in ["thief", "juggernaut"]:
		# the bot's dice must not depend on how many rolls the earlier sections took (as in main.gd's bot checks):
		# the global dice and the match's own, which rolls the new bot's mind (skill, strafe side, timings)
		seed(2024)
		m.rng.seed = 2024
		A.set_bot_arch(ba)
		var B: Hunter = A.bot
		P.teleport(A.home); B.teleport(A.home + Vector3(5.0, 0, 0))
		var seen := {"dash": false}
		var tb := 0.0
		# up to 40s, stopping once it has used all of them (the dash is a dice roll in a short window)
		while tb < 40.0:
			P.hp = P.max_hp
			B.hp = B.max_hp
			if int(tb / DT) % int(3.0 / DT) == 1:
				# a hit every 3s: the bot only dashes when it has just been hurt, and the Bokis no longer happen to land
				# one
				B.hp = B.max_hp - 20.0
			# step back every 5s: with no glove ranks its RMB is ready so often that it never leaves melee for an E
			if int(tb / DT) % int(5.0 / DT) == 2:
				B.teleport(P.pos + Vector3(6.0, 0, 0))
			m.step(DT); tb += DT
			if B.ak is ThiefKit and float((B.ak as ThiefKit).primed_t) > 0.0: seen["dash"] = true
			if B.ak is JuggernautKit and String(B.ak.st.get("last_dash", "")) == "rampage": seen["dash"] = true
			if tb > 18.0 and seen["dash"] and int(B.used.get("utility", 0)) > 0 and int(B.used.get("k1", 0)) > 0: break
		var u: Dictionary = B.used
		var used_all := int(u.get("utility", 0)) > 0 and int(u.get("k1", 0)) > 0 and bool(seen["dash"])
		ok("bot uses the %s kit (RMB, E, dash)" % ba, used_all,
			"rmb %d e %d dash %s" % [int(u.get("utility", 0)), int(u.get("k1", 0)), seen["dash"]])
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
	await m.start(
		{
			"training": true, "practice": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242,
			"no_drop": true
		}
	)
	m.set_process(false)
	printerr("ARENACHECK training match up")
	var P: Hunter = m.player
	ok(
		"training gets the practice tools",
		m.arena != null and m.arena.layout == "practice" and m.arena.dummies.size() == 3
	)
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
		var slots_built := c.grid != null and c.grid.get_child_count() == KitCard.card_slots(a).size()
		ok(
			"kit card builds: %s" % a,
			slots_built and c.size.x <= KitCard.SIZE.x + 1.0,
			"size %s" % str(c.size)
		)
		var s0 := c.size
		c._show_detail("rmb")
		await main.get_tree().process_frame
		ok(
			"kit card sub-page keeps its size: %s" % a, c.page == "rmb" and c.size.is_equal_approx(s0),
			"%s -> %s" % [str(s0), str(c.size)]
		)
		for s in KitCard.slots_of(a):
			var info := KitCard.slot_text(a, s)
			if String(info["line"]) == "" or String(info["name"]) == "":
				ok("kit card text %s.%s" % [a, s], false)
		c.queue_free()
	var inf := KitCard.infusion_lines("thief", KinLib.kin("cindle"))
	ok("kit card: Boki infusion lines (RMB and E; her ultimate on X isn't infused)", inf.size() == 2, " | ".join(inf))
	host.queue_free()

func _loadout() -> void:
	var st := KitCard.strip("juggernaut", func(): pass)
	main.add_child(st)
	await main.get_tree().process_frame
	var tiles := 0
	for ch in (st.get_child(0) as HBoxContainer).get_children():
		if ch is Button: tiles += 1
	ok("loadout strip: six kit tiles (the hunter ultimate has its own X tile)", tiles == 6, str(tiles))
	st.queue_free()
	# the real expedition panel at home carries the strip
	var Home = load("res://scripts/home/home.gd")
	ok(
		"home has the kit card",
		Home != null and (Home as Script).get_script_method_list().any(
			func(md): return String(md["name"]) == "_open_kit_card"
		)
	)
	var src := FileAccess.get_file_as_string("res://scripts/home/home.gd")
	ok("expedition panel uses KitCard.strip", src.contains("KitCard.strip(cur_a"))
