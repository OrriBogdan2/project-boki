class_name JuggernautKit
extends ArchKit
## Juggernaut (heavy): Rampage, Rage (Enraged), Smash (Earthshatter, Meteor Drop, the pull in Iron
## Hide, empowered when Enraged), Iron Hide, Avalanche. docs/ARCHETYPES.md §6.5.

var enraged_t := 0.0
var hit_at := -9.0
var lost := 0.0                # health lost toward the next +10 Rage
var ramp := {}                 # Rampage: {t, tele, hold} while Shift is down; {carry...} while charging
var charge := {}               # the running hold charge: {target, end_t, dir}
var aval := {}                 # Avalanche: {tell, t, stomp, slammed}
var iron := false
var aura: Node3D = null        # the Enraged look: a red shell, a glow, the hunter grown bigger
var grow := 0.0                # 0..1 how far into the Enraged form the model is

func full_ready() -> bool:
	return enraged_t > 0.0

func res_frac() -> float:
	return 1.0 if enraged_t > 0.0 else clampf(res / res_max(), 0.0, 1.0)

func res_text() -> String:
	return "ENRAGED" if enraged_t > 0.0 else "%d" % int(res)

func gain_rage(v: float) -> void:
	if enraged_t > 0.0:
		return
	add_res(v)
	touch_res()
	if res >= res_max():
		enraged_t = float(res_def().get("enraged_t", 5.0))
		res = res_max()
		_enrage_fx()

## Becoming Enraged: a roar, a red shockwave, and the hunter visibly swells into a red, steaming form
## (everyone sees it: that's the "back off or bait it out" read).
func _enrage_fx() -> void:
	var rc := res_col()
	m.sfx("knock", h.pos, 0.0, 0.6)          # the roar, audible within 25m
	m.sfx("charge", h.pos, -3.0, 0.45)
	m.fx.word(h.pos + Vector3(0, 2.8, 0), "ENRAGED", rc, true)
	m.fx.ring(h.pos, 2.8, rc, 0.45)
	m.fx.ring(h.pos, 1.4, Color(1, 0.9, 0.8, 0.9), 0.25)
	m.fx.burst(h.pos + Vector3(0, 1.2, 0), rc, 30, 6.0, 0.6, -2.0, 1.4)
	Feel.shake(m, "t3", h, h.pos)
	if h.is_local() and m.hud: m.hud.flash(rc, 0.15)
	if m.net_on and not h.remote:
		m.net_fx(["ring", m._r(h.pos.x), m._r(h.pos.y), m._r(h.pos.z), 2.8, rc.to_html(false)])
	_make_aura()

func _make_aura() -> void:
	if aura and is_instance_valid(aura):
		return
	aura = Node3D.new()
	var rc := res_col()
	var sh := MeshInstance3D.new()
	sh.mesh = Models.sphere(0.95, 16)
	sh.material_override = Models.glow_mat(Color(rc, 0.16))
	sh.scale = Vector3(1.0, 1.35, 1.0)
	sh.position.y = 1.05
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sh.name = "Shell"
	aura.add_child(sh)
	var ring := MeshInstance3D.new()
	ring.mesh = Models.cyl(1.05, 1.05, 0.04, 24)
	ring.material_override = Models.glow_mat(Color(rc, 0.45))
	ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.add_child(ring)
	var lt := OmniLight3D.new()
	lt.light_color = rc
	lt.light_energy = 1.6
	lt.omni_range = 3.5
	lt.position.y = 1.2
	aura.add_child(lt)
	h.add_child(aura)

func _drop_aura() -> void:
	if aura and is_instance_valid(aura):
		aura.queue_free()
	aura = null

## Spending the Rage: the shell bursts outward and the hunter shrinks back.
func _spend_fx() -> void:
	var rc := res_col()
	m.fx.ring(h.pos, 3.4, rc, 0.4)
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), rc, 26, 7.0, 0.5, 4.0, 1.3)
	_drop_aura()

