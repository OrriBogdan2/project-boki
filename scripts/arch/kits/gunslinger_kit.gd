class_name GunslingerKit
extends ArchKit
## Vex (archetype id "gunslinger", medium): the ember-rifle skirmisher. docs/heroes/gunslinger.md
## has the per-slot table, the assumptions and the research notes (briefs/hero-ref/venator.md, owner notes).
##
## Loop: tap RMB and the Burr Charge fires from the arm-cannon's launcher along the aim. A direct hit on a foe
## damages and Dazes it ("rat" Rattled in code) on the spot.
## Otherwise it flies its 10.5 m and sticks where it meets a wall
## or the ground at the end: a cone shows back toward you for its fuse, then blasts, shoving
## everyone in it along the cone (toward you), hurting and Dazing them too. The rifle does +90% to a Dazed foe, in big
## gold numbers, and the string doesn't decay on them. Slipstep goes where you move and you keep
## shooting. Longneedle: stand still while the line narrows, the aim turning only so fast, then a long beam
## through walls. A knock gives Slipstep back (Hot Streak); abilities that land add a little lifesteal (Fever).

const EMBER := Color("ff9a5c")
const HOT := Color("fff1c8")
const DEEP := Color("c43a2a")
const BRONZE := Color("b9732f")
const SMOKE := Color("d9c2a8")       # the Longneedle's recoil smoke ring: warm, not white
const SCRAPE := Color("6b4a2e")      # the slide's dust scrape under her
const BURR_HIT_HEIGHT := 2.6         # m above a foe's feet the charge can still strike
const PUSH_EASE := 10.0              # 1/s; the view push-out follows the aim distance, settling in ~0.3 s, no jumps
const SKID_LEN := 2.2                # m, the faint streaks at a slide's start
const SKID_SPREAD := 0.28            # m off the path's centre line
const SKID_WIDTH := 0.1
const SKID_SECONDS := 0.45
const ECHO_GAP := 0.05               # s between her after-images on a slide or the air dash
const ECHO_ALPHA := 0.35             # see-through, so the trail never covers her live body
const ECHO_BACK := 0.35              # m behind her along her travel: the echoes trail, not overlap
const PIP_LIFT := 0.9                # m up the screen the Fever pips sit, clear of her cap and face
const TUBE_UP := 0.16                # m above the gun's muzzle: the launcher tube, on a model without its empties
const TUBE_FIRE := "launcher_fire"   # fixed on the cannon at the bell's firing spot: the charge leaves from here
const TUBE_BELL := "launcher_muzzle" # on the swinging launcher: over and forward only after TUBE_SWING
const TUBE_SWING := 0.1              # s from the press to the bell coming forward
const BRACKET_R := 1.25              # m: the firing brackets either side of her (footage: about 0.7 bh)
const BRACKET_DEG := 56.0            # each bracket's arc
const SPIN_REST := 0.5               # s without a round before the next string winds the barrels up again

var slide := {}                # {t, held, dir} while a Slipstep runs
var burrs: Array = []          # Burr Charges in flight or stuck: {pos, dir, t, node, wall, fuse, fuse0, range, out, y0}
var burr_pool: Array = []      # their nodes, reused
var needle := {}               # Longneedle's charge: {t, dir (the turn-capped aim), push (0..1 of the view push-out)}
var knocked := {}
var direct_hits := 0           # Burr Charges that struck a foe (tests)
var rattles := 0               # Burr Charges that blew (tests)
var dazed_hits := 0            # rifle rounds on a Dazed foe (tests)
var skewers := 0               # Longneedle payoffs
var needle_hits := 0
var needle_dir := Vector2.ZERO # tests: the line the last Longneedle fired along
var wall_slams := 0
var last_dash_kind := ""
var last_cone := {}            # tests: {at, dir, wall}
var last_shot := 0
var puffs := 0                 # tests: launcher puffs
var last_puff := Vector3.ZERO  # tests: where the last one went off
var echo_t := 0.0
var refill_part := 0.0         # rounds the resting drum has part-refilled
var dry := false               # the drum ran dry: no round until it is full again
var round_at := -9.0           # match time of her last rifle round (the firing brackets)
var ult: GunslingerUlt         # Cinderfall, her ultimate on X

