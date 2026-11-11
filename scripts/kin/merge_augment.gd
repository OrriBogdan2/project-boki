class_name MergeAugment
extends RefCounted
## What a merge adds to YOUR hero's own abilities (docs/decisions/0004). You keep LMB, RMB, E, Shift and Q; the form
## (content/merge_forms/<id>.json `aug`, or the Boki type's fallback, MergeForm.aug_of) makes each stronger, the same
## for every hero:
##   LMB    a rider on every attack: chain, pierce, slow, burn, leech, an effect list on every Nth attack (lmb)
##   RMB, E an effect list the form adds when the hero casts one, and a faster recharge of that slot (on_used)
##   Shift  a form dash on top of the hero's own: sweep (damage along the path), charge (armoured shove),
##          reflect (a short mirror window), trail (the fallback: the type's rider on what you pass, then haste)
##          (on_used "dodge", tick)
##   stats  a modest passive (KinMerge.passives)
## It also owns the end of the window: the warning in the last warn_s seconds (tick) and the input gate of the
## transformation (route). State is in Hunter.merge_st["aug"].

const CHAIN_RANGE := 5.0       # m: how far an arc jumps from the foe it starts on
const HOLD_REFRESH := 0.1      # s: what a dash's armour is refreshed with every step

static func aug(h: Hunter) -> Dictionary:
	return MergeForm.aug_of(MergeForm.of(h)) if live(h) else {}

## Is a merge past its transformation (the form's augments are on)?
static func live(h: Hunter) -> bool:
	return h != null and not h.remote and not h.merge_st.is_empty() and String(h.merge_st.get("phase", "")) == "live"

static func _state(h: Hunter) -> Dictionary:
	if not h.merge_st.has("aug"):
		h.merge_st["aug"] = {"n": 0, "dash": {}, "warn": -1}
	return h.merge_st["aug"]

# ------------------------------------------------------------------ inputs
## Whatever the class kit or weapon had started before R (a charge, a bow draw, a held RMB) is dropped.
static func drop_class_holds(hunter: Hunter) -> void:
	hunter.mel_hold = 0.0
	hunter.draw_t = -1.0
	hunter.warm_t = 0.0
	if hunter.ak != null and hunter.ak.rmb_down:
		hunter.ak.rmb_down = false

## Hunter._tick, once a step after the inputs are gated. Mid-transformation: untouchable, and nothing fires.
## Live: your abilities work as the hero's own; only the Boki's own ability stays off while the Boki is inside you.
static func route(h: Hunter) -> void:
	if not KinMerge.active(h):
		return
	if KinMerge.transforming(h):
		drop_class_holds(h)
		h.inp["fire"] = false
		h.inp["sig"] = false
		h.inp["sec"] = false
		h.inp["kin_ab"] = false
	elif KinMerge.in_form(h):
		h.inp["kin_ab"] = false

# ------------------------------------------------------------------ LMB
## Hunter._kin_riders: the form's rider on this attack, written into the shot's extras.
static func lmb(h: Hunter, extra: Dictionary) -> void:
	var a: Dictionary = (aug(h).get("lmb", {}) as Dictionary)
	if a.is_empty():
		return
	var col := String(a.get("color", (MergeForm.of(h)["glow"] as Color).to_html(false)))
	if a.has("burn"):
		extra["burn"] = maxf(float(extra.get("burn", 0.0)), float(a["burn"]))
		extra["burn_for"] = float(a.get("burn_for", 3.0))
	if a.has("slow_k"):
		extra["slow"] = maxf(float(extra.get("slow", 0.0)), float(a.get("slow_s", 1.5)))
		extra["slow_k"] = maxf(float(extra.get("slow_k", 0.0)), float(a["slow_k"]))
		extra["dr"] = true
	if a.has("leech"):
		extra["leech"] = maxf(float(extra.get("leech", 0.0)), float(a["leech"]))
	if bool(a.get("pierce", false)):
		extra["pierce"] = true
		extra["hitset"] = {}
	var fx: Array = (extra.get("fx_hit", []) as Array).duplicate()
	if a.has("chain"):
		fx.append({"type": "chain", "count": int(a["chain"]), "first": float(a.get("chain_reach", CHAIN_RANGE)), "dmg": float(h.wpn["dmg"]) * float(a.get("chain_dmg", 0.5)), "color": col, "skip_here": true})
	if a.has("every") and a.has("slam"):
		var st := _state(h)
		st["n"] = int(st["n"]) + 1
		if int(st["n"]) % int(a["every"]) == 0:
			fx.append(a["slam"])
	if not fx.is_empty():
		extra["fx_hit"] = fx
		if not extra.has("fx_ctx"):
			extra["fx_ctx"] = {"slot": "lmb", "ability": "merge_aug"}

# ------------------------------------------------------------------ RMB, E, Shift
## CombatBus.ability_used for this hunter (Hunter._on_ability_used): "secondary" / "utility" = RMB, "kin" = E, "dodge" = Shift.
static func on_used(h: Hunter, slot: String) -> void:
	if not live(h):
		return
	match slot:
		"secondary", "utility":
			_addon(h, "rmb")
		"kin":
			_addon(h, "e")
		"dodge":
			_dash(h)

