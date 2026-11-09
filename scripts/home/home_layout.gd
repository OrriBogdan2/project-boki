class_name HomeLayout
extends RefCounted
## How your home islands are laid out, kept on the save as Save.d["layout"]:
##   grow     how many times you've expanded the main island (its edge grows east and south)
##   b        where each building stands and which way it faces: id -> {x, z, r} (top-left tile, quarter turns);
##            a building that isn't listed stands on its default lot (Data.BUILDINGS rect)
##   deco     decorations you've put down: [{u, id, x, z, r, c?}] (u is a unique number)
##   paths    painted path tiles: "x,z" -> catalog id ("none" clears one of the farm's own paths)
##   water    pond tiles: "x,z" -> 1
##   theme    the islands' ground colours; themes you've bought
##   inv      decorations in storage: id -> count (put away from the island, placed again for free)
## home.gd builds the world from this; HomeBuild (build mode) edits it.

const W := 92                        # the home map, in tiles (was 72 x 50)
const H := 70
const SEED := 4242
const CORE_C := Vector2(38, 32)      # the original island: everything that stood there still does
const CORE_R := Vector2(14, 11)
const LOBE_NW := Vector2(23, 20)     # the open meadow grows out east and south from this corner
const LOBE_R0 := Vector2(21, 15)
const LOBE_STEP := Vector2(2.0, 1.5)
const GAP := 3                       # tiles of sky kept between the main island and every other isle

## Growing the main island: [gems, scrap] for each step, and [wood, stone] (from the work stations).
const EXPAND := [[150, 4], [260, 8], [400, 14], [600, 22]]
const EXPAND_MATS := [[0, 0], [16, 10], [30, 20], [50, 34]]

## Ground colours for every home island. region is the world's region look (trees, rocks) to use.
const THEMES := {
	"meadow": {"name": "Meadow", "gems": 0, "region": 0},
	"autumn": {"name": "Autumn", "gems": 120, "region": 1, "top": "b08a50", "top2": "94723f", "side": "8b5a3a", "leaf": "e0743a"},
	"snow": {"name": "Snow", "gems": 160, "region": 2, "top": "d2e2ea", "top2": "aac6d6", "side": "7a8aa0", "deep": "2c3448", "leaf": "8ac8d8"},
	"blossom": {"name": "Blossom", "gems": 200, "region": 4, "top": "7cbc6c", "top2": "5c9c5c", "side": "8b6d52", "leaf": "ff9ac8"},
}

