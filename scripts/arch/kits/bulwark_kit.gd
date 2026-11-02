class_name BulwarkKit
extends ArchKit
## Bjorn (id bulwark, heavy): the squad's shield. docs/heroes/bulwark.md, hero sheet bjorn.md.
##
## - LMB (War Hammer): tap throws the hammer to the cursor (clamped to its range; it passes through foes
##   and stays planted under a gold beacon, showing foes near it to your team, until you tap again to
##   call it back, hitting on the way). Hold spins the hammer in his hand (faster as it charges, a glint
##   on its head from 0.6 s, a flare at full, 1.25 s); let go and it's a Crushing Blow: a flaming 180
##   degree crescent in front that carries him forward with it.
## - RMB: hold to raise his aegis (its own HP, regenerates); tap, or let go after a hold, to Bash.
## - Dash: 360 Smash, a short dash that ends in one full spin hit around him; with the aegis raised it's
##   a Shield Charge (invulnerable for its length, a heavier knock).
## - Passive, Guard: damage the aegis blocks becomes Guard; at 50 a Bash is a Shield Slam (stun).
##   Payoff, Crushed: a Bash, Shield Charge or full Crushing Blow that knocks a foe into a wall or
##   another foe stuns them and heals you (T4, pay_slam).
## - E, Mending Ground: a green column comes down for 1 s, then heals at the planted hammer (on you when
##   the hammer is in hand); it also mends the aegis while it's raised.
## - X, Faultline (level 6, BjornUlt): planted, a slam, and the ground erupts cell by cell down a lane.

var wall: Dictionary = {}      # the raised shield (a following verbs wall)
var shield_hp := 160.0
var down_t := 0.0              # seconds since it was lowered (regen after 2s)
var lock_t := 0.0              # broken: locked out
var front_t := 0.0             # the Shield Charge's front guard
var mend := {}                 # Mending Ground waiting to burst: {pos, t}
var mace := {}                 # the thrown mace: {} in hand, else {st: fly|ground|back, pos, dir, d, hit, node, t}
var lmb_t := -1.0              # how long the attack key has been held with the mace in hand (-1: not)
var lmb_was := false
var bot_smash_t := 0.0
var knock_until := 0.0         # a knock that can Crush is landing (bash, charge, full blow) until this time
var crushed_at := {}           # foe id -> last Crush (one per 0.6s each)
var crushes := 0               # Crushes landed (tests, demo)
var crest: Node3D = null       # the gold crest light while a Shield Slam is armed
var fx: BjornFx                # Bjorn's pooled effects
var ult: BjornUlt              # X: Faultline
var flared := false            # this hold's full-charge flare has gone off
var throws := 0                # (checks) hammers thrown, and the last throw's landing distance
var throw_d := 0.0
var slams := 0                 # (checks) Crushing Blows let go, the last one's charge and carry start
var slam_k := 0.0
var spins := 0                 # (checks) 360 Smash spin hits
var kickstarts := 0             # (checks) downed teammates Mending Ground started reviving
var throw_at := -9.0           # when the hammer last left his hand (the recall lockout)
## s after a slam or a spin hit before he can open the glider (wiki: wind-down frames keep the momentum)
const WINDDOWN := 0.3

func _setup() -> void:
	shield_hp = shield_max()
	fx = BjornFx.new(h)
	h.add_child(fx)
	self_nodes.append(fx)
	ult = BjornUlt.new(self)
	h.add_child(ult)
	self_nodes.append(ult)

func shield_max() -> float:
	return float(rmb_def()["shield"]["hp"]) + (60.0 if rank("sec") >= 3 else 0.0)

func full_ready() -> bool:
	return res >= float(res_def().get("slam", 50.0))

func res_text() -> String:
	return "SLAM" if full_ready() else "%d" % int(res)

func ready_label() -> String:
	return "SHIELD SLAM READY" if full_ready() else ""

func add_guard(v: float) -> void:
	var was := res
	add_res(v)
	touch_res()
	for step in [33.0, 66.0, 100.0]:
		if was < step and res >= step:
			m.fx.ring(h.pos, 1.0 + step / 100.0, res_col(), 0.25)      # the shield runes light in steps
			if anim_id == "": play("bul_armed")
	if was < float(res_def().get("slam", 50.0)) and full_ready():
		armed_fx("SLAM READY", "sec")

