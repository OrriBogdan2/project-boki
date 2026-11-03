class_name ShopStock
extends RefCounted
## What a vendor sells and how a sale works (content/rules/shops.json). A stock is a list of rows
## {id, rar, left}: id is a utility item id, "repair", "armor_up", "backpack", "boots:<gear id>" or
## "perk:<perk id>". The rolling is seeded per match and shop, so every game rolls the same stock;
## only `left` changes, and online the host keeps that count (Shops).
##
## For other parts: ShopStock.price(h, row), can_buy(h, row) (a reason, "" when fine), owned(h, row)
## and sell(h, row) (takes the gems, hands over the item; true on success).

static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/shops.json"))
		_rules = d if d is Dictionary else {}
	return _rules

static func theme(id: String) -> Dictionary:
	return (rules().get("themes", {}) as Dictionary).get(id, {})

## Every entry any vendor can ever stock (for checks and the never-sold rule).
static func all_entries() -> Array:
	var out: Array = []
	var themes: Dictionary = rules().get("themes", {})
	for t in themes:
		for e in (themes[t].get("always", []) as Array) + (themes[t].get("pool", []) as Array):
			if not out.has(e):
				out.append(e)
	return out

# ------------------------------------------------------------------ rolling

## The stock one vendor starts a match with (idx = its place in the map's vendor list).
static func roll(match_seed: int, idx: int, theme_id: String) -> Array:
	var rs := rules()
	var th := theme(theme_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("shops%d_%d" % [match_seed + int(rs.get("seed_add", 0)), idx])
	var span: Array = rs.get("stock", [3, 5])
	var want := rng.randi_range(int(span[0]), int(span[1]))
	var picked: Array = (th.get("always", []) as Array).duplicate()
	var pool: Array = (th.get("pool", []) as Array).duplicate()
	while picked.size() < want and not pool.is_empty():
		picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	var rows: Array = []
	for e in picked:
		rows.append(_row(rng, String(e)))
	return rows

static func _row(rng: RandomNumberGenerator, entry: String) -> Dictionary:
	var rs := rules()
	var kind := kind_of(entry)
	var span: Array = (rs.get("left", {}) as Dictionary).get(kind, [1, 1])
	var rar := 0
	if kind == "boots":
		var br: Array = rs.get("boots_rar", [1, 3])
		rar = rng.randi_range(int(br[0]), int(br[1]))
	return {"id": entry, "rar": rar, "left": rng.randi_range(int(span[0]), int(span[1]))}

## "util", "repair", "armor_up", "backpack", "boots" or "perk".
static func kind_of(entry: String) -> String:
	if entry.contains(":"):
		return entry.get_slice(":", 0)
	return entry if entry in ["repair", "armor_up", "backpack"] else "util"

static func ref(entry: String) -> String:
	return entry.get_slice(":", 1) if entry.contains(":") else entry

# ------------------------------------------------------------------ looks

static func name_of(row: Dictionary) -> String:
	var r := ref(String(row["id"]))
	match kind_of(String(row["id"])):
		"util": return UtilityBelt.name_of(r)
		"repair": return "Field repair"
		"armor_up": return "Armour upgrade"
		"backpack": return "Backpack upgrade"
		"boots": return "%s  (%s)" % [String(Gear.ALL[r]["name"]), String(Data.RARITY[int(row["rar"])]["name"])]
		_: return String(Data.PERKS[r]["name"])

static func desc_of(row: Dictionary) -> String:
	var r := ref(String(row["id"]))
	match kind_of(String(row["id"])):
		"util": return String(UtilityBelt.def(r).get("desc", ""))
		"repair": return "Armour back to full, on the spot."
		"armor_up": return "Raises your armour to its next tier (more plates)."
		"backpack": return "A bigger pack: more room for what you carry home."
		"boots": return Gear.desc_of(r, int(row["rar"]))
		_: return String(Data.PERKS[r]["desc"])

static func icon_of(row: Dictionary) -> String:
	var r := ref(String(row["id"]))
	match kind_of(String(row["id"])):
		"util": return UtilityBelt.icon_of(r)
		"repair": return "anvil"
		"armor_up": return "brightshield"
		"backpack": return "satchel"
		"boots": return Gear.icon_of(r)
		_: return String(Data.PERKS[r]["icon"])

static func col_of(row: Dictionary) -> Color:
	var r := ref(String(row["id"]))
	match kind_of(String(row["id"])):
		"util": return UtilityBelt.col_of(r)
		"boots": return Gear.ALL[r].get("col", Color.WHITE)
		"perk": return Data.PERKS[r]["col"]
		"backpack": return Color("ffb0a0")
		_: return Color("dfe9f7")

# ------------------------------------------------------------------ prices and owning

## Gems this costs this hunter now (-1: not for sale to them any more).
static func price(h, row: Dictionary) -> int:
	var rs := rules()
	var r := ref(String(row["id"]))
	match kind_of(String(row["id"])):
		"util": return int(round(float(UtilityBelt.price_of(r)) * float(rs.get("util_k", 1.0))))
		"repair": return int(rs.get("repair_price", 20))
		"armor_up":
			var ladder: Array = rs.get("armor_tier_price", [])
			var next: int = h.armor_tier + 1
			return int(ladder[next]) if next < mini(ladder.size(), Hunter.ARMOR_TIERS.size()) else -1
		"backpack": return Backpacks.shop_price(h)
		"boots": return int((rs.get("boots_price", []) as Array)[int(row["rar"])])
		_:
			var kind := PerkOrbs.kind_of(r)
			var base := int((rs.get("perk_price", {}) as Dictionary).get(kind, 60))
			return base + int(rs.get("perk_stack_extra", 0)) * h.perk_n(r)

## How many the hunter holds (belt charges, perk stacks), for the shop's "owned" column.
static func owned(h, row: Dictionary) -> int:
	var r := ref(String(row["id"]))
	match kind_of(String(row["id"])):
		"util": return UtilityBelt.count(h, r)
		"armor_up": return h.armor_tier
		"backpack": return h.backpack
		"boots": return 1 if _worn_boots(h, r, int(row["rar"])) else 0
		"perk": return h.perk_n(r)
		_: return int(h.armor)

## The owned column as words: a count for stackable things, the current level for upgrades.
static func owned_text(h, row: Dictionary) -> String:
	var n := owned(h, row)
	match kind_of(String(row["id"])):
		"repair": return "Armour %d/%d" % [int(h.armor), int(h.max_armor)]
		"armor_up": return "Tier: %s" % String(Hunter.ARMOR_TIERS[n][0])
		"backpack": return "Pack: %s" % Backpacks.name_of(n)
		"boots": return "Worn" if n > 0 else "Owned 0"
		_: return "Owned %d" % n

static func _worn_boots(h, gid: String, rar: int) -> bool:
	var cur: Dictionary = h.gear[3]
	return not cur.is_empty() and String(cur["id"]) == gid and int(cur.get("rar", 0)) >= rar

## Why this hunter can't buy the row right now ("" when they can). Stock left is the vendor's business (Shops.why_not).
static func can_buy(h, row: Dictionary) -> String:
	var r := ref(String(row["id"]))
	var cost := price(h, row)
	if cost < 0:
		return "Maxed"
	if int(h.gems) < cost:
		return "Not enough gems"
	match kind_of(String(row["id"])):
		"util": return "" if UtilityBelt.has_room(h, r) else "Belt full"
		"repair": return "" if h.armor < h.max_armor else "Armour is full"
		"boots": return "Already worn" if _worn_boots(h, r, int(row["rar"])) else ""
		"perk": return "" if h.perk_open(r) else "Maxed"
	return ""

# ------------------------------------------------------------------ selling

## Takes the gems and hands over the item. False (and nothing changes) when can_buy says no.
static func sell(h, row: Dictionary) -> bool:
	if can_buy(h, row) != "":
		return false
	var r := ref(String(row["id"]))
	var cost := price(h, row)
	match kind_of(String(row["id"])):
		"util": UtilityBelt.grant(h, r, 1)
		"repair": h.armor = h.max_armor
		"armor_up": h.armor_gain(float(Hunter.ARMOR_TIERS[h.armor_tier + 1][2]) - h.armor_xp)
		"backpack": return Backpacks.shop_upgrade(h)      # takes its own gems and trades the old pack in
		"boots":
			h.gear[3] = {"id": r, "rar": int(row["rar"])}
			h.refresh_gear()
		_: PerkOrbs.grant(h, r)
	h.gems -= cost
	return true
