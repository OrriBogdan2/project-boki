class_name HunterGear
extends RefCounted
## What a Hunter wears: armor tiers and durability, the worn-gear stat sums, and the mount speed.


## Adds armor progress; returns the new tier if it went up, else -1.
static func armor_gain(h: Hunter, xp_amount: float) -> int:
	h.armor_xp += xp_amount
	var up := -1
	while h.armor_tier < Hunter.ARMOR_TIERS.size() - 1 and h.armor_xp >= float(Hunter.ARMOR_TIERS[h.armor_tier + 1][2]):
		h.armor_tier += 1
		up = h.armor_tier
	if up >= 0:
		var old := h.max_armor
		refresh_gear(h)
		h.armor = minf(h.max_armor, h.armor + maxf(0.0, h.max_armor - old))
	return up


## How far into the current tier (0..1), for the HUD.
static func armor_frac(h: Hunter) -> float:
	if h.armor_tier >= Hunter.ARMOR_TIERS.size() - 1:
		return 1.0
	var a := float(Hunter.ARMOR_TIERS[h.armor_tier][2])
	var b := float(Hunter.ARMOR_TIERS[h.armor_tier + 1][2])
	return clampf((h.armor_xp - a) / (b - a), 0.0, 1.0)


static func armor_col(h: Hunter) -> Color:
	return Hunter.ARMOR_TIERS[h.armor_tier][1]


static func refresh_gear(h: Hunter) -> void:
	h.worn_sums.clear()
	h.max_armor = float(Hunter.ARMOR_TIERS[h.armor_tier][4]) + gear_stat(h, "armor")
	h.armor = minf(h.armor, h.max_armor)
	Gear.apply_worn(h)


static func gear_stat(h: Hunter, k: String) -> float:
	var t := _worn_stat(h, k)
	if h.kin != null and is_instance_valid(h.kin) and (k == "armor" or k == "sight"):
		t += Mutations.owner_stat((h.kin as Kin).rec, k)  # a Crystal or Glowing kin helps its hunter
	# your kin: its owner bonus points, carry passives, the merge and short ability buffs
	match k:
		"speed":
			t += h.owner_stat("move_speed") + h.kin_pt("owner_move_speed") + h.buff("move_speed")
		"dmg":
			t = KinMerge.cap_damage(h, t, h.owner_stat("damage") + h.buff("damage"))
		"heat", "glide_speed":
			t += h.owner_stat("glide")
		"cdr":
			t += h.owner_stat("cooldown")
	return t


## What the four gear slots and the perks add to a stat. Summed once a step (and again after
## refresh_gear or a new perk): with ten squads these sums were a tenth of Hunter.sim.
static func _worn_stat(h: Hunter, k: String) -> float:
	var now: float = h.m.time if h.m else 0.0
	if now != h.worn_t:
		h.worn_sums.clear()
		h.worn_t = now
	if h.worn_sums.has(k):
		return h.worn_sums[k]
	var t := 0.0
	for g in h.gear:
		if not g.is_empty():
			t += float(Gear.ALL[g["id"]]["stats"].get(k, 0.0)) * Gear.mult(int(g["rar"]))
	for pk in h.perks:
		t += float((Data.PERKS.get(pk, {}).get("stats", {}) as Dictionary).get(k, 0.0))
	h.worn_sums[k] = t
	return t


## Ground speed while you ride your mount (its carry.mount speed), as a share of your own.
static func mount_speed(h: Hunter) -> float:
	var k: Kin = h.kin
	return float(k.ks.mount.get("speed", 1.0)) if k and k.ks else 1.0
