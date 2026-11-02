class_name TenderKit
extends ArchKit
## Linnet, the Tender (medium support). docs/heroes/tender.md.
## Passive Bearer: run into a downed teammate to carry them. LMB Lantern Crook embers Kindle foes.
## RMB Burrseed sticks, then roots. Shift Relay Step. E Hearthlight heals; press again to toss it.
## No R: the revive part of the old ultimate lives in Hearthlight's rank 3 flare.

var kind := {}                 # target instance id -> {t: Ent, n: int, left: float}
var burrs: Array = []          # seeds stuck to foes: {t: Ent, left: float, node: Node3D}
var hearth := {}               # the light: {pos, mode: self|flying|latched|ground, to, who, left, tick, boost, node, revived}
var emp_until := 0.0           # the ember in flight left an idle gun (long range, double refund)
var lock_t := 0.0              # can't pick anyone up (after dropping them)
var pick_blocked := 0.0
var carry_t := 0.0
var safe_t := 0.0
var setdown_was := false        # the set-down key (crouch, never F: F is the Boki system's) was down last tick
const SETDOWN := "crouch"      # the one place to change the set-down key (a Hunter.inp key)
var last_dash_pass := false    # the last Relay Step went through a teammate (tests)

func _setup() -> void:
	res = 0.0

# ------------------------------------------------------------------ Kindle
func kindle_on(t: Ent) -> int:
	if t == null or not is_instance_valid(t):
		return 0
	var e: Dictionary = kind.get(t.get_instance_id(), {})
	return int(e.get("n", 0)) if float(e.get("left", 0.0)) > 0.0 else 0

func add_kindle(t: Ent, n := 1) -> void:
	if t == null or not is_instance_valid(t) or t.dead or t.team == h.team:
		return
	var key := t.get_instance_id()
	var e: Dictionary = kind.get(key, {"t": t, "n": 0, "left": 0.0})
	var had := int(e["n"]) if float(e["left"]) > 0.0 else 0
	e["n"] = mini(int(res_def().get("max", 5)), had + n)
	e["left"] = float(res_def().get("dur", 4.0))
	e["t"] = t
	kind[key] = e
	if int(e["n"]) >= int(res_def().get("max", 5)) and had < int(res_def().get("max", 5)):
		m.fx.word(t.pos + Vector3(0, 2.5, 0), "KINDLED", res_col(), true)
		m.fx.ring(t.pos, 1.2, res_col(), 0.3)
		m.sfx("unlock", t.pos, -6.0, 1.6)

func best_kindle() -> int:
	var b := 0
	for k in kind:
		b = maxi(b, kindle_on((kind[k] as Dictionary)["t"]))
	return b

func res_frac() -> float: return float(best_kindle()) / float(res_def().get("max", 5))
func res_text() -> String: return "%d/%d" % [best_kindle(), int(res_def().get("max", 5))]
func full_ready() -> bool: return false

func outgoing(t: Ent, dmg: float, o: Dictionary) -> float:
	if String(o.get("src", "")) == "shot":
		return dmg + float(res_def().get("per_stack", 1.0)) * float(kindle_on(t))
	return dmg

func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team:
		return
	var src := String(o.get("src", ""))
	if src == "shot":
		var had := kindle_on(t)
		if had > 0:
			var emp: bool = m.time < emp_until
			wind_back_hearth(float(res_def().get("emp_refund" if emp else "refund", 0.2)))
		add_kindle(t, 1)
	elif src == "abil" and String(o.get("ab", "")) == "utility" and o.get("kindle", false):
		add_kindle(t, 1)

func wind_back_hearth(s: float) -> void:
	cd["e"] = maxf(0.0, float(cd["e"]) - s)

# ------------------------------------------------------------------ tick
func _tick(dt: float) -> void:
	lock_t = maxf(0.0, lock_t - dt)
	# Kindle fades
	for key in kind.keys():
		var e: Dictionary = kind[key]
		e["left"] = float(e["left"]) - dt
		if float(e["left"]) <= 0.0 or not is_instance_valid(e["t"]) or (e["t"] as Ent).dead:
			kind.erase(key)
	# an idle gun: the next ember flies further (and winds Hearthlight back twice as much)
	if h.idle_fire >= 1.0 and not h.downed:
		h.shot_range_k = 1.4
		emp_until = m.time + 0.9
	_tick_burrs(dt)
	_tick_hearth(dt)
	_tick_carry(dt)
	if h.ctrl == "bot":
		_bot_idle(dt)

