extends RefCounted
## Part of --equal-check: chest keys on the utility belt (BeltKeys). They take one belt slot and
## stack in it up to the cap; a full belt leaves the key on the ground and offers a swap (nothing is
## thrown away); the key's slot opens a chest beside you or pings the nearest one; keys go in the
## deathbox, are never brought in, sold or taken home; bots make room for a key; a v5 save's market
## Rift Keys (gone with open extraction) come back as gems.

var eq

func ok(cond: bool, what: String) -> void:
	eq.ok(cond, "keys: " + what)

func run(check) -> void:
	eq = check
	_data()
	await _match()
	_migration()

func _data() -> void:
	ok(UtilityBelt.is_key("chest_key") and not UtilityBelt.is_key("rift_key") and not UtilityBelt.is_key("tonic"),
			"chest keys are belt items (Rift Keys are gone)")
	ok(UtilityBelt.max_of("chest_key") == 3, "stack cap from data: chest keys 3")
	var caps_zero := true
	for tier in Data.TIERS.size():
		caps_zero = caps_zero and UtilityBelt.bring_cap("chest_key", tier) == 0
	ok(caps_zero, "keys can't be brought in at any difficulty")
	var deeper := true
	for tier in Data.TIERS.size():
		var td: Dictionary = Data.TIERS[tier]
		deeper = deeper and int(td["depth"]) == tier + 1
		if tier > 0:
			deeper = deeper and td["mob"] > Data.TIERS[tier - 1]["mob"] and td["loot"] > Data.TIERS[tier - 1]["loot"]
	ok(deeper, "each tier is one depth deeper, with tougher monsters and richer loot")
	ok(not UtilityBelt.stock_ids().has("chest_key") and not HomeBelt.choices().has("chest_key"),
			"keys are not sold or picked at home")

func _match() -> void:
	eq._farm(false)
	var m: Match = eq._start(1, 7070)
	var P := m.player
	# picked up: the count is the truth, the belt shows it in a slot
	P.belt = UtilityBelt.empty()
	P.belt_free = {}
	m.drop("ckey", P.pos + Vector3(0, 0.5, 0), 1)
	m._collect(P, m.pickups[m.pickups.size() - 1])
	KeyChest.give(P, 1)
	BeltKeys.sync(P)
	var ck := UtilityBelt.slot_of(P, "chest_key")
	ok(P.chest_keys == 2 and ck >= 0 and int(P.belt[ck]["n"]) == 2, "chest keys stack in one slot with the count (2)")
	ok(UtilityBelt.max_of("chest_key") == KeyChest.cap(), "the chest key cap is KeyChest.cap() (%d)" % KeyChest.cap())
	# a full belt: the key stays on the ground and a slot press swaps
	P.chest_keys = 0
	BeltKeys.sync(P)
	ok(UtilityBelt.slot_of(P, "chest_key") < 0, "no keys, no key slot")
	UtilityBelt.grant(P, "tonic", 2)
	UtilityBelt.grant(P, "smoke", 1)
	UtilityBelt.grant(P, "scanner", 1)
	UtilityBelt.grant(P, "medkit", 1)
	UtilityBelt.grant(P, "stim", 1)      # (the four open slots: smoke, scanner, medkit, stim)
	m.drop("ckey", P.pos + Vector3(0, 0.3, 0), 1, "", "", Vector3.ZERO)
	var key_p: Dictionary = m.pickups[m.pickups.size() - 1]
	key_p["t"] = 1.0
	ok(not UtilityBelt.can_take(P, "ckey") and BeltKeys.blocked_pickup(P) == key_p,
			"belt full: the key can't be picked up and waits on the ground")
	var smoke_slot := UtilityBelt.slot_of(P, "smoke")
	var n_pick := m.pickups.size()
	UtilityBelt.press(P, smoke_slot)
	BeltKeys.sync(P)
	var dropped: Dictionary = m.pickups[m.pickups.size() - 1]
	ok(P.chest_keys == 1 and UtilityBelt.count(P, "smoke") == 0 and String(dropped["kind"]) == "smoke"
			and int(dropped["v"]) == 1 and m.pickups.size() == n_pick and UtilityBelt.slot_of(P, "chest_key") >= 0,
			"pressing a slot swaps it: the smoke bomb is on the ground, the key on the belt")
	KeyChest.give(P, 1)
	BeltKeys.sync(P)
	# a locked chest: far, a ping; beside it, it opens and costs one key
	var chests: Array = m.chests.filter(func(c): return not c["open"] and not bool(c.get("free", false)))
	if chests.is_empty():
		ok(false, "the test map has a locked chest")
	else:
		var c: Dictionary = chests[0]
		P.teleport(c["pos"] + Vector3(15, 0, 0))
		var pings1 := m.pings.size()
		UtilityBelt.press(P, UtilityBelt.slot_of(P, "chest_key"))
		P.teleport(c["pos"] + Vector3(0.8, 0, 0))
		UtilityBelt.press(P, UtilityBelt.slot_of(P, "chest_key"))
		ok(m.pings.size() == pings1 + 1 and bool(c["open"]) and P.chest_keys == 1,
				"chest key: ping when far, open when beside it (one key spent)")
	# never taken home, always in the deathbox
	ok(not UtilityBelt.keepers(P).has("chest_key"), "keys never come home with you")
	P.lives = 1
	m.eliminate(P, null, "knocked out", true)
	var bx := Life.box_of(m, P)
	ok(int(bx.get("chest_keys", 0)) == 1 and P.chest_keys == 0, "die and the keys are in your deathbox")
	# a bot with a full belt makes room for a key (its cheapest stack, never a key)
	var bot: Hunter = m.hunters.filter(func(x): return x != P and x.ctrl == "bot")[0]
	bot.belt = UtilityBelt.empty()
	bot.belt_free = {}
	bot.chest_keys = 1
	for id in ["tonic", "armor_kit", "smoke", "medkit", "stim"]:
		UtilityBelt.grant(bot, id, 1)
	BeltKeys.sync(bot)
	m.drop("ckey", bot.pos + Vector3(0, 0.3, 0), 1, "", "", Vector3.ZERO)
	m.pickups[m.pickups.size() - 1]["t"] = 1.0
	BeltKeys.tick(m)
	ok(bot.chest_keys == 1, "a bot with a full belt drops its cheapest stack for a key")
	await eq._drop(m)

func _migration() -> void:
	var d := Save.fresh()
	d["v"] = 5
	d["items"] = {"rift_key": 2}
	var gems0 := int(d.get("gems", 0))
	EqualMigrate.migrate(d)
	ok(not (d["items"] as Dictionary).has("rift_key") and int(d["gems"]) == gems0 + 2 * EqualMigrate.RIFT_KEY_PRICE,
			"market Rift Keys in an old stash come back as gems (%d)" % (int(d["gems"]) - gems0))
