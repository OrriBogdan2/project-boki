class_name MageKit
extends ArchKit
## Mage (medium): Blink, Overload (Heat and the Vent), Bolt (Lance, Starfall, split through the
## Sigil, Overcharged), Sigil (recast to detonate), Meteor. docs/ARCHETYPES.md §6.3.
##
## The loop (kits4): bolts and the Sigil build Heat -> Overcharged at 70 (runes orbit the Mage
## white-hot, the Sigil glows primed) -> recast E for a Flashpoint: the Sigil detonates with all the
## Heat (bigger, harder, a payoff hit that lifts), Heat drops to 0 with no Vent and the Bolt is back
## for the follow-up (or a Meteor spikes the lifted). Overshoot to 100 and you Vent instead.

var sigil := {}                # {pos, r, t, node}
var vent := {}                 # a Vent winding up: {t}
var lock_t := 0.0              # RMB locked after a Vent
var lance_tele: Node3D = null
var blink := {}                # Blink's windup: {t, to, from, ex}
var blink_back := {}           # Moon Return / echo recast window: {t, to, k}
var meteor := {}
var runes: Node3D = null       # the Heat tell: rune motes orbiting the Mage, white-hot when Overcharged
var was_over := false
var armed_at := -9.0
var flashpoints := 0           # Flashpoints set off (tests, demo)

func over() -> bool:
	return res >= float(res_def().get("over", 70.0))

func full_ready() -> bool:
	return over()

func res_text() -> String:
	return "%d HOT" % int(res) if over() else "%d" % int(res)

func ready_label() -> String:
	if over() and not sigil.is_empty(): return "FLASHPOINT READY  ·  E"
	if over(): return "OVERCHARGED"
	return ""

func e_payoff_ready() -> bool:
	return over() and not sigil.is_empty()

func add_heat(v: float) -> void:
	add_res(v)
	touch_res(float(res_def().get("wait", 1.2)))
	if res >= res_max() - 0.01 and vent.is_empty():
		_start_vent()

func _tick(dt: float) -> void:
	var rd := res_def()
	lock_t = maxf(0.0, lock_t - dt)
	if res_wait <= 0.0 and vent.is_empty():
		add_res(-float(rd.get("decay", 18.0)) * dt)
	if not vent.is_empty():
		vent["t"] = float(vent["t"]) - dt
		if float(vent["t"]) <= 0.0:
			_vent()
	if not sigil.is_empty():
		sigil["t"] = float(sigil["t"]) - dt
		if int(m.time * 4.0) != int((m.time - dt) * 4.0):
			for o in m.hunters:
				if o.team == h.team and not o.out and o.flat_dist(sigil["pos"]) < float(sigil["r"]):
					o.add_buff("move_speed", float(e_def().get("haste", 0.15)), 0.4)
		if float(sigil["t"]) <= 0.0:
			_drop_sigil()
	if lance_tele and is_instance_valid(lance_tele) and rmb_down:
		m.fx.aim_telegraph(lance_tele, h.pos, h.aim_dir())
	if not blink.is_empty():
		blink["t"] = float(blink["t"]) - dt
		if float(blink["t"]) <= 0.0:
			_do_blink()
	if not blink_back.is_empty():
		blink_back["t"] = float(blink_back["t"]) - dt
		if float(blink_back["t"]) <= 0.0: blink_back = {}
	var ov := over() and vent.is_empty()
	if ov and not was_over and m.time - armed_at > 2.0:
		armed_at = m.time
		armed_fx("OVERCHARGED", "k1" if not sigil.is_empty() else "")
	was_over = ov
	_tick_runes(dt)
	_tick_sigil_look()
	net_pulse(dt, ov)
	if not meteor.is_empty():
		meteor["t"] = float(meteor["t"]) - dt
		var mt: Node3D = meteor.get("rock")
		if mt and is_instance_valid(mt):
			var k := 1.0 - clampf(float(meteor["t"]) / float(meteor["T"]), 0.0, 1.0)
			mt.position = (meteor["at"] as Vector3) + Vector3(-3.0, 9.0, 2.0) * (1.0 - k)
		if float(meteor["t"]) <= 0.0:
			_meteor_hit()

