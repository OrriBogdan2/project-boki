class_name ThiefKit
extends ArchKit
## Thief (light): Flicker, Marks, Knife (Shadow Step, Fan, Drop Knife, silent in smoke, Cash In),
## Smoke Veil, Heist. docs/ARCHETYPES.md §6.1.

var ambush_t := 0.0            # the next hit counts as from behind
var step2 := {}                # Flicker's second step window: {t, refund_at}
var recast := {}               # Shadow Step: {target, t}
var mark_gap := {}             # target id -> time of its last Mark from us (one per 0.3s)
var heist := {}                # the running Heist: {targets, i, t}
var smoke: Dictionary = {}     # our live smoke cloud (in m.smokes)

func _setup() -> void:
	res = 0.0

# ---- Marks live on the targets: meta "marks" {thief nid: [count, time left]} ----
func marks_on(t: Ent) -> int:
	if t == null or not is_instance_valid(t):
		return 0
	var mk: Dictionary = t.get_meta("marks", {})
	var e: Array = mk.get(h.nid, [0, 0.0])
	return int(e[0]) if float(e[1]) > 0.0 else 0

func add_mark(t: Ent, n := 1, force := false) -> void:
	if t == null or not is_instance_valid(t) or t.dead or t.team == h.team:
		return
	var now: float = m.time
	if not force and now - float(mark_gap.get(t.get_instance_id(), -9.0)) < 0.3:
		return
	mark_gap[t.get_instance_id()] = now
	var mk: Dictionary = t.get_meta("marks", {})
	var e: Array = mk.get(h.nid, [0, 0.0])
	var c := mini(int(res_def().get("max", 3)), (int(e[0]) if float(e[1]) > 0.0 else 0) + n)
	mk[h.nid] = [c, float(res_def().get("dur", 6.0))]
	t.set_meta("marks", mk)
	t.set_meta("marks_t", now)
	if c >= 3:
		m.sfx("pickup", t.pos, -4.0, 1.9)       # the victim hears a coin jingle
		m.fx.word(t.pos + Vector3(0, 2.3, 0), "MARKED", res_col(), false)

func clear_marks(t: Ent) -> void:
	var mk: Dictionary = t.get_meta("marks", {})
	mk.erase(h.nid)
	t.set_meta("marks", mk)

## Highest mark count on any foe (the RMB slot's gold dot, the resource readout).
func best_marks() -> int:
	var b := 0
	for f in m.foes_of(h.team):
		b = maxi(b, marks_on(f))
	return b

func res_frac() -> float:
	return float(best_marks()) / 3.0

func res_text() -> String:
	return "%d/3" % best_marks()

func full_ready() -> bool:
	return best_marks() >= 3

func _tick(dt: float) -> void:
	ambush_t = maxf(0.0, ambush_t - dt)
	# marks fade on every target we've touched
	for f in m.foes_of(h.team):
		var mk: Dictionary = f.get_meta("marks", {}) if f.has_meta("marks") else {}
		if mk.has(h.nid):
			var e: Array = mk[h.nid]
			e[1] = float(e[1]) - dt
			if float(e[1]) <= 0.0: mk.erase(h.nid)
	if not step2.is_empty():
		step2["t"] = float(step2["t"]) + dt
		var win := float(dash_def().get("win_max", 0.7)) + (0.2 if rank("dash") >= 3 else 0.0)
		if float(step2["t"]) > win:
			# skipped the second step: a quarter of the cooldown back, and the Ambush opens now
			h.dashes = minf(h.max_dashes(), h.dashes + float(dash_def().get("skip_refund", 0.25)))
			ambush_t = maxf(ambush_t, float(dash_def().get("ambush", 1.0)))
			step2 = {}
	if not recast.is_empty():
		recast["t"] = float(recast["t"]) - dt
		if float(recast["t"]) <= 0.0 or not is_instance_valid(recast["target"]) or (recast["target"] as Ent).dead:
			recast = {}
	if not heist.is_empty():
		_tick_heist(dt)
	if not smoke.is_empty() and not m.smokes.has(smoke):
		smoke = {}

