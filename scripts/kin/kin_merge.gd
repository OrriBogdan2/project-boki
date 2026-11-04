class_name KinMerge
extends RefCounted
## The merge: one key (Merge, T) for every class (docs/decisions/0001, 0003), run from the Boki's MergeSpec (content/merges_v2)
## and the form it gives you (MergeForm). Core rules, not data (docs/KIN_GRAMMAR.md):
##   - R needs the bond meter full (fighting together fills it, Bond) and the ult slot, which opens at
##     run level Hunter.ULT_AT[0] (6); the first unlock fills the meter once, free
##   - Boki on your shoulder: you merge at once. Boki out in the field: it leaps back and merges mid-air
##     (Kin.merge_leap, hitting what is in its way). Boki DOWNED: R does nothing ("Rescue it to merge") and the
##     full meter is kept. No Boki at all (none brought, lost, dead, benched): a weak surge
##     (MergeForm.surge_spec), so a full meter is never wasted
##   - phase "xform": ~0.7s, invulnerable, the Boki leaps into you and the form pops in (MergeXform)
##   - phase "live": for the form's duration you keep your own hero's abilities and the form augments them
##     (MergeAugment), C is off, and R again (after a short lock) fires the form's ultimate, which ends the merge.
##     The shell (MergeShell) takes the damage first; when it breaks the merge ends without the ultimate. A Boki
##     without a form file keeps the stat merge (passives, pulses), the type's LMB rider and dash trail, and a basic burst as its ultimate.
##   - it ends when time runs out, with the ultimate, early if you're knocked or the Boki is lost. Time out or
##     a broken shell: the Boki pops out beside you in Follow (not downed), no burst, no afterglow, a spent window of
##     KinParts.MERGE_SPENT_TIME. The ultimate (a release): the hunter gets the afterglow and the Boki lands beside you
##     pumped and rests release_rest_s (MergeRelease, docs/decisions/0004). Then the spent window, or the rest if longer.
##   - while merged the total damage bonus from stats is at most merge_forms.json damage_cap (cap_damage).
## No tiers: a form is identical for everyone (only its shield and speed baseline follow your weight class).
## State lives on the hunter: Hunter.merge_st {def, t, T, k, giant, pulse, form, surge, phase, xt, kit, contact, from, shell, shell_max} and merge_cd.

static func def_for(k: Ent) -> MergeSpec:
	if k == null or not (k is Kin):
		return null
	return KinLib.merge_of((k as Kin).species)

static func active(h: Hunter) -> bool:
	return h != null and not h.merge_st.is_empty()

## In the 0.7s transformation (untouchable; whatever the hero had started before R is dropped, nothing fires).
static func transforming(h: Hunter) -> bool:
	if active(h):
		return String(h.merge_st.get("phase", "")) == "xform"
	# R pressed with the Boki out: it's leaping back to merge, so the hero's holds are already dropped
	var k = h.kin if h else null
	return k != null and is_instance_valid(k) and (k as Kin).state == "flying_home" and bool((k as Kin).fly.get("merge", false))

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
## "surge" (no Boki at all), "rescue" (your Boki is down: nothing happens, the meter is kept), "far" (Boki out
## of leap range: call it back first), or "" (not ready).
static func plan(h: Hunter) -> String:
	if not ready(h):
		return ""
	var k: Kin = h.kin
	if k != null and not k.dead and k.state in ["downed", "reviving"]:
		return "rescue"
	if not boki_with_you(h):
		return "surge"
	if k.state == "shoulder":
		return "merge"
	return "leap" if k.flat_dist(h) <= float(KinCommand.rules().get("merge_leap_range", 32.0)) else "far"

## R. Returns true if something started (a merge, a leap that merges on landing, a surge, or the ultimate while merged).
static func press(h: Hunter) -> bool:
	if active(h):
		return (h.merge_st["kit"] as MergeKit).press_ult() if h.merge_st["kit"] != null else false
	match plan(h):
		"merge": return cast(h)
		"leap":
			MergeAugment.drop_class_holds(h)
			if h.ak: h.ak.drop_holds()
			return (h.kin as Kin).merge_leap()
		"surge": return surge(h)
	return false

## Why R did nothing, for the HUD toast ("" when there is nothing to say).
static func deny_text(h: Hunter) -> String:
	if active(h):
		return (h.merge_st["kit"] as MergeKit).ult_text() if h.merge_st["kit"] != null else ""
	if h.merge_cd > 0.0 or int(h.slot_lv.get("ult", 0)) <= 0:
		return ""
	if h.ult < 1.0:
		return "Bond %d%%: fight together to fill it" % int(h.ult * 100.0)
	match plan(h):
		"far": return "Your Boki is too far: call it back first"
		"rescue": return rescue_text(h)
	return ""

static func rescue_text(h: Hunter) -> String:
	return "Rescue %s to fuse" % String((h.kin as Kin).rec.get("name", "your Boki"))

