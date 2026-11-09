class_name Gear
## Gear found on expeditions. A hunter wears four pieces: two gloves (Q and V; each can be an active
## or a passive glove, never two of the same: Gloves), armor and boots. (Utility items are not gear:
## they live on the three-slot belt, UtilityBelt.) Rarity (Common to Legendary) lives here, not on weapons: a hunter
## carries one fixed signature weapon and grows it with weapon upgrades (WeaponUps). Every piece gives
## stats; a glove with a cooldown is the active one. Picking up a piece replaces the one in its slot
## (the old one drops). Gear lasts one expedition, like perks.
## Defined in content/gear/*.json: name, slot ("armor" or "boots"; gloves leave it out and go
## by cooldown), cd, col, icon, stats, desc, and for most active gloves an "effects" list run through
## Effects (the same building blocks abilities use).

static var ALL: Dictionary = {}

static func _static_init() -> void:
	_load()

static func _load() -> void:
	ALL = {}
	var dir := DirAccess.open("res://content/gear")
	if dir == null:
		return
	var files: Array = []
	for f in dir.get_files():
		var fn := String(f).trim_suffix(".remap")
		if fn.ends_with(".json"): files.append(fn)
	files.sort()
	for fn in files:
		var txt := FileAccess.get_file_as_string("res://content/gear/" + String(fn))
		var d = JSON.parse_string(txt)
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var id := String(d.get("id", String(fn).trim_suffix(".json")))
		d["col"] = Color(String(d.get("col", "ffffff")))
		d["cd"] = float(d.get("cd", 0.0))
		ALL[id] = d

## A piece's KIND (slot_of, drop tables, the armory tabs): 0 active glove, 1 passive glove, 2 armor,
## 3 boots. Where a hunter WEARS it (h.gear index, slot_on): 0 glove on Q, 1 glove on V, 2 armor,
## 3 boots; either kind of glove fits either glove slot.
const SLOTS := ["glove", "passive", "armor", "boots"]
const SLOT_NAMES := ["Active glove", "Passive glove", "Armor", "Boots"]
const WORN_NAMES := ["Glove 1", "Glove 2", "Armor", "Boots"]

static func is_glove(id: String) -> bool:
	return ALL.has(id) and slot_of(id) < 2

## The h.gear index this piece goes in on this hunter (gloves: Gloves.slot_for).
static func slot_on(h, id: String) -> int:
	return Gloves.slot_for(h, id) if is_glove(id) else slot_of(id)

static func empty_slots() -> Array:
	return [{}, {}, {}, {}]

static func active(id: String) -> bool:
	return float(ALL.get(id, {}).get("cd", 0.0)) > 0.0

## Which slot a piece goes in: its "slot" key, else gloves by cooldown (0 the active slot, 1 passive).
static func slot_of(id: String) -> int:
	var sn := String(ALL.get(id, {}).get("slot", ""))
	if sn != "":
		return maxi(2, SLOTS.find(sn))
	return 0 if active(id) else 1

static func slot_name(id: String) -> String:
	return SLOT_NAMES[slot_of(id)]

## Ids of every piece for a slot index.
static func ids_for(slot: int) -> Array:
	var out: Array = []
	for k in ALL:
		if slot_of(String(k)) == slot: out.append(k)
	out.sort()
	return out

static func icon_of(id: String) -> String:
	return String(ALL.get(id, {}).get("icon", id))

## Rarer gloves have bigger numbers (1x, 1.3x, 1.6x, 2x).
static func mult(rar: int) -> float:
	return [1.0, 1.0, 1.3, 1.6, 2.0][clampi(rar, 0, 4)]

## An active glove's effects at a rarity: the same verb, bigger numbers (damage, wall health,
## healing and shields grow with the rarity multiplier; durations and pull strength by half as much).
const SCALE_FULL := ["dmg", "hp", "heal", "shield", "amount"]
const SCALE_HALF := ["strength", "time"]

static func effects_of(id: String, rar: int) -> Array:
	var effs: Array = (ALL.get(id, {}).get("effects", []) as Array).duplicate(true)
	var k := mult(rar)
	if k == 1.0:
		return effs
	for e in effs:
		_scale(e, k)
	return effs

static func _scale(e, k: float) -> void:
	if not (e is Dictionary):
		return
	for key in e.keys():
		if key in SCALE_FULL and (e[key] is float or e[key] is int):
			e[key] = float(e[key]) * k
		elif key in SCALE_HALF and (e[key] is float or e[key] is int):
			e[key] = float(e[key]) * (1.0 + (k - 1.0) * 0.5)
		elif e[key] is Array:
			for sub in e[key]: _scale(sub, k)
		elif e[key] is Dictionary and key in ["spike"]:
			pass

