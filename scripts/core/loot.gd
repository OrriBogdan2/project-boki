class_name Loot
## Things you can carry home from an expedition, as plain dictionaries (they go in the save as-is):
##   gear    {t:"gear", id, rar, uid}              a piece of gear for one of the five slots (Gear)
##   valuable{t:"val", id, uid}                    sold at home; a Soul Ember revives a kin
##   rare egg{t:"val", id:"rare_egg", sp, boss, uid}  a lair boss's egg: takes a pack slot, hatches at home
## Weapons are not loot any more: every hunter carries one fixed signature weapon and grows it with
## upgrades (WeaponUps). Their worth drives smart loot and what the backpack keeps. The element
## riders of a Brand upgrade run on the weapon's own hits (Hunter._emit_shot / _strike call rider()).

## Elements a Brand upgrade puts on your weapon (WeaponUps), one per biome style (the Greenreach meadow has none of its own).
const ELEMENTS := {
	"fire": {"name": "Ember", "col": Color("ff8a3a"), "biome": "ember", "icon": "fireball",
		"rider": "Burns: 5 damage a second for 3s."},
	"frost": {"name": "Frost", "col": Color("bff0ff"), "biome": "frost", "icon": "snare",
		"rider": "Chills: slows for 1s, and every 5th hit freezes them in place."},
	"storm": {"name": "Storm", "col": Color("fff27a"), "biome": "storm", "icon": "chain",
		"rider": "Every 4th hit arcs to 2 more foes for half damage."},
	"venom": {"name": "Venom", "col": Color("9aff6a"), "biome": "bloom", "icon": "burst",
		"rider": "Poisons: 3 damage a second and a light slow."},
	"void": {"name": "Void", "col": Color("b08aff"), "biome": "gloom", "icon": "shadowstep",
		"rider": "Drains: heals you for 8% of the damage you deal."},
}

## Treasure to sell at home, and the Soul Ember the Soul Shrine needs.
const VALUABLES := {
	"old_coin": {"name": "Old Coin", "col": Color("e8c27a"), "value": 14, "rar": 1, "desc": "Sells for a few gems."},
	"sky_pearl": {"name": "Sky Pearl", "col": Color("cfeaff"), "value": 32, "rar": 2, "desc": "Sells well."},
	"kin_idol": {"name": "Boki Idol", "col": Color("ffb0d0"), "value": 58, "rar": 3, "desc": "A little carved Boki. Collectors pay a lot."},
	"crown_shard": {"name": "Crown Shard", "col": Color("ffd23f"), "value": 105, "rar": 4, "desc": "A piece of an old crown. Worth a fortune."},
	"soul_ember": {"name": "Soul Ember", "col": Color("9ff0e0"), "value": 140, "rar": 4, "desc": "A warm, glowing ember. The Soul Shrine needs one to raise it, and one for every Boki it brings back."},
	# worth more than anything else you can carry, so smart loot and a full pack always keep it
	"rare_egg": {"name": "Rare Egg", "col": Color("ffcf4a"), "value": 400, "rar": 4, "desc": "A boss's egg, big and glowing gold. Carry it home and it hatches into a rare Boki."},
}

## A lair boss's egg as a backpack item: which rare kin hatches from it, and who guarded it.
static func rare_egg(sp: String, boss := "") -> Dictionary:
	return {"t": "val", "id": "rare_egg", "sp": sp, "boss": boss, "uid": _uid()}

static func is_rare_egg(it: Dictionary) -> bool:
	return String(it.get("t", "")) == "val" and String(it.get("id", "")) == "rare_egg"

## What a piece of gear is worth by rarity (Common..Legendary).
const GEAR_VALUE := [3, 8, 18, 36, 70]

# ------------------------------------------------------------------ making things
static func _uid() -> String:
	return "i%d%d" % [Time.get_ticks_usec() % 10000000, randi() % 10000]

static func gear(id: String, rar: int) -> Dictionary:
	return {"t": "gear", "id": id, "rar": rar, "uid": _uid()}

static func valuable(id: String) -> Dictionary:
	return {"t": "val", "id": id, "uid": _uid()}

