class_name GunslingerKit
extends ArchKit
## Venator (archetype id "gunslinger", medium): the ember-rifle skirmisher. docs/heroes/gunslinger.md
## has the per-slot table, the assumptions and the research notes (briefs/hero-ref/venator.md, owner notes).
##
## Loop: hold RMB for the Burr Charge's lane, let go to throw. It flies the whole lane, straight past
## people (owner: it never goes off on a person), and sticks where it meets a wall or the ground at the
## lane's end: a cone shows back toward you for its fuse, then blasts, shoving everyone in it along the
## cone (toward you) and Dazing them ("rat" Rattled in code). The rifle does +90% to a Dazed foe, in big
## gold numbers, and the string doesn't decay on them. Slipstep goes where you move and you keep
## shooting. Longneedle: stand still while the line narrows, then a long beam through walls. A knock
## gives Slipstep back (Hot Streak); abilities that land add a little lifesteal (Fever).

const EMBER := Color("ff9a5c")
const HOT := Color("fff1c8")
const DEEP := Color("c43a2a")

var slide := {}                # {t, held, dir} while a Slipstep runs
var burrs: Array = []          # Burr Charges in flight or stuck: {pos, dir, t, node, wall, fuse, fuse0, range, out, y0}
var burr_pool: Array = []      # their nodes, reused
var needle := {}               # Longneedle's charge: {t}
var knocked := {}
var rattles := 0               # Burr Charges that blew (tests)
var dazed_hits := 0            # rifle rounds on a Dazed foe (tests)
var skewers := 0               # Longneedle payoffs
var needle_hits := 0
var wall_slams := 0
var last_dash_kind := ""
var last_cone := {}            # tests: {at, dir, wall}
var last_shot := 0
var aim_marks := 0             # tests: foes marked inside the held lane

func fx() -> VVFx:
	return VVFx.of(m)

func full_ready() -> bool:
	return false

func res_text() -> String:
	return "%d" % int(res)

func fever_k() -> float:
	return float(res_def()["vamp"]) * floorf(res)

func ready_label() -> String:
	return ""

# ------------------------------------------------------------------ per step
func _tick(dt: float) -> void:
	if res_wait <= 0.0 and res > 0.0:
		res = 0.0
	if not slide.is_empty():
		_tick_slide(dt)
	if not burrs.is_empty():
		_tick_burrs(dt)
	if not needle.is_empty():
		_tick_needle(dt)
	_tick_lmb()
	if rmb_down:
		_tick_aim()
	self_pips(int(res_def()["max"]), int(floor(res + 0.01)), false, dt)

func teardown() -> void:
	super.teardown()
	for b in burrs:
		if b["node"] != null and is_instance_valid(b["node"]): (b["node"] as Node3D).visible = false
	burrs.clear()
	_end_needle()

func fires_in_dash() -> bool:
	return not slide.is_empty()            # any slide, tap or held: the rifle keeps going

func move_k() -> float:
	return 1.0 - float(e_def()["self_slow"]) if not needle.is_empty() else 1.0

func fire_ok() -> bool:
	return true

func add_fever(n := 1) -> void:
	res = minf(res_max(), res + float(n))
	touch_res(float(res_def()["wait"]))

## Dazed foes take +90% from the rifle: a crit-style big gold number, and the string's decay pauses.
func outgoing(t: Ent, dmg: float, o: Dictionary) -> float:
	if t is Hunter or t is Mob:
		if String(o.get("src", "")) == "shot" and not o.has("ab") and KitStatus.rattled(t):
			o["crit"] = true
			dazed_hits += 1
			h.sus_n = maxi(0, h.sus_n - 1)
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

## Hot Streak: a knock gives Slipstep back (and heals); rank 3 also resets the Burr Charge.
func _on_knock(t: Ent) -> void:
	knocked[t.get_instance_id()] = true
	h.heal(h.max_hp * float(res_def()["knock_heal"]))
	h.dashes = h.max_dashes()
	if rank("sec") >= 3:
		ch_rmb = float(rmb_charges()); cd["rmb"] = 0.0
	fx().ring(h.pos, 1.6, EMBER, HOT, 0.35)
	fx().pillar(ground(h.pos), EMBER, HOT, 2.4, 0.6, 0.5)
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "+KNOCK", Color("8ff0a0"), false)
	m.sfx("vn_stim", h.pos, -3.0)
	play("gunslinger_knock")
	if h.is_local(): h._ab_feedback("dash", "ready")

