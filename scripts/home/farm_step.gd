class_name FarmStep
extends RefCounted
## The farm avatar's clock (docs/decisions/0048): it moves in the match's fixed steps (Match.DT) whatever the
## display's frame rate, so a jump, a dash and a stop measure the same at 30, 60 and 144 fps and the same as in
## a match. Key presses are latched for exactly one step, the body is shown between its last two steps, and the
## pose plays once a frame at the frame's own pace, and the facing is blended between steps the same way (a
## step calls face()). Town and interior walk with walk(). It also holds the jump's two grace timers, the match's
## numbers (content/rules/hunter_move.json: coyote_s, jump_buffer_s).

enum Jump { NONE, JUMP, GLIDE }

const PRESSES: Array[StringName] = [&"jump", &"dash", &"glide", &"crouch"]
const SNAP_M := 2.0      # m in one step: a teleport or a respawn, shown at once instead of blended

var acc := 0.0           # s of frame time not stepped yet
var coyote := 0.0        # s left in which a jump still counts as off the ground it just walked off
var jump_buf := 0.0      # s left in which a jump pressed just before a landing still jumps
## How far the shown body trails the stepped one (m), for whatever frames the avatar (the camera).
var lag := Vector3.ZERO
## The drawn facing (rad): the stepped facing blended between the last two steps.
var yaw := 0.0
var _latched := {}       # press edges waiting for their step
var _stepping := false
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _shown := Vector3.ZERO
var _basis_to := Basis.IDENTITY      # the body's orientation after the last step
var _basis_shown := Basis.IDENTITY
var _yaw := 0.0                  # the facing after the last step
var _yaw_from := 0.0
var _yaw_to := 0.0
var _yaw_set := false
var _anim: HunterAnim = null
var _pose := {}

## One frame: runs `step` once per Match.DT of `delta` (the caller caps delta, so a hitch never spirals), then
## shows `body` between its last two steps and plays the pose.
func run(delta: float, body: Node3D, step: Callable) -> void:
	for a in PRESSES:
		if Input.is_action_just_pressed(a):
			_latched[a] = true
	if body.position != _shown or body.basis != _basis_shown:      # moved by something else: no blend
		_from = body.position
		_to = body.position
		_basis_to = body.basis
		_yaw_from = _yaw
		_yaw_to = _yaw
		_yaw_set = false      # the next step's facing starts from itself
	body.position = _to
	body.basis = _basis_to
	acc += delta
	_stepping = true
	while acc >= Match.DT:
		acc -= Match.DT
		_anim = null
		step.call(Match.DT)
		_latched.clear()
		_from = _to
		_to = body.position
		_basis_to = body.basis
		_yaw_from = _yaw_to
		_yaw_to = _yaw
		if _from.distance_to(_to) > SNAP_M:
			_from = _to
	_stepping = false
	_shown = _from.lerp(_to, acc / Match.DT)
	lag = _shown - _to
	body.position = _shown
	yaw = lerp_angle(_yaw_from, _yaw_to, acc / Match.DT)
	body.basis = _basis_to * Basis(Vector3.UP, angle_difference(_yaw_to, yaw))
	_basis_shown = body.basis
	if _anim:
		_play(delta)

## The avatar's facing after this step (rad), for run() to blend between steps.
func face(stepped: float) -> void:
	_yaw = stepped
	if not _yaw_set:      # the first step: nothing to blend from
		_yaw_set = true
		_yaw_to = stepped

## Ground speed after a step: the match's run speed, acceleration and walking brake at this hero's row.
func walk(hv: Vector2, keys: Vector2, d: float) -> Vector2:
	var row := HunterMove.of(String(Save.d.get("arch", "")))
	if keys.length() < 0.001:
		return HunterMove.brake(hv, 1.0, d)
	var wish: Vector2 = keys * float(row["speed"])
	return Loco.accel_to(hv, wish, float(row["accel"]), 0.0, HunterMove.brake_rate(hv.length()), d)

## Whether `action` was pressed for this step. A press reaches exactly one step: not lost on a frame with no
## step (144 fps), not seen twice on a frame with two (30 fps).
func pressed(action: StringName) -> bool:
	return _latched.has(action) if _stepping else Input.is_action_just_pressed(action)

## What a jump press does this step, as in a match (Hunter.do_jump): a jump off the ground or within coyote_s
## of walking off it; in the air a glider, unless a landing is close, when the press waits for it
## (jump_buffer_s). `height` is how far above the ground the avatar is (INF over the void).
func jump(press: bool, air: bool, vy: float, height: float, d: float) -> Jump:
	if not air:
		coyote = HunterMove.coyote_s + d      # the first step in the air leaves the whole window, as in a match
	else:
		coyote = maxf(0.0, coyote - d) if vy <= 0.0 else 0.0
	jump_buf = maxf(0.0, jump_buf - d)
	if (press or jump_buf > 0.0) and (not air or coyote > 0.0):
		coyote = 0.0
		jump_buf = 0.0
		return Jump.JUMP
	if not press:
		return Jump.NONE
	if HunterMove.near_landing(vy, height):
		jump_buf = HunterMove.jump_buffer_s + d      # it fires the step after the landing: the match's window
		return Jump.NONE
	return Jump.GLIDE

## The avatar's pose after a step. Under run() it plays once a frame, so the animation is as smooth as the
## display; a step called on its own (a check) plays it at once.
func pose(anim: HunterAnim, state: Dictionary, d: float) -> void:
	_anim = anim
	_pose = state
	if not _stepping:
		_play(d)

func _play(d: float) -> void:
	_anim.update(d, _pose)
	if _anim.stepped:
		Sfx.step(null, -20.0)
