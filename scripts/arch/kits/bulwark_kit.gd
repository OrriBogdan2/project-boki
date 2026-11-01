class_name BulwarkKit
extends ArchKit
## Bulwark (heavy): Interpose, Guard, Shield (raise, Bash, Shield Surf, wider in the Banner, Shield
## Slam at 50 Guard), Rally Banner, Bastion. docs/ARCHETYPES.md §6.6.

var wall: Dictionary = {}      # the raised shield (a following verbs wall)
var shield_hp := 160.0
var down_t := 0.0              # seconds since it was lowered (regen after 2s)
var lock_t := 0.0              # broken: locked out
var front_t := 0.0             # Interpose's front guard
var banner := {}               # {pos, t, r, node}
var dome := {}
var leap := {}

func _setup() -> void:
	shield_hp = shield_max()

func shield_max() -> float:
	return float(rmb_def()["shield"]["hp"]) + (60.0 if rank("sec") >= 3 else 0.0)

func full_ready() -> bool:
	return res >= float(res_def().get("slam", 50.0))

func res_text() -> String:
	return "%d" % int(res)

func add_guard(v: float) -> void:
	var was := res
	add_res(v)
	touch_res()
	for step in [33.0, 66.0, 100.0]:
		if was < step and res >= step:
			m.fx.ring(h.pos, 1.0 + step / 100.0, res_col(), 0.25)      # the shield runes light in steps

func on_block(dmg: float, _by) -> void:
	add_guard(dmg * float(res_def().get("per_hp", 0.5)))

func _tick(dt: float) -> void:
	if res_wait <= 0.0:
		add_res(-float(res_def().get("decay", 5.0)) * dt)
	lock_t = maxf(0.0, lock_t - dt)
	front_t = maxf(0.0, front_t - dt)
	var sd: Dictionary = rmb_def()["shield"]
	if not wall.is_empty():
		if not m.verbs.walls.has(wall):
			# broken: locked out for 3s
			wall = {}
			shield_hp = 0.0
			lock_t = float(sd["lock"])
			down_t = 0.0
			m.fx.word(h.pos + Vector3(0, 2.2, 0), "SHIELD BROKEN", Feel.cat_color("damage"), false)
			m.sfx("knock", h.pos, -3.0, 1.4)
		else:
			shield_hp = float(wall["hp"])
			wall["t"] = 99.0
			var wide := float(sd["len"]) + (float(rmb_def()["banner_wide"]) if _in_banner(h.pos) else 0.0)
			if absf(float(wall["len"]) - wide) > 0.05:
				wall["len"] = wide
			if h.gliding:
				h.glide_fuel = maxf(0.0, h.glide_fuel - dt / h.glide_max * (float(rmb_def()["surf_heat"]) - 1.0))
	else:
		down_t += dt
		if down_t >= float(sd["wait"]) and lock_t <= 0.0:
			shield_hp = minf(shield_max(), shield_hp + float(sd["regen"]) * dt)
	if not banner.is_empty():
		_tick_banner(dt)
	if not dome.is_empty():
		dome["t"] = float(dome["t"]) - dt
		if int(m.time * 4.0) != int((m.time - dt) * 4.0):
			for o in m.hunters:
				if o.team == h.team and not o.out and not o.downed and o.flat_dist(dome["pos"]) < float(dome["r"]):
					o.heal(float(r_def()["regen"]) * 0.25)
		if float(dome["t"]) <= 0.0: dome = {}
	if not leap.is_empty():
		leap["t"] = float(leap["t"]) - dt
		if float(leap["t"]) <= 0.0:
			_land_leap()

func move_k() -> float:
	if not wall.is_empty() and h.wid == "tower_shield" and h.grounded:
		return float(rmb_def()["shield"]["slow"])
	return 1.0

## Behind the tower shield you can't swing.
func fire_ok() -> bool:
	return wall.is_empty() or h.wid != "tower_shield"

