class_name MergeKit
extends RefCounted
## What a merged hunter plays with (docs/decisions/0003). Created with the merge (KinMerge.cast), live once
## the transformation ends. While live, LMB, RMB and E are the form's (content/merge_forms/<id>.json) and
## C is off; Shift, Q and the bar stay. The slot grammar is the same for every form:
##   LMB  the main attack            (Effects, alternating `seq` lists)
##   RMB  a HOLD mechanic            (MergeHolds: boulder, hover, prism; a rising sound, a fill, a "full" tick)
##   E    movement or utility        (Effects, or MergeHolds.blink)
##   R    the ultimate, which ends the merge: a timeline of `beats` (ops and Effects) after a tell
## A Boki without a form has no slots: only R, a basic burst.
## The hunter calls route() once a step after its inputs are gated; the merge calls tick() and press_ult().

var h: Hunter
var m: Match
var form: Dictionary
var fd: Dictionary                       # the form's data ({} for a Boki without a form)
var live := false
var age := 0.0                           # seconds since the form went live
var cd := {"lmb": 0.0, "rmb": 0.0, "e": 0.0}
var swing := 0                           # LMB casts so far (the seq alternates)
var hold: Dictionary = {}                # the RMB hold running (MergeHolds): {kind, t, fill, full, snd, hit, mirror}
var charges := 0.0                       # E charges (a blink has two)
var recharge := 0.0                      # seconds to the next charge
var ult: Dictionary = {}                 # the ultimate running: {t, done, r}
var rise: Dictionary = {}                # the ultimate's climb into the air: {base, h}
var anim_n := 0                          # counts plays, so the same pose twice in a row is a new play for other games
var anim_id := ""                        # the keyed pose playing on the hunter (MergeMoves)
var anim_at := -9.0
var bot_rmb := 0.0                       # seconds a bot keeps RMB held

func _init(hunter: Hunter, f: Dictionary) -> void:
	h = hunter
	m = hunter.m
	form = f
	fd = f["def"]
	if has_slots():
		charges = float((fd["e"] as Dictionary).get("charges", 0))

func has_slots() -> bool:
	return MergeForm.has_kit(form)

static func of(hunter: Hunter) -> MergeKit:
	return hunter.merge_st.get("kit", null) if not hunter.merge_st.is_empty() else null

## The live kit of a hunter wearing a form with slots (else null).
static func live_of(hunter: Hunter) -> MergeKit:
	var k := of(hunter)
	return k if k != null and k.live and k.has_slots() else null

## Is a merge with a live kit running (a form with slots, or the fallback's burst)?
static func is_live(hunter: Hunter) -> bool:
	var k := of(hunter)
	return k != null and k.live

func start() -> void:
	live = true
	age = 0.0

## The merge ended: let go of anything held.
func stop() -> void:
	live = false
	MergeHolds.end(self, true)
	ult = {}
	rise = {}
	anim_id = ""

func ulting() -> bool:
	return not ult.is_empty()

func busy() -> bool:
	return h.downed or h.out or h.dropping or h.riding or h.stun_t > 0.0 or ulting()

func held_rmb() -> bool:
	return bool(h.inp.get("sec_hold", false)) or bot_rmb > 0.0

func _ctx(slot: String, reach := 0.0) -> Dictionary:
	var c := {"slot": slot, "ability": "%s_%s" % [form["id"], slot], "level": 1}
	if reach > 0.0:
		c["reach"] = reach
	return c

func play(move: String) -> void:
	anim_id = move
	anim_n += 1          # (a repeat of the same pose still replays in other games, KinNet)
	anim_at = m.time

## A cast for the other games to see (Net event "mcast"): slot, where it was aimed, a radius and a time for tells.
func announce(slot: String, at := Vector3.INF, radius := 0.0, secs := 0.0) -> void:
	var t: Vector3 = h.inp.get("aim", h.pos) if at == Vector3.INF else at
	KinNet.event(m, "mcast", h, h.pos, "%s|%.1f|%.1f|%.1f|%.2f" % [slot, t.x, t.z, radius, secs])

