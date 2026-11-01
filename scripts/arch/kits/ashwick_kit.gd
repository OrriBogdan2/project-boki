class_name AshwickKit
extends ArchKit
## Ashwick (heavy). Gameplay follows the "everything builds toward a burn" brief
## (docs/heroes/ashwick.md); names, art, sounds and text are ours.
##
## - Passive, Flashover: every hit builds Char on a foe (31 = they Flash over: 3s of burning for a
##   share of their health). Stoking a foe that already burns upgrades the burn (level 2 is fiercer).
##   Char falls off all at once after 5s. A knock heals, and resets the Furnace Cloak.
## - LMB, Torch Lance: hold for a cone of fire (walls stop it) that builds Char fast.
## - RMB, Cinder Shot: a bolt that Flashes the foe over; on a burning foe it upgrades and spreads.
## - Dash, Spark Leap: a leap through the foe, half a Flashover of Char; rank 3 stokes at once and
##   leaves a short fire trail (never over the abyss).
## - E, Furnace Cloak: scorch, Char, Anti-Heal, drag foes in (walls block), shield for what it hit.

var chars := {}                 # foe id -> {e, n, t}
var ignites := {}               # foe id -> {e, lvl, until}
var drags: Array = []           # foes being dragged in by the cloak: {e, left}
var trail: Array = []           # fire-trail points: {p, until}
var flame_acc := 0.0
var spool := 0.0                # how long the lance has been held
var after_t := 0.0              # the slow after letting go
var was_held := false
var trail_acc := 0.0
var ember_t := 0.0
var ignitions := 0              # (tests)
var upgrades := 0
var spreads := 0
var resets := 0
var cloaks := 0
var refunds := 0
var trail_hits := 0
var pulled := 0
var _face_hits := 0

func rd() -> Dictionary: return res_def()
func lmbd() -> Dictionary: return d.get("lmb", {})
func res_text() -> String: return "%d" % int(_best_char())
func res_frac() -> float: return clampf(_best_char() / res_max(), 0.0, 1.0)
func ready_label() -> String: return "FLASHOVER" if not ignites.is_empty() else ""

func _best_char() -> float:
	var b := 0.0
	for k in chars:
		b = maxf(b, float(chars[k]["n"]))
	return b

# ------------------------------------------------------------------ Char and Flashover
func char_of(f: Ent) -> float:
	var e: Dictionary = chars.get(f.get_instance_id(), {})
	return float(e.get("n", 0.0))

func burning(f: Ent) -> int:
	var e: Dictionary = ignites.get(f.get_instance_id(), {})
	return int(e.get("lvl", 0)) if not e.is_empty() and float(e["until"]) > m.time else 0

## Adds Char; at the top the foe Flashes over (or the burn upgrades). True if that stoked the burn.
func add_char(f: Ent, amt: float) -> bool:
	if f == null or not is_instance_valid(f) or f.dead or f.team == h.team:
		return false
	var key := f.get_instance_id()
	var e: Dictionary = chars.get(key, {"e": f, "n": 0.0, "t": 0.0})
	e["n"] = float(e["n"]) + amt
	e["t"] = m.time
	chars[key] = e
	if float(e["n"]) >= float(rd()["ignite_at"]):
		e["n"] = 0.0          # extra Char past the top is discarded
		stoke(f)
		return true
	return false

## Apply or upgrade the burn on a foe (level 1, then 2).
func stoke(f: Ent) -> int:
	var cur := burning(f)
	var lvl := mini(2, cur + 1)
	if cur == 0: ignitions += 1
	elif lvl > cur: upgrades += 1
	_ignite(f, lvl, cur)
	return lvl

func _ignite(f: Ent, lvl: int, was: int) -> void:
	var key := f.get_instance_id()
	ignites[key] = {"e": f, "lvl": lvl, "until": m.time + float(rd()["ignite_t"])}
	var dps := float(rd()["dps%d" % lvl]) * f.max_hp * power("sec")
	if f.remote:
		f.hurt(0.01, h, {"src": "flame", "burn": dps, "burn_for": float(rd()["ignite_t"])})
	else:
		f.burn_t = maxf(f.burn_t, float(rd()["ignite_t"])); f.burn_dps = dps; f.burn_by = h
	var col := res_col()
	if lvl == 2 and was < 2:
		payoff_fx(f.pos, "FLASHOVER", Color("ffe0a0"), "as_ignite", h.aim_dir(), f)
	elif was == 0:
		m.fx.word(f.pos + Vector3(0, 2.3, 0), "ABLAZE", col, false)
		m.fx.burst(f.pos + Vector3(0, 1.0, 0), col, 22, 4.0, 0.5, -3.0, 1.3)
		m.sfx("as_ignite", f.pos, -3.0, 1.0)
		net_ring(f.pos, 1.2, col)