## The form's effect list at the same spot as the hero's cast, and that slot recharging faster. E exists only on
## ArchKit heroes (the runner has no E slot), so a hero without `ak` has nothing to speed up there.
static func _addon(h: Hunter, key: String) -> void:
	var a: Dictionary = (aug(h).get(key, {}) as Dictionary)
	if a.is_empty():
		return
	var form := MergeForm.of(h)
	Effects.run(a.get("effects", []), h, {"slot": key, "ability": "%s_%s_aug" % [form["id"], key], "level": 1})
	var k := float(a.get("cd_k", 1.0))
	if k < 1.0:
		if h.ak != null:
			var ck := "rmb" if key == "rmb" else "e"
			if h.ak.cd.has(ck):
				h.ak.cd[ck] = float(h.ak.cd[ck]) * k
		elif h.runner != null and h.runner.slots.has("utility") and key == "rmb":
			h.runner.slots["utility"]["cd"] = float(h.runner.slots["utility"]["cd"]) * k
	var col: Color = form["glow"]
	h.m.fx.word(h.pos + Vector3(0, 2.6, 0), String(a.get("name", "")).to_upper(), col)
	h.m.fx.ring(h.pos, 1.4, Color(col, 0.8), 0.3)
	_announce(h, key, 1.4)

static func _announce(h: Hunter, slot: String, radius: float) -> void:
	var t: Vector3 = h.inp.get("aim", h.pos)
	KinNet.event(h.m, "mcast", h, h.pos, "%s|%.1f|%.1f|%.1f|%.2f" % [slot, t.x, t.z, radius, 0.0])

static func _dash(h: Hunter) -> void:
	var d: Dictionary = (aug(h).get("dash", {}) as Dictionary)
	if d.is_empty():
		return
	var form := MergeForm.of(h)
	var col: Color = form["glow"]
	var st := _state(h)
	var kind := String(d["kind"])
	st["dash"] = {"kind": kind, "t": float(d["window"]), "last": h.pos, "hit": {}, "mirror": {}}
	if kind == "trail":
		h.haste_t = maxf(h.haste_t, float(d["haste_s"]))
		h.m.sfx("whoosh", h.pos, -4.0, 1.3)
		return
	h.m.fx.word(h.pos + Vector3(0, 2.6, 0), String(d.get("name", "")).to_upper(), col)
	match kind:
		"sweep":
			h.m.sfx("zap", h.pos, -3.0, 1.5)
			h.m.fx.bolt(h.pos + Vector3(0, 1.0, 0), h.pos + Vector3(h.roll_dir.x, 0.0, h.roll_dir.y) * 4.0 + Vector3(0, 1.0, 0), col)
		"charge":
			h.m.sfx("ab_slam", h.pos, -4.0, 0.8)
			h.m.fx.dust(h.pos, 8)
		"reflect":
			st["dash"]["mirror"] = h.m.verbs.add_mirror(h, {"arc": float(d["arc"]), "radius": float(d["radius"]), "time": float(d["window"]), "dmg_k": float(d["dmg_k"]), "color": col.to_html(false)})

static func _apply(h: Hunter, t: Ent, dmg: float, r: Dictionary) -> void:
	if r.has("burn"):
		t.burn_t = maxf(t.burn_t, float(r.get("burn_for", 3.0))); t.burn_dps = maxf(t.burn_dps, float(r["burn"])); t.burn_by = h
	if r.has("slow_k"):
		t.slow_k = maxf(t.slow_k, float(r["slow_k"])) if t.slow_t > 0.0 else float(r["slow_k"])
		t.slow_t = maxf(t.slow_t, float(r.get("slow_s", 1.5)))
	if r.has("kb"):
		t.impulse(h.dir_to(t) * float(r["kb"]))      # a negative shove pulls it toward you
	if r.has("leech") and not h.downed:
		h.heal(dmg * float(r["leech"]))
	if r.has("chain"):
		var best: Ent = null
		var bd := CHAIN_RANGE
		for o in h.m.foes_of(h.team):
			if o == t or o.dead or not o.hittable():
				continue
			var dd: float = o.flat_dist(t)
			if dd < bd: bd = dd; best = o
		if best:
			h.m.fx.bolt(t.pos + Vector3(0, 1.0, 0), best.pos + Vector3(0, 1.0, 0), Color(1, 1, 1, 0.9))
			best.hurt(maxf(1.0, dmg * float(r["chain"])), h, {"src": "abil", "ab": "form", "tags": ["form"], "form": true})

## KinMerge.end: whatever a form dash left on the hero (the charge's armour) goes with the merge.
static func drop(h: Hunter) -> void:
	var dsh: Dictionary = (h.merge_st.get("aug", {}) as Dictionary).get("dash", {})
	if not dsh.is_empty() and String(dsh.get("kind", "")) == "charge":
		h.fortify_t = 0.0
		h.guard_t = 0.0
		h.guard_k = 0.0

