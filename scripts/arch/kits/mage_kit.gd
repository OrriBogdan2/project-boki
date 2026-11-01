class_name MageKit
extends ArchKit
## Mage (medium): a tricky, mobile spell duelist (kits4: LeBlanc-style combos, a Sinclair-style
## steerable RMB; ideas only, our names and numbers). docs/ARCHETYPES.md "Kit loops".
##
## - RMB, Guided Bolt: fire on the press; keep holding and it bends toward your cursor (round cover
##   onto a target); it hits harder the longer it flies (10 -> 22 over 1.6s). A hit Runes the target.
## - Passive, Runes and Heat: a second spell on a Runed foe detonates the Rune: a Runeburst (16, root
##   0.5, T4). Casting builds Heat; Overcharged (70+) a detonation is a Flashpoint instead (30, a burst
##   on everyone near, root 0.8, Heat spent with no Vent, the Bolt back). At 100 you Vent.
## - E, Hex: a dodgeable bolt that turns a hunter into a harmless critter for 1.3s (half speed, no
##   attacks, casts, dashes or glides); on a Runed foe it detonates the Rune too.
## - Dash, Blink: 0.12s windup, up to 5.5m (through walls); a sigil stays where you left; dash again
##   within 3s to snap back to it.
## - R, Encore: two mirror images at your sides recast your last spell at once, then echo every Bolt
##   and Hex you cast for 4s (60%).

var vent := {}                 # a Vent winding up: {t}
var lock_t := 0.0              # RMB locked after a Vent
var blink := {}                # Blink's windup: {t, to, from, ex}
var blink_back := {}           # the snap-back window: {t, to, k, node}
var bolts: Array = []          # live Guided Bolts: {pos, dir, t, node, k, steer, hum, seg}
var runes := {}                # foe id -> {e, t, node}: Runes on targets
var orbit: Node3D = null       # the Heat tell: rune motes orbiting the Mage
var was_over := false
var armed_at := -9.0
var encore := {}               # R: {t, nodes, fx}
var last_spell := "bolt"
var detonations := 0           # Runebursts + Flashpoints (tests)
var flashpoints := 0
var hexes := 0                 # Hexes that landed (tests)

func over() -> bool:
	return res >= float(res_def().get("over", 70.0))

func full_ready() -> bool:
	return over()

func res_text() -> String:
	return "%d HOT" % int(res) if over() else "%d" % int(res)

func ready_label() -> String:
	var any := false
	for key in runes:
		if is_instance_valid(runes[key]["e"]): any = true
	if any and over(): return "RUNED  ·  OVERCHARGED: FLASHPOINT"
	if any: return "RUNED  ·  hit it again"
	if over(): return "OVERCHARGED"
	return ""

func add_heat(v: float) -> void:
	add_res(v)
	touch_res(float(res_def().get("wait", 1.2)))
	if res >= res_max() - 0.01 and vent.is_empty():
		_start_vent()

func move_k() -> float:
	return 1.0

func fire_ok_rmb() -> bool:
	return lock_t <= 0.0

## The steer is a hold, not a charge (the bolt's hum is its feedback).
func rmb_charge_full() -> float:
	return 0.0

func _tick(dt: float) -> void:
	var rd := res_def()
	lock_t = maxf(0.0, lock_t - dt)
	if res_wait <= 0.0 and vent.is_empty():
		add_res(-float(rd.get("decay", 18.0)) * dt)
	if not vent.is_empty():
		vent["t"] = float(vent["t"]) - dt
		if float(vent["t"]) <= 0.0:
			_vent()
	if not blink.is_empty():
		blink["t"] = float(blink["t"]) - dt
		if float(blink["t"]) <= 0.0:
			_do_blink()
	if not blink_back.is_empty():
		blink_back["t"] = float(blink_back["t"]) - dt
		if float(blink_back["t"]) <= 0.0: _end_back()
	_tick_bolts(dt)
	_tick_runes_on(dt)
	if not encore.is_empty(): _tick_encore(dt)
	var ov := over() and vent.is_empty()
	if ov and not was_over and m.time - armed_at > 2.0:
		armed_at = m.time
		armed_fx("OVERCHARGED", "")
	was_over = ov
	_tick_orbit()
	net_pulse(dt, ov)

