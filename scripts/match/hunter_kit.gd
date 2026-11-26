class_name HunterKit
extends RefCounted
## A Hunter's ability slots: ranks, tooltips, the cooldown scale, casting kin, Boki and ultimate abilities,
## swapping kin and the kin riders.


static func ability_level(h: Hunter, slot: String) -> int:
	var s := String(Hunter.SLOT_ALIAS.get(slot, slot))
	return maxi(1, int(h.slot_lv.get(s, 1)))


## The rank line on an ability's hover panel ("" for things that don't rank).
static func rank_text(h: Hunter, slot: String) -> String:
	var s := String({"sec": "sec", "k1": "kin", "dash": "dash", "r": "ult"}.get(slot, ""))
	if s == "":
		return ""
	var lv := int(h.slot_lv.get(s, 0))
	var mx := int(Hunter.SLOT_MAX[s])
	var per := (
		"+30% duration, +15% damage"
		if s == "ult"
		else ("15% faster recharge" if s == "dash" else "+15% damage, 10% shorter cooldown, longer/bigger effects")
	)
	if lv <= 0:
		return "Locked  ·  a skill point unlocks it"
	if h.ak and lv < mx:
		# an archetype slot: the next rank's concrete change (rank 2 when you're rank 1)
		var nr := Arch.next_ranks(h.arch, s, lv)
		if not nr.is_empty():
			per = String(nr[0][1])
	return "Rank %d / %d%s" % [lv, mx, ("  ·  next rank: " + per) if lv < mx else "  ·  max rank"]


## Cooldown multiplier for a slot's rank: 10% shorter per rank past the first.
static func rank_cd_k(h: Hunter, slot: String) -> float:
	return 1.0 - 0.1 * float(ability_level(h, slot) - 1)


## What the HUD needs to draw one ability slot: name, short name, icon, colour, one-line desc,
## cooldown left and total, charges. slot: "sec" | "dash" | "gear" | "k1" | "r".
static func slot_info(h: Hunter, slot: String) -> Dictionary:
	var mki := MergeKit.slot_info(h, slot)
	if not mki.is_empty():
		return mki  # merged: the form's slots
	if h.ak and (slot in ["sec", "utility", "k1", "e", "kin", "dash", "dodge", "x"]):
		return h.ak.slot_info(slot)
	var out_list := {
		"name": "",
		"short": "",
		"icon": "",
		"col": Color.WHITE,
		"desc": "",
		"cd": 0.0,
		"cd_max": 0.0,
		"charges": 0,
		"max_charges": 0,
		"verb": "",
		"ready": false,
		"level": ability_level(h, slot)
	}
	match slot:
		"sec", "utility":
			var d: AbilityDef = h.runner.def_of("utility") if h.runner else null
			if d == null:
				return out_list
			out_list.merge(
				{
					"name": d.display_name,
					"short": d.short,
					"icon": d.icon,
					"col": d.color,
					"desc": d.desc,
					"cd": h.runner.cd_left("utility"),
					"cd_max": h.runner.cd_max("utility"),
					"charges": h.runner.charges("utility"),
					"max_charges": d.charges,
					"verb": d.verb,
					"ready": h.runner.is_ready("utility"),
					"charge": h.charge_frac()
				},
				true
			)
		"dash", "dodge":
			var d: AbilityDef = h.dodge_def
			var dmax := h.max_dashes()
			out_list.merge(
				{
					"name": d.display_name if d else "Dash",
					"short": d.short if d else "Dash",
					"icon": d.icon if d else "dash",
					"col": d.color if d else Color("bfe6ff"),
					"desc": d.desc if d else "",
					"cd": (1.0 - fposmod(h.dashes, 1.0)) * h.dash_regen() if h.dashes < dmax - 0.001 else 0.0,
					"cd_max": h.dash_regen(),
					"charges": int(floor(h.dashes)),
					"max_charges": int(dmax),
					"verb": d.verb if d else "dash",
					"ready": h.dashes >= 1.0
				},
				true
			)
		"gear", "gear0", "q", "gear1", "v":
			var gi := 1 if slot in ["gear1", "v"] else 0  # glove 1 (Q) or glove 2 (V); gloves never rank (Gloves)
			var g: Dictionary = h.gear[gi]
			if g.is_empty() or not Gear.ALL.has(String(g["id"])):
				return out_list
			var gd: Dictionary = Gear.ALL[String(g["id"])]
			out_list.merge(
				{
					"name": String(gd["name"]),
					"short": String(gd.get("short", gd["name"])),
					"icon": Gear.icon_of(String(g["id"])),
					"col": gd["col"],
					"desc": Gear.desc_of(String(g["id"]), int(g["rar"])),
					"cd": float(h.gear_cd[gi]),
					"cd_max": Gear.cd_of(String(g["id"]), int(g["rar"])),
					"charges": 1 if float(h.gear_cd[gi]) <= 0.0 else 0,
					"max_charges": 1,
					"verb": String(gd.get("verb", "")),
					"ready": float(h.gear_cd[gi]) <= 0.0 and Gear.active(String(g["id"]))
				},
				true
			)
		"k1", "e":
			var k: Kin = h.kin
			if k == null or k.runner == null:
				return out_list
			var d: AbilitySpec = k.runner.def_of("k1")
			if d == null:
				return out_list
			out_list.merge(
				{
					"name": d.display_name,
					"short": d.short,
					"icon": KinText.icon(d),
					"col": KinText.color(d),
					"desc": KinText.ability(k.effective("k1")),
					"cd": k.runner.cd_left("k1"),
					"cd_max": k.runner.cd_max("k1"),
					"charges": k.runner.charges("k1"),
					"max_charges": d.charges,
					"verb": d.stages[0].delivery.type,
					"element": d.theme,
					"ready": k.runner.is_ready("k1") and k.ready_to_fight()
				},
				true
			)
		"r", "ult":
			var k := h.kin as Kin
			var u := KinMerge.def_for(k) if k and KinMerge.boki_with_you(h) else null
			var f := MergeForm.for_boki(k) if u else MergeForm.surge_form()
			var txt: String = (
				" ".join(KinText.merge(u, k.carry_style() == "mount"))
				if u
				else String(MergeForm.data()["surge"]["flavor"])
			)
			out_list.merge(
				{
					"name": "Fusion",
					"short": "Fusion",
					"icon": KinText.merge_icon(u),
					"col": f["glow"],
					"desc": txt,
					"form": f,
					"bond": h.ult,
					"plan": KinMerge.plan(h),
					"cd": h.merge_cd,
					"cd_max":
					(
						maxf(KinParts.MERGE_SPENT_TIME, MergeRelease.rest_s())
						if h.kin != null and h.kin.resting()
						else KinParts.MERGE_SPENT_TIME
					),
					"charges": 1 if h.ult >= 1.0 else 0,
					"max_charges": 1,
					"ready": KinMerge.plan(h) in ["merge", "leap", "surge"]
				},
				true
			)
	return out_list


