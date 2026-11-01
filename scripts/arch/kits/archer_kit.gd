class_name ArcherKit
extends ArchKit
## Archer (light): Grapple Arrow, Focus, Snare (Tripwire, Pinning Shot, Plunge, seeking in the
## Flare, rooted harder at full Focus), Flare Arrow, Skyfall Volley. docs/ARCHETYPES.md §6.2.

var flare := {}                # the live Flare zone {pos, r, t}
var trips: Array = []          # our live Tripwires (verbs trap dictionaries)
var pin_tele: Node3D = null    # the Pinning Shot's lane while held
var volley := {}
var high_t := 0.0              # re-checks high ground now and then
var on_high := false

func full_ready() -> bool:
	return res >= res_max() - 0.01

func res_text() -> String:
	return "%d" % int(res)

## A full Focus makes the next shot fully drawn or aimed at once, with +20% range (Hunter.fire reads it).
func take_focus_shot() -> bool:
	if res < res_max() - 0.01:
		return false
	res = 0.0
	m.fx.flash(h.pos + Vector3(h.aim_dir().x * 0.6, 1.0, h.aim_dir().y * 0.6), res_col(), 0.5, 0.08)
	return true

func _tick(dt: float) -> void:
	var rd := res_def()
	high_t -= dt
	if high_t <= 0.0:
		high_t = 0.5
		on_high = _high_ground()
	var still: bool = h.grounded and Vector2(h.vel.x, h.vel.z).length() < 0.6 and h.roll_t <= 0.0
	var k := float(rd.get("high_k", 1.5)) if on_high else 1.0
	if still:
		add_res(res_max() / float(rd.get("still_t", 1.4)) * k * dt)
	elif h.crouch:
		add_res(res_max() / float(rd.get("sneak_t", 2.8)) * k * dt)
	elif h.grounded and Vector2(h.vel.x, h.vel.z).length() > 2.5:
		add_res(-float(rd.get("run_drain", 60.0)) * dt)
	trips = trips.filter(func(t): return m.verbs.traps.has(t))
	if not flare.is_empty():
		flare["t"] = float(flare["t"]) - dt
		if float(flare["t"]) <= 0.0: flare = {}
	if pin_tele and is_instance_valid(pin_tele) and rmb_down:
		m.fx.aim_telegraph(pin_tele, h.pos, h.aim_dir())
	if not volley.is_empty():
		_tick_volley(dt)

func _high_ground() -> bool:
	var gy: float = m.world.ground_at(h.pos.x, h.pos.z)
	var lower := 0
	for i in 8:
		var a := TAU * i / 8.0
		var q := h.pos + Vector3(cos(a), 0, sin(a)) * 3.0
		var g: float = m.world.ground_at(q.x, q.z)
		if g <= World.VOID + 1.0 or g < gy - 0.9: lower += 1
	return lower >= 3

func on_take(_by: Ent, dmg: float, _o: Dictionary) -> void:
	if dmg > 0.5:
		add_res(-float(res_def().get("hit_loss", 40.0)))

func in_e() -> bool:
	return not flare.is_empty() and h.flat_dist(flare["pos"]) < float(flare["r"])

# ------------------------------------------------------------------ dash: Grapple Arrow
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if not spend_dash(use_ex and not h.gliding):
		return true
	var dir := h.aim_dir()
	var bite := _bite(dir, float(dd.get("reach", 9.0)), float(dd.get("max_up", 3.2)))
	var from := h.pos
	if h.gliding:
		h.glide_fuel = minf(1.0, h.glide_fuel + float(dd.get("glide_cool", 0.2)))
	Feel.dash_sound(m, id, h.pos, h)
	CombatBus.ability_used.emit(h, "grapple", "dodge")
	if bite == Vector3.INF:
		# bit nothing: a hop back, away from the cursor
		travel(float(dd.get("hop", 3.2)), 0.14, {"invuln": 0.0, "dir": -dir, "trail": "roll"}, use_ex)
		st["last_grapple"] = "hop"
		if rank("dash") >= 3: h.dashes = minf(h.max_dashes(), h.dashes + 0.4)
		return true
	st["last_grapple"] = "zip"
	var dist := Vector2(bite.x - from.x, bite.z - from.z).length()
	var t := clampf(dist / float(dd.get("zip_speed", 22.0)), 0.18, 0.45)
	m.fx.bolt(from + Vector3(0, 1.2, 0), bite + Vector3(0, 0.3, 0), Color("e8f7c0"))
	var rp := rider_points(from, bite)
	if String(rp.get("as", "")) == "blink":
		# a Lunowl: the rope flashes and you're simply there
		m.later(0.1, func():
			if is_instance_valid(h) and not h.downed:
				h.teleport(bite); h.vel = Vector3.ZERO; h.gliding = false)
	else:
		h.gliding = false
		h.launch_to(bite + Vector3(0, 0.15, 0), t)
		# the landing ring flashes 0.15s before you arrive, for everyone
		m.later(maxf(0.0, t - 0.15), func(): if is_instance_valid(h): m.fx.ring(bite, 1.0, Color("e8f7c0"), 0.2))
		tele_lane(from, Vector2(bite.x - from.x, bite.z - from.z).normalized(), dist, 0.12, Color("e8f7c0"), t)
	if rp.get("repeat") != null:
		st["regrapple_t"] = 1.0       # an echo: a free second grapple within 1s
	return true