## The build-mode catalog. cat: the bar's tab. gems / scrap: the price of one (one tile for lines and
## brushes). size: footprint in tiles before turning. block: kin and you walk around it. line: dragged
## out in a line that joins up (fences). brush: painted on tiles (path / clear / water). colour: you
## pick its colour. light: glows at night. bed: kin sleep on it.
const CATALOG := {
	"fence": {"name": "Wood fence", "cat": "Fences", "gems": 3, "line": true, "block": true},
	"picket": {"name": "Picket fence", "cat": "Fences", "gems": 4, "line": true, "block": true},
	"stone_wall": {"name": "Stone wall", "cat": "Fences", "gems": 6, "line": true, "block": true},
	"hedge": {"name": "Hedge", "cat": "Fences", "gems": 5, "line": true, "block": true},
	"path_stone": {"name": "Stone path", "cat": "Paths", "gems": 2, "brush": "path", "col": "b1a796"},
	"path_dirt": {"name": "Dirt path", "cat": "Paths", "gems": 1, "brush": "path", "col": "9c7a52"},
	"path_wood": {"name": "Boardwalk", "cat": "Paths", "gems": 2, "brush": "path", "col": "8a6242"},
	"path_clear": {"name": "Grass (clear)", "cat": "Paths", "gems": 0, "brush": "clear"},
	"clear_wild": {"name": "Clear the wild", "cat": "Island", "gems": 3, "brush": "wild"},
	"river": {"name": "River", "cat": "Paths", "gems": 2, "brush": "water", "block": true,
		"desc": "Drag a narrow channel of water across the ground. A crop patch within 2 tiles of any water waters itself."},
	"water": {"name": "Pond water", "cat": "Paths", "gems": 6, "brush": "water", "block": true},
	"flowers": {"name": "Flower bed", "cat": "Garden", "gems": 8},
	"snack_patch": {"name": "Snack patch", "cat": "Garden", "gems": 0, "size": [2, 2], "max": 1,
		"desc": "Grows four element snacks every few minutes. Walk over it to pick them. For feeding only."},
	"bush": {"name": "Bush", "cat": "Garden", "gems": 10, "block": true},
	"tree": {"name": "Leafy tree", "cat": "Garden", "gems": 20, "block": true},
	"pine": {"name": "Pine tree", "cat": "Garden", "gems": 20, "block": true},
	"blossom_tree": {"name": "Blossom tree", "cat": "Garden", "gems": 30, "block": true},
	"lantern": {"name": "Lantern", "cat": "Lights", "gems": 15, "light": true},
	"lamp_post": {"name": "Lamp post", "cat": "Lights", "gems": 20, "light": true},
	"bench": {"name": "Bench", "cat": "Furniture", "gems": 25, "size": [2, 1], "block": true},
	"kin_bed": {"name": "Boki bed", "cat": "Furniture", "gems": 15, "bed": true, "colour": true},
	"rug": {"name": "Picnic rug", "cat": "Furniture", "gems": 20, "size": [2, 2], "colour": true},
	"rug_long": {"name": "Long rug", "cat": "Furniture", "gems": 30, "size": [3, 2], "colour": true},
	"banner": {"name": "Banner", "cat": "Statues", "gems": 20, "colour": true},
	"pillar": {"name": "Old pillar", "cat": "Statues", "gems": 40, "scrap": 2, "block": true},
	"kin_statue": {"name": "Boki statue", "cat": "Statues", "gems": 120, "scrap": 6, "block": true},
	"fountain": {"name": "Fountain", "cat": "Statues", "gems": 150, "scrap": 8, "size": [2, 2], "block": true},
	# the Boki base's playthings (HomeToys, content/rules/toys.json); the Base tab shows only while base_mode is on
	"toy_ball": {"name": "Play ball", "cat": "Base", "gems": 12, "toy": true,
		"desc": "A ball to chase and nudge. Trains Speed. Boki share it."},
	"toy_post": {"name": "Climbing post", "cat": "Base", "gems": 30, "block": true, "toy": true,
		"desc": "Flying and Rock Boki love to climb it. Trains Power."},
	"toy_tub": {"name": "Splash tub", "cat": "Base", "gems": 25, "block": true, "toy": true,
		"desc": "Water and Ice Boki love a splash. Trains Focus."},
	# work stations (Work, HomeWork): kin with the right element come and work them on their own.
	# work: the element. wood / stone: building materials (Save.d["mats"]) on top of the gems.
	"job_board": {"name": "Job Board", "cat": "Work", "gems": 30, "block": true, "work": "board",
		"desc": "Set which jobs matter (Off to High) and see who's doing what. Pin a Boki to a job, or let it rest."},
	"lumber_camp": {"name": "Lumber Camp", "cat": "Work", "gems": 40, "size": [2, 1], "block": true, "work": "timber",
		"desc": "Timber Boki fell the wild trees within 5 tiles, then split its log pile (it grows back)."},
	"quarry": {"name": "Quarry", "cat": "Work", "gems": 40, "size": [2, 1], "block": true, "work": "stone",
		"desc": "Stone Boki break the wild boulders within 5 tiles, then mine its rock (it grows back)."},
	"storage_chest": {"name": "Storage Chest", "cat": "Work", "gems": 25, "block": true, "work": "haul",
		"desc": "Haul Boki bring it the wood and stone that's lying about, and take food from it to feeders that run low."},
	"hearth_oven": {"name": "Hearth Oven", "cat": "Work", "gems": 60, "wood": 6, "stone": 4, "block": true, "work": "ember",
		"desc": "Ember Boki bake a firewood log into 2 Boki kibble (3 for a skilled baker)."},
	"workbench": {"name": "Workbench", "cat": "Work", "gems": 50, "wood": 8, "size": [2, 1], "block": true, "work": "craft",
		"desc": "Craft Boki turn 2 wood and a stone into scrap for upgrades and statues."},
	"spark_mill": {"name": "Spark Mill", "cat": "Work", "gems": 80, "wood": 8, "stone": 6, "scrap": 2, "block": true, "work": "spark",
		"desc": "Spark Boki crank it up. While it has charge, the oven, workbench and infirmary work 50% faster."},
	"cold_store": {"name": "Cold Store", "cat": "Work", "gems": 70, "wood": 4, "stone": 8, "block": true, "work": "frost",
		"desc": "Frost Boki keep it cold. While it's chilled, food stays fresh and every meal fills 15% more."},
	"ranch_pen": {"name": "Ranch Pen", "cat": "Work", "gems": 60, "wood": 10, "size": [3, 2], "work": "ranch",
		"desc": "Up to two Ranch Boki lounge here and make things over time (glowcaps, sweet buns, kibble)."},
	"infirmary": {"name": "Infirmary", "cat": "Work", "gems": 70, "wood": 6, "stone": 6, "size": [2, 1], "block": true, "work": "mend",
		"desc": "Mend Boki look after tired, glum or hungry Boki, and brew tonics here when nobody needs them."},
	"seed_garden": {"name": "Seed Garden", "cat": "Work", "gems": 35, "wood": 4, "size": [2, 2], "work": "bloom",
		"desc": "A Bloom Boki you assign raises seedlings here: a common seed every few minutes, even while you're away."},
	"kiln": {"name": "Kiln", "cat": "Work", "gems": 45, "stone": 8, "block": true, "work": "ember",
		"desc": "An Ember Boki you assign burns 3 wood into an Ember Coal for the Incubator, even while you're away."},
	# the farm's own things, placed by you on a farm-start island (fs): on older islands they stand
	# where they always have. fixture: what it is to home.gd. max: how many you can have (0: no limit).
	"house": {"name": "House", "cat": "Buildings", "gems": 90, "size": [5, 3], "block": true, "fixture": "house", "max": 1, "door": true,
		"desc": "Your home. Go inside to rest and decorate; Boki nap here too. Its door needs open ground."},
	"crop_patch": {"name": "Crop patch", "cat": "Buildings", "gems": 30, "size": [5, 4], "fixture": "farm", "max": 0,
		"desc": "Four plots of tilled soil to sow and water. Buying more plots at the market makes room for another patch. Put it within 2 tiles of water and it waters itself."},
	"cook_pot": {"name": "Cooking pot", "cat": "Buildings", "gems": 20, "block": true, "fixture": "pot", "max": 1,
		"desc": "Cook what you grow into treats for your Boki."},
	"market_stall": {"name": "Market stall", "cat": "Buildings", "gems": 30, "size": [3, 2], "block": true, "fixture": "stall", "max": 1,
		"desc": "Somewhere to trade on the island (the Market is always on the hub bar too)."},
	"nesting_nook": {"name": "Nesting Nook", "cat": "Buildings", "gems": 60, "wood": 8, "size": [4, 2], "block": true, "fixture": "nook", "max": 1,
		"desc": "Where two close Boki leave an egg, with the Incubator beside it for Rare Eggs."},
	"boki_burrow": {"name": "Boki Burrow", "cat": "Buildings", "gems": 40, "wood": 6, "stone": 4, "size": [3, 2], "block": true, "fixture": "burrow", "max": 1,
		"desc": "Where Boki who aren't out on the farm curl up and sleep."},
	"training_post": {"name": "Training post", "cat": "Buildings", "gems": 35, "wood": 6, "size": [2, 2], "fixture": "yard", "max": 1,
		"desc": "Train a Boki's moves against the dummy."},
	"graveyard": {"name": "Graveyard", "cat": "Buildings", "gems": 25, "stone": 6, "size": [4, 6], "fixture": "graves", "max": 1,
		"desc": "A quiet corner for Boki who died. Their graves wait here (and the Soul Shrine can bring one back)."},
}
## Fixture -> catalog id (one each).
const FIXTURES := {"house": "house", "farm": "crop_patch", "pot": "cook_pot", "stall": "market_stall", "nook": "nesting_nook",
	"burrow": "boki_burrow", "yard": "training_post", "graves": "graveyard"}
## What a farm-start island begins with: the portal, wild meadow and gems for a house and the essentials
## (house 90 + crop patch 30 + cooking pot 20 = 140, and some to spare; the market stall comes with the island).
const FS_GEMS := 200
## The landing by the portal, kept clear on a farm-start island: you arrive here.
const LANDING := Vector3(38.5, 0, 35.5)
const CATS := ["Buildings", "Work", "Fences", "Paths", "Garden", "Lights", "Furniture", "Statues", "Upgrades", "Island"]
const COLOURS := ["e0607e", "f2c84a", "5ab0f0", "8fd16a", "b48cf2", "f3eee2"]

## The farm's lamps and flower beds start out as decorations, so they can be moved or put away too.
const STOCK := [["lamp_post", 36.2, 30.0], ["lamp_post", 39.6, 35.5], ["lamp_post", 36.4, 35.6], ["lamp_post", 41.0, 30.0],
	["lamp_post", 26.0, 29.2], ["lamp_post", 51.2, 36.6], ["flowers", 35.6, 28.6], ["flowers", 40.4, 28.6], ["flowers", 39.6, 37.4]]

# ------------------------------------------------------------------ the save
static func fresh() -> Dictionary:
	return {"v": 1, "grow": 0, "theme": "meadow", "themes": ["meadow"], "b": {}, "deco": [], "paths": {}, "water": {}, "inv": {}, "uid": 0,
		"seed": 0, "made": true, "cleared": {}, "fs": 0, "regrow": {}}