func _setup() -> void:
	ult = GunslingerUlt.new(self)

func fx() -> VVFx:
	return VVFx.of(m)

func cast_ult() -> bool:
	return HeroUlt.press(self, ult.cast)

func has_ult() -> bool:
	return true

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
	if ult.running():
		ult.tick(dt)
	_tick_lmb()
	_tick_mag(dt)
	_tick_brackets()
	_tick_echo(dt)
	_tick_trail()
	_tick_walk_off()
	self_pips(int(res_def()["max"]), int(floor(res + 0.01)), false, dt, PIP_LIFT, 0.65)

func own_dash_trail() -> bool:
	return true

func dodge_anim() -> String:
	return "slide" if not slide.is_empty() else ""      # Slipstep: the kit move is the whole pose (no roll)

func shows_charge_ball() -> bool:
	return false                   # the Longneedle charges an ember orb at the muzzle instead

## Moves whose hand leaves an ember swoosh: [hand, from s, to s].
const TRAILS := {"gunslinger_knock": ["r", 0.0, 0.25]}
const SLIDE_KEY := 0.45              # s: the dash clip's last slide key (vex.json "dash", low from 0.08): a held slide
                                     # keeps the clip there, so she stands up as the skid ends, not mid-skid
const WALK_OFF := {"gunslinger_dash": 0.0, "gunslinger_e": 0.8}   # s into the move its hit is past: the dash's
                                     # from the skid's end, the Longneedle's once its shove has played
const OVER := 2.0                    # s: older than any of her clips (the longest runs 1.07 s): a move aged this far
                                     # is over to the clips (the kit's anim_id is read as long as it is set)

## Walking out of a move's recovery (the slide's stand-up, the Longneedle's settle): the legs are hers again and
## the walk blends in (WardenClips.FADE_LOCO) in place of the clip's stand-still pose, the source's Ghost walking off.
## (Clearing anim_id would not do: the published anim state keeps the last kmove until another move plays.)
func _tick_walk_off() -> void:
	if not WALK_OFF.has(anim_id) or not slide.is_empty() or not needle.is_empty() or not h.grounded:
		return
	var walking := (h.inp.get("move", Vector2.ZERO) as Vector2).length() > 0.5
	if walking and float(m.time) - anim_at >= float(WALK_OFF[anim_id]):
		anim_at = float(m.time) - OVER        # the move reads as over: past its clip, the body goes back to the legs

func _tick_trail() -> void:
	var tr: Array = TRAILS.get(anim_id, [])
	var t := float(m.time) - anim_at
	if tr.is_empty() or h.anim == null or t < float(tr[1]) or t > float(tr[2]):
		return
	var hand: Node3D = h.anim.hand_l if String(tr[0]) == "l" else h.anim.hand_r
	if hand != null:
		fx().trail("vn%d" % h.get_instance_id(), hand.global_position, EMBER, HOT, 0.24)

## Her after-image colour: a deeper ember, so the trail reads apart from her warm live body.
static func echo_col() -> Color:
	return EMBER.lerp(DEEP, 0.5)

## Her own after-images on Slipstep and the air dash: her silhouette in ember, cooling to deep red.
func _tick_echo(dt: float) -> void:
	if h.roll_t <= 0.0 and slide.is_empty():
		echo_t = 0.0
		return
	echo_t -= dt
	if echo_t > 0.0:
		return
	echo_t = ECHO_GAP
	fx().echo(h, echo_col(), 0.4, ECHO_ALPHA, ECHO_BACK)

func teardown() -> void:
	super.teardown()
	for b in burrs:
		if b["node"] != null and is_instance_valid(b["node"]): (b["node"] as Node3D).visible = false
	burrs.clear()
	ult.clear()
	_end_needle()

func move_k() -> float:
	return 1.0 - float(e_def()["self_slow"]) if not needle.is_empty() else 1.0

## The rifle can't fire while a dry drum refills (_tick_mag).
func fire_ok() -> bool:
	return not dry

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

## Hot Streak: a knock gives Slipstep back (the takedown heal is DashReset's); rank 3 also resets the Burr Charge.
func _on_knock(t: Ent) -> void:
	knocked[t.get_instance_id()] = true
	h.dashes = h.max_dashes()
	if rank("sec") >= 3:
		ch_rmb = float(rmb_charges())
		cd["rmb"] = 0.0
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "+KNOCK", Color("8ff0a0"), false)
	m.sfx("vn_stim", h.pos, -3.0)
	play("gunslinger_knock")
	DashReset.cue(h)