# ------------------------------------------------------------------ inputs
## Hunter._tick: this step's presses. LMB, RMB and E go to the form; C is dropped; R stays with KinMerge.press.
## Whatever the class kit or weapon had started before R (a charge, a bow draw, a held RMB) is dropped, and stays dropped
## while merged: the form's own kit owns the buttons (the pattern Hex uses for a hexed hunter).
static func drop_class_holds(hunter: Hunter) -> void:
	hunter.mel_hold = 0.0
	hunter.draw_t = -1.0
	hunter.warm_t = 0.0
	if hunter.ak != null and hunter.ak.rmb_down:
		hunter.ak.rmb_down = false

static func route(hunter: Hunter) -> void:
	if KinMerge.active(hunter):
		drop_class_holds(hunter)
	var k := live_of(hunter)
	if k != null:
		k.inputs()
	elif KinMerge.active(hunter) and String(hunter.merge_st.get("phase", "")) == "xform":
		hunter.inp["fire"] = false          # mid-transformation: untouchable, and nothing fires
		hunter.inp["sig"] = false
		hunter.inp["sec"] = false
		hunter.inp["kin_ab"] = false

func inputs() -> void:
	var fire := bool(h.inp.get("fire", false))
	var e_press := bool(h.inp.get("sig", false))
	var r_press := bool(h.inp.get("sec", false))
	h.inp["fire"] = false
	h.inp["sig"] = false
	h.inp["sec"] = false
	if bool(h.inp.get("kin_ab", false)) and h.is_local():
		KinCommand.say(h, "C is unavailable while merged: your Boki is part of you", Color("a2a8bb"))
	h.inp["kin_ab"] = false
	if e_press:
		press_e()
	if r_press:
		press_rmb()
	if fire and cd["lmb"] <= 0.0 and not busy() and (hold.is_empty() or String(hold["kind"]) != "boulder"):
		fire_lmb()

func fire_lmb() -> void:
	var d: Dictionary = fd["lmb"]
	var seq: Array = d["seq"]
	var poses: Array = d.get("pose", [])
	if not poses.is_empty():
		play(String(poses[swing % poses.size()]))
	var list: Array = seq[swing % seq.size()]
	swing += 1
	cd["lmb"] = float(d["cooldown"])
	h.cast_at = m.time
	h.cast_slot = "lmb"
	h.used["lmb"] = int(h.used.get("lmb", 0)) + 1
	Effects.run(list, h, _ctx("lmb"))
	if float(d.get("shake", 0.0)) > 0.0:
		m.shake(float(d["shake"]), h.pos)
	if not _only_shots(list):
		announce("lmb")           # (shots already cross the net by themselves)
	CombatBus.ability_used.emit(h, "%s_lmb" % form["id"], "lmb")

static func _only_shots(list: Array) -> bool:
	for e in list:
		if String((e as Dictionary).get("type", "")) != "projectile":
			return false
	return true

func press_e() -> void:
	var e: Dictionary = fd["e"]
	if busy():
		h._ab_feedback("k1", "deny")
		return
	if String(e.get("kind", "")) == "blink":
		if MergeHolds.blink(self):
			h._ab_feedback("k1", "cast")
		else:
			h._ab_feedback("k1", "deny")
		return
	if cd["e"] > 0.0:
		h._ab_feedback("k1", "deny")
		return
	cd["e"] = float(e["cooldown"])
	h._ab_feedback("k1", "cast")
	h.cast_at = m.time
	h.cast_slot = "kin"
	play("mf_e")
	Effects.run(e["effects"], h, _ctx("e", float(e.get("range", 0.0))))
	announce("e", Vector3.INF, float(e.get("range", 0.0)), 0.0)
	CombatBus.ability_used.emit(h, "%s_e" % form["id"], "kin")