## A farm-start island (new saves from the farm-start update on): it begins almost empty and you
## place the house, crop patch, pot and the rest yourself. Older islands keep their fixed farm.
static func fs(d: Dictionary) -> bool:
	return int(of(d).get("fs", 0)) >= 1

## A brand new farm-start layout for a save (its own seed, so its own island).
static func new_fs(d: Dictionary, seed := -1) -> Dictionary:
	var L := fresh()
	if seed <= 0:
		var r := RandomNumberGenerator.new(); r.randomize()
		seed = r.randi_range(1, 2147483646)
	L["seed"] = seed
	L["fs"] = 1
	L["fb"] = 1               # the farm-building pass: unlocks, construction sites, upgrades (FarmUnlocks, FarmSites)
	L["made"] = true          # no "Make it home" suggestions: you choose where everything goes
	L["sk"] = fs_scale(seed)
	d["layout"] = L
	# gems for a house and the essentials, and the first trough waits in storage to be set down
	if not bool(d.get("fs_grant", false)):
		d["fs_grant"] = true
		d["gems"] = maxi(int(d.get("gems", 0)), FS_GEMS)
	if (d.get("feeders", []) as Array).is_empty():
		d["feeder_given"] = true
		if typeof(d.get("feeder_inv")) != TYPE_DICTIONARY: d["feeder_inv"] = {}
		d["feeder_inv"]["trough"] = maxi(1, int(d["feeder_inv"].get("trough", 0)))
	return L

## The fixture entries placed on the island: [deco entry] for one fixture kind, sorted by uid.
static func fixtures(d: Dictionary, fx: String) -> Array:
	var id := String(FIXTURES.get(fx, ""))
	var out: Array = []
	for e in of(d).get("deco", []):
		if String(e.get("id", "")) == id and not FarmSites.is_site(e): out.append(e)
	out.sort_custom(func(a, b): return int(a["u"]) < int(b["u"]))
	return out

## How many of a catalog item you may have out (and in storage) at once; 0 is no limit.
static func max_of(id: String, d: Dictionary) -> int:
	var c: Dictionary = CATALOG.get(id, {})
	if id == "crop_patch":
		return maxi(1, int(ceil(float(int(d.get("plot_cap", 4))) / 4.0)))
	return int(c.get("max", 0))

static func count_of(id: String, d: Dictionary) -> int:
	var L := of(d)
	var n := int((L.get("inv", {}) as Dictionary).get(id, 0))
	for e in L.get("deco", []):
		if String(e.get("id", "")) == id: n += 1
	return n

## A fixture's door step (the house): just outside its front.
static func fixture_door(e: Dictionary) -> Vector3:
	var sz: Array = CATALOG.get(String(e["id"]), {}).get("size", [1, 1])
	return deco_center(e) + facing(int(e.get("r", 0))) * (float(sz[1]) * 0.5 + 0.6)

## Is a building on its lot? On a farm-start island the main isle's buildings have no lot until you
## place one (from build mode); everywhere else they always do.
static func placed(b: String, d: Dictionary) -> bool:
	if not fs(d) or String(Data.BUILDINGS[b].get("isle", "main")) != "main":
		return true
	return (of(d).get("b", {}) as Dictionary).has(b)

## Fills in the layout on a save that doesn't have one yet (a new game, or one from before build
## mode): buildings stay on their lots, and the farm's lamps and flower beds become decorations.
static func ensure(d: Dictionary) -> Dictionary:
	if typeof(d.get("layout")) != TYPE_DICTIONARY:
		var L := fresh()
		if d.has("tutorial") and not bool(d.get("tutorial", {}).get("home", false)):
			# a brand new home: a farm-start island of its own, nearly empty (see new_fs). (Only a
			# real save: someone else's island you're visiting has no "tutorial" and stays as it is.)
			L = new_fs(d)
		for s in STOCK if int(L.get("fs", 0)) < 1 else []:
			var e := {"u": _next_uid(L), "id": String(s[0]), "x": int(floor(float(s[1]))), "z": int(floor(float(s[2]))), "r": 0, "px": float(s[1]), "pz": float(s[2])}
			(L["deco"] as Array).append(e)
		d["layout"] = L
	var L: Dictionary = d["layout"]
	var f := fresh()
	for k in f:
		var a := typeof(L.get(k)); var b := typeof(f[k])
		if L.has(k) and a != b and a in [TYPE_INT, TYPE_FLOAT] and b in [TYPE_INT, TYPE_FLOAT]:
			# JSON brings every number back as a float: a number is still a number (the seed, the
			# farm-start flag, the uid counter and the island's size used to be reset here)
			L[k] = int(L[k]) if b == TYPE_INT else float(L[k])
			continue
		if not L.has(k) or a != b:
			L[k] = f[k] if typeof(f[k]) != TYPE_DICTIONARY and typeof(f[k]) != TYPE_ARRAY else f[k].duplicate()
	L["grow"] = clampi(int(L["grow"]), 0, EXPAND.size())
	if not THEMES.has(String(L["theme"])): L["theme"] = "meadow"
	# JSON brings numbers back as floats; drop anything that isn't in the catalog any more
	var keep: Array = []
	for e in L["deco"]:
		if typeof(e) == TYPE_DICTIONARY and CATALOG.has(String(e.get("id", ""))):
			e["x"] = int(e.get("x", 0)); e["z"] = int(e.get("z", 0)); e["r"] = int(e.get("r", 0)) % 4
			if not e.has("u"): e["u"] = _next_uid(L)
			e["u"] = int(e["u"])
			FarmSites.clean(e)
			keep.append(e)
	L["deco"] = keep
	for b in (L["b"] as Dictionary).keys():
		var be = L["b"][b]
		if not Data.BUILDINGS.has(b) or typeof(be) != TYPE_DICTIONARY:
			(L["b"] as Dictionary).erase(b)
			continue
		be["x"] = int(be.get("x", 0)); be["z"] = int(be.get("z", 0)); be["r"] = int(be.get("r", 0)) % 4
	SnackPatch.grant(d)
	return L

static func of(d: Dictionary) -> Dictionary:
	var L = d.get("layout")
	return L if typeof(L) == TYPE_DICTIONARY else fresh()

static func _next_uid(L: Dictionary) -> int:
	L["uid"] = int(L.get("uid", 0)) + 1
	return int(L["uid"])

static func key(x: int, z: int) -> String:
	return "%d,%d" % [x, z]

static func unkey(k: String) -> Vector2i:
	var p := k.split(",")
	return Vector2i(int(p[0]), int(p[1])) if p.size() == 2 else Vector2i(-1, -1)

# ------------------------------------------------------------------ buildings
## The building's footprint before turning: [width along x, depth along z].
static func base_size(b: String) -> Vector2i:
	var rc: Array = Data.BUILDINGS[b]["rect"]
	return Vector2i(int(rc[2]) - int(rc[0]) + 1, int(rc[3]) - int(rc[1]) + 1)

static func turned(sz: Vector2i, r: int) -> Vector2i:
	return Vector2i(sz.y, sz.x) if r % 2 == 1 else sz

