class_name RimewrightKit
extends ArchKit
## Tamsin, the Rimewright (light skirmisher with a shelter). docs/heroes/rimewright.md.
## Passive Hoarfrost: damage Chills; a knock on a Chilled foe Splinters them. LMB Hoar Fan: a flurry
## of homing shards ending in three heavy ones. RMB Sleet Lance. Shift Rinkrun (hold). E Rink Wall.
## No R: the old ultimate was flavour; the wall's frost shield gives the squad its part.

var chill := {}                # target instance id -> {t: Ent, left: float}
var fan_hits := {}             # target instance id -> {n: int, left: float}
var darts: Array = []          # homing shards in flight: {s: Dictionary}
var seq_i := 0                 # position in the flurry (0-3 light, 4-6 heavy)
var seq_next := 0.0            # when the next shard may leave
var rinkrun := {}                # the running Rinkrun: {t, dir}
var wall := {}                 # the Rink Wall's record: {w, left, sliding, warded: {}, dir}
var splinter_log := 0           # Splinters fired (tests)

func _setup() -> void:
	res = 0.0

# ------------------------------------------------------------------ Chill and Splinter
func chilled(t: Ent) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	var e: Dictionary = chill.get(t.get_instance_id(), {})
	return float(e.get("left", 0.0)) > 0.0

func add_chill(t: Ent) -> void:
	if t == null or not is_instance_valid(t) or t.dead or t.team == h.team:
		return
	var key := t.get_instance_id()
	var fresh := not chilled(t)
	chill[key] = {"t": t, "left": float(d["passive"].get("chill_t", 4.0))}
	if fresh:
		m.fx.ring(t.pos, 0.9, res_col(), 0.25)

func best_fan() -> int:
	var b := 0
	for k in fan_hits:
		b = maxi(b, int((fan_hits[k] as Dictionary)["n"]))
	return b

func res_frac() -> float: return float(best_fan()) / float(d["passive"].get("fan_hits", 8))
func res_text() -> String: return "%d/%d" % [best_fan(), int(d["passive"].get("fan_hits", 8))]
func full_ready() -> bool: return false

func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team or String(o.get("src", "")) in ["burn", "splinter"]:
		return
	var pd: Dictionary = d["passive"]
	# the knock or the kill on a Chilled foe: they Splinter a beat later
	if t.hp <= 0.0 and chilled(t) and (t is Hunter or t is Mob):
		var at := t.pos
		m.later(float(pd.get("splinter_delay", 0.4)), func(): splinter(at, float(pd["splinter_dmg"]), float(pd["splinter_r"]), t))
		chill.erase(t.get_instance_id())
		return
	add_chill(t)
	if String(o.get("ab", "")) == "fan":
		var key := t.get_instance_id()
		var e: Dictionary = fan_hits.get(key, {"n": 0, "left": 3.0})
		e["n"] = int(e["n"]) + 1
		e["left"] = 3.0
		fan_hits[key] = e
		if int(e["n"]) >= int(pd.get("fan_hits", 8)):
			fan_hits.erase(key)
			var at2 := t.pos
			splinter(at2, float(pd["fan_splinter"]), float(pd["splinter_r"]) * 0.8, t)

func splinter(at: Vector3, dmg: float, r: float, skip: Ent = null) -> void:
	splinter_log += 1
	var col := res_col()
	CareUtil.payoff(m, h, at, "SPLINTER", col, "rime_splinter")
	m.fx.ring(at, r, Color.WHITE, 0.4)
	for f in foes_in(at, r):
		if f == skip and f.hp <= 0.0:
			continue
		f.hurt(dmg * m.dmg_mult(h), h, {"src": "splinter", "ab": "passive", "slow": 1.2, "slow_k": 0.3, "tags": ["passive", "splinter"], "payoff": true})
		add_chill(f)

func _tick(dt: float) -> void:
	for key in chill.keys():
		var e: Dictionary = chill[key]
		e["left"] = float(e["left"]) - dt
		var tv = e["t"]     # untyped first: a freed foe can't be assigned to a typed var
		var t: Ent = tv if is_instance_valid(tv) else null
		if float(e["left"]) <= 0.0 or t == null or t.dead:
			chill.erase(key)
			continue
		var ck := float(d["passive"].get("chill_slow", 0.15))
		if t.slow_t <= 0.0:
			t.slow_k = ck
		t.slow_t = maxf(t.slow_t, 0.25)
	for key in fan_hits.keys():
		var e2: Dictionary = fan_hits[key]
		e2["left"] = float(e2["left"]) - dt
		if float(e2["left"]) <= 0.0: fan_hits.erase(key)
	_tick_darts(dt)
	_tick_rinkrun(dt)
	_tick_wall(dt)
	if h.ctrl == "bot":
		_bot_idle()

