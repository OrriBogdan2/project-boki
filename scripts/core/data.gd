extends Node
## Every tunable definition in the game lives here: classes, weapons, kin, monsters, crops.
## Distances are in tiles (1 unit), speeds in tiles per second, times in seconds.

const TEAM_COLORS := [Color("f2a24a"), Color("5ab0f0"), Color("e0607e"), Color("8fd16a"), Color("b48cf2"), Color("f0d45a"),
	Color("4ad8c8"), Color("ff8ad8"), Color("c8a07a"), Color("9ab4ff"), Color("ff6a4a"), Color("b8e05a"), Color("e6e6f0"),
	Color("7a8cff"), Color("ffb8a0"), Color("5ae08a"), Color("d07aff"), Color("ffe08a"), Color("6ac0ff"), Color("ff9a5a")]
## Every expedition has about this many hunters, however they're split into squads.
const MATCH_PLAYERS := 20

const CLASSES := {
	"light": {
		"name": "Light", "color": Color("c9bcff"), "hp": 124, "speed": 4.4, "dashes": 1, "mass": 0.85, "scale": 0.9, "hit_r": 0.35,
		"ex_dist": 5.0, "ex_time": 0.2, "ex_cd": 12.0, "glide_cap": 1.2,
		"weapon": "smg", "weapons": ["smg", "sniper", "twin_blades", "longbow", "coilcaster"],
		"desc": "Fast and fragile. The fastest dash, the longest glide, and hits throw you furthest.",
	},
	"medium": {
		"name": "Medium", "color": Color("9ee2a0"), "hp": 145, "speed": 4.4, "dashes": 1, "mass": 1.0, "scale": 1.0, "hit_r": 0.40,
		"ex_dist": 4.6, "ex_time": 0.2, "ex_cd": 13.0, "glide_cap": 1.0,
		"weapon": "rifle", "weapons": ["rifle", "burst_rifle", "longsword", "spellstaff", "quill_rifle"],
		"desc": "The all-rounder: middle health, speed, dash and glide.",
	},
	"heavy": {
		"name": "Heavy", "color": Color("e6dbc4"), "hp": 193, "speed": 4.4, "dashes": 2, "mass": 1.35, "scale": 1.14, "hit_r": 0.50,
		"ex_dist": 4.2, "ex_time": 0.21, "ex_cd": 15.0, "glide_cap": 0.85,
		"weapon": "shotgun", "weapons": ["shotgun", "minigun", "greatsword", "tower_shield"],
		"desc": "Slow and tough. Two short dashes, the most health, and very hard to push off a ledge.",
	},
}

const NO_AMMO_MAG := 999         # rounds a weapon with no ammo nominally holds (never shown, never drained for good)

## Fallback only: every real weapon lives in content/weapons.
const WEAPONS := {
	"rifle": {"name": "Rifle", "dmg": 3.87, "rate": 0.08, "speed": 110.0, "mag": 30, "reload": 1.8,
		"kb": 0.8, "spread": 0.035, "range": 9.5, "sfx": "rifle", "color": Color("d9ff66"), "size": 0.12},
}

## Rarity tiers, Common to Legendary: the names and colours gear is sold, shown and sorted by
## (Gear.mult has the numbers; GearDrops has the odds). Weapons have no rarity: each hunter carries
## one fixed signature weapon and grows it with upgrades (WeaponUps).
const RARITY := [
	{"name": "Common", "color": Color("d6d2c8")},
	{"name": "Fine", "color": Color("8fe0a0")},
	{"name": "Rare", "color": Color("6ab8ff")},
	{"name": "Epic", "color": Color("c08aff")},
	{"name": "Legendary", "color": Color("ffb64a")},
]

## Every weapon: the ones in content/weapons (the source of truth), plus any only defined here.
func weapon_ids() -> Array:
	# a hero's fixed signature weapon ("hero_only" in its JSON) never drops as loot
	var ids: Array = Content.ids("weapons").filter(func(w): return not bool(Content._load("weapons", String(w)).get("hero_only", false)))
	for k in WEAPONS:
		if not ids.has(k): ids.append(k)
	return ids

## A weapon's plain stats. "short" is the plain name for the ability bar. A weapon with no "mag" in its data
## has no ammo at all (the source gives ammo to one gun only): it gets "ammo": false and a nominal NO_AMMO_MAG
## rounds that its kit keeps topped up (ArchKit.tick), so nothing drains, reloads or shows a count.
func weapon_stats(wid: String) -> Dictionary:
	var wd := Content.weapon(wid)
	var w: Dictionary = wd.primary.duplicate() if wd else WEAPONS.get(wid, WEAPONS["rifle"]).duplicate()
	w["short"] = String(w["name"]).split(" ")[0]
	if not w.has("mag"):
		w["mag"] = NO_AMMO_MAG
		w["ammo"] = false
	return w