## {x, z, r}: where a building stands (its default lot unless you've moved it).
static func place_of(b: String, d: Dictionary) -> Dictionary:
	var L := of(d)
	var be = (L.get("b", {}) as Dictionary).get(b)
	if typeof(be) == TYPE_DICTIONARY:
		return {"x": int(be["x"]), "z": int(be["z"]), "r": int(be.get("r", 0)) % 4}
	var rc: Array = Data.BUILDINGS[b]["rect"]
	return {"x": int(rc[0]), "z": int(rc[1]), "r": 0}

## The tile rect [x0, z0, x1, z1] a building covers where it stands now.
static func rect_of(b: String, d: Dictionary) -> Array:
	var p := place_of(b, d)
	return rect_at(b, int(p["x"]), int(p["z"]), int(p["r"]))

static func rect_at(b: String, x: int, z: int, r: int) -> Array:
	var sz := turned(base_size(b), r)
	return [x, z, x + sz.x - 1, z + sz.y - 1]

static func rect_center(rc: Array) -> Vector3:
	return Vector3((rc[0] + rc[2] + 1) * 0.5, 0, (rc[1] + rc[3] + 1) * 0.5)

## Which way a quarter turn faces: the door side (+z unturned).
static func facing(r: int) -> Vector3:
	return [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)][r % 4]

## The spot just outside a building's door (or the middle of its lot's front), for a footprint at x,z turned r.
static func door_at(b: String, x: int, z: int, r: int) -> Vector3:
	var rc := rect_at(b, x, z, r)
	return rect_center(rc) + facing(r) * (base_size(b).y * 0.5 + 1.1)

static func cells_of(rc: Array) -> Array:
	var out: Array = []
	for zz in range(int(rc[1]), int(rc[3]) + 1):
		for xx in range(int(rc[0]), int(rc[2]) + 1):
			out.append(Vector2i(xx, zz))
	return out

# ------------------------------------------------------------------ decorations
static func size_of(id: String, r: int) -> Vector2i:
	var s: Array = CATALOG.get(id, {}).get("size", [1, 1])
	return turned(Vector2i(int(s[0]), int(s[1])), r)

static func deco_cells(e: Dictionary) -> Array:
	var sz := size_of(String(e["id"]), int(e.get("r", 0)))
	return cells_of([int(e["x"]), int(e["z"]), int(e["x"]) + sz.x - 1, int(e["z"]) + sz.y - 1])

static func deco_center(e: Dictionary) -> Vector3:
	if e.has("px"):
		return Vector3(float(e["px"]), 0, float(e["pz"]))
	var sz := size_of(String(e["id"]), int(e.get("r", 0)))
	return Vector3(int(e["x"]) + sz.x * 0.5, 0, int(e["z"]) + sz.y * 0.5)

static func blocks(id: String) -> bool:
	return bool(CATALOG.get(id, {}).get("block", false))

## [gems, scrap, wood, stone] for n of a catalog item.
static func price(id: String, n := 1) -> Array:
	var c: Dictionary = CATALOG.get(id, {})
	return [int(c.get("gems", 0)) * n, int(c.get("scrap", 0)) * n, int(c.get("wood", 0)) * n, int(c.get("stone", 0)) * n]

## The work stations placed on the island: [{e (the deco entry), id, el}].
static func stations(d: Dictionary, el := "") -> Array:
	var out: Array = []
	for e in of(d).get("deco", []):
		var c: Dictionary = CATALOG.get(String(e.get("id", "")), {})
		if c.has("work") and (el == "" or String(c["work"]) == el) and not FarmSites.is_site(e):
			out.append({"e": e, "id": String(e["id"]), "el": String(c["work"])})
	return out

# ------------------------------------------------------------------ the land
static func lobe(level: int) -> Array:
	var rr := LOBE_R0 + LOBE_STEP * level
	return [LOBE_NW + rr, rr]

## The home world: the islands from their definitions, then the main island's meadow grown out to
## the save's size. The original island's shape is untouched, so nothing that stood on it falls off.
## sk: a farm-start island's size scale (its layout's "sk"); 0 for the classic and procedural meadows.
static func make_world(world: World, level: int, seed := 0, sk := 0.0) -> void:
	# a farm-start island keeps only a small fixed heart round the portal: the rest is its own shape
	var defs: Array = [["main", CORE_C, CORE_R] if sk <= 0.0 else ["main", FS_CORE_C, FS_CORE_R]]
	for k in Data.ISLES:
		defs.append([k, Data.ISLES[k]["c"], Data.ISLES[k]["r"]])
	world.make_islands(SEED, W, H, defs)
	grow_main(world, level, seed, sk)
	var spans := {}
	# a farm-start island's ponds and cliffs (wild_fs) can't take a bridge's foot or its sign
	var bad := {}
	if sk > 0.0:
		var wt := wild_fs(world, seed, sk, {})
		for i in wt:
			if String(wt[i]) in ["water", "cliff"]: bad[i] = true
	for k in Data.ISLES:
		spans[k] = bridge_span(world, k, bad)
	world.set_meta("isle_bridges", spans)