func on_block(dmg: float, by) -> void:
	add_guard(dmg * float(res_def().get("per_hp", 0.5)))
	if not wall.is_empty() or front_t > 0.0:
		var d := h.aim_dir()
		if by is Node3D and is_instance_valid(by):
			var to := Vector2((by as Node3D).global_position.x - h.pos.x, (by as Node3D).global_position.z - h.pos.z)
			if to.length() > 0.1: d = to.normalized()
		fx.aegis_block(h.pos + Vector3(d.x * 0.95, 1.1, d.y * 0.95))
		m.sfx("bjorn_block", h.pos, -5.0)

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
			var d0 := h.aim_dir()
			fx.aegis_break(h.pos + Vector3(d0.x, 0, d0.y) * 0.95)
			play("bul_break")
			m.sfx("bjorn_break", h.pos, -2.0)
		else:
			shield_hp = float(wall["hp"])
			wall["t"] = 99.0
			if h.gliding:
				h.glide_fuel = maxf(0.0, h.glide_fuel - dt / h.glide_max * (float(rmb_def()["surf_heat"]) - 1.0))
			# his aegis over the wall (armed: it burns hotter), cracking as it weakens
			fx.aegis_show(wall, 1.0 - clampf(float(wall["hp"]) / maxf(1.0, shield_max()), 0.0, 1.0), full_ready())
	else:
		fx.aegis_hide()
		down_t += dt
		if down_t >= float(sd["wait"]) and lock_t <= 0.0:
			shield_hp = minf(shield_max(), shield_hp + float(sd["regen"]) * dt)
	_tick_mace(dt)
	ult.tick(dt)
	if not mend.is_empty():
		mend["t"] = float(mend["t"]) - dt
		var u := 1.0 - clampf(float(mend["t"]) / float(e_def()["delay"]), 0.0, 1.0)
		fx.purify(mend["pos"], float(mend["r"]), u)
		AimKit.circle(h, "e", {"at": mend["pos"], "r": float(mend["r"]), "fill": u, "ticks": true, "all": true,
			"col": BjornFx.GREEN})
		if float(mend["t"]) <= 0.0: _mend_burst()
	# Guard: three rune pips over the helm (33 / 66 / 100), a gold crest light when a Slam is armed
	self_pips(3, int(res / 33.0 + 0.01), full_ready(), dt)
	_tick_crest()
	net_pulse(dt, full_ready())

func _tick_crest() -> void:
	if crest == null or not is_instance_valid(crest):
		crest = own_node()
		var lt := OmniLight3D.new()
		lt.light_color = res_col()
		lt.omni_range = 3.2
		lt.light_energy = 2.0
		crest.add_child(lt)
	crest.visible = full_ready() and tells_visible()
	if crest.visible:
		crest.global_position = h.position + Vector3(0, 2.3 * float(h.cdat.get("scale", 1.0)), 0)

func move_k() -> float:
	var k := 1.0
	if not wall.is_empty() and h.grounded:
		k *= float(rmb_def()["shield"]["slow"])
	if lmb_t > 0.2:
		k *= 0.55          # winding up the Crushing Blow
	if ult.planted():
		k = 0.0
	return k

## Behind the raised shield you can't swing or throw.
func fire_ok() -> bool:
	return wall.is_empty() and not ult.planted()

## X: Faultline. The aegis comes down and a Crushing Blow charge is dropped as he plants.
func cast_ult() -> bool:
	_drop_holds()
	return ult.cast()

## The Shield Charge's front guard: hits from the front 140° are blocked (and become Guard).
func incoming(by: Ent, dmg: float, o: Dictionary) -> Array:
	if front_t > 0.0 and by != null and is_instance_valid(by):
		var to := Vector2(by.pos.x - h.pos.x, by.pos.z - h.pos.z)
		var fwd := Vector2(-sin(h.face), -cos(h.face))
		if to.length() > 0.1 and fwd.dot(to.normalized()) > cos(deg_to_rad(70.0)):
			on_block(dmg, by)
			m.fx.flash(h.pos + Vector3(to.normalized().x * 0.6, 1.0, to.normalized().y * 0.6), res_col(), 0.4, 0.05)
			o = o.duplicate(); o.erase("kb"); o.erase("lift")
			return [0.0, o]
	return [dmg, o]

## A Shield Charge counts as being in the fight up front (the dash's own "during E" stand-in).
func in_e() -> bool:
	return not mend.is_empty()

# ------------------------------------------------------------------ Crushed (the payoff)
## A knock that drives a foe into terrain, or into another foe, Crushes it: a stun, a heal for you.
func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team or t.dead or m.time > knock_until:
		return
	if String(o.get("src", "")) == "burn" or (o.get("tags", []) as Array).has("crushed"):
		return
	_try_crush(t, Vector2(t.pos.x - h.pos.x, t.pos.z - h.pos.z).normalized())