## The Heat tell on the Mage (everyone sees it): a rune mote per 20 Heat orbiting the waist, blue
## and calm below 70, white-hot, faster and lit from 70 (Overcharged).
func _tick_runes(_dt: float) -> void:
	if runes == null or not is_instance_valid(runes):
		runes = own_node()
		for i in 5:
			var d := MeshInstance3D.new()
			d.mesh = Models.box(0.16, 0.16, 0.16)
			d.material_override = Models.glow_mat(Color(col_of(e_def()), 0.95))
			d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			runes.add_child(d)
		var lt := OmniLight3D.new()
		lt.name = "Light"
		lt.light_color = res_col()
		lt.omni_range = 3.0
		runes.add_child(lt)
	var n := int(ceil(res / 20.0 - 0.01))
	runes.visible = tells_visible() and n > 0
	if not runes.visible:
		return
	var sc := float(h.cdat.get("scale", 1.0))
	runes.global_position = h.position + Vector3(0, 1.05 * sc, 0)
	var ov := over()
	var hot := res_col().lerp(Color("ffb070"), 0.35)
	var a: float = m.time * (5.5 if ov else 2.0)
	for i in 5:
		var d := runes.get_child(i) as MeshInstance3D
		d.visible = i < n
		var ang := a + TAU * i / 5.0
		var rad := (0.85 if ov else 0.7) * sc
		d.position = Vector3(cos(ang) * rad, 0.15 * sin(m.time * 3.0 + i), sin(ang) * rad)
		d.rotation = Vector3(m.time * 2.0, m.time * 3.0 + i, 0.0)
		d.scale = Vector3.ONE * ((1.4 + 0.25 * sin(m.time * 14.0 + i)) if ov else 1.0)
		d.material_override.set_shader_parameter("color", Color(hot, 1.0) if ov else Color(col_of(e_def()), 0.9))
	(runes.get_node("Light") as OmniLight3D).light_energy = (1.6 + 0.6 * sin(m.time * 12.0)) if ov else 0.0

## A primed Sigil (the Mage is Overcharged): its rings burn white-gold and throb, so everyone can read
## that the detonation will be a Flashpoint.
func _tick_sigil_look() -> void:
	if sigil.is_empty() or not is_instance_valid(sigil.get("node")):
		return
	var n: Node3D = sigil["node"]
	var ov := over()
	var c := res_col().lerp(Color.WHITE, 0.3) if ov else col_of(e_def())
	for ch in n.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).material_override:
			(ch as MeshInstance3D).material_override.set_shader_parameter("color", Color(c, 0.95 if ov else 0.8))
	n.scale = Vector3.ONE * ((1.0 + 0.05 * sin(m.time * 12.0)) if ov else 1.0)
	n.rotation.y += 0.02 if ov else 0.004

func move_k() -> float:
	if rmb_down and rmb_t > 0.15 and not rmb_ctx.get("air", false):
		return 1.0 - float(rmb_def()["lance"]["self_slow"])     # slowed while the Lance charges
	return 1.0

func fire_ok_rmb() -> bool:
	return lock_t <= 0.0

# ---- the Vent: a 0.4s ring collapsing onto you (everyone sees it), then the nova ----
func _start_vent() -> void:
	var rd := res_def()
	vent = {"t": float(rd.get("vent_t", 0.4))}
	var ring := tele_circle(h.pos, float(rd.get("vent_r", 3.0)), res_col(), float(rd.get("vent_t", 0.4)))
	m.sfx("warn", h.pos, -2.0, 1.5)
	m.fx.burst(h.pos + Vector3(0, 1.4, 0), Color(1, 1, 1, 0.7), 16, 2.5, 0.4, -3.0)