## (feelfix) Where the bridge to isle k goes on this world: {"rect": [x0, z0, x1, z1], "sign":
## Vector2}. The main island's outline differs per seed, so the span is found from the real edges:
## along the isle's usual axis (Data.ISLES[k]["bridge"]), the two-tile-wide strip with the shortest
## run of open sky that starts on the isle's edge and ends on the main island's edge, both ends at
## ground level, nothing else in between. The sign (where you build it) stands on the main island
## beside the bridge's foot. Falls back to the fixed rect if no strip fits.
static func bridge_span(world: World, k: String, bad := {}) -> Dictionary:
	var rc: Array = Data.ISLES[k]["bridge"]
	var fallback := {"rect": rc, "sign": Data.ISLES[k]["sign"]}
	var ii := -1
	for i in world.islands.size():
		if String(world.islands[i]["id"]) == k: ii = i
	if ii < 0:
		return fallback
	var horiz: bool = rc[2] - rc[0] > rc[3] - rc[1]
	var ic: Vector2 = Data.ISLES[k]["c"]
	var mid: float = (rc[1] + rc[3]) * 0.5 if horiz else (rc[0] + rc[2]) * 0.5
	# which way the main island lies from the isle, along the bridge
	var dir: float = signf(((rc[0] + rc[2]) * 0.5 - ic.x) if horiz else ((rc[1] + rc[3]) * 0.5 - ic.y))
	if dir == 0.0: dir = 1.0
	var ic_a := int(floor(ic.x if horiz else ic.y))
	var limit := world.w if horiz else world.h
	var at := func(a: int, b: int) -> int:     # tile index at (along a, across b)
		var x := a if horiz else b; var z := b if horiz else a
		return world.idx(x, z) if world.inb(x, z) else -1
	var level_ok := func(a: int, b: int) -> bool:
		var x := (a if horiz else b); var z := (b if horiz else a)
		if not world.inb(x, z) or bad.has(world.idx(x, z)): return false
		return absf(world.ground_at(x + 0.5, z + 0.5)) < 0.3
	var cands: Array = []
	for off in range(-8, 9):
		var b0 := int(floor(mid)) + off
		var a_start := -1; var a_end := -1; var good := true
		for b in [b0, b0 + 1]:
			# from the isle's centre walk toward the main island: isle ground, then sky, then main ground
			var a := ic_a; var last_isle := -1; var first_main := -1
			while a >= 0 and a < limit:
				var i: int = at.call(a, b)
				if i < 0: break
				if world.island[i] == ii and world.kind[i] != World.T_VOID:
					last_isle = a
				elif world.kind[i] != World.T_VOID:
					var nx: int = at.call(a + int(dir), b)
					if world.island[i] == 0 and last_isle >= 0 and nx >= 0 and world.kind[nx] == World.T_VOID:
						a += int(dir)      # (a one-tile spur: carry on past it)
						continue
					if world.island[i] == 0 and last_isle >= 0: first_main = a
					break
				elif last_isle >= 0 and absf(a - last_isle) > 24:
					break
				a += int(dir)
			if last_isle < 0 or first_main < 0 or not level_ok.call(last_isle, b) or not level_ok.call(first_main, b) or not level_ok.call(first_main + int(dir), b):
				good = false; break
			var s0 := last_isle + int(dir); var s1 := first_main - int(dir)
			a_start = s0 if a_start < 0 else (maxi(a_start, s0) if dir > 0 else mini(a_start, s0))
			a_end = s1 if a_end < 0 else (mini(a_end, s1) if dir > 0 else maxi(a_end, s1))
		if not good: continue
		# both columns must be open sky over the whole span (the shorter column's ends are trimmed
		# by the longer one's land, so check the union run is all sky or the two islands)
		var lo := mini(a_start, a_end); var hi := maxi(a_start, a_end)
		if (hi - lo) < 0 or (dir > 0 and a_start > a_end) or (dir < 0 and a_start < a_end):
			continue
		var clean := true
		for b in [b0, b0 + 1]:
			for a in range(lo, hi + 1):
				var i: int = at.call(a, b)
				if i < 0 or (world.kind[i] != World.T_VOID and world.island[i] != 0 and world.island[i] != ii): clean = false
		if not clean: continue
		cands.append({"b0": b0, "lo": lo, "hi": hi, "score": float(hi - lo) + absf(off) * 0.35})
	cands.sort_custom(func(p, q): return float(p["score"]) < float(q["score"]))
	for cd in cands:
		# span the gap from isle edge to main edge (the land tiles at either end are left as they are)
		var lo2: int = cd["lo"]; var hi2: int = cd["hi"]
		var b0b: int = cd["b0"]
		# extend to cover any sky the shorter column still has next to the land
		while true:
			var grow := false
			for b in [b0b, b0b + 1]:
				var i: int = at.call(lo2 - 1, b)
				if i >= 0 and world.kind[i] == World.T_VOID: grow = true
			if not grow: break
			lo2 -= 1
		while true:
			var grow := false
			for b in [b0b, b0b + 1]:
				var i: int = at.call(hi2 + 1, b)
				if i >= 0 and world.kind[i] == World.T_VOID: grow = true
			if not grow: break
			hi2 += 1
		var foot := (hi2 + 1) if dir > 0 else (lo2 - 1)
		var head := (lo2 - 1) if dir > 0 else (hi2 + 1)
		# both ends land on the right island at ground level, in both columns
		var ends_ok := true
		for b in [b0b, b0b + 1]:
			var fi: int = at.call(foot, b); var hi_: int = at.call(head, b)
			if fi < 0 or hi_ < 0 or world.island[fi] != 0 or world.kind[fi] == World.T_VOID or world.island[hi_] != ii or world.kind[hi_] == World.T_VOID:
				ends_ok = false
			elif not level_ok.call(foot, b) or not level_ok.call(head, b) or not level_ok.call(foot + int(dir), b):
				ends_ok = false
		if not ends_ok: continue
		var rect: Array = [lo2, b0b, hi2, b0b + 1] if horiz else [b0b, lo2, b0b + 1, hi2]
		# the sign: on the main island, a step back from the bridge's foot, to one side
		var sign := Vector2.INF
		for cand in [[foot + int(dir), b0b - 1], [foot + int(dir), b0b + 2], [foot, b0b - 1], [foot, b0b + 2], [foot + 2 * int(dir), b0b - 1], [foot + 2 * int(dir), b0b + 2]]:
			var i: int = at.call(cand[0], cand[1])
			if i >= 0 and world.island[i] == 0 and world.kind[i] == World.T_GROUND and level_ok.call(cand[0], cand[1]):
				var along := float(cand[0]) + 0.5; var across := float(cand[1]) + (0.6 if cand[1] < b0b else 0.4)
				sign = Vector2(along, across) if horiz else Vector2(across, along)
				break
		if sign == Vector2.INF: continue
		return {"rect": rect, "sign": sign}
	return fallback

## The bridge to isle k on this home world (bridge_span, worked out when the world was made).
static func isle_bridge(world: World, k: String) -> Dictionary:
	if world and world.has_meta("isle_bridges"):
		var sp: Dictionary = world.get_meta("isle_bridges")
		if sp.has(k): return sp[k]
	return {"rect": Data.ISLES[k]["bridge"], "sign": Data.ISLES[k]["sign"]}

## The meadow's outline. seed 0 is the classic island; any other seed gives its own shape: the
## meadow's size wobbles, its edge noise differs and one to three headlands bulge out of it.
static func shape_of(level: int, seed: int) -> Array:
	var lb := lobe(level)
	var c: Vector2 = lb[0]; var rr: Vector2 = lb[1]
	var bulges: Array = []
	if seed != 0:
		var r := RandomNumberGenerator.new(); r.seed = seed
		var j := Vector2(r.randf_range(-1.5, 2.5), r.randf_range(-1.0, 2.0))
		rr += j; c += j
		for k in r.randi_range(1, 3):
			var a := r.randf_range(-0.25 * PI, 0.75 * PI)          # east round to south
			var at := c + Vector2(cos(a) * rr.x, sin(a) * rr.y) * r.randf_range(0.8, 0.95)
			bulges.append([at, Vector2(r.randf_range(4.5, 7.5), r.randf_range(4.0, 6.5))])
	return [c, rr, bulges]

