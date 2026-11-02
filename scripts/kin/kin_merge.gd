class_name KinMerge
extends RefCounted
## The merge: R for every class (docs/decisions/0001), run from the Boki's MergeSpec (content/merges_v2)
## and the form its type and power tier give (MergeForm). Core rules, not data (docs/KIN_GRAMMAR.md):
##   - R needs the bond meter full (fighting together fills it, Bond) and the ult slot, which opens at
##     run level Hunter.ULT_AT[0] (6); the first unlock fills the meter once, free
##   - Boki on your shoulder: you merge at once. Boki out in the field: it leaps back and merges mid-air
##     (Kin.merge_leap, hitting what is in its way). Boki downed, benched or lost, or none: a weak
##     surge instead (MergeForm.surge_spec), so a full meter is never wasted
##   - for a few seconds hunter and kin fight as one: the merge's owner passives (scaled by its
##     strength, capped at the merge maximums), riders on every shot, pulses, merged versions of the
##     kin's abilities, and the form's changes to your own abilities. A kin you ride (mount) grows
##     giant under you; any other kin fuses onto you
##   - it ends when time runs out, early if you're knocked or you throw the kin; then a short spent
##     window (KinParts.MERGE_SPENT_TIME) before it can go again. Call-back and throw stay available.
## State lives on the hunter: Hunter.merge_st {def, t, T, k, giant, pulse: [timers], form, surge} and merge_cd.

static func def_for(k: Ent) -> MergeSpec:
	if k == null or not (k is Kin):
		return null
	return KinLib.merge_of((k as Kin).species)

static func active(h: Hunter) -> bool:
	return h != null and not h.merge_st.is_empty()

## Is the meter full and the slot ready (not counting where the Boki is)?
static func ready(h: Hunter) -> bool:
	if h == null or h.ult < 1.0 or h.downed or h.out or h.riding or h.dropping or active(h) or h.merge_cd > 0.0:
		return false
	return int(h.slot_lv.get("ult", 0)) > 0

static func boki_with_you(h: Hunter) -> bool:
	var k: Kin = h.kin
	return k != null and not k.dead and k.state in ["shoulder", "active", "flying", "returning", "flying_home"]

static func can_cast(h: Hunter) -> bool:
	return ready(h) and boki_with_you(h)

## What R would do right now: "merge" (Boki on the shoulder), "leap" (Boki out: it comes back and merges),
## "surge" (no Boki able to fight), "far" (Boki out of leap range: call it back first), or "" (not ready).
static func plan(h: Hunter) -> String:
	if not ready(h):
		return ""
	var k: Kin = h.kin
	if not boki_with_you(h):
		return "surge"
	if k.state == "shoulder":
		return "merge"
	return "leap" if k.flat_dist(h) <= float(KinCommand.rules().get("merge_leap_range", 32.0)) else "far"

## R. Returns true if something started (a merge, a leap that merges on landing, or a surge).
static func press(h: Hunter) -> bool:
	match plan(h):
		"merge": return cast(h)
		"leap": return (h.kin as Kin).merge_leap()
		"surge": return surge(h)
	return false

## Why R did nothing, for the HUD toast ("" when there is nothing to say).
static func deny_text(h: Hunter) -> String:
	if active(h) or h.merge_cd > 0.0 or int(h.slot_lv.get("ult", 0)) <= 0:
		return ""
	if h.ult < 1.0:
		return "Bond %d%%: fight together to fill it" % int(h.ult * 100.0)
	return "Your Boki is too far: call it back first" if plan(h) == "far" else ""

## The weak merge with no Boki to give it a form: short, plain, but the full meter is spent on something.
static func surge(h: Hunter) -> bool:
	if plan(h) != "surge":
		return false
	h.ult = 0.0
	var ms := MergeForm.surge_spec()
	var form := MergeForm.surge_form()
	h.merge_st = {"def": ms, "t": ms.duration, "T": ms.duration, "k": 1.0, "giant": false, "pulse": [], "form": form, "surge": true}
	h._refresh_kin_stats()
	MergeLook.attach(h, form)
	MergeForm.activate(h.m, h.pos, form)
	CombatBus.ability_used.emit(h, ms.id, "ult")
	h.m.on_merge(h, null, ms)
	return true

## 0..1: how grown the merge is, from the kin's level and your bond (trust).
static func growth(k: Kin) -> float:
	var lv := clampf((float(k.rec.get("level", 1)) - 1.0) / 19.0, 0.0, 1.0)
	var tr := clampf(k.trust / 100.0, 0.0, 1.0)
	return lv * 0.5 + tr * 0.5

