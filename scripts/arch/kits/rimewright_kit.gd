class_name RimewrightKit
extends ArchKit
## Tamsin, the Rimewright (light ice controller). docs/heroes/rimewright.md. Copies her source as it
## plays: ice damage, control and a wall, no healing or shields for the squad.
## Passive Hoarfrost: damage Chills; a knock on a Chilled foe, or 8 darts on one foe, Shatters them.
## LMB Ice Dart: hold for a steady stream of slow homing shards that bow out and curve onto the foe
## nearest the cursor; while skating they fly straight and thick and hit 1.6x. RMB Ice Spear: hold to
## see the landing ring, let go: it lands at the cursor, leaves a slow zone and detonates 1.8s later.
## Shift Skate (hold). E Rink Wall: a 0.2s tell, then a narrow block of ice that slides toward the
## cursor, widening, shoving foes; E again freezes it. X Rimelock (level 6): sealed in ice, invulnerable,
## inside a slowing rink that cracks open into a stun. R is the Boki Merge. Looks: CareLook, UltLook;
## moves: KMovesCare "tm_".

var chill := {}                # target instance id -> {t: Ent, left: float}
var fan_hits := {}             # target instance id -> {n: int, left: float, t: Ent}
var darts: Array = []          # homing shards in flight: {s: Dictionary, side: float, passed}
var dart_n := 0                # darts thrown (alternates the bow side and the hand)
var seq_next := 0.0            # when the next dart may leave
var rinkrun := {}              # the running Skate: {t, dir, loop}
var wall := {}                 # the Rink Wall: {w, dir, sliding, t, slide_t, hp0, hit}
var wall_cast := {}            # the wall's 0.2 s tell before it erupts: {t, dir, travel}
var spear_aim := false         # RMB held: the landing ring and the raised spear are up
var zones: Array = []          # landed spears: {at, left, total, id}
var zone_n := 0
var splinter_log := 0          # Shatters fired (tests)
var look: CareLook
var chip_t := 0.0
var aft_t := 0.0
var stats := {"darts": 0, "beams": 0, "spears": 0, "detonations": 0, "rimes": 0, "crashes": 0, "cancels": 0}   # tests
var rime := {}                 # Rimelock running: {t, at, slow: {instance id: seconds in the rink}, creak}
var last_stunned := 0          # foes the last Rimelock crash stunned (tests)
var ult_look: UltLook

func _setup() -> void:
	res = 0.0

func lk() -> CareLook:
	if look == null:
		look = CareLook.new(m, h)
	return look

func play_soft(move: String) -> void:
	if anim_id == "" or m.time - anim_at >= KMovesCare.length(anim_id):
		play(move)

# ------------------------------------------------------------------ Chill and Shatter
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
		m.fx.burst(t.pos + Vector3(0, 1.0, 0), res_col(), 8, 1.5, 0.4, -1.0, 0.8)

func fan_on(t: Ent) -> int:
	if t == null or not is_instance_valid(t): return 0
	return int((fan_hits.get(t.get_instance_id(), {}) as Dictionary).get("n", 0))

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
	# the knock or the kill on a Chilled foe: they Shatter a beat later
	if t.hp <= 0.0 and chilled(t) and (t is Hunter or t is Mob):
		var at := t.pos
		m.later(
				float(pd.get("splinter_delay", 0.4)),
				func(): splinter(at, float(pd["splinter_dmg"]), float(pd["splinter_r"]), t))
		chill.erase(t.get_instance_id())
		return
	add_chill(t)
	if String(o.get("ab", "")) == "fan":
		var key := t.get_instance_id()
		var e: Dictionary = fan_hits.get(key, {"n": 0, "left": 3.0, "t": t})
		e["n"] = int(e["n"]) + 1
		e["left"] = 3.0
		e["t"] = t
		fan_hits[key] = e
		if int(e["n"]) >= int(pd.get("fan_hits", 8)):
			fan_hits.erase(key)
			splinter(t.pos, float(pd["fan_splinter"]), float(pd["splinter_r"]) * 0.8, t)

