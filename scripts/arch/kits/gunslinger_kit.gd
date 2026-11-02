class_name GunslingerKit
extends ArchKit
## Marlowe (archetype id "gunslinger", medium): the burr-and-needle marksman. docs/heroes/gunslinger.md
## has the per-slot table and the research notes.
##
## Loop: Burr Charge sticks to a foe (or the wall behind them) and goes off, leaving them Rattled:
## slowed, and the Quill Rifle and Longneedle hit them harder. Every ability that lands also builds
## Fever, a stack of lifesteal that your rifle then feeds on. Longneedle is the big pierce shot; a
## hunter hit shortens its cooldown. A knock heals you and refreshes Slipstep.

var slide := {}                # {t, held, dir} while a Slipstep runs
var burrs: Array = []          # Burr Charges in flight or stuck: {pos, dir, t, node, stuck, wall, fuse}
var needle := {}               # Longneedle's charge: {t, tele}
var knocked := {}
var rattles := 0               # Burr Charges that detonated (tests)
var skewers := 0               # Longneedle payoffs
var needle_hits := 0
var wall_slams := 0
var last_dash_kind := ""

func full_ready() -> bool:
	return false

func res_text() -> String:
	return "%d" % int(res)

func fever_k() -> float:
	return float(res_def()["vamp"]) * floorf(res)

func ready_label() -> String:
	return ""

# ------------------------------------------------------------------ passive: Fever
func _tick(dt: float) -> void:
	if res_wait <= 0.0 and res > 0.0:
		res = 0.0
	if not slide.is_empty():
		_tick_slide(dt)
	if not burrs.is_empty():
		_tick_burrs(dt)
	if not needle.is_empty():
		_tick_needle(dt)
	self_pips(int(res_def()["max"]), int(floor(res + 0.01)), false, dt)

func teardown() -> void:
	super.teardown()
	for b in burrs:
		if b["node"] != null and is_instance_valid(b["node"]): (b["node"] as Node).queue_free()
	burrs.clear()
	_end_needle()

func fires_in_dash() -> bool:
	return not slide.is_empty() and bool(slide.get("held", false))

func move_k() -> float:
	return 1.0 - float(e_def()["self_slow"]) if not needle.is_empty() else 1.0

func fire_ok() -> bool:
	return true

func add_fever(n := 1) -> void:
	res = minf(res_max(), res + float(n))
	touch_res(float(res_def()["wait"]))

## Rattled foes take more from the rifle.
func outgoing(t: Ent, dmg: float, o: Dictionary) -> float:
	if t is Hunter or t is Mob:
		if String(o.get("src", "")) == "shot" and not o.has("ab") and KitStatus.rattled(t):
			return dmg * (1.0 + float(res_def()["rattle_k"]))
	return dmg

func on_deal(t: Ent, dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team or String(o.get("src", "")) == "burn":
		return
	if res > 0.0:
		h.heal(dmg * fever_k())
	if o.has("ab") and String(o.get("ab")) != "dodge":
		add_fever(1)
	if t is Hunter and ((t as Hunter).downed or t.hp <= 0.0) and not knocked.has(t.get_instance_id()):
		_on_knock(t)

func _on_knock(t: Ent) -> void:
	knocked[t.get_instance_id()] = true
	h.heal(h.max_hp * float(res_def()["knock_heal"]))
	h.dashes = h.max_dashes()
	if rank("sec") >= 3:
		ch_rmb = float(rmb_charges()); cd["rmb"] = 0.0
	m.fx.ring(h.pos, 1.3, Color("8ff0a0"), 0.3)
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "+KNOCK", Color("8ff0a0"), false)
	if h.is_local(): h._ab_feedback("dash", "ready")

# ------------------------------------------------------------------ dash: Slipstep
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if use_ex:
		if not spend_dash(true): return true
		travel(float(h.cdat.get("ex_dist", 4.6)) * 0.9, float(h.cdat.get("ex_time", 0.2)), {"invuln": 0.08, "trail": "roll"}, true)
		last_dash_kind = "air"
		return true
	if not spend_dash(false):
		return true
	travel(float(dd["roll"]), float(dd["roll_t"]), {"invuln": float(dd["invuln"]), "trail": "roll"})
	slide = {"t": 0.0, "held": false, "dir": h.roll_dir}
	play("gunslinger_dash")
	m.later(0.08, func(): if is_instance_valid(h): m.sfx("click", h.pos, -8.0, 1.8))
	return true