# ------------------------------------------------------------------ LMB: the rifle's rounds
## Each round: a hot ember needle with a cooling tail, a bronze star at the muzzle, the shoulder kick.
func _tick_lmb() -> void:
	if h.shot_n == last_shot:
		return
	last_shot = h.shot_n
	if m.time - round_at > SPIN_REST:
		m.sfx("gunslinger_spinup", h.pos, -6.0)      # the shoulder cannon winds up as a string starts
	round_at = m.time
	var shots: Array = m.get("shots")
	for i in range(shots.size() - 1, -1, -1):
		var sd: Dictionary = shots[i]
		if sd["by"] == h and not (sd["x"] as Dictionary).has("src"):
			fx().ride(sd, "tracer", EMBER, HOT, 2.6, 0.18, _round_end)
			fx().star(sd["pos"], BRONZE, HOT, 0.75, 0.06)
			break
	if anim_id == "" or anim_id == "gunslinger_lmb" or m.time - anim_at > 1.2:
		play("gunslinger_lmb")

## While the rifle fires, two thin arcs bracket her left and right (your screen only; the footage's firing
## brackets), gone a beat after the trigger rests.
func _tick_brackets() -> void:
	if not _rifle_in_hand() or m.time - round_at > float(h.wpn["rate"]) + 0.1 or busy():
		return
	var d := h.aim_dir()
	for side in [-1.0, 1.0]:
		AimKit.arc_wall(h, "lmb_bracket%d" % int(side), {"dir": Vector2(-d.y, d.x) * side, "radius": BRACKET_R,
				"deg": BRACKET_DEG, "thick": 0.05, "panels": 1})

func _rifle_in_hand() -> bool:
	return h.wid == String(d.get("signature", ""))

## The drum (the source's rifle: 30 rounds that "rapidly reload when not firing"; there is no reload key): once no
## round has left for `refill_after` it refills at `refill_rate`, so a string after a pause starts full. Run dry,
## the trigger is dead until the drum is full again (held or not), then the string picks up.
func _tick_mag(dt: float) -> void:
	if not _rifle_in_hand():
		dry = false
		return
	var mag := int(h.wpn["mag"])
	if h.ammo <= 0:
		dry = true
	if h.ammo >= mag or h.idle_fire < float(h.wpn["refill_after"]):
		refill_part = 0.0
		if h.ammo >= mag:
			dry = false
		return
	refill_part += float(h.wpn["refill_rate"]) * dt
	var add := int(refill_part)
	refill_part -= float(add)
	h.ammo = mini(mag, h.ammo + add)

func _round_end(at: Vector3, vel: Vector2) -> void:
	var d := Vector3(-vel.x, 0.4, -vel.y).normalized() if vel.length() > 0.1 else Vector3.UP
	m.fx.spark(at, d, EMBER, 3, 5.0, 50.0, 0.14, 8.0, 0.7)

# ------------------------------------------------------------------ dash: Slipstep
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if use_ex and h.dashes >= 1.0 and not h.grounded:
		# an air tap: a slide of 2/3 the full hold's distance (source patch notes), spending a charge
		h.dashes -= 1.0
		var ad := float(dd["slide"]) * float(dd.get("air_k", 0.667))
		var air_t := float(dd["slide_t"]) * 0.6
		travel(ad, air_t, {"invuln": float(dd["invuln"])})
		slide = {"t": 0.0, "held": false, "dir": h.roll_dir, "fx": 0.0, "air": true, "len_t": air_t}
		play("gunslinger_dash")
		fx().echo(h, echo_col(), 0.5, ECHO_ALPHA, ECHO_BACK)
		m.sfx("vn_slide", h.pos, -4.0, 1.2)
		last_dash_kind = "air_slide"
		return true
	if use_ex:
		if not spend_dash(true):
			return true
		travel(float(h.cdat.get("ex_dist", 4.6)) * 0.9, float(h.cdat.get("ex_time", 0.2)), {"invuln": 0.08})
		play("gunslinger_dash_ex")
		fx().echo(h, echo_col(), 0.45, ECHO_ALPHA, ECHO_BACK)
		last_dash_kind = "air"
		return true
	if not spend_dash(false):
		return true
	var start := h.position
	travel(float(dd["roll"]), float(dd["roll_t"]), {"invuln": float(dd["invuln"])})
	slide = {"t": 0.0, "held": false, "dir": h.roll_dir, "fx": 0.0}
	play("gunslinger_dash")
	# where it began: her ember after-image standing there (0.6 s), dust, and two faint skid streaks.
	# No rings or discs: those mean damage or an area in this game
	fx().echo(h, echo_col(), 0.6, ECHO_ALPHA, ECHO_BACK)
	_skid_streaks(start, h.roll_dir)
	m.fx.dust(h.pos, 10)
	m.sfx("vn_slide", h.pos, -4.0)
	return true