func _tick_look(dt: float) -> void:
	var want := 1.0 if enraged_t > 0.0 else 0.0
	grow = move_toward(grow, want, dt * (6.0 if want > grow else 3.0))
	if h.model:
		h.model.scale = Vector3.ONE * (1.0 + 0.16 * grow)
	if aura and is_instance_valid(aura):
		var sh := aura.get_node_or_null("Shell") as MeshInstance3D
		if sh: sh.scale = Vector3(1.0, 1.35, 1.0) * (1.0 + 0.06 * sin(m.time * 10.0))
		if randf() < dt * 14.0:
			# red steam off the shoulders
			for sx in [-0.45, 0.45]:
				m.fx.burst(h.pos + Vector3(sx, 1.75, 0), res_col(), 2, 1.6, 0.5, -3.0, 0.9)
	if enraged_t <= 0.0 and aura:
		_drop_aura()

func _tick(dt: float) -> void:
	_tick_look(dt)
	if enraged_t > 0.0:
		enraged_t -= dt
		if enraged_t <= 0.0:
			enraged_t = 0.0; res = 0.0
	elif res_wait <= 0.0:
		add_res(-float(res_def().get("decay", 12.0)) * dt)
	if not ramp.is_empty():
		_tick_windup(dt)
	if not charge.is_empty():
		_tick_carry(dt)
	if not aval.is_empty():
		_tick_aval(dt)

func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team:
		return
	if String(o.get("src", "")) == "wall":
		gain_rage(float(res_def().get("wall", 20.0)))
		return
	if String(o.get("src", "")) == "burn":
		return
	if m.time - hit_at >= 0.15:          # a pellet volley counts as one hit
		hit_at = m.time
		gain_rage(float(res_def().get("per_hit", 6.0)))

func on_take(_by: Ent, dmg: float, _o: Dictionary) -> void:
	lost += dmg
	var step := h.max_hp * 0.1
	while lost >= step and step > 0.0:
		lost -= step
		gain_rage(float(res_def().get("per_10pct", 10.0)))

## Unstoppable (Avalanche): no stun, root or knockback; slows at half strength. Iron Hide: 30% less.
func incoming(_by: Ent, dmg: float, o: Dictionary) -> Array:
	if not aval.is_empty() and float(aval.get("t", 0.0)) > 0.0:
		o = o.duplicate()
		o.erase("stun"); o.erase("root"); o.erase("kb"); o.erase("lift")
		if o.has("slow_k"): o["slow_k"] = float(o["slow_k"]) * 0.5
	if iron:
		dmg *= 1.0 - float(e_def().get("dr", 0.3))
		o = o.duplicate(); o.erase("kb"); o.erase("lift")
	return [dmg, o]

func move_k() -> float:
	var k := 1.0
	if not ramp.is_empty() and bool(ramp.get("hold", false)):
		k *= float(dash_def().get("hold_slow", 0.5))
	if not aval.is_empty() and float(aval.get("t", 0.0)) > 0.0:
		k *= 1.0 + float(r_def().get("speed", 0.3))
	return k

# ------------------------------------------------------------------ dash: Rampage
func on_dash(use_ex: bool) -> bool:
	if not ramp.is_empty() or not charge.is_empty():
		return true
	if use_ex and not h.grounded:
		if not spend_dash(true): return true
		travel(float(h.cdat.get("ex_dist", 4.2)), float(h.cdat.get("ex_time", 0.21)), {"invuln": 0.08, "trail": "dust"}, true)
		return true
	if not spend_dash(false):
		return true
	ramp = {"t": 0.0, "hold": false, "dir": h.aim_dir()}
	return true

## The held Rampage's wind-up as a charge (the shared hold feedback reads it).
func dash_charge() -> float:
	if ramp.is_empty() or not bool(ramp.get("hold", false)):
		return -1.0
	return clampf((float(ramp["t"]) - float(dash_def().get("tap_t", 0.15))) / windup_t(), 0.0, 1.0)

func windup_t() -> float:
	var t := float(dash_def().get("windup", 0.7))
	if rank("dash") >= 3: t = 0.55
	if enraged_t > 0.0: t *= 0.5
	return t

func _arrow_len(k: float) -> float:
	var a: Array = dash_def().get("arrow", [3.0, 7.0])
	var extra := 1.0 if _rider_as() == "blink" else 0.0
	return lerpf(float(a[0]), float(a[1]), clampf(k, 0.0, 1.0)) + extra

func _rider_as() -> String:
	var k: Kin = h.kin
	return String(k.ks.dodge_rider.get("as", "")) if k and k.ks and not k.dead else ""