## A Boki merge sets a carried teammate down (unbroken: no stun) and keeps the key from picking anyone up meanwhile.
func _drop_holds() -> void:
	if not carrying().is_empty():
		drop_all(false)
	carry_t = 0.0
	setdown_was = false
	lock_t = maxf(lock_t, 0.3)

# ------------------------------------------------------------------ Bearer (carry)
func carrying() -> Array:
	return CareUtil.carried_of(m, h)

func move_k() -> float:
	return 1.0 - (float(d["passive"].get("slow", 0.3)) if not carrying().is_empty() else 0.0)

func can_pick() -> bool:
	return lock_t <= 0.0 and h.stun_t <= 0.0 and h.root_t <= 0.0 and not busy() and not Hex.active(h)

func _tick_carry(dt: float) -> void:
	var pd: Dictionary = d["passive"]
	var cs := carrying()
	if not cs.is_empty():
		carry_t += dt
		if h.stun_t > 0.0 or h.root_t > 0.0 or Hex.active(h) or h.shield <= 0.01:
			drop_all(true)
			return
		h.shield_t = maxf(h.shield_t, 2.0)      # the Bearer shield stays up while you carry
		var down := bool(h.inp.get(SETDOWN, false))
		if down and not setdown_was:
			drop_all(false)
		setdown_was = down
		return
	carry_t = 0.0
	setdown_was = bool(h.inp.get(SETDOWN, false))
	if not can_pick():
		return
	for o in CareUtil.mates(m, h, h.pos, float(pd.get("pick_r", 1.1)) + h.r):
		if not o.downed or CareUtil.is_carried(o) or bool(o.get_meta("stomped", false)):
			continue
		if absf(o.pos.y - h.pos.y) > 1.5:
			continue
		if h.ctrl == "bot" and not _foes_near(5.0):
			continue          # a bot only carries when someone is closing in; otherwise it revives on the spot
		if carrying().size() >= int(pd.get("max", 2)):
			break
		pick_up(o)

func _foes_near(r: float) -> bool:
	for f in m.foes_of(h.team):
		if f is Hunter and h.flat_dist(f) < r:
			return true
	return false

func pick_up(o: Hunter) -> void:
	var pd: Dictionary = d["passive"]
	CareUtil.set_carry(m, o, h.nid)
	h.shield = float(pd.get("shield", 40.0)) + float(pd.get("shield_lv", 6.0)) * float(maxi(0, h.lvl - 1))
	h.shield_t = 999.0
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "CARRY", res_col(), false)
	m.fx.ring(h.pos, 1.4, res_col(), 0.3)
	m.sfx("pickup", h.pos, -2.0, 0.8)
	if rank("dash") >= 3:
		h.ex_cd = 0.0
	if h.is_local() and m.hud:
		m.hud.toast_small("Carrying %s. Press %s to set them down" % [o.pname, Settings.key_cap(SETDOWN)], res_col())

func drop_all(broken: bool) -> void:
	for o in carrying():
		CareUtil.set_carry(m, o, "")
		o.teleport(Vector3(h.pos.x, h.pos.y, h.pos.z) + Vector3(0.9, 0, 0))
		o.vel = Vector3.ZERO
	h.shield = 0.0
	h.shield_t = 0.0
	lock_t = maxf(lock_t, 1.5)          # set down: not picked straight back up
	if broken:
		var pd: Dictionary = d["passive"]
		h.stun_t = maxf(h.stun_t, float(pd.get("drop_stun", 0.6)))
		lock_t = float(pd.get("lock", 4.0))
		m.fx.word(h.pos + Vector3(0, 2.4, 0), "DROPPED", Color("ff8a6a"), false)
		m.sfx("knock", h.pos, -4.0, 1.2)