static func cast(h: Hunter) -> bool:
	if not can_cast(h):
		return false
	var k: Kin = h.kin
	var ms := def_for(k)
	if ms == null:
		return false
	h.ult = 0.0
	var g := growth(k)
	var rank := h.ability_level("ult")
	var form := MergeForm.for_boki(k)
	var dur := (ms.duration + ms.grow_duration * g + float(form["dur"])) * (1.0 + 0.3 * float(rank - 1))
	var strength := (1.0 + clampf(ms.grow_strength, 0.0, float(KinParts.MERGE["grow_strength"][2])) * g) * float(form["k"])
	var giant := k.carry_style() == "mount"
	var timers: Array = []
	for pl in ms.pulses:
		timers.append(float(pl["every"]))
	h.merge_st = {"def": ms, "t": dur, "T": dur, "k": strength, "giant": giant, "pulse": timers, "form": form, "surge": false}
	k.merge_in(giant)
	h._refresh_kin_stats()
	MergeLook.attach(h, form)
	MergeForm.activate(h.m, h.pos, form)
	var sh := h.owner_stat("shield")
	if sh > 0.0:
		h.shield = maxf(h.shield, sh)
		h.shield_t = maxf(h.shield_t, dur)
	if h.owner_stat("dodge_regen") >= 0.99:
		h.dashes = h.max_dashes()
	var cx := _cx(h, k, ms, strength, rank)
	KinExec.run_stages(ms.on_start, cx)
	CombatBus.ability_used.emit(h, ms.id, "ult")
	h.m.on_merge(h, k, ms)
	return true

static func _cx(h: Hunter, k: Kin, ms: MergeSpec, strength: float, rank: int) -> Dictionary:
	var aim: Vector3 = h.inp.get("aim", h.pos)
	return KinExec.make_cx(h.m, h, k, h, aim, k.ability_power() * strength * Effects.level_k({"level": rank}), "ult", ms.id)

## Every simulation step while merged: time, pulses, senses. Ends it when it's over or broken.
static func tick(h: Hunter, dt: float) -> void:
	if not active(h):
		h.merge_cd = maxf(0.0, h.merge_cd - dt)
		return
	var k: Kin = h.kin
	var surge_on: bool = h.merge_st.get("surge", false)
	if h.downed or h.out or h.extracted or (not surge_on and (k == null or k.dead or k.state in ["downed", "bench", "away"])):
		end(h, "knocked" if h.downed else "broken")
		return
	var st: Dictionary = h.merge_st
	st["t"] = float(st["t"]) - dt
	var ms: MergeSpec = st["def"]
	var timers: Array = st["pulse"]
	for i in ms.pulses.size():
		timers[i] = float(timers[i]) - dt
		if float(timers[i]) <= 0.0:
			timers[i] = float(ms.pulses[i]["every"])
			KinExec.run_stage(ms.pulses[i]["stage"], _cx(h, k, ms, float(st["k"]), h.ability_level("ult")))
	var rr := h.owner_stat("reveal_radius")
	if rr > 0.0:
		for o in h.m.hunters:
			if o.team != h.team and not o.out and o.flat_dist(h) < rr:
				o.reveal_t = maxf(o.reveal_t, 0.3)
	if float(st["t"]) <= 0.0:
		end(h, "time")

static func end(h: Hunter, why := "time") -> void:
	if not active(h):
		return
	var st: Dictionary = h.merge_st
	var ms: MergeSpec = st["def"]
	var k: Kin = h.kin
	h.merge_st = {}
	h.merge_cd = KinParts.MERGE_SPENT_TIME
	h._refresh_kin_stats()
	MergeLook.detach(h)
	if k and is_instance_valid(k) and not k.dead and not st.get("surge", false):
		if not h.downed and not h.out:
			KinExec.run_stages(ms.on_end, _cx(h, k, ms, float(st["k"]), h.ability_level("ult")))
		k.merge_out()
	h.m.on_merge_end(h, why)

## The merged patch for one of the kin's slots ({} when not merged or no patch).
static func patch(h: Hunter, slot: String) -> Dictionary:
	if not active(h):
		return {}
	var ms: MergeSpec = h.merge_st["def"]
	return ms.merged.get("active" if slot == "k1" else "auto", {})

## The merge's riders on every shot, scaled by its strength: {effects, splash, chain, k}.
static func on_shot(h: Hunter) -> Dictionary:
	if not active(h):
		return {}
	var ms: MergeSpec = h.merge_st["def"]
	if ms.on_shot.is_empty():
		return {}
	var out: Dictionary = ms.on_shot.duplicate()
	out["k"] = float(h.merge_st["k"])
	return out