# ------------------------------------------------------------------ LMB: Hoar Fan
func lmb_override(held: bool, _dt: float) -> bool:
	if not h.can_fire():
		return true
	if not held:
		if m.time > seq_next + 0.6: seq_i = 0
		return true
	if h.fire_cd > 0.0 or m.time < seq_next:
		return true
	_throw_shard()
	return true

func _throw_shard() -> void:
	var heavy := seq_i >= 4
	var wd: Dictionary = h.wpn
	var dir := h.aim_dir()
	var start := Vector3(h.pos.x + dir.x * 0.6, h.pos.y + 0.95 * float(h.cdat["scale"]), h.pos.z + dir.y * 0.6)
	var dmg: float = float(wd["dmg"]) * (2.0 if heavy else 1.0) * float(m.dmg_mult(h)) * (2.0 if not rinkrun.is_empty() else 1.0)
	var spd := float(wd["speed"]) * (1.35 if heavy else 1.0)
	var rng := float(wd["range"]) * (1.4 if heavy else 1.0) * h.shot_range_k
	h.shot_range_k = 1.0
	var col: Color = wd["color"]
	var extra := {"src": "shot", "ab": "fan", "kb": float(wd["kb"]) * (2.0 if heavy else 1.0), "tracer": 1.0}
	m.spawn_shot(h, start, dir * spd, dmg, rng / spd, float(wd["size"]) * (1.6 if heavy else 1.0), col, extra)
	if not m.shots.is_empty():
		darts.append({"s": m.shots[-1]})
	m.sfx(String(wd["sfx"]), h.pos, -2.0, 1.3 if heavy else 1.0)
	h.recoil = 0.6
	h.muzzle_t = 0.05
	h.reveal_t = maxf(h.reveal_t, 1.2)
	h.idle_fire = 0.0
	seq_i += 1
	if seq_i >= 7:
		seq_i = 0
		seq_next = m.time + 0.5
	else:
		seq_next = m.time + (0.13 if seq_i >= 4 else 0.1)

func _tick_darts(dt: float) -> void:
	for dd in darts.duplicate():
		var s: Dictionary = dd["s"]
		if not m.shots.has(s):
			darts.erase(dd)
			continue
		var v: Vector2 = s["vel"]
		var p: Vector3 = s["pos"]
		var best: Ent = null
		var bd := 9.0
		for f in m.foes_of(h.team):
			var to := Vector2(f.pos.x - p.x, f.pos.z - p.z)
			var dist := to.length()
			if dist < bd and dist > 0.3 and absf(v.angle_to(to)) < 0.7 and f.hittable():
				bd = dist; best = f
		if best != null:
			var want := Vector2(best.pos.x - p.x, best.pos.z - p.z).normalized() * v.length()
			var ang := clampf(v.angle_to(want), -2.4 * dt, 2.4 * dt)
			s["vel"] = v.rotated(ang)

# ------------------------------------------------------------------ Shift: Rinkrun
func fires_in_dash() -> bool:
	return not rinkrun.is_empty()

func on_dash(use_ex: bool) -> bool:
	if not rinkrun.is_empty():
		return true
	var dd := dash_def()
	if use_ex:
		if not spend_dash(true): return true
		travel(float(h.cdat.get("ex_dist", 5.0)), float(h.cdat.get("ex_time", 0.2)), {"invuln": 0.1, "trail": "ghost"}, true)
		return true
	if not spend_dash(false): return true
	var dir := h.inp["move"] as Vector2
	if dir.length() < 0.1: dir = h.aim_dir()
	rinkrun = {"t": 0.0, "dir": dir.normalized()}
	m.sfx("rime_run", h.pos, -3.0, 1.0)
	m.fx.ring(h.pos, 1.0, col_of(dd), 0.3)
	return true

func _tick_rinkrun(dt: float) -> void:
	if rinkrun.is_empty():
		return
	var dd := dash_def()
	rinkrun["t"] = float(rinkrun["t"]) + dt
	var t := float(rinkrun["t"])
	var stop := h.downed or h.stun_t > 0.0 or h.out or t >= float(dd.get("max_t", 1.6)) or h.gliding or not h.grounded
	var holding := held("dash")
	if t > float(dd.get("min_t", 0.2)) and not holding:
		stop = true
	if stop:
		_rinkrun_end()
		return
	# steer gently towards the move keys
	var mv: Vector2 = h.inp["move"]
	var cur: Vector2 = rinkrun["dir"]
	if mv.length() > 0.1:
		var ang := clampf(cur.angle_to(mv.normalized()), -2.2 * dt, 2.2 * dt)
		cur = cur.rotated(ang)
	rinkrun["dir"] = cur
	h.roll_dir = cur
	h.roll_speed = float(dd.get("speed", 11.5))
	h.roll_t = 0.1
	h.move_kind = "rinkrun"
	if fposmod(t, 0.12) < dt:
		m.fx.burst(h.pos + Vector3(0, 0.05, 0), col_of(dd), 3, 1.5, 0.3, 0.0, 0.8)
	if rank("dash") >= 3 and h.over_void():
		_ice_bridge()