func _tick_windup(dt: float) -> void:
	var dd := dash_def()
	ramp["t"] = float(ramp["t"]) + dt
	var t := float(ramp["t"])
	if h.stun_t > 0.0 or h.root_t > 0.0 or h.downed:
		# CC'd during the windup: cancelled, half a charge back
		if ramp.get("tele") and is_instance_valid(ramp["tele"]): m.fx.end_telegraph(ramp["tele"])
		ramp = {}
		h.dashes = minf(h.max_dashes(), h.dashes + 0.5)
		return
	if not bool(ramp["hold"]):
		if held("dash") and t >= float(dd.get("tap_t", 0.15)):
			ramp["hold"] = true
			ramp["tele"] = tele_lane(h.pos, h.aim_dir(), _arrow_len(0.0), 1.2, res_col(), 0.0)
			m.sfx("charge", h.pos, -4.0, 0.5)       # the engine-like growl
		elif not held("dash"):
			ramp = {}
			_tap_charge()
		return
	var k := clampf((t - float(dd.get("tap_t", 0.15))) / windup_t(), 0.0, 1.0)
	var tele: Node3D = ramp.get("tele")
	if tele and is_instance_valid(tele):
		tele.set_meta("len", _arrow_len(k))
		var pm := (tele as MeshInstance3D).mesh as PlaneMesh
		if pm: pm.size = Vector2(1.2, _arrow_len(k))
		m.fx.aim_telegraph(tele, h.pos, h.aim_dir())
		m.fx.telegraph_progress(tele, k)
	if int(t * 8.0) != int((t - dt) * 8.0): m.fx.dust(h.pos, 3)
	if not held("dash") or t >= float(dd.get("tap_t", 0.15)) + windup_t() + 0.4:
		if tele and is_instance_valid(tele): m.fx.end_telegraph(tele)
		ramp = {}
		_hold_charge(_arrow_len(k))

func _tap_charge() -> void:
	var dd := dash_def()
	var kb := float(dd["shove"]) * (1.5 if enraged_t > 0.0 else 1.0)
	travel(float(dd["tap"]), float(dd["tap"]) / float(dd["tap_speed"]), {"invuln": 0.0, "shove": true, "shove_kb": kb, "shove_dmg": 8.0, "wallstun": float(dd["wallstun"]), "trail": "dust", "dir": h.aim_dir()})
	st["last_dash"] = "tap"

func _hold_charge(length: float) -> void:
	var dd := dash_def()
	var spd := float(dd["speed"])
	var t := length / spd
	var from := h.pos
	travel(length, t, {"invuln": 0.0, "trail": "dust", "dir": h.aim_dir()})
	h.fortify_t = maxf(h.fortify_t, t + 0.1)       # unstoppable
	charge = {"target": null, "end": m.time + t, "dir": h.roll_dir, "carried": 0.0}
	st["last_dash"] = "hold"
	if h.kin and not (h.kin as Kin).dead and (h.kin as Kin).ks:
		for md in (h.kin as Kin).ks.dodge_rider.get("modifiers", []):
			if (md as PartSpec).type == "repeat":
				m.later(t + 0.18, func():
					if is_instance_valid(h) and not h.downed and charge.is_empty():
						travel(length * 0.55, t * 0.55, {"invuln": 0.0, "trail": "dust"})
						charge = {"target": null, "end": m.time + t * 0.55, "dir": h.roll_dir, "carried": 0.0})

