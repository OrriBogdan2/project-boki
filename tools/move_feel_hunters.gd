extends RefCounted
## --move-feel-check, the movement review per Hunter (sv/MOVEMENT_PARITY.md "Review on main, 2026-11-20"):
## each of the 13 Hunters, its own kit and model swapped in, on the real match step. Measured per kit: the run (top
## speed against its hunter_move.json row, 95% of it), the let-go slide (inside the source's 30-144 fps band for that
## speed) and its stop time, the jump's lift-off (Hunter.JUMP_V, pinned at 6.8 m/s by the owner's ruling), the glide
## cruise and its 90-degree steer, and the dive's peak fall speed. Targets are the check's own rows (T); walking off
## a ledge, the overheated lift and the wall kick and bounce per Hunter are --move-rule-guard-check and
## --wallmove-check.

const DT := 1.0 / 60.0
const JUMP_PINNED := 6.8  # m/s, owner ruling (sv/MOVEMENT_PARITY.md "Lift-off speed"): never the source's 7.5
const SPEED_TOL := 0.01  # m/s: the run and the lift-off land on their rows within this
const SETTLE_STEPS := 30  # after the kit swap: a swap slows the walk (x0.8) for its first 0.25 s, not a run row
const GLIDE_TOL := 0.05  # m/s: the cruise against the glide speed row (MaxGlide 5.0)

var c  # the move-feel check (its hunter, match and rec/ok)
var hunter: Hunter


func _init(check) -> void:
	c = check
	hunter = check.P


func run() -> void:
	var cls_was := hunter.cls
	var arch_was := hunter.arch
	var wid_was := hunter.wid
	for id in Arch.ids():
		hunter.reclass(Arch.weight(id), id)
		c._reset(c.flat)
		c._steps(SETTLE_STEPS)
		var walk := _run_and_stop()
		var jump := _lift_off()
		var glide := _glide_steer()
		var dive := _dive_peak()
		var band: Vector2 = c.ue_band(walk[0])
		c.ok(
			absf(walk[0] - HunterMove.speed(id)) <= SPEED_TOL and _in(walk[1], "ground_t95"),
			"hunter %-10s run %.3f m/s (row %.2f), 95%% in %.3f s" % [id, walk[0], HunterMove.speed(id), walk[1]]
		)
		c.ok(
			walk[2] >= band.x and walk[2] <= band.y and _in(walk[3], "ground_stop_t"),
			"hunter %-10s let go: slide %.3f m (source %.3f-%.3f), stop %.3f s" % [id, walk[2], band.x, band.y, walk[3]]
		)
		c.ok(
			absf(jump - JUMP_PINNED) <= SPEED_TOL and is_equal_approx(Hunter.JUMP_V, JUMP_PINNED),
			"hunter %-10s jump lift-off %.3f m/s (pinned %.1f)" % [id, jump, JUMP_PINNED]
		)
		c.ok(
			absf(glide[0] - 5.0) <= GLIDE_TOL and _in(glide[1], "glide_turn90_t"),
			"hunter %-10s glide cruise %.3f m/s, 90-degree steer %.3f s" % [id, glide[0], glide[1]]
		)
		c.ok(_in(dive, "dive_vy"), "hunter %-10s dive peak %.3f m/s (row %.1f)" % [id, dive, HunterMove.dive_vy])
	hunter.reclass(cls_was, arch_was, wid_was)
	c._reset(c.flat)


## Whether v sits in the check's "~" target `key`, or under its "<=" one.
func _in(v: float, key: String) -> bool:
	var t: Array = c.T[key]
	if String(t[0]) == "<=":
		return v > 0.0 and v <= float(t[1]) + 1e-6
	var r: Array = t[1]
	return v >= float(r[0]) - 1e-6 and v <= float(r[1]) + 1e-6


## [top speed, s to 95% of it, slide after letting go (m), s to a stop].
func _run_and_stop() -> Array:
	c._reset(c.flat + Vector3(-2.5, 0, 0))
	hunter.inp["move"] = Vector2(1, 0)
	var t95 := -1.0
	for i in 40:
		c.m.step(DT)
		if t95 < 0.0 and c._hv(hunter).length() >= 0.95 * hunter.base_speed:
			t95 = (i + 1) * DT
	var top: float = c._hv(hunter).length()
	var x0 := hunter.pos.x
	hunter.inp["move"] = Vector2.ZERO
	var ts := -1.0
	for i in 30:
		c.m.step(DT)
		if ts < 0.0 and c._hv(hunter).length() < 0.05:
			ts = (i + 1) * DT
	return [top, t95, hunter.pos.x - x0, ts]


## The lift-off speed of a Space press on flat ground (m/s): the first rising step's speed plus the one step of
## gravity it has already had.
func _lift_off() -> float:
	c._reset(c.flat)
	hunter.inp["jump"] = true
	for i in 10:
		c.m.step(DT)
		if hunter.vel.y > 0.0:
			return hunter.vel.y + Hunter.H_GRAV * DT
	return 0.0


## [cruise speed after 2.5 s of glide held forward (m/s), s to steer 90 degrees at 80% of it].
func _glide_steer() -> Array:
	c._glide_at(25.0)
	hunter.inp["jump"] = true
	for i in 150:
		hunter.inp["glide"] = true
		hunter.inp["move"] = Vector2(1, 0)
		c.m.step(DT)
	var cruise: float = c._hv(hunter).length()
	for i in 60:
		hunter.inp["glide"] = true
		hunter.inp["move"] = Vector2(0, 1)
		c.m.step(DT)
		var hv: Vector2 = c._hv(hunter)
		if absf(hv.angle_to(Vector2(0, 1))) < deg_to_rad(10.0) and hv.length() > cruise * 0.8:
			return [cruise, (i + 1) * DT]
	return [cruise, -1.0]


## The peak fall speed of a glide dive (crouch held from 0.5 s) from 60 m up (m/s).
func _dive_peak() -> float:
	c._reset(c.flat + Vector3(0, 60.0, 0), false)
	hunter.inp["jump"] = true
	var peak := 0.0
	for i in 300:
		hunter.inp["glide"] = true
		hunter.inp["crouch"] = i >= 30
		c.m.step(DT)
		if hunter.glide_dive.on:
			peak = maxf(peak, -hunter.vel.y)
		if hunter.grounded:
			break
	hunter.inp["crouch"] = false
	return peak
