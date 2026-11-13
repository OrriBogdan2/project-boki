class_name HunterLoco
extends RefCounted
## A Hunter's locomotion state, owned (briefs/STATE_MACHINES.md M2, docs/decisions/0022): one Fsm (Loco.S) and the
## data of the move it is in. Hunter.gliding, roll_t, knock_t and lfloat are views of this; writing one asks the
## machine for the transition. A move starts on its write (a dash, the glider, a ledge grab); a move whose time ran
## out or that was cancelled leaves at the end of the step (settle), as the timers did.
##
## A knock is drift the hunter carries: a dash or a ledge rise under way keeps going and the knock's state follows
## it; an open glider stays open (a hard knock folds it through the glider's own rules).

var h: Hunter
var fsm := Loco.machine()
var dash_left := 0.0     # s of the dash or kit rush left (DASHING)
var knock_left := 0.0    # s of knockback drift left (KNOCKED, or carried under a dash, glide or ledge rise)
var ledge := {}          # the ledge rise under way (MANTLING): see Hunter._try_ledge_grab
var _scripted := false   # a scripted glider (the drop, a check, the net) is not a press: no guard

func _init(hunter: Hunter) -> void:
	h = hunter
	fsm.guard(Loco.S.GLIDING, _glide_ok)
	fsm.on_exit(Loco.S.GLIDING, _glide_folded)
	fsm.on_exit(Loco.S.DASHING, func(_to: int) -> void: dash_left = minf(dash_left, 0.0))     # (an overrun stays)
	fsm.on_exit(Loco.S.MANTLING, func(_to: int) -> void: ledge = {})

## A press opens the glider only out of a stun and out of a knock carried under a dash or a ledge rise.
func _glide_ok(from: int) -> bool:
	if _scripted:
		return true
	return h.stun_t <= 0.0 and (knock_left <= 0.0 or (from != Loco.S.DASHING and from != Loco.S.MANTLING))

## A dash folds the glider: the fold the glider's own step made the same frame (no feathering after it).
func _glide_folded(to: int) -> void:
	if to == Loco.S.DASHING:
		h.glide_off_t = 9.0
		h.glider_sfx("close")

func open_glider() -> bool:
	return fsm.go(Loco.S.GLIDING)

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