func _tick_carry(_dt: float) -> void:
	var dd := dash_def()
	var dir: Vector2 = charge["dir"]
	var tgt: Ent = charge["target"]
	if tgt == null:
		for f in m.foes_of(h.team):
			if f is Hunter and h.flat_dist(f) < h.r + f.r + 0.4 and absf(f.pos.y - h.pos.y) < 1.4:
				charge["target"] = f
				tgt = f
				m.fx.word(f.pos + Vector3(0, 2.2, 0), "CARRIED", res_col(), false)
				break
	if tgt and is_instance_valid(tgt) and not tgt.dead:
		var ahead := h.pos + Vector3(dir.x, 0, dir.y) * (h.r + tgt.r + 0.15)
		if not m.world.is_void(ahead.x, ahead.z) and not m.world.is_block(ahead.x, ahead.z) and m.world.ground_at(ahead.x, ahead.z) < h.pos.y + 0.6:
			tgt.teleport(Vector3(ahead.x, tgt.pos.y, ahead.z))
			tgt.vel = Vector3.ZERO
	if m.time >= float(charge["end"]) or h.roll_t <= 0.0:
		var c := charge
		charge = {}
		if tgt and is_instance_valid(tgt) and not tgt.dead:
			if _wall_ahead(tgt, dir, 0.9):
				# a wall at the end of the carry: stun 1.2 and a payoff-tier hit
				tgt.hurt(10.0 * power("dash"), h, {"src": "abil", "ab": "dodge", "tags": ["dodge", "rampage"], "stun": float(dd["wallstun"]), "payoff": true, "melee": true})
				gain_rage(float(res_def().get("wall", 20.0)))
				m.fx.word(tgt.pos + Vector3(0, 2.3, 0), "SLAMMED", res_col(), true)
				Feel.shake(m, "t4", h, tgt.pos, tgt)
			else:
				tgt.hurt(6.0 * power("dash"), h, {"src": "abil", "ab": "dodge", "tags": ["dodge"], "kb": dir * float(dd["shove"]), "lift": 2.5, "melee": true})

func _wall_ahead(t: Ent, dir: Vector2, reach: float) -> bool:
	var k := 0.3
	while k <= reach:
		var q := t.pos + Vector3(dir.x, 0, dir.y) * (t.r + k)
		if m.world.is_block(q.x, q.z) or m.world.ground_at(q.x, q.z) > t.pos.y + 0.8:
			return true
		k += 0.3
	return false

# ------------------------------------------------------------------ RMB: Smash
func rmb_auto_t() -> float:
	return 1.0

func rmb_hold_tick(t: float) -> void:
	if t > 0.2 and not st.has("shatter_tele"):
		var reach := 7.0
		var a := aim()
		var dv := Vector2(a.x - h.pos.x, a.z - h.pos.z)
		if dv.length() > reach: dv = dv.normalized() * reach
		st["shatter_tele"] = true

