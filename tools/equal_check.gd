extends RefCounted
## --equal-check (and --equal-migrate-check for the migration alone): equal footing in matches
## (docs/decisions/0005-equal-footing.md). Two saves with very different farms start a match with the
## same armor, perks and stats and differ only in the gloves, boots and utility they bring, within
## the difficulty tier's cap; the utility belt on 1/2/3 holds charges that are brought in, found and
## lost on death; armor levels up from damage to rival hunters; bots use their belt; the v5 to v6
## save migration converts armor and kit pieces with nothing silently deleted.
## Prints EQUAL ok/FAIL lines and "EQUAL DONE, failures: N". Never touches the save file.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("EQUAL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(host: Node, which := "all") -> void:
	main = host
	Save.no_write = true
	if which != "migrate":
		_keys()
		await _equal_base()
		await _belt()
		await _armor_levels()
		await _bots()
		await _gloves()
		_drops()
		await load("res://tools/equal_keys_check.gd").new().run(self)      # keys on the belt
	_migration()
	print("EQUAL DONE, failures: %d" % bad)
	host.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ helpers
func _farm(rich: bool) -> void:
	Save.d = Save.fresh()
	Econ.ensure()
	Save.d["tutorial"]["hatched"] = true
	Save.d["cls"] = "medium"
	var rec := Save.new_kin("cindle", "Pip", 77)
	Save.d["roster"] = [rec]
	Save.d["active"] = rec["uid"]
	if not rich:
		return
	# a rich farm: the workshop, the guild's projects, bought backpack levels, a full armory and stash
	Save.d["buildings"] += ["workshop", "armory"]
	Save.d["guild_perks"] = ["lighthouse", "forge", "hall"]
	Save.d["pack_lvl"] = 3
	Save.d["armory"] = [
		{"uid": "a1", "t": "gear", "id": "vest", "rar": 4},
		{"uid": "a2", "t": "gear", "id": "skylark_boots", "rar": 4},
		{"uid": "a3", "t": "gear", "id": "blink", "rar": 3},
		{"uid": "a4", "t": "gear", "id": "focus", "rar": 1}]
	Save.d["loadout"] = {"gear0": "a3", "gear1": "a4", "gear2": "a1", "gear3": "a2"}
	Save.d["items"]["tonic"] = 9
	Save.d["items"]["smoke"] = 3
	Save.d["items"]["scanner"] = 2
	Save.d["belt_pick"] = ["smoke", "tonic", "scanner"]

func _start(tier: int, seed := 9001) -> Match:
	var o := {"teams": 2, "squad": 1, "tier": tier, "length": 1e9, "seed": seed, "no_drop": true, "raid": "clear"}
	o["kit_items"] = Equal.take_loadout(tier)
	o["belt_items"] = Equal.take_belt(tier)
	var m := Match.new()
	main.add_child(m)
	m.start(o)
	m.set_process(false)
	return m

func _look(P: Hunter) -> Dictionary:
	return {"max_hp": P.max_hp, "max_armor": P.max_armor, "armor": P.armor, "base_armor": P.base_armor,
		"tier": P.armor_tier, "perks": P.perks.duplicate(),
		"glide": P.glide_max, "pack": P.pack_cap, "speed": P.base_speed,
		"armor_gear": (P.gear[2] as Dictionary).is_empty(), "dashes": P.max_dashes(),
		"hp": P.hp, "ult": P.ult, "skill": P.skill_pts}

func _drop(m: Match) -> void:
	m.queue_free()
	await main.get_tree().process_frame

# ------------------------------------------------------------------ keys
func _keys() -> void:
	for pair in [["util1", KEY_1], ["util2", KEY_2], ["util3", KEY_3], ["util4", KEY_4]]:
		var evs := InputMap.action_get_events(String(pair[0]))
		var code: int = pair[1]
		var on_key := evs.any(func(ev): return ev is InputEventKey and (ev as InputEventKey).physical_keycode == code)
		ok(on_key, "%s is on key %s" % [pair[0], OS.get_keycode_string(pair[1])])
	ok(not InputMap.has_action("tonic") and not InputMap.has_action("armor_kit"),
			"the old heal and armor-kit actions are gone")
	ok(UtilityBelt.KEYS == ["util1", "util2", "util3", "util4"] and Hunter.new().inp.has("util4")
			and not Hunter.new().inp.has("kit"), "hunters take util1..4 as inputs")

