class_name ShopStock
extends RefCounted
## What a vendor sells and how a sale works (content/rules/shops.json). A stock is a list of rows
## {id, rar, k, left}: id is a utility item id, "repair", "armor_up", "backpack", "gear:<gear id>" (gloves,
## armor or boots) or "perk:<perk id>"; k is the theme's price multiplier. The stock is fixed per shop
## theme, the same in every match and in every game; only `left` changes, and online the host keeps
## that count (Shops).
##
## For other parts: ShopStock.price(h, row), can_buy(h, row) (a reason, "" when fine), owned(h, row)
## and sell(h, row) (takes the gems, hands over the item; true on success).

const NO_GEMS := "Not enough gems"      # can_buy's reason when the price is more than the hunter's gems

static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/shops.json"))
		_rules = d if d is Dictionary else {}
	return _rules

static func theme(id: String) -> Dictionary:
	return (rules().get("themes", {}) as Dictionary).get(id, {})

## Every entry any vendor sells (for checks and the never-sold rule).
static func all_entries() -> Array:
	var out: Array = []
	var themes: Dictionary = rules().get("themes", {})
	for t in themes:
		for e in themes[t].get("sells", []):
			if not out.has(e):
				out.append(e)
	return out

# ------------------------------------------------------------------ the fixed stock

## The stock a vendor of this theme starts every match with: its whole `sells` list.
static func stock_of(theme_id: String) -> Array:
	var rows: Array = []
	var th := theme(theme_id)
	for e in th.get("sells", []):
		rows.append(_row(String(e), th))
	return rows

static func _row(entry: String, th: Dictionary) -> Dictionary:
	var rs := rules()
	var kind := kind_of(entry)
	var rar: int = int(th.get("gear_rar", rs.get("gear_rar", 1))) if kind == "gear" else 0
	return {"id": entry, "rar": rar, "k": float(th.get("price_k", 1.0)),
		"left": int((rs.get("left", {}) as Dictionary).get(kind, 1))}

## "util", "repair", "armor_up", "backpack", "gear" or "perk".
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
		"armor_up": return "Armor upgrade"
		"backpack": return "Backpack upgrade"
		"gear": return "%s  (%s)" % [String(Gear.ALL[r]["name"]), String(Data.RARITY[int(row["rar"])]["name"])]
		_: return String(Data.PERKS[r]["name"])

## The row's one plain line, from live data: where the hunter stands now for upgrades, what it does
## (and how many they carry) for everything else.
static func line_of(h, row: Dictionary) -> String:
	var r := ref(String(row["id"]))
	var n := owned(h, row)
	match kind_of(String(row["id"])):
		"repair": return "Armor %d/%d. Back to full on the spot." % [int(h.armor), int(h.max_armor)]
		"armor_up":
			var top := Hunter.ARMOR_TIERS.size() - 1
			var next := String(Hunter.ARMOR_TIERS[mini(n + 1, top)][0])
			return _next_line(String(Hunter.ARMOR_TIERS[n][0]), n < top, "%s armor" % next)
		"backpack": return _next_line(Backpacks.name_of(n), n < Backpacks.top(), Backpacks.label(n + 1))
		"gear": return ("Worn. " if n > 0 else "") + Gear.desc_of(r, int(row["rar"]))
		"util": return _carried(n, String(UtilityBelt.def(r).get("desc", "")))
		_: return _carried(n, String(Data.PERKS[r]["desc"]))

static func _next_line(now: String, more: bool, next: String) -> String:
	return "Now %s. Next: %s." % [now, next] if more else "Now %s, the top tier." % now

static func _carried(n: int, desc: String) -> String:
	return desc if n == 0 else "You have %d. %s" % [n, desc]

static func icon_of(row: Dictionary) -> String:
	var r := ref(String(row["id"]))
	match kind_of(String(row["id"])):
		"util": return UtilityBelt.icon_of(r)
		"repair": return "anvil"
		"armor_up": return "brightshield"
		"backpack": return "satchel"
		"gear": return Gear.icon_of(r)
		_: return String(Data.PERKS[r]["icon"])

static func col_of(row: Dictionary) -> Color:
	var r := ref(String(row["id"]))
	match kind_of(String(row["id"])):
		"util": return UtilityBelt.col_of(r)
		"gear": return Gear.ALL[r].get("col", Color.WHITE)
		"perk": return Data.PERKS[r]["col"]
		"backpack": return Color("ffb0a0")
		_: return Color("dfe9f7")

# ------------------------------------------------------------------ prices and owning

## Gems this costs this hunter now (-1: not for sale to them any more), with the theme's multiplier.
static func price(h, row: Dictionary) -> int:
	var base := _base_price(h, row)
	return base if base < 0 else int(round(base * float(row.get("k", 1.0))))

static func _base_price(h, row: Dictionary) -> int:
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
		"gear": return int((rs.get("gear_price", []) as Array)[int(row["rar"])])
		_:
			var kind := PerkOrbs.kind_of(r)
			var base := int((rs.get("perk_price", {}) as Dictionary).get(kind, 60))
			return base + int(rs.get("perk_stack_extra", 0)) * h.perk_n(r)

## How many the hunter holds (belt charges, perk stacks; the tier for upgrades), for line_of and bots.
static func owned(h, row: Dictionary) -> int:
	var r := ref(String(row["id"]))
	match kind_of(String(row["id"])):
		"util": return UtilityBelt.count(h, r)
		"armor_up": return h.armor_tier
		"backpack": return h.backpack
		"gear": return 1 if _worn(h, r, int(row["rar"])) else 0
		"perk": return h.perk_n(r)
		_: return int(h.armor)

## Is this piece (at this rarity or better) on the hunter already, in whichever slot it fits?
static func _worn(h, gid: String, rar: int) -> bool:
	for cur in h.gear:
		if not (cur as Dictionary).is_empty() and String(cur["id"]) == gid and int(cur.get("rar", 0)) >= rar:
			return true
	return false

## Why this hunter can't buy the row right now ("" when they can). Stock left is the vendor's business (Shops.why_not).
static func can_buy(h, row: Dictionary) -> String:
	var r := ref(String(row["id"]))
	var cost := price(h, row)
	if cost < 0:
		return "Maxed"
	if int(h.gems) < cost:
		return NO_GEMS
	match kind_of(String(row["id"])):
		"util": return "" if UtilityBelt.has_room(h, r) else "Belt full"
		"repair": return "" if h.armor < h.max_armor else "Armor is full"
		"gear": return "Already worn" if _worn(h, r, int(row["rar"])) else ""
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
		"gear":
			h.gear[Gear.slot_on(h, r)] = {"id": r, "rar": int(row["rar"])}
			h.refresh_gear()
		_: PerkOrbs.grant(h, r)
	h.gems -= cost
	return true