# ------------------------------------------------------------------ dash: Flicker
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	var step := float(dd.get("step", 2.3)); var tt := float(dd.get("step_t", 0.085))
	if not step2.is_empty() and float(step2["t"]) >= float(dd.get("win_min", 0.08)) and h.roll_t <= 0.0:
		# step 2: free, any direction (movement keys, else the cursor)
		step2 = {}
		travel(step, tt, {"invuln": float(dd.get("phase", 0.1)), "phase": 0.3, "trail": "ghost"})
		_afterimage()
		m.later(tt, func(): ambush_t = maxf(ambush_t, float(dd.get("ambush", 1.0))))
		m.sfx("swipe", h.pos, -6.0, 2.0)
		return true
	if not step2.is_empty():
		return true          # too soon after step 1: swallowed
	if use_ex:
		if not spend_dash(true): return true
		travel(float(h.cdat.get("ex_dist", 5.0)), float(h.cdat.get("ex_time", 0.2)), {"invuln": 0.1, "trail": "ghost"}, true)
		return true
	if not spend_dash(false): return true
	travel(step, tt, {"invuln": float(dd.get("phase", 0.1)), "phase": 0.3, "trail": "ghost"})
	_afterimage()
	step2 = {"t": 0.0}
	return true

## Enemy cue: a smoke afterimage of the Thief at each start point.
func _afterimage() -> void:
	m.fx.ghost(h.position, h.face, Color("6a6480"), float(h.cdat["scale"]))
	m.fx.burst(h.pos + Vector3(0, 0.8, 0), Color("8a84a0"), 8, 1.5, 0.3, -1.0)

# ------------------------------------------------------------------ passive hooks
func outgoing(t: Ent, dmg: float, _o: Dictionary) -> float:
	return dmg * (1.0 + float(res_def().get("per_mark", 0.05)) * float(marks_on(t)))

func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team or String(o.get("src", "")) == "burn":
		return
	if ambush_t > 0.0 or ArchKit.behind(t, h, float(res_def().get("rear_deg", 120.0))):
		if ambush_t > 0.0:
			ambush_t = 0.0
			m.fx.word(t.pos + Vector3(0, 2.0, 0), "AMBUSH", res_col(), false)
		add_mark(t, 1)

# ------------------------------------------------------------------ RMB: Knife
func rmb_press_extra() -> bool:
	if recast.is_empty():
		return false
	var tgt: Ent = recast["target"]
	recast = {}
	if not is_instance_valid(tgt) or tgt.dead or h.flat_dist(tgt) > float(rmb_def()["knife"]["range"]) + 1.5:
		h._ab_feedback("sec", "deny")
		return true
	_shadow_step(tgt, not h.grounded or h.gliding)
	return true

func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if c.get("hold", false):
		if not spend_rmb(): return
		_fan(c)
		return
	if not spend_rmb(): return
	_knife(c)

func _knife(c: Dictionary) -> void:
	var kd: Dictionary = rmb_def()["knife"]
	var silent: bool = c.get("e", false) and _in_my_smoke(h.pos)
	var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": float(kd["speed"]), "range": float(kd["range"]), "size": 0.14}, "effects": [{"type": "damage", "amount": float(kd["dmg"])}]})
	var cc := cx("rmb", "knife", aim(), {"on_foe": func(f: Ent, _c: Dictionary):
		if f is Hunter or f is Mob or f is Kin:
			var cash := marks_on(f) >= 3
			if cash:
				# Cash In: the Marks pay out for +50% and your dash comes back
				var bonus := float(kd["dmg"]) * float(res_def().get("cash_bonus", 0.5)) * power("sec")
				f.hurt(bonus, h, {"src": "abil", "ab": "utility", "tags": ["utility", "cash_in"], "payoff": true, "crit": true})
				clear_marks(f)
				h.dashes = minf(h.max_dashes(), h.dashes + 1.0)
				m.fx.word(f.pos + Vector3(0, 2.4, 0), "CASH IN", res_col(), true)
				m.sfx("pickup", f.pos, -1.0, 1.5)
			else:
				add_mark(f, 1, true)
			recast = {"target": f, "t": float(rmb_def().get("recast", 1.5)) + (0.5 if rank("sec") >= 3 else 0.0)}})
	if silent:
		cc["silent"] = true
	run(stg, cc)
	if not silent:
		Feel.cast_sound(m, "projectile", "damage", h.pos, h, "")