# ------------------------------------------------------------------ equal base
func _equal_base() -> void:
	var cap0 := Equal.rarity_cap(0)
	ok(Equal.rarity_cap(0) == 2 and Equal.rarity_cap(1) == 3 and Equal.rarity_cap(2) == 4,
			"rarity caps by tier: Rare, Epic, Legendary (%d, %d, %d)" % [Equal.rarity_cap(0), Equal.rarity_cap(1),
			Equal.rarity_cap(2)])
	for tier in [2, 0]:
		_farm(false)
		var m1 := _start(tier)
		var poor := _look(m1.player)
		var poor_gear: Array = m1.player.gear.duplicate(true)
		var poor_belt := _belt_ids(m1.player)
		await _drop(m1)
		_farm(true)
		var armory_before := Econ.armory().size()
		var m2 := _start(tier)
		var P := m2.player
		var rich := _look(P)
		var same := true
		for k in poor:
			if str(poor[k]) != str(rich[k]):
				same = false
				print("EQUAL   differs: %s  %s vs %s" % [k, str(poor[k]), str(rich[k])])
		ok(same, "tier %d: two very different farms start with identical armor, perks, health, pack and stats" % tier)
		ok(int(rich["pack"]) == Equal.base_pack() and int(rich["tier"]) == 0 and (rich["perks"] as Array).is_empty()
				and bool(rich["armor_gear"]),
				"tier %d: base pack %d, armor level 0, no perks, no armor piece" % [tier, Equal.base_pack()])
		var bare := poor_gear.all(func(g): return (g as Dictionary).is_empty())
		ok(bare and poor_belt == ["tonic", "armor_kit", "", ""],
				"tier %d: the poor farm brings nothing but the everyday issue (%s)" % [tier, str(poor_belt)])
		var worn: Array = P.gear.filter(func(g): return not (g as Dictionary).is_empty())
		var worn_text: Array = worn.map(func(g): return "%s r%d" % [g["id"], g["rar"]])
		ok(worn.all(func(g): return int(g["rar"]) <= Equal.rarity_cap(tier)),
				"tier %d: every brought piece is within the rarity cap (%s)" % [tier, str(worn_text)])
		ok((P.gear[2] as Dictionary).is_empty(), "tier %d: the armor in the loadout stayed home" % tier)
		if tier == 2:
			ok(String(P.gear[3].get("id", "")) == "skylark_boots" and int(P.gear[3]["rar"]) == 4
					and String(P.gear[0].get("id", "")) == "blink",
					"tier 2: Legendary boots and an Epic glove come (no cap)")
		else:
			ok((P.gear[3] as Dictionary).is_empty() and String(P.gear[0].get("id", "")) == "focus"
					and (P.gear[1] as Dictionary).is_empty(),
					"tier 0: boots and glove above Rare stay home, the Fine passive comes (on Q, the first glove slot)")
			ok(Econ.find("a2").size() > 0 and Econ.find("a3").size() > 0,
					"...and they are still in the armory, not lost")
		ok(armory_before - Econ.armory().size() == worn.size(),
				"what is brought leaves the armory (%d out)" % worn.size())
		var b := _belt_ids(P)
		ok(b[0] == "smoke" and b[1] == "tonic" and b[2] == "scanner",
				"tier %d: the belt is what was picked, in order (%s)" % [tier, str(b)])
		ok(P.tonics == UtilityBelt.bring_cap("tonic", tier)
				and UtilityBelt.count(P, "smoke") == UtilityBelt.bring_cap("smoke", tier)
				and UtilityBelt.count(P, "scanner") == UtilityBelt.bring_cap("scanner", tier),
				"tier %d: stack caps by tier (tonic %d, smoke %d, seeker %d)" % [tier, P.tonics,
				UtilityBelt.count(P, "smoke"), UtilityBelt.count(P, "scanner")])
		ok(int(Save.d["items"]["tonic"]) == 9 - (UtilityBelt.bring_cap("tonic", tier) - 2)
				and int(Save.d["items"]["smoke"]) == 3 - UtilityBelt.bring_cap("smoke", tier),
				"tier %d: what is brought leaves the stash" % tier)
		await _drop(m2)
	ok(cap0 == 2, "(the easiest tier caps at Rare)")
	# the backpack size comes from one place: base (content/rules) + the worn backpack + gear and perk "pack" stats
	ok(Equal.base_pack() == int(Equal.rules().get("base_pack", -1)) and Econ.pack_cap() == Equal.base_pack(),
			"the base backpack size is data (%d slots, content/rules/equal.json)" % Equal.base_pack())
	ok(Equal.pack_slots(PackStub.new(0.0)) == Equal.base_pack()
			and Equal.pack_slots(PackStub.new(1.0)) == Equal.base_pack() + 1,
			"pack_slots adds a +1 pack stat (the satchel perk) to the base")
	var packed := PackStub.new(1.0)
	packed.backpack = 2
	ok(Equal.pack_slots(packed) == Equal.base_pack() + Backpacks.slots(2) + 1,
			"...and the worn backpack's slots (a Pack and the perk: %d)" % Equal.pack_slots(packed))
	# the workshop and guild perks are gone from the match
	_farm(true)
	var m3 := _start(1)
	ok(is_equal_approx(m3.player.glide_max, GLIDE_BASE(m3.player)),
			"workshop, lighthouse and forge no longer change the glider or tonics (glide %.2f)" % m3.player.glide_max)
	await _drop(m3)