# ------------------------------------------------------------------ LMB: the rifle's rounds
## Each round: a hot ember needle with a cooling tail, a bronze star at the muzzle, the shoulder kick.
func _tick_lmb() -> void:
	if h.shot_n == last_shot:
		return
	last_shot = h.shot_n
	var shots: Array = m.get("shots")
	for i in range(shots.size() - 1, -1, -1):
		var sd: Dictionary = shots[i]
		if sd["by"] == h and not (sd["x"] as Dictionary).has("src"):
			fx().ride(sd, "tracer", EMBER, HOT, 2.6, 0.16, _round_end)
			fx().star(sd["pos"], EMBER, HOT, 0.5, 0.06)
			break
	if anim_id == "" or anim_id == "gunslinger_lmb" or m.time - anim_at > 1.2:
		play("gunslinger_lmb")

func _round_end(at: Vector3, vel: Vector2) -> void:
	var d := Vector3(-vel.x, 0.4, -vel.y).normalized() if vel.length() > 0.1 else Vector3.UP
	m.fx.spark(at, d, EMBER, 3, 5.0, 50.0, 0.14, 8.0, 0.7)

# ------------------------------------------------------------------ dash: Slipstep
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if use_ex:
		if not spend_dash(true): return true
		travel(float(h.cdat.get("ex_dist", 4.6)) * 0.9, float(h.cdat.get("ex_time", 0.2)), {"invuln": 0.08}, true)
		play("gunslinger_dash_ex")
		fx().ghost(h.position, h.face, EMBER, float(h.cdat.get("scale", 1.0)), 0.35)
		last_dash_kind = "air"
		return true
	if not spend_dash(false):
		return true
	var start := h.position
	travel(float(dd["roll"]), float(dd["roll_t"]), {"invuln": float(dd["invuln"])})
	slide = {"t": 0.0, "held": false, "dir": h.roll_dir, "fx": 0.0}
	play("gunslinger_dash")
	# where it began: an ember afterimage and a white ring; dust under him
	fx().ghost(start, h.face, EMBER, float(h.cdat.get("scale", 1.0)), 0.45)
	fx().ring(ground(start), 1.2, Color.WHITE, EMBER, 0.45)
	m.fx.dust(h.pos, 8)
	m.sfx("vn_slide", h.pos, -4.0)
	return true

func _slide_end(early: bool) -> void:
	var dd := dash_def()
	h.roll_t = 0.0
	if early:
		h.dashes = minf(h.max_dashes(), h.dashes + float(dd["refund"]))
	elif rank("dash") >= 3:
		h.add_buff("move_speed", 0.25, 2.0)
		fx().ring(h.pos, 1.0, col_of(dd), HOT, 0.25)
	st["last_dash"] = "slide" if bool(slide.get("held", false)) else "step"
	last_dash_kind = String(st["last_dash"])
	slide = {}

func _tick_slide(dt: float) -> void:
	var dd := dash_def()
	slide["t"] = float(slide["t"]) + dt
	var t := float(slide["t"])
	slide["fx"] = float(slide["fx"]) - dt
	if float(slide["fx"]) <= 0.0:
		slide["fx"] = 0.06
		# ribbon of afterimages from the shoulders back along the slide
		fx().ghost(h.position, h.face, DEEP.lerp(EMBER, 0.4), float(h.cdat.get("scale", 1.0)) * 0.9, 0.25)
		m.fx.dust(h.pos, 2)
	if not bool(slide["held"]):
		if t >= float(dd["tap_t"]) and held("dash") and not h.downed and h.stun_t <= 0.0 and h.root_t <= 0.0 and h.grounded:
			slide["held"] = true
			slide["t0"] = t
			h.roll_dir = slide["dir"]
			h.move_kind = "dash"
			m.fx.dust(h.pos, 8)
		elif t >= float(dd["tap_t"]):
			_slide_end(false)                # a tap: the skid runs its whole length (you shoot through it)
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

# ------------------------------------------------------------------ RMB: Burr Charge
func rmb_charge_full() -> float:
	return 0.0                              # a held aim, not a charge

func rmb_auto_t() -> float:
	return float(rmb_def().get("auto", 4.0))