## The class you play and the weapon you carry are your whole loadout: left and right click come
## from the weapon, Q, E and R from the kin you bring.
func class_of_save() -> String:
	var c: String = Save.d.get("cls", "medium")
	return c if CLASSES.has(c) else "medium"

## The saved weapon if the class can carry it, else the class's default.
func weapon_for(cls: String, w: String) -> String:
	var cd: Dictionary = CLASSES.get(cls, CLASSES["medium"])
	return w if (cd["weapons"] as Array).has(w) else String(cd["weapon"])


## The soundtrack. Tracks join your music list the first time you hear them; some only play in
## rare places or moments.
const MUSIC := {
	"title": {"name": "Project Boki", "hint": "The title screen."},
	"home_day": {"name": "Hearthwind", "hint": "Your home island by day."},
	"home_night": {"name": "Hearthwind (Night)", "hint": "Your home island after dark."},
	"orchard": {"name": "Orchard Light", "hint": "Cross the bridge to Orchard Isle."},
	"meadow": {"name": "Tag in the Meadow", "hint": "Cross the bridge to Boki Meadow."},
	"summit": {"name": "Lookout Wind", "hint": "Cross the bridge to Lookout Peak."},
	"match": {"name": "Into the Isles", "hint": "Head out on an expedition."},
	"hollow": {"name": "The Hollow", "hint": "Brave the Hollow."},
	"hub": {"name": "Market Square", "hint": "Visit the town."},
	"guild": {"name": "Banners", "hint": "Visit a guild isle."},
	"lullaby": {"name": "Boki Lullaby", "hint": "Watch a Boki evolve."},
}