## Two short, low-contrast scrape lines on the ground along the first stretch of the slide.
func _skid_streaks(from: Vector3, dir: Vector2) -> void:
	var along := Vector3(dir.x, 0.0, dir.y)
	var side := Vector3(-dir.y, 0.0, dir.x) * SKID_SPREAD
	var low := Vector3(0.0, 0.05, 0.0)
	for sign_k in [-1.0, 1.0]:
		var begin: Vector3 = ground(from) + low + side * sign_k
		fx().smear(begin, begin + along * SKID_LEN, SCRAPE, SCRAPE.lightened(0.2), SKID_WIDTH, SKID_SECONDS)

func _slide_end() -> void:
	h.roll_t = 0.0
	if rank("dash") >= 3:
		h.add_buff("move_speed", 0.25, 2.0)
	var air := bool(slide.get("air", false))
	if air and not h.gliding:
		h.vel.x *= 0.25          # an air slide stops short instead of carrying on (a glide press carries it, item 4)
		h.vel.z *= 0.25
	var kind := "slide" if bool(slide.get("held", false)) else "step"
	st["last_dash"] = "air_slide" if air else kind
	last_dash_kind = String(st["last_dash"])
	slide = {}

## A tap: a skid that starts fast and bleeds off to a run over roll_t, covering `roll` m (you shoot
## through it); the speed falls linearly from the peak that covers the distance.
func _skid(t: float, dd: Dictionary) -> void:
	var feel := dash_feel()                 # the global dash feel, as travel() applies it
	var dur := float(dd["roll_t"]) * float(feel["time"])
	if t >= dur:
		_slide_end()
		return
	var run := float(h.cdat["speed"])
	var peak := 2.0 * float(dd["roll"]) * float(feel["dist"]) / dur - run
	h.roll_speed = lerpf(peak, run, t / dur)

func _tick_slide(dt: float) -> void:
	if h.gliding:
		_slide_end()      # a glide press cancelled it (Hunter._dash_into_glide): the glide has its speed now
		return
	var dd := dash_def()
	slide["t"] = float(slide["t"]) + dt
	var t := float(slide["t"])
	slide["fx"] = float(slide["fx"]) - dt
	if float(slide["fx"]) <= 0.0:
		slide["fx"] = 0.06
		m.fx.dust(h.pos, 2)            # (the after-images and the scrape are _tick_echo's)
	if not bool(slide["held"]):
		if bool(slide.get("air", false)):
			if t >= float(slide["len_t"]):
				_slide_end()
			return
		var can_hold := not h.downed and h.stun_t <= 0.0 and h.root_t <= 0.0 and h.grounded
		if t >= float(dd["tap_t"]) and not bool(slide.get("tap", false)):
			if held("dash") and can_hold:
				slide["held"] = true
				slide["t0"] = t
				h.dashes -= float(dd["hold_cost"])       # the longer slide takes longer to come back
				h.roll_dir = slide["dir"]
				h.move_kind = "dash"
				m.fx.dust(h.pos, 8)
				return
			slide["tap"] = true
		_skid(t, dd)
		return
	var st_t := t - float(slide["t0"])
	var dur := float(dd["slide_t"])
	if not held("dash") or st_t >= dur or h.stun_t > 0.0 or h.root_t > 0.0:
		_slide_end()
		return
	var k := 1.0 - st_t / dur
	h.roll_t = maxf(h.roll_t, dt * 1.5)
	if anim_id == "gunslinger_dash":
		anim_at = maxf(anim_at, float(m.time) - SLIDE_KEY)   # the clip stays low on its slide key while she slides
	h.roll_speed = float(dd["slide"]) / dur * (0.5 + k)
	h.inv_t = 0.0