# ------------------------------------------------------------------ dash: Relay Step
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if not spend_dash(use_ex):
		return true
	var dist := float(h.cdat.get("ex_dist", 5.0)) if use_ex else float(dd.get("dist", 4.2))
	var tt := float(h.cdat.get("ex_time", 0.2)) if use_ex else float(dd.get("time", 0.16))
	var from := h.pos
	travel(dist, tt, {"invuln": float(dd.get("invuln", 0.12)), "trail": "ghost"}, use_ex)
	var rd := h.roll_dir if h.roll_dir.length() > 0.1 else h.aim_dir()
	var to := from + Vector3(rd.x, 0, rd.y).normalized() * dist
	last_dash_pass = false
	var ar := float(dd.get("ally_r", 1.1))
	for o in CareUtil.mates(m, h, Vector3.INF, 1e9, false):
		var c := Geometry2D.get_closest_point_to_segment(Vector2(o.pos.x, o.pos.z), Vector2(from.x, from.z), Vector2(to.x, to.z))
		if Vector2(o.pos.x, o.pos.z).distance_to(c) < ar + o.r and absf(o.pos.y - from.y) < 2.0:
			last_dash_pass = true
			if use_ex:
				h.ex_cd *= 1.0 - float(dd.get("refund", 0.5))
			else:
				h.dashes = minf(h.max_dashes(), h.dashes + float(dd.get("refund", 0.5)))
			wind_back_hearth(float(dd.get("e_refund", 1.0)))
			m.fx.ring(o.pos, 1.3, col_of(dd), 0.3)
			m.fx.word(o.pos + Vector3(0, 2.2, 0), "RELAY", col_of(dd), false)
			m.sfx("ab_ready", o.pos, -6.0, 1.5)
			break
	return true

# ------------------------------------------------------------------ RMB: Burrseed
func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if not spend_rmb():
		return
	play("tend_seed")
	var sd: Dictionary = rmb_def()["seed"]
	var dir := h.aim_dir()
	var start := Vector3(h.pos.x + dir.x * 0.6, h.pos.y + 0.95, h.pos.z + dir.y * 0.6)
	var life := float(sd["range"]) / float(sd["speed"])
	var extra := {"src": "abil", "ab": "utility", "tracer": 0.0, "kb": 0.0, "kx": func(s: Dictionary, at: Vector3, e: Ent, _why: String):
		if e != null and e.team != h.team and not e.dead:
			_stick(e)}
	m.spawn_shot(h, start, dir * float(sd["speed"]), float(sd["dmg"]) * power("sec"), life, float(sd["hit_r"]) * 0.5, col_of(rmb_def()), extra)
	m.sfx("tend_seed", h.pos, -2.0, 1.0)
	Feel.shake(m, "t1", h, h.pos)

func _stick(e: Ent) -> void:
	var sd: Dictionary = rmb_def()["seed"]
	var n := Node3D.new()
	n.top_level = true
	var col := col_of(rmb_def())
	var core := MeshInstance3D.new()
	core.mesh = Models.sphere(0.2, 10)
	core.material_override = Models.glow_mat(Color(col, 0.95))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(core)
	m.add_child(n)
	burrs.append({"t": e, "left": float(sd["delay"]), "node": n, "ring": 0.0})
	m.fx.ring(e.pos, 1.0, col, 0.3)
	m.sfx("tend_stick", e.pos, -3.0, 1.0)

func _tick_burrs(dt: float) -> void:
	for b in burrs.duplicate():
		var t: Ent = b["t"]
		var n: Node3D = b["node"]
		if not is_instance_valid(t) or t.dead:
			if is_instance_valid(n): n.queue_free()
			burrs.erase(b)
			continue
		b["left"] = float(b["left"]) - dt
		b["ring"] = float(b["ring"]) - dt
		if is_instance_valid(n):
			n.global_position = t.position + Vector3(0, 1.6 if t is Hunter else 1.1, 0)
			n.scale = Vector3.ONE * (1.0 + 0.25 * sin(m.time * 14.0))
		if float(b["ring"]) <= 0.0:
			b["ring"] = 0.5
			net_ring(t.pos, 0.9, col_of(rmb_def()))     # everyone sees the burr pulse
		if float(b["left"]) <= 0.0:
			if is_instance_valid(n): n.queue_free()
			burrs.erase(b)
			_burst(t)

func _burst(t: Ent) -> void:
	var sd: Dictionary = rmb_def()["seed"]
	var at := t.pos
	var rr := float(sd["burst_r"]) * (1.0 + (0.0))
	var col := col_of(rmb_def())
	m.fx.ring(at, rr, col, 0.45)
	m.fx.burst(at + Vector3(0, 0.5, 0), col, 26, 5.0, 0.6, 3.0, 1.2)
	m.sfx("tend_root", at, 0.0, 1.0)
	m.shake(0.25, at)
	var root := float(sd["root"]) + (0.3 if rank("sec") >= 3 else 0.0)
	for f in foes_in(at, rr):
		f.hurt(float(sd["burst_dmg"]) * power("sec"), h, {"src": "abil", "ab": "utility", "root": root, "dr": true, "kindle": true, "tags": ["utility", "burrseed"]})
	m.fx.word(at + Vector3(0, 2.2, 0), "ROOTED", col, false)