## One perk per loadout.
## Perks are found during an expedition, never brought from home: chests, shrines and bosses drop
## perk orbs you walk into (PerkOrbs, content/rules/perk_orbs.json). They stack up to "max" and last
## until the expedition ends, extracted or not. stats feed Hunter.gear_stat like gear does
## (speed, dmg, armor, cdr, heat, glide_speed); the rest are read by name with Hunter.perk_n().
const PERKS := {
	"quickhands": {"name": "Quick Hands", "desc": "Reload 30% faster.", "icon": "medkit", "col": Color("ffd27a"), "max": 1},
	"secondwind": {"name": "Second Wind", "desc": "One extra dash charge.", "icon": "dash", "col": Color("bfe6ff"), "max": 1},
	"featherfall": {"name": "Featherfall", "desc": "Your glider lasts 60% longer.", "icon": "updraft", "col": Color("cfeaff"), "max": 1},
	"scavenger": {"name": "Scavenger", "desc": "Gems you pick up are worth 25% more.", "icon": "gem", "col": Color("f2c84a"), "max": 2},
	"toughskin": {"name": "Tough Skin", "desc": "+15 max health, healed right away.", "icon": "heart", "col": Color("8fe0a0"), "max": 3},
	"overcharge": {"name": "Overcharge", "desc": "Your bond ultimate charges 30% faster.", "icon": "bond", "col": Color("ffd23f"), "max": 1},
	"keen": {"name": "Keen Edge", "desc": "8% more damage.", "icon": "burst", "col": Color("ff8a6a"), "max": 3, "stats": {"dmg": 0.08}},
	"fleet": {"name": "Fleet Foot", "desc": "6% faster on foot.", "icon": "jump", "col": Color("8fd16a"), "max": 2, "stats": {"speed": 0.06}},
	"plating": {"name": "Plating", "desc": "+20 max armor.", "icon": "fortify", "col": Color("dfe9f7"), "max": 2, "stats": {"armor": 20.0}},
	"focus": {"name": "Clear Mind", "desc": "Abilities recharge 12% faster.", "icon": "pulse", "col": Color("d07aff"), "max": 2, "stats": {"cdr": 0.12}},
	"tailwind": {"name": "Tailwind", "desc": "Glide 15% faster.", "icon": "gust", "col": Color("9fe8ff"), "max": 1, "stats": {"glide_speed": 0.15}},
	"remedy": {"name": "Remedy", "desc": "Tonics heal 40% more.", "icon": "tonic", "col": Color("8fe0a0"), "max": 1},
	# the old kit passives, now found as orbs (the same numbers they had as kit gear)
	"field_kit": {"name": "Field Surgeon", "desc": "Needle and thread: tonics heal 35% more.", "icon": "tonic", "col": Color("8fe0a0"), "max": 1, "stats": {"tonic": 0.35}},
	"magpie": {"name": "Magpie Pouch", "desc": "Shiny things stick: gems you pick up are worth 25% more.", "icon": "gem", "col": Color("f2c84a"), "max": 1, "stats": {"gems": 0.25}},
	"satchel": {"name": "Wayfarer's Satchel", "desc": "A deep bag: one more backpack slot.", "icon": "satchel", "col": Color("d9b27a"), "max": 2, "stats": {"pack": 1.0}},
	"spyglass": {"name": "Brass Spyglass", "desc": "See 12% further through grass and gloom.", "icon": "scanner", "col": Color("ffe08a"), "max": 1, "stats": {"sight": 0.12}},
	"tinker_roll": {"name": "Tinker's Roll", "desc": "A roll of small tools: reloads 15% faster.", "icon": "medkit", "col": Color("ffb86a"), "max": 1, "stats": {"reload": 0.15}},
	# weapon upgrades (WeaponUps): they grow the one signature weapon you carry. Even levels take them in a fixed order (WeaponPath); orbs drop the rest.
	"hotload": {"name": "Hotload", "desc": "Your weapon hits 10% harder.", "icon": "burst", "col": Color("ff8a6a"), "max": 4, "wup": {"dmg": 0.10}},
	"deepmag": {"name": "Deep Magazine", "desc": "20% more rounds before a reload.", "icon": "satchel", "col": Color("ffd27a"), "max": 3, "wup": {"mag": 0.20}},
	"quickfeed": {"name": "Quick Feed", "desc": "Your weapon fires 7% faster.", "icon": "pulse", "col": Color("d07aff"), "max": 3, "wup": {"rate": -0.07}},
	"longreach": {"name": "Long Reach", "desc": "12% more range (and reach, for blades).", "icon": "gust", "col": Color("9fe8ff"), "max": 2, "wup": {"range": 0.12}},
	"brand_fire": {"name": "Ember Brand", "desc": "Your hits burn: 5 damage a second for 3s.", "icon": "fireball", "col": Color("ff8a3a"), "max": 1, "wup": {"brand": "fire"}},
	"brand_frost": {"name": "Rime Brand", "desc": "Your hits chill, and every 5th freezes.", "icon": "snare", "col": Color("bff0ff"), "max": 1, "wup": {"brand": "frost"}},
	"brand_storm": {"name": "Storm Brand", "desc": "Every 4th hit arcs to 2 more foes.", "icon": "chain", "col": Color("fff27a"), "max": 1, "wup": {"brand": "storm"}},
	"brand_venom": {"name": "Venom Brand", "desc": "Your hits poison and slow.", "icon": "burst", "col": Color("9aff6a"), "max": 1, "wup": {"brand": "venom"}},
	"brand_void": {"name": "Hollow Brand", "desc": "Your hits heal you for 8% of the damage.", "icon": "shadowstep", "col": Color("b08aff"), "max": 1, "wup": {"brand": "void"}},
}

## Bot hunter difficulty. "auto" (the default) picks one from the run tier and how experienced you
## are; admins can force one in Settings > Gameplay or the admin panel (F1).
##   skill: aim lead/accuracy and how often they think   react: seconds before they fire on a new target
##   dmg: their damage   fire: how much of the time they keep the trigger down
##   abil: how readily they use abilities and kin   aggro: how far they chase and how hard they press
const BOT_DIFF := {
	"easy": {"name": "Easy", "skill": 0.28, "react": 0.75, "dmg": 0.65, "fire": 0.5, "abil": 0.3, "aggro": 0.6},
	"medium": {"name": "Medium", "skill": 0.5, "react": 0.45, "dmg": 0.82, "fire": 0.7, "abil": 0.55, "aggro": 0.8},
	"hard": {"name": "Hard", "skill": 0.72, "react": 0.28, "dmg": 0.95, "fire": 0.85, "abil": 0.8, "aggro": 0.95},
	"expert": {"name": "Expert", "skill": 0.92, "react": 0.16, "dmg": 1.05, "fire": 1.0, "abil": 1.0, "aggro": 1.1},
}
const BOT_ORDER := ["easy", "medium", "hard", "expert"]

## Which difficulty "auto" means for a run: the tier sets the base (Meadow easy, Dusk Isles medium,
## the Hollow hard) and lots of successful extractions push it up one step. The tutorial is always easy.
static func auto_bot_diff(tier: int, extracts: int, tutorial := false) -> String:
	if tutorial:
		return "easy"
	var i := clampi(tier, 0, 2)
	if extracts >= 12 * (i + 1):
		i += 1
	return BOT_ORDER[clampi(i, 0, BOT_ORDER.size() - 1)]

