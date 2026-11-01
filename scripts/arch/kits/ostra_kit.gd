class_name OstraKit
extends ArchKit
## Ostra (medium): Swell, Tether Lantern (a Settled orb after a pause), Swap, Rift Snap, Brimseed.
## docs/heroes/ostra.md. The loop: hits (ten times as much on hunters) fill Swell; Swollen, the seed
## grows bigger and quicker, Swap lands sooner and Snap hits harder. Plant the seed, Snap to stun,
## Swap to put the foe in it, pop it for the Collapse.
##
## The seed is a ground zone placed through HeroZones (legal ground, short of walls, never in the
## abyss) and synced over Net as ["zone", "seed" | "pop", ...].

const PAY := "COLLAPSE"
const TEAL := Color("7fe0d0")

var swollen_t := 0.0
var last_shot_t := -99.0
var shot_seen := 0
var primed := false
var base_wpn: Dictionary = {}
var prime_until := -9.0
var seed: Dictionary = {}      # {pos, t, grow, rmax, sid, tele, burn}
var sid_n := 0
var swap: Dictionary = {}      # {t, land, from}
# counters for the checks
var swells := 0
var settled_shots := 0
var swaps := 0
var swapped_foes := 0
var snaps := 0
var pops := 0
var collapses := 0
var seed_denied := 0

func lmb_def() -> Dictionary: return d.get("lmb", {})
func is_swollen() -> bool: return swollen_t > 0.0

func res_text() -> String: return "SWOLLEN" if is_swollen() else "%d" % int(res)
func ready_label() -> String: return "SWOLLEN" if is_swollen() else ""
func e_recastable() -> bool: return not seed.is_empty()

# ------------------------------------------------------------------ passive
func add_swell(v: float) -> void:
	if is_swollen() or v <= 0.0:
		return
	res = minf(res_max(), res + v)
	touch_res(float(res_def()["wait"]))
	if res >= res_max():
		swollen_t = float(res_def()["swollen_t"])
		swells += 1
		armed_fx("SWOLLEN", "")
		m.sfx("ab_ready", h.pos, -3.0, 0.8)

func on_deal(t: Ent, dmg: float, _o: Dictionary) -> void:
	if t == null or t.team == h.team:
		return
	var rd := res_def()
	add_swell(dmg * float(rd["per_dmg"]) * (float(rd["hunter_k"]) if t is Hunter else 1.0))

func on_knock(_t: Hunter, mine: bool) -> void:
	if mine and not h.downed:
		h.heal(h.max_hp * 0.2)
		m.fx.word(h.pos + Vector3(0, 2.2, 0), "+20%", TEAL, false)

func outgoing(t: Ent, dmg: float, o: Dictionary) -> float:
	# a Settled orb slows what it hits
	if m.time < prime_until and String(o.get("src", "")) == "shot" and not o.has("ab") and t != null and t.team != h.team:
		prime_until = -9.0
		o["slow"] = float(lmb_def()["prime_slow_t"])
		o["slow_k"] = float(lmb_def()["prime_slow"])
	return dmg

# ------------------------------------------------------------------ per step
func _tick(dt: float) -> void:
	if is_swollen():
		swollen_t = maxf(0.0, swollen_t - dt)
		res = res_max() * swollen_t / float(res_def()["swollen_t"])
		if swollen_t <= 0.0: res = 0.0
	elif res_wait <= 0.0:
		add_res(-float(res_def()["drain"]) * dt)
	tell = "full" if is_swollen() else ("half" if res > 30.0 else "")
	net_pulse(dt, is_swollen())
	_tick_weapon()
	if not swap.is_empty():
		_tick_swap(dt)
	if not seed.is_empty():
		_tick_seed(dt)