func _vent() -> void:
	var rd := res_def()
	vent = {}
	res = 0.0
	lock_t = float(rd.get("lock", 1.0))
	var stg := StageSpec.parse({"delivery": {"type": "burst", "origin": "caster", "radius": float(rd.get("vent_r", 3.0))},
		"effects": [{"type": "damage", "amount": float(rd.get("vent_dmg", 14.0))}, {"type": "push", "strength": float(rd.get("vent_push", 9.0))}]}, "", GrammarReport.new())
	run(stg, cx("rmb", "vent", h.pos, {"no_floor": true}))
	m.fx.word(h.pos + Vector3(0, 2.3, 0), "VENT", res_col(), true)
	Feel.shake(m, "t3", h, h.pos)

# ------------------------------------------------------------------ dash: Blink
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if not blink_back.is_empty():
		# Moon Return (a Lunowl) or the echo's free recast
		var to: Vector3 = blink_back["to"]
		var k := float(blink_back.get("k", 1.0))
		blink_back = {}
		if k < 1.0:
			var dv := Vector2(aim().x - h.pos.x, aim().z - h.pos.z)
			if dv.length() > 0.1: dv = dv.normalized() * minf(dv.length(), float(dd["dist"]) * k)
			to = _safe_spot(h.pos + Vector3(dv.x, 0, dv.y))
		_land_blink(h.pos, to, false)
		return true
	if not blink.is_empty():
		return true
	var air := not h.grounded or h.gliding
	if not spend_dash(use_ex and not air):
		return true
	var reach := float(dd["air_dist"]) if air else float(dd["dist"])
	var a := aim()
	var dv := Vector2(a.x - h.pos.x, a.z - h.pos.z)
	if dv.length() > reach: dv = dv.normalized() * reach
	if dv.length() < 0.5: dv = h.aim_dir() * reach
	var to := h.pos + Vector3(dv.x, 0, dv.y)
	to = _safe_spot(to) if not air else Vector3(to.x, h.pos.y, to.z)
	# the 0.12s windup: a sigil at the destination, for everyone
	tele_circle(ground(to), 0.6, col_of(dd), float(dd["windup"]))
	m.sfx("portal", h.pos, -6.0, 1.9)
	blink = {"t": float(dd["windup"]), "to": to, "air": air, "vel": h.vel}
	CombatBus.ability_used.emit(h, "blink", "dodge")
	return true

## Never into the abyss: an over-the-abyss destination comes back toward you onto ground (or, in
## the air, you arrive gliding).
func _safe_spot(p: Vector3) -> Vector3:
	var from := h.pos
	var k := 1.0
	while k > 0.0:
		var q := from.lerp(p, k)
		if not m.world.is_void(q.x, q.z) and not m.world.is_block(q.x, q.z):
			return Vector3(q.x, m.world.ground_at(q.x, q.z), q.z)
		k -= 0.1
	return from

func _do_blink() -> void:
	var b := blink
	blink = {}
	if h.downed or h.stun_t > 0.0:
		return
	_land_blink(h.pos, b["to"], true, bool(b.get("air", false)), b.get("vel", Vector3.ZERO))

