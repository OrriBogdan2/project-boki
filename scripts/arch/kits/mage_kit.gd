class_name MageKit
extends ArchKit
## Vireo (archetype id "mage", light): the storm-kite runner. docs/heroes/mage.md has the per-slot
## table and the research notes.
##
## Loop: every hit loads a Spark on the target (4 = Live, pips ring over them everyone sees) ->
## Wirerun (hold to stretch the lane, let go to streak, shots pass through you) through a Live foe is
## a Blowout: big damage, their Sparks spent, your dash back at once. Coilshot throws a foe into a
## wall or another foe (stun) and drops a charge mote that also gives the dash back; Skycall flings
## and grounds a crowd (no dashing) and can steal a rival's mote. A knock heals you.

var sparks := {}               # foe id -> {e, n, t, node, pips}
var wire := {}                 # Wirerun's lane growing: {t, tele, end}
var motes: Array = []          # charge motes: {pos, t, node, owner}
var strikes: Array = []        # Skycall's marked spots: {at, t, dir, tele}
var coil_tele: Node3D = null
var knocked := {}              # foes I already got the knock heal for
var blowouts := 0              # tests and the demo
var slams := 0
var mote_pickups := 0
var last_dash_kind := ""

func full_ready() -> bool:
	for k in sparks:
		if int(sparks[k]["n"]) >= int(res_def()["max"]):
			return true
	return false

func res_text() -> String:
	var best := 0
	for k in sparks: best = maxi(best, int(sparks[k]["n"]))
	return "%d/%d" % [best, int(res_def()["max"])]

func res_frac() -> float:
	var best := 0
	for k in sparks: best = maxi(best, int(sparks[k]["n"]))
	return float(best) / float(res_def()["max"])

func ready_label() -> String:
	return "LIVE FOE: WIRERUN THROUGH" if full_ready() else ""

func live(f: Ent) -> bool:
	var s = sparks.get(f.get_instance_id())
	return s != null and int(s["n"]) >= int(res_def()["max"])

func spark_n(f: Ent) -> int:
	var s = sparks.get(f.get_instance_id())
	return int(s["n"]) if s != null else 0

# ------------------------------------------------------------------ Sparks
func add_spark(f: Ent, n := 1) -> void:
	if f == null or not is_instance_valid(f) or f.dead or f.team == h.team:
		return
	if f is Hunter and (f as Hunter).downed:
		return
	var key := f.get_instance_id()
	var rd := res_def()
	var s: Dictionary = sparks.get(key, {"e": f, "n": 0, "t": 0.0, "node": null})
	var was := int(s["n"])
	s["n"] = mini(int(rd["max"]), was + n)
	s["t"] = float(rd["dur"])
	sparks[key] = s
	if int(s["n"]) >= int(rd["max"]) and was < int(rd["max"]):
		m.sfx("ab_ready", f.pos, -3.0, 1.9)
		m.fx.ring(f.pos, 1.3, res_col(), 0.3)
		m.fx.word(f.pos + Vector3(0, 2.5, 0), "LIVE", res_col(), false)
		net_ring(f.pos, 1.3, res_col())
		if h.is_local(): h._ab_feedback("dash", "ready")

func clear_sparks(f: Ent) -> void:
	var key := f.get_instance_id()
	if sparks.has(key):
		_free_pips(sparks[key])
		sparks.erase(key)

func _free_pips(s: Dictionary) -> void:
	var n = s.get("node")
	if n != null and is_instance_valid(n):
		self_nodes.erase(n)
		(n as Node).queue_free()