## Q and V: your active kin's abilities, aimed at the cursor.
static func use_kin_ability(h: Hunter, slot: String) -> void:
	var k: Kin = h.kin
	if k == null or h.downed or h.dropping or h.riding:
		return
	if not k.ready_to_fight():
		_ab_feedback(h, slot, "deny")
		if h.is_local() and h.m.hud:
			h.m.hud.toast(
				(
					"%s is resting%s"
					% [
						k.rec.get("name", "Your Boki"),
						(
							(
								"  ·  %s swaps in %s"
								% [Settings.key_cap("swap_kin"), (h.kin2 as Kin).rec.get("name", "your other Boki")]
							)
							if h.kin2 and (h.kin2 as Kin).hp > 0.0
							else ""
						)
					]
				),
				Color("a2a8bb")
			)
		return
	if k.use_ability(slot, h._ground_aim()) or k.pend_slot == slot:
		h.used[slot] = int(h.used.get(slot, 0)) + 1
		_ab_feedback(h, slot, "cast")
		if h.is_local():
			# tie the button to what happened: a flash line from you to the kin doing it, if it's away
			var kc := KinText.color(k.runner.def_of(slot))
			if k.flat_dist(h) > 2.5 and k.state != "shoulder":
				h.m.fx.bolt(h.pos + Vector3(0, 1.2, 0), k.pos + Vector3(0, 0.6, 0), Color(kc, 0.8))
	else:
		_ab_feedback(h, slot, "deny")


## C (with an archetype): your Boki's own ability, cast from wherever the Boki is (KinCommand.cast_c).
## On your shoulder it is cast through you; out in the field it casts where it stands.
static func use_boki_c(h: Hunter) -> void:
	if KinCommand.cast_c(h):
		if h.is_local() and h.m.sfx:
			h.m.sfx("skill", null, -10.0, 1.3)
		return
	_ab_feedback(h, "k1", "deny")
	var why := KinCommand.c_deny_text(h)
	if why != "" and h.is_local() and h.m.hud:
		h.m.hud.toast_small(why, Color("ffb0a0"))