func rmb_hold_tick(t: float) -> void:
	if t <= 0.02 and anim_id != "gunslinger_rmb_hold":
		play("gunslinger_rmb_hold")
		m.sfx("vn_cock", h.pos, -4.0)

## While held: the fixed lane with an arrow tip out past the cursor; foes inside it are marked.
func _tick_aim() -> void:
	var bd := rmb_def()["burr"] as Dictionary
	var d := h.aim_dir()
	AimKit.lane(h, "rmb", {"len": float(bd["range"]), "width": float(bd["lane_w"]), "tip": true, "col": Color(1, 1, 1, 0.8), "col2": EMBER})
	for f in m.foes_of(h.team):
		if f.hittable() and AimMode.in_lane(h.pos, d, float(bd["range"]), float(bd["lane_w"]), f.pos, f.r):
			aim_marks += 1
			AimKit.circle(h, "mark%d" % f.get_instance_id(), {"at": f.pos, "r": 0.75, "col": Color("ff4fb0"), "col2": HOT, "alpha": 1.2})

func fire_rmb(c: Dictionary) -> void:
	AimKit.hide(h, "rmb")
	last_variant = String(c["variant"])
	if not spend_rmb(): return
	var bd := rmb_def()["burr"] as Dictionary
	var d := h.aim_dir()
	var n: Node3D = null
	for p in burr_pool:
		if is_instance_valid(p) and not (p as Node3D).visible:
			n = p; break
	if n == null:
		n = _make_burr()
	n.visible = true
	n.scale = Vector3.ONE
	var at := h.pos + Vector3(d.x * 0.6, 1.6, d.y * 0.6)
	n.global_position = at
	burrs.append({"pos": at, "dir": d, "t": 0.0, "node": n, "wall": false, "fuse": -1.0, "fuse0": float(bd["fuse"]), "range": float(bd["range"]), "y0": at.y, "g0": ground(h.pos).y})
	play("gunslinger_rmb")
	m.sfx("vn_throw", h.pos, -2.0)
	if h.is_local(): Oomph.punch_dir(m, -d, 0.08)

## The charge: a dark spiked canister, an ember glow inside.
func _make_burr() -> Node3D:
	var n := own_node()
	var core := Models.part(n, Models.sphere(0.15, 10), Models.toon(Color("2b2a33"), true, 0.0))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := Models.part(n, Models.sphere(0.1, 8), Models.glow_mat(EMBER), Vector3.ZERO, Vector3.ONE * 1.25)
	glow.name = "Glow"
	for sa in 8:
		var a := TAU * sa / 8.0
		var sp := Models.part(n, Models.crystal(0.03, 0.14, 4), Models.glow_mat(HOT), Vector3(cos(a), sin(sa * 2.1) * 0.5, sin(a)) * 0.17)
		sp.look_at_from_position(sp.position, sp.position * 2.0, Vector3.UP if absf(sp.position.normalized().y) < 0.95 else Vector3.RIGHT)
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burr_pool.append(n)
	return n

func _tick_burrs(dt: float) -> void:
	var bd := rmb_def()["burr"] as Dictionary
	for b in burrs.duplicate():
		var n: Node3D = b["node"]
		if float(b["fuse"]) >= 0.0:
			# stuck: blinks faster, the cone shows back toward the thrower for everyone
			b["fuse"] = float(b["fuse"]) - dt
			var k := 1.0 - float(b["fuse"]) / float(b["fuse0"])
			if is_instance_valid(n):
				n.global_position = b["pos"]
				n.scale = Vector3.ONE * (1.0 + 0.35 * sin(m.time * lerpf(10.0, 44.0, k)))
			AimKit.cone(h, "burr%d" % n.get_instance_id(), {"from": b["pos"], "dir": b["out"], "len": float(bd["cone_len"]), "deg": float(bd["cone_deg"]), "fill": k, "all": true, "col": EMBER, "col2": HOT, "hot": k})
			if float(b["fuse"]) <= 0.0:
				burrs.erase(b)
				_detonate(b)
			continue
		var p: Vector3 = b["pos"]
		var dir: Vector2 = b["dir"]
		b["t"] = float(b["t"]) + dt
		var flat := p + Vector3(dir.x, 0, dir.y) * float(bd["speed"]) * dt
		var dist: float = float(b["t"]) * float(bd["speed"])
		var u := clampf(dist / float(b["range"]), 0.0, 1.0)
		# a slight lob: up a little, then down onto the lane's end
		var gy := ground(flat).y
		flat.y = lerpf(float(b["y0"]), gy + 0.25, u * u) + 0.6 * sin(PI * u)
		var walled: bool = m.world.is_block(flat.x, flat.z) or m.world.ground_at(flat.x, flat.z) > float(b["g0"]) + 0.6
		if walled:
			_stick(b, p, true)
		elif dist >= float(b["range"]):
			_stick(b, ground(flat) + Vector3(0, 0.2, 0), false)       # the ground at the lane's end
		else:
			b["pos"] = flat
			if int(b["t"] * 60.0) % 3 == 0: m.fx.burst(flat, EMBER, 3, 0.6, 0.25, 0.0, 0.7)
		if is_instance_valid(n):
			n.global_position = b["pos"]
			n.rotation.y += dt * 14.0