func _land_blink(from: Vector3, to: Vector3, first: bool, air := false, keep_vel := Vector3.ZERO) -> void:
	var dd := dash_def()
	m.fx.burst(from + Vector3(0, 0.9, 0), col_of(dd), 16, 3.0, 0.3)
	h.teleport(to)
	h.vel = keep_vel if air else Vector3.ZERO
	h.phase_t = maxf(h.phase_t, 0.1)
	m.fx.burst(to + Vector3(0, 0.9, 0), col_of(dd), 16, 3.0, 0.3)
	Feel.dash_sound(m, id, to, h)
	if not first:
		return
	# the residue rune at the departure point bursts 0.6s later: a slow (the kin rider changes it)
	var rp := rider_points(from, to)
	var dbl := 2.0 if rank("dash") >= 3 else 1.0
	var rune := ground(from)
	tele_circle(rune, float(dd["rune_r"]), Feel.cat_color("control"), float(dd["rune_t"]))
	m.later(float(dd["rune_t"]), func():
		if not is_instance_valid(h): return
		var stg := StageSpec.parse({"delivery": {"type": "burst", "origin": "here", "radius": float(dd["rune_r"])},
			"effects": [{"type": "slow", "duration": minf(4.0, float(dd["rune_slow_t"]) * dbl), "strength": minf(0.6, float(dd["rune_slow"]) * dbl)}]}, "", GrammarReport.new())
		run(stg, cx("dash", "blink_rune", rune, {"at": rune, "no_floor": true})))
	if String(rp.get("as", "")) == "blink":
		blink_back = {"t": 1.5, "to": from, "k": 1.0}          # Moon Return
	elif rp.get("repeat") != null:
		blink_back = {"t": 1.0, "to": to, "k": float((rp["repeat"] as PartSpec).params.get("falloff", 0.55))}

# ------------------------------------------------------------------ RMB: Bolt
func rmb_hold_tick(t: float) -> void:
	if t > 0.15 and lance_tele == null:
		lance_tele = tele_lane(h.pos, h.aim_dir(), float(rmb_def()["lance"]["range"]), float(rmb_def()["lance"]["width"]), Feel.cat_color("damage"), 0.0)

func rmb_auto_t() -> float:
	return 1.2

func press_rmb() -> void:
	if lock_t > 0.0 or not vent.is_empty():
		h._ab_feedback("sec", "deny")
		return
	super.press_rmb()

func fire_rmb(c: Dictionary) -> void:
	if lance_tele and is_instance_valid(lance_tele): m.fx.end_telegraph(lance_tele)
	lance_tele = null
	last_variant = String(c["variant"])
	if not spend_rmb(): return
	var sd := rmb_def()
	var ov := over()
	var k := 1.0 + (float(sd.get("over_k", 0.25)) if ov else 0.0)
	if c.get("air", false):
		var sf: Dictionary = sd["starfall"]
		var stg := stage("rmb", {"delivery": {"type": "burst", "origin": "caster", "radius": float(sf["radius"]) * k},
			"effects": [{"type": "damage", "amount": float(sf["dmg"]) * k}, {"type": "push", "strength": float(sf["push"])}]})
		run(stg, cx("rmb", "starfall", h.pos))
		h.vel.y = maxf(h.vel.y, float(sf["lift"]))
		h.gliding = false; h.grounded = false
		h.glide_fuel = minf(1.0, h.glide_fuel + float(sf["cool"]))
		add_heat(float(res_def()["tap"]))
		return
	var through := _through_sigil()
	if c.get("hold", false):
		var ld: Dictionary = sd["lance"]
		var mods: Array = [{"type": "pierce", "count": 5 if rank("sec") >= 3 else 3}]
		if through >= 0.0: mods.append({"type": "chain", "count": 2, "range": 4.5})
		var stg := stage("rmb", {"delivery": {"type": "beam", "range": float(ld["range"]), "width": float(ld["width"])},
			"effects": [{"type": "damage", "amount": float(ld["dmg"]) * k}], "modifiers": mods})
		run(stg, cx("rmb", "lance", aim(), {"no_floor": true}))
		if through >= 0.0: last_variant = "during_e"
		add_heat(float(res_def()["hold"]))
		Feel.cast_sound(m, "beam", "damage", h.pos, h)
		return
	var bd: Dictionary = sd["bolt"]
	var effs := [{"type": "damage", "amount": float(bd["dmg"]) * k}, {"type": "slow", "duration": float(bd["slow_t"]), "strength": float(bd["slow"])}]
	var base := {"delivery": {"type": "projectile", "speed": float(bd["speed"]), "range": float(bd["range"]), "size": 0.2}, "effects": effs}
	if ov: base["modifiers"] = [{"type": "pierce", "count": 1}]
	var c2 := cx("rmb", "bolt", aim())
	if through >= 0.0 and through < float(bd["range"]):
		# a bolt through the Sigil splits into 3 at the rune
		var first := base.duplicate(true)
		first["delivery"]["range"] = maxf(2.0, through)
		var rest := maxf(2.0, float(bd["range"]) - through + 2.0)
		var stg1 := stage("rmb", first)
		c2["on_shot_end"] = func(at: Vector3, why: String, e):
			if why == "expire" and e == null and is_instance_valid(h):
				var sp := base.duplicate(true)
				sp["delivery"]["range"] = rest
				sp["delivery"]["origin"] = "here"
				var md: Array = sp.get("modifiers", [])
				md.append({"type": "split", "count": int(sd["split"]["count"]), "angle": float(sd["split"]["angle"])})
				sp["modifiers"] = md
				var st2 := stage("rmb", sp)
				var c3 := cx("rmb", "bolt_split", at + Vector3(h.aim_dir().x, 0, h.aim_dir().y) * 3.0, {"at": at, "dir": h.aim_dir()})
				run(st2, c3)
				m.fx.ring(at, 1.0, col_of(e_def()), 0.25)
		run(stg1, c2)
		last_variant = "during_e"
	else:
		run(stage("rmb", base), c2)
	add_heat(float(res_def()["tap"]))
	Feel.cast_sound(m, "projectile", "control", h.pos, h)