# ------------------------------------------------------------------ RMB: Burr Charge
func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if not spend_rmb():
		return
	var bd := rmb_def()["burr"] as Dictionary
	var d := h.aim_dir()
	var n: Node3D = null
	for p in burr_pool:
		if is_instance_valid(p) and not (p as Node3D).visible:
			n = p
			break
	if n == null:
		n = _burr_mesh()
		burr_pool.append(n)
	n.visible = true
	n.scale = Vector3.ONE
	var at := _launcher_at(d)
	n.global_position = at
	var burr := {"pos": at, "dir": d, "t": 0.0, "node": n, "wall": false, "fuse": -1.0, "fuse0": float(bd["fuse"])}
	burr["range"] = float(bd["range"])
	burr["y0"] = at.y
	burr["g0"] = ground(h.pos).y
	burrs.append(burr)
	play("gunslinger_rmb")
	_launcher_puff(at, d)
	m.sfx("gunslinger_grenade_thunk", h.pos, -2.0)

## Where the Burr Charge leaves: the cannon's firing spot, read live so it follows the aim, else above the muzzle.
func _launcher_at(d: Vector2) -> Vector3:
	var spot := WardenGlb.anchor(h.model, TUBE_FIRE)
	if spot != null:
		return spot.global_position
	var muzzle := h.model.get_node_or_null("Rig/Torso/Aim/Gun/Muzzle") as Node3D if h.model else null
	return (muzzle.global_position if muzzle else _muzzle(d)) + Vector3.UP * TUBE_UP

## The launcher's puff: at the bell once it has swung forward, or at once where there is no swinging bell.
func _launcher_puff(at: Vector3, d: Vector2) -> void:
	var bell := WardenGlb.anchor(h.model, TUBE_BELL)
	if bell == null:
		_puff(at, d)
		return
	m.later(TUBE_SWING, func():
		if is_instance_valid(bell) and is_instance_valid(h):
			_puff(bell.global_position, h.aim_dir()))

func _puff(at: Vector3, d: Vector2) -> void:
	puffs += 1
	last_puff = at
	m.fx.muzzle(at, d, EMBER, 2.0)

