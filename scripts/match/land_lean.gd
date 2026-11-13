class_name LandLean
extends RefCounted
## A landing squash and a lean into starting and stopping, read off where a body has been (Boki: BokiRig and
## KinPuppet, which have no grounded state or velocity of their own). Visual only: the caller lays `squash` and
## `lean` on a model node; nothing that moves or hits reads them. The Hunters' come from HunterAnim (land_k, acc_f).

const FALL_MIN := 2.5       # m/s: a fall slower than this lands without a squash (a gait's bob, a kerb)
const FALL_FULL := 9.0      # m/s: a fall this fast lands with the whole squash
const SQUASH_RATE := 4.0    # 1/s: how fast a landing's squash springs back out
const LEAN_PER_ACC := 0.012 # rad per m/s² of change in ground speed
const LEAN_MAX := 0.18      # rad: the most it tips forward (speeding up) or back (stopping)
const LEAN_RATE := 10.0     # 1/s: how fast the lean follows
const SPEED_EASE := 12.0    # 1/s: the ground speed is smoothed this much before its change is read
const JUMP := 5.0           # m: moved further than this in one frame is a teleport, not motion

var squash := 0.0           # 0..1, the landing's squash
var lean := 0.0             # rad, + forward
var _prev := Vector3.INF
var _vy := 0.0
var _speed := 0.0

func step(dt: float, at: Vector3) -> void:
	if dt <= 0.0:
		return
	squash = maxf(0.0, squash - dt * SQUASH_RATE)
	if _prev == Vector3.INF or at.distance_to(_prev) > JUMP:
		_prev = at
		return
	var v := (at - _prev) / dt
	_prev = at
	if _vy < -FALL_MIN and v.y > -0.5:
		squash = maxf(squash, clampf(-_vy / FALL_FULL, 0.3, 1.0))
	_vy = v.y
	var was := _speed
	_speed = lerpf(_speed, Vector2(v.x, v.z).length(), 1.0 - exp(-SPEED_EASE * dt))
	var goal := clampf((_speed - was) / dt * LEAN_PER_ACC, -LEAN_MAX, LEAN_MAX) if absf(v.y) < 1.5 else 0.0
	lean = lerpf(lean, goal, 1.0 - exp(-LEAN_RATE * dt))