const SIGS := {
	"cloak": {"name": "Cloak", "cd": 14.0, "desc": "Vanish for 3s and move 35% faster. Firing reveals you."},
	"mend": {"name": "Mend", "cd": 16.0, "desc": "Heal 35 to you, nearby teammates and Boki. Nearby revives jump halfway."},
	"fortify": {"name": "Fortify", "cd": 16.0, "desc": "A 60 point shield for 5s. Nothing can knock you back."},
}

## Kin species, built from the kin grammar (content/kin_v2, see KinLib.species): name, colours,
## stats from its points, abilities, merge, carry style. content/kin/<id>.json now only holds
## home and economy data for a species (rare/boss egg, work elements, shiny palette); a new kin
## needs only its kin_v2 file.
var KIN := {}

## Things a kin can wear. Bought at the stall, put on from the kin's card, worn into matches too.
const ACCS := {
	"bell": {"name": "Little bell", "price": 25, "col": Color("f2c84a")},
	"bow": {"name": "Ribbon bow", "price": 30, "col": Color("ff7aa8")},
	"leafhat": {"name": "Leaf hat", "price": 35, "col": Color("5aa84a")},
	"scarf": {"name": "Cozy scarf", "price": 40, "col": Color("d9604a")},
	"crown": {"name": "Flower crown", "price": 45, "col": Color("ffd0e8")},
	"goggles": {"name": "Flight goggles", "price": 55, "col": Color("8b6d52")},
	"cape": {"name": "Hero cape", "price": 70, "col": Color("5a7ae0")},
	"tophat": {"name": "Tiny top hat", "price": 80, "col": Color("2b2a33")},
	"collar": {"name": "Studded collar", "price": 50, "col": Color("8a4a5a")},
	"charm": {"name": "Star charm", "price": 150, "col": Color("ffe27a")},
}

func _init() -> void:
	load_kin_content()

## Reads every kin that passed the grammar checker (KinLib) into KIN, plus its home data
## (content/kin/<id>.json: rare, boss).
func load_kin_content() -> void:
	KIN.clear()
	var ids: Array = []
	for first in ["cindle", "puddlet", "burrlet", "zapple", "pebbit", "wisplet"]:     # the original order (starters)
		if KinLib.kin(first): ids.append(first)
	for id in KinLib.kin_ids():
		if not ids.has(id): ids.append(id)
	for id in ids:
		var sp: Dictionary = KinLib.species(id)
		var home: Dictionary = Content._load("kin", id)
		if bool(home.get("rare", false)):
			sp["rare"] = true
			sp["boss"] = String(home.get("boss", ""))
		KIN[id] = sp

## Species anyone can meet in the wild, pick as a starter or see on a rival: everything but the rare
## kin (content/kin/*.json "rare": true), which only ever hatch from a boss's Rare Egg.
## The six that shipped first lead the list (code reads common_kin()[0] and [i % size]), then the rest by id.
const LAUNCH_KIN := ["burrlet", "cindle", "pebbit", "puddlet", "wisplet", "zapple"]

func common_kin() -> Array:
	var all: Array = KIN.keys().filter(func(k): return not KIN[k].get("rare", false))
	return LAUNCH_KIN.filter(func(k): return all.has(k)) + all.filter(func(k): return not LAUNCH_KIN.has(k))

func is_rare(sp_id: String) -> bool:
	return bool(KIN.get(sp_id, {}).get("rare", false))

## What a species' egg is called ("Venom Egg"), from content/kin/<id>.json "egg".
func egg_name(sp_id: String) -> String:
	var sp: Dictionary = KIN.get(sp_id, {})
	var e: Dictionary = sp.get("egg", {})
	if e.has("name"):
		return String(e["name"])
	return "%s Egg" % String(sp.get("type", "Kin")).capitalize()

func egg_info(sp_id: String) -> Dictionary:
	var sp: Dictionary = KIN.get(sp_id, {})
	var e: Dictionary = sp.get("egg", {}).duplicate()
	e["name"] = egg_name(sp_id)
	return e