func GLIDE_BASE(P: Hunter) -> float:
	return Hunter.GLIDE_TIME * float(P.cdat.get("glide_cap", 1.0))

func _belt_ids(P: Hunter) -> Array:
	return P.belt.map(func(s): return String(s.get("id", "")))

# ------------------------------------------------------------------ the belt
func _belt() -> void:
	_farm(false)
	var m := _start(2, 9002)
	var P := m.player
	P.ctrl = "idle"
	for x in m.hunters:
		if x != P: x.ctrl = "idle"
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	ok(P.tonics == 3 and P.armor_kits == 2,
			"a hunter sets out with the issue (2 tonics, 2 kits) plus the 1 tonic in the stash (%d, %d)" % [P.tonics,
			P.armor_kits])
	# charges and caps
	var h := Hunter.new()
	h.belt = UtilityBelt.empty()
	ok(UtilityBelt.grant(h, "smoke", 2) == 2 and UtilityBelt.grant(h, "smoke", 5) == 1
			and UtilityBelt.count(h, "smoke") == 3, "grant stacks onto one slot up to its max (smoke 3)")
	ok(UtilityBelt.grant(h, "tonic", 1) == 1 and UtilityBelt.grant(h, "scanner", 1) == 1
			and UtilityBelt.grant(h, "medkit", 1) == 1 and UtilityBelt.grant(h, "stim", 1) == 0,
			"four slots hold four kinds; a fifth kind does not fit")
	ok(UtilityBelt.take(h, "smoke", 5) == 3 and h.belt[0].is_empty(), "an emptied slot frees up")
	h.free()
	# the belt keys with charges
	P.belt = UtilityBelt.empty()
	P.belt_free = {}
	UtilityBelt.grant(P, "tonic", 3)
	UtilityBelt.grant(P, "armor_kit", 2)
	UtilityBelt.grant(P, "smoke", 2)
	P.hp = P.max_hp * 0.5
	P.armor = 0.0
	P.inp["util3"] = true
	m.step(Match.DT)
	ok(UtilityBelt.count(P, "smoke") == 1 and m.smokes.size() == 1,
			"key 3 throws a smoke bomb: one charge spent, a cloud down")
	P.inp["util3"] = true
	m.step(Match.DT)
	ok(UtilityBelt.count(P, "smoke") == 1, "it has a short cooldown between uses")
	P.inv_t = 99.0
	P.inp["util1"] = true
	m.step(Match.DT)
	ok(P.drink_t > 0.0, "key 1 starts a drink")
	for i in int((Hunter.DRINK_TIME + 0.3) / Match.DT): m.step(Match.DT)
	ok(P.tonics == 2 and P.hp > P.max_hp * 0.85,
			"a finished drink spends one tonic and heals (%d left, hp %.0f/%.0f)" % [P.tonics, P.hp, P.max_hp])
	P.inp["util2"] = true
	m.step(Match.DT)
	ok(P.kit_t > 0.0, "key 2 starts an armor repair")
	P.inv_t = 0.0
	P.hurt(5.0, null, {"src": "shot"})
	ok(P.kit_t <= 0.0 and P.armor_kits == 2, "a hit spills it and nothing is spent")
	P.inv_t = 99.0
	P.inp["util2"] = true
	m.step(Match.DT)
	for i in int((Hunter.KIT_TIME + 0.3) / Match.DT): m.step(Match.DT)
	ok(P.armor_kits == 1 and P.armor >= P.max_armor - 0.5, "a finished repair spends one kit and fills armor")
	P.hp = P.max_hp
	P.inp["util1"] = true
	m.step(Match.DT)
	ok(P.drink_t <= 0.0 and P.tonics == 2, "a tonic at full health does nothing (the slot buzzes)")
	# the other items
	P.belt = UtilityBelt.empty()
	UtilityBelt.grant(P, "medkit", 2)
	UtilityBelt.grant(P, "stim", 1)
	UtilityBelt.grant(P, "shield_cell", 1)
	P.hp = P.max_hp * 0.4
	P.armor = 0.0
	UtilityBelt.use_id(P, "medkit")
	ok(P.hp >= P.max_hp * 0.4 + 39.0 and P.armor >= 19.0, "a mending kit heals 40 and mends 20 armor")
	UtilityBelt.use_id(P, "stim")
	ok(P.haste_t > 5.0, "a swift draught hastes you")
	UtilityBelt.use_id(P, "shield_cell")
	ok(P.shield > 30.0, "a shield cell gives a shield")
	P.belt = UtilityBelt.empty()
	UtilityBelt.grant(P, "jump_pad", 1)
	UtilityBelt.grant(P, "scanner", 1)
	var pads0 := m.gpads.size()
	UtilityBelt.use_id(P, "jump_pad")
	var foe: Hunter = m.hunters.filter(func(x): return x != P)[0]
	foe.reveal_t = 0.0
	foe.teleport(P.pos + Vector3(8, 0, 0))
	UtilityBelt.use_id(P, "scanner")
	ok(m.gpads.size() == pads0 + 1 and foe.reveal_t > 2.0,
			"a spring pad goes down and a seeker flare reveals rivals nearby")
	ok(UtilityBelt.count(P, "jump_pad") == 0 and UtilityBelt.count(P, "scanner") == 0,
			"single-charge items are used up")
	# found in the match: a pickup goes on the belt (and only if there is room)
	P.belt = UtilityBelt.empty()
	UtilityBelt.grant(P, "tonic", 5)
	UtilityBelt.grant(P, "armor_kit", 4)
	UtilityBelt.grant(P, "smoke", 3)
	UtilityBelt.grant(P, "medkit", 1)
	ok(not UtilityBelt.can_take(P, "scanner") and not UtilityBelt.can_take(P, "tonic")
			and UtilityBelt.can_take(P, "gem"),
			"a full belt cannot take another kind or more of a full stack (gems always can)")
	UtilityBelt.take(P, "smoke", 3)
	m.drop("scanner", P.pos + Vector3(0, 0.5, 0), 1)
	var pk: Dictionary = m.pickups[m.pickups.size() - 1]
	m._collect(P, pk)
	ok(UtilityBelt.count(P, "scanner") == 1, "found in the match: a dropped seeker flare goes on the belt")
	# lost on death: it goes in the deathbox, and the box gives it back
	var n0 := UtilityBelt.count(P, "tonic")
	P.lives = 1
	m.eliminate(P, null, "knocked out", true)
	var bx := Life.box_of(m, P)
	var in_box: bool = not bx.is_empty() \
			and (bx["belt"] as Array).any(func(st): return st["id"] == "tonic" and int(st["n"]) == n0)
	ok(in_box, "die and the whole belt is in your deathbox (%d tonics)" % n0)
	var bare_belt := P.belt.all(func(slot): return (slot as Dictionary).is_empty())
	ok(bare_belt and P.tonics == 0, "...and you have nothing left on you")
	var rows: Array = Life.box_items(m, foe, bx).filter(func(it): return it["key"] == "belt")
	ok(rows.size() == 4, "a looter sees it item by item (%d rows)" % rows.size())
	foe.belt = UtilityBelt.empty()
	foe.belt_free = {}
	Life.loot_box(m, foe, bx)
	ok(UtilityBelt.count(foe, "tonic") == 5 and UtilityBelt.count(foe, "scanner") == 1,
			"a rival who loots the box takes the charges")
	# coming home: only what is above the everyday issue
	var q := Hunter.new()
	q.belt = UtilityBelt.empty()
	q.belt_free = {}
	UtilityBelt.grant(q, "tonic", 2, true)
	UtilityBelt.grant(q, "tonic", 2)
	UtilityBelt.grant(q, "smoke", 1)
	ok(Equal.belt_home(q, true) == {"tonic": 2, "smoke": 1} and Equal.belt_home(q, false).is_empty(),
			"extracting brings the brought and found charges home, not the issue; dying brings none")
	q.free()
	Save.d["items"]["tonic"] = 4
	Equal.settle_belt({"belt": {"tonic": 2, "smoke": 1}})
	ok(int(Save.d["items"]["tonic"]) == 6 and int(Save.d["items"]["smoke"]) == 1, "...into the farm stash")
	await _drop(m)