func fire_rmb(c: Dictionary) -> void:
	st.erase("shatter_tele")
	last_variant = String(c["variant"])
	if not spend_rmb(): return
	var sd := rmb_def()
	var emp: bool = c.get("full", false) and enraged_t > 0.0
	var kk := 1.5 if emp else 1.0
	if emp:
		enraged_t = 0.0; res = 0.0      # the empowered Smash spends the rage
		_spend_fx()
		m.fx.word(h.pos + Vector3(0, 2.6, 0), "RAGE SMASH", res_col(), true)
		Feel.shake(m, "t4", h, h.pos)
	if c.get("air", false):
		var dd: Dictionary = sd["drop"]
		h.gliding = false
		h.vel = Vector3(h.vel.x * 0.2, -22.0, h.vel.z * 0.2)
		var drop_at := h.pos
		m.later(0.12, func():
			if not is_instance_valid(h): return
			var stg := stage("rmb", {"delivery": {"type": "burst", "origin": "caster", "radius": float(dd["radius"])},
				"effects": [{"type": "damage", "amount": float(dd["dmg"])}, {"type": "lift", "strength": float(dd["lift"])}],
				"modifiers": [{"type": "spike", "bonus": 0.5, "stun": float(dd["spike_stun"])}]})
			run(stg, cx("rmb", "meteor_drop", h.pos, {"no_floor": true}))
			m.fx.dust(h.pos, 14)
			Feel.shake(m, "leap", h, h.pos))
		return
	if c.get("hold", false):
		var stun := 1.0 + (0.2 if rank("sec") >= 3 else 0.0)
		var r := 3.0 + (1.0 if emp else 0.0)
		var land_effs: Array = [{"type": "damage", "amount": 20.0}, {"type": "push", "strength": 3.0 * kk}, {"type": "lift", "strength": 8.0}]
		if emp: land_effs.append({"type": "stun", "duration": 0.6})
		var stg := stage("rmb", {"delivery": {"type": "leap", "range": 7.0, "time": 0.55, "height": 2.5},
			"then": {"on_land": [{"delivery": {"type": "burst", "origin": "here", "radius": r}, "effects": land_effs,
				"modifiers": [{"type": "spike", "bonus": 0.6, "stun": stun}]}]}}, {})
		# the kin's parts ride the landing burst
		var land := stage("rmb", {"delivery": {"type": "burst", "origin": "here", "radius": r}, "effects": land_effs, "modifiers": [{"type": "spike", "bonus": 0.6, "stun": stun}]})
		stg.then["on_land"] = [land]
		run(stg, cx("rmb", "earthshatter", aim()))
		m.later(0.55, func(): if is_instance_valid(h): Feel.shake(m, "leap", h, h.pos))
		return
	var shotgun := h.wid == "shotgun"
	var go := func():
		if not is_instance_valid(h) or h.downed: return
		var od: Dictionary = sd["over"]
		var effs: Array = [{"type": "damage", "amount": 12.0 if shotgun else float(od["dmg"])}, {"type": "push", "strength": minf(16.0, (13.0 if shotgun else float(od["push"])) * kk), "from": "caster"}]
		var stg := stage("rmb", {"delivery": {"type": "cone", "radius": 3.5 if shotgun else float(od["radius"]), "angle": 70.0 if shotgun else float(od["angle"])}, "effects": effs})
		run(stg, cx("rmb", "breach" if shotgun else "overhead_smash", aim(), {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary):
			# a solid smash: a payoff-weight hit-stop when it's empowered
			Feel.hitstop(m, h, f, 30.0, {"melee": true, "payoff": kk > 1.0, "heavy": true})}))
		var dd := h.aim_dir()
		m.fx.cone(h.pos + Vector3(0, 0.1, 0), dd, 3.5 if shotgun else float(od["radius"]), res_col() if kk > 1.0 else col_of(sd))
		m.fx.slash(h.pos + Vector3(0, 0.9, 0), atan2(dd.y, dd.x), deg_to_rad(110.0), float(od["radius"]), col_of(sd), true)
		m.fx.dust(h.pos + Vector3(dd.x, 0, dd.y) * 1.8, 10)
		Feel.shake(m, "t2", h, h.pos)
		if h.is_local(): Oomph.punch_dir(m, dd, 0.22 * kk)
		if shotgun:
			var d := h.aim_dir()
			h.vel.x = -d.x * 9.0; h.vel.z = -d.y * 9.0
			h.knock_t = 0.15
			m.sfx("shotgun" if Sfx.has("shotgun") else "boom", h.pos, -1.0, 0.8)
		else:
			m.sfx("cleave", h.pos, -1.0, 0.8)
	if c.get("e", false):
		# Iron Hide: the tap pulls foes within 4m in first
		var pd: Dictionary = sd["pull"]
		var ps := StageSpec.parse({"delivery": {"type": "burst", "origin": "caster", "radius": float(pd["radius"])}, "effects": [{"type": "pull", "strength": float(pd["strength"]), "to": "caster"}]}, "", GrammarReport.new())
		run(ps, cx("rmb", "smash_pull", h.pos, {"no_floor": true}))
		m.later(0.15, go)
	else:
		go.call()

# ------------------------------------------------------------------ E: Iron Hide
func in_e() -> bool:
	return iron

func cast_e() -> bool:
	var ed := e_def()
	iron = true
	e_t = float(ed["time"])
	h.fortify_t = maxf(h.fortify_t, e_t)
	h.slow_t = 0.0; h.root_t = 0.0; h.stun_t = 0.0; h.burn_t = 0.0; h.slow_k = 0.0     # cleanse
	m.fx.ring(h.pos, 1.5, col_of(ed), 0.35)
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), col_of(ed), 16, 2.5, 0.4)
	m.sfx("shield", h.pos, -2.0, 0.6)
	var g := Arch.fill(ed.get("sockets", {}), infusion(), "e", "burst", [], budget_k("e"))
	var friendly: Array = (g["effects"] as Array).filter(func(e): return String(e["type"]) in ["shield", "heal", "reflect", "buff"])
	if not friendly.is_empty():
		var fs := StageSpec.parse({"delivery": {"type": "burst", "origin": "caster", "radius": 0.0}, "effects": friendly}, "", GrammarReport.new())
		if fs: run(fs, cx("e", "iron_hide", h.pos, {"no_floor": true}))
	return true

