extends RefCounted
## --region-shops-check: the shops are a per-region system (content/maps/hollowcrown.json regions[].shops,
## Shops.spot). Every region has 1-2 vendors (the Crown at most one, a premium one); every vendor stands
## on its own region's open ground with a stock nobody else sells; stocks fit their region (Frostgate
## armor, Cinder gloves and weapon tunings, a hazard ward perk where that hazard is); a spot a re-drawn
## layout leaves off the ground moves to the nearest open tile of the region; the ward perks keep their
## hazard off; vendors show on the minimap and the legend fits a 720p map; rich bots buy upgrades.
## Prints REGION SHOPS PASS/FAIL.

var main: Node
var fails := 0
var n := 0

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("REGION SHOPS %-62s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 3, "squad": 1, "tier": 0, "seed": 21, "no_drop": true})
	m.set_process(false)
	_regions(m)
	_fit(m)
	_snap(m)
	_wards(m)
	_maps(m)
	_bots(m)
	print("REGION SHOPS DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _vendor(m: Match, theme: String) -> Dictionary:
	for v in Shops.list(m):
		if v["theme"] == theme:
			return v
	return {}

func _region(m: Match, id: String) -> Dictionary:
	for reg in m.world.regions:
		if reg["id"] == id:
			return reg
	return {}

func _sells(theme: String, pred: Callable) -> bool:
	return (ShopStock.theme(theme).get("sells", []) as Array).any(pred)

# ------------------------------------------------------------------ regions and spots

func _regions(m: Match) -> void:
	var counts_ok := true
	var known := true
	var seen := {}
	var unique := true
	for reg in m.world.regions:
		var shops: Array = reg.get("shops", [])
		var lo := 0 if reg["id"] == "crown" else 1
		if shops.size() < lo or shops.size() > (1 if reg["id"] == "crown" else 2):
			counts_ok = false
		for sp in shops:
			known = known and not ShopStock.theme(String(sp[2])).is_empty()
			unique = unique and not seen.has(sp[2])
			seen[sp[2]] = true
	ok("every region has 1-2 shops, the Crown at most one", counts_ok and m.world.regions.size() >= 9)
	ok("every listed stock is in shops.json and used once", known and unique, str(seen.keys()))
	var home := true
	var bad: Array = []
	for v in Shops.list(m):
		var x := int(floor(v["pos"].x))
		var z := int(floor(v["pos"].z))
		var i := m.world.idx(x, z)
		var isle := String(m.world.islands[m.world.island[i]].get("id", "")) if m.world.island[i] >= 0 else ""
		if not (_region(m, v["region"])["islands"] as Array).has(isle) or m.world.kind[i] != World.T_GROUND:
			home = false
			bad.append(v["theme"])
	ok("every vendor stands on its own region's open ground", home, str(bad))
	ok("every region's shops stand (none lost to a bad spot)", Shops.list(m).size() == seen.size())

func _fit(m: Match) -> void:
	var gear_slot := func(slot: int) -> Callable:
		return func(e): return String(e).begins_with("gear:") and Gear.slot_of(String(e).get_slice(":", 1)) == slot
	var wup := func(e): return String(e).begins_with("perk:") and Data.PERKS[String(e).get_slice(":", 1)].has("wup")
	var frost := String(_region(m, "frostgate")["shops"][0][2])
	var up := func(e): return e == "armor_up"
	ok("Frostgate sells armor pieces and armor upgrades", _sells(frost, gear_slot.call(2)) and _sells(frost, up))
	var cinder: Array = (_region(m, "cinder")["shops"] as Array).map(func(sp): return String(sp[2]))
	var gloves := cinder.any(func(t): return _sells(t, gear_slot.call(0)) or _sells(t, gear_slot.call(1)))
	ok("Cinder Steps sells gloves and weapon tunings", gloves and cinder.any(func(t): return _sells(t, wup)))
	var crown := ShopStock.theme(String(_region(m, "crown")["shops"][0][2]))
	ok("the Crown's stall is premium (dearer, rarer gear)", float(crown.get("price_k", 1.0)) > 1.0
			and int(crown.get("gear_rar", 0)) > int(ShopStock.rules()["gear_rar"]))
	var placed := true
	var wards := {}
	for v in Shops.list(m):
		var biome: Dictionary = m.biomes.defs.get(String(_region(m, v["region"])["biome"]), {})
		var kinds: Array = (biome.get("hazards", []) as Array).map(func(h): return String(h["kind"]))
		for e in ShopStock.theme(String(v["theme"]))["sells"]:
			var ward := _ward_of(String(e))
			if ward != "":
				wards[ward] = true
				placed = placed and kinds.has(ward)
	ok("each hazard ward is sold in a region with that hazard", placed and wards.size() == 4, str(wards.keys()))
	var orbs := true
	var rng := RandomNumberGenerator.new()
	for i in 300:
		rng.seed = i
		orbs = orbs and not Data.PERKS[PerkOrbs.roll(rng, "chest")].has("ward")
	ok("ward perks never come from perk orbs (shop-only)", orbs)

func _snap(m: Match) -> void:
	var reg := _region(m, "frostgate")
	var sp: Array = reg["shops"][0]
	var at := Shops.spot(m.world, reg, sp)
	ok("a spot on open ground stays where it is listed", at.x == int(sp[0]) + 0.5 and at.z == int(sp[1]) + 0.5)
	var edge := _void_near(m, at)
	var moved := Shops.spot(m.world, reg, [edge.x, edge.y, sp[2]])
	var ii := m.world.island[m.world.idx(int(floor(moved.x)), int(floor(moved.z)))]
	ok("a spot over the void moves onto the region's ground", moved != Vector3.INF and ii >= 0
			and (reg["islands"] as Array).has(String(m.world.islands[ii]["id"])), str(edge))
	ok("and to the same tile every time", moved == Shops.spot(m.world, reg, [edge.x, edge.y, sp[2]]))
	var other := _region(m, "highwatch")
	var far := Shops.spot(m.world, reg, [other["shops"][0][0], other["shops"][0][1], sp[2]])
	ok("a spot far from the region finds nothing (no shop on someone else's land)", far == Vector3.INF)

## The hazard kind a stock entry's perk wards off ("" for anything else).
func _ward_of(entry: String) -> String:
	if not entry.begins_with("perk:"):
		return ""
	return String(Data.PERKS[entry.get_slice(":", 1)].get("ward", ""))

## A void tile a few metres off this ground spot (the coast outward).
func _void_near(m: Match, at: Vector3) -> Vector2i:
	for r in range(1, 40):
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := Vector2i(int(at.x), int(at.z)) + d * r
			if m.world.inb(q.x, q.y) and m.world.kind[m.world.idx(q.x, q.y)] == World.T_VOID:
				return q + d * 2
	return Vector2i(int(at.x), int(at.z))

# ------------------------------------------------------------------ wards

func _wards(m: Match) -> void:
	var h: Hunter = m.player
	h.pos = _vendor(m, "kiln_forge")["pos"]
	var hurt := _lava_tick(m, h)
	h.gems = 500
	var v := _vendor(m, "kiln_forge")
	var bought := Shops.buy(m, h, v, _row(v, "perk:ember_walk")) == ""
	ok("Emberwalk is bought at the Kiln Forge", bought and BiomeRun.warded(h, "lava_vent"))
	ok("a lava pool burns a hunter, not one with Emberwalk", hurt > 0.0 and _lava_tick(m, h) == 0.0, "%.1f" % hurt)
	var ice: Array = m.biomes.hazards.filter(func(z): return z["kind"] == "ice_patch")
	if ice.is_empty():
		ok("an ice patch to test Sure Foot on", false)
		return
	var p: Vector3 = ice[0]["pos"]
	var slick := m.ground_grip(p, h)
	h.add_perk("sure_foot")
	ok("ice is slick, but not with Sure Foot", slick < 1.0 and m.ground_grip(p, h) == 1.0, "%.2f" % slick)

## Health and armor a lava pool takes from h in one tick.
func _lava_tick(m: Match, h: Hunter) -> float:
	h.hp = h.max_hp
	h.armor = 0.0
	var before := h.hp
	m.fields.add(m.biomes.hz_ent, h.pos, {"radius": 2.0, "time": 1.0, "every": 0.5, "dmg": 6.0, "own": true,
		"ward": "lava_vent"}, {"slot": "lava", "ability": "lava"}, 1.0)
	m.fields.tick(0.6)
	m.fields.clear()
	return before - h.hp

func _row(v: Dictionary, entry: String) -> int:
	for i in (v["rows"] as Array).size():
		if String(v["rows"][i]["id"]) == entry:
			return i
	return -1

# ------------------------------------------------------------------ maps and bots

func _maps(m: Match) -> void:
	ok("vendors are a minimap detail kind (shown on a hold or once in view)", MapDetail.DETAIL.has("shop")
			and not MapDetail.shows("shop", false) and MapDetail.shows("shop", false, true))
	var r := ShopLegend.place(m, 20.0, 260.0, 200.0, 710.0)
	ok("the legend fits a 720p map (one-line rows when it must)", r.end.y <= 710.0
			and Shops.legend_rows(m).filter(func(x): return x["kind"] == "shop").size() == Shops.list(m).size())

func _bots(m: Match) -> void:
	var bot: Hunter = null
	for h in m.hunters:
		if h != m.player and h.ctrl == "bot":
			bot = h
	var forge := _vendor(m, "kiln_forge")
	bot.pos = forge["pos"] + Vector3(1.0, 0, 0)
	bot.gear[0] = {}
	bot.gear[1] = {}
	UtilityBelt.grant(bot, "tonic", 2)
	UtilityBelt.grant(bot, "armor_kit", 2)
	bot.gems = 70
	ok("a bot short of its upgrade reserve buys no gear", not BotShop.think(m, bot))
	bot.gems = 400
	var bought := BotShop.think(m, bot)
	ok("a rich bot at the forge buys a glove", bought and bot.gems < 400 and not (bot.gear[0] as Dictionary).is_empty())
	var bench := _vendor(m, "tuning_bench")
	bot.pos = bench["pos"] + Vector3(1.0, 0, 0)
	var perks: int = bot.perks.size()
	ok("and at the tuning bench a weapon tuning", BotShop.think(m, bot) and bot.perks.size() == perks + 1)