# ---- the Vent: a 0.4s ring collapsing onto you (everyone sees it), then the nova ----
func _start_vent() -> void:
	var rd := res_def()
	vent = {"t": float(rd.get("vent_t", 0.4))}
	tele_circle(h.pos, float(rd.get("vent_r", 3.0)), res_col(), float(rd.get("vent_t", 0.4)))
	m.sfx("warn", h.pos, -2.0, 1.5)
	m.fx.burst(h.pos + Vector3(0, 1.4, 0), Color(1, 1, 1, 0.7), 16, 2.5, 0.4, -3.0)
	net_ring(h.pos, float(rd.get("vent_r", 3.0)), res_col())

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

## The Heat tell on the Mage (everyone sees it): a rune mote per 20 Heat orbiting the waist, calm
## below 70, burning, faster and lit from 70 (Overcharged).
func _tick_orbit() -> void:
	if orbit == null or not is_instance_valid(orbit):
		orbit = own_node()
		for i in 5:
			var d := MeshInstance3D.new()
			d.mesh = Models.box(0.16, 0.16, 0.16)
			d.material_override = Models.glow_mat(Color(Arch.color(id), 0.95))
			d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			orbit.add_child(d)
		var lt := OmniLight3D.new()
		lt.name = "Light"
		lt.light_color = res_col()
		lt.omni_range = 3.0
		orbit.add_child(lt)
	var n := int(ceil(res / 20.0 - 0.01))
	orbit.visible = tells_visible() and n > 0
	if not orbit.visible:
		return
	var sc := float(h.cdat.get("scale", 1.0))
	orbit.global_position = h.position + Vector3(0, 1.05 * sc, 0)
	var ov := over()
	var hot := res_col().lerp(Color("ffb070"), 0.35)
	var a: float = m.time * (5.5 if ov else 2.0)
	for i in 5:
		var d := orbit.get_child(i) as MeshInstance3D
		d.visible = i < n
		var ang := a + TAU * i / 5.0
		var rad := (0.85 if ov else 0.7) * sc
		d.position = Vector3(cos(ang) * rad, 0.15 * sin(m.time * 3.0 + i), sin(ang) * rad)
		d.rotation = Vector3(m.time * 2.0, m.time * 3.0 + i, 0.0)
		d.scale = Vector3.ONE * ((1.4 + 0.25 * sin(m.time * 14.0 + i)) if ov else 1.0)
		d.material_override.set_shader_parameter("color", Color(hot, 1.0) if ov else Color(Arch.color(id), 0.9))
	(orbit.get_node("Light") as OmniLight3D).light_energy = (1.6 + 0.6 * sin(m.time * 12.0)) if ov else 0.0

# ------------------------------------------------------------------ Runes (marks on targets) and detonation
func runed(f: Ent) -> bool:
	return f != null and runes.has(f.get_instance_id()) and is_instance_valid(runes[f.get_instance_id()]["e"])

func _add_rune(f: Ent) -> void:
	var key := f.get_instance_id()
	if runes.has(key):
		runes[key]["t"] = float(res_def().get("rune_t", 4.0))
		return
	var n := Node3D.new()
	n.top_level = true
	var ring := MeshInstance3D.new()
	ring.mesh = Models.flat_quad(1.2)
	ring.material_override = Models.ring_mat(Color(Arch.color(id), 0.95), 0.12)
	n.add_child(ring)
	var gem := MeshInstance3D.new()
	gem.mesh = Models.box(0.22, 0.22, 0.22)
	gem.material_override = solid_mat(Arch.color(id).lightened(0.3))
	gem.rotation = Vector3(PI * 0.25, 0, PI * 0.25)
	n.add_child(gem)
	m.add_child(n)
	runes[key] = {"e": f, "t": float(res_def().get("rune_t", 4.0)), "node": n}
	m.fx.word(f.pos + Vector3(0, 2.3, 0), "RUNED", Arch.color(id), false)
	m.sfx("zap", f.pos, -6.0, 1.6)
	net_ring(f.pos, 1.0, Arch.color(id))