## The Interpose front guard: shots from the front 140° are blocked (and become Guard).
func incoming(by: Ent, dmg: float, o: Dictionary) -> Array:
	if front_t > 0.0 and by != null and is_instance_valid(by):
		var to := Vector2(by.pos.x - h.pos.x, by.pos.z - h.pos.z)
		var fwd := Vector2(-sin(h.face), -cos(h.face))
		if to.length() > 0.1 and fwd.dot(to.normalized()) > cos(deg_to_rad(float(dash_def().get("arc", 140.0)) * 0.5)):
			on_block(dmg, by)
			m.fx.flash(h.pos + Vector3(to.normalized().x * 0.6, 1.0, to.normalized().y * 0.6), res_col(), 0.4, 0.05)
			o = o.duplicate(); o.erase("kb"); o.erase("lift")
			return [0.0, o]
	return [dmg, o]

func _in_banner(p: Vector3) -> bool:
	return not banner.is_empty() and Vector2(p.x - banner["pos"].x, p.z - banner["pos"].z).length() < float(banner["r"])

func in_e() -> bool:
	return _in_banner(h.pos)

# ------------------------------------------------------------------ RMB: Shield
## In the air the press doesn't fire at once: holding it there is Shield Surf.
func press_rmb() -> void:
	if busy():
		h._ab_feedback("sec", "deny")
		return
	if rmb_down:
		return
	rmb_down = true
	rmb_t = 0.0
	rmb_ctx = {"air": not h.grounded or h.gliding, "e": in_e(), "r": r_t > 0.0, "full": full_ready()}

func rmb_hold_tick(t: float) -> void:
	if t >= float(rmb_def()["hold"]) and wall.is_empty() and lock_t <= 0.0 and shield_hp > 5.0:
		_raise()

func _raise() -> void:
	var sd: Dictionary = rmb_def()["shield"]
	var wide := float(sd["len"]) + (float(rmb_def()["banner_wide"]) if _in_banner(h.pos) else 0.0)
	var d := h.aim_dir()
	wall = m.verbs.add_wall(h, h.pos + Vector3(d.x, 0, d.y) * 1.0, d, {"length": wide, "hp": shield_hp, "time": 99.0, "follow": true, "dist": 0.95, "block": "enemy", "color": rmb_def().get("col", "#9ad8ff")}, 1.0)
	h.mel_hold = 0.0
	last_variant = "air" if rmb_ctx.get("air", false) else "hold"

func _lower() -> void:
	if wall.is_empty():
		return
	shield_hp = float(wall["hp"])
	if m.verbs.walls.has(wall):
		m.verbs.walls.erase(wall)
		if is_instance_valid(wall["node"]): (wall["node"] as Node3D).queue_free()
	wall = {}
	down_t = 0.0

func fire_rmb(c: Dictionary) -> void:
	if not wall.is_empty() or c.get("hold", false):
		_lower()
		return
	last_variant = String(c["variant"])
	if not spend_rmb(): return
	var bd: Dictionary = rmb_def()["bash"]
	var slam: bool = c.get("full", false)
	var heal_behind: bool = c.get("e", false)
	var go := func():
		if not is_instance_valid(h) or h.downed: return
		var effs: Array = [{"type": "damage", "amount": float(bd["dmg"])}, {"type": "push", "strength": float(rmb_def()["slam"]["push"]) if slam else float(bd["push"]), "from": "caster"}]
		if slam: effs.append({"type": "stun", "duration": float(rmb_def()["slam"]["stun"])})
		var stg := stage("rmb", {"delivery": {"type": "cone", "radius": float(bd["radius"]), "angle": float(bd["angle"])}, "effects": effs})
		run(stg, cx("rmb", "shield_slam" if slam else "bash", aim(), {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary):
			if f is Hunter: (f as Hunter).wallstun = maxf((f as Hunter).wallstun, float(bd["wallstun"]))}))
		m.sfx("shield", h.pos, -1.0, 0.7)
		if heal_behind:
			var back := -h.aim_dir()
			for o in m.hunters:
				if o != h and o.team == h.team and not o.out and o.flat_dist(h) < 4.0 and Vector2(o.pos.x - h.pos.x, o.pos.z - h.pos.z).normalized().dot(back) > 0.0:
					o.heal(float(rmb_def()["banner_heal"]))
					m.fx.burst(o.pos + Vector3(0, 1.0, 0), Feel.cat_color("sustain"), 10, 2.0, 0.4, -2.0)
	if slam:
		# Shield Slam spends 50 Guard; a 0.3s shield flare is the tell
		res -= float(res_def().get("slam", 50.0))
		m.fx.flash(h.pos + Vector3(h.aim_dir().x * 0.8, 1.0, h.aim_dir().y * 0.8), res_col(), 0.9, float(rmb_def()["slam"]["tell"]))
		tele_lane(h.pos, h.aim_dir(), float(bd["radius"]), 2.0, Feel.cat_color("control"), float(rmb_def()["slam"]["tell"]))
		m.later(float(rmb_def()["slam"]["tell"]), go)
	else:
		go.call()