# ------------------------------------------------------------------ E: Hearthlight
func cast_e() -> bool:
	var ed := e_def()
	hearth = {"pos": h.pos, "mode": "self", "who": null, "left": float(ed["time"]), "tick": 0.0, "boost": 0.0, "node": _hearth_node(), "revived": false, "tossed": false}
	e_t = float(ed["time"])
	play("tend_hearth")
	m.fx.ring(h.pos, float(ed["radius"]), col_of(ed), 0.5)
	m.sfx("tend_hearth", h.pos, -2.0, 1.0)
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "HEARTHLIGHT", col_of(ed), false)
	return true

func e_recastable() -> bool:
	return not hearth.is_empty() and not bool(hearth.get("tossed", false))

func e_recast() -> bool:
	if hearth.is_empty() or hearth.get("tossed", false):
		return true
	var ed := e_def()
	var to := aim_at(float(ed["reach"]))
	# carrying someone: a toss aimed at yourself lands on them
	var cs := carrying()
	if not cs.is_empty() and Vector2(to.x - h.pos.x, to.z - h.pos.z).length() < 2.0:
		_latch(cs[0])
	else:
		hearth["mode"] = "flying"
		hearth["to"] = to
		hearth["pos"] = h.pos
	hearth["tossed"] = true
	hearth["boost"] = float(ed.get("boost_t", 1.0)) * (2.0 if rank("kin") >= 3 else 1.0)
	m.sfx("tend_toss", h.pos, -2.0, 1.2)
	h._ab_feedback("k1", "cast")
	return true

func _latch(o: Hunter) -> void:
	hearth["mode"] = "latched"
	hearth["who"] = o
	m.fx.ring(o.pos, 1.5, col_of(e_def()), 0.3)
	m.sfx("ab_ready", o.pos, -4.0, 1.4)