# ------------------------------------------------------------------ every step
## KinMerge.tick, live: the dash window and the end-of-window warning.
static func tick(h: Hunter, dt: float) -> void:
	var st := _state(h)
	var dsh: Dictionary = st["dash"]
	if not dsh.is_empty():
		_tick_dash(h, dsh, dt)
		if float(dsh["t"]) <= 0.0:
			st["dash"] = {}
	var left := warn_left(h)
	var kit: MergeKit = h.merge_st.get("kit", null)
	if left > 0.0 and (kit == null or not kit.ulting()):
		var sec := int(ceil(left))
		if sec != int(st["warn"]):
			st["warn"] = sec
			_warn_tick(h, sec)

## The seconds left in the window while the warning is on (the last warn_s seconds), else -1. Works for other games too.
static func warn_left(h: Hunter) -> float:
	var left := -1.0
	if not h.merge_st.is_empty():
		if String(h.merge_st.get("phase", "")) != "live":
			return -1.0
		left = float(h.merge_st["t"])
	elif h.has_meta("mf_left"):
		left = float(h.get_meta("mf_left"))
	return left if left > 0.0 and left <= float(MergeForm.data()["warn_s"]) else -1.0

## A rising tick each second, a ring in the form's colour. The local hunter hears it loudest; rivals hear it too.
static func _warn_tick(h: Hunter, sec: int) -> void:
	var m := h.m
	var warn_s := float(MergeForm.data()["warn_s"])
	var col: Color = MergeForm.of(h)["glow"]
	var rise := 1.0 + (warn_s - float(sec)) * 0.3
	m.sfx("click", h.pos, -2.0 if h.is_local() else -12.0, rise)
	m.sfx("warn", h.pos, -6.0 if h.is_local() else -16.0, rise * 0.9)
	m.fx.ring(h.pos, 1.8 + (warn_s - float(sec)) * 0.4, Color(col, 0.9), 0.35)
	if h.is_local() and m.hud:
		m.hud.flash(col, 0.12)

static func _tick_dash(h: Hunter, dsh: Dictionary, dt: float) -> void:
	dsh["t"] = float(dsh["t"]) - dt
	var d: Dictionary = (aug(h).get("dash", {}) as Dictionary)
	var kind := String(dsh["kind"])
	var from: Vector3 = dsh["last"]
	dsh["last"] = h.pos
	if kind == "reflect" or d.is_empty():
		return
	if kind == "charge":
		h.fortify_t = maxf(h.fortify_t, HOLD_REFRESH)
		h.guard_t = maxf(h.guard_t, HOLD_REFRESH)
		h.guard_k = maxf(h.guard_k, float(d["guard"]))
	var seg := Vector2(h.pos.x - from.x, h.pos.z - from.z)
	var a2 := Vector2(from.x, from.z)
	var b2 := Vector2(h.pos.x, h.pos.z)
	var hit: Dictionary = dsh["hit"]
	var col: Color = MergeForm.of(h)["glow"]
	if kind == "trail" and seg.length() > 0.01:
		h.m.fx.spark(h.pos + Vector3(0, 0.4, 0), Vector3(-seg.x, 0.0, -seg.y).normalized(), col, 2, 3.0)
	for f in h.m.foes_of(h.team):
		if hit.has(f) or f.dead or not f.hittable():
			continue
		var fp := Vector2(f.pos.x, f.pos.z)
		if fp.distance_to(Geometry2D.get_closest_point_to_segment(fp, a2, b2)) > float(d["width"]) + f.r or not AimMode.in_reach(h.pos.y, f.pos.y):
			continue
		hit[f] = true
		var o := {"src": "abil", "ab": "form_dash", "tags": ["form", "dash"], "dr": true}
		var dmg: float = float(d["dmg"]) * h.m.dmg_mult(h)
		if kind == "trail":
			f.hurt(dmg, h, o)
			_apply(h, f, dmg, d)
			continue
		if kind == "sweep":
			o["stun"] = float(d["stun"])
			h.m.fx.bolt(f.pos + Vector3(0, 2.5, 0), f.pos + Vector3(0, 0.8, 0), col)
		else:
			var dir := seg.normalized() if seg.length() > 0.01 else h.aim_dir()
			f.impulse(dir * float(d["shove"]) * f.mass())
			h.m.fx.dust(f.pos, 3)
		f.hurt(dmg, h, o)

# ------------------------------------------------------------------ the HUD's views
## What a slot of the hero shows while merged: {} or {name, desc, col, badge} ("lmb" | "rmb" | "e" | "dash").
static func mark(h: Hunter, slot: String) -> Dictionary:
	if h == null or h.merge_st.is_empty() or String(h.merge_st.get("phase", "")) != "live":
		return {}
	var f := MergeForm.of(h)
	var a: Dictionary = (MergeForm.aug_of(f).get(slot, {}) as Dictionary)
	if a.is_empty():
		return {}
	return {"name": String(a.get("name", "")), "desc": String(a.get("desc", "")), "col": f["glow"], "badge": String(f["word"]).substr(0, 1)}