func _foe_behind(t: Ent, dir: Vector2, reach: float) -> Ent:
	for f in m.foes_of(h.team):
		if f == t or not f.hittable(): continue
		var to := Vector2(f.pos.x - t.pos.x, f.pos.z - t.pos.z)
		var ahead := to.length() > 0.05 and to.normalized().dot(dir) > 0.5
		if to.length() < reach + f.r and ahead and absf(f.pos.y - t.pos.y) < 1.4:
			return f
	return null

func _try_crush(t: Ent, dir: Vector2) -> void:
	if dir.length() < 0.1:
		dir = h.aim_dir()
	if m.time - float(crushed_at.get(t.get_instance_id(), -9.0)) < 0.6:
		return
	var other := _foe_behind(t, dir, 1.6)
	if other == null and not terrain_behind(t, dir, float(res_def().get("crush_reach", 1.5))):
		return
	crushed_at[t.get_instance_id()] = m.time
	var rd := res_def()
	var tgt := t
	m.later(0.02, func():
		if not is_instance_valid(h) or not is_instance_valid(tgt) or tgt.dead: return
		crushes += 1
		var crush_dmg := float(rd.get("crush_dmg", 8.0)) * power("sec")
		var crush_stun := float(rd.get("crush_stun", 0.8))
		tgt.hurt(crush_dmg, h, {"src": "abil", "ab": "utility", "tags": ["utility", "crushed"], "payoff": true,
			"stun": crush_stun, "dr": true})
		if other and is_instance_valid(other) and not other.dead:
			crushed_at[other.get_instance_id()] = m.time
			other.hurt(crush_dmg, h, {"src": "abil", "ab": "utility", "tags": ["utility", "crushed"],
				"stun": crush_stun * 0.6, "dr": true})
		h.heal(float(rd.get("crush_heal", 24.0)))
		payoff_fx(tgt.pos, "CRUSHED", res_col(), "pay_slam", dir, tgt)
		if not anim_id in ["bul_smash", "bul_charge"]: play("bul_crush")
		m.fx.dust(tgt.pos, 14))

# ------------------------------------------------------------------ LMB: the mace (throw / Crushing Blow)
func _wk() -> float:
	return h.wup_dmg * m.dmg_mult(h)

func lmb_override(held: bool, dt: float) -> bool:
	if h.wid != "tower_shield":
		return false
	if ult.planted():
		lmb_was = held
		return true
	var pressed := held and not lmb_was
	lmb_was = held
	# a merge ends the Crushing Blow's charge: letting go of it must not swing mid-transformation
	if KinMerge.transforming(h):
		drop_holds()
		return true
	if not h.can_fire() or h.fire_cd > 0.0:
		if lmb_t >= 0.0 and not h.can_fire() and m.time > short_until:
			lmb_t = -1.0; h.mel_hold = 0.0
		return true
	var md := lmb_def()
	if not mace.is_empty():
		# the mace is out: a press calls it back
		# (wiki patch 20.11.24: a recall can't come within 0.25 s of the throw)
		if pressed and String(mace["st"]) != "back" and m.time - throw_at >= float(md.get("recall_lock", 0.25)):
			_recall()
		return true
	var local := h.ctrl == "local"
	if pressed and not local:
		# a bot: throw from range, wind up a Crushing Blow up close
		var tg := _bot_target()
		if tg == null or h.flat_dist(tg) > 3.4:
			_throw()
			return true
		lmb_t = 0.0
		bot_smash_t = randf_range(0.5, 1.35)
		return true
	if not local:
		if lmb_t >= 0.0:
			lmb_t += dt
			h.mel_hold = lmb_t
			_hold_tell()
			if lmb_t >= bot_smash_t: _smash()
		return true
	if held:
		if lmb_t < float(md["tap"]) and lmb_t + dt >= float(md["tap"]):
			play("bul_smash_wind")
			m.sfx("bjorn_spin", h.pos, -5.0 if h.is_local() else -9.0)
		lmb_t = maxf(lmb_t, 0.0) + dt
		h.mel_hold = lmb_t
		_hold_tell()
		if lmb_t >= float(md["full"]) + 0.4:
			_smash()           # held well past full: it goes off by itself
	elif lmb_t >= 0.0:
		if lmb_t < float(md["tap"]): _throw()
		else: _smash()
	return true