## The Settled orb: after a pause the next shot is harder and faster.
func _tick_weapon() -> void:
	if h.wid != "tether_lantern":
		return
	if h.shot_n != shot_seen:
		shot_seen = h.shot_n
		last_shot_t = m.time
		if primed:
			primed = false
			settled_shots += 1
			prime_until = m.time + 1.2
			if not base_wpn.is_empty(): h.wpn = base_wpn
			m.fx.ring(h.pos, 1.0, TEAL, 0.2)
	if not primed and m.time - last_shot_t >= float(lmb_def()["idle"]) and not h.downed:
		primed = true
		base_wpn = h.wpn
		var w := h.wpn.duplicate()
		w["dmg"] = float(w["dmg"]) * (1.0 + float(lmb_def()["prime_dmg"]))
		w["speed"] = float(w["speed"]) * float(lmb_def()["prime_speed"])
		w["color"] = Color("e8fffa")
		h.wpn = w

# ------------------------------------------------------------------ dash: Swap
func swap_time() -> float:
	var dd := dash_def()
	return float(dd["time_swollen"]) if is_swollen() else float(dd["time"])

func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if use_ex:
		if not spend_dash(true): return true
		travel(float(h.cdat.get("ex_dist", 4.6)), float(h.cdat.get("ex_time", 0.2)), {"invuln": 0.1}, true)
		return true
	if not swap.is_empty():
		return true
	var pw := HeroZones.walk(m, h.pos, aim(), float(dd["reach"]))
	if not pw["ok"]:
		h._ab_feedback("dash", "deny")
		return true
	if not spend_dash(false):
		return true
	var land: Vector3 = pw["pos"]
	swap = {"t": swap_time(), "T": swap_time(), "land": land, "from": h.pos}
	play("ostra_dash")
	var tele := tele_circle(land, float(dd["radius"]), Color("b8f5ea"), swap_time())
	swap["tele"] = tele
	var lantern := MeshInstance3D.new()
	lantern.mesh = Models.sphere(0.22, 10)
	lantern.material_override = Models.glow_mat(Color("e8fffa", 1.0))
	lantern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(lantern)
	lantern.global_position = h.pos + Vector3(0, 1.2, 0)
	swap["node"] = lantern
	m.sfx("ab_throw", h.pos, -3.0, 1.4)
	net_bolt(h.pos + Vector3(0, 1.2, 0), land + Vector3(0, 0.6, 0), Color("b8f5ea"))
	return true

func _tick_swap(dt: float) -> void:
	swap["t"] = float(swap["t"]) - dt
	var land: Vector3 = swap["land"]
	var u := 1.0 - clampf(float(swap["t"]) / float(swap["T"]), 0.0, 1.0)
	var ln: MeshInstance3D = swap.get("node")
	if ln and is_instance_valid(ln):
		var from: Vector3 = swap["from"]
		ln.global_position = from.lerp(land, u) + Vector3(0, 1.2 + sin(u * PI) * 2.2, 0)
	if h.downed or h.out or h.stun_t > 0.0:
		_swap_end(false)
		return
	if float(swap["t"]) <= 0.0:
		_swap_end(true)

func _swap_end(go: bool) -> void:
	var dd := dash_def()
	var land: Vector3 = swap.get("land", h.pos)
	var from: Vector3 = swap.get("from", h.pos)
	var ln: MeshInstance3D = swap.get("node")
	var tele: Node3D = swap.get("tele")
	if tele and is_instance_valid(tele): m.fx.end_telegraph(tele)
	if ln and is_instance_valid(ln): ln.queue_free()
	swap = {}
	if not go:
		return
	swaps += 1
	var here := h.pos
	m.fx.ring(here, 1.4, Color("b8f5ea"), 0.3)
	m.fx.burst(here + Vector3(0, 1.0, 0), TEAL, 16, 4.0, 0.4, -2.0, 1.0)
	for f in foes_in(land, float(dd["radius"])):
		swapped_foes += 1
		if not f.remote:
			f.teleport(Vector3(from.x, m.world.ground_at(from.x, from.z), from.z))
		KitStatus.apply(f, "dsr", float(dd["slow_t"]), float(dd["slow"]))
	h.teleport(Vector3(land.x, m.world.ground_at(land.x, land.z), land.z))
	h.vel.y = 0.0
	m.fx.ring(land, 1.6, Color("e8fffa"), 0.3)
	m.fx.flash(land + Vector3(0, 1.0, 0), TEAL, 1.2, 0.08)
	m.sfx("swap", land, -2.0, 1.2)
	net_ring(land, 1.6, TEAL)
	if rank("dash") >= 3:
		for o in m.hunters:
			if o != h and o.team == h.team and not o.downed and o.flat_dist(h) < float(dd["ally_r"]):
				o.shield = maxf(o.shield, float(dd["ally_shield"]))
				o.shield_t = 3.0