const MOBS := {
	"skitter": {"name": "Skitter", "hp": 34.0, "speed": 5.2, "dmg": 9.0, "range": 1.2, "windup": 0.55, "cd": 1.3,
		"r": 0.45, "gems": 2, "color": Color("7b5ea8"), "attack": "lunge"},
	"spitter": {"name": "Spitter", "hp": 44.0, "speed": 2.2, "dmg": 11.0, "range": 8.0, "windup": 0.8, "cd": 2.2,
		"r": 0.55, "gems": 3, "color": Color("4f9e6e"), "attack": "spit"},
	"brute": {"name": "Brute", "hp": 170.0, "speed": 3.0, "dmg": 24.0, "range": 2.2, "windup": 1.05, "cd": 2.6,
		"r": 0.9, "gems": 9, "color": Color("8a5a48"), "attack": "slam", "stag": true},
	"bomber": {"name": "Puffbomb", "hp": 26.0, "speed": 4.4, "dmg": 16.0, "range": 1.7, "windup": 1.0, "cd": 1.0,
		"r": 0.5, "gems": 2, "color": Color("e07a3a"), "attack": "fuse", "slam_r": 2.5},
	"sentinel": {"name": "Sentinel", "hp": 70.0, "speed": 0.0, "dmg": 8.0, "range": 10.0, "windup": 0.95, "cd": 2.6,
		"r": 0.55, "gems": 4, "color": Color("5ab0c8"), "attack": "volley", "stag": true},
	"glimmer": {"name": "Glimmerkin", "hp": 110.0, "speed": 5.9, "dmg": 0.0, "range": 0.0, "windup": 1.0, "cd": 99.0,
		"r": 0.45, "gems": 22, "color": Color("ffd25a"), "attack": "none", "flee": true, "stag": true},
	# the bush mimic (scripts/match/shrubling.gd): a clump of tall grass you can hide in; hit it and it runs.
	# It always carries a chest key.
	"shrubling": {"name": "Shrubling", "hp": 26.0, "speed": 6.5, "dmg": 0.0, "range": 0.0, "windup": 1.0, "cd": 99.0,
		"r": 0.4, "gems": 6, "color": Color("5f9a46"), "attack": "none", "mimic": true},
	"warden": {"name": "The Watcher", "hp": 820.0, "speed": 3.3, "dmg": 30.0, "range": 2.8, "windup": 0.95, "cd": 2.1,
		"r": 1.3, "gems": 30, "color": Color("5a4a7a"), "attack": "slam", "slam_r": 3.3, "stag": true},
	# lair bosses (scripts/match/boss.gd runs them; Lairs wakes them): each drops a Rare Egg of its own kin
	"colossus": {"name": "The Stone Colossus", "hp": 1500.0, "speed": 2.5, "dmg": 26.0, "range": 3.2, "windup": 1.1, "cd": 1.9,
		"r": 1.6, "gems": 40, "color": Color("7d7468"), "attack": "boss", "slam_r": 3.8, "stag": true, "stag_k": 0.04, "boss": true,
		"egg": "cairnback", "enrage": 75.0},
	"serpent": {"name": "Stormcoil, the Sky Serpent", "hp": 1250.0, "speed": 5.2, "dmg": 22.0, "range": 10.0, "windup": 0.95, "cd": 1.5,
		"r": 1.15, "gems": 40, "color": Color("3f86b8"), "attack": "boss", "stag": true, "stag_k": 0.04, "boss": true,
		"egg": "zephyrak", "enrage": 75.0},
	"brood": {"name": "The Brood Mother", "hp": 1350.0, "speed": 2.3, "dmg": 18.0, "range": 9.0, "windup": 1.0, "cd": 1.7,
		"r": 1.55, "gems": 40, "color": Color("8a9a3a"), "attack": "boss", "stag": true, "stag_k": 0.04, "boss": true,
		"egg": "hivara", "enrage": 75.0},
	# the Blight (scripts/match/blight.gd, BlightDir): the Wyrm's corruption, hunting by noise and
	# light. These are the base numbers; BlightDir scales health and damage from weak (the first
	# minutes, outer islands) to full (late, the core, night). "lvl" 1 is full strength.
	"bl_skitter": {"name": "Blight Skitter", "hp": 30.0, "speed": 5.4, "dmg": 8.0, "range": 1.15, "windup": 0.5, "cd": 1.35,
		"r": 0.4, "gems": 1, "color": Color("3e3634"), "attack": "lunge", "blight": true},
	"bl_warden": {"name": "Blight Watcher", "hp": 150.0, "speed": 1.3, "dmg": 12.0, "range": 9.0, "windup": 1.1, "cd": 2.8,
		"r": 0.8, "gems": 4, "color": Color("4a4240"), "attack": "spit", "blight": true},
	# a lair's ward stones: break all three (guards come out as you do) and its seal fails
	"ward": {"name": "Ward Stone", "hp": 150.0, "speed": 0.0, "dmg": 0.0, "range": 0.0, "windup": 1.0, "cd": 999.0,
		"r": 0.7, "gems": 3, "color": Color("8fd8ff"), "attack": "none", "ward": true},
}
## The lair bosses, in the order generated maps hand them out.
const BOSSES := ["colossus", "serpent", "brood"]

