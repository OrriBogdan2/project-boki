extends RefCounted
## --hot-zone-check: The Hollow Crown's regions (docs/MAP_REGIONS.md) and the hot drop zone
## (scripts/match/hot_zone.gd). Every region has a landmark, raised terrain, tall grass and a
## reason to go; region loot leans multiply into the biome's; each match picks one hot region
## from its seed (same seed, same zone; it varies between seeds; never the Crown), loot there rolls
## a rarity step better, and bot squads drop there without piling in. Never touches the save.

const SEEDS := [3, 5, 9, 12, 21, 33, 47, 58]
const LANDMARK_ROLES := ["heart", "camp", "nest", "shrine", "grove"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HOTZONE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _match(main: Node, seed_v: int, no_drop := true) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 6, "squad": 3, "tier": 0, "length": 1e9, "seed": seed_v, "no_drop": no_drop})
	m.set_process(false)
	return m

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_regions(main)
	_hot(main)
	_bots(main)
	print("HOTZONE DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

## Each region: a landmark (its own, or its role's), a raised tier, tall grass, a stated reason.
func _regions(main: Node) -> void:
	var m := _match(main, 3)
	var w := m.world
	ok(w.regions.size() >= 9, "the map has its regions (%d)" % w.regions.size())
	for R in w.regions:
		var nm := String(R.get("name", ""))
		var marked := false
		var raised := false
		var grass := 0
		for ii in w.islands.size():
			var I: Dictionary = w.islands[ii]
			if not String(I.get("id", "")) in R.get("islands", []):
				continue
			var own = I.get("landmark")
			var by_role: bool = own == null and String(I.get("role", "")) in LANDMARK_ROLES
			marked = marked or (own is String and own != "") or by_role
			for x in range(int(I["c"].x) - int(I["r"]), int(I["c"].x) + int(I["r"]) + 1):
				for z in range(int(I["c"].y) - int(I["r"]), int(I["c"].y) + int(I["r"]) + 1):
					if w.island_of(x + 0.5, z + 0.5) != ii:
						continue
					raised = raised or w.level[w.idx(x, z)] >= 2
					grass += 1 if w.bush.has(w.idx(x, z)) else 0
		ok(marked, "%s has a landmark" % nm)
		ok(raised, "%s has raised ground" % nm)
		ok(grass > 0, "%s has tall grass (%d tiles)" % [nm, grass])
		ok(String(R.get("purpose", "")).length() > 20, "%s has a reason to go" % nm)
	# region loot multiplies into the biome's lean: Frostgate leans armor harder than the frost alone
	var fg: Dictionary = w.regions.filter(func(R): return R["id"] == "frostgate")[0]
	var fi: Dictionary = w.islands.filter(func(I): return I.get("id") == "frostgate")[0]
	var at := Vector3(fi["c"].x + 0.5, 0, fi["c"].y + 0.5)
	var biome_lean: Dictionary = m.biomes._biome(at).get("loot", {}).get("slots", {})
	var want := float(biome_lean.get("armor", 1.0)) * float(fg["loot"]["slots"]["armor"])
	var got := float(m.biomes.slot_lean_at(at).get("armor", 1.0))
	ok(is_equal_approx(got, want), "Frostgate armor lean = biome x region (%.2f)" % want)
	m.free()

## The hot zone: from the seed, varied, never the Crown, a rarity step better, on its own islands.
func _hot(main: Node) -> void:
	var picked := {}
	for s in SEEDS:
		var m := _match(main, s)
		var hz: HotZone = m.biomes.hot
		ok(hz.hot >= 0 and not hz.zone.is_empty(), "seed %d: a hot zone (%s)" % [s, m.world.regions[hz.hot]["name"]])
		picked[hz.hot] = true
		ok(HotZone.new(m.world, s).hot == hz.hot, "seed %d: the same seed picks the same zone" % s)
		for ii in m.world.islands.size():
			if hz.region_of[ii] == hz.hot:
				ok(String(m.world.islands[ii].get("role", "")) != "heart", "seed %d: the hot zone isn't the Crown" % s)
		var c: Vector3 = hz.zone[0]["c"]
		var own := int(m.world.regions[hz.hot].get("loot", {}).get("rarity_bonus", 0))
		ok(hz.rarity_bonus(c) == own + HotZone.RARITY, "seed %d: hot zone loot rolls a step better" % s)
		ok(hz.region_at(hz.landing()) == hz.hot, "seed %d: the bots' landing is in the hot zone" % s)
		m.free()
	ok(picked.size() >= 3, "the hot zone varies between matches (%d regions)" % picked.size())

## Bot squads weigh the hot zone when they plan the drop, and never two squads into it.
func _bots(main: Node) -> void:
	var into := 0
	for s in SEEDS:
		var m := _match(main, s, false)
		var guard := 0
		while m.skydrop != null and m.skydrop.planning and guard < 4000:
			m.step(Match.DT)
			guard += 1
		var hz: HotZone = m.biomes.hot
		var squads := 0
		for t in m.skydrop.leads:
			var l: Hunter = m.skydrop.leader(int(t))
			if l and l.ctrl == "bot" and hz.region_at(l.ai.get("land", Vector3.INF)) == hz.hot \
					and l.ai.get("land", Vector3.INF).distance_to(hz.landing()) < 14.0:
				squads += 1
		ok(squads <= 1, "seed %d: at most one bot squad heads for the hot zone's landing (%d)" % [s, squads])
		into += squads
		m.free()
	ok(into >= 2, "bot squads pick the hot zone over %d matches (%d times)" % [SEEDS.size(), into])