## The weak merge with no Boki at all: short, plain, but the full meter is spent on something.
static func surge(h: Hunter) -> bool:
	if plan(h) != "surge":
		return false
	MergeAugment.drop_class_holds(h)
	if h.ak: h.ak.drop_holds()      # whatever the hero had started before R never fires (charges, wind-ups, reels)
	h.ult = 0.0
	var ms := MergeForm.surge_spec()
	var form := MergeForm.surge_form()
	h.merge_st = {"def": ms, "t": ms.duration, "T": ms.duration, "giant": false, "pulse": [], "form": form, "surge": true, "phase": "live", "xt": 0.0, "kit": null, "contact": true}
	h._refresh_kin_stats()
	MergeLook.attach(h, form)
	MergeXform.flash_only(h.m, h.pos, form)
	CombatBus.ability_used.emit(h, ms.id, "ult")
	h.m.on_merge(h, null, ms)
	return true

## Starts the merge: the transformation first (phase "xform"), the form goes live when it ends.
static func cast(h: Hunter) -> bool:
	if not can_cast(h):
		return false
	var k: Kin = h.kin
	var ms := def_for(k)
	if ms == null:
		return false
	k.disengaged = false
	if h.ak: h.ak.drop_holds()      # whatever the hero had started before R never fires (charges, wind-ups, reels)
	h.ult = 0.0
	MergeAugment.drop_class_holds(h)
	for bb in h.m.bubbles.duplicate():
		if bb["ent"] == k:
			h.m.bubbles.erase(bb)          # (a line it said a moment ago does not hang over the merge)
	var form := MergeForm.for_boki(k)
	var giant := k.carry_style() == "mount" and not MergeForm.has_kit(form)
	var timers: Array = []
	for pl in ms.pulses:
		timers.append(float(pl["every"]))
	var xs := float(MergeForm.data()["xform_s"])
	h.merge_st = {"def": ms, "t": ms.duration, "T": ms.duration, "giant": giant, "pulse": timers, "form": form, "surge": false,
		"phase": "xform", "xt": xs, "kit": MergeKit.new(h, form), "contact": false, "from": k.pos}
	k.merge_in(giant)
	h._refresh_kin_stats()
	h.inv_t = maxf(h.inv_t, xs)
	MergeXform.begin(h, form)
	CombatBus.ability_used.emit(h, ms.id, "ult")
	h.m.on_merge(h, k, ms)
	return true

## The transformation is over: the form is live (its shield, riders, the Boki's start stage).
static func _go_live(h: Hunter) -> void:
	var st: Dictionary = h.merge_st
	st["phase"] = "live"
	var k: Kin = h.kin
	var ms: MergeSpec = st["def"]
	MergeShell.start(h)
	if h.owner_stat("dodge_regen") >= 0.99:
		h.dashes = h.max_dashes()
	if k and not k.dead:
		KinExec.run_stages(ms.on_start, _cx(h, k, ms))
	(st["kit"] as MergeKit).start()

static func _cx(h: Hunter, k: Kin, ms: MergeSpec) -> Dictionary:
	var aim: Vector3 = h.inp.get("aim", h.pos)
	return KinExec.make_cx(h.m, h, k, h, aim, k.ability_power(), "ult", ms.id)

## Is the form with a kit worn right now (so LMB, RMB and E are the form's, C is off)?
static func kit_form(h: Hunter) -> bool:
	if h.remote:
		return bool(h.get_meta("mf_kit", false))          # (other games: set from the snapshot, KinNet)
	return active(h) and MergeForm.has_kit(MergeForm.of(h)) and h.merge_st.get("phase", "") == "live"

## Wearing (or turning into) a form with a kit: the transformation counts, so a G or an order mid-leap cannot end the merge.
static func in_form(h: Hunter) -> bool:
	if h.remote:
		return bool(h.get_meta("mf_kit", false))
	return active(h) and MergeForm.has_kit(MergeForm.of(h))

## Is the Boki hidden inside you (a live form with a kit)? The Boki's render asks.
static func inside(k: Kin) -> bool:
	return k.state == "fused" and k.owner_h != null and kit_form(k.owner_h)

## The owner-stat rows the merge gives: its own passives, or a form's weight-class baseline (the only scaling).
static func passives(h: Hunter) -> Array:
	var f := MergeForm.of(h)
	if MergeForm.has_kit(f):
		var out: Array = []
		var b := MergeForm.baseline(f, h.cls)
		for stat in ["move_speed"]:
			if b.has(stat):
				out.append({"stat": stat, "amount": float(b[stat]), "category": String(KinParts.OWNER_STATS[stat][0])})
		var stats: Dictionary = MergeForm.aug_of(f).get("stats", {})
		for stat in stats:
			if stat != "cooldown":          # (the cooldown rate is the form's haste, Hunter._refresh_kin_stats)
				out.append({"stat": stat, "amount": float(stats[stat]), "category": String(KinParts.OWNER_STATS[stat][0])})
		return out
	return (h.merge_st["def"] as MergeSpec).passives

