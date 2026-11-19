class_name Equal
extends RefCounted
## Equal footing in matches (docs/decisions/0005-equal-footing.md). Everyone drops on the same base:
## the same body, the same base armor, no perks, one pack size. What you may bring from home is
## only gloves, boots and utility items, each capped by the difficulty tier (content/rules/equal.json):
##   gloves and boots   their rarity must be within rarity_cap_by_tier (a higher piece stays home)
##   utility            charges from your farm stash, at most UtilityBelt.bring_cap per item
## What you bring is at risk: die and it is in your deathbox like everything else.
## The workshop and guild-project perks, the bigger home backpack and armor from the armory are gone.

const BRING_SLOTS := [0, 1, 3]  # gear KINDS that may come from home (Gear.slot_of): active glove, passive glove, boots

static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/equal.json"))
		_rules = d if d is Dictionary else {}
	return _rules

# ------------------------------------------------------------------ backpack size (one place)
## Backpack slots every hunter starts with (content/rules/equal.json base_pack): the same for all.
static func base_pack() -> int:
	return int(rules().get("base_pack", 6))

## Slots the backpack a hunter wears adds (Backpacks: the Pouch adds none).
static func backpack_bonus(h) -> int:
	return Backpacks.slots(int(h.backpack))

## Slots on top of the base: a brought backpack plus every "pack" stat from worn gear and perks
## (the satchel perk's +1 is a perk with stats {"pack": 1}). Gear.apply_worn keeps h.pack_cap in step.
static func pack_bonus(h) -> int:
	return backpack_bonus(h) + int(round(h.gear_stat("pack")))

## A hunter's backpack size: base + brought backpack + gear and perk bonuses.
static func pack_slots(h) -> int:
	return base_pack() + pack_bonus(h)

## The highest rarity (0 Common .. 4 Legendary) that may be brought at a difficulty tier.
static func rarity_cap(tier: int) -> int:
	var c: Array = rules().get("rarity_cap_by_tier", [4])
	return int(c[clampi(tier, 0, c.size() - 1)])

## Can this armory piece be brought at this tier? Gloves and boots within the cap only.
static func may_bring(it: Dictionary, tier: int) -> bool:
	if String(it.get("t", "")) != "gear" or not Gear.ALL.has(String(it.get("id", ""))):
		return false
	return BRING_SLOTS.has(Gear.slot_of(String(it["id"]))) and int(it.get("rar", 0)) <= rarity_cap(tier)

## Does this piece salvage on arrival instead of being stored? Armor: it is found, not kept.
static func salvages(it: Dictionary) -> bool:
	return String(it.get("t", "")) == "gear" and Gear.ALL.has(String(it.get("id", ""))) \
			and Gear.slot_of(String(it["id"])) == 2

## Why a piece can't come, for the expedition panel ("" when it can).
static func why_not(it: Dictionary, tier: int) -> String:
	if may_bring(it, tier):
		return ""
	if int(it.get("rar", 0)) > rarity_cap(tier):
		return "%s or lower at %s" % [Data.RARITY[rarity_cap(tier)]["name"],
				Data.TIERS[clampi(tier, 0, Data.TIERS.size() - 1)]["name"]]
	return "Not allowed in matches"

# ------------------------------------------------------------------ setting out (the farm side)
## The loadout leaves the armory and rides with you. Only pieces that may come at this tier go;
## the rest stay in the armory. Returns the pieces.
static func take_loadout(tier: int) -> Array:
	Econ.ensure_min()
	var out: Array = []
	var ids := {}
	for slot in Econ.LOADOUT_SLOTS:
		var it := Econ.loadout(slot)
		if it.is_empty() or not may_bring(it, tier) or ids.has(String(it["id"])):
			continue          # (two of the same glove can't be worn: the second stays home)
		ids[String(it["id"])] = true
		Save.d["armory"].erase(it)
		out.append(it)
	Save.d["raid_out"] = out.duplicate(true)
	return out

## The utility you picked (Save.d["belt_pick"], an item id per belt slot) leaves the stash: as many
## charges of each as the tier allows, counting the everyday issue. Returns one entry per slot:
## [{id, n (all charges), free (of them issued)}]; the match sets the belt from it (start).
static func take_belt(tier: int) -> Array:
	var out: Array = []
	var gone := {}
	var iss: Dictionary = rules().get("issue", {})
	var pk := picks()
	for pi in UtilityBelt.SLOTS:
		var id := String(pk[pi])
		if not UtilityBelt.is_item(id) or gone.has(id):
			out.append({"id": "", "n": 0, "free": 0})
			continue
		var issued := int(iss.get(id, 0))
		var stash := stash_of(id)
		var took := clampi(UtilityBelt.bring_cap(id, tier) - issued, 0, stash)
		Save.d["items"][id] = stash - took
		gone[id] = took
		out.append({"id": id, "n": issued + took, "free": issued})
	Save.d["raid_belt"] = gone
	return out

## Charges of an item in the farm stash (the tonic stash is the old one; the rest sit beside it).
static func stash_of(id: String) -> int:
	return int(Save.d.get("items", {}).get(id, 0))

## The picks as the belt slots will hold them: which item sits in 1 to 4.
static func picks() -> Array:
	var p: Array = (Save.d.get("belt_pick", ["tonic", "armor_kit", "", ""]) as Array).duplicate()
	while p.size() < UtilityBelt.SLOTS:
		p.append("")
	return p