func _slide_end(early: bool) -> void:
	var dd := dash_def()
	h.roll_t = 0.0
	if early:
		h.dashes = minf(h.max_dashes(), h.dashes + float(dd["refund"]))
	elif rank("dash") >= 3:
		h.add_buff("move_speed", 0.25, 2.0)
		m.fx.ring(h.pos, 1.0, col_of(dd), 0.25)
	st["last_dash"] = "slide" if bool(slide.get("held", false)) else "step"
	last_dash_kind = String(st["last_dash"])
	slide = {}

func _tick_slide(dt: float) -> void:
	var dd := dash_def()
	slide["t"] = float(slide["t"]) + dt
	var t := float(slide["t"])
	if not bool(slide["held"]):
		if t >= float(dd["tap_t"]) and held("dash") and not h.downed and h.stun_t <= 0.0 and h.root_t <= 0.0 and h.grounded:
			slide["held"] = true
			slide["t0"] = t
			h.roll_dir = slide["dir"]
			h.move_kind = "dash"
			m.fx.dust(h.pos, 8)
		elif not held("dash") or t >= float(dd["tap_t"]):
			_slide_end(false)
		return
	var st_t := t - float(slide["t0"])
	var dur := float(dd["slide_t"])
	if not held("dash") or st_t >= dur or h.stun_t > 0.0 or h.root_t > 0.0:
		_slide_end(st_t < dur * 0.9 and h.stun_t <= 0.0 and h.root_t <= 0.0)
		return
	var k := 1.0 - st_t / dur
	h.roll_t = maxf(h.roll_t, dt * 1.5)
	h.roll_speed = float(dd["slide"]) / dur * (0.5 + k)
	h.inv_t = 0.0
	if int(st_t * 20.0) % 2 == 0: m.fx.dust(h.pos, 2)

# ------------------------------------------------------------------ RMB: Burr Charge
func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if not spend_rmb(): return
	var bd := rmb_def()["burr"] as Dictionary
	var d := h.aim_dir()
	var n := own_node()
	var core := MeshInstance3D.new()
	core.mesh = Models.sphere(0.16, 10)
	core.material_override = Models.glow_mat(Color(col_of(rmb_def()), 1.0))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(core)
	for sa in 6:
		var sp := MeshInstance3D.new()
		sp.mesh = Models.crystal(0.03, 0.12, 4)
		sp.material_override = Models.glow_mat(Color("fff2c8"))
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sp.position = Vector3(cos(sa * 1.047), sin(sa * 2.1) * 0.5, sin(sa * 1.047)) * 0.2
		sp.look_at_from_position(sp.position, sp.position * 2.0, Vector3.UP)
		n.add_child(sp)
	var at := h.pos + Vector3(d.x * 0.8, 1.0, d.y * 0.8)
	n.global_position = at
	burrs.append({"pos": at, "dir": d, "t": 0.0, "node": n, "stuck": null, "wall": false, "fuse": -1.0, "range": float(bd["range"])})
	play("gunslinger_rmb")
	m.sfx("ab_throw", h.pos, -2.0, 0.8)
	m.sfx("click", h.pos, -5.0, 0.8)
	if h.is_local(): Oomph.punch_dir(m, -d, 0.08)

func _tick_burrs(dt: float) -> void:
	var bd := rmb_def()["burr"] as Dictionary
	for b in burrs.duplicate():
		var n: Node3D = b["node"]
		if float(b["fuse"]) >= 0.0:
			# stuck: blinks faster as it goes
			b["fuse"] = float(b["fuse"]) - dt
			var stuck = b["stuck"]
			if stuck != null and is_instance_valid(stuck) and not bool(b["wall"]):
				b["pos"] = (stuck as Ent).position + Vector3(0, 1.0, 0)
			if is_instance_valid(n):
				n.global_position = b["pos"]
				n.scale = Vector3.ONE * (1.0 + 0.35 * sin(m.time * lerpf(10.0, 40.0, 1.0 - float(b["fuse"]) / float(bd["fuse"]))))
			if float(b["fuse"]) <= 0.0:
				burrs.erase(b)
				_detonate(b)
			continue
		var p: Vector3 = b["pos"]
		var dir: Vector2 = b["dir"]
		b["t"] = float(b["t"]) + dt
		var q := p + Vector3(dir.x, 0, dir.y) * float(bd["speed"]) * dt
		var walled: bool = m.world.is_block(q.x, q.z) or m.world.ground_at(q.x, q.z) > p.y - 0.4
		var hit: Ent = null
		if not walled:
			for f in foes_in(q - Vector3(0, 1.0, 0), 0.7, 2.0):
				hit = f
				break
		var dist: float = float(b["t"]) * float(bd["speed"])
		if hit != null:
			b["stuck"] = hit; b["fuse"] = float(bd["fuse"]); b["pos"] = hit.position + Vector3(0, 1.0, 0)
			_attach(b, hit)
		elif walled:
			b["wall"] = true; b["fuse"] = float(bd["fuse"]) * 0.85
			m.sfx("click", p, -4.0, 1.4)
		elif dist >= float(b["range"]):
			b["wall"] = false; b["fuse"] = float(bd["fuse"]) * 0.6        # lands on the floor and pops (a miss)
			b["pos"] = ground(q) + Vector3(0, 0.2, 0)
		else:
			b["pos"] = q
		if is_instance_valid(n):
			n.global_position = b["pos"]
			n.rotation.y += dt * 14.0