# ------------------------------------------------------------------ RMB: Rift Snap
func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if not spend_rmb(): return
	var sn: Dictionary = rmb_def()["snap"]
	snaps += 1
	play("ostra_rmb")
	var k := power("sec") * (1.0 + float(sn["swollen_k"]) if is_swollen() else 1.0)
	var base := h.aim_dir()
	var a0 := atan2(base.y, base.x)
	var fan := deg_to_rad(float(sn["fan_deg"]))
	var start := Vector3(h.pos.x + base.x * 0.6, h.pos.y + 0.95 * float(h.cdat["scale"]), h.pos.z + base.y * 0.6)
	var spd := float(sn["speed"])
	for i in [-1, 0, 1]:
		var a := a0 + fan * float(i)
		var dv := Vector2(cos(a), sin(a))
		var center: bool = i == 0
		var dmg := (float(sn["dmg"]) if center else float(sn["side_dmg"])) * k
		m.spawn_shot(h, start, dv * spd, dmg, float(sn["range"]) / spd, 0.3 if center else 0.2, Color("9be8dc"), {"kb": 1.0, "tracer": 1.0, "kx": func(s, at, e, _why): _snap_hit(s, at, e, center)})
	m.sfx("zap", h.pos, -2.0, 1.6)
	m.sfx("rail", h.pos, -6.0, 1.7)
	m.fx.flash(start, Color("9be8dc"), 0.9, 0.07)

func _snap_hit(s: Dictionary, at: Vector3, e: Ent, center: bool) -> void:
	if not center or e == null:
		return
	var sn: Dictionary = rmb_def()["snap"]
	var st: Vector3 = s["start"]
	var kd := clampf(Vector2(at.x - st.x, at.z - st.z).length() / float(sn["range"]), 0.0, 1.0)
	s["x"]["stun"] = lerpf(float(sn["stun"][0]), float(sn["stun"][1]), kd)
	s["x"]["dr"] = true

# ------------------------------------------------------------------ E: Brimseed
func cast_e() -> bool:
	var ed := e_def()
	var pw := HeroZones.walk(m, h.pos, aim(), float(ed["reach"]))
	var p: Vector3 = pw["pos"]
	if not pw["ok"] or not HeroZones.fits(m, p, h.pos.y, false):
		seed_denied += 1
		if h.is_local() and m.hud: m.hud.toast_small("No ground to plant on", col_of(ed))
		return false
	sid_n += 1
	var sid := "%s.s%d" % [h.nid if h.nid != "" else str(h.get_instance_id()), sid_n]
	var grow := float(ed["grow"]) * (0.75 if is_swollen() else 1.0)
	var rmax := float(ed["rmax_swollen"]) if is_swollen() else float(ed["rmax"])
	var tele := tele_circle(p, rmax, TEAL, grow)
	var vis := HeroZones.seed_visual(m, sid, p, rmax, grow, TEAL)
	seed = {"pos": p, "t": 0.0, "grow": grow, "rmax": rmax, "sid": sid, "tele": tele, "vis": vis, "burn": 0.0}
	e_t = grow + 1.0
	play("ostra_e")
	m.sfx("plant", p, -2.0, 0.8)
	m.sfx("ab_plant", p, -4.0, 1.3)
	if (m.net_on or HeroZones.capture) and not h.remote:
		HeroZones.tx(m, ["zone", "seed", h.nid, sid, m._r(p.x), m._r(p.y), m._r(p.z), snappedf(rmax, 0.1), snappedf(grow, 0.1)])
	return true