# ------------------------------------------------------------------ armor levels
func _armor_levels() -> void:
	_farm(false)
	var m := _start(1, 9003)
	var P := m.player
	P.ctrl = "idle"
	var B: Hunter = m.hunters.filter(func(x): return x != P)[0]
	B.ctrl = "idle"
	B.max_hp = 9000.0
	B.hp = 9000.0
	B.armor = 0.0
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	ok(P.armor_tier == 0 and B.armor_tier == 0, "everyone starts at armor level 0")
	var base := P.max_armor
	B.hurt(100.0, P, {"src": "shot"})
	ok(P.armor_tier == 0 and P.armor_xp > 0.0, "damage to a rival fills your armor progress (%.0f xp)" % P.armor_xp)
	ok(not ArmorHud.tip(P).is_empty() and String(ArmorHud.tip(P)[2][0]).begins_with("Next"),
			"the HUD tip names the next level")
	for i in 3: B.hurt(100.0, P, {"src": "shot"})
	ok(P.armor_tier >= 1 and float(Hunter.ARMOR_TIERS[P.armor_tier][3]) > float(Hunter.ARMOR_TIERS[0][3]),
			"enough damage levels your armor up: a bigger reduction (plates %.0f -> %.0f)" % [base, P.max_armor])
	ok(is_equal_approx(P.max_armor, round(P.base_armor * float(Hunter.ARMOR_TIERS[P.armor_tier][4]))),
			"plates follow the tier's durability (docs/ARMOUR_PARITY.md)")
	ok(B.armor_xp > 0.0, "damage taken from a rival fills armor progress too (source)")
	var xp0 := P.armor_xp
	var mob: Mob = m.spawn_mob("skitter", P.pos + Vector3(3, 0, 0))
	mob.hurt(30.0, P, {"src": "shot"})
	ok(P.armor_xp - xp0 > 0.0 and P.armor_xp - xp0 < 30.0 * 0.5,
			"monsters count for a third (%.1f xp for 30 damage)" % (P.armor_xp - xp0))
	P.armor_gain(5000.0)
	ok(P.armor_tier == Hunter.ARMOR_TIERS.size() - 1 and ArmorHud.tip(P).size() == 3,
			"the top level is reachable and the HUD says so")
	ok(m.hud != null and ResourceLoader.exists("res://scripts/ui/armor_hud.gd"),
			"the HUD has the armor badge (ArmorHud)")
	await _drop(m)