## Shatter: a starburst of ice spikes round the foe, damage and more Chill to everyone near.
func splinter(at: Vector3, dmg: float, r: float, skip: Ent = null) -> void:
	splinter_log += 1
	var col := res_col()
	CareUtil.payoff(m, h, at, "SHATTER", col, "rime_splinter")
	lk().burst("spikes", at, {"r": r * 0.75, "dur": 0.65})
	lk().burst("flare", at, {"col": Color("9af0e6"), "rim": Color(1, 1, 1), "r": r, "dur": 0.3, "pattern": 2.0})
	play_soft("tm_shatter")
	for f in foes_in(at, r):
		if f == skip and f.hp <= 0.0:
			continue
		f.hurt(
				dmg * power("passive"), h,
				{
					"src": "splinter", "ab": "passive", "slow": 1.2, "slow_k": 0.3, "tags": ["passive", "splinter"],
					"payoff": true})
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
		var tv2 = e2["t"]
		if float(e2["left"]) <= 0.0 or not is_instance_valid(tv2):
			fan_hits.erase(key)
			continue
		# the frost glow on the foe grows with each dart toward the Shatter
		var n := int(e2["n"])
		lk().keep(
				"frost%d" % key, "frost", (tv2 as Node3D).global_position,
				{"r": 0.9 + 0.04 * n, "a": 0.25 + 0.6 * float(n) / 8.0})
	_tick_darts(dt)
	_tick_rinkrun(dt)
	_tick_wall_cast(dt)
	_tick_wall(dt)
	_tick_zones(dt)
	_tick_rime(dt)
	_tick_trails(dt)
	if h.is_local() and not busy():
		AimKit.line(h, "aim", {"alpha": 0.7, "col": Color("e8ffff")})     # the thin aim line to the cursor, always up
	lk().tick(dt)
	if ult_look != null:
		ult_look.tick(dt)

# ------------------------------------------------------------------ LMB: Ice Dart
func lmb_override(held: bool, _dt: float) -> bool:
	if not h.can_fire() or not rime.is_empty():
		return true
	if not held or h.fire_cd > 0.0 or m.time < seq_next:
		return true
	_throw_dart()
	return true

func _throw_dart() -> void:
	var wd: Dictionary = h.wpn
	var skating := not rinkrun.is_empty()
	var dir := h.aim_dir()
	dart_n += 1
	var side := 1.0 if dart_n % 2 == 0 else -1.0
	# a dart leaves bowed out to one side and curves back in; a skating dart flies straight
	var bow := 0.0 if skating else deg_to_rad(float(wd.get("bow_deg", 18.0))) * side
	var v := dir.rotated(bow)
	var start := Vector3(h.pos.x + v.x * 0.6, h.pos.y + 0.95 * float(h.cdat["scale"]), h.pos.z + v.y * 0.6)
	var dmg: float = float(wd["dmg"]) * float(m.dmg_mult(h)) * (
			float(dash_def().get("dart_k", 1.6)) if skating else 1.0)
	var spd := float(wd.get("skate_speed", 30.0)) if skating else float(wd["speed"])
	var rng := float(wd["range"]) * h.shot_range_k
	h.shot_range_k = 1.0
	var extra := {"src": "shot", "ab": "fan", "kb": float(wd["kb"]), "tracer": 1.0}
	m.spawn_shot(
			h, start, v * spd, dmg, rng / spd * (1.0 if skating else 1.15),
			float(wd["size"]) * (1.6 if skating else 1.0), wd["color"], extra)
	var s := lk().last_shot()
	if not s.is_empty():
		lk().skin(s, "beam" if skating else "shard")
		if not skating:
			darts.append({"s": s, "side": side, "passed": false})
	m.fx.flash(start, Color("e8ffff"), 0.3 if not skating else 0.5, 0.05)
	m.sfx("rime_beam" if skating else String(wd["sfx"]), h.pos, -2.0, 1.0 + 0.06 * side)
	if skating:
		stats["beams"] += 1
		play("tm_beam")
	else:
		stats["darts"] += 1
		if not spear_aim:
			play("tm_dart_r" if side > 0.0 else "tm_dart_l")
	h.recoil = 0.4
	h.muzzle_t = 0.05
	h.reveal_t = maxf(h.reveal_t, 1.2)
	h.idle_fire = 0.0
	seq_next = m.time + float(wd.get("rate", 0.18))