## It meets a wall (or the ground at the lane's end) and sticks: the cone points back the way it came.
func _stick(b: Dictionary, at: Vector3, wall: bool) -> void:
	var bd := rmb_def()["burr"] as Dictionary
	b["pos"] = at
	b["wall"] = wall
	b["fuse"] = float(bd["fuse"]); b["fuse0"] = float(bd["fuse"])
	b["out"] = -(b["dir"] as Vector2)
	m.sfx("vn_stick", at, -3.0)
	fx().star(at, EMBER, HOT, 0.6, 0.12)
	net_ring(at, 1.0, EMBER)

func _detonate(b: Dictionary) -> void:
	var bd := rmb_def()["burr"] as Dictionary
	var n: Node3D = b["node"]
	if is_instance_valid(n):
		n.visible = false
		AimKit.hide(h, "burr%d" % n.get_instance_id())
	var at: Vector3 = b["pos"]
	rattles += 1
	m.fx.flash(at, HOT, 1.6, 0.1)
	fx().ring(ground(at), 1.8, EMBER, HOT, 0.35)
	m.sfx("vn_blast", at, -1.0)
	Feel.shake(m, "t3", h, at)
	_cone(at, b["out"] as Vector2, bd, bool(b["wall"]))

## The blast: a cone back out of the stick point, shoving everything in it along the cone (toward the
## thrower) and Dazing it; a hunter shoved into more terrain is stunned, and that shaves the cooldown.
func _cone(at: Vector3, out: Vector2, bd: Dictionary, wall: bool) -> void:
	last_cone = {"at": at, "dir": out, "wall": wall}
	fx().fan(ground(at), out, float(bd["cone_len"]), float(bd["cone_deg"]), EMBER, HOT, 0.35)
	m.fx.burst(at + Vector3(out.x, 0.4, out.y) * 1.5, EMBER, 18, 8.0, 0.4, 3.0, 1.4, Vector3(out.x, 0.2, out.y), float(bd["cone_deg"]) * 0.5)
	net_ring(at, 1.6, EMBER)
	var shaved := false
	for f in m.foes_of(h.team):
		if not f.hittable(): continue
		if absf(f.pos.y - at.y) > 2.6: continue
		if not AimMode.in_cone(at, out, float(bd["cone_len"]), float(bd["cone_deg"]), f.pos, 0.3, f.r): continue
		var to := Vector2(f.pos.x - at.x, f.pos.z - at.z)
		var away := (out * 0.6 + to.normalized() * 0.4).normalized() if to.length() > 0.2 else out
		var o := {"src": "abil", "ab": "utility", "tags": ["utility", "burr"], "kb": away * float(bd["push"]), "lift": 2.0}
		f.hurt(float(bd["cone_dmg"]) * power("sec") * m.dmg_mult(h), h, o)
		KitStatus.apply(f, "rat", float(bd["cone_rattle"]))         # Dazed: the training dummy too
		fx().swirl(f, Color("ff4fb0"), HOT, float(bd["cone_rattle"]))
		if f is Hunter and terrain_behind(f, away, 2.4):
			wall_slams += 1
			f.hurt(0.1, h, {"src": "abil", "ab": "utility", "tags": ["utility", "burr"], "stun": float(bd["wall_stun"]), "dr": true})
			m.fx.word(f.pos + Vector3(0, 2.2, 0), "WALLED", EMBER, false)
			shaved = true
	if shaved:
		cd["rmb"] = float(cd["rmb"]) * (1.0 - float(bd["shave"]))