# ------------------------------------------------------------------ bots
func _bots() -> void:
	_farm(false)
	var m := _start(1, 9004)
	var P := m.player
	P.ctrl = "idle"
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var B: Hunter = m.hunters.filter(func(x): return x != P)[0]
	B.belt = UtilityBelt.empty()
	B.belt_free = {}
	UtilityBelt.grant(B, "tonic", 2)
	UtilityBelt.grant(B, "armor_kit", 2)
	UtilityBelt.grant(B, "smoke", 1)
	B.hp = B.max_hp * 0.3
	B.armor = B.max_armor
	var inp := {}
	BotBelt.think(m, B, B.ai, inp)
	ok(inp.get("util1", false), "a hurt bot reaches for its tonic (slot 1)")
	inp = {}
	B.hp = B.max_hp
	B.armor = 0.0
	BotBelt.think(m, B, B.ai, inp)
	ok(inp.get("util2", false), "a bot with broken armor and nobody close reaches for an armor kit (slot 2)")
	inp = {}
	B.armor = B.max_armor
	B.hp = B.max_hp * 0.3
	B.ai["tgt"] = P
	P.teleport(B.pos + Vector3(5, 0, 0))
	UtilityBelt.take(B, "tonic", 2)
	BotBelt.think(m, B, B.ai, inp)
	ok(inp.get("util3", false), "hurt with a rival close and no tonic, a bot throws smoke (slot 3)")
	# and for real: a hurt bot, left alone, drinks within a few seconds of play
	B.ai.erase("tgt")
	P.teleport(B.pos + Vector3(60, 0, 0))
	UtilityBelt.grant(B, "tonic", 2)
	B.hp = B.max_hp * 0.3
	var t0 := UtilityBelt.count(B, "tonic")
	var used := false
	for i in 400:
		m.step(Match.DT)
		if UtilityBelt.count(B, "tonic") < t0 or B.drink_t > 0.0:
			used = true
			break
	ok(used, "in play, a hurt bot drinks a tonic by itself (%d steps)" % [400])
	# what bots start with: no armor, a spare utility item on harder settings
	var armor_any := false
	var spare := 0
	for i in 40:
		var bb := Hunter.new()
		var r := RandomNumberGenerator.new()
		r.seed = i
		GearDrops.bot_start(bb, r, "hard")
		if not (bb.gear[2] as Dictionary).is_empty(): armor_any = true
		for sl in bb.belt:
			if not (sl as Dictionary).is_empty():
				spare += 1
				break
		bb.free()
	ok(not armor_any and spare == 40, "bots start without armor, with a spare utility item on hard (%d of 40)" % spare)
	await _drop(m)

