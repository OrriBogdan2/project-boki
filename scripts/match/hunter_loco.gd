class_name HunterLoco
extends RefCounted
## A Hunter's locomotion state, owned (briefs/STATE_MACHINES.md M2, docs/decisions/0022): one Fsm (Loco.S) and the
## data of the move it is in. Hunter.gliding, roll_t, knock_t and lfloat are views of this; writing one asks the
## machine for the transition. A move starts on its write (a dash, the glider, a ledge grab); a move whose time ran
## out or that was cancelled leaves at the end of the step (settle), as the timers did.
##
## A knock is drift the hunter carries: a dash or a ledge rise under way keeps going and the knock's state follows
## it; an open glider stays open (a hard knock folds it through the glider's own rules).
##
## The glider (M2a, docs/decisions/0061): GLIDING has one way in, open_glider(), guarded by _glide_ok. What asks:
## a second Space in the air (press_glide), the glide button mid Shift dash (dash_into_glide), the press that armed
## it once the move it waited for ends, a pad's or an updraft's auto_glide, or a scripted open (the drop, the net,
## a check). A held key never opens it: a player's press arms it, the open uses the press up, so a fold (a heal, a
## dash, a knock) stays shut until a new press. glide_tick runs the state each step: the fold when the key is let
## go or the state can't hold it, the heat, the overheat burn and feathering (let_go_t).

var h: Hunter
var fsm := Loco.machine()
var dash_left := 0.0     # s of the dash or kit rush left (DASHING)
var knock_left := 0.0    # s of knockback drift left (KNOCKED, or carried under a dash, glide or ledge rise)
var ledge := {}          # the ledge rise under way (MANTLING): see Hunter._try_ledge_grab
var auto_glide := false  # carried by a lair's escape updraft, a pad's apex or rising air: the glider opens and stays
                         # open by itself until you land (a fresh glide press takes it back)
var armed := false       # a fresh glide press waiting for its open (a move keeps the glider shut; held, it opens after)
var let_go_t := INF      # s since the glider was let go in the air: under Hunter.FEATHER_KEEP its speed and steering
                         # carry (feathering); INF after a knock or a dash folded it, or on the ground
var lift_t := 0.0        # s of the current abyss lift (feathering taps stay in the cheap part of the heat)
var heat_burn := 0.0     # damage an overheated glider has built toward its next tick
var _scripted := false   # a scripted glider (the drop, a check, the net) is not a press: no guard, no open kick
var _glide_held := true  # glide held last step (auto_glide ends on a fresh press, not a held key)
var _btn_held := false   # the glide button held last step (a fresh press opens with no wait)

func _init(hunter: Hunter) -> void:
	h = hunter
	fsm.guard(Loco.S.GLIDING, _glide_ok)
	fsm.on_enter(Loco.S.GLIDING, _glide_opened)
	fsm.on_exit(Loco.S.GLIDING, _glide_folded)
	fsm.on_exit(Loco.S.DASHING, func(_to: int) -> void: dash_left = minf(dash_left, 0.0))     # (an overrun stays)
	fsm.on_exit(Loco.S.MANTLING, func(_to: int) -> void: ledge = {})

## The glider opens in the air, out of a stun, with its cooldown over, not shot down, downed or in the opening
## drop, no dash left to run, and out of a knock carried under a dash or a ledge rise. Each press path adds its
## own rules before asking (Hunter.can_glide, dash_into_glide, glide_tick's hold).
func _glide_ok(from: int) -> bool:
	if _scripted:
		return true
	return h.stun_t <= 0.0 and (knock_left <= 0.0 or (from != Loco.S.DASHING and from != Loco.S.MANTLING)) \
		and not h.grounded and dash_left <= 0.0 and h.glide_cd <= 0.0 and not h.downed and not h.dropping \
		and not h.shot_down

## The open: the press is used up, the step keeps your velocity (Loco.glide_start cuts a rise), the canopy's kick
## and sound, a feather counted below the lip. A scripted open mirrors a glider already open: none of it.
func _glide_opened(_from: int) -> void:
	if _scripted:
		return
	armed = false
	h.grounded = false
	if h.below_lip:
		h.m.sfx("glide", h.pos, -2.0, 1.4)
		h.add_stat("feathers")
	h.glider_sfx("open")
	h.vel.y = Loco.glide_start(h.vel.y)
	h.glide_lift.open_kick(h)

