class_name BulwarkKit
extends ArchKit
## Breaker (id bulwark, heavy): the squad's shield. docs/heroes/bulwark.md, hero sheet bjorn.md.
##
## - LMB (War Hammer): tap throws the hammer to the cursor (clamped to its range; it passes through foes
##   and stays planted under a gold beacon, showing foes near it to your team, until you tap again to
##   call it back, hitting on the way). Hold whirls the hammer round him at arm's length, turning faster as it
##   charges (a glint on its head from 0.6 s, no damage until he lets go); at full (1.25 s) a flash
##   on its head and a click open the perfect window, the whirl still going. Let go and it's a Crushing Blow: a
##   flaming 180 degree crescent in front that steps him forward with it; let go in the window and it's the
##   perfect swing, a leaping launch (BjornLaunch).
## - RMB: hold to raise his aegis (its own HP, regenerates); letting go only lowers it.
## - Dash: 360 Smash, a short dash that ends in one full spin hit around him; with the aegis raised it's
##   the Shield Charge (the Bash: invulnerable for its length, a heavier knock) on the RMB slot's own cooldown.
## - Passive, Crushed: any knock of his (the hammer thrown or called back, Crushing Blow, 360 Smash, Shield
##   Charge) that drives a foe into a wall stuns them (T4, pay_slam). No resource.
## - E, Mending Ground: a green column comes down for 1 s, then a zone round the hammer (on you when the hammer
##   is in hand) heals a little every 0.5 s for 4 s and ends in a burst that also mends a raised aegis.
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
var knock_until := 0.0         # a knock that can Crush is landing (blow, spin, charge) until this time
var crushed_at := {}           # foe id -> last Crush (one per 0.6s each)
var crushes := 0               # Crushes landed (tests, demo)
var fx: BjornFx                # Breaker's pooled effects
var ult: BjornUlt              # X: Faultline
var launch: BjornLaunch        # the perfect swing's launch
var flared := false            # this hold's full-charge flare has gone off
var spin := 0.0                # the whirled hammer's angle (rad), counted on match time (BjornFx draws it)
var throws := 0                # (checks) hammers thrown, and the last throw's landing distance
var throw_d := 0.0
var slams := 0                 # (checks) Crushing Blows let go, the last one's charge and carry start
var slam_k := 0.0
var spins := 0                 # (checks) 360 Smash spin hits
var kickstarts := 0             # (checks) downed teammates Mending Ground started reviving
var ticks_healed := 0           # (checks) heals the zone's ticks gave
var throw_at := -9.0           # when the hammer last left his hand (the recall lockout)
var hold_blocked := false      # the Crushing Blow was cut short: the button must come up before it can start again
var pushed_at := {}            # foe id -> when the aegis last pushed it (one push per "push_gap")
var pushes := 0                # (checks) foes the raised aegis has pushed back
var dash_after_plant := false  # Shift came in while planted for Faultline: the dash goes when the plant ends
var step_until := 0.0          # the swing's step or the perfect launch runs until this time
var glove_cd_seen := [0.0, 0.0] # each glove slot's cooldown last step: a jump means a glove just went off
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
	launch = BjornLaunch.new(self)

## The aegis grows by "hp_rank" of its base HP for every rank past the first (rank 2: +25%, rank 3: +50%).
func shield_max() -> float:
	var sd: Dictionary = rmb_def()["shield"]
	return float(sd["hp"]) * (1.0 + float(sd["hp_rank"]) * float(rank("sec") - 1))

## One of the aegis's repair numbers; rank 3 swaps in the faster "<key>_rank3" value.
func _shield_stat(key: String) -> float:
	var sd: Dictionary = rmb_def()["shield"]
	if rank("sec") >= 3 and sd.has(key + "_rank3"):
		return float(sd[key + "_rank3"])
	return float(sd[key])

## The Shield Charge's own cooldown drops by "cd_per_rank" seconds for every dash rank past the first, and
## Mending Ground's drops to its rank-3 time; the shared rule keeps the other slots.
func cd_k(slot: String) -> float:
	if slot == "sec":
		var cut := float(rmb_def().get("cd_per_rank", 1.5)) * float(rank("dash") - 1)
		return 1.0 - cut / float(rmb_def()["cooldown"])
	if slot == "kin":
		return float(e_def()["cooldown_rank3"]) / float(e_def()["cooldown"]) if rank("kin") >= 3 else 1.0
	return super.cd_k(slot)

## Mending Ground heals 25% more at rank 2 and another 25% at rank 3.
func heal_k() -> float:
	return 1.0 + 0.25 * float(rank("kin") - 1)