# ------------------------------------------------------------------ at the drop (the match side)
## Applies what you brought to the local player at the start of a match. Everything else about the
## hunter is already the same for everyone (Hunter.init_hunter).
static func start(m, h) -> void:
	var tier: int = m.tier
	h.backpack = mini(int(m.opts.get("backpack", Backpacks.POUCH)), Backpacks.cap(tier))
	h.pack_cap = pack_slots(h)
	h.set_meta("gear_pack", pack_bonus(h))       # (Gear.apply_worn counts changes from here)
	if "--equal-demo" in OS.get_cmdline_user_args():
		# screenshots: read here, not in main.gd (its budget)
		m.opts["equal_demo"] = true
		m.opts["no_drop"] = true
	if m.opts.get("training", false) or m.opts.get("tutorial", false) or m.opts.get("duel", false):
		return
	for it in m.opts.get("kit_items", []):
		if may_bring(it, tier):
			# gloves: Q first, then V
			h.gear[Gear.slot_on(h, String(it["id"]))] = {"id": it["id"], "rar": int(it["rar"])}
	# the belt: what you picked, in the order you picked it (slots 1 to 4)
	if m.opts.has("belt_items"):
		h.belt = UtilityBelt.empty()
		h.belt_free = {}
		var slots: Array = m.opts["belt_items"]
		for i in mini(slots.size(), UtilityBelt.SLOTS):
			var e: Dictionary = slots[i]
			if int(e.get("n", 0)) > 0:
				UtilityBelt.set_slot(h, i, String(e["id"]), int(e["n"]), int(e.get("free", 0)))
	h.refresh_gear()
	if m.opts.get("equal_demo", false):
		_demo(m, h)

## --equal-demo (screenshots): a full belt (two chest keys in slot 4), armor on its way to Epic, a little hurt.
static func _demo(m, h) -> void:
	h.gear[0] = {"id": "grapple", "rar": 3}
	h.gear[1] = {"id": "quake", "rar": 2}
	var t := Timer.new()          # held for the whole shot: the match keeps playing underneath
	t.wait_time = 0.2
	t.autostart = true
	m.add_child(t)
	t.timeout.connect(func(): _demo_late(m, h))
	h.belt = UtilityBelt.empty()
	h.belt_free = {}
	UtilityBelt.grant(h, "tonic", 3)
	UtilityBelt.grant(h, "armor_kit", 2)
	UtilityBelt.grant(h, "smoke", 2)
	UtilityBelt.grant(h, "chest_key", 2)
	h.armor_gain(780.0)
	h.hp = h.max_hp * 0.62
	h.armor = h.max_armor * 0.55

## Held every 0.2s (the rivals are in after the first tick): glove 2 cooling down, the bond part
## full, and a rival beside you so its overhead row shows (two gloves, one cooling down, a full bond).
static func _demo_late(m, h) -> void:
	if not is_instance_valid(h):
		return
	Settings.v["tips"] = false          # (a clean frame: no tip card, no level-up choice, no monsters close by)
	for mb in m.mobs:
		if is_instance_valid(mb) and not mb.dead and mb.flat_dist(h) < 30.0:
			mb.hp = 0.0
			mb.dead = true
			mb.visible = false
	h.gear_cd[1] = 9.0
	h.ult = 0.7
	h.hp = maxf(h.hp, h.max_hp * 0.62)
	for o in m.hunters:
		if o != h and o.team != h.team:
			var at: Vector3 = h.pos + Vector3(-3.5, 0, 2.5)
			for off in [Vector3(-3.5, 0, 2.5), Vector3(3.5, 0, 2.5), Vector3(-3.5, 0, -2.5), Vector3(3.5, 0, -2.5)]:
				var p: Vector3 = h.pos + off
				if not m.world.is_void(p.x, p.z) and not m.world.is_block(p.x, p.z):
					at = Vector3(p.x, m.world.ground_at(p.x, p.z), p.z)
					break
			o.teleport(at)
			o.reveal_t = 1.0
			o.ctrl = "remote"           # stands still for the shot (no bot mind)
			o.gear[0] = {"id": "blink", "rar": 4}
			o.gear[1] = {"id": "barrier", "rar": 1}
			o.gear_cd[1] = 8.0
			o.ult = 1.0
			break

## What the belt gives back to the farm when the match ends: only if you got out, and only what is
## above the everyday issue ({id: n}).
static func belt_home(h, extracted: bool) -> Dictionary:
	return UtilityBelt.keepers(h) if extracted else {}

## A match result's belt goes into the stash. A belt that never came home is simply gone (it was
## at risk); a crash mid-match puts the brought charges back (Econ.ensure).
static func settle_belt(r: Dictionary) -> void:
	var items: Dictionary = Save.d["items"]
	var home: Dictionary = r.get("belt", {})
	for id in home:
		items[id] = int(items.get(id, 0)) + int(home[id])
	Save.d["raid_belt"] = {}

static func recover_belt() -> void:
	var left: Dictionary = Save.d.get("raid_belt", {})
	for id in left:
		Save.d["items"][id] = int(Save.d["items"].get(id, 0)) + int(left[id])
	Save.d["raid_belt"] = {}