func press_rmb() -> void:
	if busy() or not hold.is_empty() or cd["rmb"] > 0.0:
		h._ab_feedback("sec", "deny")
		return
	h._ab_feedback("sec", "cast")
	MergeHolds.begin(self)

# ------------------------------------------------------------------ the ultimate
func ult_def() -> Dictionary:
	if has_slots():
		return fd["r"]
	var fb: Dictionary = MergeForm.data()["fallback"]
	var b: Dictionary = fb["burst"]
	var w := float(fb["ult_s"])
	var col: String = (form["glow"] as Color).to_html(false)
	return {"name": "Burst", "icon": "burst", "end": w + 0.25, "range": 0.0, "bot_range": float(b["radius"]), "desc": "The merge bursts outward and ends.",
		"beats": [{"at": 0.0, "effects": [{"type": "telegraph", "at": "self", "radius": float(b["radius"]), "time": w, "color": col}]},
			{"at": w, "effects": [{"type": "area", "at": "self", "radius": float(b["radius"]), "dmg": float(b["dmg"]), "kb": float(b["kb"]), "color": col}]}]}

func lock_left() -> float:
	return maxf(0.0, float(MergeForm.data()["ult_lock_s"]) - age)

func ult_text() -> String:
	if ulting() or not live:
		return ""
	if lock_left() > 0.0:
		return "%s ready in %.1fs" % [String(ult_def()["name"]), lock_left()]
	return ""

## R while merged: the ultimate, once the lock is over. It separates you when it lands.
func press_ult() -> bool:
	if not live or ulting() or lock_left() > 0.0 or h.downed or h.out or h.stun_t > 0.0 or h.dropping:
		return false
	MergeHolds.end(self, true)
	var r := ult_def()
	ult = {"t": 0.0, "done": 0, "r": r}
	h.cast_at = m.time
	h.cast_slot = "ult"
	h.used["r"] = int(h.used.get("r", 0)) + 1
	var col: Color = form["glow"]
	m.fx.word(h.pos + Vector3(0, 3.0, 0), String(r["name"]).to_upper(), col, true)
	m.sfx("charge", h.pos, 0.0, 0.6)
	m.sfx("warn", h.pos, -4.0, 0.7)
	play("mf_ult")
	var tx: Vector3 = _ult_target(r)
	announce("ult", tx, _tell_radius(r), float(r.get("end", 1.0)))
	CombatBus.ability_used.emit(h, "%s_r" % form["id"], "ult")
	_run_beats()
	return true

func _ult_target(r: Dictionary) -> Vector3:
	var a: Vector3 = h.inp.get("aim", h.pos)
	var reach := float(r.get("range", 0.0))
	if reach > 0.0 and (r["beats"][0]["effects"][0] as Dictionary).get("type", "") == "leap":
		var d := Vector2(a.x - h.pos.x, a.z - h.pos.z)
		if d.length() > reach:
			d = d.normalized() * reach
		return Vector3(h.pos.x + d.x, h.pos.y, h.pos.z + d.y)
	return h.pos

func _tell_radius(r: Dictionary) -> float:
	var best := 0.0
	for b in r["beats"]:
		for e in (b as Dictionary).get("effects", []):
			var ed: Dictionary = e
			best = maxf(best, float(ed.get("radius", 0.0)))
			for e2 in ed.get("on_land", []):
				best = maxf(best, float((e2 as Dictionary).get("radius", 0.0)))
	return best

func _tick_ult(dt: float) -> void:
	ult["t"] = float(ult["t"]) + dt
	_run_beats()
	if float(ult["t"]) >= float((ult["r"] as Dictionary).get("end", 1.0)):
		KinMerge.end(h, "ult")