# ------------------------------------------------------------------ two gloves (Q, V)
func _gloves() -> void:
	_farm(false)
	var m := _start(1, 9005)
	var P := m.player
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var B: Hunter = m.hunters.filter(func(x): return x != P)[0]
	B.ctrl = "idle"
	# skill points: never on a glove
	ok(not Hunter.SLOTS.has("gear") and not Hunter.SLOT_MAX.has("gear") and not P.slot_lv.has("gear"),
			"gloves are not a ranked slot (%s)" % str(Hunter.SLOTS))
	var pts := P.skill_pts
	ok(not P.can_level("gear") and not P.level_slot("gear") and P.skill_pts == pts,
			"no skill point can be spent on a glove")
	# a worn glove casts at once: level 1, no point spent, on either key
	ok(P.lvl == 1 and P.slot_lv.values().all(func(v): return int(v) == 0), "a fresh hunter: level 1, nothing ranked")
	P.gear[0] = {"id": "grapple", "rar": 1}
	P.gear[1] = {"id": "quake", "rar": 1}
	P.gear_cd[0] = 0.0
	P.gear_cd[1] = 0.0
	P.inp["aim"] = B.pos + Vector3(0, 0.9, 0)
	P.inp["gear1"] = true
	m.step(Match.DT)
	ok(P.gear_cd[0] > 0.0 and P.skill_pts == pts,
			"a worn glove casts on Q at level 1 with no point spent (cd %.1f)" % P.gear_cd[0])
	P.inp["gear2"] = true
	m.step(Match.DT)
	ok(P.gear_cd[1] > 0.0 and P.skill_pts == pts, "the second glove casts on V (cd %.1f)" % P.gear_cd[1])
	ok(absf(P.gear_cd[0] - Gear.cd_of("grapple", 1)) < 0.1, "its cooldown is the glove's own: no rank shortens it")
	var evs := InputMap.action_get_events("gear2")
	var on_v := evs.any(func(ev): return ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_V)
	ok(on_v and Settings.conflicts(evs[0], "gear2").is_empty(), "glove 2 is on V, shared on purpose with play at home")
	# bots: points go to the hero's own abilities only
	B.skill_pts = 8
	B.lvl = 9
	B._bot_spend()
	ok(B.skill_pts < 8 and not B.slot_lv.has("gear"),
			"a bot spends its points on its hero's abilities (%s)" % str(B.slot_lv))
	# the HUD: both gloves and the Boki's Merge box sit on the right (GripHud), not on the left bar
	m.hud.c.queue_redraw()
	for i in 3: await main.get_tree().process_frame
	var sz: Vector2 = m.hud.c.size
	var spots: Array = m.hud.hover_spots.filter(func(hs): return String(hs[1]) in ["gear0", "gear1"])
	var spot_at: Array = spots.map(func(hs): return (hs[0] as Rect2).position)
	var right := spots.all(func(hs): return (hs[0] as Rect2).position.x > sz.x * 0.5)
	ok(spots.size() == 2 and right, "the HUD's two glove boxes sit on the right (%s)" % str(spot_at))
	var merge_right := false
	for hs in m.hud.hover_spots:
		if String(hs[1]) == "r" and (hs[0] as Rect2).position.x > sz.x * 0.5:
			merge_right = true
	ok(P.kin == null or merge_right, "the Boki box beside them is the Merge's (its key and tip: \"ultimate\")")
	ok(not P.slot_info("gear1").is_empty()
			and String(P.slot_info("gear1")["name"]) == String(Gear.ALL["quake"]["name"]),
			"the V glove has its own slot info")
	# overhead: two gloves and the Boki type, read from the net snapshot for a remote hunter
	B.gear[0] = {"id": "blink", "rar": 4}
	B.gear[1] = {"id": "barrier", "rar": 1}
	B.gear_cd[0] = 0.0
	B.gear_cd[1] = 7.0
	B.ult = 1.0
	var R: Hunter = m.make_hunter("R9", 3, "medium", "Remote", "remote", {}, P.pos + Vector3(5, 0, 0))
	R.remote = true
	var snap: Array = m._ser(B)
	snap[1] = R.nid
	m._net_apply(R, snap)
	var row := GripOverhead.row(R)
	ok(String(row[0]["id"]) == "blink" and String(row[1]["id"]) == "barrier"
			and row[0]["col"] == Data.RARITY[4]["color"],
			"a remote hunter's two gloves come over the net with their rarity (%s, %s)" % [row[0]["id"], row[1]["id"]])
	ok(not row[0]["dim"] and row[1]["dim"] and R.ult >= 1.0,
			"the glove on cooldown is dimmed, the ready one is not; the full bond comes too")
	var kb: Kin = P.kin
	if kb != null:
		R.kin = kb
		var rk := GripOverhead.row(R)
		ok(String(rk[2]["id"]) == DexView.type_of(kb.species) and rk[2]["glow"],
				"the third icon is the Boki's type, glowing on a full bond (%s)" % String(rk[2]["id"]))
		R.kin = null
	var cs := GripOverhead.centres(Vector2(400, 300))
	var under := cs.all(func(c): return (c as Vector2).y >= 300.0 + HudStyle.PLATE_ICON_ROW)
	ok(cs.size() == 3 and under, "the three icons sit in the row HudStyle leaves under the nameplate")
	# bots wear two different active gloves and use both
	var two := 0
	for i in 20:
		var bb := Hunter.new()
		var rg := RandomNumberGenerator.new()
		rg.seed = 100 + i
		GearDrops.bot_start(bb, rg, "hard")
		var g0: Dictionary = bb.gear[0]
		var g1: Dictionary = bb.gear[1]
		if not g0.is_empty() and not g1.is_empty() and g0["id"] != g1["id"] and Gear.active(String(g0["id"])) \
				and Gear.active(String(g1["id"])): two += 1
		bb.free()
	ok(two >= 18, "a hard bot starts with two different active gloves (%d of 20)" % two)
	# a bot's glove choice, both slots: each fires on its own key when its moment comes (Bot passes
	# its real aim here; the stub says "now" so terrain and line of sight stay out of the test)
	B.gear[0] = {"id": "grapple", "rar": 2}
	B.gear[1] = {"id": "quake", "rar": 2}
	B.gear_cd[0] = 0.0
	B.gear_cd[1] = 0.0
	var used := [false, false]
	for i in 200:
		var bot_inp := {}
		Gloves.bot_use(B, P, 1.0, bot_inp, func(_gdf, tgt): return tgt.pos)
		for gi in 2:
			if bot_inp.get(Gloves.KEYS[gi], false):
				used[gi] = true
				B.gear_cd[gi] = 5.0
		if used[0] and used[1]:
			break
	ok(used[0] and used[1], "a bot uses both gloves, each on its own key (Q %s, V %s)" % [str(used[0]), str(used[1])])
	await _drop(m)