## Where the line arrow bites: a wall, rock or ledge up to max_up above you (you climb on top),
## or Vector3.INF for nothing (open ground, the abyss).
func _bite(dir: Vector2, reach: float, max_up: float) -> Vector3:
	var y0 := h.pos.y
	var k := 0.5
	var last_ok := Vector3.INF
	while k <= reach:
		var q := h.pos + Vector3(dir.x, 0, dir.y) * k
		var g: float = m.world.ground_at(q.x, q.z)
		if m.world.is_block(q.x, q.z):
			return last_ok if last_ok != Vector3.INF and k > 1.2 else Vector3.INF
		if g > World.VOID + 1.0 and g > y0 + 0.6:
			if g <= y0 + max_up + (2.0 if not h.grounded else 0.0):
				var top := h.pos + Vector3(dir.x, 0, dir.y) * minf(reach, k + 0.6)
				var gt: float = m.world.ground_at(top.x, top.z)
				if gt < g - 0.3 or m.world.is_block(top.x, top.z): top = q
				return Vector3(top.x, m.world.ground_at(top.x, top.z), top.z)
			return last_ok if last_ok != Vector3.INF and k > 1.2 else Vector3.INF
		if g > World.VOID + 1.0 and absf(g - y0) < 0.6:
			last_ok = Vector3(q.x, g, q.z)
		k += 0.25
	return Vector3.INF

# ------------------------------------------------------------------ RMB: Snare
func rmb_hold_tick(t: float) -> void:
	if t > 0.15 and pin_tele == null and not rmb_ctx.get("air", false):
		# the draw shows a glint and the lane to enemies (a hard-CC telegraph)
		pin_tele = tele_lane(h.pos, h.aim_dir(), float(rmb_def()["pin"]["range"]), 0.5, Color("ffe0a0"), 0.0)
		m.fx.flash(h.pos + Vector3(0, 1.2, 0), Color("ffe0a0"), 0.4, 0.1)

func rmb_auto_t() -> float:
	return 1.5

func _drop_tele() -> void:
	if pin_tele and is_instance_valid(pin_tele):
		m.fx.end_telegraph(pin_tele)
	pin_tele = null

func fire_rmb(c: Dictionary) -> void:
	_drop_tele()
	last_variant = String(c["variant"])
	if not spend_rmb(): return
	var sd := rmb_def()
	if c.get("air", false):
		_plunge()
		return
	var target_aim := aim()
	if c.get("e", false):
		target_aim = _seek(target_aim, float(sd.get("seek_deg", 10.0)))
	if c.get("hold", false):
		_pin(target_aim)
		return
	var sn: Dictionary = sd["snare"]
	var root := float(sn["root_full"]) if c.get("full", false) else float(sn["root"])
	# the arrow comes down at the cursor (up to 11m): a miss plants the Tripwire there
	var srange := clampf(Vector2(target_aim.x - h.pos.x, target_aim.z - h.pos.z).length() + 0.5, 2.5, float(sn["range"]))
	var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": float(sn["speed"]), "range": srange, "size": 0.16},
		"effects": [{"type": "damage", "amount": float(sn["dmg"])}, {"type": "root", "duration": root}]})
	run(stg, cx("rmb", "snare", target_aim, {"on_shot_end": func(at: Vector3, why: String, e):
		if why != "hit" and e == null:
			_tripwire(at)}))
	Feel.cast_sound(m, "projectile", "control", h.pos, h)

func _seek(a: Vector3, deg: float) -> Vector3:
	var d0 := Vector2(a.x - h.pos.x, a.z - h.pos.z).normalized()
	var best: Ent = null; var bd := cos(deg_to_rad(deg))
	for f in m.foes_of(h.team):
		if not ("reveal_t" in f) or float(f.get("reveal_t")) <= 0.0: continue
		var to := Vector2(f.pos.x - h.pos.x, f.pos.z - h.pos.z)
		if to.length() > 14.0: continue
		var dt := to.normalized().dot(d0)
		if dt > bd: bd = dt; best = f
	return (best.pos + Vector3(0, 0.9, 0)) if best else a

