extends RefCounted
## --traversal-parity-check: the traversal rules that come from the reference's data hold their numbers
## (content/rules/hunter_move.json physics, tuning.json air), run through the same functions the match and
## the farm call: the coyote window; the landing buffer (a jump pressed falling near the ground is kept to
## the landing, never lost and never a glider); no glider rising under 0.5 m; the glider's catch on opening,
## its sink and cruise; the air's let-go drag; the dash-jump trim (JumpTrim) and the ground refill.
## No match is started.
## Prints "TRAVPAR ok|FAIL <what>" and "TRAVERSAL PARITY CHECK DONE, failures: N".

const DT := 1.0 / 60.0
const BODY := 1.16  # hunter_move.json body_scale: speeds are the reference's at our body height

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("TRAVPAR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func run(main: Node) -> void:
	_rows()
	_landing_buffer()
	_glide_open()
	_air_let_go()
	_dash_jump_trim()
	print("TRAVERSAL PARITY CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## The plain numbers: m and s, the reference's uu / 100.
func _rows() -> void:
	ok(near(HunterMove.coyote_s, 0.25, 1e-6), "coyote window 0.25 s (%.3f)" % HunterMove.coyote_s)
	ok(near(HunterMove.glide_sink, 1.25, 1e-6), "glide sink 1.25 m/s (%.3f)" % HunterMove.glide_sink)
	var cruise := HunterMove.glide_cruise
	ok(near(cruise, 7.0 * BODY, 1e-4), "glide cruise 7.0 m/s at body scale (%.2f)" % cruise)
	var start := HunterMove.glide_start_vy
	ok(near(start, 0.85, 1e-6), "glider open caps a fall at 0.85 m/s (%.3f)" % start)
	ok(near(HunterMove.glide_regen_s, 2.0, 1e-6), "empty glider refills in 2.0 s on the ground")
	ok(near(HunterMove.sneak_speed, 0.4, 1e-6), "crouch walk 0.4 of run speed")
	ok(near(Hunter.H_GRAV, 14.7, 1e-6), "gravity 14.7 m/s^2")


## Falling within land_buffer_h (1.5 m) a press is a jump kept to the landing; higher, or rising, it is not.
func _landing_buffer() -> void:
	ok(near(HunterMove.land_buffer_h, 1.5, 1e-6), "landing buffer height 1.5 m")
	ok(HunterMove.near_landing(-0.5, 1.45), "falling 1.45 m up: about to land")
	ok(HunterMove.near_landing(-12.0, 1.45), "falling fast 1.45 m up: about to land")
	ok(not HunterMove.near_landing(-0.5, 1.6), "falling 1.6 m up: free to glide")
	ok(not HunterMove.near_landing(3.0, 0.4), "rising: never 'about to land'")
	for vy in [-0.01, -2.0, -6.0, -12.0]:
		var y := 1.49
		var v: float = vy
		var t := 0.0
		while y > 0.0:
			var nv := v - Hunter.H_GRAV * DT
			y += 0.5 * (v + nv) * DT
			v = nv
			t += DT
		var hold := HunterMove.jump_hold(vy, 1.49)
		ok(hold >= t, "a press 1.49 m up at %.2f m/s is kept %.3f s, the landing comes at %.3f s" % [vy, hold, t])
	ok(
		near(HunterMove.jump_hold(-0.5, 4.0), HunterMove.jump_buffer_s, 1e-6),
		"higher up the press keeps the usual buffer"
	)


## The step the glider opens: a fall is caught at 0.85 m/s at once, a rise kept only near the ground.
func _glide_open() -> void:
	ok(near(Loco.glide_start(-12.0, 10.0), -0.85, 1e-6), "opened falling 12 m/s: 0.85 m/s down at once")
	ok(near(Loco.glide_start(-0.4, 10.0), -0.4, 1e-6), "opened falling slower than the cap: kept")
	ok(near(Loco.glide_start(6.0, 1.0), 2.5, 1e-6), "opened rising 1 m up: keeps 2.5 m/s of rise")
	ok(near(Loco.glide_start(6.0, 3.825), 1.25, 1e-3), "opened rising halfway (3.8 m): half of it")
	ok(near(Loco.glide_start(6.0, 10.0), 0.0, 1e-6), "opened rising 10 m up: the rise stops")
	ok(near(Loco.glide_start(-5.0, INF), -0.85, 1e-6), "over the void: caught the same")


## A jump with no keys loses 0.75 of its speed a second (falling friction 0.375 x braking factor 2).
func _air_let_go() -> void:
	ok(near(Loco.air_idle_drag, 0.75, 1e-6), "air let-go drag 0.75 /s")
	var hv := Vector2(4.0, 0.0)
	for i in 60:
		hv = Loco.air_step(hv, Vector2.ZERO, 5.3, DT)
	ok(near(hv.length(), 4.0 * exp(-0.75), 0.01), "1 s with no keys: 4.0 -> %.2f m/s" % hv.length())


## A dash-jump's speed over the trim's first end settles to its target within ~0.3 s; a run jump is never
## trimmed; landing ends the trim.
func _dash_jump_trim() -> void:
	var lo := HunterMove.jump_trim_in
	var to := HunterMove.jump_trim_to
	ok(near(lo.x, 8.0 * BODY, 1e-4) and near(lo.y, 16.0 * BODY, 1e-4), "trim from 8 m/s, full at 16 (x body)")
	ok(near(to.x, 5.0 * BODY, 1e-4) and near(to.y, 7.0 * BODY, 1e-4), "trim to 5..7 m/s (x body)")
	var tr := JumpTrim.new()
	tr.start(Vector2(HunterMove.speed("default"), 0.0))
	ok(tr.target < 0.0, "a run jump is not trimmed")
	tr.start(Vector2(30.0, 0.0))
	ok(near(tr.target, to.y, 1e-4), "a very fast jump settles at the high end (%.2f)" % tr.target)
	var v0 := Hunter.DASH_SPEED * Loco.dash_jump_keep
	var air_s := 2.0 * Hunter.JUMP_V / Hunter.H_GRAV
	var cap := HunterMove.speed("default")
	var trimmed := _hop(v0, cap, air_s, true)
	var free := _hop(v0, cap, air_s, false)
	tr.start(Vector2(v0, 0.0))
	var want := tr.target
	ok(want > to.x and want < to.y, "a dash-jump at %.1f m/s settles at %.2f m/s" % [v0, want])
	ok(
		trimmed.y >= to.x and trimmed.y <= want + 0.2,
		"0.3 s in it goes %.2f m/s (untrimmed %.2f)" % [trimmed.y, free.y]
	)
	ok(trimmed.x < free.x - 1.0, "the hop covers %.2f m, not %.2f m" % [trimmed.x, free.x])
	tr.start(Vector2(v0, 0.0))
	tr.step(Vector2(v0, 0.0), false, DT)
	ok(tr.target < 0.0, "landing ends the trim")


## A jump leaving at v0 m/s, keys held along it, for `air_s` seconds: x = metres covered, y = speed 0.3 s in.
func _hop(v0: float, cap: float, air_s: float, trim: bool) -> Vector2:
	var tr := JumpTrim.new()
	var hv := Vector2(v0, 0.0)
	if trim:
		tr.start(hv)
	var dist := 0.0
	var at := 0.0
	var t := 0.0
	while t < air_s:
		hv = tr.step(Loco.air_step(hv, Vector2.RIGHT, cap, DT), true, DT)
		dist += hv.length() * DT
		t += DT
		if at == 0.0 and t >= 0.3 - 1e-6:
			at = hv.length()
	return Vector2(dist, at)