## Cooldown at a rarity: 8% shorter per step above common.
static func cd_of(id: String, rar: int) -> float:
	return float(ALL.get(id, {}).get("cd", 0.0)) * (1.0 - 0.08 * float(clampi(rar - 1, 0, 3)))

static func desc_of(id: String, rar: int) -> String:
	var d := String(ALL.get(id, {}).get("desc", ""))
	if active(id) and mult(rar) > 1.0 and ALL[id].has("effects"):
		d += "  (%s: +%d%% power, %ds cooldown)" % [String(Data.RARITY[clampi(rar, 0, Data.RARITY.size() - 1)].get("name", "Rare")), int(round((mult(rar) - 1.0) * 100.0)), int(round(cd_of(id, rar)))]
	return d

## An active glove as an AbilityDef, for its aim indicator and for bots.
static var _defs := {}
static func def_of(id: String) -> AbilityDef:
	if _defs.has(id):
		return _defs[id]
	var g: Dictionary = ALL.get(id, {})
	var d := AbilityDef.from_dict({"id": id, "name": g.get("name", id), "short": g.get("short", ""), "verb": g.get("verb", ""), "icon": g.get("icon", id),
		"color": "#" + (g.get("col", Color.WHITE) as Color).to_html(false), "cooldown": g.get("cd", 0.0), "effects": g.get("effects", []), "bot": g.get("bot", {}), "aim": g.get("aim", []), "desc": g.get("desc", "")})
	if not g.has("effects") and g.get("aim", []).is_empty():
		d.aim = ["self", 0.0, 1.2]
	_defs[id] = d
	return d

static func stat_text(id: String, rar: int) -> String:
	var bits: Array = []
	var st: Dictionary = ALL[id]["stats"]
	var k := mult(rar)
	for s in st:
		var v := float(st[s]) * k
		match s:
			"speed": bits.append("%+d%% move speed" % int(round(v * 100)))
			"glide_speed": bits.append("+%d%% glide speed" % int(round(v * 100)))
			"heat": bits.append("+%d%% glider heat" % int(round(v * 100)))
			"armor": bits.append("+%d armor" % int(round(v)))
			"dmg": bits.append("+%d%% damage" % int(round(v * 100)))
			"cdr": bits.append("%d%% faster abilities" % int(round(v * 100)))
			"hp": bits.append("+%d health" % int(round(v)))
			"reload": bits.append("%d%% faster reloads" % int(round(v * 100)))
			"tonic": bits.append("tonics heal %d%% more" % int(round(v * 100)))
			"pack": bits.append("+%d backpack slot%s" % [pack_bonus(rar, float(st[s])), "" if pack_bonus(rar, float(st[s])) == 1 else "s"])
			"dodge": bits.append("dashes back %d%% sooner" % int(round(v * 100)))
			"gems": bits.append("+%d%% gems" % int(round(v * 100)))
			"sight": bits.append("+%d%% sight" % int(round(v * 100)))
	return ", ".join(bits)

## Backpack slots a kit adds at a rarity (rounded: 1 up to Rare, 2 from Epic).
static func pack_bonus(rar: int, base: float) -> int:
	return int(round(base * mult(rar)))

static func roll(r: RandomNumberGenerator) -> String:
	var keys: Array = ALL.keys()
	keys.sort()
	return keys[r.randi_range(0, keys.size() - 1)]

## Gear stats that change a number worked out once (max health, backpack size) are re-applied here
## whenever the worn gear changes. What was added last time is kept on the hunter, so it never stacks.
static func apply_worn(h) -> void:
	var hp_new: float = h.gear_stat("hp")
	var hp_old := float(h.get_meta("gear_hp", 0.0))
	if absf(hp_new - hp_old) > 0.01:
		var old_max: float = h.max_hp
		h.max_hp += hp_new - hp_old
		h.hp = clampf(h.hp * h.max_hp / maxf(old_max, 1.0), 1.0, h.max_hp)      # the same share of the bar, so swapping armor never heals
		h.set_meta("gear_hp", hp_new)
	var pk_new := Equal.pack_bonus(h)          # gear and perk "pack" stats plus a brought backpack (Equal.pack_slots)
	var pk_old := int(h.get_meta("gear_pack", 0))
	if pk_new != pk_old:
		h.pack_cap += pk_new - pk_old
		h.set_meta("gear_pack", pk_new)