func on_block(_dmg: float, by) -> void:
	if not wall.is_empty() or front_t > 0.0:
		var d := h.aim_dir()
		if by is Node3D and is_instance_valid(by):
			var to := Vector2((by as Node3D).global_position.x - h.pos.x, (by as Node3D).global_position.z - h.pos.z)
			if to.length() > 0.1: d = to.normalized()
		fx.aegis_block(h.pos + Vector3(d.x * 0.95, 1.1, d.y * 0.95))
		m.sfx("bjorn_block", h.pos, -5.0)

func _tick(dt: float) -> void:
	lock_t = maxf(0.0, lock_t - dt)
	front_t = maxf(0.0, front_t - dt)
	var sd: Dictionary = rmb_def()["shield"]
	if not wall.is_empty():
		if not m.verbs.walls.has(wall):
			# broken: locked out for 3s
			wall = {}
			shield_hp = 0.0
			lock_t = _shield_stat("lock")
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
			# his aegis over the wall, cracking as it weakens
			fx.aegis_show(wall, 1.0 - clampf(float(wall["hp"]) / maxf(1.0, shield_max()), 0.0, 1.0))
			_shield_push()
	else:
		fx.aegis_hide()
		down_t += dt
		if down_t >= _shield_stat("wait") and lock_t <= 0.0:
			shield_hp = minf(shield_max(), shield_hp + _shield_stat("regen") * dt)
	_tick_glove()
	_tick_mace(dt)
	ult.tick(dt)
	if h.dash_buf > 0.0 and m.time < step_until:
		h.roll_t = 0.0         # Shift in the swing's step or launch: the dash goes now (item 51), not at its end
	launch.tick(dt)
	if dash_after_plant and not ult.planted():
		dash_after_plant = false
		h.dash_buf = Hunter.DASH_BUFFER
	if not mend.is_empty():
		_tick_mend(dt)

# ------------------------------------------------------------------ the raised aegis pushes back
## The aegis's contact reach past its own thickness (m): a foe pressed against it is in range.
const PUSH_REACH := 0.4

## Foes that meet the raised aegis are shoved back along its facing ("push" m, once per "push_gap" s each), and
## a hunter dashing into it is stopped. The double chevron in front of it shows the push (BjornFx.push_hint).
func _shield_push() -> void:
	var sd: Dictionary = rmb_def()["shield"]
	var push := float(sd.get("push", 2.0))
	var n := h.aim_dir()
	var a: Vector2 = wall["a"]
	var b: Vector2 = wall["b"]
	var flash := false
	for f in m.foes_of(h.team):
		if not f.hittable():
			continue
		var p := Vector2(f.pos.x, f.pos.z)
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var reach: float = f.r + Verbs.WALL_TH + PUSH_REACH
		var key: int = f.get_instance_id()
		var in_front: bool = (p - q).dot(n) > 0.0 and absf(f.pos.y - float(wall["y"])) < 2.2
		var gap_ok: bool = m.time - float(pushed_at.get(key, -9.0)) >= float(sd.get("push_gap", 0.6))
		if in_front and p.distance_to(q) < reach and gap_ok:
			pushed_at[key] = m.time
			_shove(f, n, push, float(sd.get("push_speed", 14.0)))
			pushes += 1
			flash = true
	fx.push_hint(wall, n, push, flash)
	if flash:
		m.sfx("bjorn_bash", h.pos, -5.0, 1.4)

## A Q glove going off is another ability starting: it ends a Crushing Blow being wound up.
func _tick_glove() -> void:
	var used := false
	for gi in 2:
		used = used or float(h.gear_cd[gi]) > float(glove_cd_seen[gi]) + 0.001
		glove_cd_seen[gi] = float(h.gear_cd[gi])
	if used and lmb_t >= 0.0:
		cancel_hold()

## Slides a pushed foe back along the aegis's facing (a wall behind it stops the slide; Displace: a player
## online slides on their own game).
func _shove(f: Ent, dir: Vector2, dist: float, speed: float) -> void:
	var push := {"mode": "push", "dir": [dir.x, dir.y], "dist": dist, "spd": speed, "dur": dist / speed + 0.1}
	push["unroll"] = true          # a hunter dashing into it is stopped
	m.displace.tow(f, null, push)

func move_k() -> float:
	var k := 1.0
	if not wall.is_empty() and h.grounded:
		k *= float(rmb_def()["shield"]["slow"])
	if lmb_t > 0.2:
		k *= 0.55          # winding up the Crushing Blow
	if ult.planted():
		k = 0.0
	return k

## The shared charge ring at his feet burns in his gold; the hammer head carries the hand tell (BjornFx).
func charge_color() -> Color:
	return BjornFx.GOLD

func charge_orb() -> bool:
	return false

## His dash after-image: a gold chevron wake instead of the shared ghost.
func dash_afterimage() -> bool:
	fx.afterimage(h.position, h.face, float(h.cdat.get("scale", 1.0)))
	return true