## A dash folds the glider with no feathering after it (and its sound: the fold the glider's own step made).
func _glide_folded(to: int) -> void:
	if to == Loco.S.DASHING:
		let_go_t = INF
		h.glider_sfx("close")

## The one way into GLIDING. `why` is the press that asked ("press", "button", "auto", "held", "pad"): the F7
## readout and --fsm-check read it.
func open_glider(why: String) -> bool:
	return fsm.go(Loco.S.GLIDING, why)

## A second Space press in the air (Hunter.do_jump), unless you're about to land: opens the glider now, out of a
## Shift dash too, or arms it so the held key opens it the step the move it waits for ends. True when the press
## was a glide press (opened or refused), false when it buffers a jump instead.
func press_glide(near_ground: bool) -> bool:
	if fsm.is_in(Loco.S.GLIDING) or near_ground:
		armed = false
		return false
	if dash_into_glide() or h.can_glide():
		open_glider("press")
		return true
	armed = true
	return false

## Item 4: a fresh glide press at any moment of an air Shift dash ends the dash that frame (no minimum time) and
## the glide takes over at the dash's own velocity, no reset, no snap: Loco.glide_step's drag and this hunter's
## glide_carry cap tame it. A kit's rush or special movement (move_kind other than "dash") is not cancelled.
func dash_into_glide() -> bool:
	if dash_left <= 0.0 or h.grounded or h.move_kind != "dash" or h.dropping or h.glide_cd > 0.0 or h.downed \
			or h.shot_down:
		return false
	dash_left = 0.0
	h.shove = {}
	if Vector2(h.vel.x, h.vel.z).length() > Hunter.GLIDE_SPEED * 1.25:
		h.glide_boost_fx()
	return true

## Just after letting go of the glider you keep its speed and steering.
func feathering() -> bool:
	return let_go_t < Hunter.FEATHER_KEEP