func _tick_sparks(dt: float) -> void:
	for key in sparks.keys():
		var s: Dictionary = sparks[key]
		var f: Ent = s["e"]
		s["t"] = float(s["t"]) - dt
		if not is_instance_valid(f) or f.dead or float(s["t"]) <= 0.0 or (f is Hunter and (f as Hunter).downed):
			_free_pips(s)
			sparks.erase(key)
			continue
		var is_live := int(s["n"]) >= int(res_def()["max"])
		var node: Node3D = s["node"]
		if node == null or not is_instance_valid(node):
			node = own_node()
			var pips: Array = []
			for i in 4:
				var p := MeshInstance3D.new()
				p.mesh = Models.crystal(0.06, 0.1, 4)
				p.material_override = Models.glow_mat(Color(res_col(), 1.0))
				p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.add_child(p)
				pips.append(p)
			s["node"] = node
			s["pips"] = pips
		node.visible = f.visible
		var top := 2.2 * (float((f as Hunter).cdat.get("scale", 1.0)) if f is Hunter else 0.8)
		node.global_position = f.position + Vector3(0, top, 0)
		var a: float = m.time * (7.0 if is_live else 2.0)
		var pips2: Array = s["pips"]
		for i in pips2.size():
			var p: MeshInstance3D = pips2[i]
			p.visible = i < int(s["n"])
			var ang := a + TAU * i / 4.0
			p.position = Vector3(cos(ang) * 0.42, 0.04 * sin(m.time * 9.0 + i), sin(ang) * 0.42)
			p.rotation = Vector3(m.time * 5.0, m.time * 3.0, 0)
			p.scale = Vector3.ONE * ((1.5 + 0.2 * sin(m.time * 12.0 + i)) if is_live else 1.0)
		if is_live and int(m.time * 9.0) != int((m.time - dt) * 9.0):
			m.fx.bolt(f.position + Vector3(0, top - 0.2, 0), ground(f.pos) + Vector3(randf_range(-0.4, 0.4), 0.05, randf_range(-0.4, 0.4)), res_col())

func _tick(dt: float) -> void:
	_tick_sparks(dt)
	_tick_motes(dt)
	_tick_strikes(dt)
	if not wire.is_empty():
		_tick_wire(dt)
	if coil_tele and is_instance_valid(coil_tele):
		if rmb_down:
			var k := clampf(rmb_t / float(rmb_def()["hold"]), 0.0, 1.0)
			m.fx.aim_telegraph(coil_tele, h.pos, h.aim_dir())
			m.fx.telegraph_progress(coil_tele, k)
		else:
			m.fx.end_telegraph(coil_tele)
			coil_tele = null
	net_pulse(dt, full_ready())

func teardown() -> void:
	super.teardown()
	sparks.clear()
	for mt in motes:
		if mt["node"] != null and is_instance_valid(mt["node"]): (mt["node"] as Node).queue_free()
	motes.clear()
	for s in strikes:
		if s["tele"] != null and is_instance_valid(s["tele"]): m.fx.end_telegraph(s["tele"])
	strikes.clear()
	_end_wire()

# ------------------------------------------------------------------ passive: weapon hits, knocks
func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team or String(o.get("src", "")) == "burn":
		return
	if String(o.get("src", "")) == "shot" and not o.has("ab"):
		add_spark(t)
	if t is Hunter and ((t as Hunter).downed or t.hp <= 0.0) and not knocked.has(t.get_instance_id()):
		knocked[t.get_instance_id()] = true
		h.heal(h.max_hp * float(res_def()["knock_heal"]))
		m.fx.ring(h.pos, 1.3, Color("8ff0a0"), 0.3)
		m.fx.word(h.pos + Vector3(0, 2.4, 0), "+KNOCK", Color("8ff0a0"), false)

# ------------------------------------------------------------------ dash: Wirerun
func dash_charge() -> float:
	return clampf(float(wire["t"]) / float(dash_def()["hold"]), 0.0, 1.0) if not wire.is_empty() else -1.0

func wire_len(t: float) -> float:
	var dd := dash_def()
	return lerpf(float(dd["dist"][0]), float(dd["dist"][1]), clampf(t / float(dd["hold"]), 0.0, 1.0))

func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if use_ex:
		# the long air dash / extra dash: a plain streak that still lets shots through
		if not spend_dash(true): return true
		travel(float(h.cdat.get("ex_dist", 5.0)), float(h.cdat.get("ex_time", 0.2)), {"invuln": 0.1, "phase": 1.0, "trail": "roll"}, true)
		last_dash_kind = "ex"
		return true
	if h.dashes < 1.0:
		h._ab_feedback("dash", "deny")
		return true
	if not wire.is_empty():
		return true
	var tele := tele_lane(h.pos, h.aim_dir(), 1.0, 0.9, col_of(dd), 0.0)
	var endc: Node3D = m.fx.telegraph_circle(h.pos, 0.7, Color(col_of(dd), 0.9))
	wire = {"t": 0.0, "tele": tele, "end": endc}
	play("mage_dash")
	m.sfx("zap", h.pos, -8.0, 0.7)
	return true

func _end_wire() -> void:
	if wire.is_empty(): return
	for k in ["tele", "end"]:
		var n = wire.get(k)
		if n != null and is_instance_valid(n): m.fx.end_telegraph(n)
	wire = {}

