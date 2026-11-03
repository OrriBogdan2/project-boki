class_name EqualMigrate
extends RefCounted
## Save v5 -> v6 (docs/decisions/0005-equal-footing.md): the equal-footing update takes armor and kit
## pieces out of the armory, so nothing is silently deleted:
##   armor pieces and kit pieces   become gems and farm materials at a fair rate (below)
##   smoke / spring pad / seeker / mending gloves   became utility items: charges in the stash
##   gloves and boots              stay (the second glove slot, V, starts empty in the loadout)
##   bought backpack levels        the backpack of that level (Backpacks), the levels below refunded
##   Rift Keys in the stash        refunded at the market price (keys are found in the match only now)
## A one-time notice (data["equal_notice"], shown on the farm) lists everything that converted.
##
## The rate, per piece: gems = its full item value (Common 3, Fine 8, Rare 18, Epic 36, Legendary 70)
## times content/rules/equal.json migration.gem_k, plus the materials an extraction of that rarity
## gives (content/rules/gear.json extract_mats). That is more than selling it (60% of the value).

const KIT_IDS := ["field_kit", "magpie", "satchel", "spyglass", "tinker_roll"]
const MOVED_IDS := ["smoke", "jump_pad", "scanner", "medkit"]       # gloves that became utility items
const GEAR_VALUE := [3, 8, 18, 36, 70]                               # Loot.GEAR_VALUE, as it was
const PACK_REFUND := [[120, 4], [260, 10], [450, 20]]  # what the three backpack upgrades cost [gems, scrap]
const RIFT_KEY_PRICE := 140                              # what a Rift Key cost at the market
const OLD_NAMES := {"field_kit": "Field Surgeon's Kit", "magpie": "Magpie Pouch", "satchel": "Wayfarer's Satchel",
	"spyglass": "Brass Spyglass", "tinker_roll": "Tinker's Roll", "smoke": "Smoke Glove", "jump_pad": "Springpad Glove",
	"scanner": "Seeker Glove", "medkit": "Mending Glove"}
const MAX_LISTED := 8

## What a stored piece is for the update: "armor", "kit", "moved" (a glove that became a utility item)
## or "" (it stays).
static func fate(id: String) -> String:
	if KIT_IDS.has(id):
		return "kit"
	if MOVED_IDS.has(id):
		return "moved"
	if String(Gear.ALL.get(id, {}).get("slot", "")) == "armor":
		return "armor"
	return ""

static func name_of(id: String) -> String:
	return String(OLD_NAMES.get(id, Gear.ALL.get(id, {}).get("name", id)))

## What converting one piece of rarity `rar` gives: {gems, wood, stone, scrap}.
static func rate(rar: int) -> Dictionary:
	var r := clampi(rar, 0, GEAR_VALUE.size() - 1)
	var k := float((Equal.rules().get("migration", {}) as Dictionary).get("gem_k", 1.0))
	var out := {"gems": int(round(float(GEAR_VALUE[r]) * k)), "wood": 0, "stone": 0, "scrap": 0}
	var tab: Array = GearDrops.rules().get("extract_mats", [])
	if not tab.is_empty():
		var row: Dictionary = tab[mini(r, tab.size() - 1)]
		for m in ["wood", "stone", "scrap"]:
			out[m] = int(row.get(m, 0))
	return out