## The swing held: the hammer spins in his hand (a whoosh each turn), the glint from 0.6 s, the flare and
## the cursor ring's flare at full; the body keeps facing the cursor (Hunter faces its aim).
func _hold_tell() -> void:
	if lmb_t < float(lmb_def()["tap"]):
		return
	var k := smash_k()
	fx.hold(lmb_t, k)
	AimKit.charge(h, k, {"col": Color("ffc94a"), "col2": Color("fff1c0"), "flare": false})
	var turn := fmod(lmb_t * lerpf(1.4, 3.5, k), 1.0)
	if turn < fmod((lmb_t - Match.DT) * lerpf(1.4, 3.5, k), 1.0):
		m.sfx("bjorn_spin", h.pos, -9.0 if h.is_local() else -13.0, lerpf(0.9, 1.25, k))
	if k >= 0.99 and not flared:
		flared = true
		fx.full_flare()
		AimKit.flare(h, {"col2": Color("fff1c0")})
		m.sfx("bjorn_glint", h.pos, -3.0 if h.is_local() else -8.0)

## Charge 0..1 of the Crushing Blow being held.
func smash_k() -> float:
	var md := lmb_def()
	return clampf((lmb_t - float(md["tap"])) / maxf(0.05, float(md["full"]) - float(md["tap"])), 0.0, 1.0)

const CARRY_T := 0.24          # s the slam's forward carry lasts

## The Crushing Blow let go: the hammer sweeps round from behind into a 180 degree flaming crescent in
## front, and the slam carries him forward (a strong slam with forward momentum).
func _smash() -> void:
	play("bul_smash")
	var md := lmb_def()
	var k := smash_k()
	lmb_t = -1.0
	h.mel_hold = 0.0
	fx.hold_end()
	flared = false
	var full := k >= 0.99
	var dmg := lerpf(float(md["smash_dmg"][0]), float(md["smash_dmg"][1]), k) * _wk()
	var kb := lerpf(float(md["smash_kb"][0]), float(md["smash_kb"][1]), k)
	h.fire_cd = float(md["smash_rate"])
	slams += 1
	slam_k = k
	h.glide_cd = maxf(h.glide_cd, WINDDOWN)
	if full: knock_until = m.time + 0.25
	h._strike(dmg / m.dmg_mult(h), float(md["smash_reach"]), float(md["smash_arc"]), kb, {"heavy": true, "charged": true, "stun": float(md["smash_stun"]) if full else 0.0})
	var dv := h.aim_dir()
	# the slam carries him forward (a jump out of it still glides)
	var cr: Array = md.get("carry", [1.6, 3.4])
	if h.grounded:
		var carry := lerpf(float(cr[0]), float(cr[1]), k)          # m carried over CARRY_T
		h.dash_with({"type": "dash", "speed": carry / CARRY_T, "time": CARRY_T, "invuln": 0.0, "dir": dv, "trail": "dust"})
	var front := h.pos + Vector3(dv.x, 0, dv.y) * 1.6
	fx.slam(h.pos, dv, k)
	m.fx.dust(front, 8 + int(10 * k))
	for f in foes_in(h.pos + Vector3(dv.x, 0, dv.y) * 1.2, float(md["smash_reach"]), 2.2):
		_impact_trail(f, dv, k)
	Feel.shake(m, "t3" if full else "t2", h, h.pos)
	if h.is_local(): Oomph.punch_dir(m, dv, 0.15 + 0.25 * k)
	m.sfx("bjorn_slam", h.pos, lerpf(-4.0, 0.0, k), lerpf(1.1, 0.85, k))
	if full:
		m.fx.ring(front, 2.2, Color("ffb04a"), 0.3)
		net_ring(front, 2.2, res_col())

## A foe the slam caught: a white dust puff on them, then a debris trail as they fly back.
func _impact_trail(f: Ent, dv: Vector2, k: float) -> void:
	m.fx.burst(f.pos + Vector3(0, 0.9, 0), Color.WHITE, 10, 4.0, 0.3, 3.0, 1.1)
	for i in 3:
		m.later(0.06 * (i + 1), func():
			if is_instance_valid(f) and not f.dead:
				m.fx.burst(f.pos + Vector3(0, 0.4, 0), Color("c86a4a"), 4, 2.0 + k * 2.0, 0.35, 8.0, 0.8, Vector3(-dv.x, 0.6, -dv.y), 50.0))

func _throw() -> void:
	play("bul_throw")
	var md := lmb_def()
	lmb_t = -1.0
	h.mel_hold = 0.0
	fx.hold_end()
	h.fire_cd = float(md["throw_rate"])
	var at := h.pos + Vector3(0, 1.0, 0)
	# it lands at the cursor, clamped to its range
	var dist := AimMode.dist(h, float(md["throw_range"]), AimMode.CURSOR, float(md.get("throw_min", 5.0)))   # (wiki: at least 5 m)
	throw_at = m.time
	mace = {"st": "fly", "pos": at, "dir": h.aim_dir(), "d": 0.0, "to": dist, "hit": {}, "t": 0.0}
	throws += 1
	h.swing_t = 0.18; h.swing_n += 1
	fx.in_hand(false)
	m.sfx("bjorn_throw", h.pos, -2.0)
	Oomph.on_fire(h, true)
	net_bolt(at, at + Vector3(mace["dir"].x, 0, mace["dir"].y) * dist, Color("ffd27a"))