## Every simulation step while merged: time, pulses, senses. Ends it when it's over or broken.
static func tick(h: Hunter, dt: float) -> void:
	if not active(h):
		h.merge_cd = maxf(0.0, h.merge_cd - dt)
		MergeRelease.tick(h, dt)
		return
	var k: Kin = h.kin
	var surge_on: bool = h.merge_st.get("surge", false)
	if h.downed or h.out or h.extracted or h.dropping or (not surge_on and (k == null or k.dead or k.state in ["downed", "bench", "away"])):
		end(h, "knocked" if h.downed else "broken")          # (also: a lost life drops you back in)
		return
	var st: Dictionary = h.merge_st
	if st["phase"] == "xform":
		st["xt"] = float(st["xt"]) - dt
		h.inv_t = maxf(h.inv_t, float(st["xt"]) + 0.02)          # untouchable for the whole transformation
		var rules := MergeForm.data()
		if not st["contact"] and float(rules["xform_s"]) - float(st["xt"]) >= float(rules["xform_contact_s"]):
			st["contact"] = true
			MergeXform.contact(h, st["form"])
		if float(st["xt"]) <= 0.0:
			_go_live(h)
		return
	var kit: MergeKit = st["kit"]
	if kit != null:
		kit.tick(dt)
		if not active(h):
			return              # (the ultimate separated you)
	MergeAugment.tick(h, dt)
	if kit == null or not kit.ulting():
		st["t"] = float(st["t"]) - dt           # (the timer holds while the ultimate plays out)
	var ms: MergeSpec = st["def"]
	var timers: Array = st["pulse"]
	for i in ms.pulses.size():
		timers[i] = float(timers[i]) - dt
		if float(timers[i]) <= 0.0:
			timers[i] = float(ms.pulses[i]["every"])
			KinExec.run_stage(ms.pulses[i]["stage"], _cx(h, k, ms))
	var rr := h.owner_stat("reveal_radius")
	if rr > 0.0:
		for o in h.m.hunters:
			if o.team != h.team and not o.out and o.flat_dist(h) < rr:
				o.reveal_t = maxf(o.reveal_t, 0.3)
	if float(st["t"]) <= 0.0:
		end(h, "time")

## The merge is over (time, the ultimate, a knock-out, the Boki lost): you separate. With the ultimate (a release) you
## get the afterglow and the Boki lands beside you pumped and rests (MergeRelease); otherwise it pops out in Follow.
static func end(h: Hunter, why := "time") -> void:
	if not active(h):
		return
	var st: Dictionary = h.merge_st
	var ms: MergeSpec = st["def"]
	var form: Dictionary = st["form"]
	var k: Kin = h.kin
	var kit: MergeKit = st["kit"]
	MergeAugment.drop(h)
	var released: bool = why == "ult" and not st.get("surge", false)
	var rest := MergeRelease.rest_s()
	h.merge_st = {}
	var timed_out: bool = why == "time" and not st.get("surge", false)
	if timed_out:
		rest = MergeRelease.timeout_rest_s()
	h.merge_cd = maxf(KinParts.MERGE_SPENT_TIME, rest if released or timed_out else 0.0)
	if released:
		h.ult = 0.0          # (the bond restarts from nothing)
	if kit != null:
		kit.stop()
	h._refresh_kin_stats()
	MergeXform.separate(h, form, why)
	if k and is_instance_valid(k) and not k.dead and not st.get("surge", false):
		if not h.downed and not h.out:
			KinExec.run_stages(ms.on_end, _cx(h, k, ms))
		if released and not h.out and not h.extracted and not h.downed:
			k.land_pumped(rest)
			MergeRelease.afterglow(h)
		elif k.state == "fused" and MergeForm.has_kit(form) and not h.out and not h.extracted:
			k.merge_pop()
		else:
			k.merge_out()
		if timed_out:
			k.rest_t = rest       # (ran out of time: it rests longer than after a release)
	h.m.on_merge_end(h, why)

## The merged patch for one of the kin's slots ({} when not merged or no patch).
static func patch(h: Hunter, slot: String) -> Dictionary:
	if not active(h):
		return {}
	var ms: MergeSpec = h.merge_st["def"]
	return ms.merged.get("active" if slot == "k1" else "auto", {})

## The merge's riders on every shot, {effects, splash, chain} (the same for everyone: no tiers).
static func on_shot(h: Hunter) -> Dictionary:
	if not active(h):
		return {}
	var ms: MergeSpec = h.merge_st["def"]
	if ms.on_shot.is_empty() or not (MergeForm.aug_of(MergeForm.of(h)).get("lmb", {}) as Dictionary).is_empty():
		return {}          # (a form's LMB rider, fallback forms included, is its augment, MergeAugment.lmb: never both)
	return ms.on_shot.duplicate()

## The hunter's damage bonus from stats: `base` (gear and perks) plus `extra` (the Boki's passives and buffs).
## While merged the total is at most damage_cap, so an ultimate into a merge cannot one-shot; the cap never
## takes away what gear and perks gave you on their own.
static func cap_damage(h: Hunter, base: float, extra: float) -> float:
	if not active(h):
		return base + extra
	return minf(base + extra, maxf(float(MergeForm.data().get("damage_cap", 0.2)), base))
