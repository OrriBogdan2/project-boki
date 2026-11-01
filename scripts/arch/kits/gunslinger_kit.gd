class_name GunslingerKit
extends ArchKit
## Gunslinger (medium): Slide Reload, Six Chambers, Trick Shot (Rail Charge, Recoil Shot, doubled in
## Quickdraw, Called Shot at 6), Quickdraw, Last Round. docs/ARCHETYPES.md §6.4.

var load_at := -9.0            # last chamber loaded (one per 0.25s)
var slide := {}                # {t, held, refund} while a Slide Reload runs
var pd_t := 0.0                # Quickdraw: the next slide's perfect-dodge window is doubled
var rail_tele: Node3D = null
var lock := {}                 # Last Round: {t, locks: {id: [ent, time]}}

func full_ready() -> bool:
	return res >= res_max() - 0.01

func res_text() -> String:
	return "%d/6" % int(res)

func load_chambers(n: int, force := false) -> void:
	if not force and m.time - load_at < float(res_def().get("gap", 0.25)):
		return
	load_at = m.time
	var was := res
	add_res(float(n))
	touch_res(float(res_def().get("wait", 4.0)))
	if res >= res_max() and was < res_max():
		m.sfx("reload", h.pos, -2.0, 1.9)      # the cylinder-spin click
		m.fx.ring(h.pos, 1.2, res_col(), 0.3)

## Perfect-dodge window multiplier (Hunter._mitigate reads it).
func pd_k() -> float:
	return float(e_def().get("pd_k", 2.0)) if pd_t > 0.0 else 1.0

## Shooting from the held slide.
func fires_in_dash() -> bool:
	return not slide.is_empty() and bool(slide.get("held", false))

func _tick(dt: float) -> void:
	pd_t = maxf(0.0, pd_t - dt)
	if res_wait <= 0.0:
		add_res(-float(res_def().get("drain", 1.0)) * dt)
	if not slide.is_empty():
		_tick_slide(dt)
	if rail_tele and is_instance_valid(rail_tele) and rmb_down:
		m.fx.aim_telegraph(rail_tele, h.pos, h.aim_dir())
		var k := clampf(rmb_t / float(rmb_def()["rail"]["time"]), 0.0, 1.0)
		m.fx.telegraph_progress(rail_tele, k)
	if not lock.is_empty():
		_tick_lock(dt)

func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team:
		return
	if String(o.get("src", "")) == "shot" and not o.has("ab"):
		load_chambers(1)

# ------------------------------------------------------------------ dash: Slide Reload
## The roll starts on the press; still holding Shift past 0.18s it becomes the long slide.
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if use_ex:
		if not spend_dash(true): return true
		travel(float(h.cdat.get("ex_dist", 4.6)), float(h.cdat.get("ex_time", 0.2)), {"invuln": 0.1, "trail": "roll", "reload": float(dd["reload"])}, true)
		return true
	if not spend_dash(false):
		return true
	travel(float(dd["roll"]), float(dd["roll_t"]), {"invuln": float(dd["invuln"]), "reload": float(dd["reload"]), "trail": "roll"})
	slide = {"t": 0.0, "held": false, "dir": h.roll_dir}
	if pd_t > 0.0:
		h.dash_at = m.time        # the doubled perfect-dodge window counts from here
	m.later(0.08, func(): if is_instance_valid(h): m.sfx("click", h.pos, -8.0, 1.8))     # shell casings
	return true

func _tick_slide(dt: float) -> void:
	var dd := dash_def()
	slide["t"] = float(slide["t"]) + dt
	var t := float(slide["t"])
	if not bool(slide["held"]):
		if t >= float(dd["tap_t"]) and held("dash") and not h.downed and h.stun_t <= 0.0 and h.root_t <= 0.0 and h.grounded:
			# the held slide: up to 6m over 0.5s, slowing as it goes; you can fire
			slide["held"] = true
			slide["t0"] = t
			h.roll_dir = slide["dir"]
			h.move_kind = "dash"
			m.fx.dust(h.pos, 8)
		elif not held("dash") or t >= float(dd["tap_t"]):
			# a tap roll: it loads 2 chambers
			load_chambers(int(res_def().get("roll", 2)), true)
			slide = {}
			st["last_dash"] = "roll"
		return
	var st_t := t - float(slide["t0"])
	var dur := float(dd["slide_t"])
	if not held("dash") or st_t >= dur or h.stun_t > 0.0 or h.root_t > 0.0:
		var early := st_t < dur * 0.9 and h.stun_t <= 0.0 and h.root_t <= 0.0
		h.roll_t = 0.0
		if early:
			h.dashes = minf(h.max_dashes(), h.dashes + float(dd["refund"]))
		else:
			h.ammo = int(h.wpn["mag"]); h.reload_t = 0.0
			m.sfx("reload", h.pos, -5.0, 1.3)
		st["last_dash"] = "slide"
		slide = {}
		return
	# keep sliding, slowing down (6m over the slide)
	var k := 1.0 - st_t / dur
	h.roll_t = maxf(h.roll_t, dt * 1.5)
	h.roll_speed = float(dd["slide"]) / dur * (0.5 + k)
	h.inv_t = 0.0
	if int(st_t * 20.0) % 2 == 0: m.fx.dust(h.pos, 2)