func _recall() -> void:
	play("bul_recall")
	mace["st"] = "back"
	mace["hit"] = {}
	m.sfx("bjorn_recall", mace["pos"], -4.0)

func _mace_hit(f: Ent, dmg: float, dir: Vector2) -> void:
	f.hurt(dmg * _wk(), h, {"src": "abil", "ab": "primary", "tags": ["primary", "mace"], "kb": dir * 3.0, "melee": true})

func _tick_mace(dt: float) -> void:
	if mace.is_empty():
		return
	var md := lmb_def()
	if h.downed or h.out:
		_catch(true)
		return
	var p: Vector3 = mace["pos"]
	match String(mace["st"]):
		"fly":
			var dir: Vector2 = mace["dir"]
			var step := float(md["throw_speed"]) * dt
			var q := p + Vector3(dir.x, 0, dir.y) * step
			mace["d"] = float(mace["d"]) + step
			var g: float = m.world.ground_at(q.x, q.z)
			var blocked: bool = m.world.is_block(q.x, q.z) or g > p.y - 0.2
			if not blocked: p = q
			for f in foes_in(p, 0.9, 1.8):
				if not (mace["hit"] as Dictionary).has(f.get_instance_id()):
					mace["hit"][f.get_instance_id()] = true
					_mace_hit(f, float(md["throw_dmg"]), dir)
			fx.hammer_fly(p, dir, 16.0)
			if blocked or float(mace["d"]) >= float(mace.get("to", md["throw_range"])):
				var gy: float = m.world.ground_at(p.x, p.z)
				if gy <= World.VOID + 1.0:
					mace["st"] = "back"; mace["hit"] = {}       # over the abyss: it comes straight back
				else:
					p = Vector3(p.x, gy + 0.15, p.z)
					mace["st"] = "ground"; mace["t"] = 0.0
					throw_d = Vector2(p.x - h.pos.x, p.z - h.pos.z).length()
					fx.hammer_plant(Vector3(p.x, gy, p.z), atan2(-dir.x, -dir.y))
					m.fx.dust(p, 8)
					m.fx.ring(Vector3(p.x, gy, p.z), 1.0, BjornFx.GOLD, 0.25)
					m.sfx("bjorn_plant", p, -3.0)
					net_ring(p, 1.2, Color("ffd27a"))
		"ground":
			mace["t"] = float(mace["t"]) + dt
			# it shows foes near it to your team (vision where it stands)
			for f in foes_in(p, float(md["vision_r"]), 3.0):
				if "reveal_t" in f: f.set("reveal_t", maxf(float(f.get("reveal_t")), 0.4))
			if Vector2(h.pos.x - p.x, h.pos.z - p.z).length() < 1.2 and absf(h.pos.y - p.y) < 1.5:
				_catch()
				return
			if float(md.get("lie_t", 0.0)) > 0.0 and float(mace["t"]) >= float(md["lie_t"]):
				_recall()
		"back":
			var to := h.pos + Vector3(0, 1.0, 0) - p
			var step := float(md["recall_speed"]) * dt
			var dir2 := Vector2(to.x, to.z).normalized()
			if to.length() <= step + 0.6:
				_catch()
				return
			p += to.normalized() * step
			for f in foes_in(p, 0.9, 1.8):
				if not (mace["hit"] as Dictionary).has(f.get_instance_id()):
					mace["hit"][f.get_instance_id()] = true
					_mace_hit(f, float(md["recall_dmg"]), dir2)
			fx.hammer_fly(p, dir2, 16.0)
	mace["pos"] = p

func _catch(quiet := false) -> void:
	mace = {}
	fx.hammer_hide()
	fx.in_hand(true)
	if quiet:
		return
	m.sfx("bjorn_catch", h.pos, -6.0)
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), Color("ffb04a"), 8, 2.5, 0.25)
	m.fx.flash(h.pos + Vector3(0, 1.0, 0), Color("ffb04a"), 0.5, 0.06)

# ------------------------------------------------------------------ RMB: Shield (hold to block, release or tap to Bash)
## The shield is a block, not a charge (the Crushing Blow on LMB is the Bulwark's charge).
func rmb_charge_full() -> float:
	return 0.0