## Worth keeping: gear that still exists, and treasure. (Old saved weapons are scrapped on load, Save.)
static func keepable(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	match String(it.get("t", "")):
		"gear": return Gear.ALL.has(String(it.get("id", "")))
		"val": return VALUABLES.has(String(it.get("id", "")))
	return false

## A copy of an item as it goes home.
static func clean(it: Dictionary) -> Dictionary:
	return it.duplicate()

# ------------------------------------------------------------------ what things are called and worth
static func rar_of(it: Dictionary) -> int:
	if String(it.get("t", "")) == "val":
		return int(VALUABLES.get(String(it.get("id", "")), {}).get("rar", 1))
	return clampi(int(it.get("rar", 0)), 0, Data.RARITY.size() - 1)

static func name_of(it: Dictionary) -> String:
	if String(it.get("t", "")) == "val":
		if is_rare_egg(it) and Data.KIN.has(String(it.get("sp", ""))):
			return "Rare " + Data.egg_name(String(it["sp"]))
		return String(VALUABLES.get(String(it.get("id", "")), {}).get("name", "Trinket"))
	var gd: Dictionary = Gear.ALL.get(String(it.get("id", "")), {})
	var r := rar_of(it)
	return "%s%s" % [(String(Data.RARITY[r]["name"]) + " ") if r > 0 else "", gd.get("name", it.get("id", "Gear"))]

## The colour that marks it.
static func col_of(it: Dictionary) -> Color:
	if String(it.get("t", "")) == "val":
		return VALUABLES.get(String(it.get("id", "")), {}).get("col", Color("ffd36a"))
	return Palette.rarity(rar_of(it))

static func icon_of(it: Dictionary) -> String:
	if String(it.get("t", "")) == "val":
		return "bond" if String(it.get("id", "")) == "soul_ember" else ("egg" if is_rare_egg(it) else "gem")
	return Gear.icon_of(String(it.get("id", "")))

## One line under the name: what it does.
static func sub_of(it: Dictionary) -> String:
	if String(it.get("t", "")) == "val":
		if is_rare_egg(it): return "Rare Egg  ·  carry it home and it hatches a rare Boki"
		return "Treasure  ·  sells for %d gems" % sell_price(it) if String(it.get("id", "")) != "soul_ember" else "Revives a Boki at the Soul Shrine"
	var id := String(it.get("id", ""))
	if not Gear.ALL.has(id): return "Gear"
	return "%s  ·  %s" % [Gear.slot_name(id), Gear.stat_text(id, rar_of(it))]

static func value(it: Dictionary) -> int:
	if it.is_empty():
		return 0
	if String(it.get("t", "")) == "val":
		return int(VALUABLES.get(String(it.get("id", "")), {}).get("value", 5))
	return GEAR_VALUE[rar_of(it)]

## What the armory pays for it (a bit over half its worth).
static func sell_price(it: Dictionary) -> int:
	if String(it.get("t", "")) == "val":
		return value(it)
	return maxi(1, int(round(value(it) * 0.6)))

## Scrap from breaking it down at the armory, for upgrades and the farm.
static func scrap_of(it: Dictionary) -> int:
	return [1, 1, 2, 4, 7][rar_of(it)]

# ------------------------------------------------------------------ rolling drops
## A valuable by rarity tier (0 small, 1 good, 2 great).
static func roll_valuable(rng: RandomNumberGenerator, tier: int) -> String:
	var x := rng.randf()
	match tier:
		0: return "old_coin" if x < 0.8 else "sky_pearl"
		1: return "old_coin" if x < 0.35 else ("sky_pearl" if x < 0.8 else "kin_idol")
	return "sky_pearl" if x < 0.3 else ("kin_idol" if x < 0.7 else "crown_shard")

# ------------------------------------------------------------------ element riders
## Adds the weapon's element to one attack's hit options. Called once per attack.
static func rider(h, extra: Dictionary, dmg: float) -> void:
	var el: String = h.welem
	if el == "":
		return
	h.el_n += 1
	var n: int = h.el_n
	match el:
		"fire":
			extra["burn"] = maxf(float(extra.get("burn", 0.0)), 5.0)
		"frost":
			extra["slow"] = maxf(float(extra.get("slow", 0.0)), 1.0)
			if n % 5 == 0:
				extra["root"] = maxf(float(extra.get("root", 0.0)), 0.6)
		"storm":
			if n % 4 == 0 and not extra.has("fx_hit"):
				extra["fx_hit"] = [{"type": "chain", "count": 2, "first": 5.0, "dmg": dmg * 0.5, "color": "#fff27a", "skip_here": true}]
				extra["fx_ctx"] = {"slot": "weapon", "ability": "storm"}
		"venom":
			extra["burn"] = maxf(float(extra.get("burn", 0.0)), 3.0)
			extra["slow"] = maxf(float(extra.get("slow", 0.0)), 0.35)
		"void":
			extra["leech"] = 0.08
