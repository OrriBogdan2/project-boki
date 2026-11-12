class_name WeaponUps
extends RefCounted
## In-run weapon upgrades. A hunter carries one fixed signature weapon (Arch.signature) and grows it
## through the run instead of swapping it: upgrade perks (Data.PERKS entries with a "wup" block) come
## from the hero's fixed weapon path (WeaponPath, every even level), perk orbs (PerkOrbs: chests,
## shrines, bosses), and "tuning" pickups lying on the ground. They last the expedition, like every perk.
##
## "wup" keys: dmg (+fraction of damage), mag (+fraction of magazine), rate (change to the time
## between shots, negative = faster), range (+fraction of range or reach), brand (an element id from
## Loot.ELEMENTS: every hit carries that rider; the latest Brand taken wins).

static func total(h, key: String) -> float:
	var t := 0.0
	for pk in h.perks:
		t += float((Data.PERKS.get(pk, {}).get("wup", {}) as Dictionary).get(key, 0.0))
	return t

## The element of the latest Brand taken, "" if none.
static func brand_of(h) -> String:
	for i in range(h.perks.size() - 1, -1, -1):
		var b := String((Data.PERKS.get(h.perks[i], {}).get("wup", {}) as Dictionary).get("brand", ""))
		if b != "":
			return b
	return ""

## Rebuilds the weapon in hand from its plain stats plus this run's upgrades. Magazine growth also
## tops the loaded rounds up by the difference.
static func apply(h) -> void:
	var w: Dictionary = Data.weapon_stats(h.wid)
	var old_mag := int(h.wpn.get("mag", w["mag"])) if not h.wpn.is_empty() else int(w["mag"])
	var dk := 1.0 + total(h, "dmg")
	h.wup_dmg = dk
	w["dmg"] = float(w["dmg"]) * dk
	if w.has("combo_dmg"): w["combo_dmg"] = (w["combo_dmg"] as Array).map(func(x): return float(x) * dk)
	if w.has("charged_dmg"): w["charged_dmg"] = float(w["charged_dmg"]) * dk
	w["mag"] = int(round(float(w["mag"]) * (1.0 + total(h, "mag"))))
	w["rate"] = float(w["rate"]) * maxf(0.4, 1.0 + total(h, "rate"))
	w["range"] = float(w["range"]) * (1.0 + total(h, "range"))
	h.wpn = w
	h.welem = brand_of(h)
	if int(w["mag"]) != old_mag and h.ammo > 0:
		h.ammo = clampi(h.ammo + int(w["mag"]) - old_mag, 1, int(w["mag"]))

## An upgrade is only offered if it does something for this weapon: a bigger magazine is no use to a
## blade or a bow that draws one shot at a time.
static func fits(h, id: String) -> bool:
	var wu: Dictionary = Data.PERKS.get(id, {}).get("wup", {})
	if wu.has("mag") and not h.wpn.is_empty():
		var ws := Data.weapon_stats(h.wid)
		return ws.get("ammo", true) and int(ws["mag"]) > 3
	return true

## Upgrade perks that can still be offered to this hunter, optionally only Brands or only the plain ones.
static func open_ids(h, brands: bool) -> Array:
	return Data.PERKS.keys().filter(func(k): return Data.PERKS[k].has("wup") and h.perk_open(k) and (Data.PERKS[k]["wup"].has("brand") == brands))

## A tuning for a pickup on the ground: a Brand (the high-value one) or a plain upgrade this hunter
## can still use, else any upgrade at all.
static func roll_tuning(rng: RandomNumberGenerator, h = null, brand := false) -> String:
	var pool: Array = []
	for k in Data.PERKS:
		if Data.PERKS[k].has("wup") and Data.PERKS[k]["wup"].has("brand") == brand and (h == null or h.perk_open(k)):
			pool.append(k)
	if pool.is_empty():
		return ""
	pool.sort()
	return String(pool[rng.randi() % pool.size()])

## "Hotload x2, Deep Magazine, Ember Brand": the upgrades on your weapon, "" when it's plain.
static func summary(h) -> String:
	var seen: Array = []
	var bits: Array = []
	for pk in h.perks:
		if Data.PERKS.get(pk, {}).has("wup") and not seen.has(pk):
			seen.append(pk)
			var n: int = h.perks.count(pk)
			bits.append(String(Data.PERKS[pk]["name"]) + (" x%d" % n if n > 1 else ""))
	return ", ".join(bits)