## Upgrades a v5 save in place. Returns the notice lines (also stored in data["equal_notice"]).
static func migrate(data: Dictionary) -> Array:
	var tot := {"gems": 0, "wood": 0, "stone": 0, "scrap": 0}
	var listed: Array = []
	var gone := {}                      # uid -> true
	var moved := {}                     # utility id -> charges
	var n_armor := 0
	var n_kit := 0
	for key in ["armory", "raid_out"]:
		var keep: Array = []
		for it in data.get(key, []):
			if typeof(it) != TYPE_DICTIONARY or String(it.get("t", "")) != "gear":
				keep.append(it)
				continue
			var id := String(it.get("id", ""))
			var rar := int(it.get("rar", 0))
			match fate(id):
				"armor", "kit":
					var rt := rate(rar)
					for k in tot:
						tot[k] = int(tot[k]) + int(rt[k])
					if fate(id) == "armor": n_armor += 1
					else: n_kit += 1
					listed.append("%s %s" % [Data.RARITY[clampi(rar, 0, 4)]["name"], name_of(id)])
					gone[String(it.get("uid", ""))] = true
				"moved":
					var ch: Array = (Equal.rules().get("migration", {}) as Dictionary).get("moved_gloves_charges", [1])
					moved[id] = int(moved.get(id, 0)) + int(ch[clampi(rar, 0, ch.size() - 1)])
					listed.append("%s -> %s x%d" % [name_of(id), id.replace("_", " "),
							int(ch[clampi(rar, 0, ch.size() - 1)])])
					gone[String(it.get("uid", ""))] = true
				_:
					keep.append(it)
		data[key] = keep
	# what was picked for the next expedition and is now gone
	var lo: Dictionary = data.get("loadout", {})
	for k in lo.keys():
		if gone.has(String(lo[k])):
			lo.erase(k)
	# the old loadout had one active glove ("gear0") and a passive one ("gear1"); "gear1" is now the
	# second glove slot (V) and starts empty. The passive glove stays in the armory, ready to pick.
	var had_g1 := lo.has("gear1")
	lo.erase("gear1")
	data["loadout"] = lo
	# the rewards
	data["gems"] = int(data.get("gems", 0)) + int(tot["gems"])
	data["scrap"] = int(data.get("scrap", 0)) + int(tot["scrap"])
	var mats: Dictionary = data.get("mats", {})
	for m in ["wood", "stone"]:
		if int(tot[m]) > 0:
			mats[m] = int(mats.get(m, 0)) + int(tot[m])
	if not mats.is_empty():
		data["mats"] = mats
	var items: Dictionary = data.get("items", {})
	for id in moved:
		items[id] = int(items.get(id, 0)) + int(moved[id])
	data["items"] = items
	# bought backpack levels: level L was a bigger pack for good; now it is the tier-L backpack to bring
	# (at risk), and what the levels below it cost comes back
	var refund := [0, 0]
	var plvl := clampi(int(data.get("pack_lvl", 0)), 0, PACK_REFUND.size())
	for i in maxi(0, plvl - 1):
		refund[0] += int(PACK_REFUND[i][0])
		refund[1] += int(PACK_REFUND[i][1])
	var owned_packs := [0, 0, 0, 0]
	if plvl > 0:
		owned_packs[plvl] = 1
	data["backpacks"] = owned_packs
	data["pack_pick"] = plvl
	data["raid_pack"] = 0
	data["gems"] = int(data["gems"]) + refund[0]
	data["scrap"] = int(data["scrap"]) + refund[1]
	data.erase("pack_lvl")
	# Rift Keys bought at the market: keys are found in the match only now, so they come back as gems
	var old_keys := int(items.get("rift_key", 0))
	items.erase("rift_key")
	data.erase("key_buys")
	data["gems"] = int(data["gems"]) + old_keys * RIFT_KEY_PRICE
	data["belt_pick"] = ["tonic", "armor_kit", "", ""]
	data["raid_belt"] = {}
	# the notice
	var lines: Array = []
	if n_armor + n_kit + moved.size() + plvl + old_keys > 0 or had_g1:
		lines.append("Everyone now drops into matches with the same gear. You keep your gloves and boots, "
				+ "and nothing was deleted.")
		if n_armor + n_kit > 0:
			lines.append("%d armor and %d kit piece%s became %d gems, %d wood, %d stone, %d scrap." % [n_armor, n_kit,
					"" if n_armor + n_kit == 1 else "s", tot["gems"], tot["wood"], tot["stone"], tot["scrap"]])
		if not moved.is_empty():
			var bits: Array = []
			for id in moved:
				bits.append("%s x%d" % [id.replace("_", " "), moved[id]])
			lines.append("Utility charges in your stash: %s." % ", ".join(bits))
		if plvl > 0:
			var pack_line := "Your backpack upgrade is now a %s to bring (lost if you go down)" % Backpacks.label(plvl)
			if refund[0] > 0:
				pack_line += "; the smaller upgrades refunded: %d gems, %d scrap" % [refund[0], refund[1]]
			lines.append(pack_line + ".")
		if old_keys > 0:
			lines.append("%d Rift Key%s refunded: %d gems (keys are found in matches now)." % [old_keys,
				"" if old_keys == 1 else "s", old_keys * RIFT_KEY_PRICE])
		for i in mini(listed.size(), MAX_LISTED):
			lines.append("  " + String(listed[i]))
		if listed.size() > MAX_LISTED:
			lines.append("  and %d more" % (listed.size() - MAX_LISTED))
		var still := " (your passive glove is still there)" if had_g1 else ""
		var second := "New: a second glove slot on %s. " % Gloves.key_cap(1)
		lines.append(second + "Pick a glove for it in the armory%s." % still)
		lines.append("Armor and perks are found in the match now.")
	data["equal_notice"] = lines
	return lines

## The notice, once: shown on the farm, then forgotten.
static func take_notice() -> Array:
	var lines: Array = Save.d.get("equal_notice", [])
	if lines.is_empty():
		return []
	Save.d["equal_notice"] = []
	Save.save_game()
	return lines

## For screenshots (--armory-test): an old-style armory run through the migration, so the screen shows
## what a real v5 save looks like afterwards. Writes into Save.d (the caller sets Save.no_write).
static func demo() -> void:
	var d := Save.fresh()
	d["v"] = 5
	d["pack_lvl"] = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var arm: Array = []
	for t in [["vest", 2], ["quilted_coat", 3], ["bastion_plate", 4], ["tinker_roll", 2], ["satchel", 4],
			["field_kit", 1], ["magpie", 3], ["smoke", 2], ["scanner", 3]]:
		arm.append(Loot.gear(String(t[0]), int(t[1])))
	for t in [["boots", 1], ["windstep_boots", 3], ["quickstep_boots", 2]]:
		arm.append(Loot.gear(String(t[0]), int(t[1])))
	var gk: Array = Gear.ids_for(0) + Gear.ids_for(1)
	for i in mini(4, gk.size()):
		arm.append(Loot.gear(String(gk[i]), 1 + i % 4))
	d["armory"] = arm
	Save.migrate(d)
	for k in ["armory", "equal_notice", "mats", "scrap", "items", "loadout", "backpacks", "pack_pick"]:
		Save.d[k] = d[k]
	Save.d["gems"] = int(d["gems"]) + 300
	Save.d["valuables"] = {"old_coin": 3, "sky_pearl": 1}