func _hearth_node() -> Node3D:
	var n := Node3D.new()
	n.top_level = true
	var col := col_of(e_def())
	var lamp := MeshInstance3D.new()
	lamp.mesh = Models.sphere(0.22, 12)
	lamp.material_override = Models.glow_mat(Color(col.lightened(0.3), 0.95))
	lamp.position = Vector3(0, 1.3, 0)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(lamp)
	var halo := MeshInstance3D.new()
	halo.mesh = Models.flat_quad(float(e_def()["radius"]) * 2.0)
	halo.material_override = Models.ring_mat(Color(col, 0.8), 0.07)
	halo.position = Vector3(0, 0.08, 0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(halo)
	m.add_child(n)
	return n

func hearth_center() -> Vector3:
	match String(hearth.get("mode", "self")):
		"self": return h.pos
		"latched":
			var w = hearth.get("who")
			return (w as Hunter).pos if is_instance_valid(w) else hearth["pos"]
	return hearth["pos"]

func _tick_hearth(dt: float) -> void:
	if hearth.is_empty():
		return
	var ed := e_def()
	# a stun on the bearer puts the light out
	var on_me: bool = String(hearth["mode"]) == "self" or (String(hearth["mode"]) == "latched" and hearth.get("who") == h)
	if on_me and h.stun_t > 0.0:
		_hearth_end(false, "OUT")
		return
	if String(hearth["mode"]) == "flying":
		var p: Vector3 = hearth["pos"]
		var to: Vector3 = hearth["to"]
		var step := float(ed.get("toss_speed", 18.0)) * dt
		var dv := to - p
		p += dv.normalized() * minf(step, dv.length())
		hearth["pos"] = p
		for o in CareUtil.mates(m, h, p, float(ed.get("latch_r", 1.0)), true):
			_latch(o)
			break
		if dv.length() <= step:
			hearth["mode"] = "ground"
	var c := hearth_center()
	hearth["pos"] = c if String(hearth["mode"]) != "flying" else hearth["pos"]
	var n: Node3D = hearth["node"]
	if is_instance_valid(n):
		n.global_position = c
		n.rotation.y += dt * 1.5
	hearth["left"] = float(hearth["left"]) - dt
	e_t = float(hearth["left"])
	hearth["tick"] = float(hearth["tick"]) + dt
	var every := float(ed["every"])
	if float(hearth["tick"]) >= every:
		hearth["tick"] = float(hearth["tick"]) - every
		var per := float(ed["over"]) / (float(ed["time"]) / every)
		_pulse(c, per)
		m.fx.ring(c, float(ed["radius"]), col_of(ed), 0.35)
	hearth["boost"] = maxf(0.0, float(hearth["boost"]) - dt)
	if float(hearth["left"]) <= 0.0:
		_hearth_end(true, "FLARE")

func heal_k() -> float:
	return 1.0 + 0.15 * float(maxi(0, rank("kin") - 1)) + (0.0)

func _pulse(c: Vector3, per: float) -> void:
	var ed := e_def()
	var boost := 1.5 if float(hearth.get("boost", 0.0)) > 0.0 else 1.0
	for o in m.hunters:
		if o.team != h.team or o.out or o.extracted:
			continue
		if Vector2(o.pos.x - c.x, o.pos.z - c.z).length() > float(ed["radius"]) + o.r:
			continue
		var amt := per * heal_k() * boost * (float(ed.get("self_k", 0.33)) if o == h else 1.0)
		CareUtil.heal(m, o, amt, float(ed.get("wisp_k", 5.0)))

func _hearth_end(flare: bool, word: String) -> void:
	var ed := e_def()
	var c := hearth_center()
	if flare:
		var amt := float(ed["burst"]) * heal_k()
		var col := col_of(ed)
		CareUtil.payoff(m, h, c, "HEARTH", col, "tend_flare")
		for o in m.hunters:
			if o.team != h.team or o.out or o.extracted:
				continue
			if Vector2(o.pos.x - c.x, o.pos.z - c.z).length() > float(ed["radius"]) + o.r:
				continue
			if o.downed:
				if rank("kin") >= 3:
					if CareUtil.revive(m, o, h):
						CareUtil.payoff(m, h, o.pos, "UP", col, "revive")
				else:
					CareUtil.heal(m, o, amt, float(ed.get("wisp_k", 5.0)))
			else:
				CareUtil.heal(m, o, amt * (float(ed.get("self_k", 0.33)) if o == h else 1.0))
	else:
		m.fx.word(c + Vector3(0, 2.0, 0), word, Color("ff8a6a"), false)
		m.sfx("knock", c, -6.0, 1.4)
	if is_instance_valid(hearth.get("node")):
		(hearth["node"] as Node3D).queue_free()
	hearth = {}
	e_t = 0.0

func _e_end() -> void:
	if not hearth.is_empty():
		_hearth_end(true, "FLARE")

func in_e() -> bool: return not hearth.is_empty()

func teardown() -> void:
	super.teardown()
	if not hearth.is_empty() and is_instance_valid(hearth.get("node")):
		(hearth["node"] as Node3D).queue_free()
	for b in burrs:
		if is_instance_valid(b["node"]): (b["node"] as Node3D).queue_free()
	burrs.clear()

# ------------------------------------------------------------------ bots
func _bot_idle(dt: float) -> void:
	# squadmate hurt nearby: light the lantern; carrying under fire: run away from the nearest rival
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and hearth.is_empty() and not busy():
		var need := 0.0
		for o in CareUtil.mates(m, h, h.pos, float(e_def()["radius"]) - 0.6, true):
			need += (o.max_hp - o.hp) if not o.downed else 40.0
		if h.hp < h.max_hp * 0.6:
			need += (h.max_hp - h.hp) * 0.33
		if need > 30.0:
			h.inp["sig"] = true
	var cs := carrying()
	if cs.is_empty():
		safe_t = 0.0
		return
	var worst: Ent = null
	var wd := 1e9
	for f in m.foes_of(h.team):
		if f is Hunter and h.flat_dist(f) < wd:
			wd = h.flat_dist(f); worst = f
	if carry_t > 4.0:
		drop_all(false)
		lock_t = 8.0          # a bot carries for a few seconds at most, then revives them
	elif worst != null and wd < 9.0:
		safe_t = 0.0
		var away := -h.dir_to(worst)
		h.inp["move"] = away
		h.inp["fire"] = false
	else:
		safe_t += dt
		if safe_t > 0.3:
			drop_all(false)
			lock_t = 6.0          # now revive them on the spot

func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null or not carrying().is_empty():
		return
	# a seed on the nearest rival from mid range
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 10.0 and dist > 2.5 and tgt is Hunter and randf() < 0.7:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
	# a hop through a teammate when one is close and we're being pressed
	if dist < 3.5 and h.dashes >= 1.0 and randf() < 0.2:
		h.inp["aim"] = h.pos - Vector3(h.dir_to(tgt).x, 0, h.dir_to(tgt).y) * 4.0
		h.inp["dash"] = true
