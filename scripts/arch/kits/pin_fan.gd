class_name PinFan
extends Node3D
## The needles Lace holds fanned between the fingers of her draw hand (HeroVfx "nock"): Hemline's wind-up (5,
## gone as the rain fires) and Finishing Touch (3, one leaves per arrow). Each is a small PinNeedle, so they spin out
## of thread as they appear and wind back into it if the move is cancelled; a loosed one goes at once.

const MAX := 5                 # needles (Hemline's)
const SIZE := 0.22             # each needle's length as a share of the Heavy Shot's
const SPREAD := 0.26           # rad between neighbouring needles
const LIFT := 0.5              # rad the fan tips above the aim, like a hand of cards
const FINGER := 0.06           # m between the eyes across the hand
const CHARGE := 0.4            # how warm they glow, 0..1
const THREAD_N := 3            # thread joints on each

var needles: Array[PinNeedle] = []

func _init() -> void:
	for i in MAX:
		var n := PinNeedle.new(THREAD_N, SIZE)
		n.lift = LIFT
		add_child(n)
		needles.append(n)

## Every step: needles 0..n-1 of a fan of `total` held at `nock` along `dir` (her scale `sc`). One that was showing
## and is no longer wanted winds back into thread.
func show_n(n: int, total: int, nock: Vector3, dir: Vector2, sc: float, dt: float) -> void:
	var side := Vector3(-dir.y, 0, dir.x)
	for i in MAX:
		var needle := needles[i]
		if i >= n:
			needle.fade(nock, dt)
			continue
		var o := float(i) - float(total - 1) * 0.5
		needle.hold(nock + side * o * FINGER * sc, dir.rotated(-o * SPREAD), CHARGE, sc, dt)

## Needle `i` is loosed: it's gone.
func shoot(i: int) -> void:
	needles[i].put_away()

func shoot_all() -> void:
	for needle in needles:
		needle.put_away()