func _fan(c: Dictionary) -> void:
	var fd: Dictionary = rmb_def()["fan"]
	var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": 34.0, "range": float(fd["range"]), "size": 0.12},
		"effects": [{"type": "damage", "amount": float(fd["dmg"])}, {"type": "slow", "duration": float(fd["slow_t"]), "strength": float(fd["slow"])}],
		"modifiers": [{"type": "split", "count": int(fd["count"]), "angle": float(fd["angle"])}]})
	run(stg, cx("rmb", "fan", aim(), {"on_foe": func(f: Ent, _c: Dictionary): add_mark(f, 1, true)}))
	Feel.cast_sound(m, "projectile", "control", h.pos, h)

## Shadow Step: appear behind the foe (Ambush). From the air it's a Drop Knife: a dive that lands
## behind them with a small burst, out of the glide.
func _shadow_step(tgt: Ent, dive: bool) -> void:
	var back := Vector2(sin(tgt.face), cos(tgt.face))      # behind = opposite their facing
	var at := tgt.pos + Vector3(back.x, 0, back.y) * (tgt.r + h.r + 0.35)
	if m.world.is_void(at.x, at.z) or m.world.is_block(at.x, at.z):
		var away := Vector2(tgt.pos.x - h.pos.x, tgt.pos.z - h.pos.z).normalized()
		at = tgt.pos + Vector3(away.x, 0, away.y) * (tgt.r + h.r + 0.35)
	at = ground(at)
	var from := h.pos
	m.fx.ghost(h.position, h.face, Color("6a6480"), float(h.cdat["scale"]))
	h.teleport(at)
	h.vel = Vector3.ZERO
	h.gliding = false
	var dv := Vector2(tgt.pos.x - at.x, tgt.pos.z - at.z)
	if dv.length() > 0.05: h.face = atan2(-dv.x, -dv.y)
	h.crit_t = maxf(h.crit_t, 1.5 if h.wid == "twin_blades" else 0.0)
	if h.wid == "smg": h.wbloom = 0.0; h.set_meta("zero_spread_t", m.time + 1.5)
	ambush_t = maxf(ambush_t, float(dash_def().get("ambush", 1.0)))
	m.fx.burst(at + Vector3(0, 0.9, 0), Color("c8f0ff"), 14, 3.0, 0.3)
	m.fx.bolt(from + Vector3(0, 0.9, 0), at + Vector3(0, 0.9, 0), Color(0.8, 0.95, 1.0, 0.6))
	m.sfx("cloak", at, -3.0, 1.6)
	if dive:
		var dd: Dictionary = rmb_def()["drop"]
		var stg := stage("rmb", {"delivery": {"type": "burst", "origin": "caster", "radius": float(dd["radius"])}, "effects": [{"type": "damage", "amount": float(dd["dmg"])}]}, {"hit": "add"})
		run(stg, cx("rmb", "drop_knife", at))
		last_variant = "air"
		Feel.shake(m, "leap", h, at)

func _in_my_smoke(p: Vector3) -> bool:
	return not smoke.is_empty() and Vector2(p.x - smoke["pos"].x, p.z - smoke["pos"].z).length() < float(smoke["r"])

## Inside our own smoke counts as "during E".
func in_e() -> bool:
	return _in_my_smoke(h.pos)

# ------------------------------------------------------------------ E: Smoke Veil
func cast_e() -> bool:
	var ed := e_def()
	var r := float(ed["radius"]) + (0.5 if rank("kin") >= 3 else 0.0)
	var at := aim_at(float(ed["reach"]))
	var n := Node3D.new()
	m.add_child(n)
	n.position = at
	var mi := MeshInstance3D.new(); mi.mesh = Models.sphere(r, 18)
	mi.material_override = Models.glow_mat(Color(0.42, 0.42, 0.55, 0.55))
	mi.scale = Vector3(1, 0.55, 1)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	if not smoke.is_empty() and m.smokes.has(smoke):
		(smoke["node"] as Node3D).queue_free(); m.smokes.erase(smoke)
	smoke = {"pos": at, "r": r, "t": float(ed["time"]), "node": n, "by": h}
	m.smokes.append(smoke)
	m.fx.burst(at + Vector3(0, 0.6, 0), Color("8a84a0"), 30, 4.0, 0.6, 0.0, 1.6)
	Feel.cast_sound(m, "zone", "control", at, h)
	e_t = float(ed["time"])
	# foes inside are slowed (the kin's typing rides the zone: poison, pull, reveal...)
	var stg := stage("e", {"delivery": {"type": "zone", "origin": "aim", "radius": r, "duration": float(ed["time"]), "every": 0.5},
		"effects": [{"type": "slow", "duration": 0.6, "strength": float(ed["slow"])}]})
	run(stg, cx("e", "smoke_veil", at))
	return true