func _tick_wire(dt: float) -> void:
	var dd := dash_def()
	wire["t"] = float(wire["t"]) + dt
	var t := float(wire["t"])
	if h.downed or h.stun_t > 0.0 or h.root_t > 0.0 or KitStatus.grounded(h):
		_end_wire()
		return
	var d := h.aim_dir()
	var L := wire_len(t)
	var tele: Node3D = wire["tele"]
	if is_instance_valid(tele):
		tele.set_meta("len", L)
		tele.scale = Vector3(1.0, 1.0, L)
		m.fx.aim_telegraph(tele, h.pos, d)
		m.fx.telegraph_progress(tele, clampf(t / float(dd["hold"]), 0.0, 1.0))
	var endc: Node3D = wire["end"]
	if is_instance_valid(endc):
		endc.global_position = h.pos + Vector3(d.x * L, 0.07, d.y * L)
	if not held("dash") or t >= float(dd["hold"]) + 0.6:
		_end_wire()
		_run(L, d)

func _run(L: float, d: Vector2) -> void:
	var dd := dash_def()
	if not spend_dash(false):
		return
	var time := float(dd["time"]) * L / 5.5
	travel(L, time, {"invuln": time + 0.05, "phase": 1.0, "trail": "roll", "dir": d})
	h.phase_t = maxf(h.phase_t, time + 0.05)
	last_dash_kind = "wire"
	play("mage_dash_go")
	var dmg := float(dd["dmg"]) * (2.0 if rank("dash") >= 3 else 1.0)
	h.dash_pass = {"hit": {}, "w": float(dd["width"]) + 0.6, "kx": func(f: Ent): _wire_hit(f, dmg)}
	var a := h.pos + Vector3(0, 0.9, 0)
	var b := a + Vector3(d.x * L, 0, d.y * L)
	m.fx.bolt(a, b, col_of(dd))
	net_bolt(a, b, col_of(dd))
	m.sfx("zap", h.pos, -2.0, 1.6)

func _wire_hit(f: Ent, dmg: float) -> void:
	if not is_instance_valid(f) or f.dead: return
	var was_live := live(f)
	f.hurt(dmg * m.dmg_mult(h) * power("dash"), h, {"src": "abil", "ab": "dodge", "tags": ["dodge"]})
	m.fx.burst(f.pos + Vector3(0, 0.9, 0), res_col(), 10, 3.5, 0.3)
	if was_live and is_instance_valid(f) and not f.dead:
		_blowout(f)

func _blowout(f: Ent) -> void:
	var rd := res_def()
	var dmg := (float(rd["blow_dmg"]) + float(rd["blow_pct"]) * f.max_hp) * power("dash")
	clear_sparks(f)
	blowouts += 1
	f.hurt(dmg, h, {"src": "abil", "ab": "dodge", "tags": ["dodge", "blowout"], "payoff": true, "crit": true})
	h.dashes = h.max_dashes()                 # the dash comes straight back
	h.dash_buf = 0.0
	var col := res_col()
	m.fx.bolt(f.pos + Vector3(0, 3.4, 0), f.pos + Vector3(0, 0.1, 0), col)
	payoff_fx(f.pos, "BLOWOUT", col, "", h.dir_to(f), f)
	m.sfx("zap", f.pos, 0.0, 0.55)           # its own voice: a thunder crack under a rising zap
	m.sfx("boom", f.pos, -4.0, 1.4)
	m.later(0.07, func(): m.sfx("zap", f.pos, -3.0, 1.9))
	if h.is_local(): h._ab_feedback("dash", "ready")

# ------------------------------------------------------------------ RMB: Coilshot
func rmb_hold_tick(t: float) -> void:
	if t > 0.1 and (coil_tele == null or not is_instance_valid(coil_tele)):
		coil_tele = tele_lane(h.pos, h.aim_dir(), float(rmb_def()["coil"]["range"][1]), 0.5, col_of(rmb_def()), 0.0)

func rmb_charge_full() -> float:
	return float(rmb_def()["hold"])

func rmb_auto_t() -> float:
	return float(rmb_def()["hold"]) + 0.8

func fire_rmb(c: Dictionary) -> void:
	if coil_tele and is_instance_valid(coil_tele): m.fx.end_telegraph(coil_tele)
	coil_tele = null
	var sd := rmb_def()
	if not spend_rmb(): return
	var held_t := float(c["t"])
	var min_t := float(sd["min_t"])
	var k := clampf((held_t - min_t) / (float(sd["hold"]) - min_t), 0.0, 1.0)
	last_variant = "hold" if k > 0.5 else "tap"
	play("mage_rmb")
	var wait := maxf(0.0, min_t - held_t)
	if wait > 0.0:
		m.later(wait, func(): if is_instance_valid(h) and not h.downed: _coil(k))
	else:
		_coil(k)