func _attach(b: Dictionary, f: Ent) -> void:
	var bd := rmb_def()["burr"] as Dictionary
	f.hurt(float(bd["attach_dmg"]) * power("sec"), h, {"src": "abil", "ab": "utility", "tags": ["utility", "burr"]})
	m.fx.ring(f.pos, 0.9, col_of(rmb_def()), 0.2)
	m.sfx("armor_hit", f.pos, -3.0, 1.6)
	m.fx.word(f.pos + Vector3(0, 2.2, 0), "STUCK", col_of(rmb_def()), false)

func _detonate(b: Dictionary) -> void:
	var bd := rmb_def()["burr"] as Dictionary
	var n: Node3D = b["node"]
	if is_instance_valid(n):
		self_nodes.erase(n)
		n.queue_free()
	var at: Vector3 = b["pos"]
	var col := col_of(rmb_def())
	rattles += 1
	m.fx.burst(at, col, 30, 7.0, 0.5, 4.0, 1.3)
	m.fx.flash(at, Color("fff2c8"), 1.5, 0.1)
	m.sfx("boom", at, -1.0, 1.35)
	m.sfx("hit_heavy", at, -3.0, 1.2)
	Feel.shake(m, "t3", h, at)
	if bool(b["wall"]):
		_cone(at, b["dir"] as Vector2, bd)
		return
	var r := float(bd["radius"])
	m.fx.ring(at, r + 0.4, col, 0.3)
	net_ring(at, r + 0.4, col)
	var stg := stage("rmb", {"delivery": {"type": "burst", "origin": "here", "radius": r}, "effects": [{"type": "damage", "amount": float(bd["dmg"])}]})
	run(stg, cx("rmb", "burr_charge", at, {"at": at}))
	for f in foes_in(at, r):
		if f is Hunter: KitStatus.apply(f, "rat", float(bd["rattle"]))
		else: f.stun_t = maxf(f.stun_t, 0.3)

## Stuck in the wall: a cone back out of it, knocking everything away and Rattling it for longer; a
## foe thrown into more terrain is stunned, and a hunter blasted off the wall shaves the cooldown.
func _cone(at: Vector3, dir: Vector2, bd: Dictionary) -> void:
	var out := -dir
	var col := col_of(rmb_def())
	m.fx.cone(at, out, float(bd["cone_len"]), col)
	net_ring(at, 1.6, col)
	var half := deg_to_rad(float(bd["cone_deg"]) * 0.5)
	var shaved := false
	for f in m.foes_of(h.team):
		if not f.hittable(): continue
		var to := Vector2(f.pos.x - at.x, f.pos.z - at.z)
		if to.length() > float(bd["cone_len"]) + f.r or absf(f.pos.y - at.y) > 2.6: continue
		if to.length() > 0.2 and absf(out.angle_to(to.normalized())) > half: continue
		var away := to.normalized() if to.length() > 0.2 else out
		var o := {"src": "abil", "ab": "utility", "tags": ["utility", "burr"], "kb": away * float(bd["push"]), "lift": 2.0}
		f.hurt(float(bd["cone_dmg"]) * power("sec") * m.dmg_mult(h), h, o)
		if f is Hunter:
			KitStatus.apply(f, "rat", float(bd["cone_rattle"]))
			if terrain_behind(f, away, 2.4):
				wall_slams += 1
				f.hurt(0.1, h, {"src": "abil", "ab": "utility", "tags": ["utility", "burr"], "stun": float(bd["wall_stun"]), "dr": true})
				m.fx.word(f.pos + Vector3(0, 2.2, 0), "WALLED", col, false)
				shaved = true
	if shaved:
		cd["rmb"] = float(cd["rmb"]) * (1.0 - float(bd["shave"]))

# ------------------------------------------------------------------ E: Longneedle
func cast_e() -> bool:
	if not needle.is_empty(): return false
	var ed := e_def()
	var tele := tele_lane(h.pos, h.aim_dir(), float(ed["range"]), float(ed["width"]) + 0.2, col_of(ed), 0.0)
	needle = {"t": 0.0, "tele": tele}
	e_t = float(ed["charge"]) + 0.1
	m.sfx("charge", h.pos, -3.0, 1.1)
	net_ring(h.pos, 1.2, col_of(ed))
	play("gunslinger_e")
	return true