## Homing: each dart turns hard toward the foe nearest the cursor (or, with none there, the nearest
## one ahead of it, or else the cursor point itself), so the bowed darts curve in.
func _tick_darts(dt: float) -> void:
	var wd: Dictionary = h.wpn
	var turn := float(wd.get("turn", 7.0))
	var aimp: Vector3 = h.inp.get("aim", h.pos)
	var near_cur: Ent = null
	var nd := float(wd.get("cursor_r", 3.5))
	for f in m.foes_of(h.team):
		if not f.hittable(): continue
		var dc := Vector2(f.pos.x - aimp.x, f.pos.z - aimp.z).length()
		if dc < nd:
			nd = dc
			near_cur = f
	for dd in darts.duplicate():
		var s: Dictionary = dd["s"]
		if not m.shots.has(s):
			darts.erase(dd)
			continue
		var v: Vector2 = s["vel"]
		var p: Vector3 = s["pos"]
		var want := Vector2.ZERO
		if near_cur != null:
			want = Vector2(near_cur.pos.x - p.x, near_cur.pos.z - p.z)
		else:
			var best: Ent = null
			var bd := float(wd.get("acquire", 9.0))
			for f in m.foes_of(h.team):
				var to := Vector2(f.pos.x - p.x, f.pos.z - p.z)
				if (to.length() < bd
						and to.length() > 0.3
						and absf(v.angle_to(to)) < deg_to_rad(float(wd.get("cone_deg", 75.0)))
						and f.hittable()):
					bd = to.length()
					best = f
			if best != null:
				want = Vector2(best.pos.x - p.x, best.pos.z - p.z)
			elif not bool(dd["passed"]):
				want = Vector2(aimp.x - p.x, aimp.z - p.z)
				if want.length() < 0.8 or v.dot(want) < 0.0:
					dd["passed"] = true          # past the cursor: it flies on straight
					want = Vector2.ZERO
		if want.length() > 0.05:
			var ang := clampf(v.angle_to(want), -turn * dt, turn * dt)
			s["vel"] = v.rotated(ang)

# ------------------------------------------------------------------ Shift: Skate
func fires_in_dash() -> bool:
	return not rinkrun.is_empty()

func on_dash(use_ex: bool) -> bool:
	if not rinkrun.is_empty() or not rime.is_empty():
		return true
	var dd := dash_def()
	if use_ex:
		if not spend_dash(true): return true
		travel(float(h.cdat.get("ex_dist", 5.0)), float(h.cdat.get("ex_time", 0.2)), {"invuln": 0.1}, true)
		play("tm_dash_air")
		m.sfx("rime_flip", h.pos, -3.0, 1.0)
		aft_t = 0.0
		return true
	if not spend_dash(false): return true
	var dir := h.inp["move"] as Vector2
	if dir.length() < 0.1: dir = h.aim_dir()
	rinkrun = {"t": 0.0, "dir": dir.normalized(), "loop": 0.16}
	play("tm_skate_go")
	m.sfx("rime_run", h.pos, -3.0, 1.0)
	lk().burst("flare", h.pos, {"col": Color("bff7ef"), "rim": Color(1, 1, 1), "r": 1.1, "dur": 0.25, "pattern": 2.0})
	return true

func _tick_rinkrun(dt: float) -> void:
	if rinkrun.is_empty():
		return
	var dd := dash_def()
	rinkrun["t"] = float(rinkrun["t"]) + dt
	var t := float(rinkrun["t"])
	# she skates on over a ledge (only a glide, a stun or letting go ends it)
	var stop := h.downed or h.stun_t > 0.0 or h.out or t >= float(dd.get("max_t", 2.4)) or h.gliding
	if t > float(dd.get("min_t", 0.2)) and not held("dash"):
		stop = true
	if stop:
		_rinkrun_end()
		return
	# steer toward the move keys (a gentle turn rate: the skate carries its line)
	var mv: Vector2 = h.inp["move"]
	var cur: Vector2 = rinkrun["dir"]
	var steer := float(dd.get("steer", 2.2))
	if mv.length() > 0.1:
		cur = cur.rotated(clampf(cur.angle_to(mv.normalized()), -steer * dt, steer * dt))
	rinkrun["dir"] = cur
	h.roll_dir = cur
	h.roll_speed = float(dd.get("speed", 8.0))
	h.roll_t = 0.1
	h.move_kind = "rinkrun"
	# the stride move, replayed every 0.56 s
	rinkrun["loop"] = float(rinkrun["loop"]) - dt
	var stride_free: bool = anim_id in ["tm_skate", "tm_skate_go"] or m.time - anim_at >= KMovesCare.length(anim_id)
	if float(rinkrun["loop"]) <= 0.0 and stride_free:
		rinkrun["loop"] = KMovesCare.length("tm_skate")
		play("tm_skate")
	if rank("dash") >= 3 and h.over_void():
		m.fx.burst(h.pos + Vector3(0, -0.2, 0), res_col(), 4, 1.0, 0.4, 0.0, 1.0)

## A Boki merge ends the Skate (its refund is the same as letting go), drops the spear aim and a wall
## still in its tell (no wall comes up).
func _drop_holds() -> void:
	if not rime.is_empty():
		_rime_clear()
	if not rinkrun.is_empty():
		_rinkrun_end()
	if spear_aim or rmb_down:
		spear_aim = false
		rmb_down = false
		if anim_id == "tm_spear_aim": anim_id = ""
	wall_cast = {}