func _tripwire(at: Vector3) -> void:
	var tr := res_def()
	var td: Dictionary = rmb_def()["trip"]
	var g := ground(at - Vector3(h.aim_dir().x, 0, h.aim_dir().y) * 0.3)
	if m.world.is_void(g.x, g.z):
		return
	var maxn := int(td["max"]) + (1 if rank("sec") >= 3 else 0)
	while trips.size() >= maxn:
		var old: Dictionary = trips.pop_front()
		if m.verbs.traps.has(old): m.verbs._drop_trap(old)
	var n0: int = m.verbs.traps.size()
	# the trigger: a 0.15s click, then root, reveal and damage (the trap rule, DASHES §5.3)
	var stg := stage("rmb", {"delivery": {"type": "trap", "origin": "here", "radius": 1.0, "arm": float(td["arm"]), "duration": float(td["time"])},
		"then": {"on_trigger": [{"delivery": {"type": "burst", "origin": "here", "radius": 1.3},
			"effects": [{"type": "damage", "amount": float(td["dmg"])}, {"type": "root", "duration": float(td["root"])}, {"type": "mark", "mode": "reveal", "duration": float(td["reveal"])}],
			"modifiers": [{"type": "delay", "time": 0.15}]}]}}, {"hit": "add"})
	run(stg, cx("rmb", "tripwire", g, {"at": g}))
	for i in range(n0, m.verbs.traps.size()):
		trips.append(m.verbs.traps[i])

func _pin(a: Vector3) -> void:
	var pd: Dictionary = rmb_def()["pin"]
	var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": float(pd["speed"]), "range": float(pd["range"]), "size": 0.2},
		"effects": [{"type": "damage", "amount": float(pd["dmg"])}, {"type": "push", "strength": float(pd["push"]), "from": "caster"}],
		"modifiers": [{"type": "pierce", "count": 1}]})
	var dir := Vector2(a.x - h.pos.x, a.z - h.pos.z).normalized()
	run(stg, cx("rmb", "pinning_shot", a, {"on_foe": func(f: Ent, _c: Dictionary):
		# pushed into terrain within 3m: pinned (exploit near_wall)
		if _wall_behind(f, dir, float(pd["wall"])):
			m.later(0.12, func():
				if is_instance_valid(f) and not f.dead:
					f.hurt(0.1, h, {"root": float(pd["root"]), "src": "abil", "ab": "utility", "tags": ["utility", "pin"], "exploit": true, "dr": true})
					m.fx.word(f.pos + Vector3(0, 2.2, 0), "PINNED", Feel.cat_color("control"), true))}))
	Feel.cast_sound(m, "projectile", "control", h.pos, h)
	m.sfx("rail", h.pos, -4.0, 1.3)

func _wall_behind(f: Ent, dir: Vector2, reach: float) -> bool:
	var g0: float = f.pos.y
	var k := 0.4
	while k <= reach:
		var q := f.pos + Vector3(dir.x, 0, dir.y) * k
		if m.world.is_block(q.x, q.z) or m.world.ground_at(q.x, q.z) > g0 + 0.8:
			return true
		k += 0.3
	return false

func _plunge() -> void:
	var pd: Dictionary = rmb_def()["plunge"]
	var at := h.pos
	var stg := stage("rmb", {"delivery": {"type": "burst", "origin": "caster", "radius": float(pd["radius"])},
		"effects": [{"type": "push", "strength": float(pd["push"])}]}, {"hit": "add"})
	run(stg, cx("rmb", "plunge", at))
	h.vel.y = maxf(h.vel.y, float(pd["lift"]))
	h.gliding = false
	h.grounded = false
	h.glide_fuel = minf(1.0, h.glide_fuel + float(pd["cool"]))
	m.fx.bolt(at + Vector3(0, 1.0, 0), ground(at) + Vector3(0, 0.1, 0), Color("e8f7c0"))
	m.sfx("whoosh", at, -3.0, 1.3)

