class_name HunterGlide
extends RefCounted
## A Hunter's glider: opening it from a dash or a jump, its sound and boost, and the per-step glide update.


static func can_glide(h: Hunter) -> bool:
	return (
		not h.grounded
		and h.roll_t <= 0.0
		and h.fly_t <= 0.0
		and h.glide_cd <= 0.0
		and not h.downed
		and h.stun_t <= 0.0
		and h.m.time - h.kb_t > 0.4
		and not h.dropping
		and h.charge.is_empty()
		and not KitStatus.grounded(h)
		and not h.shot_down
		and not (h.ak != null and h.ak.no_glide())
		and not AirLimits.glide_locked(h)
	)


## Item 4: a fresh glide press at any moment of an air Shift dash ends the dash that frame (no minimum time) and
## the glide takes over at the dash's own velocity, no reset, no snap: Loco.glide_step's drag and this hunter's
## glide_carry cap tame it. A kit's rush or special movement (move_kind other than "dash") is not cancelled, unless
## the kit lets go of its own flight on the press (ArchKit.glide_cancel: Rock Hop's launch_to). The dash's own
## wind-down (glide_cd a kit set at its start, or left by the dash before in a chain) goes with it.
## A press just after the dash (DashGlide.fresh) counts as one in it, past the kit's wind-down (decision 0061).
static func _dash_into_glide(h: Hunter) -> bool:
	if (
		h.grounded
		or h.dropping
		or h.downed
		or h.shot_down
		or h.stun_t > 0.0
		or (h.ak != null and h.ak.no_glide())
		or not h.loco.can(Loco.S.GLIDING)
	):
		return false
	if h.ak != null and h.ak.glide_cancel():
		return true
	var in_dash := h.roll_t > 0.0 and h.move_kind == "dash"
	var just_after := h.roll_t <= 0.0 and h.dash_glide.fresh(h)
	if not (in_dash or just_after):
		return false
	h.roll_t = 0.0
	h.glide_cd = 0.0
	h.shove = {}
	if Vector2(h.vel.x, h.vel.z).length() > HunterMove.glide_cruise * 1.25:
		_glide_boost_fx(h)
	return true


static func _open_glider(h: Hunter) -> void:
	if not h.moves.open_glider():
		return
	h.add_stat("glide_presses")  # the tutorial's glide step counts only a press
	h.glide_armed = false
	h.grounded = false
	glider_sfx(h, "open")
	h.vel.y = Loco.glide_start(h.vel.y)
	h.glide_lift.open_kick(h)


## Reads as a boost: a loud whoosh, a trail that stays while you're fast (see render), and for you a brief
## camera pull-back.
static func _glide_boost_fx(h: Hunter) -> void:
	h.m.sfx("whoosh", h.pos, -1.0 if h.is_local() else -9.0, 1.2)
	h.m.sfx("glide", h.pos, -6.0 if h.is_local() else -14.0, 1.6)
	h.boost_fx_t = 1.6
	if h.is_local() and h.m.cam:
		h.m.cam.pull_back(0.12)


## The glider's open/close sound for this hunter's glider skin (quieter, and positional, for everyone else).
static func glider_sfx(h: Hunter, which: String) -> void:
	var vol := -3.0 if which == "open" else -8.0
	vol -= 0.0 if h.is_local() else 6.0
	Sfx.play_stream(Gliders.sound(Gliders.skin_of(h), which), h.pos, vol)


## Height pays off: come down hard from 8m+ (not gliding gently, not the opening drop) and the
## landing slams everyone close: damage that grows with the height and a pop into the air.
static func _skyfall(h: Hunter, drop: float, fall_v: float) -> void:
	if drop < Hunter.SKYFALL_H or fall_v > -6.0 or h.dropping or h.downed or h.remote:
		return
	var k := clampf((drop - Hunter.SKYFALL_H) / 16.0, 0.0, 1.0)
	var any := false
	for f in h.m.foes_of(h.team):
		if h.flat_dist(f) < 2.4 + f.r and absf(f.pos.y - h.pos.y) < 2.0:
			any = true
	h.m.fx.dust(h.pos, 10)
	if not any:
		return
	Abil._blast(h, h.pos, 2.4, 10.0 + 16.0 * k, 7.0, Color("ffd27a"), 7.0, "skyfall")
	h.add_stat("skyfalls")