func _rinkrun_end() -> void:
	var dd := dash_def()
	var t := float(rinkrun.get("t", 0.0))
	var early := 1.0 - clampf(t / float(dd.get("max_t", 2.4)), 0.0, 1.0)
	h.dashes = minf(h.max_dashes(), h.dashes + early * float(dd.get("refund", 0.6)))
	h.roll_t = 0.0
	h.vel.x *= 0.3
	h.vel.z *= 0.3
	rinkrun = {}
	play("tm_skate_stop")
	m.sfx("rime_stop", h.pos, -4.0, 1.0)
	m.fx.burst(
			h.pos + Vector3(0, 0.15, 0), Color("dffcff"), 12, 3.5, 0.35, 6.0, 0.8,
			Vector3(h.roll_dir.x, 0.6, h.roll_dir.y), 50.0)

func rinkrunning() -> bool: return not rinkrun.is_empty()

## The skate's ice trail and the air dash's after-images, in her teal.
func _tick_trails(dt: float) -> void:
	if not rinkrun.is_empty():
		chip_t -= dt
		if chip_t <= 0.0:
			chip_t = 0.05
			var side := Vector2(-h.roll_dir.y, h.roll_dir.x) * (0.18 if int(m.time * 20.0) % 2 == 0 else -0.18)
			lk().burst("chip", h.position + Vector3(side.x, 0.0, side.y), {"dur": 0.7})
	elif h.roll_t > 0.0 and h.move_kind == "dash":
		aft_t -= dt
		if aft_t <= 0.0:
			aft_t = 0.03
			lk().burst(
					"aft", h.position,
					{"col": Color("5fd6c4"), "yaw": h.face, "r": float(h.cdat.get("scale", 1.0)), "dur": 0.22})

# ------------------------------------------------------------------ RMB: Ice Spear
func rmb_charge_full() -> float: return 0.0

## Held: the landing ring at the cursor (clamped to range) and the spear raised behind her head.
func rmb_hold_tick(_t: float) -> void:
	if not rmb_ready() or busy():
		return
	var ld: Dictionary = rmb_def()["lance"]
	AimKit.circle(
			h, "rmb",
			{
				"range": float(ld["range"]), "r": float(ld["zone_r"]), "ticks": true, "star": true,
				"col": Color("dffcff")})
	if not spear_aim:
		spear_aim = true
		play("tm_spear_aim")
		m.sfx("rime_spear_aim", h.pos, -6.0, 1.0)

func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	spear_aim = false
	AimKit.hide(h, "rmb")
	if not spend_rmb():
		if anim_id == "tm_spear_aim": anim_id = ""
		return
	play("tm_spear")
	var ld: Dictionary = rmb_def()["lance"]
	var dir := h.aim_dir()
	var start := Vector3(h.pos.x + dir.x * 0.6, h.pos.y + 0.95, h.pos.z + dir.y * 0.6)
	var spd := float(ld["speed"])
	var dist := AimMode.dist(h, float(ld["range"]))          # lands at the cursor, clamped to its range
	var on_land := func(_s: Dictionary, at: Vector3, _e: Ent, _why: String): _spear_land(at)
	var extra := {"src": "abil", "ab": "utility", "tracer": 1.4, "kb": 0.0, "kx": on_land}
	m.spawn_shot(
			h, start, dir * spd, float(ld["dmg"]) * power("sec"), dist / spd, float(ld["hit_r"]) * 0.5,
			col_of(rmb_def()), extra)
	lk().skin(lk().last_shot(), "spear")
	stats["spears"] += 1
	m.sfx("rime_lance", h.pos, -2.0, 1.0)
	Feel.shake(m, "cast", h, h.pos)

## The spear lands: a small burst and a slow zone with a spinning crystal; 1.8 s later it detonates.
func _spear_land(at0: Vector3) -> void:
	var ld: Dictionary = rmb_def()["lance"]
	var at := ground(at0)
	zone_n += 1
	zones.append({"at": at, "left": float(ld["delay"]), "total": float(ld["delay"]), "id": zone_n})
	m.fx.burst(at + Vector3(0, 0.3, 0), Color("bff7ef"), 12, 3.0, 0.35, 6.0, 0.8)
	m.sfx("rime_zone", at, -3.0, 1.0)
	net_ring(at, float(ld["zone_r"]), col_of(rmb_def()))

