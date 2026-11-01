class_name MageKit
extends ArchKit
## Mage (medium): Blink, Overload (Heat and the Vent), Bolt (Lance, Starfall, split through the
## Sigil, Overcharged), Sigil (recast to detonate), Meteor. docs/ARCHETYPES.md §6.3.

var sigil := {}                # {pos, r, t, node}
var vent := {}                 # a Vent winding up: {t}
var lock_t := 0.0              # RMB locked after a Vent
var lance_tele: Node3D = null
var blink := {}                # Blink's windup: {t, to, from, ex}
var blink_back := {}           # Moon Return / echo recast window: {t, to, k}
var meteor := {}

func over() -> bool:
	return res >= float(res_def().get("over", 70.0))

func full_ready() -> bool:
	return over()

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
	if not meteor.is_empty():
		meteor["t"] = float(meteor["t"]) - dt
		var mt: Node3D = meteor.get("rock")
		if mt and is_instance_valid(mt):
			var k := 1.0 - clampf(float(meteor["t"]) / float(meteor["T"]), 0.0, 1.0)
			mt.position = (meteor["at"] as Vector3) + Vector3(-3.0, 9.0, 2.0) * (1.0 - k)
		if float(meteor["t"]) <= 0.0:
			_meteor_hit()

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
	tele_circle(at, r, Feel.cat_color("control"), float(ed["det_t"]))
	m.fx.flash(at + Vector3(0, 0.3, 0), col_of(ed), 1.2, float(ed["det_t"]))
	_drop_sigil()
	e_t = 0.0
	m.later(float(ed["det_t"]), func():
		if not is_instance_valid(h): return
		var k := 1.25 if over() else 1.0
		var stg := stage("e", {"delivery": {"type": "burst", "origin": "aim", "radius": r},
			"effects": [{"type": "damage", "amount": float(ed["det_dmg"]) * k}, {"type": "lift", "strength": float(ed["det_lift"])}]})
		run(stg, cx("e", "sigil_detonate", at, {"no_floor": true}))
		Feel.shake(m, "t3", h, at))
	h._ab_feedback("k1", "cast")
	last_e = "Detonate"
	return true

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
	if not sigil.is_empty() and tgt.flat_dist(sigil["pos"]) < float(sigil["r"]) and randf() < 0.6:
		h.inp["sig"] = true; return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist < 9.0 and randf() < 0.35:
		h.inp["aim"] = tgt.pos; h.inp["sig"] = true; return
	# ride the heat: don't fire into a Vent unless they're close (a Vent is a peel)
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and lock_t <= 0.0 and los and dist < 13.0 and (res < 75.0 or dist < 3.0):
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
		if dist > 9.0: bot_hold["rmb"] = float(rmb_def()["hold"]) + 0.1
