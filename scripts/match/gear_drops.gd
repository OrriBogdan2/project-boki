class_name GearDrops
extends RefCounted
## What falls out of chests, crates, guards, the Blight and bosses: gear for the four slots (Gear),
## utility items for the belt (UtilityBelt, odds in content/rules/equal.json) and weapon tunings (WeaponUps), rolled from
## the tables in content/rules/gear.json. There are no
## weapon drops any more (every hunter carries one fixed signature weapon), so this replaces them
## and the archetype-family weapon logic (DropFamily) with gear and upgrades.

static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/gear.json"))
		_rules = d if d is Dictionary else {}
	return _rules

static func table(name: String) -> Array:
	return (rules().get("tables", {}) as Dictionary).get(name, [])

## A rarity (0 Common .. 4 Legendary): the weighted roll, raised by `bonus` steps, never under `min_rar`.
static func roll_rarity(rng: RandomNumberGenerator, bonus := 0, min_rar := 0) -> int:
	var w: Array = rules().get("rarity_weights", [30, 36, 22, 9, 3])
	var tot := 0.0
	for x in w: tot += float(x)
	var r := rng.randf() * tot
	var idx := 0
	for i in w.size():
		r -= float(w[i])
		if r <= 0.0:
			idx = i
			break
	return clampi(maxi(idx + bonus, min_rar), 0, Data.RARITY.size() - 1)

## A slot index. `lean` (a region's slot weights, by slot name) multiplies the base weights.
static func roll_slot(rng: RandomNumberGenerator, lean := {}) -> int:
	var sw: Dictionary = rules().get("slot_weights", {})
	var tot := 0.0
	for sn in Gear.SLOTS: tot += float(sw.get(sn, 1.0)) * float(lean.get(sn, 1.0))
	var r := rng.randf() * tot
	for i in Gear.SLOTS.size():
		r -= float(sw.get(Gear.SLOTS[i], 1.0)) * float(lean.get(Gear.SLOTS[i], 1.0))
		if r <= 0.0:
			return i
	return 0

## One piece of gear: {id, rar}. slot -1 rolls the slot too.
static func roll_gear(rng: RandomNumberGenerator, bonus := 0, min_rar := 0, slot := -1, lean := {}) -> Dictionary:
	var sl := slot if slot >= 0 else roll_slot(rng, lean)
	var ids := Gear.ids_for(sl)
	if ids.is_empty():
		ids = Gear.ids_for(0)
	return {"id": String(ids[rng.randi() % ids.size()]), "rar": roll_rarity(rng, bonus, min_rar)}

## Where around a drop point the nth item of a pile lands.
static func spot(at: Vector3, n: int, count: int, r := -1.0) -> Vector3:
	var a := TAU * float(n) / float(maxi(count, 1)) + 0.6
	if r < 0.0:
		r = float(rules().get("ground_spacing", 1.25))
	return at + Vector3(cos(a) * r, 0, sin(a) * r)

## Plays a table at a point: spawns what its rolls produce and returns the pickups made (each
## {kind, id, rar}). ctx: bonus (extra rarity steps from the region), lean (slot weights), h (who
## earned it, so a tuning can skip upgrades they've maxed), r (the pile's radius), net (false when a remote copy will spawn).
static func run_table(m, name: String, at: Vector3, rng: RandomNumberGenerator, ctx := {}) -> Array:
	var made: Array = []
	var rolls := table(name)
	var lean: Dictionary = ctx.get("lean", {})
	for e in rolls:
		if rng.randf() >= float(e.get("chance", 1.0)):
			continue
		var p := spot(at, made.size(), rolls.size(), float(ctx.get("r", -1.0)))
		if String(e.get("kind", "gear")) == "tune":
			var tid := WeaponUps.roll_tuning(rng, ctx.get("h", null), bool(e.get("brand", false)))
			if tid == "":
				continue
			m.spawn_tune(tid, p, "", bool(ctx.get("net", true)))
			made.append({"kind": "tune", "id": tid, "rar": 2})
		else:
			var rar_bonus := int(e.get("bonus", 0)) + int(ctx.get("bonus", 0))
			var g := roll_gear(rng, rar_bonus, int(e.get("min_rar", 0)), Gear.SLOTS.find(String(e.get("slot", ""))), lean)
			if float(e.get("legendary", 0.0)) > 0.0 and rng.randf() < float(e["legendary"]):
				g["rar"] = Data.RARITY.size() - 1
			m.spawn_gear(String(g["id"]), int(g["rar"]), p, "", bool(ctx.get("net", true)))
			made.append({"kind": "gear", "id": g["id"], "rar": g["rar"]})
	var ut := UtilityDrops.roll(m, name, at, rng, ctx)
	if not ut.is_empty():
		made.append(ut)
	return made

## What a bot starts with: a few slots filled, by its difficulty (what a player may bring: boots and
## gloves, never armor; Equal) and a spare utility item.
static func bot_start(h, rng: RandomNumberGenerator, diff: String) -> void:
	var cfg: Dictionary = (rules().get("bot_start", {}) as Dictionary).get(diff, {})
	UtilityDrops.bot_start(h, rng, diff)
	Backpacks.bot_start(h, rng, diff)
	var n := int(cfg.get("slots", 0))  # boots first, then up to two different active gloves (bots use both: Gloves)
	if n > 0:
		var b := roll_gear(rng, int(cfg.get("bonus", 0)), 0, 3)
		h.gear[3] = {"id": b["id"], "rar": b["rar"]}
	Gloves.bot_fill(h, rng, n - 1, int(cfg.get("bonus", 0)))
	h.refresh_gear()

## Should a bot walking past this piece take it? An empty slot, or a rarer piece than the worn one.
static func bot_wants(h, gid: String, rar: int) -> bool:
	var cur: Dictionary = h.gear[Gear.slot_on(h, gid)]
	return cur.is_empty() or rar > int(cur.get("rar", 0))

## Test hook (--gear-demo): a hunter dressed in one piece per slot at mixed rarities, with a few weapon
## upgrades taken, and a boss's drop plus a chest's lying around their feet.
static func demo(m) -> void:
	var P = m.player
	P.gear = [{"id": "blink", "rar": 3}, {"id": "focus", "rar": 1}, {"id": "bastion_plate", "rar": 2},
			{"id": "skylark_boots", "rar": 4}]
	P.refresh_gear()
	for pk in ["hotload", "hotload", "quickfeed", "longreach", "brand_fire"]:
		P.add_perk(pk)
	P.hp = P.max_hp * 0.8
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var base: Vector3 = P.pos + Vector3(0, 0, -3.2)
	run_table(m, "boss", base, rng, {"r": 1.7, "net": false})
	run_table(m, "chest", base + Vector3(-5.0, 0, 1.0), rng, {"net": false, "h": P})
	run_table(m, "chest", base + Vector3(5.0, 0, 1.0), rng, {"net": false, "h": P, "bonus": 2})
	m.spawn_val(Loot.rare_egg("zapple", "Ember Brute"), base + Vector3(0, 0, -3.0))