## How far along the aim line the Sigil is (-1 if the line misses it).
func _through_sigil() -> float:
	if sigil.is_empty():
		return -1.0
	var a := Vector2(h.pos.x, h.pos.z)
	var dir := h.aim_dir()
	var c := Vector2(sigil["pos"].x, sigil["pos"].z)
	var t := (c - a).dot(dir)
	if t < 0.0 or t > 14.0:
		return -1.0
	if (a + dir * t).distance_to(c) > float(sigil["r"]):
		return -1.0
	return t

# ------------------------------------------------------------------ E: Sigil
func in_e() -> bool:
	return not sigil.is_empty()

func e_recastable() -> bool:
	return not sigil.is_empty()

func e_recast() -> bool:
	if sigil.is_empty():
		return false
	var ed := e_def()
	var at: Vector3 = sigil["pos"]
	var r: float = sigil["r"]
	_drop_sigil()
	e_t = 0.0
	if over() and vent.is_empty():
		_flashpoint(at, r)
		return true
	tele_circle(at, r, Feel.cat_color("control"), float(ed["det_t"]))
	m.fx.flash(at + Vector3(0, 0.3, 0), col_of(ed), 1.2, float(ed["det_t"]))
	m.later(float(ed["det_t"]), func():
		if not is_instance_valid(h): return
		var stg := stage("e", {"delivery": {"type": "burst", "origin": "aim", "radius": r},
			"effects": [{"type": "damage", "amount": float(ed["det_dmg"])}, {"type": "lift", "strength": float(ed["det_lift"])}]})
		run(stg, cx("e", "sigil_detonate", at, {"no_floor": true}))
		Feel.shake(m, "t3", h, at))
	h._ab_feedback("k1", "cast")
	last_e = "Detonate"
	return true