func _refund(slot: String) -> void:
	if rank("sec" if slot == "rmb" else "kin") < 3:
		return
	var sd: Dictionary = rmb_def() if slot == "rmb" else e_def()
	cd[slot] = float(cd[slot]) * (1.0 - float(sd.get("refund", 0.25)))
	refunds += 1

func on_knock(t: Hunter, mine: bool) -> void:
	if not mine or not is_instance_valid(t):
		return
	h.heal(h.max_hp * float(rd()["heal_knock"]))
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), Color("7fe08a"), 14, 2.5, 0.5, -2.0)
	if float(cd["e"]) > 0.0:
		cd["e"] = 0.0
		resets += 1
		m.fx.word(h.pos + Vector3(0, 2.8, 0), "CLOAK READY", col_of(e_def()), true)
		m.fx.ring(h.pos, 2.0, col_of(e_def()), 0.35)
		m.sfx("ab_ready", h.pos, -2.0, 0.8)
		if h.is_local(): h._ab_feedback("k1", "ready")
		net_ring(h.pos, 2.0, col_of(e_def()))

# ------------------------------------------------------------------ tick
func _tick(dt: float) -> void:
	if after_t > 0.0: after_t -= dt
	for key in chars.keys():
		var e: Dictionary = chars[key]
		if not is_instance_valid(e["e"]) or (e["e"] as Ent).dead or m.time - float(e["t"]) > float(rd()["expire"]):
			chars.erase(key)
	for key in ignites.keys():
		var e: Dictionary = ignites[key]
		if not is_instance_valid(e["e"]) or (e["e"] as Ent).dead or float(e["until"]) <= m.time:
			ignites.erase(key)
	ember_t -= dt
	if ember_t <= 0.0:
		ember_t = 0.35
		for key in chars:
			var e: Dictionary = chars[key]
			if float(e["n"]) >= 15.0 and tells_visible():
				m.fx.burst((e["e"] as Ent).pos + Vector3(0, 1.7, 0), Color("ff9a3a"), 2, 1.0, 0.6, -2.0, 0.8)
	if not drags.is_empty(): _tick_drags(dt)
	if not trail.is_empty(): _tick_trail(dt)
	tell = "full" if _best_char() >= 22.0 else ("half" if _best_char() >= 12.0 else "")
	net_pulse(dt, not ignites.is_empty(), 1.3)

func move_k() -> float:
	if was_held and flame_acc >= 0.0 and h.wid == "flamethrower": return 0.8
	return 0.6 if after_t > 0.0 else 1.0

# ------------------------------------------------------------------ LMB: Torch Lance
func lmb_override(held: bool, dt: float) -> bool:
	if h.wid != "flamethrower":
		return false
	if not held or not h.can_fire():
		if was_held:
			play("as_lance_end")
			after_t = float(lmbd().get("slow_after", 0.35))
			h.mel_hold = 0.0
		was_held = false
		spool = 0.0
		flame_acc = 0.0
		return true
	if not was_held:
		m.sfx("as_flame", h.pos, -4.0, 0.9)
		play("as_lance")
	was_held = true
	spool += dt
	h.mel_hold = minf(spool, float(lmbd()["spool"]))
	flame_acc += dt
	var tick := float(lmbd()["tick"])
	while flame_acc >= tick:
		flame_acc -= tick
		_flame_tick(tick)
	return true

func _flame_tick(tick: float) -> void:
	var ld := lmbd()
	var dir := h.aim_dir()
	var k := clampf(spool / float(ld["spool"]), 0.35, 1.0)
	var muzzle := h.pos + Vector3(dir.x, 1.05, dir.y) * 0.9
	var col := col_of(d)
	m.fx.burst(muzzle + Vector3(dir.x, 0, dir.y) * 1.5, Color("ffb04a"), 3, 5.0, 0.3, -2.0, 1.1, Vector3(dir.x, 0.15, dir.y), 18.0)
	m.fx.burst(muzzle + Vector3(dir.x, 0, dir.y) * 3.2, Color("ff6a2a"), 2, 4.0, 0.3, -2.0, 1.4, Vector3(dir.x, 0.2, dir.y), 24.0)
	if int(m.time * 10.0) % 4 == 0:
		m.sfx("as_flame", h.pos, -9.0, 1.0 + randf() * 0.1)
	var half := deg_to_rad(float(ld["cone_deg"]) * 0.5)
	for f in m.foes_of(h.team):
		if not f.hittable() or absf(f.pos.y - h.pos.y) > 2.2:
			continue
		var to := Vector2(f.pos.x - h.pos.x, f.pos.z - h.pos.z)
		var dist := to.length()
		if dist > float(ld["range"]) + f.r or (dist > 0.3 and absf(dir.angle_to(to.normalized())) > half + atan2(f.r, maxf(dist, 0.4))):
			continue
		if not sees(f):
			continue
		var dmg := float(ld["dps"]) * tick * k
		f.hurt(dmg, h, {"src": "flame", "ab": "primary", "tags": ["flame"], "melee": false})
		var n := float(ld["char_burning"] if burning(f) > 0 else ld["char_tick"]) * k
		add_char(f, n)

