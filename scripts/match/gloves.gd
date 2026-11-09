class_name Gloves
extends RefCounted
## The two glove slots (docs/decisions/0005-equal-footing.md): glove 1 on Q (h.gear[0]) and glove 2
## on V (h.gear[1]). Either slot holds an active glove (it casts on its key) or a passive one (its
## stats only). Two of the same glove can't be worn: a second copy replaces the first.
## Gloves never rank up: a worn glove casts at full strength at once (its rarity is its only
## strength), with no skill point and no level gate. Skill points go to the hero's own abilities.

const SLOTS := [0, 1]
const KEYS := ["gear1", "gear2"]          # the input actions (Q and V by default)

## Where this glove goes on this hunter: the slot already holding the same glove (it replaces it),
## else the first empty glove slot, else the slot with the weaker glove (slot 1 on a tie).
static func slot_for(h, id: String) -> int:
	for i in SLOTS:
		if String((h.gear[i] as Dictionary).get("id", "")) == id:
			return i
	for i in SLOTS:
		if (h.gear[i] as Dictionary).is_empty():
			return i
	var v0 := Loot.value(Loot.gear(String(h.gear[0]["id"]), int(h.gear[0]["rar"])))
	var v1 := Loot.value(Loot.gear(String(h.gear[1]["id"]), int(h.gear[1]["rar"])))
	return 0 if v0 < v1 else 1

## The glove in slot i ({} when empty).
static func worn(h, i: int) -> Dictionary:
	return h.gear[i] if i >= 0 and i < 2 else {}

## The key cap for a glove slot (Q, V).
static func key_cap(i: int) -> String:
	return Settings.key_cap(KEYS[clampi(i, 0, 1)])

## Cooldown left as a share of the full one (0 when ready or empty).
static func cd_frac(h, i: int) -> float:
	var g := worn(h, i)
	if g.is_empty() or not Gear.active(String(g["id"])):
		return 0.0
	return clampf(float(h.gear_cd[i]) / maxf(0.1, Gear.cd_of(String(g["id"]), int(g.get("rar", 1)))), 0.0, 1.0)

## Puts two gloves on at once (bring-in, bots): the first in slot 0, a different one in slot 1.
static func wear_pair(h, a: Dictionary, b: Dictionary) -> void:
	if not a.is_empty(): h.gear[slot_for(h, String(a["id"]))] = {"id": a["id"], "rar": int(a["rar"])}
	if not b.is_empty(): h.gear[slot_for(h, String(b["id"]))] = {"id": b["id"], "rar": int(b["rar"])}

## A bot's starting gloves: up to two different ACTIVE gloves (bots use both), rolled from the
## gear drop table at the bot's bonus. `n` is how many glove slots to fill.
static func bot_fill(h, rng: RandomNumberGenerator, n: int, bonus: int) -> void:
	var got: Array = []
	for i in mini(n, 2):
		var g := {}
		for tries in 8:
			g = GearDrops.roll_gear(rng, bonus, 0, 0)
			if not got.has(String(g["id"])):
				break
		if got.has(String(g["id"])):
			continue
		got.append(String(g["id"]))
		h.gear[i] = {"id": g["id"], "rar": g["rar"]}

## A bot's glove use, both slots: each active glove fires when its own moment comes (hook in range,
## a wall when shot at...), on its own key. `aim_of` is Bot.ability_aim bound to the match and bot.
static func bot_use(h, tgt, abil: float, inp: Dictionary, aim_of: Callable) -> void:
	for i in SLOTS:
		var g := worn(h, i)
		if g.is_empty() or float(h.gear_cd[i]) > 0.0 or not Gear.active(String(g["id"])) or randf() >= 0.3 + abil * 0.6:
			continue
		var gdf := Gear.def_of(String(g["id"]))
		var ga: Vector3 = aim_of.call(gdf, tgt)
		if ga == Vector3.INF and gdf.bot.is_empty() and randf() < abil * 0.3:
			ga = tgt.pos        # an old glove with no hints: now and then, at the target
		if ga != Vector3.INF:
			h.inp["aim"] = ga
			inp[KEYS[i]] = true
			return              # one glove a step: the other gets its own moment