## In the air the press doesn't fire at once: holding it there is Shield Surf.
func press_rmb() -> void:
	if busy() or ult.planted():
		h._ab_feedback("sec", "deny")
		return
	if rmb_down:
		return
	rmb_down = true
	rmb_t = 0.0
	rmb_ctx = {"air": not h.grounded or h.gliding, "e": in_e(), "full": full_ready()}
	lmb_t = -1.0; h.mel_hold = 0.0
	if anim_id == "bul_smash_wind": anim_id = ""

func rmb_hold_tick(t: float) -> void:
	if t >= float(rmb_def()["hold"]) and wall.is_empty() and lock_t <= 0.0 and shield_hp > 5.0:
		_raise()

func _raise() -> void:
	var sd: Dictionary = rmb_def()["shield"]
	var d := h.aim_dir()
	wall = m.verbs.add_wall(h, h.pos + Vector3(d.x, 0, d.y) * 1.0, d, {"length": float(sd["len"]), "hp": shield_hp, "time": 99.0, "follow": true, "dist": 0.95, "block": "enemy", "color": rmb_def().get("col", "#9ad8ff")}, 1.0)
	h.mel_hold = 0.0
	last_variant = "air" if rmb_ctx.get("air", false) else "hold"
	play("bul_guard")
	m.sfx("bjorn_shield_up", h.pos, -4.0)

var short_until := 0.0         # a short dash out of a Crushing Blow is under way: the wind-up waits, it isn't cancelled

## A Boki merge ends every hold of this kit with no release effect: the Crushing Blow's charge (lmb_t) and the raised
## shield (it keeps its hit points and starts its regen). The mace in flight and Mending Ground's pending burst are casts, not holds.
func _drop_holds() -> void:
	if lmb_t >= 0.0:
		lmb_t = -1.0
		h.mel_hold = 0.0
	flared = false
	if fx: fx.hold_end()
	if not wall.is_empty():
		_lower()
	rmb_down = false
	if ult: ult.drop()
	if anim_id in ["bul_smash_wind", "bul_guard", "bul_ult_wind"]:
		anim_id = ""

func _lower() -> void:
	if wall.is_empty():
		return
	shield_hp = float(wall["hp"])
	if m.verbs.walls.has(wall):
		m.verbs.walls.erase(wall)
		if is_instance_valid(wall["node"]): (wall["node"] as Node3D).queue_free()
	wall = {}
	down_t = 0.0
	fx.aegis_hide()
	if anim_id == "bul_guard": anim_id = ""

func fire_rmb(c: Dictionary) -> void:
	var was_up := not wall.is_empty()
	_lower()
	if c.get("air", false) and was_up:
		return                    # a Shield Surf just ends
	if not rmb_ready():
		if not was_up: h._ab_feedback("sec", "deny")
		return
	# a tap, or letting go after a block: the Bash (a Shield Slam with 50 Guard)
	c = c.duplicate()
	c["full"] = full_ready()
	last_variant = "full" if c["full"] else ("hold" if was_up else String(c["variant"]))
	if not spend_rmb(): return
	var bd: Dictionary = rmb_def()["bash"]
	var slam: bool = c["full"]
	var go := func():
		if not is_instance_valid(h) or h.downed: return
		if not slam: play("bul_bash")
		var effs: Array = [{"type": "damage", "amount": float(rmb_def()["slam"]["dmg"]) if slam else float(bd["dmg"])}, {"type": "push", "strength": float(rmb_def()["slam"]["push"]) if slam else float(bd["push"]), "from": "caster"}]
		if slam: effs.append({"type": "stun", "duration": float(rmb_def()["slam"]["stun"])})
		knock_until = m.time + 0.2
		var stg := stage("rmb", {"delivery": {"type": "cone", "radius": float(bd["radius"]), "angle": float(bd["angle"])}, "effects": effs})
		run(stg, cx("rmb", "shield_slam" if slam else "bash", aim(), {"no_floor": true, "hit_extra": {"heavy": true}}))
		var dv := h.aim_dir()
		m.fx.cone(h.pos + Vector3(0, 0.1, 0), dv, float(bd["radius"]), res_col() if slam else col_of(rmb_def()))
		m.fx.flash(h.pos + Vector3(dv.x * 0.9, 1.0, dv.y * 0.9), res_col() if slam else Color("d8e8ff"), 0.9, 0.06)
		m.sfx("bjorn_bash", h.pos, -1.0, 0.85 if slam else 1.0)
		Feel.shake(m, "t3" if slam else "t2", h, h.pos)
		if h.is_local(): Oomph.punch_dir(m, dv, 0.3 if slam else 0.18)
		if h.grounded:
			h.vel.x += dv.x * 4.0; h.vel.z += dv.y * 4.0         # you step into it
	if slam:
		# Shield Slam spends 50 Guard; a 0.3s shield flare is the tell (its own wind-up and drive)
		res -= float(res_def().get("slam", 50.0))
		play("bul_slamshield")
		m.fx.flash(h.pos + Vector3(h.aim_dir().x * 0.8, 1.0, h.aim_dir().y * 0.8), res_col(), 0.9, float(rmb_def()["slam"]["tell"]))
		tele_lane(h.pos, h.aim_dir(), float(bd["radius"]), 2.0, Feel.cat_color("control"), float(rmb_def()["slam"]["tell"]))
		net_ring(h.pos, 1.6, res_col())
		m.later(float(rmb_def()["slam"]["tell"]), go)
	else:
		go.call()