func _run_beats() -> void:
	var r: Dictionary = ult["r"]
	var beats: Array = r["beats"]
	while int(ult["done"]) < beats.size() and float((beats[int(ult["done"])] as Dictionary)["at"]) <= float(ult["t"]):
		var b: Dictionary = beats[int(ult["done"])]
		ult["done"] = int(ult["done"]) + 1
		match String(b.get("op", "")):
			"rise":
				rise = {"base": h.pos.y, "h": float(r.get("rise", 2.5))}
				h.grounded = false
				h.vel.y = 6.0
				h.roll_t = 0.0
			"crack":
				MergeXform.crack(h, form, float(b.get("time", 0.5)))
			"strike_all":
				_strike_all(b)
		if b.has("effects"):
			Effects.run(b["effects"], h, _ctx("ult", float(r.get("range", 0.0))))

## Thunderhead: one bolt from above on every foe in range.
func _strike_all(b: Dictionary) -> void:
	var col := Color(String(b.get("color", "#fff27a")))
	var rad := float(b.get("radius", 10.0))
	for f in m.foes_of(h.team):
		if not f.hittable() or f.flat_dist(h) > rad + f.r:
			continue
		m.fx.bolt(f.pos + Vector3(0, 8.0, 0), f.pos + Vector3(0, 0.8, 0), col)
		m.fx.flash(f.pos + Vector3(0, 0.9, 0), Color.WHITE, 1.3, 0.12)
		m.fx.ring(f.pos, 1.5, col, 0.3)
		f.hurt(float(b.get("dmg", 40.0)) * m.dmg_mult(h), h, {"src": "abil", "ab": "ult", "tags": ["ult", "strike"], "stun": float(b.get("stun", 0.0)), "dr": true})
	m.sfx("boom", h.pos, -1.0, 0.8)
	m.sfx("zap", h.pos, 0.0, 0.7)
	m.shake(0.6, h.pos)
	if h.is_local() and m.cam:
		m.cam.punch(0.1)

# ------------------------------------------------------------------ every step
func tick(dt: float) -> void:
	if not live:
		return
	age += dt
	for k in cd:
		cd[k] = maxf(0.0, float(cd[k]) - dt)
	bot_rmb = maxf(0.0, bot_rmb - dt)
	if has_slots() and String((fd["e"] as Dictionary).get("kind", "")) == "blink":
		var mx := float(fd["e"]["charges"])
		if charges < mx:
			recharge -= dt
			if recharge <= 0.0:
				charges += 1.0
				recharge = float(fd["e"]["recharge"]) if charges < mx else 0.0
	if not hold.is_empty():
		MergeHolds.tick(self, dt)
	if ulting():
		_tick_ult(dt)

# ------------------------------------------------------------------ the hunter's views of it
## The HUD slot rows while merged: "lmb", "sec" (RMB), "k1" (E) for a form with slots, "r" for any live kit. {} otherwise.
static func slot_info(hunter: Hunter, slot: String) -> Dictionary:
	var k := of(hunter)
	if k == null or not k.live:
		return {}
	if slot in ["r", "ult"] or k.has_slots():
		return k.info(slot)
	return {}