func _coil(k: float) -> void:
	var cd_ := rmb_def()["coil"] as Dictionary
	var dir := h.aim_dir()
	var dmg := lerpf(float(cd_["dmg"][0]), float(cd_["dmg"][1]), k)
	var rng := lerpf(float(cd_["range"][0]), float(cd_["range"][1]), k)
	var push := lerpf(float(cd_["push"][0]), float(cd_["push"][1]), k)
	if rank("sec") >= 3: dmg *= 1.2
	var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": float(cd_["speed"]), "range": rng, "size": 0.2},
		"effects": [{"type": "damage", "amount": dmg}, {"type": "push", "strength": push, "from": "caster"}]})
	var done := {"hit": false}
	run(stg, cx("rmb", "coilshot", aim(), {"on_foe": func(f: Ent, _c: Dictionary):
		if not done["hit"]:
			done["hit"] = true
			_coil_hit(f, dir, k)}))
	m.fx.flash(h.pos + Vector3(dir.x * 0.8, 1.1, dir.y * 0.8), col_of(rmb_def()), 0.9, 0.08)
	m.sfx("zap", h.pos, -1.0, 0.6 + 0.4 * (1.0 - k))
	m.sfx("rail", h.pos, -4.0, 1.2)
	Feel.shake(m, "t2", h, h.pos)

func _coil_hit(f: Ent, dir: Vector2, k: float) -> void:
	if not is_instance_valid(f) or f.dead: return
	var cd_ := rmb_def()["coil"] as Dictionary
	add_spark(f)
	m.fx.ring(f.pos, 1.0, col_of(rmb_def()), 0.25)
	# thrown into a wall or another foe: stunned (so is the one it hits)
	var reach := 1.6 + 1.4 * k
	var other: Ent = null
	for o in foes_in(f.pos + Vector3(dir.x, 0, dir.y) * (f.r + reach * 0.6), reach * 0.6):
		if o != f:
			other = o
			break
	if other != null or terrain_behind(f, dir, reach):
		slams += 1
		var stn := float(cd_["stun"])
		f.hurt(0.1, h, {"src": "abil", "ab": "utility", "tags": ["utility", "slam"], "stun": stn, "dr": true})
		m.fx.word(f.pos + Vector3(0, 2.2, 0), "SLAMMED", col_of(rmb_def()), false)
		m.fx.ring(f.pos, 1.6, Color("ffffff"), 0.25)
		m.sfx("ab_wall", f.pos, -2.0, 1.3)
		if other != null:
			other.hurt(0.1, h, {"src": "abil", "ab": "utility", "tags": ["utility", "slam"], "stun": stn, "dr": true})
			add_spark(other)
	if f is Hunter:
		m.later(float(cd_["mote_t"]), func(): _drop_mote(f))

func _drop_mote(f: Ent) -> void:
	if not is_instance_valid(f) or not is_instance_valid(h) or h.downed:
		return
	var cd_ := rmb_def()["coil"] as Dictionary
	var at := ground(f.pos)
	var n := own_node()
	var core := MeshInstance3D.new()
	core.mesh = Models.sphere(0.2, 10)
	core.material_override = Models.glow_mat(Color(col_of(rmb_def()).lightened(0.3), 1.0))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(core)
	var lt := OmniLight3D.new()
	lt.light_color = col_of(rmb_def()); lt.omni_range = 2.2; lt.light_energy = 1.2
	n.add_child(lt)
	n.global_position = at + Vector3(0, 0.6, 0)
	motes.append({"pos": at, "t": float(cd_["mote_life"]), "node": n, "owner": h})
	m.fx.ring(at, float(cd_["mote_r"]) + 0.2, col_of(rmb_def()), 0.3)
	m.sfx("ab_ready", at, -6.0, 1.7)
	net_ring(at, 1.0, col_of(rmb_def()))

func _tick_motes(dt: float) -> void:
	var cd_ := rmb_def()["coil"] as Dictionary
	for mt in motes.duplicate():
		mt["t"] = float(mt["t"]) - dt
		var n: Node3D = mt["node"]
		if is_instance_valid(n):
			n.global_position = (mt["pos"] as Vector3) + Vector3(0, 0.6 + 0.15 * sin(m.time * 5.0), 0)
		if float(mt["t"]) <= 0.0:
			_free_mote(mt)
			continue
		var mp: Vector3 = mt["pos"]
		if mt["owner"] == h and not h.downed and Vector2(h.pos.x - mp.x, h.pos.z - mp.z).length() < float(cd_["mote_r"]) + h.r:
			mote_pickups += 1
			h.dashes = h.max_dashes()
			m.sfx("pickup", h.pos, -4.0, 1.8)
			m.fx.ring(h.pos, 1.3, col_of(rmb_def()), 0.3)
			m.fx.word(h.pos + Vector3(0, 2.3, 0), "WIRERUN BACK", col_of(dash_def()), false)
			if h.is_local(): h._ab_feedback("dash", "ready")
			_free_mote(mt)