func _tick_zones(dt: float) -> void:
	var ld: Dictionary = rmb_def()["lance"]
	for z in zones.duplicate():
		z["left"] = float(z["left"]) - dt
		var at: Vector3 = z["at"]
		var k := 1.0 - float(z["left"]) / maxf(0.01, float(z["total"]))
		var key := "zone%d" % int(z["id"])
		lk().keep(
				key, "zone", at,
				{
					"r": float(ld["zone_r"]), "col": Color("7fd8ff"), "rim": Color("e8ffff"), "fill": 0.8,
					"sweep": k, "pattern": 2.0, "spin": m.time * 0.6, "a": 0.9})
		AimKit.circle(
				h, key,
				{"at": at, "r": float(ld["burst_r"]), "fill": k, "all": true, "dashed": true, "col": Color("bff7ef")})
		for f in foes_in(at, float(ld["zone_r"])):
			f.slow_k = maxf(f.slow_k if f.slow_t > 0.0 else 0.0, float(ld["zone_slow"]))
			f.slow_t = maxf(f.slow_t, 0.2)
			add_chill(f)
		if float(z["left"]) <= 0.0:
			zones.erase(z)
			lk().drop(key)
			AimKit.hide(h, key)
			_detonate(at)

func _detonate(at: Vector3) -> void:
	var ld: Dictionary = rmb_def()["lance"]
	var rr := float(ld["burst_r"]) * (1.3 if rank("sec") >= 3 else 1.0)
	stats["detonations"] += 1
	lk().burst("dome", at, {"r": rr, "dur": 0.45})
	lk().burst("spikes", at, {"r": rr * 0.6, "dur": 0.5})
	m.fx.burst(at + Vector3(0, 0.6, 0), Color("dffcff"), 30, 6.0, 0.5, 5.0, 1.3)
	m.sfx("rime_burst", at, -1.0, 1.0)
	Feel.shake(m, "t4", h, at)
	play_soft("tm_clench")
	for f in foes_in(at, rr):
		f.hurt(
				float(ld["burst_dmg"]) * power("sec"), h,
				{
					"src": "abil", "ab": "utility", "tags": ["utility", "lance"], "root": float(ld["freeze"]),
					"dr": true, "slow": 0.8, "slow_k": 0.3, "payoff": true})
		lk().burst("shell", f.pos, {"dur": float(ld["encase_t"]), "ent": f})

# ------------------------------------------------------------------ E: Rink Wall
## E: a 0.2 s tell (a sparkle at her feet, and everyone sees the path), then the wall erupts.
func cast_e() -> bool:
	if not rime.is_empty():
		return false
	var ed := e_def()
	var dir := h.aim_dir()
	# it slides until its middle reaches the cursor (clamped to its travel)
	var travel_d := clampf(AimMode.cursor_dist(h) - float(ed["reach"]), float(ed["travel_min"]), float(ed["travel"]))
	wall_cast = {"t": float(ed["tell"]), "dir": dir, "travel": travel_d}
	e_t = float(ed["tell"]) + 0.1
	play("tm_wall")
	lk().burst(
			"flare", h.pos,
			{"col": Color("c8a8ff"), "rim": Color(1, 1, 1), "r": 0.9, "dur": float(ed["tell"]) + 0.05, "pattern": 2.0})
	m.fx.burst(h.pos + Vector3(0, 0.2, 0), Color("e8d8ff"), 14, 1.5, 0.3, -2.0, 0.7)
	AimKit.lane(
			h, "e",
			{
				"len": float(ed["reach"]) + travel_d, "width": float(ed["length_max"]), "all": true,
				"dur": float(ed["tell"]) + 0.3, "col": Color("9af0e6")})
	m.sfx("rime_wall_tell", h.pos, -3.0, 1.0)
	return true

func _tick_wall_cast(dt: float) -> void:
	if wall_cast.is_empty():
		return
	wall_cast["t"] = float(wall_cast["t"]) - dt
	if float(wall_cast["t"]) <= 0.0:
		var wc := wall_cast
		wall_cast = {}
		_raise_wall(wc["dir"], float(wc["travel"]))