# ------------------------------------------------------------------ RMB: Cinder Shot
func fire_rmb(c: Dictionary) -> void:
	c["variant"] = "tap"
	last_variant = "tap"
	if not spend_rmb():
		return
	var rdf := rmb_def()
	play("as_shot")
	var amt := float(rdf["dmg"]) * (1.6 if rank("sec") >= 3 else 1.0)
	var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": float(rdf["speed"]), "range": float(rdf["range"]), "size": float(rdf["size"])},
		"effects": [{"type": "damage", "amount": amt}]})
	run(stg, cx("rmb", "cinder_shot", aim(), {"on_foe": func(f: Ent, _c: Dictionary): _cinder_hit(f)}))
	m.fx.burst(h.pos + Vector3(h.aim_dir().x, 1.1, h.aim_dir().y) * 0.9, Color("ffb04a"), 10, 4.0, 0.3, -2.0, 1.2)
	m.sfx("as_flame", h.pos, -2.0, 1.4)

func _cinder_hit(f: Ent) -> void:
	if not is_instance_valid(f) or f.dead or f.team == h.team:
		return
	var rdf := rmb_def()
	var cur := burning(f)
	var stoked := false
	if cur > 0:
		# a burning foe: upgrade, and the burn the foe had spreads to the ones around
		spreads += 1
		var around := foes_in(f.pos, float(rdf["spread_r"]))
		stoke(f)
		for o in around:
			if o != f and is_instance_valid(o) and not o.dead and sees_from(f.pos, o):
				_ignite(o, cur, burning(o))
		stoked = true
		m.fx.ring(f.pos, float(rdf["spread_r"]), col_of(rdf), 0.35)
		m.fx.word(f.pos + Vector3(0, 2.5, 0), "SPREAD", col_of(rdf), true)
	else:
		stoke(f)
		stoked = true
	if stoked: _refund("rmb")

func sees_from(p: Vector3, o: Ent) -> bool:
	return m.world.los(p, o.pos, p.y + 0.95)

# ------------------------------------------------------------------ dash: Spark Leap
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	var dir := h.aim_dir()
	if use_ex and not h.grounded:
		if not spend_dash(true): return true
		travel(float(h.cdat.get("ex_dist", 4.2)), float(h.cdat.get("ex_time", 0.21)), {"invuln": 0.08, "trail": "dust", "dir": dir}, true)
		play("as_leap")
		return true
	if not spend_dash(false):
		return true
	var start := h.pos
	var pk := power("dash") / maxf(0.01, m.dmg_mult(h))
	var t := float(dd["time"])
	travel(float(dd["dist"]), t, {"invuln": 0.06, "shove": true, "shove_kb": float(dd["kb"]), "shove_dmg": float(dd["dmg"]) * pk, "trail": "dust", "dir": dir})
	st["last_dash"] = "spark_leap"
	play("as_leap")
	h.glide_cd = maxf(h.glide_cd, t + 0.35)
	m.sfx("ab_whirr", h.pos, -4.0, 0.8)
	m.later(t * 0.6, func(): if is_instance_valid(h) and not h.downed: _leap_char(start, dir))
	if rank("dash") >= 3:
		m.later(t + 0.05, func(): if is_instance_valid(h): _lay_trail(start))
	return true

func _leap_char(start: Vector3, dir: Vector2) -> void:
	var dd := dash_def()
	var end := Vector2(start.x, start.z) + dir * float(dd["dist"])
	for f in m.foes_of(h.team):
		if not f.hittable() or absf(f.pos.y - h.pos.y) > 2.2:
			continue
		var fp := Vector2(f.pos.x, f.pos.z)
		if fp.distance_to(Geometry2D.get_closest_point_to_segment(fp, Vector2(start.x, start.z), end)) < 1.1 + f.r:
			var stoked := add_char(f, float(dd["char"]))
			if rank("dash") >= 3:
				stoke(f)
				stoked = true
			m.fx.burst(f.pos + Vector3(0, 1.0, 0), Color("ffc060"), 12, 4.0, 0.4)