func fire_ok_rmb() -> bool:
	return lock_t <= 0.0

# ------------------------------------------------------------------ dash: Whirl / Shield Charge
func on_dash(use_ex: bool) -> bool:
	if ult.planted():
		return true          # planted for the slam: Shift waits
	var dd := dash_def()
	if lmb_t > float(lmb_def().get("tap", 0.2)) and h.grounded and mace.is_empty():
		# Shift while winding up the Crushing Blow: a short plain dash (no spin), half a charge, the blow keeps charging
		if not spend_dash(false): return true
		h.dashes = minf(h.max_dashes(), h.dashes + 0.5)       # (half the charge comes back: the reduced cooldown)
		var sd2 := float(dd.get("short", 2.6))
		travel(sd2, sd2 / float(dd["whirl_speed"]), {"invuln": 0.0, "trail": "dust", "dir": h.aim_dir()})
		st["last_dash"] = "short"
		short_until = m.time + sd2 / float(dd["whirl_speed"]) + 0.2
		play("bul_short")
		m.sfx("ab_whirr", h.pos, -6.0, 0.9)
		return true
	if not wall.is_empty() and h.grounded:
		# Shield Charge: behind the raised shield, invulnerable for its length, a heavier knock
		if not spend_dash(false): return true
		var dist := float(dd["charge"]) + (1.0 if rank("dash") >= 3 else 0.0)
		var t := dist / float(dd["charge_speed"])
		travel(dist, t, {"invuln": t + 0.08, "shove": true, "shove_kb": float(dd["charge_kb"]), "shove_dmg": float(dd["charge_dmg"]), "trail": "dust", "dir": h.aim_dir()})
		front_t = t + 0.15
		knock_until = m.time + t + 0.1
		st["last_dash"] = "charge"
		play("bul_charge")
		m.fx.word(h.pos + Vector3(0, 2.3, 0), "SHIELD CHARGE", col_of(dd), false)
		m.sfx("shield", h.pos, 0.0, 0.55)
		return true
	if not spend_dash(use_ex):
		return true
	if use_ex:
		# the long dash (in the air, or out of charges): Bjorn lumbers in shoulder first, shoving foes aside
		var de := float(h.cdat.get("ex_dist", 4.2))
		travel(de, de / float(dd.get("lumber_speed", 14.0)), {"invuln": 0.1, "shove": true, "shove_kb": 6.0, "shove_dmg": 0.0, "trail": "dust"}, true)
		st["last_dash"] = "lumber"
		play("bul_lumber")
		for i in 4:
			m.later(0.07 * i, func(): if is_instance_valid(h): m.fx.dust(h.pos, 5); m.fx.burst(h.pos + Vector3(0, 0.6, 0), Color(String(d.get("color", "#8fd0ff"))), 3, 1.2, 0.3, 0.0, 1.2))
		return true
	# 360 Smash: a short fixed dash in the aim (or move) direction, then ONE full spin hit around him
	var dist2 := float(dd["whirl"]) + (1.0 if rank("dash") >= 3 else 0.0)
	var t2 := dist2 / float(dd["whirl_speed"])
	travel(dist2, t2, {"invuln": 0.1, "trail": "dust"}, use_ex)
	st["last_dash"] = "whirl"
	play("bul_whirl")
	m.fx.burst(h.pos + Vector3(0, 0.2, 0), Color("e6d8ff"), 8, 3.0, 0.2, 2.0, 0.8)
	m.later(t2, func():
		if is_instance_valid(h) and not h.downed and not KinMerge.active(h): _spin_hit())
	return true

