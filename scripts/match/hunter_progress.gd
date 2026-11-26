class_name HunterProgress
extends RefCounted
## A Hunter's levels and ranks: XP, spending skill points, the locked-key gate and perks.
## Hunter keeps the state and thin entry points.


static func gain_xp(h: Hunter, x: float) -> void:
	if h.lvl >= Hunter.XP_TO.size() or x <= 0.0 or not TutorialCamps.xp_ok(h):
		return
	if h.m and h.m.rolling:
		x = h.m.rolling.scale_xp(h, x)  # catch-up XP below the session's median level (Rolling.xp_mult)
	h.xp += x
	while h.lvl < Hunter.XP_TO.size() and h.xp >= float(Hunter.XP_TO[h.lvl]):
		h.lvl += 1
		h.skill_pts += 1
		if h.m and not h.remote:
			LevelGrowth.apply(h)  # every level: a little more health and ability power, quietly
		# one upward glow in the hunter's colour that everyone nearby sees (no ground ring: that means gameplay)
		if h.m and h.m.fx and h.visible and not h.unseen:
			h.m.fx.body_glow(h.pos, Arch.color(h.arch) if Arch.exists(h.arch) else Color("ffd27a"))
		if h.is_local() and h.m and h.m.hud:
			h.m.hud.level_up(h.lvl)
			LevelSfx.level_up(h.m)  # the soft rising bell run (tools/gen_sfx_ui.py)
			if h.kin is Kin:
				BokiChatter.say(h.m, h.kin, "level_up")
			h.level_ups += 1
	if not h.is_local():
		_bot_spend(h)


static func xp_frac(h: Hunter) -> float:
	if h.lvl >= Hunter.XP_TO.size():
		return 1.0
	var a := float(Hunter.XP_TO[h.lvl - 1])
	var b := float(Hunter.XP_TO[h.lvl])
	return clampf((h.xp - a) / (b - a), 0.0, 1.0)


static func can_level(h: Hunter, slot: String) -> bool:
	if h.skill_pts <= 0 or not Hunter.SLOT_MAX.has(slot) or int(h.slot_lv.get(slot, 0)) >= int(Hunter.SLOT_MAX[slot]):
		return false
	if not TutorialCamps.lets_level(h, slot):
		return false
	if slot == "ult":
		return (
			MergeForm.enabled() and h.lvl >= int(Hunter.ULT_AT[mini(int(h.slot_lv["ult"]), Hunter.ULT_AT.size() - 1)])
		)
	return true


static func level_slot(h: Hunter, slot: String) -> bool:
	if not can_level(h, slot):
		return false
	h.slot_lv[slot] = int(h.slot_lv[slot]) + 1
	h.skill_pts -= 1
	if slot == "ult" and h.merge_free and h.kin != null:
		# the merge unlocks with a full bond meter, once a run
		h.merge_free = false
		h.ult = 1.0
		if h.m and h.m.has_method("on_bond_ready"):
			h.m.on_bond_ready(h)
	if h.is_local() and h.m and h.m.hud:
		h.m.hud.ability_feedback({"sec": "sec", "dash": "dash", "kin": "k1", "ult": "r"}[slot], "cast")
		LevelSfx.rank(h.m, slot, int(h.slot_lv[slot]))
	return true


## Bots (and anyone skipping the choice) spend points in a sensible order.
static func _bot_spend(h: Hunter) -> void:
	var order := ["sec", "dash", "kin", "sec", "kin", "dash", "sec", "kin", "dash"]
	if h.ak:
		# the archetype's recommended order (ARCHETYPES §6) without the R (ranks 1-2 as they open, rank 3 once
		# every slot is rank 2) or any "gear" left in it (gloves don't rank)
		order = (
			(h.ak.d.get("order", []) as Array).filter(func(x): return x != "ult" and Hunter.SLOT_MAX.has(x))
			+ ["kin", "dash", "sec"]
		)
	while h.skill_pts > 0:
		if (
			can_level(h, "ult")
			and (int(h.slot_lv["ult"]) < 2 or Hunter.SLOTS.all(func(s): return int(h.slot_lv[s]) >= 2))
		):
			level_slot(h, "ult")
			continue
		var done := false
		# follow the order as a list of ranks (sec 1, dash 1, kin 1, gear 1, sec 2, ...), so every slot
		# opens early: the kin's abilities are locked until its slot has a point (KinRules slot locks)
		var want := {}
		for s in order:
			want[s] = int(want.get(s, 0)) + 1
			if int(h.slot_lv[s]) < int(want[s]) and int(h.slot_lv[s]) < int(Hunter.SLOT_MAX[s]) and can_level(h, s):
				level_slot(h, s)
				done = true
				break
		if not done:
			break


## Everything open at rank 1, for practice modes.
static func unlock_all(h: Hunter) -> void:
	for s in Hunter.SLOTS:
		h.slot_lv[s] = maxi(int(h.slot_lv[s]), 1)
	h.skill_pts = 0


## Every ability key pressed this step: a locked one takes a point if you have one (_gate).
static func gate_ranks(h: Hunter) -> void:
	for gk in Hunter.SLOT_GATES:
		_gate(h, gk[0], gk[1], gk[2])


## Pressing a locked ability: spend a point on it if you have one, otherwise say it's locked.
static func _gate(h: Hunter, key: String, slot: String, fb: String) -> void:
	if not h.inp.get(key, false) or int(h.slot_lv[slot]) > 0:
		return
	h.inp[key] = false
	if key == "dash":
		h.dash_buf = 0.0
	if h.is_local() and level_slot(h, slot):
		return
	h._ab_feedback(fb, "deny")
	if h.is_local() and h.m.hud:
		if slot == "ult" and h.skill_pts > 0:
			h.m.hud.toast("Ultimate unlocks at level %d" % int(Hunter.ULT_AT[0]), Color("a2a8bb"))
		else:
			h.m.hud.toast(TutorialCamps.locked_text(h), Color("a2a8bb"))


## How many stacks of a perk you've picked up this run.
static func perk_n(h: Hunter, id: String) -> int:
	return h.perks.count(id)


## Can this perk still be offered to you (a free perk slot, not at its stack limit)?
static func perk_open(h: Hunter, id: String) -> bool:
	if id == "secondwind" and h.ak and h.ak.single_dash():
		return false
	var below_max := perk_n(h, id) < int(Data.PERKS.get(id, {}).get("max", 1))
	return h.perks.size() < PerkOrbs.slots() and below_max and WeaponUps.fits(h, id)


## Takes a perk for the rest of the expedition. Stats that are worked out once (health, glider,
## armor) are updated on the spot.
static func add_perk(h: Hunter, id: String) -> void:
	if not Data.PERKS.has(id) or not perk_open(h, id):
		return
	h.perks.append(id)
	h.worn_sums.clear()
	match id:
		"toughskin":
			h.max_hp += 15.0
			h.hp = minf(h.max_hp, h.hp + 15.0)
		"featherfall":
			h.glide_max *= 1.6
	if (Data.PERKS[id] as Dictionary).has("wup"):
		WeaponUps.apply(h)
	h.refresh_gear()