func _lay_trail(start: Vector3) -> void:
	var dd := dash_def()
	var a := Vector2(start.x, start.z); var b := Vector2(h.pos.x, h.pos.z)
	var n := maxi(1, int(ceil(a.distance_to(b) / 0.9)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(n))
		var g: float = m.world.ground_at(p.x, p.y)
		if g <= World.VOID + 1.0:
			continue           # fire never forms over the abyss
		trail.append({"p": Vector3(p.x, g, p.y), "until": m.time + float(dd["trail_t"])})
	while trail.size() > 12: trail.pop_front()

func _tick_trail(dt: float) -> void:
	trail = trail.filter(func(t): return float(t["until"]) > m.time)
	trail_acc += dt
	if trail_acc < 0.3:
		return
	trail_acc = 0.0
	var dd := dash_def()
	for t in trail:
		m.fx.burst((t["p"] as Vector3) + Vector3(0, 0.3, 0), Color("ff8a3a"), 2, 1.5, 0.4, -3.0, 1.2)
	for f in m.foes_of(h.team):
		if not f.hittable():
			continue
		for t in trail:
			if Vector2(f.pos.x - t["p"].x, f.pos.z - t["p"].z).length() < 1.0 + f.r and absf(f.pos.y - t["p"].y) < 1.6:
				f.hurt(float(dd["trail_dps"]) * 0.3, h, {"src": "flame", "ab": "dodge", "tags": ["flame"], "slow": 0.25, "slow_for": 0.5})
				add_char(f, 4.0)
				trail_hits += 1
				break

# ------------------------------------------------------------------ E: Furnace Cloak
func cast_e() -> bool:
	var ed := e_def()
	cloaks += 1
	play("as_cloak")
	var col := col_of(ed)
	var hit := 0
	var stoked := false
	var k := 1.5 if rank("kin") >= 3 else 1.0
	m.fx.ring(h.pos, float(ed["radius"]), col, 0.4)
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), col, 30, 6.0, 0.5, -2.0, 1.4)
	m.sfx("as_cloak", h.pos, -1.0, 1.0)
	Feel.shake(m, "t2", h, h.pos)
	for f in foes_in(h.pos, float(ed["radius"])):
		if not sees(f):
			continue
		hit += 1
		f.hurt(float(ed["dmg"]) * power("kin") * k, h, {"src": "flame", "ab": "k1", "tags": ["flame", "cloak"]})
		if add_char(f, float(ed["char"])): stoked = true
		KitStatus.apply(f, "blt", float(ed["blt_t"]))
		if f.mass() < 6.0 and not f.remote:
			drags.append({"e": f, "left": 0.45})
			pulled += 1
	if hit > 0:
		h.shield = maxf(h.shield, h.max_hp * (float(ed["shield_base"]) + float(ed["shield_each"]) * hit) * k)
		h.shield_t = float(ed["shield_t"])
		m.fx.ring(h.pos, 1.2, Color("ffd890"), 0.5)
		m.sfx("shield", h.pos, -3.0, 0.9)
	if stoked: _refund("e")
	net_ring(h.pos, float(ed["radius"]), col)
	return true

func _tick_drags(dt: float) -> void:
	var ed := e_def()
	for dg in drags.duplicate():
		var fe = dg["e"]
		dg["left"] = float(dg["left"]) - dt
		if not is_instance_valid(fe) or (fe as Ent).dead or float(dg["left"]) <= 0.0:
			drags.erase(dg); continue
		var e := fe as Ent
		var to := Vector2(h.pos.x - e.pos.x, h.pos.z - e.pos.z)
		var dist := to.length()
		if dist <= float(ed["gap"]):
			drags.erase(dg); continue
		var step := minf(float(ed["pull_speed"]) * dt, dist - float(ed["gap"]))
		var dir := to / dist
		var nx := e.pos.x + dir.x * step; var nz := e.pos.z + dir.y * step
		var bx: float = m.world.occupy(nx, e.pos.z, e.r, e.pos.y, false)
		var bz: float = m.world.occupy(e.pos.x, nz, e.r, e.pos.y, false)
		if bx == 0.0: e.pos.x = nx
		if bz == 0.0: e.pos.z = nz
		if bx != 0.0 and bz != 0.0: drags.erase(dg)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	var te := tgt as Ent
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and los and dist < float(e_def()["radius"]) - 0.5:
		h.inp["aim"] = tgt.pos; h.inp["sig"] = true; return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < float(rmb_def()["range"]) - 1.0 and dist > 3.0 and (burning(te) > 0 or randf() < 0.5):
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0); h.inp["sec"] = true; return
	if int(h.slot_lv["dash"]) > 0 and h.dashes >= 1.0 and los and dist > 3.5 and dist < 6.0 and randf() < 0.2:
		h.inp["aim"] = tgt.pos
		h.ai["dash_dir"] = h.dir_to(tgt)
		h.inp["move"] = h.dir_to(tgt)
		h.inp["dash"] = true