## The 360 Smash's spin on arrival: one hit all round him, a red-gold swirl ring.
func _spin_hit() -> void:
	var dd := dash_def()
	var r := float(dd.get("spin_r", 2.2))
	spins += 1
	h.glide_cd = maxf(h.glide_cd, WINDDOWN)
	h._strike(float(dd["whirl_dmg"]) * h.wup_dmg * power("dash") / maxf(0.01, m.dmg_mult(h)), r, 360.0, float(dd["whirl_kb"]), {"heavy": true})
	fx.smash_ring(h.pos)
	m.fx.dust(h.pos, 10)
	Feel.shake(m, "t2", h, h.pos)
	m.sfx("bjorn_whirl", h.pos, -2.0)
	net_ring(h.pos, r, Color("ff7a3a"))

# ------------------------------------------------------------------ E: Mending Ground
func cast_e() -> bool:
	var ed := e_def()
	var at := ground(h.pos)                   # with the hammer in hand it comes down on you
	if not mace.is_empty() and String(mace["st"]) == "ground":
		at = ground(mace["pos"])          # ...else where the hammer stands
	var r := float(ed["radius"]) + (0.5 if rank("kin") >= 3 else 0.0)
	play("bul_mend")
	mend = {"pos": at, "t": float(ed["delay"]), "r": r}
	e_t = float(ed["delay"])
	fx.purify(at, r, 0.0)
	m.sfx("bjorn_purify", at, -2.0)
	net_ring(at, r, Feel.cat_color("sustain"))
	return true

func _mend_burst() -> void:
	var ed := e_def()
	var at: Vector3 = mend["pos"]
	var r: float = mend["r"]
	mend = {}
	var heal := float(ed["heal"]) + (10.0 if rank("kin") >= 3 else 0.0)
	# a downed teammate inside starts coming back (wiki: allied wisps hit by the burst begin to resurrect)
	for o in m.hunters:
		if o != h and o.team == h.team and o.downed and not o.out and Vector2(o.pos.x - at.x, o.pos.z - at.z).length() < r:
			o.revive = minf(0.95, o.revive + float(ed.get("revive", 0.35)))
			kickstarts += 1
			m.fx.burst(o.pos + Vector3(0, 0.8, 0), BjornFx.GREEN, 14, 3.0, 0.5, -3.0)
	for o in m.hunters:
		if o.team == h.team and not o.out and not o.downed and Vector2(o.pos.x - at.x, o.pos.z - at.z).length() < r:
			o.heal(heal * (1.25 if rank("kin") >= 2 else 1.0))
			m.fx.burst(o.pos + Vector3(0, 1.0, 0), Feel.cat_color("sustain"), 12, 2.5, 0.5, -3.0)
			if o == h and not wall.is_empty():
				shield_hp = minf(shield_max(), shield_hp + float(ed["shield"]))
				if m.verbs.walls.has(wall): wall["max_hp"] = shield_max(); wall["hp"] = minf(shield_max(), float(wall["hp"]) + float(ed["shield"]))
	# the kin's typing rides the burst (a cleanse, a shield, a slow on foes...)
	var stg := stage("e", {"delivery": {"type": "burst", "origin": "aim", "radius": r}, "effects": [{"type": "slow", "duration": 1.0, "strength": float(ed["slow"])}]})
	run(stg, cx("e", "mending_ground", at, {"no_floor": true}))
	fx.purify_burst(at, r)
	m.fx.ring(at, r, BjornFx.GREEN, 0.45)
	m.fx.burst(at + Vector3(0, 0.3, 0), BjornFx.GREEN, 24, 4.0, 0.8, -4.0, 1.2, Vector3.UP, 25.0)
	m.sfx("bjorn_purify_burst", at, 0.0)
	net_ring(at, r, Feel.cat_color("sustain"))

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and (h.hp < h.max_hp * 0.65 or shield_hp < shield_max() * 0.4) and randf() < 0.5:
		h.inp["aim"] = h.pos; h.inp["sig"] = true; return
	if int(h.slot_lv["sec"]) > 0:
		var shot_at: bool = m.time - h.hurt_at < 0.6 and dist > 3.0
		if shot_at and lock_t <= 0.0 and shield_hp > 30.0:
			# raise the shield toward whoever is shooting
			h.inp["aim"] = tgt.pos
			if not rmb_down: h.inp["sec"] = true
			bot_hold["rmb"] = 1.0
		elif dist < 2.6 and rmb_ready():
			h.inp["aim"] = tgt.pos; h.inp["sec"] = true
	# close in: a Shield Charge from behind the shield, else a Whirl
	if int(h.slot_lv["dash"]) > 0 and h.dashes >= 1.0 and los and dist < 4.5 and dist > 1.5 and randf() < 0.3:
		h.inp["aim"] = tgt.pos
		h.ai["dash_dir"] = h.dir_to(tgt)
		h.inp["move"] = h.dir_to(tgt)
		h.inp["dash"] = true