func _raise_wall(dir: Vector2, travel_d: float) -> void:
	var ed := e_def()
	var at := h.pos + Vector3(dir.x, 0, dir.y) * float(ed["reach"])
	at.y = h.pos.y
	var g: float = m.world.ground_at(at.x, at.z)
	if g <= World.VOID + 1.0 or m.world.is_block(at.x, at.z):
		at = h.pos + Vector3(dir.x, 0, dir.y) * 1.0
	var hp := float(ed["hp"]) + (40.0 if rank("kin") >= 3 else 0.0)
	var w: Dictionary = m.verbs.add_wall(
			h, at, dir,
			{
				"length": float(ed["length"]), "hp": hp, "time": float(ed["time"]), "move": true,
				"color": String(ed["col"]), "block": "enemy",
				"touch": {"kb": float(ed["push"]), "dmg": 0.5, "slow": 1.0, "slow_k": 0.3}},
			power("kin"))
	w["y"] = at.y
	# her own ice look instead (CareLook "wall")
	if is_instance_valid(w["node"]): (w["node"] as Node3D).visible = false
	wall = {
			"w": w, "dir": dir, "sliding": true, "t": 0.0, "slide_t": travel_d / float(ed["slide"]),
			"hp0": float(w["hp"]), "hit": 0.0}
	e_t = float(ed["time"])
	m.sfx("rime_wall", at, -1.0, 1.0)
	m.fx.burst(at + Vector3(0, 0.4, 0), Color("dffcff"), 24, 5.0, 0.45, 8.0, 1.2)
	Feel.shake(m, "t2", h, at)

func e_recastable() -> bool:
	return not wall.is_empty() and bool(wall.get("sliding", false))

func e_recast() -> bool:
	if not wall_cast.is_empty():
		return true          # still in its tell
	if wall.is_empty() or not bool(wall["sliding"]):
		return true
	_freeze_wall()
	play("tm_freeze")
	return true

func _freeze_wall() -> void:
	var ed := e_def()
	wall["sliding"] = false
	wall["frozen"] = true
	var w: Dictionary = wall["w"]
	w["t"] = float(ed["frozen_t"])
	e_t = float(ed["frozen_t"])
	wall["hit"] = 1.0
	var mid := ((w["a"] as Vector2) + (w["b"] as Vector2)) * 0.5
	lk().burst(
			"flare", Vector3(mid.x, float(w["y"]), mid.y),
			{"col": Color("e8ffff"), "rim": Color(1, 1, 1), "r": 2.4, "dur": 0.3, "pattern": 2.0})
	m.sfx("rime_freeze", h.pos, -3.0, 1.0)

## Sliding toward the cursor and widening from a narrow block to its full width; it stops at the
## cursor distance, at a cliff or a wall, then stands until its time runs out.
func _tick_wall(dt: float) -> void:
	if wall.is_empty():
		return
	var w: Dictionary = wall["w"]
	if not m.verbs.walls.has(w):
		wall = {}
		e_t = 0.0
		return
	var ed := e_def()
	var mid: Vector2 = ((w["a"] as Vector2) + (w["b"] as Vector2)) * 0.5
	if bool(wall["sliding"]):
		wall["t"] = float(wall["t"]) + dt
		var dir: Vector2 = wall["dir"]
		var nmid := mid + dir * float(ed["slide"]) * dt
		if (m.world.is_void(nmid.x, nmid.y)
				or m.world.is_block(nmid.x, nmid.y)
				or float(wall["t"]) >= float(wall["slide_t"])):
			wall["sliding"] = false          # it stops where it got to and stands for the rest of its time
		else:
			mid = nmid
			_carry(w, dir, dir * float(ed["slide"]) * dt)
	var gk := clampf(float(wall["t"]) / maxf(0.1, minf(float(ed["grow_t"]), float(wall["slide_t"]))), 0.0, 1.0)
	var ln := lerpf(float(ed["length"]), float(ed["length_max"]), gk)
	var side := Vector2(-(wall["dir"] as Vector2).y, (wall["dir"] as Vector2).x)
	w["a"] = mid - side * ln * 0.5
	w["b"] = mid + side * ln * 0.5
	w["len"] = ln
	# a hit whitens it for a beat
	if float(w["hp"]) < float(wall["hp0"]) - 0.01:
		wall["hp0"] = float(w["hp"])
		wall["hit"] = 1.0
	wall["hit"] = maxf(0.0, float(wall["hit"]) - dt * 4.0)
	var rise := clampf(float(wall["t"]) / 0.15, 0.0, 1.0) if not bool(wall.get("frozen", false)) else 1.0
	lk().keep(
			"wall", "wall", Vector3(mid.x, float(w["y"]), mid.y),
			{"a": w["a"], "b": w["b"], "y": float(w["y"]), "hit": float(wall["hit"]), "rise": maxf(rise, 0.1)})
	if is_instance_valid(w["node"]):
		(w["node"] as Node3D).visible = false

## A foe on the wall's front face rides along with it (it pushes and carries, it never passes through).
func _carry(w: Dictionary, dir: Vector2, step: Vector2) -> void:
	for f in m.foes_of(h.team):
		if f.dead or absf(f.pos.y - float(w["y"])) > 2.0:
			continue
		var p2 := Vector2(f.pos.x, f.pos.z)
		var c := Geometry2D.get_closest_point_to_segment(p2, w["a"], w["b"])
		var off := p2 - c
		if off.length() < f.r + 0.55 and off.dot(dir) > -0.1:
			var ahead: float = (f.r + 0.55) - off.dot(dir)
			var nd := p2 + step + dir * maxf(0.0, ahead * 0.5)
			if not m.world.is_block(nd.x, nd.y):
				f.teleport(Vector3(nd.x, f.pos.y, nd.y))