func fire_ok_rmb() -> bool:
	return lock_t <= 0.0

# ------------------------------------------------------------------ dash: Interpose
func _ally_under_cursor() -> Hunter:
	var dd := dash_def()
	var reach := float(dd["ally_reach"]) + (1.0 if rank("dash") >= 3 else 0.0)
	var a := aim()
	var best: Hunter = null; var bd := float(dd["snap"])
	for o in m.hunters:
		if o == h or o.team != h.team or o.out or o.downed or h.flat_dist(o) > reach:
			continue
		var dd2 := Vector2(o.pos.x - a.x, o.pos.z - a.z).length()
		if dd2 < bd: bd = dd2; best = o
	return best

func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if not leap.is_empty():
		return true
	var ally := _ally_under_cursor()
	if ally and h.grounded:
		if not spend_dash(false): return true
		var side := h.aim_dir()
		var to := ground(ally.pos + Vector3(side.x, 0, side.y) * 1.1)
		if m.world.is_void(to.x, to.z) or m.world.is_block(to.x, to.z): to = ally.pos
		tele_circle(to, float(dd["push_r"]), col_of(dd), float(dd["leap_t"]))
		h.launch_to(to, float(dd["leap_t"]))
		h.fortify_t = maxf(h.fortify_t, float(dd["leap_t"]) + 0.1)
		leap = {"t": float(dd["leap_t"]), "to": to, "from": h.pos}
		Feel.dash_sound(m, id, h.pos, h)
		st["last_dash"] = "leap"
		CombatBus.ability_used.emit(h, "interpose", "dodge")
		return true
	if not spend_dash(use_ex):
		return true
	var dist := float(dd["step"]) if not use_ex else float(h.cdat.get("ex_dist", 4.2))
	travel(dist, dist / float(dd["step_speed"]), {"invuln": 0.0, "trail": "dust"}, use_ex)
	front_t = dist / float(dd["step_speed"]) + float(dd["guard_t"]) + (0.3 if _rider_repeat() else 0.0)
	h.fortify_t = maxf(h.fortify_t, front_t)
	st["last_dash"] = "step"
	return true

func _rider_repeat() -> bool:
	var k: Kin = h.kin
	if k == null or k.dead or k.ks == null: return false
	for md in k.ks.dodge_rider.get("modifiers", []):
		if (md as PartSpec).type == "repeat": return true
	return false

func _land_leap() -> void:
	var dd := dash_def()
	var to: Vector3 = leap["to"]
	var from: Vector3 = leap["from"]
	leap = {}
	if h.downed: return
	rider_points(from, h.pos)
	var spend := res >= float(res_def().get("leap", 20.0))
	for o in m.hunters:
		if o.team == h.team and o != h and not o.out and o.flat_dist(h) < float(dd["ally_r"]):
			o.shield = maxf(o.shield, float(dd["ally_shield"]) if spend else float(dd["ally_shield"]) * 0.5)
			o.shield_t = maxf(o.shield_t, 3.0)
			m.fx.ring(o.pos, 1.0, Feel.cat_color("shield"), 0.4)
	if spend: res -= float(res_def().get("leap", 20.0))
	var ps := StageSpec.parse({"delivery": {"type": "burst", "origin": "caster", "radius": float(dd["push_r"])}, "effects": [{"type": "push", "strength": float(dd["push"])}]}, "", GrammarReport.new())
	run(ps, cx("dash", "interpose_land", h.pos, {"no_floor": true}))
	front_t = maxf(front_t, 0.3)
	m.sfx("shield", h.pos, 0.0, 0.6)
	Feel.shake(m, "leap", h, h.pos)