# ------------------------------------------------------------------ RMB: Trick Shot
func rmb_hold_tick(t: float) -> void:
	if t > float(rmb_def()["hold"]) and rail_tele == null:
		rail_tele = tele_lane(h.pos, h.aim_dir(), float(rmb_def()["rail"]["range"][1]), 0.35, Color("ffd23f"), 0.0)
		m.sfx("rail", h.pos, -14.0, 0.6)

func rmb_auto_t() -> float:
	return float(rmb_def()["rail"]["time"]) + float(rmb_def()["hold"]) + 0.4

func fire_rmb(c: Dictionary) -> void:
	if rail_tele and is_instance_valid(rail_tele): m.fx.end_telegraph(rail_tele)
	rail_tele = null
	last_variant = String(c["variant"])
	if not spend_rmb(): return
	var sd := rmb_def()
	var called: bool = c.get("full", false)
	if called:
		res = 0.0
		m.fx.word(h.pos + Vector3(0, 2.3, 0), "CALLED SHOT", res_col(), true)
		m.sfx("crit", h.pos, -2.0, 0.8)
	var ck := (1.0 + float(res_def()["called_k"])) * 1.5 if called else 1.0
	if c.get("air", false):
		var rc: Dictionary = sd["recoil"]
		var d := h.aim_dir()
		var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": 50.0, "range": 6.0, "size": 0.16},
			"effects": [{"type": "damage", "amount": float(rc["dmg"]) * ck}, {"type": "push", "strength": float(rc["push"]), "from": "caster"}]})
		run(stg, cx("rmb", "recoil_shot", aim()))
		h.gliding = false
		h.vel = Vector3(-d.x * float(rc["kick"]), float(rc["lift"]), -d.y * float(rc["kick"]))
		h.fly_t = 0.3
		m.sfx("rifle", h.pos, -1.0, 0.8)
		return
	if c.get("hold", false):
		var rl: Dictionary = sd["rail"]
		var k := clampf((float(c["t"]) - float(sd["hold"])) / float(rl["time"]), 0.15, 1.0)
		var effs: Array = [{"type": "damage", "amount": lerpf(float(rl["dmg"][0]), float(rl["dmg"][1]), k) * ck}]
		if k >= 0.99: effs.append({"type": "stun", "duration": float(rl["stun"])})
		elif called: effs.append({"type": "stun", "duration": float(res_def()["called_stun"])})
		var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": 80.0, "range": lerpf(float(rl["range"][0]), float(rl["range"][1]), k), "size": 0.16},
			"effects": effs, "modifiers": [{"type": "pierce", "count": 3}]})
		run(stg, cx("rmb", "rail_charge", aim()))
		if k >= 0.99: m.fx.flash(h.pos + Vector3(0, 1.0, 0), Color("ffd23f"), 0.6, 0.08)
		m.sfx("rail", h.pos, -2.0, 0.9)
		return
	_trick(ck, called, 1.0)
	if c.get("e", false):
		var dk := float(sd["double"]["k"])
		m.later(float(sd["double"]["gap"]), func(): if is_instance_valid(h) and not h.downed: _trick(dk, false, dk))

func _trick(k: float, called: bool, _vis: float) -> void:
	var td: Dictionary = rmb_def()["trick"]
	var burst := h.wid == "burst_rifle"
	var effs: Array = [{"type": "damage", "amount": (6.0 if burst else float(td["dmg"])) * k}]
	if called: effs.append({"type": "stun", "duration": float(res_def()["called_stun"])})
	var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": float(td["speed"]), "range": float(td["range"]), "size": 0.14},
		"effects": effs, "modifiers": [{"type": "bounce", "count": 1, "range": float(td["foe_jump"]), "falloff": 0.0}]})
	var walls := int(td["walls"]) + (1 if rank("sec") >= 3 else 0)
	if burst:
		# the Burst Rifle's tap: 3 small ricochets
		for i in 3:
			m.later(0.07 * i, func(): if is_instance_valid(h) and not h.downed: run(stg, cx("rmb", "trick_shot", aim(), {"wall_bounce": 1})))
	else:
		run(stg, cx("rmb", "trick_shot", aim(), {"wall_bounce": walls}))
	m.sfx("rifle", h.pos, -2.0, 1.25)

# ------------------------------------------------------------------ E: Quickdraw
func in_e() -> bool:
	return e_t > 0.0