## Each step out of the opening drop (Hunter._update_glide): the glider cools on the ground and feathering runs
## out; a fresh press takes an auto-glide back; rising air opens the glider by itself; an open glider burns when
## overheated, heats (faster lifting out of the abyss) and folds when let go or when its state can't hold it; a
## shut one opens on the glide button mid-dash, or on the press that armed it, auto_glide or scripted input
## (held Hunter.GLIDE_ENGAGE) once it may.
func glide_tick(dt: float) -> void:
	if h.grounded:
		h.glide_fuel = minf(1.0, h.glide_fuel + dt / 1.2)
		let_go_t = INF
		h.shot_down = false
	elif not fsm.is_in(Loco.S.GLIDING):
		let_go_t += dt
	# a player takes the glider back with a fresh press of glide; a bot's own glide input (it holds
	# glide over the void to recover) must not fold the glider it's being carried on
	var held: bool = h.inp.get("glide", false)
	var press := held and not _glide_held and h.ctrl != "bot"
	_glide_held = held
	if auto_glide and (press or h.downed or h.out or (h.grounded and h.air_t <= 0.0 and h.vel.y <= 0.0)):
		auto_glide = false
		armed = armed or (press and not h.grounded)
	PadFlight.step(h)             # off a jump pad: the glider opens at the apex
	var shut_in_air := not fsm.is_in(Loco.S.GLIDING) and not auto_glide and not h.grounded and h.can_glide()
	if shut_in_air and not h.m.world.updraft_at(h.pos).is_empty():
		auto_glide = true            # rising air off an edge opens the glider by itself and carries you up (DECISIONS)
	# an overheated glider scorches you while it stays open
	if fsm.is_in(Loco.S.GLIDING) and h.glide_fuel <= 0.001 and not h.downed:
		heat_burn += dt * h.max_hp * 0.035      # an overheated glider burns ~3.5% of your health a second
		if heat_burn >= 20.0:                   # (in ~20-damage ticks, ~2 a second: not a stream of numbers)
			heat_burn -= 20.0
			h.hurt(20.0, null, {"src": "heat"})
	# an overheated glider stays open until you land or get hit again; a knock carries an open one (0055)
	var stays: bool = (ledge.is_empty() or (held and not bool(ledge.get("g0", true)))) and not h.grounded \
		and dash_left <= 0.0 and h.fly_t <= 0.0 and h.glide_cd <= 0.0 and not h.downed and h.stun_t <= 0.0 \
		and (fsm.is_in(Loco.S.GLIDING) or h.m.time - h.kb_t > 0.4) and h.pad.is_empty() and not h.shot_down
	var want := held or auto_glide
	var btn_down: bool = h.inp.get("glide_btn", false)
	armed = (armed or (btn_down and not _btn_held and stays)) and held and not h.grounded
	var was_btn := _btn_held
	_btn_held = btn_down
	var hold_opens: bool = auto_glide or armed or not h.inp.get("glide_press_only", false)
	if fsm.is_in(Loco.S.GLIDING):
		if not want or not stays:
			var let_go := not want and stays
			let_go_t = 0.0 if let_go else INF     # (feathering) a let-go, not a knock
			var to := Loco.S.GROUNDED if h.grounded else Loco.S.AIRBORNE
			fsm.go(to, "let go" if let_go else "folded")
			h.glider_sfx("close")
		elif not h.in_current:
			# heat builds faster while the glider is lifting you out of the abyss
			# [footage] ~1s of lift burns a quarter; (feathering) a short tap's impulse costs less
			var lifting := h.below_lip and h.lip_y - h.pos.y > 0.3 and h.vel.y > 0.0
			lift_t = lift_t + dt if lifting else 0.0
			var hk := 1.0
			if lifting:
				hk = Hunter.FEATHER_TAP_HEAT if lift_t <= Hunter.FEATHER_TAP else 4.0
			if h.hit_heat_t > 0.0:
				hk *= 2.0
			h.glide_fuel = maxf(0.0, h.glide_fuel - dt * hk / (h.glide_max * (1.0 + h.gear_stat("heat"))))
		h.stats["glide_t"] = float(h.stats.get("glide_t", 0.0)) + dt
	elif btn_down and not was_btn and dash_into_glide():
		open_glider("button")
	elif want and stays and hold_opens and fsm.can(Loco.S.GLIDING) and not AirLimits.glide_locked(h) \
			and h.air_t >= (0.0 if btn_down else Hunter.GLIDE_ENGAGE) and h.jump_at != h.m.time:
		# a fresh press in the air armed it and it is still held, or a pad's auto-glide, or scripted input: the
		# glider opens. Space held since the jump never gets here (glide_press_only; the press that jumped is not
		# also a glide press)
		var why := "auto" if auto_glide else "held"
		if armed:
			why = "press"
		open_glider(why)

func set_glide(on: bool) -> void:
	if not on:
		if fsm.is_in(Loco.S.GLIDING):
			fsm.go(Loco.S.GROUNDED if h.grounded else Loco.S.AIRBORNE)
		return
	if fsm.is_in(Loco.S.GLIDING) or dash_left > 0.0:
		return     # a dash under way keeps going: the glider's step folded a scripted open the same frame
	_scripted = true
	if not fsm.go(Loco.S.GLIDING):
		fsm.go(Loco.S.AIRBORNE)       # (from the ground or a knock: a scripted glider is up in the air)
		fsm.go(Loco.S.GLIDING)
	_scripted = false

func set_dash(t: float) -> void:
	if t > 0.0:
		fsm.go(Loco.S.DASHING)     # (every state may dash: a kit's rush or a pull moves a knocked hunter too)
	dash_left = t

func set_ledge(lf: Dictionary) -> void:
	if not lf.is_empty():
		fsm.go(Loco.S.MANTLING)
	ledge = lf

## End of the step: a move that ran out hands over to the knock it carried, a jump pad's mantle, or the ground/air.
func settle(dt: float) -> void:
	var held := fsm.is_in(Loco.S.GLIDING) or (fsm.is_in(Loco.S.DASHING) and dash_left > 0.0) \
		or (fsm.is_in(Loco.S.MANTLING) and not ledge.is_empty())
	if not held:
		if knock_left > 0.0:
			fsm.go(Loco.S.KNOCKED)
		elif not h.pad.is_empty() and h.pad.has("face"):
			fsm.go(Loco.S.MANTLING)
		else:
			fsm.go(Loco.S.GROUNDED if h.grounded else Loco.S.AIRBORNE)
	fsm.tick(dt)