static func grow_main(world: World, level: int, seed := 0, sk := 0.0) -> void:
	var shape := FastNoiseLite.new(); shape.seed = SEED if seed == 0 else seed; shape.frequency = 0.12
	var drng := RandomNumberGenerator.new(); drng.seed = SEED + 3
	var sh := shape_of(level, seed) if sk <= 0.0 else fs_shape(level, seed, sk)
	var c: Vector2 = sh[0]; var rr: Vector2 = sh[1]
	var bulges: Array = sh[2]
	var cuts: Array = sh[3] if sh.size() > 3 else []
	# keep a strip of sky round every other isle
	var near := {}
	for i in world.kind.size():
		if world.island[i] > 0:
			var x0 := i % world.w; var z0 := i / world.w
			for dz in range(-GAP, GAP + 1):
				for dx in range(-GAP, GAP + 1):
					near[(z0 + dz) * world.w + x0 + dx] = true
	var cells: Array = world.islands[0]["cells"]
	for z in range(1, world.h - 1):
		for x in range(1, world.w - 1):
			var i := world.idx(x, z)
			if world.island[i] > 0 or near.has(i):
				continue
			var dl := Vector2((x + 0.5 - c.x) / rr.x, (z + 0.5 - c.y) / rr.y).length()
			for bg in bulges:
				dl = minf(dl, Vector2((x + 0.5 - bg[0].x) / bg[1].x, (z + 0.5 - bg[0].y) / bg[1].y).length())
			if dl + shape.get_noise_2d(x, z) * 0.14 >= 1.0:
				continue
			if _cut(Vector2(x + 0.5, z + 0.5), cuts):
				continue
			var dc := Vector2((x + 0.5 - CORE_C.x) / CORE_R.x, (z + 0.5 - CORE_C.y) / CORE_R.y).length()
			var dep := -(2.0 + (1.0 - minf(dl, dc)) * 5.0 + drng.randf())
			if world.kind[i] == World.T_VOID:
				world.kind[i] = World.T_GROUND
				world.island[i] = 0
				world.depth[i] = dep
				cells.append(Vector2i(x, z))
			else:
				world.depth[i] = minf(world.depth[i], dep)

## Open ground on the main island (what you can build on, before anything is put down).
static func main_tiles(level: int, seed := 0, sk := 0.0) -> int:
	var w := World.new()
	make_world(w, level, seed, sk)
	var n := 0
	for i in w.kind.size():
		if w.island[i] == 0 and w.kind[i] == World.T_GROUND: n += 1
	w.free()
	return n

static var _tiles := {}
## How many tiles the next expansion adds (cached: it builds two worlds to count).
static func expand_gain(level: int, seed := 0, sk := 0.0) -> int:
	if level >= EXPAND.size():
		return 0
	for lv in [level, level + 1]:
		if not _tiles.has(Vector2i(lv, seed)): _tiles[Vector2i(lv, seed)] = main_tiles(lv, seed, sk)
	return int(_tiles[Vector2i(level + 1, seed)]) - int(_tiles[Vector2i(level, seed)])

# ------------------------------------------------------------------ farm-start islands
## Every farm-start island has about this much land before any expansion (the classic island's
## meadow is about the same), whatever its shape.
const FS_LAND := 1250
## Land kept for every bridge to land on (the isles'): a small rise of
## ground always meets each one, whatever the island's shape.
const FS_FEET := [[Vector2(62.5, 29.5), Vector2(3.4, 3.0)], [Vector2(34.5, 45.5), Vector2(3.4, 3.2)], [Vector2(28.5, 25.5), Vector2(3.0, 3.0)],
	[Vector2(26.0, 30.5), Vector2(3.0, 3.0)], [Vector2(44.5, 24.5), Vector2(3.0, 3.0)], [Vector2(39.5, 45.0), Vector2(3.0, 3.0)]]
## A farm-start island's fixed heart: the portal, its rack, the ferry and the landing.
const FS_CORE_C := Vector2(38.5, 35.0)
const FS_CORE_R := Vector2(8.5, 7.5)

## Is p inside one of the bays a farm-start island has cut out of its edge (never near the
## landing or a bridge's foot)?
static func _cut(p: Vector2, cuts: Array) -> bool:
	if cuts.is_empty() or p.distance_to(Vector2(LANDING.x, LANDING.z)) < 9.5:
		return false
	for f in FS_FEET:
		if Vector2((p.x - f[0].x) / (f[1].x + 1.5), (p.y - f[0].y) / (f[1].y + 1.5)).length() < 1.0:
			return false
	for ct in cuts:
		if Vector2((p.x - ct[0].x) / ct[1].x, (p.y - ct[0].y) / ct[1].y).length() < 1.0:
			return true
	return false

## A farm-start meadow's outline: each seed leans its own way (wide or deep, nudged off centre),
## grows two to four headlands in any direction and, scaled by sk, has about FS_LAND tiles of land.
static func fs_shape(level: int, seed: int, sk: float) -> Array:
	var r := RandomNumberGenerator.new(); r.seed = seed * 31 + 7
	var base := LOBE_R0 + LOBE_STEP * level
	var asp := r.randf_range(0.55, 1.7)
	var rr := Vector2(base.x * sqrt(asp), base.y / sqrt(asp)) * sk
	var c := LOBE_NW + LOBE_R0 + Vector2(r.randf_range(-6.0, 5.0), r.randf_range(-4.0, 3.0))
	var bulges: Array = []
	var n := r.randi_range(2, 4)
	var a0 := r.randf() * TAU
	for k in n:
		var a := a0 + TAU * float(k) / float(n) + r.randf_range(-0.5, 0.5)
		var at := c + Vector2(cos(a) * rr.x, sin(a) * rr.y) * r.randf_range(0.8, 1.0)
		bulges.append([at, Vector2(r.randf_range(4.5, 8.0), r.randf_range(4.0, 7.0)) * sqrt(sk)])
	for f in FS_FEET:
		bulges.append([f[0], f[1]])
	# one to three bays bitten out of the edge
	var cuts: Array = []
	var b0 := r.randf() * TAU
	for k in r.randi_range(1, 3):
		var a := b0 + TAU * float(k) / 3.0 + r.randf_range(-0.4, 0.4)
		var at := c + Vector2(cos(a) * rr.x, sin(a) * rr.y) * r.randf_range(0.85, 1.05)
		cuts.append([at, Vector2(r.randf_range(4.0, 7.5), r.randf_range(3.5, 6.5))])
	return [c, rr, bulges, cuts]

## The size scale that gives a seed's island about FS_LAND tiles (a few quick trial builds).
static func fs_scale(seed: int) -> float:
	var lo := 0.55; var hi := 1.5
	var best := 1.0; var bd := 1e9
	for i in 7:
		var mid := (lo + hi) * 0.5
		var n := main_tiles(0, seed, mid)
		if absf(n - FS_LAND) < bd: bd = absf(n - FS_LAND); best = mid
		if n < FS_LAND: lo = mid
		else: hi = mid
	return snappedf(best, 0.001)

## Is (x, z) inside a farm-start meadow (before the edge noise)? For placing its features.
static func _fs_in(p: Vector2, sh: Array, pad := 0.0) -> bool:
	var c: Vector2 = sh[0]; var rr: Vector2 = sh[1]
	var dl := Vector2((p.x - c.x) / maxf(1.0, rr.x - pad), (p.y - c.y) / maxf(1.0, rr.y - pad)).length()
	var dc := Vector2((p.x - FS_CORE_C.x) / (FS_CORE_R.x - pad), (p.y - FS_CORE_C.y) / (FS_CORE_R.y - pad)).length()
	if minf(dl, dc) >= 1.0:
		return false
	for ct in sh[3]:
		if Vector2((p.x - ct[0].x) / (ct[1].x + pad), (p.y - ct[0].y) / (ct[1].y + pad)).length() < 1.0: return false
	return true