func cast_e() -> bool:
	var ed := e_def()
	var t := float(ed["time"]) + (1.0 if rank("kin") >= 3 else 0.0)
	h.add_buff("fire_rate", float(ed["fire_rate"]), t)
	h.ammo = int(h.wpn["mag"]); h.reload_t = 0.0
	h.dashes = minf(h.max_dashes(), h.dashes + 1.0)
	pd_t = t + 2.0
	e_t = t
	m.fx.ring(h.pos, 1.6, col_of(ed), 0.3)
	m.sfx("reload", h.pos, -2.0, 1.6)
	var stg := stage("e", {"delivery": {"type": "burst", "origin": "caster", "radius": 0.0}, "effects": [{"type": "buff", "stat": "fire_rate", "amount": float(ed["fire_rate"]), "duration": t, "target": "owner"}]})
	run(stg, cx("e", "quickdraw", h.pos, {"no_floor": true}))
	return true

# ------------------------------------------------------------------ R: Last Round
func move_k() -> float:
	return 1.0 - float(r_def()["self_slow"]) if not lock.is_empty() else 1.0

func cast_r() -> bool:
	var rd := r_def()
	var reach := float(rd["reach"]) + (2.0 if rank("ult") >= 2 else 0.0)
	var tg: Array = rival_hunters_in(reach)
	if tg.is_empty():
		for f in foes_in(h.pos, reach):
			if f is Mob and sees(f): tg.append(f)
	if tg.is_empty():
		return false
	var locks := {}
	for t in tg:
		locks[t.get_instance_id()] = [t, 0.0]
		m.fx.word(t.pos + Vector3(0, 2.4, 0), "LOCKED", res_col(), true)
		if t == m.player and m.hud: m.hud.toast_small("LOCKED  ·  break line of sight", res_col())
	lock = {"t": 0.0, "locks": locks, "reach": reach}
	r_t = float(rd["channel"]) + 0.2
	m.sfx("charge", h.pos, -2.0, 0.9)
	return true

func r_recast() -> bool:
	if lock.is_empty():
		return false
	_fire_lock()
	return true

func _tick_lock(dt: float) -> void:
	lock["t"] = float(lock["t"]) + dt
	var draw := int(lock["t"] * 10.0) != int((float(lock["t"]) - dt) * 10.0)
	for key in (lock["locks"] as Dictionary).keys():
		var e: Array = lock["locks"][key]
		var t: Ent = e[0]
		if not is_instance_valid(t) or t.dead or h.flat_dist(t) > float(lock["reach"]) + 1.0 or not sees(t):
			(lock["locks"] as Dictionary).erase(key)      # broke line of sight: lock dropped
			continue
		e[1] = float(e[1]) + dt
		if draw:
			m.fx.bolt(h.pos + Vector3(0, 1.0, 0), t.pos + Vector3(0, 1.0, 0), Color(res_col(), clampf(0.3 + float(e[1]), 0.3, 1.0)))
	if float(lock["t"]) >= float(r_def()["channel"]) or h.downed or h.stun_t > 0.0:
		_fire_lock()

func _fire_lock() -> void:
	var rd := r_def()
	var locks: Dictionary = lock.get("locks", {})
	lock = {}
	r_t = 0.0
	if h.downed:
		return
	for key in locks:
		var t: Ent = locks[key][0]
		var lt: float = float(locks[key][1])
		if not is_instance_valid(t) or t.dead: continue
		var effs: Array = [{"type": "damage", "amount": minf(60.0, (float(rd["base"]) + float(rd["per_s"]) * lt) * r_k())}]
		if lt >= float(rd["channel"]) - 0.05: effs.append({"type": "stun", "duration": float(rd["stun"])})
		var stg := stage("r", {"delivery": {"type": "projectile", "speed": 70.0, "range": float(rd["reach"]) + 3.0, "size": 0.18}, "effects": effs})
		var c := cx("r", "last_round", t.pos + Vector3(0, 0.9, 0), {"no_floor": true})
		run(stg, c)
	m.sfx("rifle", h.pos, 2.0, 0.6)
	Feel.shake(m, "t3", h, h.pos)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if not lock.is_empty():
		if float(lock["t"]) > 0.9: h.inp["ult"] = true
		return
	if int(h.slot_lv["ult"]) > 0 and float(cd["r"]) <= 0.0 and los and dist < float(r_def()["reach"]) and randf() < 0.35:
		h.inp["ult"] = true; return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist < 9.0 and randf() < 0.3:
		h.inp["sig"] = true; return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 15.0:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
		if dist > 8.0 or randf() < 0.25: bot_hold["rmb"] = float(rmb_def()["hold"]) + float(rmb_def()["rail"]["time"])
	# out of ammo: a held slide reloads it
	if h.ammo <= 0 and h.dashes >= 1.0 and randf() < 0.5:
		h.inp["dash"] = true
		bot_hold["dash"] = 0.6