# ------------------------------------------------------------------ E: Rally Banner
func cast_e() -> bool:
	var ed := e_def()
	var at := aim_at(float(ed["reach"]))
	var r := float(ed["radius"]) + (1.0 if rank("kin") >= 3 else 0.0)
	if not banner.is_empty() and is_instance_valid(banner["node"]): (banner["node"] as Node3D).queue_free()
	var n := Node3D.new()
	m.add_child(n)
	n.position = at
	Models.part(n, Models.cyl(0.05, 0.05, 2.4, 8), Models.toon(Color("6a5040")), Vector3(0, 1.2, 0))
	var tc: Color = Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()]
	Models.part(n, Models.box(0.7, 0.5, 0.04), Models.toon(tc, true, 0.4), Vector3(0.36, 2.1, 0))
	var ring := MeshInstance3D.new(); ring.mesh = Models.flat_quad(r * 2.0)
	ring.material_override = Models.ring_mat(Color(col_of(ed), 0.85), 0.05)
	ring.position.y = 0.07
	n.add_child(ring)
	banner = {"pos": at, "t": float(ed["time"]), "r": r, "node": n, "tick": 0.0}
	e_t = float(ed["time"])
	var stg := stage("e", {"delivery": {"type": "zone", "origin": "aim", "radius": r, "duration": float(ed["time"]), "every": 0.5},
		"effects": [{"type": "slow", "duration": 0.6, "strength": float(ed["slow"])}]})
	run(stg, cx("e", "rally_banner", at, {"no_floor": true}))
	m.sfx("build", at, -2.0, 1.2)
	return true

func _tick_banner(dt: float) -> void:
	banner["t"] = float(banner["t"]) - dt
	banner["tick"] = float(banner["tick"]) - dt
	if float(banner["tick"]) <= 0.0:
		banner["tick"] = 1.0
		var ed := e_def()
		for o in m.hunters:
			if o.team == h.team and not o.out and not o.downed and o.flat_dist(banner["pos"]) < float(banner["r"]):
				o.shield = minf(float(ed["max"]), o.shield + float(ed["shield"]))
				o.shield_t = maxf(o.shield_t, 2.0)
	if float(banner["t"]) <= 0.0:
		if is_instance_valid(banner["node"]): (banner["node"] as Node3D).queue_free()
		banner = {}

# ------------------------------------------------------------------ R: Bastion
func cast_r() -> bool:
	var rd := r_def()
	var tell := float(rd["tell"])
	var r := float(rd["radius"]) + (1.0 if rank("ult") >= 2 else 0.0)
	var at := h.pos
	tele_circle(at, r, col_of(rd), tell)
	m.sfx("shield", at, 0.0, 0.5)
	var extra: float = floor(res / 50.0) * float(rd["per_50"])
	res = 0.0
	r_t = tell + float(rd["time"]) * r_dur_k() + extra
	m.later(tell, func():
		if not is_instance_valid(h) or h.downed: return
		var dur: float = float(rd["time"]) * r_dur_k() + extra
		m.add_zone("dome", at, r, dur, h.team, h)
		if not m.zones.is_empty(): m.zones[-1]["hp"] = 600.0
		dome = {"pos": at, "r": r, "t": dur}
		var stg := stage("r", {"delivery": {"type": "burst", "origin": "aim", "radius": r}, "effects": [{"type": "push", "strength": float(rd["push"])}]})
		run(stg, cx("r", "bastion", at, {"no_floor": true}))
		Feel.shake(m, "leap", h, at))
	return true

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if int(h.slot_lv["ult"]) > 0 and float(cd["r"]) <= 0.0 and (h.hp < h.max_hp * 0.5 or res > 60.0) and dist < 9.0 and randf() < 0.4:
		h.inp["ult"] = true; return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist < 8.0 and randf() < 0.3:
		h.inp["aim"] = h.pos.lerp(tgt.pos, 0.3); h.inp["sig"] = true; return
	if int(h.slot_lv["sec"]) <= 0:
		return
	var shot_at: bool = m.time - h.hurt_at < 0.6 and dist > 3.0
	if shot_at and lock_t <= 0.0 and shield_hp > 30.0:
		# raise the shield toward whoever is shooting
		h.inp["aim"] = tgt.pos
		if not rmb_down: h.inp["sec"] = true
		bot_hold["rmb"] = 1.0
	elif dist < 2.6 and rmb_ready() and wall.is_empty():
		h.inp["aim"] = tgt.pos; h.inp["sec"] = true