## Behind the raised shield you can't swing or throw.
func fire_ok() -> bool:
	return wall.is_empty() and not ult.planted()

## X: Faultline. The aegis comes down and a Crushing Blow charge is dropped as he plants.
func cast_ult() -> bool: return HeroUlt.press(self, _start_ult)
func has_ult() -> bool: return true

func _start_ult() -> bool:
	_drop_holds()
	return ult.cast()

func ult_running() -> bool:
	return ult.phase != ""

## The Shield Charge's front guard: hits from the front 140° are blocked.
func incoming(by: Ent, dmg: float, o: Dictionary) -> Array:
	if _aegis_takes(by, o):
		m.verbs.absorb(wall, dmg)          # it takes the hit as it does a shot
		o = o.duplicate(); o.erase("kb"); o.erase("lift")
		return [0.0, o]
	if front_t > 0.0 and by != null and is_instance_valid(by):
		var to := Vector2(by.pos.x - h.pos.x, by.pos.z - h.pos.z)
		var fwd := Vector2(-sin(h.face), -cos(h.face))
		if to.length() > 0.1 and fwd.dot(to.normalized()) > cos(deg_to_rad(70.0)):
			on_block(dmg, by)
			m.fx.flash(h.pos + Vector3(to.normalized().x * 0.6, 1.0, to.normalized().y * 0.6), res_col(), 0.4, 0.05)
			o = o.duplicate(); o.erase("kb"); o.erase("lift")
			return [0.0, o]
	return [dmg, o]

## The raised aegis blocks all damage from the front (data: Brightshield), melee and abilities as well as the
## shots the wall itself stops: a hit from a foe inside its arc, facing the cursor. Damage over time isn't a hit.
func _aegis_takes(by: Ent, o: Dictionary) -> bool:
	if wall.is_empty() or by == null or not is_instance_valid(by) or o.get("tick", false):
		return false
	if String(o.get("src", "")) in ["burn", "fall", "heat"]:
		return false
	var to := Vector2(by.pos.x - h.pos.x, by.pos.z - h.pos.z)
	var half := deg_to_rad(float(rmb_def()["shield"].get("arc", 140.0)) * 0.5)
	return to.length() > 0.1 and h.aim_dir().dot(to.normalized()) > cos(half)

## A Shield Charge counts as being in the fight up front (the dash's own "during E" stand-in).
func in_e() -> bool:
	return not mend.is_empty()

# ------------------------------------------------------------------ Crushed (the payoff)
## A knock that drives a foe into terrain, or into another foe, Crushes it: a stun.
func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team or t.dead or m.time > knock_until:
		return
	if String(o.get("src", "")) == "burn" or (o.get("tags", []) as Array).has("crushed"):
		return
	_try_crush(t, Vector2(t.pos.x - h.pos.x, t.pos.z - h.pos.z).normalized())