# ------------------------------------------------------------------ E: Longneedle
func cast_e() -> bool:
	if not needle.is_empty(): return false
	var ed := e_def()
	needle = {"t": 0.0}
	e_t = float(ed["charge"]) + 0.1
	m.sfx("vn_ion_charge", h.pos, -3.0)
	net_ring(h.pos, 1.2, col_of(ed))
	play("gunslinger_e")
	return true

## A Boki merge ends the Longneedle's charge with no shot, cuts a Slipstep short (no refund, no speed
## buff) and drops a Burr Charge held in the hand (nothing thrown).
func _drop_holds() -> void:
	_end_needle()
	if not slide.is_empty():
		slide = {}
		h.roll_t = 0.0
	rmb_down = false
	rmb_t = 0.0

func _end_needle() -> void:
	if needle.is_empty(): return
	needle = {}
	e_t = 0.0
	AimKit.hide(h, "e")

func _tick_needle(dt: float) -> void:
	var ed := e_def()
	needle["t"] = float(needle["t"]) + dt
	if h.downed or h.stun_t > 0.0 or Hex.active(h):
		_end_needle()
		return
	var k := clampf(float(needle["t"]) / float(ed["charge"]), 0.0, 1.0)
	# a bright wide line drawn full length at once, narrowing to a thin core as the cast completes
	AimKit.lane(h, "e", {"len": float(ed["range"]), "width": 1.0, "width_to": 0.12, "k": k, "all": true, "col": col_of(ed), "col2": HOT})
	AimKit.charge(h, k, {"col": col_of(ed), "col2": HOT})
	if float(needle["t"]) >= float(ed["charge"]) + 0.03:          # (a beat at full so the full tick plays)
		_end_needle()
		_fire_needle()

func dash_charge() -> float:
	return -1.0

func charge_now() -> Array:
	if not needle.is_empty():
		return ["needle", clampf(float(needle["t"]) / float(e_def()["charge"]), 0.0, 1.0)]
	return super.charge_now()

func _fire_needle() -> void:
	var ed := e_def()
	var d := h.aim_dir()
	var a := h.pos + Vector3(d.x * 0.9, 1.1, d.y * 0.9)
	var L := float(ed["range"])
	var b := a + Vector3(d.x, 0, d.y) * L
	var col := col_of(ed)
	fx().beam(a, b, col, HOT, 0.9, float(ed["linger"]))
	fx().star(a, Color("9ff5ff"), Color.WHITE, 1.1, 0.14)        # the muzzle orb and its flat flare
	m.fx.flash(a, Color.WHITE, 1.2, 0.08)
	fx().ring(ground(h.pos), 1.6, Color.WHITE, HOT, 0.35)         # the smoke ring round him
	net_bolt(a, b, col)
	m.sfx("vn_ion_fire", h.pos, 1.0)
	Feel.shake(m, "t3", h, h.pos)
	if h.is_local():
		Oomph.punch_dir(m, -d, 0.22)
		if m.cam: m.cam.add_trauma(0.18)
	h.impulse(-d * float(ed.get("recoil", 6.0)))                  # the recoil shoves him back a step
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
		var nn := hits if rank("kin") >= 3 else 1
		cd["e"] = maxf(0.0, float(cd["e"]) - maxcd * float(ed["shave"]) * nn)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	var aimp := tgt.pos + Vector3(0, 0.9, 0)
	if not needle.is_empty() or rmb_down:
		h.inp["aim"] = aimp
		return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and los and dist > 4.0 and dist < 17.0 and (KitStatus.rattled(tgt) or randf() < 0.15):
		h.inp["aim"] = aimp
		h.inp["sig"] = true
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 10.0 and dist > 2.0 and randf() < 0.4:
		# throw it past them so the cone comes back over them
		h.inp["aim"] = aimp
		h.inp["sec"] = true
		bot_hold["rmb"] = 0.3
		return
	if h.hp < h.max_hp * 0.4 and h.dashes >= 1.0 and randf() < 0.1:
		h.inp["dash"] = true
		bot_hold["dash"] = 0.5