# ------------------------------------------------------------------ drops
func _drops() -> void:
	ok(UtilityDrops.chance("boss") > 0.5 and UtilityDrops.chance("ground") == 0.0
			and UtilityDrops.chance("nonsense") == UtilityDrops.chance("_default"),
			"drop odds come from content/rules/equal.json (boss %.2f)" % UtilityDrops.chance("boss"))
	var util_ids := UtilityBelt.ids()
	var described := util_ids.all(func(id): return UtilityBelt.def(id).has("desc") and UtilityBelt.max_of(id) >= 1)
	ok(UtilityBelt.ids().size() >= 8 and described,
			"%d utility items, each with a description and a stack size" % UtilityBelt.ids().size())
	for id in ["smoke", "jump_pad", "scanner", "medkit"]:
		ok(UtilityBelt.is_item(id) and not Gear.ALL.has(id), "%s moved from gloves to utility items" % id)
	for id in ["field_kit", "magpie", "satchel", "spyglass", "tinker_roll"]:
		ok(not Gear.ALL.has(id), "%s left the gear slots (it comes back as a perk)" % id)
	ok(Gear.SLOTS.size() == 4 and not Gear.SLOTS.has("kit"), "the kit gear slot is gone: %s" % str(Gear.SLOTS))

# ------------------------------------------------------------------ the migration
func _migration() -> void:
	var d := Save.fresh()
	d["v"] = 5
	d["gems"] = 60
	d["pack_lvl"] = 2
	d["armory"] = [
		{"uid": "u1", "t": "gear", "id": "vest", "rar": 2},
		{"uid": "u2", "t": "gear", "id": "magpie", "rar": 1},
		{"uid": "u3", "t": "gear", "id": "bastion_plate", "rar": 4},
		{"uid": "u4", "t": "gear", "id": "smoke", "rar": 3},
		{"uid": "u5", "t": "gear", "id": "blink", "rar": 3},
		{"uid": "u6", "t": "gear", "id": "skylark_boots", "rar": 4},
		{"uid": "u7", "t": "val", "id": "old_coin"},
		{"uid": "u9", "t": "gear", "id": "focus", "rar": 1}]
	d["raid_out"] = [{"uid": "u8", "t": "gear", "id": "satchel", "rar": 0}]
	d["loadout"] = {"gear2": "u1", "gear3": "u6", "gear4": "u2", "gear0": "u5", "gear1": "u9"}
	d["items"]["tonic"] = 4
	var before_n := (d["armory"] as Array).size() + (d["raid_out"] as Array).size()
	ok(Save.VERSION >= 7, "the save version is 7 or later (Hunter unlocks are v6, the market v8)")
	ok(Save.migrate(d) and int(d["v"]) == Save.VERSION, "a v5 save upgrades to v%d" % Save.VERSION)
	var ids: Array = (d["armory"] as Array).map(func(it): return String(it.get("id", "")))
	ok(ids.has("blink") and ids.has("skylark_boots") and ids.has("old_coin"),
			"gloves, boots and treasure stay (%s)" % str(ids))
	ok(not ids.has("vest") and not ids.has("magpie") and not ids.has("bastion_plate") and not ids.has("smoke")
			and (d["raid_out"] as Array).is_empty(), "armor, kit and utility-glove pieces leave the armory")
	# the rate: full item value in gems + the extraction materials of its rarity
	# vest r2 (18 gems, 1 wood 1 stone), magpie r1 (8, 1 wood), bastion r4 (70, 3 stone 3 scrap), satchel r0 (3, 1
	# wood); backpack level 2 becomes a Pack, level 1 refunded (120 gems, 4 scrap)
	var gems_want := 60 + 18 + 8 + 70 + 3 + 120
	ok(int(d["gems"]) == gems_want,
			"gems: %d (want %d: item value at 100%% plus the smaller backpack level)" % [int(d["gems"]), gems_want])
	var mats: Dictionary = d.get("mats", {})
	ok(int(mats.get("wood", 0)) == 3 and int(mats.get("stone", 0)) == 4,
			"materials: %d wood, %d stone (want 3, 4)" % [int(mats.get("wood", 0)), int(mats.get("stone", 0))])
	ok(int(d["scrap"]) == 3 + 4, "scrap: %d (want 7: 3 from the plate, 4 refunded)" % int(d["scrap"]))
	ok(d["backpacks"] == [0, 0, 1, 0] and int(d["pack_pick"]) == 2,
			"backpack level 2 is now one Pack in the stash, picked (%s)" % str(d["backpacks"]))
	ok(int(d["items"].get("smoke", 0)) == 3 and int(d["items"]["tonic"]) == 4,
			"the smoke glove became 3 smoke bombs in the stash")
	ok(not d.has("pack_lvl") and d["loadout"] == {"gear3": "u6", "gear0": "u5"},
			"the old backpack level is gone (now a backpack) and the loadout keeps only gloves and boots")
	ok(not d["loadout"].has("gear1") and ids.has("focus"),
			"the second glove slot (V) starts empty; the old passive glove stays in the armory")
	var lines: Array = d.get("equal_notice", [])
	var text := " ".join(lines.map(func(l): return String(l)))
	ok(not lines.is_empty() and text.contains("Brace Plate") and text.contains("Bastion") and text.contains("Magpie")
			and text.contains("Smoke Glove") and text.contains("refunded") and text.contains("second glove slot on V"),
			"the notice lists what converted (%d lines)" % lines.size())
	ok(before_n - (d["armory"] as Array).size() - (d["raid_out"] as Array).size() == 5,
			"five pieces converted, none deleted without a line in the notice")
	# a clean old save gets no notice and still upgrades
	var d2 := Save.fresh()
	d2["v"] = 5
	ok(Save.migrate(d2) and (d2["equal_notice"] as Array).is_empty() and (d2["armory"] as Array).is_empty(),
			"a save with nothing to convert upgrades quietly")
	# the notice shows once
	var keep := Save.d
	Save.d = d
	var first := EqualMigrate.take_notice()
	var second := EqualMigrate.take_notice()
	Save.d = keep
	ok(not first.is_empty() and second.is_empty(), "the notice is shown once, then it is gone")
	# armor extracted later salvages instead of piling up in the armory
	Save.d = Save.fresh()
	Econ.ensure()
	var g0 := int(Save.d["gems"])
	var out := {}
	Econ.after_raid({"extracted": true,
			"haul": [{"t": "gear", "id": "vest", "rar": 3, "uid": "z1"},
			{"t": "gear", "id": "blink", "rar": 1, "uid": "z2"}]}, out)
	ok(Econ.armory().size() == 1 and int(Save.d["gems"]) == g0 + 36 and int(out.get("salvage_gems", 0)) == 36,
			"armor found in a match salvages for gems on arrival (+36), the glove is stored")
	Save.d = Save.fresh()

## A stand-in hunter for Equal.pack_slots: only its "pack" stat matters (a perk's stats count there).
class PackStub extends RefCounted:
	var pack := 0.0
	var backpack := 0
	func _init(p: float) -> void:
		pack = p
	func gear_stat(k: String) -> float:
		return pack if k == "pack" else 0.0