## R: the Merge (KinMerge.press): a full bond meter merges you with your Boki, with the Boki out it
## leaps back and merges, with none able to fight it is a weak surge.
static func use_ultimate(h: Hunter) -> void:
	if KinMerge.press(h):
		_ab_feedback(h, "r", "cast")
		return
	_ab_feedback(h, "r", "deny")
	var why := KinMerge.deny_text(h)
	if why != "" and h.is_local() and h.m.hud:
		h.m.hud.toast_small(why, Color("a2a8bb"))


## Tells the HUD a button press landed ("cast": the slot pops) or didn't ("deny": PressDeny's red pulse
## and tick), so a press on cooldown never just silently does nothing.
static func _ab_feedback(h: Hunter, slot: String, kind_name: String) -> void:
	if not h.is_local() or h.m.hud == null or not h.m.hud.has_method("ability_feedback"):
		return
	if kind_name == "deny":
		PressDeny.raise(h.m.hud, slot)
		return
	h.m.hud.ability_feedback(slot, kind_name)
	h.m.sfx("skill", null, -9.0, 1.15)


## X: swap which of your two kin is out. The benched one rests in your satchel.
static func swap_kin(h: Hunter, force := false) -> void:
	if h.kin2 == null or h.riding or h.out or (not force and (h.swap_cd > 0.0 or h.downed)):
		return
	var a: Kin = h.kin
	var b: Kin = h.kin2
	if b.dead or KinLoss.guarding(b) or (a and (a.state == "fused" or KinLoss.guarding(a))):
		return
	if a:
		a.bench()
	b.unbench()
	h.kin = b
	h.kin2 = a
	h.swap_cd = float(Content.rules("kin_ai").get("swap_cooldown", 3.0))
	h.m.on_kin_swap(h, b, a)


## Riders your kin puts on every shot or swing (KinSpec carry.on_shot while it rides with you, the
## merge's on_shot while merged): damage over time, slow, push, marks, splash and arcs. Never stun or root.
static func _kin_riders(h: Hunter, extra: Dictionary) -> void:
	var lists: Array = []
	var k: Kin = h.kin
	if k and k.ks and h.kin_carry_on() and not k.ks.carry_on_shot.is_empty():
		lists.append([k.ks.carry_on_shot, 1.0])
	var mo := KinMerge.on_shot(h)
	if not mo.is_empty():
		lists.append([mo, 1.0])
	MergeAugment.lmb(h, extra)  # a merge form's rider on this attack (docs/decisions/0004)
	for pair in lists:
		var os: Dictionary = pair[0]
		var kk: float = pair[1]
		for e in os.get("effects", []):
			var pr: Dictionary = (e as PartSpec).params
			match (e as PartSpec).type:
				"damage":
					if float(pr["over"]) > 0.0:
						extra["burn"] = maxf(
							float(extra.get("burn", 0.0)), float(pr["amount"]) * kk / float(pr["over"])
						)
						extra["burn_for"] = float(pr["over"])
					else:
						extra["ride_dmg"] = maxf(float(extra.get("ride_dmg", 0.0)), float(pr["amount"]) * kk)
				"slow":
					extra["slow"] = maxf(float(extra.get("slow", 0.0)), float(pr["duration"]))
					extra["slow_k"] = maxf(float(extra.get("slow_k", 0.0)), float(pr["strength"]))
					extra["dr"] = true
				"push":
					extra["kb"] = float(extra.get("kb", 0.0)) + float(pr["strength"]) * kk * 0.25
				"mark":
					extra["mark"] = [String(pr["mode"]), float(pr["duration"]), float(pr["amount"])]
		if float(os.get("splash", 0.0)) > 0.0 and not extra.has("boom"):
			extra["boom"] = float(os["splash"])
			extra["boom_kb"] = 4.0
			extra["boom_small"] = true
		if int(os.get("chain", 0)) > 0 and not extra.has("kx"):
			extra["fx_hit"] = [
				{
					"type": "chain",
					"count": int(os["chain"]),
					"first": 5.0,
					"dmg": float(h.wpn["dmg"]) * 0.5,
					"color": Color(h.wpn["color"]).to_html(false),
					"skip_here": true
				}
			]
			extra["fx_ctx"] = {"slot": "ult", "ability": "merge"}