func _clear_rune(key: int) -> void:
	if not runes.has(key): return
	var n: Node3D = runes[key]["node"]
	if is_instance_valid(n): n.queue_free()
	runes.erase(key)

func _tick_runes_on(dt: float) -> void:
	for key in runes.keys():
		var r: Dictionary = runes[key]
		var f: Ent = r["e"]
		r["t"] = float(r["t"]) - dt
		if float(r["t"]) <= 0.0 or not is_instance_valid(f) or f.dead:
			_clear_rune(key)
			continue
		var n: Node3D = r["node"]
		if is_instance_valid(n):
			n.global_position = f.position + Vector3(0, 2.75 if f is Hunter else 1.9, 0)
			n.rotation.y = m.time * 3.0
			n.scale = Vector3.ONE * ((1.15 + 0.15 * sin(m.time * 12.0)) if over() else 1.0)

func teardown() -> void:
	for key in runes.keys(): _clear_rune(key)
	for b in bolts:
		if is_instance_valid(b["node"]): (b["node"] as Node3D).queue_free()
	bolts.clear()
	super.teardown()

## A spell landed on `f`: a Runed foe detonates; a Bolt Runes a fresh one.
func spell_hit(f: Ent, spell: String) -> void:
	if f == null or not is_instance_valid(f) or f.dead or f.team == h.team:
		return
	if runed(f):
		_clear_rune(f.get_instance_id())
		var tgt := f
		m.later(0.02, func(): if is_instance_valid(h) and is_instance_valid(tgt) and not tgt.dead: _detonate(tgt, spell != "hex"))
	elif spell == "bolt":
		_add_rune(f)

## The payoff: a Runeburst, or Overcharged a Flashpoint (all the Heat, a burst on everyone near).
func _detonate(f: Ent, root: bool) -> void:
	var rd := res_def()
	detonations += 1
	var dir := h.dir_to(f)
	if over() and vent.is_empty():
		flashpoints += 1
		res = 0.0; vent = {}; was_over = false
		var hot := res_col().lerp(Color.WHITE, 0.35)
		f.hurt(float(rd["flash_dmg"]) * power("sec"), h, {"src": "abil", "ab": "utility", "tags": ["utility", "flashpoint"], "payoff": true, "crit": true, "root": float(rd["flash_root"]) if root else 0.0, "dr": true})
		for o in foes_in(f.pos, float(rd["flash_r"])):
			if o != f: o.hurt(float(rd["flash_splash"]) * power("sec"), h, {"src": "abil", "ab": "utility", "tags": ["utility", "flashpoint"], "root": float(rd["flash_root"]) * 0.5, "dr": true, "kb": Vector2(o.pos.x - f.pos.x, o.pos.z - f.pos.z).normalized() * 4.0})
		m.sfx("pay_flashpoint", f.pos, 0.0, 1.0)
		payoff_fx(f.pos, "FLASHPOINT", hot, "", dir, f)
		m.fx.ring(f.pos, float(rd["flash_r"]), Color(res_col(), 0.9), 0.45)
		m.fx.burst(f.pos + Vector3(0, 0.6, 0), Color("ff9a4a"), 30, 9.0, 0.6, 3.0, 1.5)
		ch_rmb = float(rmb_charges()); cd["rmb"] = 0.0; lock_t = 0.0
		h._ab_feedback("sec", "ready")
	else:
		f.hurt(float(rd["burst_dmg"]) * power("sec"), h, {"src": "abil", "ab": "utility", "tags": ["utility", "runeburst"], "payoff": true, "crit": true, "root": float(rd["burst_root"]) if root else 0.0, "dr": true})
		m.sfx("pay_flashpoint", f.pos, -3.0, 1.45)
		payoff_fx(f.pos, "RUNEBURST", Arch.color(id).lightened(0.2), "", dir, f)
	CombatBus.ability_used.emit(h, "runeburst", "secondary")