func seed_radius() -> float:
	if seed.is_empty(): return 0.0
	return float(seed["rmax"]) * clampf(float(seed["t"]) / float(seed["grow"]), 0.08, 1.0)

func _tick_seed(dt: float) -> void:
	seed["t"] = float(seed["t"]) + dt
	if rank("kin") >= 3:
		seed["burn"] = float(seed["burn"]) - dt
		if float(seed["burn"]) <= 0.0:
			seed["burn"] = 0.5
			for f in foes_in(seed["pos"], seed_radius()):
				f.hurt(2.5 * power("kin"), h, {"src": "abil", "ab": "e"})
	if h.downed:
		_pop(false)

func _e_end() -> void:
	if not seed.is_empty():
		_pop(true)

func e_recast() -> bool:
	if seed.is_empty():
		return false
	_pop(true)
	e_t = 0.0
	return true

func _pop(hit: bool) -> void:
	var ed := e_def()
	var p: Vector3 = seed["pos"]
	var k := clampf(float(seed["t"]) / float(seed["grow"]), 0.0, 1.0)
	var rad := seed_radius()
	var tele: Node3D = seed.get("tele")
	if tele and is_instance_valid(tele): m.fx.end_telegraph(tele)
	var sid := String(seed["sid"])
	var vis: Node3D = seed.get("vis")
	if vis and is_instance_valid(vis): vis.queue_free()
	seed = {}
	e_t = 0.0
	HeroZones.seed_pop(m, sid, TEAL)
	if (m.net_on or HeroZones.capture) and not h.remote:
		HeroZones.tx(m, ["zone", "pop", sid])
	if not hit:
		return
	pops += 1
	var mult := 1.0 + (float(ed["dmg_max_k"]) - 0.5) * k
	var dmg := float(ed["dmg"]) * mult * power("kin")
	m.fx.ring(p, rad, TEAL, 0.35)
	m.fx.ring(p, rad * 0.5, Color("e8fffa"), 0.2)
	m.fx.burst(p + Vector3(0, 0.8, 0), TEAL, int(14 + 22 * k), 6.0, 0.6, -4.0, 1.2)
	m.fx.flash(p + Vector3(0, 0.8, 0), Color("e8fffa"), 1.0 + k, 0.1)
	m.sfx("boom", p, -5.0, 0.8)
	m.sfx("ab_blast", p, -3.0, 0.7)
	Feel.shake(m, "t3" if k > 0.6 else "t2", h, p)
	net_ring(p, rad, TEAL)
	var catch_r := rad * (1.3 if rank("kin") >= 3 else 1.0)
	var caught_hunter: Ent = null
	for f in foes_in(p, catch_r):
		if rank("kin") >= 3 and not f.remote and Vector2(f.pos.x - p.x, f.pos.z - p.z).length() > rad * 0.3:
			f.teleport(Vector3(p.x, m.world.ground_at(p.x, p.z), p.z))
		f.hurt(dmg, h, {"src": "abil", "ab": "e", "payoff": k >= 0.99 and f is Hunter})
		KitStatus.apply(f, "gnd", float(ed["ground"]))
		if f is Hunter: caught_hunter = f
	if caught_hunter != null and k >= 0.99:
		collapses += 1
		payoff_fx(caught_hunter.pos, PAY, TEAL, "pay_collapse", h.dir_to(caught_hunter), caught_hunter)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if not seed.is_empty():
		var inside := Vector2(tgt.pos.x - float(seed["pos"].x), tgt.pos.z - float(seed["pos"].z)).length() < seed_radius()
		if inside or float(seed["t"]) > float(seed["grow"]) * 0.9:
			h.inp["sig"] = true
		return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist < 8.0 and los and randf() < 0.3:
		h.inp["aim"] = tgt.pos
		h.inp["sig"] = true
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 11.0 and randf() < 0.5:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
		return
	if int(h.slot_lv["dash"]) > 0 and h.dashes >= 1.0 and swap.is_empty() and dist > 6.0 and dist < 11.0 and los and randf() < 0.15:
		h.inp["aim"] = tgt.pos
		h.inp["dash"] = true