func in_e() -> bool: return not wall.is_empty() or not wall_cast.is_empty()

func _e_end() -> void:
	pass

func teardown() -> void:
	super.teardown()
	rinkrun = {}
	rime = {}
	zones.clear()
	if look != null:
		look.teardown()
		look = null
	if ult_look != null:
		ult_look.teardown()
		ult_look = null

# ------------------------------------------------------------------ X: Rimelock
func ulk() -> UltLook:
	if ult_look == null:
		ult_look = UltLook.new(m, h)
	return ult_look


func ult_running() -> bool:
	return not rime.is_empty()


## Sealed in: invulnerable and rooted, and the rink snaps out round her. Nothing else fires inside.
func cast_ult() -> bool:
	if not rinkrun.is_empty():
		_rinkrun_end()
	if spear_aim or rmb_down:
		spear_aim = false
		rmb_down = false
		AimKit.hide(h, "rmb")
	rime = {"t": 0.0, "at": h.pos, "slow": {}, "creak": 0.6}
	stats["rimes"] += 1
	_rime_hold_body()
	play("tm_rime")
	m.sfx("rime_lock", h.pos, 0.0, 1.0)
	m.fx.word(h.pos + Vector3(0, 3.0, 0), "RIMELOCK", col_of(x_def()), true)
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), Color("dffcff"), 24, 4.0, 0.4, 2.0, 1.1)
	net_ring(h.pos, float(x_def()["radius"]), col_of(x_def()))
	Feel.shake(m, "cast", h, h.pos)
	return true


func _rime_hold_body() -> void:
	h.inv_t = maxf(h.inv_t, 0.12)
	h.root_t = maxf(h.root_t, 0.12)
	h.vel.x = 0.0
	h.vel.z = 0.0


## X again: in the last `late` seconds it cracks open early at late_k; any earlier the shell just breaks
## (no damage, no stun, no bond).
func ult_recast() -> bool:
	var xd := x_def()
	if float(rime["t"]) >= float(xd["hold"]) - float(xd["late"]):
		_rime_crash(float(xd["late_k"]))
	else:
		_rime_cancel()
	return true


func _tick_rime(dt: float) -> void:
	if rime.is_empty():
		return
	var xd := x_def()
	if h.out or h.downed:
		_rime_clear()
		return
	rime["t"] = float(rime["t"]) + dt
	var t := float(rime["t"])
	var hold := float(xd["hold"])
	_rime_hold_body()
	var at: Vector3 = rime["at"]
	var radius := float(xd["radius"])
	_rime_slow(at, radius, dt)
	_rime_look(at, radius, t / hold, dt)
	if anim_id == "" or (anim_id != "tm_rime_hold" and m.time - anim_at >= KMovesCare.length(anim_id)):
		play("tm_rime_hold")
	if t >= hold:
		_rime_crash(1.0)


## Foes in the rink are Chilled and slowed more the longer they stay (a stacking slow up to slow_max).
func _rime_slow(at: Vector3, radius: float, dt: float) -> void:
	var xd := x_def()
	var slow: Dictionary = rime["slow"]
	for f in foes_in(at, radius):
		var key: int = f.get_instance_id()
		slow[key] = float(slow.get(key, 0.0)) + dt
		var k := minf(float(xd["slow_max"]), float(xd["slow_base"]) + float(xd["slow_per_s"]) * float(slow[key]))
		f.slow_k = maxf(f.slow_k if f.slow_t > 0.0 else 0.0, k)
		f.slow_t = maxf(f.slow_t, 0.2)
		add_chill(f)


func rime_slow_of(f: Ent) -> float:
	if rime.is_empty():
		return 0.0
	return float((rime["slow"] as Dictionary).get(f.get_instance_id(), 0.0))