func rmb_hold_tick(_t: float) -> void:
	pass

func _end_needle() -> void:
	if needle.is_empty(): return
	var tele = needle.get("tele")
	if tele != null and is_instance_valid(tele): m.fx.end_telegraph(tele)
	needle = {}
	e_t = 0.0

func _tick_needle(dt: float) -> void:
	var ed := e_def()
	needle["t"] = float(needle["t"]) + dt
	if h.downed or h.stun_t > 0.0 or Hex.active(h):
		_end_needle()
		return
	var tele: Node3D = needle["tele"]
	var k := clampf(float(needle["t"]) / float(ed["charge"]), 0.0, 1.0)
	if is_instance_valid(tele):
		m.fx.aim_telegraph(tele, h.pos, h.aim_dir())
		m.fx.telegraph_progress(tele, k)
	if int(float(needle["t"]) * 14.0) != int((float(needle["t"]) - dt) * 14.0):
		m.sfx("click", h.pos, lerpf(-14.0, -6.0, k), lerpf(1.0, 2.2, k))
	if float(needle["t"]) >= float(ed["charge"]) + 0.03:          # (a beat at full so the full tick plays)
		_end_needle()
		_fire_needle()

func dash_charge() -> float:
	return -1.0

func rmb_charge_full() -> float:
	return 0.0

func charge_now() -> Array:
	if not needle.is_empty():
		return ["needle", clampf(float(needle["t"]) / float(e_def()["charge"]), 0.0, 1.0)]
	return super.charge_now()

func _fire_needle() -> void:
	var ed := e_def()
	var d := h.aim_dir()
	var a := h.pos + Vector3(d.x * 0.7, 1.1, d.y * 0.7)
	var L := float(ed["range"])
	var b := a + Vector3(d.x, 0, d.y) * L
	var col := col_of(ed)
	m.fx.beam(a, b, col, 0.7, 0.35)
	m.fx.flash(a, Color("ffffff"), 1.1, 0.08)
	net_bolt(a, b, col)
	m.sfx("rail", h.pos, 1.0, 0.8)
	m.sfx("sniper", h.pos, -3.0, 1.3)
	Feel.shake(m, "t3", h, h.pos)
	if h.is_local(): Oomph.punch_dir(m, -d, 0.22)
	var hits := 0
	var dmg0: float = float(ed["dmg"]) * power("kin") * m.dmg_mult(h)
	for f in m.foes_of(h.team):
		if not f.hittable(): continue
		var v := Vector2(f.pos.x - h.pos.x, f.pos.z - h.pos.z)
		var along := v.dot(d)
		if along < 0.0 or along > L + f.r: continue
		if absf(v.cross(d)) > float(ed["width"]) + f.r: continue
		if absf(f.pos.y - h.pos.y) > 2.6: continue
		var rat := KitStatus.rattled(f)
		var dmg: float = dmg0 * ((1.0 + float(ed["rattle_k"])) if rat else 1.0)
		var o := {"src": "abil", "ab": "k1", "tags": ["k1", "needle"]}
		if rat and f is Hunter: o["payoff"] = true
		f.hurt(dmg, h, o)
		needle_hits += 1
		m.fx.burst(f.pos + Vector3(0, 1.0, 0), col, 14, 5.0, 0.3)
		if f is Hunter:
			hits += 1
			if rat:
				skewers += 1
				payoff_fx(f.pos, "SKEWERED", col, "", h.dir_to(f), f)
				m.sfx("hero_skewer", f.pos, 0.0)
	if hits > 0:
		var maxcd := float(ed["cooldown"]) * cd_k("kin")
		var n := hits if rank("kin") >= 3 else 1
		cd["e"] = maxf(0.0, float(cd["e"]) - maxcd * float(ed["shave"]) * n)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	var aimp := tgt.pos + Vector3(0, 0.9, 0)
	if not needle.is_empty():
		h.inp["aim"] = aimp
		return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and los and dist > 4.0 and dist < 13.0 and (KitStatus.rattled(tgt) or randf() < 0.15):
		h.inp["aim"] = aimp
		h.inp["sig"] = true
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 10.0 and dist > 2.0 and randf() < 0.4:
		h.inp["aim"] = aimp
		h.inp["sec"] = true
		return
	if h.hp < h.max_hp * 0.4 and h.dashes >= 1.0 and randf() < 0.1:
		h.inp["dash"] = true
		bot_hold["dash"] = 0.5