# ------------------------------------------------------------------ dash: Blink (snap back within 3s)
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if not blink_back.is_empty():
		# snap back to the sigil you left
		var to: Vector3 = blink_back["to"]
		var from := h.pos
		_end_back()
		_land_blink(from, to, false)
		m.fx.word(h.pos + Vector3(0, 2.3, 0), "SNAP BACK", col_of(dd), false)
		st["last_dash"] = "back"
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
	st["last_dash"] = "blink"
	CombatBus.ability_used.emit(h, "blink", "dodge")
	return true

## Never into the abyss: an over-the-abyss destination comes back toward you onto ground.
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
	if h.downed or h.stun_t > 0.0 or Hex.active(h):
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
	net_bolt(from + Vector3(0, 0.9, 0), to + Vector3(0, 0.9, 0), col_of(dd))
	if not first:
		return
	# the sigil you leave: it slows foes on it 0.6s later, and for 3s you can snap back to it
	var rp := rider_points(from, to)
	var dbl := 2.0 if rank("dash") >= 3 else 1.0
	var rune := ground(from)
	tele_circle(rune, float(dd["rune_r"]), Feel.cat_color("control"), float(dd["rune_t"]))
	m.later(float(dd["rune_t"]), func():
		if not is_instance_valid(h): return
		var stg := StageSpec.parse({"delivery": {"type": "burst", "origin": "here", "radius": float(dd["rune_r"])},
			"effects": [{"type": "slow", "duration": minf(4.0, float(dd["rune_slow_t"]) * dbl), "strength": minf(0.6, float(dd["rune_slow"]) * dbl)}]}, "", GrammarReport.new())
		run(stg, cx("dash", "blink_rune", rune, {"at": rune, "no_floor": true})))
	var n := own_node()
	var ring := MeshInstance3D.new()
	ring.mesh = Models.flat_quad(1.6)
	ring.material_override = Models.ring_mat(Color(col_of(dd), 0.9), 0.1)
	n.add_child(ring)
	n.global_position = rune + Vector3(0, 0.1, 0)
	blink_back = {"t": float(dd.get("back_t", 3.0)), "to": rune, "node": n}
	if rp.get("repeat") != null:
		blink_back["t"] = float(blink_back["t"]) + 1.0

func _end_back() -> void:
	var n: Node3D = blink_back.get("node")
	if n and is_instance_valid(n):
		self_nodes.erase(n)
		n.queue_free()
	blink_back = {}

# ------------------------------------------------------------------ RMB: Guided Bolt
## Fires on the press; while you keep holding, the bolt bends toward your cursor.
func press_rmb() -> void:
	if busy() or lock_t > 0.0 or not vent.is_empty():
		h._ab_feedback("sec", "deny")
		return
	if rmb_down:
		return
	var air := not h.grounded or h.gliding
	if not spend_rmb(): return
	rmb_down = true
	rmb_t = 0.0
	rmb_ctx = {"air": air, "e": false, "r": not encore.is_empty(), "full": over()}
	if air:
		_starfall()
		rmb_down = false
		last_variant = "air"
		return
	last_variant = "full" if over() else ("during_r" if not encore.is_empty() else "tap")
	last_spell = "bolt"
	_spawn_bolt(h.pos + Vector3(h.aim_dir().x * 0.6, 1.05, h.aim_dir().y * 0.6), h.aim_dir(), 1.0, true)
	add_heat(float(res_def()["tap"]))
	if not encore.is_empty(): _echo("bolt")

func fire_rmb(_c: Dictionary) -> void:
	pass         # (the bolt went on the press; letting go just stops the steering)

func rmb_auto_t() -> float:
	return float(rmb_def()["bolt"]["life"]) + 0.2