## The charge: a bronze ball about 0.3 m across, a dark band round it, an ember heart showing through
## and eight hot spikes. Solid colours, so it reads bronze and ember on any ground.
func _burr_mesh() -> Node3D:
	var n := own_node()
	Models.part(n, Models.sphere(0.15, 12), Models.shiny(BRONZE, 0.6))
	var band := Models.cyl(0.155, 0.155, 0.06, 14)
	Models.part(n, band, Models.toon(Color("2b2a33"), false, 0.0))
	var heart := Models.part(n, Models.sphere(0.07, 8), solid_mat(EMBER), Vector3(0, 0.1, 0.1))
	heart.name = "Glow"
	for i in 8:
		var a := TAU * i / 8.0
		var out := Vector3(cos(a), sin(i * 2.1) * 0.5, sin(a)).normalized()
		var spike := Models.part(n, Models.crystal(0.04, 0.17, 4), solid_mat(HOT), out * 0.17)
		var up := Vector3.UP if absf(out.y) < 0.95 else Vector3.RIGHT
		spike.look_at_from_position(spike.position, spike.position * 2.0, up)
	for ch in n.get_children():
		(ch as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
			var cone := {"from": b["pos"], "dir": b["out"], "len": float(bd["cone_len"]), "deg": float(bd["cone_deg"])}
			cone.merge({"fill": k, "all": true, "col": EMBER, "col2": HOT, "hot": k})
			AimKit.cone(h, "burr%d" % n.get_instance_id(), cone)
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
		var victim := _burr_victim(p, flat)
		if victim != null:
			burrs.erase(b)
			_direct_hit(b, victim, flat)
			continue
		var ledge: bool = m.world.ground_at(flat.x, flat.z) > float(b["g0"]) + 0.6
		var walled: bool = m.world.is_block(flat.x, flat.z) or ledge
		if walled:
			_stick(b, p, true)
		elif dist >= float(b["range"]):
			_stick(b, ground(flat) + Vector3(0, 0.2, 0), false)       # the ground at the lane's end
		else:
			b["pos"] = flat
			var back := Vector3(dir.x, 0, dir.y) * 0.35
			fx().smear(p - back, flat, DEEP, HOT, 0.3, 0.2)      # the ember smear behind it (joined up)
			if int(b["t"] * 60.0) % 3 == 0:
				m.fx.burst(flat, EMBER, 3, 0.6, 0.25, 0.0, 0.7)
		if is_instance_valid(n):
			n.global_position = b["pos"]
			n.rotation.y += dt * 14.0

## The first foe the charge touches between two steps, or null. Reach is the foe's body plus the lane's half width.
func _burr_victim(from: Vector3, to: Vector3) -> Ent:
	var reach_extra := float(rmb_def()["burr"]["lane_w"]) * 0.5
	var from_flat := Vector2(from.x, from.z)
	var to_flat := Vector2(to.x, to.z)
	var best: Ent = null
	var best_along := INF
	for f in m.foes_of(h.team):
		if not f.hittable():
			continue
		var height: float = to.y - f.pos.y
		if height < -0.3 or height > BURR_HIT_HEIGHT:
			continue
		var foe_flat := Vector2(f.pos.x, f.pos.z)
		var closest := Geometry2D.get_closest_point_to_segment(foe_flat, from_flat, to_flat)
		if closest.distance_to(foe_flat) > f.r + reach_extra:
			continue
		var along := from_flat.distance_to(closest)
		if along < best_along:
			best_along = along
			best = f
	return best

## A direct hit: it hurts and Dazes the foe it struck and is spent, with no cone.
func _direct_hit(b: Dictionary, victim: Ent, at: Vector3) -> void:
	var bd := rmb_def()["burr"] as Dictionary
	var n: Node3D = b["node"]
	if is_instance_valid(n):
		n.visible = false
	direct_hits += 1
	var dir: Vector2 = b["dir"]
	var spray := Vector3(-dir.x, 0.2, -dir.y)
	m.fx.flash(at, HOT, 1.2, 0.1)
	m.fx.burst(at, EMBER, 12, 6.0, 0.35, 2.0, 1.0, spray, 70.0)
	m.sfx("vn_blast", at, -4.0)
	net_ring(at, 1.0, EMBER)
	var o := {"src": "abil", "ab": "utility", "tags": ["utility", "burr"]}
	victim.hurt(float(bd["hit_dmg"]) * power("sec"), h, o)
	daze(victim, float(bd["cone_rattle"]))

## Dazed: the foe takes more from the rifle and Longneedle (rattle_k in the data) and is slowed.
func daze(foe: Ent, seconds: float) -> void:
	KitStatus.apply(foe, "rat", seconds)
	fx().swirl(foe, Color("ff4fb0"), HOT, seconds)

## It meets a wall (or the ground at the lane's end) and sticks: the cone points back the way it came.
func _stick(b: Dictionary, at: Vector3, wall: bool) -> void:
	var bd := rmb_def()["burr"] as Dictionary
	b["pos"] = at
	b["wall"] = wall
	b["fuse"] = float(bd["fuse"])
	b["fuse0"] = float(bd["fuse"])
	b["out"] = -(b["dir"] as Vector2)
	m.sfx("gunslinger_grenade_thunk", at, -3.0)
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
	_cone(at, b["out"] as Vector2, bd, bool(b["wall"]))

## The blast: a cone back out of the stick point, shoving everything in it along the cone (toward the
## thrower) and Dazing it; a hunter shoved into more terrain is stunned.
func _cone(at: Vector3, out: Vector2, bd: Dictionary, wall: bool) -> void:
	last_cone = {"at": at, "dir": out, "wall": wall}
	fx().fan(ground(at), out, float(bd["cone_len"]), float(bd["cone_deg"]), EMBER, HOT, 0.35)
	var spray := Vector3(out.x, 0.2, out.y)
	m.fx.burst(at + Vector3(out.x, 0.4, out.y) * 1.5, EMBER, 18, 8.0, 0.4, 3.0, 1.4, spray, float(bd["cone_deg"]) * 0.5)
	net_ring(at, 1.6, EMBER)
	for f in m.foes_of(h.team):
		if not f.hittable(): continue
		if absf(f.pos.y - at.y) > 2.6: continue
		if not AimMode.in_cone(at, out, float(bd["cone_len"]), float(bd["cone_deg"]), f.pos, 0.3, f.r): continue
		var to := Vector2(f.pos.x - at.x, f.pos.z - at.z)
		var away := (out * 0.6 + to.normalized() * 0.4).normalized() if to.length() > 0.2 else out
		var o := {"src": "abil", "ab": "utility", "tags": ["utility", "burr"], "kb": away * float(bd["push"])}
		o["lift"] = 2.0
		f.hurt(float(bd["cone_dmg"]) * power("sec"), h, o)
		daze(f, float(bd["cone_rattle"]))         # the training dummy too
		if f is Hunter and terrain_behind(f, away, 2.4):
			wall_slams += 1
			var slam := {"src": "abil", "ab": "utility", "tags": ["utility", "burr"], "stun": float(bd["wall_stun"])}
			slam["dr"] = true
			f.hurt(0.1, h, slam)
			daze(f, float(bd["cone_rattle"]) + float(bd["wall_daze"]))     # the data: walled, "Dazed longer"
			m.fx.word(f.pos + Vector3(0, 2.2, 0) + fx().screen_up() * 2.0, "WALLED", EMBER, false)   # over DAZED

# ------------------------------------------------------------------ E: Longneedle
func cast_e() -> bool:
	if not needle.is_empty(): return false
	var ed := e_def()
	needle = {"t": 0.0, "dir": h.aim_dir(), "push": _push_want()}
	e_t = float(ed["charge"]) + 0.1
	m.sfx("vn_ion_charge", h.pos, -3.0)
	play("gunslinger_e")
	return true

## A Boki merge ends the Longneedle's charge with no shot and cuts a Slipstep short (no refund, no speed buff).
func _drop_holds() -> void:
	_end_needle()
	if not slide.is_empty():
		slide = {}
		h.roll_t = 0.0
	rmb_down = false
	rmb_t = 0.0

func _end_needle() -> void:
	if needle.is_empty():
		return
	needle = {}
	e_t = 0.0
	AimKit.hide(h, "e")

## While the Longneedle charges she aims along the capped line, not the cursor (ZERO otherwise: free).
func aim_lock() -> Vector2:
	return needle.get("dir", Vector2.ZERO)

func _tick_needle(dt: float) -> void:
	var ed := e_def()
	needle["t"] = float(needle["t"]) + dt
	if h.downed or h.stun_t > 0.0 or Hex.active(h):
		_end_needle()
		return
	_turn_needle(dt)
	var k := clampf(float(needle["t"]) / float(ed["charge"]), 0.0, 1.0)
	# a bright wide line drawn full length at once, narrowing to a thin core as the cast completes
	var wide := beam_width()
	var lane := {"len": float(ed["range"]), "width": wide, "width_to": wide * 0.12, "k": k, "all": true}
	lane.merge({"col": EMBER, "col2": HOT})
	AimKit.lane(h, "e", lane)
	needle["push"] = lerpf(float(needle["push"]), _push_want(), 1.0 - exp(-PUSH_EASE * dt))
	if h.is_local() and m.cam:
		var push := float(needle["push"])
		m.cam.cast_view(h.aim_dir(), float(ed["view_zoom"]) * push, float(ed["range"]) * push)   # (the caster's camera)
	AimKit.charge(h, k, {"col": EMBER, "col2": HOT})
	# an ember orb swells at the muzzle through the cast
	if int(m.time * 20.0) != int((m.time - dt) * 20.0):
		fx().star(_muzzle(h.aim_dir()), EMBER, HOT, 0.35 + 0.6 * k, 0.07)
	if float(needle["t"]) >= float(ed["charge"]) + 0.03:          # (a beat at full so the full tick plays)
		_fire_needle()                                              # along the capped aim, so before the lock lifts
		_end_needle()

## The locked aim turns toward the cursor at the data's capped rate (deg/s): a flick across the screen can't drag it.
func _turn_needle(dt: float) -> void:
	var want := _cursor()
	if want.length() < 0.05:
		return
	var cur: Vector2 = needle["dir"]
	var step := deg_to_rad(float(e_def()["turn_deg_s"])) * dt
	needle["dir"] = cur.rotated(clampf(cur.angle_to(want), -step, step)).normalized()

## The cursor relative to her on the ground: where she wants to aim, as against the capped aim she holds.
func _cursor() -> Vector2:
	var a: Vector3 = h.inp["aim"]
	return Vector2(a.x - h.pos.x, a.z - h.pos.z)

## How much of the view push-out this aim distance asks for: none inside view_near_m, all of it at full range.
func _push_want() -> float:
	var ed := e_def()
	return smoothstep(float(ed["view_near_m"]), float(ed["range"]), _cursor().length())

## Where the Longneedle leaves the rifle: ahead of her at the barrel's height.
func _muzzle(d: Vector2) -> Vector3:
	return h.pos + Vector3(d.x * 0.9, 1.1, d.y * 0.9)

## The beam's full width in m: what it hits, so the line, the beam and the hit all agree.
func beam_width() -> float:
	return float(e_def()["width"]) * 2.0

func dash_charge() -> float:
	return -1.0

func charge_now() -> Array:
	if not needle.is_empty():
		return ["needle", clampf(float(needle["t"]) / float(e_def()["charge"]), 0.0, 1.0)]
	return super.charge_now()

func _fire_needle() -> void:
	var ed := e_def()
	var d := h.aim_dir()
	var a := _muzzle(d)
	var L := float(ed["range"])
	var b := a + Vector3(d.x, 0, d.y) * L
	needle_dir = d
	# an ember body, a hot core, a bronze shimmer down its edges; the ember muzzle orb and its flare
	fx().beam(a, b, EMBER, HOT, beam_width(), float(ed["linger"]), BRONZE)
	fx().star(a, EMBER, HOT, 1.3, 0.16)
	m.fx.flash(a, EMBER, 1.2, 0.08)
	fx().pillar(ground(h.pos), SMOKE, EMBER, 1.6, 0.45, 0.4)   # recoil smoke puffs up round her (no ground ring)
	net_bolt(a, b, EMBER)
	m.sfx("vn_ion_fire", h.pos, 1.0)
	h.impulse(-d * float(ed.get("recoil", 6.0)))                  # the recoil shoves her back a step
	var hits := 0
	var dmg0: float = float(ed["dmg"]) * power("kin")
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
		m.fx.burst(f.pos + Vector3(0, 1.0, 0), EMBER, 14, 5.0, 0.3)
		if f is Hunter:
			hits += 1
			if rat:
				skewers += 1
				# the word rides up the screen, clear of the damage number on the body
				payoff_fx(f.pos, "", EMBER, "", h.dir_to(f), f)
				m.fx.word(f.pos + Vector3(0, 2.7, 0) + fx().screen_up() * 1.3, "SKEWERED", EMBER, true)
				m.sfx("hero_skewer", f.pos, 0.0)
	if hits > 0:
		var maxcd := float(ed["cooldown"]) * cd_k("kin")
		var cut := float(ed["shave"])
		if rank("kin") >= 3:
			cut = float(ed["shave_rank3"]) * hits       # rank 3: 30% for every hunter hit
		cd["e"] = maxf(0.0, float(cd["e"]) - maxcd * cut)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	var aimp := tgt.pos + Vector3(0, 0.9, 0)
	if not needle.is_empty() or rmb_down:
		h.inp["aim"] = aimp
		return
	if HeroUlt.ready(self) and tgt is Hunter and los and dist > 2.5 and randf() < 0.35:
		h.inp["aim"] = aimp
		if HunterKeys.ult_pressed(h):
			return
	var needle_ok := int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and los and dist > 4.0 and dist < 17.0
	if needle_ok and (KitStatus.rattled(tgt) or randf() < 0.15):
		h.inp["aim"] = aimp
		h.inp["sig"] = true
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 10.0 and dist > 2.0 and randf() < 0.4:
		# throw it past them so the cone comes back over them
		h.inp["aim"] = aimp
		h.inp["sec"] = true
		return
	if h.hp < h.max_hp * 0.4 and h.dashes >= 1.0 and randf() < 0.1:
		h.inp["dash"] = true
		bot_hold["dash"] = 0.5