# ------------------------------------------------------------------ R: Heist
func cast_r() -> bool:
	var rd := r_def()
	var reach := float(rd["reach"])
	var n := int(rd["targets"]) + (1 if rank("ult") >= 2 else 0)
	var tg: Array = rival_hunters_in(reach)
	if tg.is_empty():
		# nobody to rob: the nearest monsters stand in (so the ult still works in the wilds)
		for f in foes_in(h.pos, reach):
			if f is Mob and sees(f): tg.append(f)
	if tg.is_empty():
		return false
	tg.sort_custom(func(a, b): return h.flat_dist(a) < h.flat_dist(b))
	tg = tg.slice(0, n)
	var tell := float(rd["tell"])
	heist = {"targets": tg, "i": -1, "t": tell, "lines": []}
	for t in tg:
		m.fx.bolt(h.pos + Vector3(0, 1.0, 0), t.pos + Vector3(0, 1.0, 0), res_col())
		m.fx.word(t.pos + Vector3(0, 2.4, 0), "TARGETED", res_col(), true)
		if t == m.player and m.hud: m.hud.toast_small("TARGETED  ·  break line of sight", res_col())
	r_t = tell + float(rd["gap"]) * float(tg.size()) + 0.3
	m.sfx("cloak", h.pos, -1.0, 0.8)
	return true

func _tick_heist(dt: float) -> void:
	heist["t"] = float(heist["t"]) - dt
	var rd := r_def()
	if int(heist["i"]) < 0:
		# the mark-out: anyone who dashes out of reach or breaks sight drops out
		if float(heist["t"]) > 0.0:
			return
		heist["targets"] = (heist["targets"] as Array).filter(func(t): return is_instance_valid(t) and not t.dead and h.flat_dist(t) <= float(rd["reach"]) + 0.5 and sees(t))
		heist["i"] = 0
		heist["t"] = 0.0
	if float(heist["t"]) > 0.0:
		return
	var tg: Array = heist["targets"]
	var i := int(heist["i"])
	if i >= tg.size():
		heist = {}
		ambush_t = maxf(ambush_t, 1.0)
		return
	var t: Ent = tg[i]
	heist["i"] = i + 1
	heist["t"] = float(rd["gap"])
	if not is_instance_valid(t) or t.dead:
		return
	h.cloak_t = maxf(h.cloak_t, float(rd["gap"]))      # untargetable for each hop
	h.inv_t = maxf(h.inv_t, float(rd["gap"]))
	_shadow_step(t, false)
	var stg := stage("r", {"delivery": {"type": "burst", "origin": "here", "radius": 0.0}, "effects": [{"type": "damage", "amount": float(rd["dmg"]) * r_k()}]})
	# the strike: a single-target hit on this foe, then 3 Marks
	var c := cx("r", "heist", t.pos, {"at": t.pos})
	KinExec.apply_foe(stg.effects, t, c, t.pos, stg)
	KinExec.apply_friends(stg.effects, c, h.pos, 1.0)
	add_mark(t, int(rd["marks"]), true)
	Feel.hitstop(m, h, t, 14.0, {"melee": true, "payoff": i == tg.size() - 1})
	m.sfx("swipe", t.pos, -2.0, 1.4)
	h.cloak_t = 0.0

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if not recast.is_empty() and randf() < 0.7:
		h.inp["sec"] = true
		return
	if int(h.slot_lv["ult"]) > 0 and float(cd["r"]) <= 0.0 and rival_hunters_in(float(r_def()["reach"])).size() >= 1 and randf() < 0.5:
		h.inp["ult"] = true
		return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist < 7.0 and (h.hp < h.max_hp * 0.6 or randf() < 0.25):
		h.inp["aim"] = h.pos
		h.inp["sig"] = true
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < float(rmb_def()["knife"]["range"]):
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
		if dist < 5.0 and randf() < 0.3: bot_hold["rmb"] = float(rmb_def()["hold"]) + 0.1
	# Flicker behind them once the knife has landed
	if not step2.is_empty() and float(step2["t"]) > 0.15 and randf() < 0.5:
		var side := h.dir_to(tgt).rotated(PI * 0.5 * (1.0 if randf() < 0.5 else -1.0))
		h.ai["dash_dir"] = side
		h.inp["move"] = side
		h.inp["dash"] = true