## The rink (snaps out in snap_t, its cracks brighter as it builds), the countdown fill everyone sees,
## her frost bud and the creaks.
func _rime_look(at: Vector3, radius: float, k: float, dt: float) -> void:
	var xd := x_def()
	var snap := clampf(float(rime["t"]) / float(xd["snap_t"]), 0.0, 1.0)
	ulk().keep("rink", "rink", at, {"r": radius * lerpf(0.25, 1.0, snap), "crack": k})
	ulk().keep("bud", "frostbud", h.pos, {"k": clampf(float(rime["t"]) / 0.15, 0.0, 1.0)})
	AimKit.circle(h, "x", {"at": at, "r": radius, "fill": k, "all": true, "col": col_of(xd), "hot": k})
	rime["creak"] = float(rime["creak"]) - dt
	if float(rime["creak"]) <= 0.0:
		rime["creak"] = lerpf(0.8, 0.35, k)
		m.sfx("rime_creak", at, -8.0, 0.9 + 0.3 * k)
		var a := randf() * TAU
		m.fx.burst(
				at + Vector3(cos(a) * radius * 0.6, 0.1, sin(a) * radius * 0.6), Color("e8ffff"), 5, 2.0, 0.3, 4.0,
				0.7)


## The crash: a light pillar comes down on her, the shell bursts into shards, and every foe in the rink
## she can see takes the damage and an ice-block stun (k < 1: an early crack).
func _rime_crash(k: float) -> void:
	var xd := x_def()
	var at: Vector3 = rime["at"]
	var radius := float(xd["radius"])
	var stun := float(xd["stun"]) * k
	var stunned := 0
	for f in foes_in(at, radius):
		if not m.world.los(at, f.pos, at.y + 0.95):
			continue
		f.hurt(float(xd["dmg"]) * power("ult") * k, h, {"src": "abil", "ab": "ult", "stun": stun, "dr": true,
			"payoff": true, "tags": ["ult", "rimelock"]})
		add_chill(f)
		ulk().burst("block", f.pos, {"ent": f, "dur": maxf(0.3, stun)})
		stunned += 1
		HeroUlt.landed(self, f)      # the cast's best event (hit, knock, kill) pays the bond once
	last_stunned = stunned
	stats["crashes"] += 1
	ulk().burst("pillar", h.pos, {"r": 1.4, "dur": 0.5})
	ulk().burst("spikes", h.pos, {"r": 3.6, "dur": 0.55})
	ulk().burst("flare", at, {"col": Color("9fe0ff"), "rim": Color("bff7ef"), "r": radius, "dur": 0.35, "pattern": 4.0})
	m.fx.spark(h.pos + Vector3(0, 1.0, 0), Vector3.UP, Color("dffcff"), 26, 9.0, 180.0, 0.4, 8.0, 1.2)
	m.sfx("rime_crash", at, 1.0, 1.0)
	CareUtil.payoff(m, h, h.pos, "", col_of(xd), "")      # the words go on the frozen foes; hers is the bond's
	play("tm_rime_crash")
	_rime_clear()


func _rime_cancel() -> void:
	stats["cancels"] += 1
	ulk().burst("spikes", h.pos, {"r": 1.6, "dur": 0.35})
	m.sfx("rime_crack", h.pos, -3.0, 1.0)
	play("tm_rime_break")
	_rime_clear()


func _rime_clear() -> void:
	rime = {}
	h.inv_t = minf(h.inv_t, 0.05)
	h.root_t = 0.0
	AimKit.hide(h, "x")
	if ult_look != null:
		ult_look.drop("rink")
		ult_look.drop("bud")
		if anim_id == "tm_rime_hold":
			anim_id = ""


# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	var x_ready := HeroUlt.unlocked(self) and float(cd["x"]) <= 0.0
	if rime.is_empty() and x_ready and los and dist < float(x_def()["radius"]) * 0.6 and tgt is Hunter:
		use_x()          # sealed in with a rival close: it cracks open on them
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 12.0 and dist > 3.0 and tgt is Hunter:
		h.inp["aim"] = tgt.pos + Vector3(tgt.vel.x, 0, tgt.vel.z) * 0.6 + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
	if int(h.slot_lv["kin"]) > 0 and not wall.is_empty() and bool(wall["sliding"]) and float(wall["t"]) > 1.2:
		h.inp["sig"] = true          # freeze it where it stands
	elif (int(h.slot_lv["kin"]) > 0
			and float(cd["e"]) <= 0.0
			and dist < 9.0
			and los
			and (h.hp < h.max_hp * 0.8 or randf() < 0.1)):
		h.inp["aim"] = tgt.pos
		h.inp["sig"] = true
	# skate in to the darts' range, or away when hurt
	if rinkrun.is_empty() and h.dashes >= 1.0 and h.grounded and randf() < 0.25:
		if h.hp < h.max_hp * 0.4:
			h.inp["move"] = -h.dir_to(tgt)
		elif dist > 8.0:
			h.inp["move"] = h.dir_to(tgt)
		else:
			return
		h.inp["dash"] = true
		bot_hold["dash"] = 0.8
