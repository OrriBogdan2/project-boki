extends RefCounted
## --gear-check: every archetype carries one fixed signature weapon, no weapon pickups ever spawn,
## gear rolls the Common..Legendary rarities, gear and weapon upgrades change the numbers they say,
## the chest / crate / Blight / boss drop tables give gear and tunings (bosses fewer and better),
## and a v4 save (weapons, gloves, glove loadout) migrates to v5 gear. Prints GEARCHECK PASS/FAIL.

var main: Node
var fails := 0
var n := 0

func ok(name: String, cond: bool, info := "") -> void:
	n += 1
	printerr("GEARCHECK %-52s %s  %s" % [name, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_data()
	_rolls()
	_migration()
	await _match()
	_glove_combos()
	print("GEARCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _data() -> void:
	var seen := {}
	var good := true
	for a in Arch.ids():
		var sg := Arch.signature(String(a))
		if sg == "" or not FileAccess.file_exists("res://content/weapons/%s.json" % sg) or not Arch.weapon_ok(String(a), sg) or (Arch.weapons(String(a)) as Array).size() != 1:
			good = false
		seen[sg] = true
	ok("each archetype names one signature weapon", good, str(seen.keys()))
	ok("the six archetypes have six different signatures", seen.size() == Arch.ids().size(), "%d" % seen.size())
	for s in Gear.SLOTS.size():
		ok("slot %d (%s) has gear to find" % [s, Gear.SLOTS[s]], not Gear.ids_for(s).is_empty())
	ok("armor and boots pieces exist beyond the old gloves (the kit slot is the utility belt now)",
			Gear.ids_for(2).size() >= 2 and Gear.ids_for(3).size() >= 2 and Gear.SLOTS.size() == 4)
	var wup := 0
	var brands := 0
	for k in Data.PERKS:
		if Data.PERKS[k].has("wup"):
			wup += 1
			if Data.PERKS[k]["wup"].has("brand"): brands += 1
	ok("weapon upgrades and Brands exist as perks", wup >= 9 and brands >= 4, "%d upgrades, %d brands" % [wup, brands])
	ok("rarity multiplier rises Common to Legendary", Gear.mult(0) < Gear.mult(2) and Gear.mult(2) < Gear.mult(3) and Gear.mult(3) < Gear.mult(4))
	var lo_ok := true
	for k in ["gear0", "gear1", "gear3"]:
		if not Econ.LOADOUT_SLOTS.has(k): lo_ok = false
	ok("the loadout has three slots: gloves and boots (armor and kit are not brought in)", lo_ok
			and Econ.LOADOUT_SLOTS.size() == 3)

func _rolls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var count := [0, 0, 0, 0, 0]
	var slots := [0, 0, 0, 0]
	for i in 4000:
		var g := GearDrops.roll_gear(rng)
		count[int(g["rar"])] += 1
		slots[Gear.slot_of(String(g["id"]))] += 1
	ok("gear rolls every rarity, Common most and Legendary least", count.min() > 0 and count[1] > count[3] and count[3] > count[4], str(count))
	ok("gear rolls every slot", slots.min() > 0, str(slots))
	var up := [0, 0, 0, 0, 0]
	for i in 2000: up[GearDrops.roll_rarity(rng, 2)] += 1
	ok("a rarity bonus pushes drops up", up[0] == 0 and up[2] + up[3] + up[4] > count[2] / 2, str(up))
	var floor_ok := true
	for i in 500:
		if GearDrops.roll_rarity(rng, 0, 2) < 2: floor_ok = false
	ok("min_rar is a floor", floor_ok)
	var forced := true
	for i in 200:
		if Gear.slot_of(String(GearDrops.roll_gear(rng, 0, 0, 3)["id"])) != 3: forced = false
	ok("a forced slot gives that slot's gear", forced)

func _migration() -> void:
	var d := {"v": 4, "arch": "mage", "weapon": "shotgun", "scrap": 3,
		"armory": [{"t": "weapon", "wid": "smg", "rar": 3, "el": "fire", "uq": "", "uid": "iw1"},
			{"t": "glove", "id": "vest", "rar": 2, "uid": "ig1"}, {"t": "valuable", "id": "old_coin", "uid": "iv1"}],
		"raid_out": [{"t": "weapon", "wid": "pistol", "rar": 0, "el": "", "uq": "", "uid": "iw2"}],
		"loadout": {"weapon": "iw1", "glove0": "ig1", "glove1": "gone"}}
	GearSave.migrate(d)
	var types := (d["armory"] as Array).map(func(it): return String(it.get("t", "")))
	ok("migration: stored weapons are gone, gloves become gear", not types.has("weapon") and types.has("gear") and types.has("valuable") and (d["raid_out"] as Array).is_empty(), str(types))
	ok("migration: weapons break down into scrap", int(d["scrap"]) >= 3 + 4 + 2 + 1, "scrap %d" % int(d["scrap"]))
	ok("migration: an old glove that is armor now lands in the armor slot (not gear0)", d["loadout"].get("gear2", "") == "ig1" and not d["loadout"].has("gear0") and not d["loadout"].has("glove0") and not d["loadout"].has("weapon") and not d["loadout"].has("gear1"), str(d["loadout"]))
	# a v4 loadout whose two "gloves" are really vest + boots, with a third piece (an active glove) in the armory
	var d2 := {"v": 4, "arch": "mage", "scrap": 0,
		"armory": [{"t": "glove", "id": "vest", "rar": 1, "uid": "a1"}, {"t": "glove", "id": "boots", "rar": 2, "uid": "a2"},
			{"t": "glove", "id": "blink", "rar": 0, "uid": "a3"}, {"t": "glove", "id": "blink", "rar": 3, "uid": "a4"}],
		"raid_out": [], "loadout": {"glove0": "a1", "glove1": "a2"}}
	GearSave.migrate(d2)
	ok("migration: vest and boots keep both pieces, each in its own real slot", d2["loadout"].get("gear2", "") == "a1" and d2["loadout"].get("gear3", "") == "a2" and d2["loadout"].size() == 2, str(d2["loadout"]))
	var d3 := {"v": 4, "arch": "mage", "scrap": 0,
		"armory": [{"t": "glove", "id": "blink", "rar": 0, "uid": "a3"}, {"t": "glove", "id": "blink", "rar": 3, "uid": "a4"}],
		"raid_out": [], "loadout": {"glove0": "a3", "glove1": "a4"}}
	GearSave.migrate(d3)
	var left: Array = (d3["armory"] as Array).map(func(it): return String(it["uid"]))
	ok("migration: two pieces for one slot: one is worn, the other stays in the armory (nothing lost)", d3["loadout"].size() == 1 and d3["loadout"].get("gear0", "") == "a3" and left.has("a4") and left.has("a3"), "%s %s" % [str(d3["loadout"]), str(left)])
	ok("migration: the weapon you carry is your signature", String(d["weapon"]) == Arch.signature("mage"), String(d["weapon"]))
	var s := Save.fresh()
	ok("a fresh save is v%d" % Save.VERSION, int(s["v"]) == Save.VERSION and Save.VERSION >= 5)
	Save.d = Save.fresh()
	var before := int(Save.d.get("scrap", 0))
	var mats := GearSave.extract_mats([Loot.gear("quilted_coat", 0), Loot.gear("quilted_coat", 4), Loot.valuable("old_coin")])
	ok("extracting gear gives farm materials, more for rarer gear", int(mats["wood"]) + int(mats["stone"]) + int(mats["scrap"]) > 0 and int(Save.d["scrap"]) >= before)
	var lo := GearSave.extract_mats([Loot.gear("quilted_coat", 4)])
	var hi := GearSave.extract_mats([Loot.gear("quilted_coat", 0)])
	ok("a Legendary breaks down into more than a Common", int(lo["wood"]) + int(lo["stone"]) + int(lo["scrap"]) > int(hi["wood"]) + int(hi["stone"]) + int(hi["scrap"]))

func _start(arch: String, seed_: int) -> Match:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": seed_, "no_drop": true, "arch": arch, "cls": Arch.weight(arch)})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	return m

func _match() -> void:
	# 1. every archetype starts with its signature weapon
	for a in Arch.ids():
		var m := await _start(String(a), 11)
		var P: Hunter = m.player
		ok("%s: starts with its signature %s" % [a, Arch.signature(String(a))], P.wid == Arch.signature(String(a)), P.wid)
		var bots_ok := true
		for h in m.hunters:
			if not Arch.weapon_ok(h.arch, h.wid): bots_ok = false
		ok("%s match: every hunter holds their archetype's weapon" % a, bots_ok)
		m.queue_free()
	var m := await _start("archer", 5)
	var P: Hunter = m.player
	# 2. gear effects
	var hp0 := P.max_hp
	P.gear[2] = {"id": "quilted_coat", "rar": 2}
	P.refresh_gear()
	ok("armor gear adds health", absf(P.max_hp - hp0 - 22.0 * Gear.mult(2)) < 0.6, "%.1f -> %.1f" % [hp0, P.max_hp])
	P.gear[2] = {}
	P.refresh_gear()
	ok("taking the armor off takes the health back", absf(P.max_hp - hp0) < 0.6, "%.1f" % P.max_hp)
	# swapping armor keeps the same share of the health bar: it must never heal (pack swap, review finding)
	P.hp = P.max_hp * 0.4
	var share0 := P.hp / P.max_hp
	var hp_hurt := P.hp
	for round_i in 3:
		P.gear[2] = {"id": "quilted_coat", "rar": 2}
		P.refresh_gear()
		ok("wearing armor while hurt keeps the same share of the bar (round %d)" % round_i, absf(P.hp / P.max_hp - share0) < 0.001, "%.1f / %.1f" % [P.hp, P.max_hp])
		P.gear[2] = {}
		P.refresh_gear()
		ok("and taking it off again does not heal (round %d)" % round_i, P.hp <= hp_hurt + 0.01 and absf(P.hp / P.max_hp - share0) < 0.001, "%.1f / %.1f" % [P.hp, P.max_hp])
	var cap0 := P.pack_cap
	ok("the pack is the same size for everyone", cap0 == Equal.base_pack(), str(cap0))
	P.gear[3] = {"id": "windstep_boots", "rar": 1}
	ok("boots give their movement perk", P.gear_stat("glide_speed") > 0.0)
	P.gear[3] = {}
	var hi := Loot.gear("quilted_coat", 4)
	var lo := Loot.gear("quilted_coat", 0)
	ok("a Legendary is worth more than a Common", Loot.value(hi) > Loot.value(lo))
	# 3. weapon upgrades
	var d0 := float(P.wpn["dmg"])
	var mag0 := int(P.wpn["mag"])
	ok("a one-shot weapon is never offered Deep Magazine", not P.perk_open("deepmag"))
	P.add_perk("hotload")
	ok("Hotload hits harder", absf(float(P.wpn["dmg"]) - d0 * 1.10) < 0.01 * d0 + 0.001, "%.2f -> %.2f" % [d0, float(P.wpn["dmg"])])
	ok("Deep Magazine is no use to the longbow, so it can't be taken", int(P.wpn["mag"]) == mag0)
	ok("the weapon in hand is still the signature", P.wid == Arch.signature("archer"))
	var rf := await _start("gunslinger", 6)
	var G: Hunter = rf.player
	var gm0 := int(G.wpn["mag"])
	G.add_perk("deepmag")
	ok("Deep Magazine holds more rounds for a magazine weapon", int(G.wpn["mag"]) > gm0, "%d -> %d" % [gm0, int(G.wpn["mag"])])
	rf.queue_free()
	P.add_perk("brand_fire")
	ok("a Brand sets the element on every hit", P.welem == "fire", P.welem)
	P.add_perk("brand_frost")
	ok("the latest Brand wins", P.welem == "frost", P.welem)
	ok("the upgrade line names them", WeaponUps.summary(P).contains("Hotload") and WeaponUps.summary(P).contains("Brand"), WeaponUps.summary(P))
	# a level-up takes the hero's fixed weapon path (no choice); the full per-hero check is --perkorb-check
	var lv_before := P.perks.size()
	var step := WeaponPath.on_level(P, 2)
	ok("a level-up applies a weapon upgrade by itself", not step.is_empty() and P.perks.size() == lv_before + 1 and Data.PERKS[step["perk"]].has("wup"), str(step.get("perk", "")))
	# 4. drop tables: gear and tunings, never a weapon
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var at: Vector3 = P.pos + Vector3(3, 0, 3)
	var tables: Array = ["ground", "cache", "crate", "chest", "brute", "sentinel", "warden", "glimmer", "bl_skitter", "bl_warden", "boss"]
	var total := {}
	for t in tables:
		total[t] = 0
		for i in 40:
			total[t] += GearDrops.run_table(m, String(t), at, rng, {"h": P}).size()
	var clean := true
	for wp in m.wpicks:
		if not (wp.has("gear") or wp.has("tune") or wp.has("val")) or String(wp.get("wid", "")) != "":
			clean = false
	ok("no weapon pickups spawn from any table", clean and not m.wpicks.is_empty(), "%d pickups" % m.wpicks.size())
	ok("every table is defined and drops something", tables.all(func(t): return int(total[t]) > 0), str(total))
	ok("a chest pays more than a crate", int(total["chest"]) > int(total["crate"]))
	var bossn := 0
	var low := false
	var brand := false
	var legend := 0
	for i in 200:
		var r := GearDrops.run_table(m, "boss", at, rng, {"h": null, "net": false})
		bossn += r.size()
		for e in r:
			if e["kind"] == "gear":
				if int(e["rar"]) < 2: low = true
				if int(e["rar"]) == 4: legend += 1
			elif e["kind"] == "tune" and Data.PERKS[e["id"]]["wup"].has("brand"): brand = true
	ok("a boss drops few items", float(bossn) / 200.0 <= 4.0, "%.2f a boss" % (float(bossn) / 200.0))
	ok("boss gear is Rare or better, with a Brand and sometimes Legendary", not low and brand and legend > 0, "legend %d/200" % legend)
	var per_chest := float(total["chest"]) / 40.0
	ok("a boss drops fewer than a rich chest has junk, but better", float(bossn) / 200.0 <= maxf(per_chest, 3.0))
	# 5. walking over a tuning applies it; gear goes into its slot and the old piece drops
	for wp in m.wpicks.duplicate():
		if is_instance_valid(wp["node"]): wp["node"].queue_free()
	m.wpicks.clear()
	var P2: Hunter = P
	P2.perks.clear()
	WeaponUps.apply(P2)
	m.spawn_tune("longreach", P2.pos, "", false)
	m.take_pick(P2, m.wpicks[0])
	ok("taking a tuning applies it", P2.perks.has("longreach") and m.wpicks.is_empty(), str(P2.perks))
	P2.gear[2] = {"id": "quilted_coat", "rar": 0}
	m.spawn_gear("bastion_plate", 3, P2.pos, "", false)
	m.take_pick(P2, m.wpicks[0])
	ok("taking gear replaces the slot", String(P2.gear[2]["id"]) == "bastion_plate" and int(P2.gear[2]["rar"]) == 3)
	ok("and the old piece drops to the ground", m.wpicks.size() == 1 and String(m.wpicks[0].get("gear", "")) == "quilted_coat")
	# 6. a bot picks up a rarer piece than it wears
	var bot: Hunter = null
	for h in m.hunters:
		if h != P: bot = h
	if bot != null:
		bot.gear[2] = {}
		ok("bots want gear for an empty slot", GearDrops.bot_wants(bot, "bastion_plate", 0))
		bot.gear[2] = {"id": "bastion_plate", "rar": 3}
		ok("bots leave a worse piece alone", not GearDrops.bot_wants(bot, "quilted_coat", 1))
		var r2 := RandomNumberGenerator.new(); r2.seed = 3
		bot.gear = Gear.empty_slots()
		GearDrops.bot_start(bot, r2, "hard")
		ok("a hard bot starts with gear on", bot.gear.any(func(g): return not (g as Dictionary).is_empty()))
	m.queue_free()

## Two gloves (Q and V) chain into each other: a hook drags a foe in and a fissure on the other key
## throws them up at once; each glove keeps its own cooldown; a passive glove sits in either slot.
func _glove_combos() -> void:
	var r: Array = main._ac_setup(7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	P.gear[0] = {"id": "grapple", "rar": 1}
	P.gear[1] = {"id": "quake", "rar": 1}
	P.gear_cd[0] = 0.0
	P.gear_cd[1] = 0.0
	var d0 := P.flat_dist(T)
	P.inp["gear1"] = true
	_glove_run(m, 0.8)
	ok("combo: Q's hook drags the foe to your feet", P.flat_dist(T) < 3.0, "%.1f -> %.1f m" % [d0, P.flat_dist(T)])
	ok("combo: V is ready the moment Q is spent (two cooldowns, not one)", P.gear_cd[0] > 0.0 and P.gear_cd[1] <= 0.0)
	var hp0 := T.hp
	var y0 := T.pos.y
	var rose := [false]
	P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
	P.inp["aim_y"] = T.pos.y
	P.inp["gear2"] = true
	_glove_run(m, 0.6, func(): if T.pos.y > y0 + 0.3: rose[0] = true)
	ok("combo: V's fissure right after the hook throws the hooked foe up and hurts it", rose[0] and T.hp < hp0,
			"hp %.0f -> %.0f, rose %s" % [hp0, T.hp, str(rose[0])])
	ok("combo: both gloves now cool down on their own clocks", P.gear_cd[0] > 0.0 and P.gear_cd[1] > 0.0
			and absf(P.gear_cd[0] - P.gear_cd[1]) > 0.2, "Q %.1f, V %.1f" % [P.gear_cd[0], P.gear_cd[1]])
	# a passive glove in the Q slot gives its stats and casts nothing; the active one on V still fires
	P.gear[0] = {"id": "focus", "rar": 2}
	P.gear[1] = {"id": "grapple", "rar": 1}
	P.gear_cd[0] = 0.0
	P.gear_cd[1] = 0.0
	P.refresh_gear()
	P.inp["gear1"] = true
	m.step(Match.DT)
	var q_quiet: bool = P.gear_cd[0] <= 0.0
	P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
	P.inp["gear2"] = true
	m.step(Match.DT)
	ok("a passive glove on Q casts nothing; the hook on V fires", q_quiet and P.gear_cd[1] > 0.0
			and P.gear_stat("cdr") > 0.0, "Q cd %.1f, V cd %.1f" % [P.gear_cd[0], P.gear_cd[1]])
	# two of the same glove can't be worn: a second hook replaces the first
	P.gear = Gear.empty_slots()
	m.spawn_gear("grapple", 1, P.pos, "", false)
	m.take_pick(P, m.wpicks[m.wpicks.size() - 1])
	m.spawn_gear("grapple", 3, P.pos, "", false)
	m.take_pick(P, m.wpicks[m.wpicks.size() - 1])
	ok("two of the same glove can't be worn: the better hook replaces the first",
			String(P.gear[0].get("id", "")) == "grapple" and int(P.gear[0]["rar"]) == 3
			and (P.gear[1] as Dictionary).is_empty(), str(P.gear))
	m.spawn_gear("quake", 1, P.pos, "", false)
	m.take_pick(P, m.wpicks[m.wpicks.size() - 1])
	ok("a different glove goes in the free slot (V)", String(P.gear[1].get("id", "")) == "quake", str(P.gear))
	m.queue_free()

func _glove_run(m: Match, secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs:
		if each.is_valid(): each.call()
		m.step(Match.DT)
		t += Match.DT