func _spawn_bolt(at: Vector3, dir: Vector2, k: float, steer: bool) -> void:
	var n := own_node()
	var core := MeshInstance3D.new()
	core.mesh = Models.sphere(0.22, 12)
	core.material_override = Models.glow_mat(Color(col_of(rmb_def()), 1.0))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(core)
	var lt := OmniLight3D.new()
	lt.light_color = col_of(rmb_def())
	lt.light_energy = 1.2
	lt.omni_range = 2.2
	n.add_child(lt)
	n.global_position = at
	bolts.append({"pos": at, "dir": dir.normalized(), "t": 0.0, "node": n, "k": k, "steer": steer, "hum": 0.0, "seg": 0.0, "last": at})
	m.sfx("zap", h.pos, -3.0, 0.8)
	m.sfx("ab_throw", h.pos, -6.0, 1.5)
	m.fx.flash(at, col_of(rmb_def()), 0.5, 0.06)

func _tick_bolts(dt: float) -> void:
	if bolts.is_empty():
		return
	var bd: Dictionary = rmb_def()["bolt"]
	var steering := rmb_down and held("rmb")
	var a := aim()
	for b in bolts.duplicate():
		var n: Node3D = b["node"]
		b["t"] = float(b["t"]) + dt
		var p: Vector3 = b["pos"]
		var dir: Vector2 = b["dir"]
		if steering and bool(b["steer"]):
			# bend toward the cursor
			var want := Vector2(a.x - p.x, a.z - p.z)
			if want.length() > 0.3:
				var ang := dir.angle_to(want.normalized())
				var turn := float(bd["turn"]) * (1.3 if rank("sec") >= 3 else 1.0) * dt
				dir = dir.rotated(clampf(ang, -turn, turn))
				b["dir"] = dir
		var q := p + Vector3(dir.x, 0, dir.y) * float(bd["speed"]) * dt
		var gq: float = m.world.ground_at(q.x, q.z)
		var fk := clampf(float(b["t"]) / float(bd["ramp"]), 0.0, 1.0)
		var done: bool = float(b["t"]) >= float(bd["life"]) or m.world.is_block(q.x, q.z) or gq > p.y - 0.3
		if not done:
			p = q
			for f in foes_in(p - Vector3(0, 1.0, 0), 0.75, 2.0):
				_bolt_hit(f, b, fk)
				done = true
				break
		b["pos"] = p
		if is_instance_valid(n):
			n.global_position = p
			n.scale = Vector3.ONE * (0.8 + 0.9 * fk)
		# the hum climbs as it flies; a trail of sparks
		b["hum"] = float(b["hum"]) - dt
		if float(b["hum"]) <= 0.0:
			b["hum"] = 0.12
			m.sfx("ab_whirr", p, lerpf(-14.0, -7.0, fk), lerpf(1.0, 1.9, fk))
		m.fx.burst(p, col_of(rmb_def()), 1, 0.6, 0.25, 0.0, 0.6 + 0.6 * fk)
		b["seg"] = float(b["seg"]) - dt
		if float(b["seg"]) <= 0.0:
			b["seg"] = 0.1
			net_bolt(b["last"], p, col_of(rmb_def()))        # remote players see the path
			b["last"] = p
		if done:
			if is_instance_valid(n):
				m.fx.burst(p, col_of(rmb_def()), 10, 3.0, 0.3)
				self_nodes.erase(n)
				n.queue_free()
			bolts.erase(b)