func _try_crush(t: Ent, dir: Vector2) -> void:
	if dir.length() < 0.1:
		dir = h.aim_dir()
	if m.time - float(crushed_at.get(t.get_instance_id(), -9.0)) < 0.6:
		return
	if not terrain_behind(t, dir, float(d["passive"]["crush_reach"])):
		return
	crushed_at[t.get_instance_id()] = m.time
	var pd: Dictionary = d["passive"]
	var tgt := t
	m.later(0.02, func():
		if not is_instance_valid(h) or not is_instance_valid(tgt) or tgt.dead: return
		crushes += 1
		var crush_dmg := float(pd["crush_dmg"]) * power("sec")
		var crush_stun := float(pd["crush_stun"])
		tgt.hurt(crush_dmg, h, {"src": "abil", "ab": "utility", "tags": ["utility", "crushed"], "payoff": true,
			"stun": crush_stun, "dr": true})
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
	if not held:
		hold_blocked = false
	if _hold_interrupted():
		if lmb_t >= 0.0:
			cancel_hold()
		elif pressed:
			lmb_was = false    # a fresh press while he's busy waits: still held when he's free, it goes then
		return true
	if hold_blocked:
		return true
	# a hold carried through a dash (hold rows: keep) charges on in it and swings on the release
	var rides_dash := lmb_t >= 0.0 and flow.move_now() in ["ground", "air"]
	if not rides_dash and (not h.can_fire() or h.fire_cd > 0.0):
		return true
	var md := lmb_def()
	if not mace.is_empty():
		# the mace is out: a press calls it back
		# (wiki patch 20.11.24: a recall can't come within 0.25 s of the throw)
		if pressed and String(mace["st"]) != "back" and m.time - throw_at >= float(md.get("recall_lock", 0.25)):
			_recall()
		elif pressed and String(mace["st"]) != "back":
			buffer_recast("lmb")            # inside the lockout: RecastCue's buffer recalls it as soon as it may
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
		_resume_wind()
	elif lmb_t >= 0.0:
		if lmb_t < float(md["tap"]): _throw()
		else: _smash()
	return true

## Out of a dash with the swing still held: back into the spin's pose at the point the charge has reached (the
## kit move eases over from the dash's).
func _resume_wind() -> void:
	if anim_id in ["bul_short", "bul_lumber", "bul_whirl"] and h.roll_t <= 0.0 and lmb_t >= float(lmb_def()["tap"]):
		play("bul_smash_wind")
		anim_at = m.time - (lmb_t - float(lmb_def()["tap"]))

## True while something else has him: a move whose hold row ends the hold (content/dash_flow/bulwark.json: a
## mantle), a glide, a stun, a launch or a hard knock. The held Crushing Blow ends the moment one starts, and the
## button has to come up before it can begin again.
func _hold_interrupted() -> bool:
	var pad_flight := not h.pad.is_empty() and not h.mantling()
	return flow.ends_hold("lmb") or h.gliding or h.stun_t > 0.0 or h.downed or pad_flight \
		or not h.grap.is_empty() or m.time - maxf(h.kb_time, h.kb_t) < 0.12

## Ends the Crushing Blow's hold with no swing (another ability started, or he was moved): the spin and its
## tell stop at once and the held button is ignored until it is released.
func cancel_hold() -> void:
	if lmb_t >= 0.0 or h.mel_hold > 0.0:
		lmb_t = -1.0
		h.mel_hold = 0.0
		flared = false
		fx.hold_end()
		if anim_id == "bul_smash_wind":
			anim_id = ""
	hold_blocked = bool(h.inp.get("fire", false))

## The swing held: the hammer whirls round him (BjornFx draws it; the angle is counted here on match time, the
## rate is lmb.spin_turns from no charge to full, a whoosh each turn), the glint from 0.6 s; at full the perfect
## window opens with a flash on its head, a click and the cursor ring's flare (the glint burns hot until the
## window shuts); the body keeps facing the cursor (Hunter faces its aim). The whirl itself never hits.
func _hold_tell() -> void:
	if lmb_t < float(lmb_def()["tap"]):
		return
	var k := smash_k()
	if not fx.held:
		spin = h.face         # (the head leaves from in front of him)
	var was := spin
	var rate: Array = lmb_def()["spin_turns"]
	spin += TAU * lerpf(float(rate[0]), float(rate[1]), k) * Match.DT
	fx.hold(lmb_t, k, launch.in_window(lmb_t), spin)
	AimKit.charge(h, k, {"col": Color("ffc94a"), "col2": Color("fff1c0"), "flare": false})
	if floori(spin / TAU) > floori(was / TAU):
		m.sfx("bjorn_spin", h.pos, -9.0 if h.is_local() else -13.0, lerpf(0.9, 1.25, k))
	if k >= 0.99 and not flared:
		flared = true
		fx.full_flare()
		AimKit.flare(h, {"col2": Color("fff1c0")})
		m.sfx("bjorn_glint", h.pos, -3.0 if h.is_local() else -8.0)
		m.sfx("click", h.pos, -2.0 if h.is_local() else -9.0, 1.6)

## Charge 0..1 of the Crushing Blow being held.
func smash_k() -> float:
	var md := lmb_def()
	return clampf((lmb_t - float(md["tap"])) / maxf(0.05, float(md["full"]) - float(md["tap"])), 0.0, 1.0)

const CARRY_T := 0.24          # s the slam's forward step lasts

## The Crushing Blow let go: the hammer sweeps round from behind into a 180 degree flaming crescent in
## front and the slam steps him forward ("carry" m); let go in the perfect window it launches him instead
## (BjornLaunch), knocks harder ("perfect.kb_k") and lands with a heavier hit-stop. His own swing never shakes his
## screen (item 50, the owner's rule): the hit-stop, the crescent, the dust and the sound carry it.
func _smash() -> void:
	var md := lmb_def()
	var k := smash_k()
	var perfect := launch.in_window(lmb_t)
	lmb_t = -1.0
	h.mel_hold = 0.0
	fx.hold_end()
	flared = false
	var full := k >= 0.99
	var dmg := lerpf(float(md["smash_dmg"][0]), float(md["smash_dmg"][1]), k) * _wk()
	var kb := lerpf(float(md["smash_kb"][0]), float(md["smash_kb"][1]), k)
	if perfect:
		kb *= float(launch.pd().get("kb_k", 1.4))
	h.fire_cd = float(md["smash_rate"])
	slams += 1
	slam_k = k
	knock_until = m.time + 0.25
	h._strike(dmg / m.dmg_mult(h), float(md["smash_reach"]), float(md["smash_arc"]), kb,
		{"heavy": true, "charged": true, "stun": float(md["smash_stun"]) if full else 0.0})
	var dv := h.aim_dir()
	if perfect:
		launch.start(dv)
	else:
		_carry(dv, k)
	fx.slam(dv, k)
	m.fx.dust(h.pos + Vector3(dv.x, 0, dv.y) * 1.6, 8 + int(10 * k))
	for f in foes_in(h.pos + Vector3(dv.x, 0, dv.y) * 1.2, float(md["smash_reach"]), 2.2):
		_impact_trail(f, dv, k)
		if perfect:
			Feel.hitstop(m, h, f, dmg, {"melee": true, "heavy": true, "payoff": true})
	var heavier := 1.0 if perfect else 0.0
	m.sfx("bjorn_slam", h.pos, lerpf(-4.0, 0.0, k) + 2.0 * heavier, lerpf(1.1, 0.85, k) - 0.1 * heavier)

## The normal swing's step: "carry" m in all (more with the charge; the dash over CARRY_T plus its exit
## slide), on the ground only, then a short wind-down before the glider can open. Let go in the air or in
## a dash, the swing rides the move he's in.
func _carry(dv: Vector2, k: float) -> void:
	play("bul_smash")
	h.glide_cd = maxf(h.glide_cd, WINDDOWN)
	if not h.grounded or h.roll_t > 0.0:
		return
	var cr: Array = lmb_def().get("carry", [1.5, 1.8])
	var carry := lerpf(float(cr[0]), float(cr[1]), k)
	carry -= HunterMove.slide(minf(carry / CARRY_T, h.base_speed * HunterMove.dash_exit_run))
	h.dash_with({"type": "dash", "speed": carry / CARRY_T, "time": CARRY_T, "invuln": 0.0, "dir": dv, "trail": "dust"})
	step_until = m.time + CARRY_T

## A foe the slam caught: a white dust puff on them, then a debris trail as they fly back.
func _impact_trail(f: Ent, dv: Vector2, k: float) -> void:
	m.fx.burst(f.pos + Vector3(0, 0.9, 0), Color.WHITE, 10, 4.0, 0.3, 3.0, 1.1)
	for i in 3:
		m.later(0.06 * (i + 1), func():
			if is_instance_valid(f) and not f.dead:
				m.fx.burst(f.pos + Vector3(0, 0.4, 0), Color("c86a4a"), 4, 2.0 + k * 2.0, 0.35, 8.0, 0.8, Vector3(-dv.x, 0.6, -dv.y), 50.0))

## s the hammer stays in his hand after the throw starts; with the step it's queued on (~0.04 s) it leaves
## ~0.15 s after the press, as the arm comes through in bul_throw (its release key, 0.14 s; sheet 0033-0034)
const THROW_WIND := 0.10

func _throw() -> void:
	play("bul_throw")
	var md := lmb_def()
	lmb_t = -1.0
	h.mel_hold = 0.0
	fx.hold_end()
	h.fire_cd = float(md["throw_rate"])
	var at := h.pos + Vector3(0, 1.0, 0)
	# it lands at the cursor, clamped to its range
	var dist := AimMode.dist(h, float(md["throw_range"]), AimMode.CURSOR, float(md.get("throw_min", 2.5)))
	throw_at = m.time
	mace = {"st": "wind", "pos": at, "dir": h.aim_dir(), "d": 0.0, "to": dist, "hit": {}, "t": 0.0}
	throws += 1
	h.swing_t = 0.18; h.swing_n += 1
	m.sfx("bjorn_throw", h.pos, -2.0)
	Oomph.on_fire(h, true)
	net_bolt(at, at + Vector3(mace["dir"].x, 0, mace["dir"].y) * dist, Color("ffd27a"))
	CombatBus.ability_used.emit(h, id + "_throw", "primary")

## RecastCue: LMB again calls the hammer back (from the recall lockout on); the marker rides the hammer. Lying
## on the ground it comes back by itself after lie_t (the ring runs down then).
func recast_window() -> Dictionary:
	if mace.is_empty() or String(mace["st"]) == "back":
		return {}
	var md := lmb_def()
	var lie := float(md.get("lie_t", 0.0))
	var total := lie if lie > 0.0 else 1.0
	var left := total - float(mace["t"]) if lie > 0.0 and String(mace["st"]) == "ground" else total
	var armed: bool = m.time - throw_at >= float(md.get("recall_lock", 0.25))
	return RecastCue.window("lmb", left, total, mace["pos"], armed, true)

func recast_now(slot_id: String) -> void:
	if slot_id == "lmb" and not mace.is_empty() and String(mace["st"]) != "back":
		_recall()
	else:
		super(slot_id)

func _recall() -> void:
	play("bul_recall")
	mace["st"] = "back"
	mace["hit"] = {}
	m.sfx("bjorn_recall", mace["pos"], -4.0)
	CombatBus.ability_used.emit(h, id + "_recall", "primary")       # a press with the hammer out is the recall

func _mace_hit(f: Ent, dmg: float, dir: Vector2) -> void:
	knock_until = m.time + 0.25       # its knock into a wall Crushes too (data: any knock into a wall)
	f.hurt(dmg * _wk(), h, {"src": "abil", "ab": "primary", "tags": ["primary", "mace"], "kb": dir * 3.0, "melee": true})
	m.sfx("bulwark_hammer_clang", f.pos, -4.0)

func _tick_mace(dt: float) -> void:
	if mace.is_empty():
		return
	var md := lmb_def()
	if h.downed or h.out:
		_catch(true)
		return
	var p: Vector3 = mace["pos"]
	match String(mace["st"]):
		"wind":
			# still in his hand while the arm comes through: it leaves THROW_WIND s after the press
			p = h.pos + Vector3(0, 1.0, 0)
			mace["t"] = float(mace["t"]) + dt
			if float(mace["t"]) >= THROW_WIND:
				mace["st"] = "fly"
				fx.in_hand(false)
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
					m.sfx("bjorn_plant", p, -3.0)
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

# ------------------------------------------------------------------ RMB: Shield (hold to block)
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
	rmb_ctx = {"air": not h.grounded or h.gliding, "e": in_e()}
	cancel_hold()

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
	m.sfx("bulwark_hull_creak", h.pos, -7.0)      # the prow's old timbers take the strain
	fx.aegis_rise(h.pos + Vector3(d.x, 0, d.y) * 1.2)

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
	dash_after_plant = false
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

## Letting go of the RMB only lowers the aegis: the Bash lives on Shift behind a raised shield (the Shield Charge).
func fire_rmb(c: Dictionary) -> void:
	var was_up := not wall.is_empty()
	_lower()
	last_variant = "air" if c.get("air", false) and was_up else ("hold" if was_up else "tap")

func fire_ok_rmb() -> bool:
	return lock_t <= 0.0

# ------------------------------------------------------------------ dash: Whirl / Shield Charge
func on_dash(use_ex: bool) -> bool:
	if ult.planted():
		dash_after_plant = true          # planted for the slam: Shift goes when the plant ends (into_dash.x)
		return true
	var dd := dash_def()
	var winding := lmb_t > float(lmb_def().get("tap", 0.2))
	if flow.ends_hold("lmb", flow.dash_move()):
		cancel_hold()
		winding = false
	if winding and h.grounded and mace.is_empty():
		# Shift while winding up the Crushing Blow: a short plain dash (no spin: the hammer is busy) on a full
		# charge, the swing still charging through it (hold.lmb.ground)
		if not spend_dash(false): return true
		var sd2 := float(dd.get("short", 2.6))
		travel(sd2, sd2 / float(dd["whirl_speed"]), {"invuln": 0.0, "trail": "dust", "dir": dash_dir()})
		st["last_dash"] = "short"
		play("bul_short")
		m.sfx("bjorn_spin", h.pos, -6.0, 0.9)
		return true
	if wall.is_empty() and rmb_down and lock_t <= 0.0 and shield_hp > 5.0:
		_raise()          # Shift while the aegis is still rising: it is up now, the bash goes
	if not wall.is_empty():
		# Shield Charge (into_dash.rmb): behind the raised shield, on the ground or riding it in the air (Shield
		# Surf), on its own cooldown (the RMB slot's), invulnerable for its length, a heavier knock
		if not spend_rmb(): return true
		var dist := float(dd["charge"]) + (1.0 if rank("dash") >= 3 else 0.0)
		var t := dist / float(dd["charge_speed"])
		var t_felt := t * float(dash_feel()["time"])
		travel(dist, t, {"invuln": t_felt + 0.08, "shove": true, "shove_kb": float(dd["charge_kb"]), "shove_dmg": float(dd["charge_dmg"]), "trail": "dust", "dir": h.aim_dir()})
		front_t = t_felt + 0.15
		knock_until = m.time + t_felt + 0.1
		st["last_dash"] = "charge"
		play("bul_charge")
		m.fx.word(h.pos + Vector3(0, 2.3, 0), "SHIELD CHARGE", col_of(dd), false)
		m.sfx("bulwark_charge", h.pos, -2.0)
		return true
	use_ex = use_ex and h.dashes < 1.0         # a charge in the air is the same 360 Smash (item 183)
	if not spend_dash(use_ex):
		return true
	if use_ex:
		# the long dash (out of charges): Breaker lumbers in shoulder first, shoving foes aside
		var de := float(h.cdat.get("ex_dist", 4.2))
		travel(de, de / float(dd.get("lumber_speed", 14.0)), {"invuln": 0.1, "shove": true, "shove_kb": 6.0, "shove_dmg": 0.0, "trail": "dust"})
		st["last_dash"] = "lumber"
		play("bul_lumber")
		for i in 4:
			m.later(0.07 * i, func(): if is_instance_valid(h): m.fx.dust(h.pos, 5))
		return true
	# 360 Smash: a short fixed dash in the aim (or move) direction, then ONE full spin hit around him
	var dist2 := float(dd["whirl"]) + (1.0 if rank("dash") >= 3 else 0.0)
	var t2 := dist2 / float(dd["whirl_speed"])
	var wd := dash_dir()
	travel(dist2, t2, {"invuln": 0.1, "trail": "dust", "dir": wd})
	t2 *= float(dash_feel()["time"])          # the spin lands when the (feel-scaled) dash arrives
	st["last_dash"] = "whirl"
	play("bul_whirl")
	m.later(t2, func():
		if is_instance_valid(h) and not h.downed and not KinMerge.active(h) and not ult.planted(): _spin_hit(wd))
	return true

## m/s he keeps sliding forward with through the 360 Smash's spin (about 1 m)
const SPIN_GLIDE := 6.0

## The 360 Smash's spin on arrival: one hit all round him, a red-gold swirl ring, still sliding on along
## `wd`.
func _spin_hit(wd: Vector2) -> void:
	if h.grounded:
		h.vel.x += wd.x * SPIN_GLIDE
		h.vel.z += wd.y * SPIN_GLIDE
	var dd := dash_def()
	var r := float(dd.get("spin_r", 2.2))
	spins += 1
	knock_until = m.time + 0.25
	if rank("dash") >= 3 and not foes_in(h.pos, r).is_empty():
		# rank 3: hitting foes with the dash refunds the Shield Charge (cue only when something was spent)
		if ch_rmb < float(rmb_charges()) or float(cd["rmb"]) > 0.0: DashReset.cue(h, "dash_hit")
		ch_rmb = float(rmb_charges())
		cd["rmb"] = 0.0
	h.glide_cd = maxf(h.glide_cd, WINDDOWN)
	h._strike(float(dd["whirl_dmg"]) * h.wup_dmg * power("dash") / maxf(0.01, m.dmg_mult(h)), r, 360.0, float(dd["whirl_kb"]), {"heavy": true})
	fx.smash_ring(h.pos)
	m.fx.dust(h.pos, 10)
	m.sfx("bjorn_whirl", h.pos, -2.0)
	net_ring(h.pos, r, Color("ff7a3a"))

# ------------------------------------------------------------------ E: Mending Ground
## Where the zone sits: round the hammer wherever it is (planted, flying out or back), else round him.
func _zone_anchor() -> Vector3:
	if not mace.is_empty():
		return ground(mace["pos"])
	return ground(h.pos)

func cast_e() -> bool:
	cancel_hold()
	var ed := e_def()
	var at := _zone_anchor()
	var r := float(ed["radius"])
	play("bul_mend")
	mend = {"pos": at, "t": float(ed["delay"]), "r": r, "zone": -1.0, "tick": 0.0}
	e_t = float(ed["delay"]) + float(ed["time"])
	fx.purify(at, r, 0.0)
	m.sfx("bjorn_purify", at, -2.0)
	net_ring(at, r, Feel.cat_color("sustain"))
	return true

## The light column comes down ("delay"), then the zone heals everyone inside a little every "every" s for
## "time" s (following the hammer) and ends in a burst.
func _tick_mend(dt: float) -> void:
	var ed := e_def()
	var r := float(mend["r"])
	mend["pos"] = _zone_anchor()
	if float(mend["zone"]) < 0.0:
		mend["t"] = float(mend["t"]) - dt
		var u := 1.0 - clampf(float(mend["t"]) / float(ed["delay"]), 0.0, 1.0)
		fx.purify(mend["pos"], r, u)
		AimKit.circle(h, "e", {"at": mend["pos"], "r": r, "fill": u, "ticks": true, "all": true, "col": BjornFx.GREEN})
		if float(mend["t"]) <= 0.0:
			mend["zone"] = float(ed["time"])
			mend["tick"] = float(ed["every"])
			m.fx.ring(mend["pos"], r, BjornFx.GREEN, 0.4)
		return
	mend["zone"] = float(mend["zone"]) - dt
	mend["tick"] = float(mend["tick"]) - dt
	fx.purify_hold(mend["pos"], r)
	AimKit.circle(h, "e", {"at": mend["pos"], "r": r, "fill": float(mend["zone"]) / float(ed["time"]), "all": true,
		"col": BjornFx.GREEN})
	if float(mend["tick"]) <= 0.0:
		mend["tick"] = float(mend["tick"]) + float(ed["every"])
		_mend_tick()
	if float(mend["zone"]) <= 0.0:
		_mend_burst()

func _allies_in(at: Vector3, r: float) -> Array:
	var out: Array = []
	for o in m.hunters:
		if o.team == h.team and not o.out and Vector2(o.pos.x - at.x, o.pos.z - at.z).length() < r:
			out.append(o)
	return out

func _mend_tick() -> void:
	var heal := float(e_def()["tick_heal"]) * heal_k()
	for o in _allies_in(mend["pos"], float(mend["r"])):
		if o.downed:
			continue
		ticks_healed += 1
		o.heal(heal)
		m.fx.burst(o.pos + Vector3(0, 1.0, 0), Feel.cat_color("sustain"), 4, 1.5, 0.35, -3.0)

func _mend_burst() -> void:
	var ed := e_def()
	var at: Vector3 = mend["pos"]
	var r: float = mend["r"]
	mend = {}
	var heal := float(ed["heal"]) * heal_k()
	# a downed teammate inside starts coming back (wiki: allied wisps hit by the burst begin to resurrect)
	for o in _allies_in(at, r):
		if o != h and o.downed:
			o.revive = minf(0.95, o.revive + float(ed.get("revive", 0.35)))
			kickstarts += 1
			m.fx.burst(o.pos + Vector3(0, 0.8, 0), BjornFx.GREEN, 14, 3.0, 0.5, -3.0)
		elif not o.downed:
			o.heal(heal)
			m.fx.burst(o.pos + Vector3(0, 1.0, 0), Feel.cat_color("sustain"), 12, 2.5, 0.5, -3.0)
			if o == h and not wall.is_empty():
				shield_hp = minf(shield_max(), shield_hp + float(ed["shield"]))
				if m.verbs.walls.has(wall): wall["max_hp"] = shield_max(); wall["hp"] = minf(shield_max(), float(wall["hp"]) + float(ed["shield"]))
	# the kin's typing rides the burst (a cleanse, a shield, a slow on foes...); with no kin it has nothing to carry
	if not infusion().is_empty():
		var stg := stage("e", {"delivery": {"type": "burst", "origin": "aim", "radius": r}, "effects": []})
		run(stg, cx("e", "mending_ground", at, {"no_floor": true}))
	fx.purify_burst(at, r)
	m.fx.ring(at, r, BjornFx.GREEN, 0.45)
	m.fx.burst(at + Vector3(0, 0.3, 0), BjornFx.GREEN, 24, 4.0, 0.8, -4.0, 1.2, Vector3.UP, 25.0)
	m.sfx("bjorn_purify_burst", at, 0.0)
	net_ring(at, r, Feel.cat_color("sustain"))

# ------------------------------------------------------------------ bots
## The hammer: called back from where it landed, else thrown at a foe out of arm's reach.
func _bot_hammer(dist: float, los: bool) -> void:
	var reach := float(lmb_def()["throw_range"]) - 1.0
	if not mace.is_empty():
		h.inp["fire"] = String(mace["st"]) == "ground" and m.time - throw_at > 0.8
	elif los and wall.is_empty() and dist > 3.6 and dist < reach and randf() < 0.7:
		h.inp["fire"] = true

func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and (h.hp < h.max_hp * 0.65 or shield_hp < shield_max() * 0.4) and randf() < 0.5:
		h.inp["aim"] = h.pos; h.inp["sig"] = true; return
	_bot_hammer(dist, los)
	if HeroUlt.ready(self) and los and dist > 4.0 and dist < 13.0:
		h.inp["aim"] = tgt.pos
		HunterKeys.ult_pressed(h)
		return
	if int(h.slot_lv["sec"]) > 0:
		var shot_at: bool = m.time - h.hurt_at < 0.6 and dist > 3.0
		if shot_at and lock_t <= 0.0 and shield_hp > 30.0:
			# raise the shield toward whoever is shooting
			h.inp["aim"] = tgt.pos
			if not rmb_down: h.inp["sec"] = true
			bot_hold["rmb"] = 1.0
		elif dist < 4.5 and rmb_ready() and not rmb_down:
			h.inp["aim"] = tgt.pos; h.inp["sec"] = true
			bot_hold["rmb"] = 1.2
	# close in: a Shield Charge from behind the shield, else a Whirl
	# (behind the raised aegis the dash is the Shield Charge)
	var odds := 0.8 if not wall.is_empty() and rmb_ready() else 0.3
	if int(h.slot_lv["dash"]) > 0 and h.dashes >= 1.0 and los and dist < 4.5 and dist > 1.5 and randf() < odds:
		h.inp["aim"] = tgt.pos
		h.ai["dash_dir"] = h.dir_to(tgt)
		h.inp["move"] = h.dir_to(tgt)
		h.inp["dash"] = true