## Flashpoint: an Overcharged detonation spends all the Heat. The rune collapses inward for the same
## 0.3s (a bigger, white-gold ring everyone sees), then a payoff burst: more damage and radius, a
## harder lift (a Meteor spikes it), T4 on each foe it catches; Heat drops to 0 with no Vent and the
## Bolt comes straight back.
func _flashpoint(at: Vector3, r0: float) -> void:
	var ed := e_def()
	var fd: Dictionary = ed.get("flash", {})
	res = 0.0
	vent = {}
	was_over = false
	var r := r0 * float(fd.get("r_k", 1.3))
	var hot := res_col().lerp(Color.WHITE, 0.35)
	var dt_ := float(ed["det_t"])
	tele_circle(at, r, hot, dt_)
	m.fx.ring(at, r, Color(hot, 0.9), dt_)
	m.fx.flash(at + Vector3(0, 0.4, 0), hot, 1.8, dt_)
	for i in 10:
		var a := TAU * i / 10.0
		var p := at + Vector3(cos(a) * r, 0.3, sin(a) * r)
		m.fx.burst(p, hot, 3, 9.0, 0.25, 0.0, 1.1, (at + Vector3(0, 0.6, 0) - p).normalized(), 8.0)
	m.sfx("pay_flashpoint", at, 0.0, 1.0)        # the rush in, then the boom on the detonation
	net_ring(at, r, hot)
	h._ab_feedback("k1", "cast")
	last_e = "Flashpoint"
	flashpoints += 1
	m.later(dt_, func():
		if not is_instance_valid(h): return
		var stg := stage("e", {"delivery": {"type": "burst", "origin": "aim", "radius": r},
			"effects": [{"type": "damage", "amount": float(fd.get("dmg", 24.0))}, {"type": "lift", "strength": float(fd.get("lift", 8.5))}]})
		run(stg, cx("e", "flashpoint", at, {"no_floor": true, "hit_extra": {"payoff": true}}))
		var dir := Vector2(at.x - h.pos.x, at.z - h.pos.z)
		payoff_fx(at, "FLASHPOINT", hot, "", dir)
		m.fx.ring(at, r * 1.15, Color(res_col(), 0.9), 0.45)
		m.fx.burst(at + Vector3(0, 0.6, 0), Color("ff9a4a"), 30, 9.0, 0.6, 3.0, 1.5)
		for i in 6:
			m.later(0.05 * i, func(): if is_instance_valid(h): m.fx.burst(at + Vector3(0, 0.4 + 0.7 * i, 0), hot, 8, 2.2, 0.35, -2.0, 1.2))
		# the Bolt is straight back: Lance (or Meteor) the lifted
		ch_rmb = float(rmb_charges()); cd["rmb"] = 0.0; lock_t = 0.0
		h._ab_feedback("sec", "ready"))
	CombatBus.ability_used.emit(h, "flashpoint", "kin")

func cast_e() -> bool:
	var ed := e_def()
	var at := aim_at(float(ed["reach"]))
	var r := float(ed["radius"]) * (1.25 if over() else 1.0)
	_drop_sigil()
	var n := Node3D.new()
	m.add_child(n)
	n.position = at + Vector3(0, 0.08, 0)
	var ring := MeshInstance3D.new(); ring.mesh = Models.flat_quad(r * 2.0)
	ring.material_override = Models.ring_mat(Color(col_of(ed), 0.9), 0.08)
	n.add_child(ring)
	var inner := MeshInstance3D.new(); inner.mesh = Models.flat_quad(r * 1.3)
	inner.material_override = Models.ring_mat(Color(col_of(ed), 0.6), 0.04)
	n.add_child(inner)
	sigil = {"pos": at, "r": r, "t": float(ed["time"]), "node": n}
	e_t = float(ed["time"])
	add_heat(float(res_def()["e"]))
	m.fx.burst(at + Vector3(0, 0.3, 0), col_of(ed), 20, 3.0, 0.4, 0.0)
	Feel.cast_sound(m, "zone", "utility", at, h)
	# the kin's typing rides the rune (a reveal, a shield...): a light zone with only its parts
	var fill := Arch.fill(ed.get("sockets", {}), infusion(), "e", "zone", [], budget_k("e"))
	var effs: Array = (fill["effects"] as Array).filter(func(e): return String(e["type"]) in ["mark", "shield", "slow"])
	if not effs.is_empty():
		var z := StageSpec.parse({"delivery": {"type": "zone", "origin": "aim", "radius": r, "duration": float(ed["time"]), "every": 1.0}, "effects": effs}, "", GrammarReport.new())
		if z: run(z, cx("e", "sigil", at, {"no_floor": true}))
	return true