## What makes a farm-start island its own besides its outline: from its seed, a grove of trees and a
## field of boulders always, and two of a pond, a stream, a cliff ridge, another grove or another
## boulder field, plus a scatter of lone trees and rocks. Laid out on the unexpanded island (so
## growing it keeps them where they were) away from the landing by the portal; kept tiles are left
## out. Returns {tile index: "tree" | "rock" | "water" | "cliff"}.
static func wild_fs(world: World, seed: int, sk: float, keep: Dictionary) -> Dictionary:
	var out := {}
	var plan := fs_plan(seed, sk)
	for f in plan:
		for t in f["tiles"]:
			var v: Vector2i = t
			if not world.inb(v.x, v.y): continue
			var i := world.idx(v.x, v.y)
			if world.island[i] != 0 or world.kind[i] != World.T_GROUND or keep.has(i) or world.paint.has(i) or world.bridge.has(i):
				continue
			if world.edge_dist(v.x, v.y, 3) < (1 if f["kind"] == "water" else 2):
				continue
			if not out.has(i): out[i] = f["what"] if typeof(f["what"]) == TYPE_STRING else f["what"][v]
	return out

static var _plans := {}
## A farm-start island's features (cached): [{kind, at: Vector2, tiles: [Vector2i], what: String or {Vector2i: String}}].
static func fs_plan(seed: int, sk: float) -> Array:
	var ck := "%d:%.3f" % [seed, sk]
	if _plans.has(ck):
		return _plans[ck]
	var sh := fs_shape(0, seed, sk)
	var r := RandomNumberGenerator.new(); r.seed = seed + 9001
	var land := Vector2(LANDING.x, LANDING.z)
	var kinds: Array = ["grove", "rocks"]
	var extra: Array = ["pond", "cliff", "stream", "grove", "rocks", "cliff", "pond"]
	for k in 2:
		var pick: String = extra[r.randi_range(0, extra.size() - 1)]
		while kinds.count(pick) >= (1 if pick in ["pond", "stream"] else 2) or (pick == "stream" and kinds.has("pond")) or (pick == "pond" and kinds.has("stream")):
			pick = extra[r.randi_range(0, extra.size() - 1)]
		kinds.append(pick)
	var plan: Array = []
	var used: Array = [land]
	for kd in kinds:
		var at := Vector2.INF
		for tries in 200:
			var p := Vector2(r.randf_range(14.0, 76.0), r.randf_range(14.0, 56.0))
			if not _fs_in(p, sh, 3.5 if kd != "stream" else 1.0): continue
			if p.distance_to(land) < (10.0 if kd != "stream" else 12.0): continue
			if used.any(func(u): return p.distance_to(u) < 9.0): continue
			at = p
			break
		if at == Vector2.INF: continue
		used.append(at)
		var f := {"kind": kd, "at": at, "tiles": [], "what": ""}
		match kd:
			"grove", "rocks":
				var rad := Vector2(r.randf_range(3.4, 4.8), r.randf_range(2.8, 3.8)) if kd == "grove" else Vector2(r.randf_range(2.4, 3.4), r.randf_range(2.0, 2.8))
				var ang := r.randf() * PI
				var what := {}
				for dz in range(-6, 7):
					for dx in range(-6, 7):
						var q := Vector2(dx, dz).rotated(ang)
						var e := Vector2(q.x / rad.x, q.y / rad.y).length()
						if e > 1.0: continue
						var dens := 0.85 if kd == "grove" else 0.6
						if r.randf() > dens * (1.15 - e * 0.5): continue
						var t := Vector2i(int(floor(at.x)) + dx, int(floor(at.y)) + dz)
						f["tiles"].append(t)
						what[t] = ("tree" if r.randf() < 0.92 else "rock") if kd == "grove" else ("rock" if r.randf() < 0.88 else "tree")
				f["what"] = what
			"pond":
				var pr := Vector2(r.randf_range(1.8, 2.8), r.randf_range(1.6, 2.4))
				for dz in range(-3, 4):
					for dx in range(-3, 4):
						if Vector2(dx / pr.x, dz / pr.y).length() < 1.0: f["tiles"].append(Vector2i(int(floor(at.x)) + dx, int(floor(at.y)) + dz))
				f["what"] = "water"
			"stream":
				var p := at
				var dir := Vector2.from_angle(r.randf() * TAU)
				for st in r.randi_range(12, 18):
					f["tiles"].append(Vector2i(int(floor(p.x)), int(floor(p.y))))
					dir = dir.rotated(r.randf_range(-0.45, 0.45))
					p += dir
				f["what"] = "water"
			"cliff":
				# a curved ridge of bare rock, two tiles thick: it stays (you walk round it)
				var dir := Vector2.from_angle(r.randf() * TAU)
				var p := at - dir * 4.0
				var bend := r.randf_range(-0.16, 0.16)
				for st in r.randi_range(8, 12):
					var side := dir.orthogonal()
					for o in [0.0, 1.0]:
						var q: Vector2 = p + side * float(o)
						f["tiles"].append(Vector2i(int(floor(q.x)), int(floor(q.y))))
					dir = dir.rotated(bend)
					p += dir
				f["what"] = "cliff"
		plan.append(f)
	# a scatter of lone trees and rocks across the meadow
	var lone := {"kind": "lone", "at": land, "tiles": [], "what": {}}
	for k in r.randi_range(10, 16):
		for tries in 40:
			var p := Vector2(r.randf_range(12.0, 78.0), r.randf_range(12.0, 58.0))
			if not _fs_in(p, sh, 2.0) or p.distance_to(land) < 7.0: continue
			var t := Vector2i(int(floor(p.x)), int(floor(p.y)))
			lone["tiles"].append(t)
			lone["what"][t] = "tree" if r.randf() < 0.65 else "rock"
			break
	plan.append(lone)
	_plans[ck] = plan
	return plan