func _free_mote(mt: Dictionary) -> void:
	var n = mt.get("node")
	if n != null and is_instance_valid(n):
		self_nodes.erase(n)
		(n as Node).queue_free()
	motes.erase(mt)

# ------------------------------------------------------------------ E: Skycall
func cast_e() -> bool:
	var ed := e_def()
	var at := aim_at(float(ed["reach"]))
	var dir := Vector2(at.x - h.pos.x, at.z - h.pos.z)
	dir = dir.normalized() if dir.length() > 0.1 else h.aim_dir()
	var tele := tele_circle(at, float(ed["radius"]), col_of(ed), float(ed["delay"]))
	strikes.append({"at": at, "t": float(ed["delay"]), "dir": dir, "tele": tele})
	m.sfx("zap", h.pos, -4.0, 1.1)
	m.sfx("charge", at, -8.0, 1.8)
	net_ring(at, float(ed["radius"]), col_of(ed))
	play("mage_e")
	return true

func _tick_strikes(dt: float) -> void:
	for s in strikes.duplicate():
		s["t"] = float(s["t"]) - dt
		if float(s["t"]) <= 0.0:
			strikes.erase(s)
			_strike(s)

func _strike(s: Dictionary) -> void:
	var ed := e_def()
	var at: Vector3 = s["at"]
	var dir: Vector2 = s["dir"]
	var col := col_of(ed)
	m.fx.bolt(at + Vector3(0, 9.0, 0), at, col)
	net_bolt(at + Vector3(0, 9.0, 0), at, col)
	m.fx.ring(at, float(ed["radius"]) + 0.6, col, 0.3)
	m.fx.burst(at + Vector3(0, 0.5, 0), col, 26, 6.0, 0.5, 6.0, 1.2)
	m.fx.flash(at + Vector3(0, 1.0, 0), Color("ffffff"), 1.4, 0.1)
	m.sfx("boom", at, -2.0, 1.5)
	m.sfx("zap", at, 0.0, 0.7)
	Feel.shake(m, "t3", h, at)
	var stg := stage("e", {"delivery": {"type": "burst", "origin": "here", "radius": float(ed["radius"])},
		"effects": [{"type": "damage", "amount": float(ed["dmg"])}]})
	run(stg, cx("e", "skycall", at, {"at": at, "dir": dir}))
	for f in foes_in(at, float(ed["radius"])):
		add_spark(f)
		# flung along the aim, pinned to the ground for a moment
		f.impulse(dir * float(ed["push"]), float(ed["lift"]))
		if f is Hunter:
			KitStatus.apply(f, "gnd", float(ed["grounded"]))
	# lightning flings a charge mote it catches; a rival's becomes mine
	for mt in motes:
		if (mt["pos"] as Vector3).distance_to(at) < float(ed["radius"]) + 0.6:
			mt["pos"] = ground((mt["pos"] as Vector3) + Vector3(dir.x, 0, dir.y) * float(ed["push"]) * 0.6)
			mt["owner"] = h
			mt["t"] = float(rmb_def()["coil"]["mote_life"])

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	var aimp := tgt.pos + Vector3(0, 0.9, 0)
	if not wire.is_empty():
		h.inp["aim"] = aimp
		return
	if float(cd["e"]) <= 0.0 and int(h.slot_lv["kin"]) > 0 and los and dist < 8.5 and randf() < 0.3:
		h.inp["aim"] = aimp
		h.inp["sig"] = true
		return
	if live(tgt) and h.dashes >= 1.0 and dist < 6.5 and los:
		h.inp["aim"] = aimp
		h.inp["dash"] = true
		bot_hold["dash"] = clampf((dist - 3.5) / 3.0, 0.1, 0.5) * float(dash_def()["hold"]) + 0.05
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 12.0 and randf() < 0.4:
		h.inp["aim"] = aimp
		h.inp["sec"] = true
		bot_hold["rmb"] = (0.5 + randf() * 0.6) if dist > 6.0 else 0.0
