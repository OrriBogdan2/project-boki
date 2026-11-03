extends RefCounted
## --backpack-check: backpack tiers (Backpacks, docs/decisions/0005-equal-footing.md). The Pouch is
## free; a Satchel, Pack or Rucksack is bought at home, brought in (capped by difficulty) and at risk:
## death puts it in the deathbox, a revived hunter is on the Pouch, a rival takes a bigger one from
## the box (leaving theirs), a shop sells the next tier, nothing drops one at random, and an extracted
## backpack comes home. The size always goes through Equal.pack_slots. Never touches the save file.
## Prints PACKS ok/FAIL lines and "PACKS DONE, failures: N".

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("PACKS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(host: Node) -> void:
	main = host
	Save.no_write = true
	_data()
	_home()
	await _match()
	print("PACKS DONE, failures: %d" % bad)
	host.get_tree().quit(1 if bad > 0 else 0)

func _fresh() -> void:
	Save.d = Save.fresh()
	Econ.ensure()
	Save.d["tutorial"]["hatched"] = true
	Save.d["cls"] = "medium"
	var rec := Save.new_kin("cindle", "Pip", 77)
	Save.d["roster"] = [rec]
	Save.d["active"] = rec["uid"]

# ------------------------------------------------------------------ data
func _data() -> void:
	var names: Array = Backpacks.tiers().map(func(t): return String(t["name"]))
	ok(names == ["Pouch", "Satchel", "Pack", "Rucksack"], "four tiers: %s" % str(names))
	var grows := true
	for tier in range(1, Backpacks.tiers().size()):
		grows = grows and Backpacks.slots(tier) > Backpacks.slots(tier - 1)
	ok(Backpacks.slots(0) == 0 and grows, "the Pouch adds nothing, each tier adds more")
	ok(Backpacks.cap(0) == 1 and Backpacks.cap(1) == 2 and Backpacks.cap(2) == 3,
			"the biggest you may bring: Satchel, Pack, Rucksack by difficulty")
	var gear_text := FileAccess.get_file_as_string("res://content/rules/gear.json")
	ok(not gear_text.to_lower().contains("backpack") and not gear_text.contains("rucksack"),
			"no drop table holds a backpack (no random backpack drops)")

# ------------------------------------------------------------------ home
func _home() -> void:
	_fresh()
	ok(Backpacks.pick(2) == Backpacks.POUCH and Backpacks.take_home(2) == Backpacks.POUCH,
			"a new farm brings the Pouch")
	Backpacks.settle({"backpack": 0})
	Save.d["gems"] = 1000
	Save.d["scrap"] = 50
	var cost := Backpacks.price(3)
	ok(Backpacks.buy(3) == "" and Backpacks.owned(3) == 1 and int(Save.d["gems"]) == 1000 - cost[0]
			and int(Save.d["scrap"]) == 50 - cost[1],
			"buy a Rucksack at the armory for gems and scrap (%s)" % str(cost))
	ok(Backpacks.buy(1) == "" and Backpacks.owned(1) == 1, "and a Satchel")
	Save.d["gems"] = 0
	ok(Backpacks.buy(2) == "Not enough gems", "no gems, no Pack")
	Backpacks.set_pick(3)
	ok(Backpacks.pick(0) == 1 and Backpacks.pick(2) == 3,
			"the Rucksack is picked; the easiest difficulty takes the biggest allowed one you own (Satchel)")
	var tier := Backpacks.take_home(2)
	ok(tier == 3 and Backpacks.owned(3) == 0 and int(Save.d["raid_pack"]) == 3, "setting out takes it from the stash")
	Backpacks.recover()
	ok(Backpacks.owned(3) == 1 and int(Save.d["raid_pack"]) == 0, "a match that never ended puts it back")
	Backpacks.take_home(2)
	Backpacks.settle({"backpack": 0})
	ok(Backpacks.owned(3) == 0, "die with it and it is gone")
	Backpacks.take_home(0)
	Backpacks.settle({"backpack": 2})
	ok(Backpacks.owned(1) == 0 and Backpacks.owned(2) == 1, "extract wearing a rival's Pack: the Pack comes home")

# ------------------------------------------------------------------ the match
func _match() -> void:
	_fresh()
	var o := {"teams": 2, "squad": 1, "tier": 2, "length": 1e9, "seed": 4242, "no_drop": true, "raid": "clear",
		"backpack": 2}
	var m := Match.new()
	main.add_child(m)
	m.start(o)
	m.set_process(false)
	var P := m.player
	var base := Equal.base_pack()
	ok(P.backpack == 2 and P.pack_cap == base + Backpacks.slots(2) and P.pack_cap == Equal.pack_slots(P),
			"a brought Pack: %d slots (Equal.pack_slots)" % P.pack_cap)
	var foe: Hunter = m.hunters.filter(func(x): return x != P)[0]
	Backpacks.wear(foe, 1)
	ok(foe.pack_cap == base + Backpacks.slots(1), "a Satchel on a rival: %d slots" % foe.pack_cap)
	# the shop: the next tier for run gems, the old one traded in
	var price := Backpacks.shop_price(P)
	P.gems = price
	ok(price > 0 and Backpacks.shop_upgrade(P) and P.backpack == 3 and P.gems == 0
			and P.pack_cap == base + Backpacks.slots(3), "a shop upgrade to the Rucksack for %d gems" % price)
	ok(Backpacks.shop_price(P) == -1 and not Backpacks.shop_upgrade(P), "nothing above the Rucksack")
	# death: it goes in the box
	P.pack = [Loot.valuable("old_coin")]
	P.lives = 1
	m.eliminate(P, null, "knocked out", true)
	var bx := Life.box_of(m, P)
	ok(not bx.is_empty() and int(bx.get("backpack", 0)) == 3, "die and your backpack is in your deathbox")
	ok(P.backpack == Backpacks.POUCH and P.pack_cap == base, "...and you are on the Pouch (%d slots)" % P.pack_cap)
	Life.bring_back(m, P, P.pos, 0.5, false)
	ok(P.backpack == Backpacks.POUCH and P.pack_cap == base, "revived: still the Pouch")
	# a rival sees it, takes it, and leaves theirs
	var rows: Array = Life.box_items(m, foe, bx).filter(func(it): return it["key"] == "backpack")
	ok(rows.size() == 1 and bool(rows[0]["upgrade"]), "a looter sees the Rucksack as an upgrade")
	Life.take_item(m, foe, bx, rows[0])
	ok(foe.backpack == 3 and int(bx["backpack"]) == 1 and foe.pack_cap == base + Backpacks.slots(3),
			"taken: the rival wears the Rucksack, their Satchel is in the box")
	ok(not Backpacks.take_from_box(m, foe, bx) and foe.backpack == 3, "a smaller one is never swapped in")
	# smart loot and take-all take a bigger one too
	Life.smart_loot(m, P, bx)
	ok(P.backpack == 1 and int(bx.get("backpack", 0)) == 0, "smart loot takes the Satchel back from the box")
	var bx2 := {"owner": foe, "team": foe.team, "pos": P.pos, "gems": 0, "seeds": {}, "caught": [], "belt": [],
		"soul_until": 0.0, "prog": {}, "node": null, "empty": false, "gear": [], "pack": [], "keys": 0, "backpack": 2}
	Life.loot_box(m, P, bx2)
	ok(P.backpack == 2 and int(bx2["backpack"]) == 1 and not bool(bx2["empty"]), "taking everything swaps in a Pack")
	# extraction and the result
	ok(Backpacks.home_tier(P, true) == 2 and Backpacks.home_tier(P, false) == 0,
			"the result carries the backpack home only when you extract")
	# bots: on harder settings some set out with a bigger one
	var big := 0
	for i in 40:
		var b := Hunter.new()
		b.m = m
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + i
		Backpacks.bot_start(b, rng, "expert")
		if b.backpack > 0:
			big += 1
		b.free()
	ok(big > 5 and big < 40, "expert bots: %d of 40 set out with a bigger backpack" % big)
	m.queue_free()
	await main.get_tree().process_frame