## Crops grow on the farm while you play matches. Each becomes something for your next match.
const CROPS := {
	"emberberry": {"name": "Emberberry", "grow": 2, "color": Color("ff6a4a"), "price": 20,
		"use": "treat_power", "desc": "Treat: your Boki deals 25% more damage next match."},
	"tidebloom": {"name": "Tidebloom", "grow": 1, "color": Color("5ab8f0"), "price": 12,
		"use": "tonic", "desc": "Brews 2 tonics. Key 1 in a match heals 45."},
	"sunroot": {"name": "Sunroot", "grow": 2, "color": Color("f2c84a"), "price": 18,
		"use": "treat_hardy", "desc": "Treat: your Boki has 40% more health next match."},
	"mindmint": {"name": "Mindmint", "grow": 3, "color": Color("8fe0b0"), "price": 25,
		"use": "treat_calm", "desc": "Treat: +12 trust. Calm Boki follow risky orders."},
	"puffcorn": {"name": "Puffcorn", "grow": 1, "color": Color("f6e3a8"), "price": 8,
		"use": "snack", "desc": "Snack: your partner gets +4 trust right away. Quick and cheap."},
	"glowcap": {"name": "Glowcap", "grow": 2, "color": Color("b48cff"), "price": 30, "weight": 0.6,
		"use": "treat_xp", "desc": "Treat: your partner learns half again as much next match."},
	"starfruit": {"name": "Starfruit", "grow": 4, "color": Color("fff07a"), "price": 60, "weight": 0.3,
		"use": "levelup", "desc": "Rare. Your partner gains a level right away (once a day)."},
}

## Furniture for decorating the insides of buildings. size is in floor tiles (w, d); "walk" lets you
## walk over it (rugs). Prices are in gems at the stall or the decorating catalog.
const FURN := {
	"bed": {"name": "Bed", "cat": "Beds & seats", "price": 60, "size": [2, 3]},
	"kin_bed": {"name": "Boki basket", "cat": "Beds & seats", "price": 25, "size": [1, 1]},
	"table": {"name": "Table", "cat": "Tables & shelves", "price": 40, "size": [2, 1]},
	"chair": {"name": "Chair", "cat": "Beds & seats", "price": 15, "size": [1, 1]},
	"stool": {"name": "Stool", "cat": "Beds & seats", "price": 10, "size": [1, 1]},
	"rug": {"name": "Rug", "cat": "Rugs", "price": 30, "size": [3, 2], "walk": true},
	"rug_round": {"name": "Round rug", "cat": "Rugs", "price": 30, "size": [2, 2], "walk": true},
	"lamp": {"name": "Floor lamp", "cat": "Decor", "price": 25, "size": [1, 1]},
	"plant": {"name": "Potted plant", "cat": "Decor", "price": 15, "size": [1, 1]},
	"big_plant": {"name": "Big plant", "cat": "Decor", "price": 35, "size": [1, 1]},
	"shelf": {"name": "Bookshelf", "cat": "Tables & shelves", "price": 45, "size": [2, 1]},
	"chest": {"name": "Chest", "cat": "Tables & shelves", "price": 30, "size": [1, 1]},
	"stove": {"name": "Stove", "cat": "Tables & shelves", "price": 55, "size": [1, 1]},
	"fireplace": {"name": "Fireplace", "cat": "Tables & shelves", "price": 90, "size": [2, 1]},
	"wardrobe": {"name": "Wardrobe", "cat": "Tables & shelves", "price": 50, "size": [2, 1]},
	"fishbowl": {"name": "Fish bowl", "cat": "Decor", "price": 35, "size": [1, 1]},
	"easel": {"name": "Painting", "cat": "Decor", "price": 40, "size": [1, 1]},
	"trophy": {"name": "Trophy stand", "cat": "Decor", "price": 70, "size": [1, 1]},
	"cushion": {"name": "Floor cushion", "cat": "Beds & seats", "price": 12, "size": [1, 1], "walk": true},
	"toy_ball": {"name": "Boki toy", "cat": "Decor", "price": 8, "size": [1, 1], "walk": true},
	"journal": {"name": "Boki journal", "cat": "Useful", "price": 20, "size": [1, 1]},
	"gramophone": {"name": "Gramophone", "cat": "Useful", "price": 30, "size": [1, 1]},
}