func _ice_bridge() -> void:
	m.fx.burst(h.pos + Vector3(0, -0.2, 0), res_col(), 4, 1.0, 0.4, 0.0, 1.0)

## A Boki merge ends the Rinkrun (its refund and slide-out are the same as letting go).
func _drop_holds() -> void:
	if not rinkrun.is_empty():
		_rinkrun_end()

func _rinkrun_end() -> void:
	var dd := dash_def()
	var t := float(rinkrun.get("t", 0.0))
	var early := 1.0 - clampf(t / float(dd.get("max_t", 1.6)), 0.0, 1.0)
	h.dashes = minf(h.max_dashes(), h.dashes + early * float(dd.get("refund", 0.6)))
	h.roll_t = 0.0
	h.vel.x *= 0.3; h.vel.z *= 0.3
	rinkrun = {}
	m.fx.ring(h.pos, 0.8, col_of(dd), 0.2)

func rinkrunning() -> bool: return not rinkrun.is_empty()

# ------------------------------------------------------------------ RMB: Sleet Lance
func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if not spend_rmb():
		return
	play("rime_javelin")
	var ld: Dictionary = rmb_def()["lance"]
	var dir := h.aim_dir()
	var start := Vector3(h.pos.x + dir.x * 0.6, h.pos.y + 0.95, h.pos.z + dir.y * 0.6)
	var rng := float(ld["range"])
	var spd := float(ld["speed"])
	var extra := {"src": "abil", "ab": "utility", "tracer": 1.4, "kb": 0.0, "kx": func(s: Dictionary, at: Vector3, e: Ent, _why: String):
		var trav := Vector2(at.x - (s["start"] as Vector3).x, at.z - (s["start"] as Vector3).z).length()
		var k := clampf(trav / rng, 0.0, 1.0)
		if e != null and e.team != h.team:
			s["dmg"] = float(s["dmg"]) * lerpf(float(ld["near_dmg"]), float(ld["far_dmg"]), k)
			var sx: Dictionary = s["x"]
			sx["slow"] = float(ld["slow_t"])
			sx["slow_k"] = lerpf(float(ld["slow_near"]), float(ld["slow_far"]), k)
		_lance_land(at)}
	m.spawn_shot(h, start, dir * spd, float(ld["dmg"]) * power("sec"), rng / spd, float(ld["hit_r"]) * 0.5, col_of(rmb_def()), extra)
	m.sfx("rime_lance", h.pos, -2.0, 1.0)
	Feel.shake(m, "cast", h, h.pos)

func _lance_land(at: Vector3) -> void:
	var ld: Dictionary = rmb_def()["lance"]
	var col := col_of(rmb_def())
	m.fx.ring(at, 1.0, col, 0.3)
	net_ring(at, 1.0, col)
	var rr := float(ld["burst_r"]) * (1.45 if rank("sec") >= 3 else 1.0)
	m.later(float(ld["delay"]), func():
		m.fx.ring(at, rr, col, 0.4)
		m.fx.burst(at + Vector3(0, 0.5, 0), col, 24, 5.0, 0.5, 4.0, 1.2)
		m.sfx("rime_burst", at, -1.0, 1.0)
		m.shake(0.25, at)
		for f in foes_in(at, rr):
			f.hurt(float(ld["burst_dmg"]) * power("sec"), h, {"src": "abil", "ab": "utility", "tags": ["utility", "lance"], "kb": h.dir_to(f) * -0.0, "slow": 0.8, "slow_k": 0.3}))

# ------------------------------------------------------------------ E: Rink Wall
func cast_e() -> bool:
	var ed := e_def()
	var dir := h.aim_dir()
	var at := h.pos + Vector3(dir.x, 0, dir.y) * float(ed["reach"])
	at.y = h.pos.y
	var g: float = m.world.ground_at(at.x, at.z)
	if g <= World.VOID + 1.0 or m.world.is_block(at.x, at.z):
		at = h.pos + Vector3(dir.x, 0, dir.y) * 2.0
	var hp := float(ed["hp"]) + (40.0 if rank("kin") >= 3 else 0.0)
	var w: Dictionary = m.verbs.add_wall(h, at, dir, {"length": float(ed["length"]), "hp": hp, "time": float(ed["slide_t"]) + 0.2, "move": true, "color": String(ed["col"]), "block": "enemy", "touch": {"kb": float(ed["push"]), "dmg": 0.5, "slow": 1.0, "slow_k": 0.3}}, power("kin"))
	w["y"] = at.y
	wall = {"w": w, "dir": dir, "sliding": true, "t": 0.0, "warded": {}}
	e_t = float(ed["slide_t"])
	play("rime_slam")
	m.sfx("rime_wall", at, -1.0, 1.0)
	m.fx.word(at + Vector3(0, 2.4, 0), "RINK WALL", col_of(ed), false)
	return true

