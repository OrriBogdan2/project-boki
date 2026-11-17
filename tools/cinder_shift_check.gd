extends "res://tools/move_feel_check.gd"
## --cinder-shift-check: one Cinder Shift (Soot Ram on the ground, the poof in the air), measured in the real
## match step with the keys held the way a player holds them (W held through the dash). Prints, per dash:
## the dash's own metres and seconds, its peak speed, and the whole move (press to back at run speed, run
## pace subtracted), against the target in docs/heroes/ashwick.md (owner playtest 11-17). Ends with
## "CINDER SHIFT CHECK DONE, failures: N".

const TOL := 0.05         # owner 11-17: within 5% of the target distance

func run(main: Node) -> void:
	_begin(main)
	P.reclass(Arch.weight("ashwick"), "ashwick")
	var dd: Dictionary = P.ak.dash_def()
	_one("ground", false, float(dd["dist"]), float(dd["time"]))
	_one("air", true, float(dd["air_dist"]), float(dd["air_time"]))
	print("CINDER SHIFT CHECK DONE, failures: %d" % bad)

## One Shift from a run (W held all the way). dash = the metres in the dash's own time; peak = top speed;
## whole = the extra metres the Shift gave over just running on for the same time (press to run speed).
func _one(tag: String, air: bool, want_m: float, want_s: float) -> void:
	_steps(30)
	_reset(flat + Vector3(-4.0, 6.0 if air else 0.0, 0), not air)
	P.inp["move"] = Vector2(1, 0)
	_steps(1 if air else 20)          # up to run speed (the air one straight from the hover)
	var run := _hv(P).length()
	var p0 := Vector2(P.pos.x, P.pos.z)
	P.inp["dash"] = true
	var dash_m := 0.0
	var dash_t := 0.0
	var peak := 0.0
	var n := 0
	var back := false
	var done_t := 0.0
	for i in 180:
		var before := Vector2(P.pos.x, P.pos.z)
		var left := minf(P.roll_t, DT)
		m.step(DT)
		P.inp["dash"] = false
		var v := _hv(P).length()
		peak = maxf(peak, v)
		var step := Vector2(P.pos.x, P.pos.z).distance_to(before)
		if P.roll_t > 0.0 or (n == 0 and i == 0):
			dash_m += step; dash_t += DT; n += 1
		elif n > 0 and not back and left > 0.0:
			dash_m += step * (left / DT); dash_t += left
			back = true
		if back and v <= run * 1.02 + 0.05:
			done_t = float(i + 1) * DT
			break
	var whole := Vector2(P.pos.x, P.pos.z).distance_to(p0) - run * done_t
	var hit := absf(dash_m / want_m - 1.0) <= TOL
	ok(hit, "Cinder Shift %-6s %.2f m in %.3f s (peak %.1f m/s, mean %.1f m/s), whole move +%.2f m over a %.2f m/s run; want %.2f m in %.2f s"
			% [tag, dash_m, dash_t, peak, dash_m / maxf(dash_t, 0.001), whole, run, want_m, want_s])