func info(slot: String) -> Dictionary:
	var col: Color = form["glow"]
	var base := {"short": "", "col": col, "charges": 0, "max_charges": 0, "verb": "", "level": 1}
	match slot:
		"lmb":
			var d: Dictionary = fd["lmb"]
			base.merge({"name": d["name"], "short": d["name"], "icon": d["icon"], "desc": d["desc"], "cd": cd["lmb"], "cd_max": d["cooldown"], "ready": cd["lmb"] <= 0.0}, true)
		"sec", "utility", "rmb":
			var d: Dictionary = fd["rmb"]
			base.merge({"name": d["name"], "short": d["name"], "icon": d["icon"], "desc": d["desc"], "cd": cd["rmb"], "cd_max": d["cooldown"], "ready": cd["rmb"] <= 0.0 and hold.is_empty(),
				"hold": float(hold.get("fill", 0.0)) if not hold.is_empty() else -1.0, "full": bool(hold.get("full", false))}, true)
		"k1", "e", "kin":
			var d: Dictionary = fd["e"]
			if String(d.get("kind", "")) == "blink":
				base.merge({"name": d["name"], "short": d["name"], "icon": d["icon"], "desc": d["desc"], "cd": recharge if charges < 1.0 else 0.0, "cd_max": d["recharge"],
					"charges": int(floor(charges)), "max_charges": int(d["charges"]), "ready": charges >= 1.0}, true)
			else:
				base.merge({"name": d["name"], "short": d["name"], "icon": d["icon"], "desc": d["desc"], "cd": cd["e"], "cd_max": d["cooldown"], "ready": cd["e"] <= 0.0}, true)
		"r", "ult":
			var r: Dictionary = ult_def()
			base.merge({"name": r["name"], "short": r["name"], "icon": r.get("icon", "burst"), "desc": r.get("desc", ""), "cd": lock_left(), "cd_max": float(MergeForm.data()["ult_lock_s"]),
				"ready": lock_left() <= 0.0 and not ulting(), "form": form, "plan": "ult", "timer": float(h.merge_st.get("t", 0.0)), "timer_max": float(h.merge_st.get("T", 1.0)), "ulting": ulting()}, true)
		_:
			return {}
	return base

## Hunter._anim_state: the keyed pose the form is playing (MergeMoves, through HunterAnim's kit-move channel).
## Other games read the pose id the owner syncs (KinNet) from the hunter's meta.
static func anim_state(hunter: Hunter, s: Dictionary) -> void:
	var id := ""
	var at := 0.0
	var k := of(hunter)
	if k != null:
		id = k.anim_id
		at = k.anim_at
	elif hunter.remote:
		id = String(hunter.get_meta("kpose", ""))
		at = float(hunter.get_meta("kpose_at", -9.0))
	if id.begins_with("mf_"):
		s["kmove"] = id
		s["kmove_t"] = hunter.m.time - at
	elif String(s.get("kmove", "")).begins_with("mf_"):
		s.erase("kmove")
		s.erase("kmove_t")

# ------------------------------------------------------------------ bots
## How a bot plays the form: holds, E and the ultimate at the right moments (LMB is the bot's usual fire).
static func bot_use(hunter: Hunter, tgt: Ent, dist: float, los: bool) -> void:
	var k := of(hunter)
	if k == null or not k.live or tgt == null:
		return
	k.bot_think(tgt, dist, los)

func bot_think(tgt: Ent, dist: float, los: bool) -> void:
	if ulting() or busy():
		return
	var r := ult_def()
	var foes := 0
	var reach := float(r.get("bot_range", 8.0))
	for f in m.foes_of(h.team):
		if f.hittable() and f.flat_dist(h) <= reach:
			foes += 1
	var low_time := float(h.merge_st.get("t", 99.0)) < 2.0
	if lock_left() <= 0.0 and (foes > 0 or low_time):
		press_ult()
		return
	if not has_slots():
		return
	var rm: Dictionary = fd["rmb"]
	if hold.is_empty() and cd["rmb"] <= 0.0 and los:
		var kind := String(rm["kind"])
		var near := dist < 4.5
		if (kind == "boulder" and dist < 9.0 and dist > 2.0) or (kind == "prism" and dist < 12.0 and randf() < 0.5) or (kind == "hover" and near and randf() < 0.3):
			bot_rmb = minf(float(rm.get("max_s", rm.get("drain_s", 2.0))) * 0.6, 1.4)
			press_rmb()
	var e: Dictionary = fd["e"]
	if String(e.get("kind", "")) == "blink":
		if charges >= 1.0 and dist > 5.0 and los:
			h.inp["aim"] = tgt.pos
			press_e()
	elif cd["e"] <= 0.0 and dist <= maxf(4.0, float(e.get("range", 5.0))) and los:
		press_e()