# ------------------------------------------------------------------ the wild
## A procedural home's wild land: copses of trees, boulders and a pond or a stream out in the
## meadow, away from the farm. Returns {tile index: "tree" | "rock" | "water"}; keep is a set of
## tile indices to leave alone (paths, kept-clear spots, lots). Deterministic for a seed.
static func wild(world: World, seed: int, keep: Dictionary) -> Dictionary:
	var out := {}
	if seed == 0:
		return out
	var r := RandomNumberGenerator.new(); r.seed = seed + 101
	var cand: Array = []
	for i in world.kind.size():
		if world.island[i] != 0 or world.kind[i] != World.T_GROUND or keep.has(i) or world.paint.has(i) or world.bridge.has(i):
			continue
		var x := i % world.w; var z := i / world.w
		var dc := Vector2((x + 0.5 - CORE_C.x) / CORE_R.x, (z + 0.5 - CORE_C.y) / CORE_R.y).length()
		if dc < 1.1 or world.edge_dist(x, z, 3) < 2:
			continue
		cand.append(i)
	if cand.is_empty():
		return out
	var ok_tile := func(i: int) -> bool:
		return i >= 0 and i < world.kind.size() and world.island[i] == 0 and world.kind[i] == World.T_GROUND and not keep.has(i) and not world.paint.has(i) and not out.has(i)
	# copses: short random walks of trees with the odd boulder
	for k in r.randi_range(10, 15):
		var i: int = cand[r.randi_range(0, cand.size() - 1)]
		var what := "tree" if r.randf() < 0.7 else "rock"
		for s in r.randi_range(3, 10):
			if ok_tile.call(i): out[i] = what if r.randf() < 0.8 else ("rock" if what == "tree" else "tree")
			var dv: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][r.randi_range(0, 3)]
			i += dv.y * world.w + dv.x
	# water: a round pond, or a stream winding in from the island's edge
	var wi: int = cand[r.randi_range(0, cand.size() - 1)]
	if r.randf() < 0.5:
		var wx := wi % world.w; var wz := wi / world.w
		var pr := Vector2(r.randf_range(1.6, 2.8), r.randf_range(1.4, 2.4))
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				if Vector2(dx / pr.x, dz / pr.y).length() < 1.0 and ok_tile.call(wi + dz * world.w + dx):
					out[wi + dz * world.w + dx] = "water"
	else:
		var p := Vector2(wi % world.w, wi / world.w)
		var dir := Vector2.from_angle(r.randf() * TAU)
		for s in r.randi_range(10, 18):
			var ti := int(p.y) * world.w + int(p.x)
			if ok_tile.call(ti): out[ti] = "water"
			dir = dir.rotated(r.randf_range(-0.5, 0.5))
			p += dir
	return out

## Every bit of open ground on the main island has to be reachable from the house: wild tiles that
## shut a pocket in are taken out again until none do. Returns the wild that's left.
static func open_up(world: World, start: Vector2i, wild_t: Dictionary) -> Dictionary:
	for _round in 12:
		var seen := {}
		var q: Array = [world.idx(start.x, start.y)]
		seen[q[0]] = true
		var head := 0
		while head < q.size():
			var i: int = q[head]; head += 1
			for dv in [1, -1, world.w, -world.w]:
				var j: int = i + dv
				if j < 0 or j >= world.kind.size() or seen.has(j): continue
				if world.kind[j] != World.T_GROUND and not world.bridge.has(j): continue
				seen[j] = true
				q.append(j)
		var shut: Array = []
		for i in world.kind.size():
			if world.island[i] == 0 and world.kind[i] == World.T_GROUND and not seen.has(i): shut.append(i)
		if shut.is_empty():
			break
		# open the wild next to each pocket
		for i in shut:
			for dv in [1, -1, world.w, -world.w]:
				var j: int = i + dv
				if wild_t.has(j):
					wild_t.erase(j)
					world.kind[j] = World.T_GROUND
					world.level[j] = 0          # a cliff tile opened up is level meadow again
	return wild_t

## A farm-start island's version: each shut-in pocket gets one gap per round (the wild tile beside
## it nearest open ground, never a cliff unless there's nothing else), so a ridge or a grove that
## closes off a corner gets a way through instead of being cleared away. Returns the wild that's left.
static func open_up_fs(world: World, start: Vector2i, wild_t: Dictionary) -> Dictionary:
	for _round in 60:
		var seen := PackedByteArray(); seen.resize(world.kind.size())
		var q: Array = [world.idx(start.x, start.y)]
		seen[q[0]] = 1
		var head := 0
		while head < q.size():
			var i: int = q[head]; head += 1
			for dv in [1, -1, world.w, -world.w]:
				var j: int = i + dv
				if j < 0 or j >= world.kind.size() or seen[j] == 1: continue
				if world.kind[j] != World.T_GROUND and not world.bridge.has(j): continue
				seen[j] = 1
				q.append(j)
		# every shut-in pocket left, each as a whole
		var pockets: Array = []
		var in_p := {}
		for i in world.kind.size():
			if world.island[i] != 0 or world.kind[i] != World.T_GROUND or seen[i] == 1 or in_p.has(i): continue
			var pocket: Array = [i]; in_p[i] = true
			var ph := 0
			while ph < pocket.size():
				var a: int = pocket[ph]; ph += 1
				for dv in [1, -1, world.w, -world.w]:
					var b: int = a + dv
					if b >= 0 and b < world.kind.size() and not in_p.has(b) and world.kind[b] == World.T_GROUND and seen[b] == 0:
						in_p[b] = true; pocket.append(b)
			pockets.append(pocket)
		if pockets.is_empty():
			break
		var opened := 0
		for pocket in pockets:
			# one gap per pocket: a wild tile (or a rim tree) beside it, best one also beside open ground
			var best := -1; var bs := -1e9
			for i in pocket:
				for dv in [1, -1, world.w, -world.w]:
					var j: int = i + dv
					if j < 0 or j >= world.kind.size(): continue
					var rim: bool = world.kind[j] == World.T_BLOCK and not wild_t.has(j) and not world.no_deco.has(j) and world.island[j] == 0
					if not wild_t.has(j) and not rim: continue
					var sc := 0.0
					for dv2 in [1, -1, world.w, -world.w]:
						var k2: int = j + dv2
						if k2 >= 0 and k2 < seen.size() and seen[k2] == 1: sc += 10.0
					if wild_t.get(j, "") == "cliff": sc -= 5.0
					if wild_t.get(j, "") == "water": sc -= 2.0
					if sc > bs: bs = sc; best = j
			if best < 0:
				# shut in by something that isn't wild (the island's edge and a fixed blocker): a
				# nook that small just gets a boulder of its own instead of being dead ground
				if pocket.size() <= 6:
					for i in pocket:
						wild_t[i] = "rock"; world.kind[i] = World.T_BLOCK; world.props[i] = "rock"
				continue
			wild_t.erase(best)
			world.kind[best] = World.T_GROUND
			world.level[best] = 0
			world.props.erase(best)
			opened += 1
		if opened == 0:
			break
	return wild_t

## Feeders left out over what used to be ground (the Orchard Isle moved when the islands grew)
## go back to open ground near the pot.
static func rescue_feeders(world: World) -> void:
	var fs: Array = Save.d.get("feeders", [])
	for f in fs:
		var x := float(f.get("x", 0.0)); var z := float(f.get("z", 0.0))
		if not world.inb(int(floor(x)), int(floor(z))) or world.is_void(x, z) or world.kind[world.idx(int(floor(x)), int(floor(z)))] != World.T_GROUND:
			var others: Array = fs.filter(func(o): return o != f).map(func(o): return Vector3(float(o.get("x", 0.0)), 0, float(o.get("z", 0.0))))
			var p := world.free_spot_near(Econ.FEEDER_START, others, 2.8, 0.5, 14.0)
			f["x"] = snappedf(p.x, 0.1); f["z"] = snappedf(p.z, 0.1)