func _e_end() -> void:
	if not iron:
		return
	iron = false
	var ed := e_def()
	var push := 14.0 if rank("kin") >= 3 else float(ed["end_push"])
	var stg := stage("e", {"delivery": {"type": "burst", "origin": "caster", "radius": float(ed["end_r"])}, "effects": [{"type": "push", "strength": push}]}, {"hit": "add", "ctrl": "add", "ctrl_cap": "soft", "util": "add"})
	run(stg, cx("e", "shrug_off", h.pos, {"no_floor": true}))
	m.fx.word(h.pos + Vector3(0, 2.2, 0), "SHRUG", col_of(ed), false)
	m.fx.ring(h.pos, float(ed["end_r"]), col_of(ed), 0.3)
	m.fx.dust(h.pos, 12)
	m.sfx("knock", h.pos, -6.0, 0.9)
	Feel.shake(m, "t2", h, h.pos)

# ------------------------------------------------------------------ R: Avalanche
func cast_r() -> bool:
	var rd := r_def()
	aval = {"tell": float(rd["tell"]), "t": 0.0, "stomp": 0.0, "slammed": {}, "first": true}
	m.sfx("knock", h.pos, 2.0, 0.5)
	m.fx.word(h.pos + Vector3(0, 2.6, 0), "AVALANCHE", col_of(rd), true)
	for i in 5:
		m.later(0.06 * i, func(): if is_instance_valid(h): m.fx.burst(h.pos + Vector3(0, 0.5 + i * 0.6, 0), col_of(rd), 10, 2.0, 0.35, -2.0, 1.1))
	tele_circle(h.pos, 2.0, col_of(rd), float(rd["tell"]))
	r_t = float(rd["tell"]) + float(rd["time"]) * r_dur_k()
	return true

func _tick_aval(dt: float) -> void:
	var rd := r_def()
	if float(aval["tell"]) > 0.0:
		aval["tell"] = float(aval["tell"]) - dt
		if float(aval["tell"]) <= 0.0:
			aval["t"] = float(rd["time"]) * r_dur_k()
			h.dashes = h.max_dashes()      # Rampage charges refill
		return
	aval["t"] = float(aval["t"]) - dt
	h.fortify_t = maxf(h.fortify_t, 0.1)
	h.stun_t = 0.0; h.root_t = 0.0
	if float(aval["t"]) <= 0.0:
		aval = {}
		return
	aval["stomp"] = float(aval["stomp"]) - dt
	if float(aval["stomp"]) <= 0.0:
		aval["stomp"] = float(rd["stomp"])
		var r := float(rd["stomp_r"]) + (1.0 if bool(aval["first"]) and rank("ult") >= 2 else 0.0)
		aval["first"] = false
		var stg := stage("r", {"delivery": {"type": "burst", "origin": "caster", "radius": r},
			"effects": [{"type": "damage", "amount": float(rd["stomp_dmg"]) * r_k()}, {"type": "push", "strength": float(rd["stomp_push"])}]})
		run(stg, cx("r", "avalanche_stomp", h.pos, {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary):
			# the first wall slam on each foe stuns 1.0
			if f is Hunter and not (aval.get("slammed", {}) as Dictionary).has(f.get_instance_id()):
				(f as Hunter).wallstun = float(rd["wall_stun"])
				if not aval.is_empty(): aval["slammed"][f.get_instance_id()] = true}))
		m.fx.dust(h.pos, 10)
		Feel.shake(m, "t2", h, h.pos)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if int(h.slot_lv["ult"]) > 0 and float(cd["r"]) <= 0.0 and dist < 6.0 and randf() < 0.4:
		h.inp["ult"] = true; return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist < 5.0 and (h.hp < h.max_hp * 0.7 or randf() < 0.3):
		h.inp["sig"] = true; return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los:
		if dist < 3.2:
			h.inp["aim"] = tgt.pos; h.inp["sec"] = true
		elif dist < 7.0 and randf() < 0.5:
			h.inp["aim"] = tgt.pos; h.inp["sec"] = true
			bot_hold["rmb"] = 0.75
	# Rampage in: a held charge from range, a tap shove up close
	if int(h.slot_lv["dash"]) > 0 and h.dashes >= 1.0 and los and ramp.is_empty() and charge.is_empty() and randf() < 0.25:
		if dist > 3.5 and dist < 7.5:
			h.inp["aim"] = tgt.pos; h.inp["dash"] = true
			bot_hold["dash"] = 0.15 + windup_t() * clampf((dist - 3.0) / 4.0, 0.2, 1.0)
		elif dist < 2.5:
			h.inp["aim"] = tgt.pos; h.inp["dash"] = true