func _bolt_hit(f: Ent, b: Dictionary, fk: float) -> void:
	var bd: Dictionary = rmb_def()["bolt"]
	var ok := 1.0 + (float(rmb_def().get("over_k", 0.25)) if over() else 0.0)
	var dmg := lerpf(float(bd["dmg"][0]), float(bd["dmg"][1]), fk) * float(b["k"]) * ok
	var stg := stage("rmb", {"delivery": {"type": "burst", "origin": "here", "radius": 0.0},
		"effects": [{"type": "damage", "amount": dmg}, {"type": "slow", "duration": float(bd["slow_t"]), "strength": float(bd["slow"])}]})
	KinExec.apply_foe(stg.effects, f, cx("rmb", "guided_bolt", f.pos, {"at": f.pos, "dir": b["dir"]}), f.pos, stg)
	m.fx.ring(f.pos, 0.8 + 0.6 * fk, col_of(rmb_def()), 0.2)
	m.sfx("ab_hit", f.pos, -4.0, lerpf(1.3, 0.9, fk))
	spell_hit(f, "bolt")

## Starfall (in the air): a bolt into the ground under you, a lift and a cooler glider.
func _starfall() -> void:
	var sf: Dictionary = rmb_def()["starfall"]
	var stg := stage("rmb", {"delivery": {"type": "burst", "origin": "caster", "radius": float(sf["radius"])},
		"effects": [{"type": "damage", "amount": float(sf["dmg"])}, {"type": "push", "strength": float(sf["push"])}]})
	run(stg, cx("rmb", "starfall", h.pos))
	h.vel.y = maxf(h.vel.y, float(sf["lift"]))
	h.gliding = false; h.grounded = false
	h.glide_fuel = minf(1.0, h.glide_fuel + float(sf["cool"]))
	add_heat(float(res_def()["tap"]))

# ------------------------------------------------------------------ E: Hex
func cast_e() -> bool:
	last_spell = "hex"
	_hex_bolt(h.pos + Vector3(0, 1.0, 0), aim(), 1.0)
	add_heat(float(res_def()["e"]))
	if not encore.is_empty(): _echo("hex")
	return true

func _hex_bolt(_from: Vector3, at: Vector3, k: float) -> void:
	var ed := e_def()
	var stg := stage("e", {"delivery": {"type": "projectile", "speed": float(ed["speed"]), "range": float(ed["range"]), "size": 0.26},
		"effects": [{"type": "damage", "amount": float(ed["dmg"]) * k}]})
	run(stg, cx("e", "hex", at, {"on_foe": func(f: Ent, _c: Dictionary): _hex_hit(f, k)}))
	m.sfx("portal", h.pos, -3.0, 1.4)
	m.fx.flash(h.pos + Vector3(h.aim_dir().x * 0.6, 1.1, h.aim_dir().y * 0.6), Color("e2b8ff"), 0.6, 0.08)

func _hex_hit(f: Ent, k: float) -> void:
	var ed := e_def()
	spell_hit(f, "hex")
	if f is Hunter:
		hexes += 1
		Hex.apply(f as Hunter, float(ed["time"]) * k + (0.3 if rank("kin") >= 3 else 0.0))
	elif is_instance_valid(f) and not f.dead:
		f.hurt(0.1, h, {"stun": float(ed["mob_stun"]) * k, "src": "abil", "ab": "k1", "tags": ["k1", "hex"]})

# ------------------------------------------------------------------ R: Encore
func cast_r() -> bool:
	var rd := r_def()
	var t := float(rd["time"]) * r_dur_k()
	var nodes: Array = []
	for i in 2:
		var n := own_node()
		var orb := MeshInstance3D.new()
		orb.mesh = Models.sphere(0.3, 12)
		orb.material_override = Models.glow_mat(Color(col_of(rd), 0.9))
		n.add_child(orb)
		nodes.append(n)
	encore = {"t": t, "nodes": nodes, "fx": 0.0}
	r_t = t
	_place_mirrors()
	for n in nodes:
		m.fx.burst((n as Node3D).global_position, col_of(rd), 20, 4.0, 0.4, -1.0, 1.2)
		net_ring((n as Node3D).global_position, 1.2, col_of(rd))
	m.sfx("bond", h.pos, -3.0, 1.4)
	m.sfx("portal", h.pos, -2.0, 0.8)
	m.fx.word(h.pos + Vector3(0, 2.6, 0), "ENCORE", col_of(rd), true)
	# the mirrors recast your last spell straight away, at full power
	_echo(last_spell, 1.0)
	return true