## Rooms you can go into: floor size in tiles and what's in them to begin with.
const ROOMS := {
	"house": {"name": "Your house", "w": 10, "d": 8, "floor": Color("8f6644"), "wall": Color("efe2c8"),
		"start": []},
	"cottage": {"name": "Boki Cottage", "w": 8, "d": 6, "floor": Color("86603f"), "wall": Color("e8d8b8"),
		"start": [["kin_bed", 1, 1, 0], ["kin_bed", 3, 1, 0], ["rug_round", 4, 3, 0], ["toy_ball", 6, 4, 0]]},
	"cottage2": {"name": "Meadow Cottage", "w": 8, "d": 6, "floor": Color("86603f"), "wall": Color("dfe8c8"),
		"start": [["kin_bed", 1, 1, 0], ["kin_bed", 6, 1, 0], ["cushion", 3, 3, 0], ["plant", 7, 4, 0]]},
}

## Farming: a watered plant grows a stage after this long at home (half in the greenhouse).
const WATER_TIME := 90.0

## A random seed for loot, rare crops less often.
func pick_seed(r: RandomNumberGenerator = null) -> String:
	var total := 0.0
	for k in CROPS: total += float(CROPS[k].get("weight", 1.0))
	var x := (r.randf() if r else randf()) * total
	for k in CROPS:
		x -= float(CROPS[k].get("weight", 1.0))
		if x <= 0.0: return k
	return CROPS.keys()[0]

const KIN_NAMES := Names.KIN      # ~2,200 names: see scripts/core/names.gd
const BOT_NAMES := Names.BOT      # ~180 gamer tags

## A kin's name until you give it one: its species' name, as in a field guide.
func default_kin_name(species: String) -> String:
	return String(KIN[species]["name"]) if KIN.has(species) else "Kin"

## "Pip the Vespyx", or just "Vespyx" for a Boki still called by its species' name (not "Vespyx the Vespyx").
func kin_title(kname: String, species_name: String) -> String:
	return species_name if kname == "" or kname == species_name else "%s the %s" % [kname, species_name]

## Expedition tiers: deeper islands are harder and richer, and in the Hollow your partner can be lost.
const TIERS := [
	{"name": "The Meadow", "desc": "Gentle islands. Your Boki are always safe here: lose your loot, never your Boki.",
		"depth": 1, "mob": 1.0, "loot": 1.0, "kin_lvl": [1, 3], "unlock": 0, "lives": 1,
		"biome": {"top": Color("5f8d45"), "top2": Color("4a7538"), "side": Color("8b6d52"), "deep": Color("3a3140"), "leaf": Color("5a9a4f")},
		"sky": Color("10131f"), "ambient": Color("b9c4e6"), "sun": Color("fff1dc"), "clouds": [Color(0.06, 0.07, 0.13), Color(0.22, 0.24, 0.38)]},
	{"name": "Dusk Isles", "desc": "Tougher monsters, more loot, rarer Boki. Your Boki is always safe here: it goes home with you if you fall.",
		"depth": 2, "mob": 1.45, "loot": 1.75, "kin_lvl": [2, 5], "unlock": 2, "lives": 1,
		"biome": {"top": Color("56688a"), "top2": Color("465576"), "side": Color("6d5a74"), "deep": Color("2a2440"), "leaf": Color("8a6fb8")},
		"sky": Color("150f22"), "ambient": Color("c9b4e6"), "sun": Color("ffc9a8"), "clouds": [Color(0.09, 0.05, 0.14), Color(0.32, 0.2, 0.4)]},
	{"name": "The Hollow", "desc": "Brutal and rich. If you fall your Boki drops dazed beside your deathbox and guards it. Get revived and run into it to pick it up, or a rival can scan it and take it (knock it out, then hold the interact key).",
		"depth": 3, "mob": 2.0, "loot": 2.75, "kin_lvl": [4, 8], "unlock": 5, "lives": 1,
		"biome": {"top": Color("4f6b5e"), "top2": Color("3d5650"), "side": Color("5a4a44"), "deep": Color("1e1a22"), "leaf": Color("c25a4a")},
		"sky": Color("0d0b10"), "ambient": Color("d0a0a0"), "sun": Color("ffb090"), "clouds": [Color(0.07, 0.03, 0.04), Color(0.3, 0.12, 0.12)]},
]