# ------------------------------------------------------------------ E: Flare Arrow
func cast_e() -> bool:
	var ed := e_def()
	var at := aim_at(float(ed["reach"]))
	var r := float(ed["radius"])
	var t := float(ed["time"]) + (2.0 if rank("kin") >= 3 else 0.0)
	m.spawn_shot(h, h.pos + Vector3(0, 1.2, 0), Vector2(at.x - h.pos.x, at.z - h.pos.z).normalized() * maxf(4.0, h.flat_dist(at) / float(ed["flight"])), 0.0, float(ed["flight"]), 0.15, col_of(ed), {"lob": 2.5, "cos": true})
	m.later(float(ed["flight"]), func():
		if not is_instance_valid(h): return
		flare = {"pos": at, "r": r, "t": t}
		e_t = t
		var stg := stage("e", {"delivery": {"type": "burst", "origin": "aim", "radius": r}, "effects": [{"type": "mark", "mode": "reveal", "duration": t}]})
		run(stg, cx("e", "flare", at, {"no_floor": true}))
		var zst := stage("e", {"delivery": {"type": "zone", "origin": "aim", "radius": minf(r, 6.0), "duration": t, "every": 0.5}, "effects": [{"type": "mark", "mode": "reveal", "duration": 1.0}]}, {})
		run(zst, cx("e", "flare_zone", at, {"no_floor": true}))
		# traps and smoke show up too
		for tr in m.verbs.traps:
			if Vector2(tr["at"].x - at.x, tr["at"].z - at.z).length() < r: tr["reveal"] = maxf(float(tr.get("reveal", 0.0)), 1.0); tr["seen_by"] = h.team
		m.fx.ring(at, r, col_of(ed), 0.6)
		m.fx.burst(at + Vector3(0, 2.5, 0), col_of(ed), 30, 6.0, 0.8, 1.0, 1.4)
		m.sfx("ping", at, -1.0, 0.9))
	Feel.cast_sound(m, "projectile", "utility", h.pos, h)
	return true

# ------------------------------------------------------------------ R: Skyfall Volley
func cast_r() -> bool:
	var rd := r_def()
	var at := aim_at(float(rd["reach"]))
	var r := float(rd["radius"])
	var tell := float(rd["tell"])
	tele_circle(at, r, col_of(rd), tell)
	for i in 8:
		m.later(0.08 * i, func(): if is_instance_valid(h): m.fx.burst(h.pos + Vector3(0, 1.4, 0), col_of(rd), 3, 6.0, 0.4, -8.0, 0.8, Vector3.UP, 15.0))
	m.sfx("charge", at, -2.0, 1.8)      # a rising whistle
	var waves := int(rd["waves"]) + (1 if rank("ult") >= 2 else 0)
	volley = {"at": at, "t": tell, "left": waves, "n": waves}
	r_t = tell + float(rd["every"]) * waves + 0.2
	return true

func _tick_volley(dt: float) -> void:
	volley["t"] = float(volley["t"]) - dt
	if float(volley["t"]) > 0.0:
		return
	var rd := r_def()
	var at: Vector3 = volley["at"]
	var left := int(volley["left"])
	volley["left"] = left - 1
	volley["t"] = float(rd["every"])
	var last := left == 1
	if left == 2:
		tele_circle(at, float(rd["inner"]), Feel.cat_color("control"), float(rd["every"]))   # the inner ring's own fill
	var stg := stage("r", {"delivery": {"type": "burst", "origin": "aim", "radius": float(rd["radius"])},
		"effects": [{"type": "damage", "amount": float(rd["dmg"]) * r_k()}, {"type": "slow", "duration": 0.8, "strength": float(rd["slow"])}]})
	run(stg, cx("r", "volley", at, {"no_floor": true}))
	for i in 6:
		var q := at + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * float(rd["radius"]) * 0.8
		m.fx.bolt(q + Vector3(0, 6.0, 0), q, col_of(rd))
	if last:
		var ist := stage("r", {"delivery": {"type": "burst", "origin": "aim", "radius": float(rd["inner"])}, "effects": [{"type": "root", "duration": float(rd["root"])}]}, {"ctrl": "add", "ctrl_cap": "soft"})
		run(ist, cx("r", "volley_root", at, {"no_floor": true}))
		volley = {}

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if int(h.slot_lv["ult"]) > 0 and float(cd["r"]) <= 0.0 and dist < float(r_def()["reach"]) and los and randf() < 0.4:
		h.inp["aim"] = tgt.pos; h.inp["ult"] = true; return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist < 13.0 and randf() < 0.3:
		h.inp["aim"] = tgt.pos; h.inp["sig"] = true; return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 13.0:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
		if dist > 9.0 or randf() < 0.35: bot_hold["rmb"] = float(rmb_def()["hold"]) + 0.15
	# grapple away from a brawler, or up onto a ledge
	if dist < 3.0 and h.dashes >= 1.0 and randf() < 0.2:
		h.inp["aim"] = h.pos - Vector3(h.dir_to(tgt).x, 0, h.dir_to(tgt).y) * 4.0
		h.inp["dash"] = true