func _mirror_spots() -> Array:
	var d := h.aim_dir()
	var side := Vector2(-d.y, d.x)
	var off := float(r_def()["offset"])
	return [h.pos + Vector3(side.x, 0, side.y) * off + Vector3(0, 1.0, 0), h.pos - Vector3(side.x, 0, side.y) * off + Vector3(0, 1.0, 0)]

func _place_mirrors() -> void:
	var sp := _mirror_spots()
	var nodes: Array = encore.get("nodes", [])
	for i in nodes.size():
		if is_instance_valid(nodes[i]): (nodes[i] as Node3D).global_position = sp[i]

func _tick_encore(dt: float) -> void:
	encore["t"] = float(encore["t"]) - dt
	_place_mirrors()
	encore["fx"] = float(encore["fx"]) - dt
	if float(encore["fx"]) <= 0.0 and tells_visible():
		encore["fx"] = 0.12
		for p in _mirror_spots():
			m.fx.ghost(Vector3(p.x, h.position.y, p.z), h.face, Color(col_of(r_def()), 0.8), float(h.cdat["scale"]))
	if float(encore["t"]) <= 0.0:
		for n in encore.get("nodes", []):
			if is_instance_valid(n):
				m.fx.burst((n as Node3D).global_position, col_of(r_def()), 12, 3.0, 0.3)
				self_nodes.erase(n)
				(n as Node3D).queue_free()
		encore = {}

## The mirrors recast a spell from their spots, 0.2s later (at `k`, 60% by default).
func _echo(spell: String, k := -1.0) -> void:
	var kk := float(r_def()["echo_k"]) if k < 0.0 else k
	m.later(0.2, func():
		if not is_instance_valid(h) or h.downed: return
		for p in _mirror_spots():
			var dir := Vector2(aim().x - p.x, aim().z - p.z).normalized()
			if spell == "hex":
				var stg := stage("e", {"delivery": {"type": "projectile", "origin": "here", "speed": float(e_def()["speed"]), "range": float(e_def()["range"]), "size": 0.22},
					"effects": [{"type": "damage", "amount": float(e_def()["dmg"]) * kk}]})
				run(stg, cx("e", "hex_echo", aim(), {"at": p, "dir": dir, "on_foe": func(f: Ent, _c: Dictionary): _hex_hit(f, kk)}))
			else:
				_spawn_bolt(p, dir, kk, true)
			m.fx.flash(p, col_of(r_def()), 0.5, 0.06))

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if int(h.slot_lv["ult"]) > 0 and float(cd["r"]) <= 0.0 and tgt is Hunter and los and dist < 10.0 and randf() < 0.35:
		h.inp["aim"] = tgt.pos; h.inp["ult"] = true; return
	# Hex a rival hunter (always worth it on a Runed one: it detonates)
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and tgt is Hunter and los and dist < float(e_def()["range"]) - 1.0 and (runed(tgt) or randf() < 0.3):
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0); h.inp["sig"] = true; return
	# a Guided Bolt, steered onto them (the bot's aim follows the target while it holds)
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and lock_t <= 0.0 and dist < 16.0 and (res < 75.0 or dist < 3.0):
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
		bot_hold["rmb"] = clampf(dist / float(rmb_def()["bolt"]["speed"]) + 0.3, 0.4, 1.6)
	# Blink out when it's going badly; snap back once it's safe
	if int(h.slot_lv["dash"]) > 0:
		if blink_back.is_empty() and h.dashes >= 1.0 and dist < 4.0 and h.hp < h.max_hp * 0.5 and randf() < 0.5:
			var away := -h.dir_to(tgt)
			h.inp["aim"] = h.pos + Vector3(away.x, 0, away.y) * 5.0
			h.inp["dash"] = true
		elif not blink_back.is_empty() and h.hp > h.max_hp * 0.55 and float(blink_back["t"]) < 1.5 and randf() < 0.4:
			h.inp["dash"] = true