## Home islands beyond the first one. Build a bridge to reach them. Rects are in home grid tiles.
const ISLES := {
	"orchard": {"name": "Orchard Isle", "cost": 100, "need": 1, "c": Vector2(69, 11), "r": Vector2(8.5, 6.5),
		"bridge": [62, 14, 63, 29], "sign": Vector2(60.6, 29.4), "desc": "A sunny isle with room for a greenhouse."},
	"meadow": {"name": "Boki Meadow", "cost": 140, "need": 2, "c": Vector2(10.5, 30.5), "r": Vector2(8.4, 7.2),
		"bridge": [17, 30, 26, 31], "sign": Vector2(25.2, 29.0), "desc": "Open fields where Boki love to play. Room for a cottage and a training yard."},
	"summit": {"name": "Lookout Peak", "cost": 220, "need": 4, "c": Vector2(45, 9), "r": Vector2(9.0, 6.5),
		"bridge": [44, 12, 45, 24], "sign": Vector2(46.8, 23.6), "desc": "A high rock for a vault and a trophy hall."},
	"grove": {"name": "Blossom Grove", "cost": 180, "need": 3, "c": Vector2(12, 53), "r": Vector2(8.5, 6.8),
		"bridge": [17, 47, 34, 48], "sign": Vector2(34.6, 45.0), "desc": "A quiet grove with open ground to plant, decorate and lay out however you like."},
	"pines": {"name": "Pine Hollow", "cost": 160, "need": 2, "c": Vector2(25, 11), "r": Vector2(8.0, 6.0),
		"bridge": [28, 14, 29, 25], "sign": Vector2(30.6, 25.4), "desc": "A sheltered hollow of open ground: room for gardens, ponds and Boki beds."},
}

## Buildings you can buy for your islands. "rect" is the tile footprint [x0, z0, x1, z1].
const BUILDINGS := {
	"workshop": {"name": "Workshop", "isle": "main", "cost": 90, "rect": [28, 26, 30, 28],
		"desc": "Tune your glider. You glide 50% longer on expeditions."},
	"cottage": {"name": "Boki Cottage", "isle": "main", "cost": 110, "rect": [27, 35, 29, 36],
		"desc": "Boki who stay home rest here and gain 2 trust after every expedition."},
	"greenhouse": {"name": "Greenhouse", "isle": "orchard", "cost": 150, "rect": [67, 7, 70, 9],
		"desc": "Four more plots. Crops planted here grow twice as fast."},
	"cottage2": {"name": "Meadow Cottage", "isle": "meadow", "cost": 140, "rect": [8, 26, 10, 27],
		"desc": "Boki who stay home gain 2 more trust after every expedition."},
	"dojo": {"name": "Training Yard", "isle": "meadow", "cost": 180, "rect": [11, 32, 14, 34],
		"desc": "Boki who stay home gain 40 XP after every expedition."},
	"vault": {"name": "Vault", "isle": "summit", "cost": 220, "rect": [41, 7, 43, 8],
		"desc": "If you go down, you still keep a third of the gems you were carrying."},
	"board": {"name": "Challenge House", "isle": "main", "cost": 0, "rect": [31, 22, 33, 23], "free": true,
		"desc": "Challenges to take on, their rewards, and what they unlock at the market."},
	"ransom": {"name": "Black Market", "isle": "main", "cost": 0, "rect": [42, 39, 44, 40], "free": true,
		"desc": "Old Pell's place. Boki left behind on expeditions end up here (Ransom), you deal with rivals who took yours, and he sells rare pieces at a steep price."},
	"hall": {"name": "Trophy Hall", "isle": "summit", "cost": 120, "rect": [47, 6, 49, 8],
		"desc": "Keeps your records and every Boki you've brought home."},
	"armory": {"name": "Armory", "isle": "main", "cost": 40, "rect": [45, 25, 47, 26],
		"desc": "Stores the weapons and gloves you bring home. Pick what you take on your next expedition, sell or salvage the rest, and get a bigger backpack."},
	"shrine": {"name": "Soul Shrine", "isle": "main", "cost": 150, "rect": [49, 35, 50, 36], "needs_ember": true,
		"desc": "Lit by a Soul Ember. Keeps the souls of Boki buried in the graveyard, and can bring one back (a little different)."},
}

const MATCH := {
	"length": 360.0,       # seconds until the islands fall
	"portal_open": 150.0,  # first exit portals open this many seconds in
	"extract_time": 4.0,   # seconds standing in an exit's circle to leave; a hit from another hunter resets it
	"revive_time": 3.0,
	"kin_revive_time": 5.0,
	"bleed": 2.5,          # downed health lost per second
	"down_hp": 100.0,      # so about 40 seconds downed before you bleed out
}
