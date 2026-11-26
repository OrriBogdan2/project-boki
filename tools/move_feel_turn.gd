extends RefCounted
## --move-feel-check, the run turn (docs/MOVEMENT_FEEL.md "Run turn"): every Hunter at full run on flat ground flips
## the stick 180 degrees, on the real match step. Measured per kit: the time to zero speed, the time back to 95% of
## the run the other way, and the body's 180 when the cursor flips with the stick (the body faces the cursor, never
## the stick: with the cursor held ahead it does not turn and the legs backpedal).
## Asserted per kit against the source's engine rule, worked out from its data (no number of ours): keys held at or
## under the run, UE's walking step turns the velocity toward the keys with GroundFriction (1/s, 1.0) and adds
## MaxAcceleration; the walking brake (BrakingDecelerationWalking 22.2 m/s^2) only acts with no keys or over the run,
## so it plays no part in a held flip. Ours (Loco.accel_to) has no turn friction: it lands within a 60 Hz step.

const DT := 1.0 / 60.0
const TOL_FRAMES := 1  # steps ours may lag the source's rule
const TURN_FRAMES := 9  # steps: RotationRate yaw 1280 deg/s turns 180 in 0.141 s (8.4 steps)

var c  # the move-feel check (its hunter, match and rec/ok)
var p: Hunter


func _init(check) -> void:
	c = check
	p = check.p_v


## UE's CalcVelocity along one axis, keys held the other way at full stick: [steps to zero, steps to 95% back].
static func ue_turn(v_run: float, acc: float, friction: float, dt: float) -> Vector2i:
	var v := v_run
	var zero := -1
	for i in 120:
		if v > 0.0:
			v -= 2.0 * v * minf(dt * friction, 1.0)  # Velocity - (Velocity - AccelDir * |Velocity|) * min(dt F, 1)
		v = maxf(v - acc * dt, -v_run)
		if zero < 0 and v <= 0.0:
			zero = i + 1
		if v <= -0.95 * v_run:
			return Vector2i(zero, i + 1)
	return Vector2i(zero, -1)


func run() -> void:
	var friction := float(HunterMove.rules()["physics"]["ground_friction"])
	var worst := 0
	var slowest := 0.0
	var face_slow := 0.0
	var face0 := p.face
	var base0 := p.base_speed
	var acc0 := p.ground_accel
	for id in Arch.ids():
		var row := {}
		for aim_flip in [false, true]:
			c._reset(c.flat + Vector3(-2.5, 0, 0))
			p.base_speed = HunterMove.speed(id)
			p.ground_accel = HunterMove.accel(id)
			p.inp["aim"] = p.pos + Vector3(40, 0.9, 0)
			p.inp["move"] = Vector2(1, 0)
			c._steps(30)
			var top: float = p.vel.x
			var face_to := atan2(1.0, 0.0)  # facing -x (atan2(-ad.x, -ad.y), ad = (-1, 0))
			p.inp["move"] = Vector2(-1, 0)
			if aim_flip:
				p.inp["aim"] = p.pos + Vector3(-40, 0.9, 0)
			var zero := -1
			var full := -1
			var turned := -1
			for i in 40:
				c.m.step(DT)
				if zero < 0 and p.vel.x <= 0.0:
					zero = i + 1
				if full < 0 and p.vel.x <= -0.95 * top:
					full = i + 1
				if turned < 0 and absf(wrapf(p.face - face_to, -PI, PI)) < deg_to_rad(1.0):
					turned = i + 1
			row[aim_flip] = [top, zero, full, turned]
		var r: Array = row[false]
		var src := ue_turn(float(r[0]), HunterMove.accel(id), friction, DT)
		var err := maxi(absi(int(r[1]) - src.x), absi(int(r[2]) - src.y))
		var flip: Array = row[true]
		err = maxi(err, maxi(absi(int(flip[1]) - int(r[1])), absi(int(flip[2]) - int(r[2]))))
		worst = maxi(worst, err)
		slowest = maxf(slowest, int(r[2]) * DT)
		face_slow = maxf(face_slow, int(flip[3]) * DT)
		c.ok(
			err <= TOL_FRAMES and int(flip[3]) > 0 and int(flip[3]) <= TURN_FRAMES and int(r[3]) < 0,
			(
				(
					"run turn %-10s %.2f m/s: zero %.3f s, 95%% back %.3f s (source %.3f / %.3f s); "
					% [id, r[0], int(r[1]) * DT, int(r[2]) * DT, src.x * DT, src.y * DT]
				)
				+ (
					"cursor flipped: body 180 in %.3f s, speed %.3f / %.3f s; cursor held: no body turn"
					% [int(flip[3]) * DT, int(flip[1]) * DT, int(flip[2]) * DT]
				)
			)
		)
	c.rec("run_turn_err_frames", worst)
	c.rec("run_turn_full_t", slowest)
	c.rec("run_turn_face_t", face_slow)
	p.face = face0
	p.base_speed = base0
	p.ground_accel = acc0
	c._reset(c.flat)