static func _update_glide(h: Hunter, dt: float) -> void:
	h.air_t = 0.0 if h.grounded else h.air_t + dt
	h.glide_lift.tick(h, dt)
	h.glide_dive.tick(h, dt)
	if h.dropping:
		# the opening drop: the glider stays open until you land, or until you sink below the islands
		h.gliding = not h.grounded
		var pull: bool = DropFeel.pulls(h.inp, h.glide_btn_held) and h.ctrl != "bot"
		h.glide_btn_held = h.inp.get("glide_btn", false)
		if h.diving:
			var void_below: bool = h.m.world.is_void(h.pos.x, h.pos.z)
			var above: float = h.pos.y - (World.VOID if void_below else h.m.world.ground_at(h.pos.x, h.pos.z))
			if (not void_below and above < HunterFeel.deploy_h) or (void_below and h.pos.y < 7.0) or pull:
				h._deploy()
		if h.pos.y < -1.5:
			h.dropping = false
			h.diving = false
			h.glide_fuel = 1.0
		return
	if h.grounded:
		h.glide_fuel = minf(1.0, h.glide_fuel + dt / 1.2)
		h.glide_off_t = 9.0
	elif not h.gliding:
		h.glide_off_t += dt
	if h.grounded:
		h.shot_down = false
	# a player takes the glider back with a fresh press of glide; a bot's own glide input (it holds
	# glide over the void to recover) must not fold the glider it's being carried on
	var glide_press: bool = h.inp.get("glide", false) and not h.auto_glide_held and h.ctrl != "bot"
	h.auto_glide_held = h.inp.get("glide", false)
	if h.auto_glide and (glide_press or h.downed or h.out or (h.grounded and h.air_t <= 0.0 and h.vel.y <= 0.0)):
		h.auto_glide = false
		h.glide_armed = h.glide_armed or (glide_press and not h.grounded)
	# an overheated glider scorches you while it stays open
	if h.gliding and not h.dropping and h.glide_fuel <= 0.001 and not h.downed:
		h.heat_burn += dt * h.max_hp * HunterMove.overheat_burn  # a share of your health a second
		if h.heat_burn >= 20.0:  # (in ~20-damage ticks, ~2 a second: not a stream of numbers)
			h.heat_burn -= 20.0
			h.hurt(20.0, null, {"src": "heat"})
	# an overheated glider stays open until you land or get hit again; a knock carries an open one (0055)
	var can: bool = (
		(h.lfloat.is_empty() or (bool(h.inp.get("glide", false)) and not bool(h.lfloat.get("g0", true))))
		and not h.grounded
		and h.roll_t <= 0.0
		and h.fly_t <= 0.0
		and h.glide_cd <= 0.0
		and not h.downed
		and h.stun_t <= 0.0
		and (h.gliding or h.m.time - h.kb_t > 0.4)
		and h.pad.is_empty()
		and not h.shot_down
	)
	var want: bool = h.inp.get("glide", false) or h.auto_glide
	var btn_down: bool = h.inp.get("glide_btn", false)
	# a fresh button press arms through a lock (a wind-down) as a second Space does: held, it opens as the lock ends
	h.glide_armed = (
		(h.glide_armed or (btn_down and not h.glide_btn_held)) and bool(h.inp.get("glide", false)) and not h.grounded
	)
	var was_btn := h.glide_btn_held
	h.glide_btn_held = btn_down
	var hold_opens: bool = h.auto_glide or h.glide_armed or not h.inp.get("glide_press_only", false)
	if h.gliding:
		if not want or not can:
			h.gliding = false
			h.glide_off_t = 0.0 if want == false and can else 9.0  # (feathering) a let-go, not a knock
			glider_sfx(h, "close")
		elif not h.in_current:
			# heat builds faster while the glider is lifting you out of the abyss
			# [footage] ~1s of lift burns a quarter; (feathering) a short tap's impulse costs less
			var lifting := h.below_lip and h.lip_y - h.pos.y > 0.3 and h.vel.y > 0.0
			h.lift_t = h.lift_t + dt if lifting else 0.0
			var lift_k := HunterMove.lift_tap_heat if h.lift_t <= HunterFeel.feather_tap else HunterMove.lift_heat
			var hk := lift_k if lifting else 1.0
			if h.hit_heat_t > 0.0:
				hk *= 2.0
			h.glide_fuel = maxf(0.0, h.glide_fuel - dt * hk / (h.glide_max * (1.0 + h.gear_stat("heat"))))
		if not h.dropping:
			h.stats["glide_t"] = float(h.stats.get("glide_t", 0.0)) + dt
	elif btn_down and not was_btn and _dash_into_glide(h):
		_open_glider(h)
	elif (
		want
		and can
		and hold_opens
		and h.loco.can(Loco.S.GLIDING)
		and h.air_t >= (0.0 if btn_down else HunterFeel.glide_engage)
		and h.jump_at != h.m.time
		and not AirLimits.glide_locked(h)
	):  # (the press that jumped is not also a glide press)
		# a fresh press in the air opened it (glide_armed) and it is still held, or a pad's auto-glide, or scripted
		# input: the glider opens. Space held since the jump never gets here (glide_press_only)
		h.moves.open_glider()
		h.glide_armed = false
		if h.below_lip:
			h.m.sfx("glide", h.pos, -2.0, 1.4)
			h.add_stat("feathers")
		glider_sfx(h, "open")
		h.vel.y = Loco.glide_start(h.vel.y)
		h.glide_lift.open_kick(h)