func _drop_sigil() -> void:
	if not sigil.is_empty() and is_instance_valid(sigil["node"]):
		(sigil["node"] as Node3D).queue_free()
	sigil = {}

# ------------------------------------------------------------------ R: Meteor
func cast_r() -> bool:
	var rd := r_def()
	var at := aim_at(float(rd["reach"]))
	var tell := float(rd["tell"])
	tele_circle(at, float(rd["radius"]), Feel.cat_color("control"), tell)
	var rock := Node3D.new()
	m.add_child(rock)
	var mi := MeshInstance3D.new(); mi.mesh = Models.sphere(0.7, 12)
	mi.material_override = Models.glow_mat(Color("ff7a3d"))
	rock.add_child(mi)
	rock.position = at + Vector3(-3.0, 9.0, 2.0)
	m.sfx("charge", at, 0.0, 0.5)       # the ground rumbles
	meteor = {"at": at, "t": tell, "T": tell, "rock": rock, "over": over()}
	if over():
		res = 0.0                        # Overcharged cast: Heat resets, no Vent
		vent = {}
	r_t = tell + 0.5
	return true

func _meteor_hit() -> void:
	var rd := r_def()
	var at: Vector3 = meteor["at"]
	if is_instance_valid(meteor.get("rock")): (meteor["rock"] as Node3D).queue_free()
	meteor = {}
	var mods: Array = [{"type": "spike", "bonus": float(rd["spike"]), "stun": float(rd["spike_stun"])}]
	if rank("ult") >= 2: mods.append({"type": "repeat", "count": 1, "delay": 0.5, "falloff": 0.5})
	var stg := stage("r", {"delivery": {"type": "burst", "origin": "aim", "radius": float(rd["radius"])},
		"effects": [{"type": "damage", "amount": float(rd["dmg"]) * r_k()}, {"type": "lift", "strength": float(rd["lift"])}], "modifiers": mods})
	run(stg, cx("r", "meteor", at, {"no_floor": true}))
	var burn := StageSpec.parse({"delivery": {"type": "zone", "origin": "aim", "radius": float(rd["radius"]) * 0.8, "duration": float(rd["burn_t"]), "every": 0.5},
		"effects": [{"type": "damage", "amount": float(rd["burn"])}]}, "", GrammarReport.new())
	run(burn, cx("r", "meteor_burn", at, {"no_floor": true}))
	m.fx.burst(at + Vector3(0, 0.5, 0), Color("ff7a3d"), 40, 7.0, 0.7, 6.0, 1.5)
	Feel.shake(m, "leap", h, at)
	m.sfx("boom", at, 2.0, 0.6)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if int(h.slot_lv["ult"]) > 0 and float(cd["r"]) <= 0.0 and dist < float(r_def()["reach"]) and randf() < 0.35:
		h.inp["aim"] = tgt.pos; h.inp["ult"] = true; return
	# a primed Sigil with them in it: Flashpoint. Not Overcharged: detonate now and then (or as it fades)
	if not sigil.is_empty() and tgt.flat_dist(sigil["pos"]) < float(sigil["r"]) + 0.5 and (over() and randf() < 0.9 or randf() < 0.25 or float(sigil["t"]) < 1.5):
		h.inp["sig"] = true; return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist < 9.0 and randf() < 0.35:
		h.inp["aim"] = tgt.pos; h.inp["sig"] = true; return
	# ride the heat: don't fire into a Vent unless they're close (a Vent is a peel)
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and lock_t <= 0.0 and los and dist < 13.0 and (res < 75.0 or dist < 3.0):
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
		if dist > 9.0: bot_hold["rmb"] = float(rmb_def()["hold"]) + 0.1