func e_recastable() -> bool:
	return not wall.is_empty() and bool(wall.get("sliding", false))

func e_recast() -> bool:
	if wall.is_empty() or not bool(wall["sliding"]):
		return true
	_freeze_wall()
	return true

func _freeze_wall() -> void:
	var ed := e_def()
	wall["sliding"] = false
	var w: Dictionary = wall["w"]
	w["t"] = float(ed["time"]) + (0.0)
	e_t = float(ed["time"])
	m.fx.ring(Vector3((w["a"].x + w["b"].x) * 0.5, w["y"], (w["a"].y + w["b"].y) * 0.5), 2.0, Color.WHITE, 0.3)
	m.sfx("rime_freeze", h.pos, -3.0, 1.0)

func _tick_wall(dt: float) -> void:
	if wall.is_empty():
		return
	var w: Dictionary = wall["w"]
	if not m.verbs.walls.has(w):
		wall = {}
		e_t = 0.0
		return
	var ed := e_def()
	if bool(wall["sliding"]):
		wall["t"] = float(wall["t"]) + dt
		var dir: Vector2 = wall["dir"]
		var step := dir * float(ed["slide"]) * dt
		var mid: Vector2 = ((w["a"] as Vector2) + (w["b"] as Vector2)) * 0.5 + step
		if m.world.is_void(mid.x, mid.y) or m.world.is_block(mid.x, mid.y) or float(wall["t"]) >= float(ed["slide_t"]):
			_freeze_wall()
		else:
			w["a"] += step
			w["b"] += step
			w["t"] = maxf(float(w["t"]), 0.5)
			if is_instance_valid(w["node"]): m.verbs._place_wall(w, w["node"])
	# allies who touch it get a frost shield, once per wall
	for o in CareUtil.mates(m, h, Vector3.INF, 1e9, false) + [h]:
		var key: int = o.get_instance_id()
		if (wall["warded"] as Dictionary).has(key) and o != h:
			continue
		var c := Geometry2D.get_closest_point_to_segment(Vector2(o.pos.x, o.pos.z), w["a"], w["b"])
		if Vector2(o.pos.x, o.pos.z).distance_to(c) < o.r + 0.9 and absf(o.pos.y - float(w["y"])) < 2.0:
			if o == h:
				continue          # (it shelters you; the shield is for the squad)
			wall["warded"][key] = true
			ward(o)

func ward(o: Hunter) -> void:
	var ed := e_def()
	var amt := float(ed["ward"]) * (2.0 if rank("kin") >= 3 else 1.0)
	if o.remote:
		CareUtil.heal(m, o, amt * 0.5)            # an online squadmate can't take our shield: it comes as health
	else:
		o.shield = maxf(o.shield, amt)
		o.shield_t = maxf(o.shield_t, float(ed["ward_t"]))
	m.fx.ring(o.pos, 1.2, col_of(ed), 0.35)
	m.fx.word(o.pos + Vector3(0, 2.2, 0), "FROST SHIELD", col_of(ed), false)
	m.sfx("shield", o.pos, -3.0, 1.4)

func in_e() -> bool: return not wall.is_empty()

func _e_end() -> void:
	pass

func teardown() -> void:
	super.teardown()
	rinkrun = {}

# ------------------------------------------------------------------ bots
func _bot_idle() -> void:
	pass

func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 12.0 and dist > 3.0 and tgt is Hunter:
		h.inp["aim"] = tgt.pos + Vector3(tgt.vel.x, 0, tgt.vel.z) * 0.3 + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
	if int(h.slot_lv["kin"]) > 0 and not wall.is_empty() and bool(wall["sliding"]) and float(wall["t"]) > 1.2:
		h.inp["sig"] = true          # freeze it where it stands
	elif int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist < 9.0 and los and (h.hp < h.max_hp * 0.8 or randf() < 0.1):
		h.inp["aim"] = tgt.pos
		h.inp["sig"] = true
	# rinkrun in to the fan's range, or away when hurt
	if rinkrun.is_empty() and h.dashes >= 1.0 and h.grounded and randf() < 0.25:
		if h.hp < h.max_hp * 0.4:
			h.inp["move"] = -h.dir_to(tgt)
		elif dist > 8.0:
			h.inp["move"] = h.dir_to(tgt)
		else:
			return
		h.inp["dash"] = true
		bot_hold["dash"] = 0.8
