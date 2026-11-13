extends RefCounted
## --move-feel-check, the 8-direction rows: W A S D and the four diagonals through the real keyboard
## path (Match._gather_input, the camera's yaw, Hunter's walk, glide and dash), on the match camera.
## Asserts what the source does: W runs straight up the screen, every key direction lands on screen
## within 1 degree of its ideal, and a diagonal is no faster than a cardinal (speeds within 1%).
## The garden shares this pipeline (home.gd _move_player, the same CamRig at yaw 0), so it needs no row.

const DT := 1.0 / 60.0
const ANGLE_TOL_DEG := 1.0      # degrees: measured on-screen (or world) heading vs its ideal
const SPEED_TOL := 0.01         # share: fastest vs slowest of the 8 directions
## key name -> [actions held, ideal world direction (x east, z south; W = north = screen up)]
const DIRS := {
	"W": [["up"], Vector2(0, -1)],
	"S": [["down"], Vector2(0, 1)],
	"A": [["left"], Vector2(-1, 0)],
	"D": [["right"], Vector2(1, 0)],
	"WD": [["up", "right"], Vector2(1, -1)],
	"WA": [["up", "left"], Vector2(-1, -1)],
	"SD": [["down", "right"], Vector2(1, 1)],
	"SA": [["down", "left"], Vector2(-1, 1)],
}

var bad := 0
var m: Match
var P: Hunter
var cam: CamRig
var flat: Vector3
var reset: Callable          # the check's _reset(pos, grounded)

func _init(match_: Match, flat_: Vector3, reset_: Callable) -> void:
	m = match_
	P = m.player
	cam = m.cam
	flat = flat_
	reset = reset_

## Runs the three modes and returns the failure count.
func run() -> int:
	if cam == null:
		print("MFEEL (no camera, 8-direction rows skipped)")
		return 0
	var lead0: float = cam.lead
	cam.lead = 0.0            # the cursor pan off: the hunter sits on the screen's vertical centre line
	m.paused = false
	_mode("ground", 45, false)
	_mode("glide", 150, true)
	_dash()
	cam.lead = lead0
	Input.action_release("glide")
	return bad

## One mode, every direction: holds the keys `frames` steps through Match._process, then reads the
## heading (on screen and in the world) and the ground speed.
func _mode(mode: String, frames: int, glide: bool) -> void:
	var worst_screen := 0.0
	var worst_world := 0.0
	var lo := 1e9
	var hi := 0.0
	for key in DIRS:
		var ideal: Vector2 = (DIRS[key][1] as Vector2).normalized()
		_start(glide)
		for a in DIRS[key][0]:
			Input.action_press(a)
		if glide:
			Input.action_press("glide")
		for i in frames:
			m._process(DT)
		var hv := Vector2(P.vel.x, P.vel.z)
		var got := _screen_deg(hv)
		var want := _screen_deg(ideal)
		var e_screen := absf(rad_to_deg(angle_difference(deg_to_rad(got), deg_to_rad(want))))
		var e_world := absf(rad_to_deg(hv.angle_to(ideal)))
		var state := "  gliding" if P.gliding else ""
		print("MFEEL dir %-6s %-2s screen %6.1f deg (ideal %6.1f) world off %4.2f deg  speed %5.3f m/s%s" % [
			mode, key, got, want, e_world, hv.length(), state])
		worst_screen = maxf(worst_screen, e_screen)
		worst_world = maxf(worst_world, e_world)
		lo = minf(lo, hv.length())
		hi = maxf(hi, hv.length())
		for a in DIRS[key][0]:
			Input.action_release(a)
		Input.action_release("glide")
		for i in 3:
			m._process(DT)
	_row("dir_%s_screen_err_deg" % mode, worst_screen, "deg", ANGLE_TOL_DEG,
		"[footage] W runs straight up the screen; each key direction lands on its line")
	_row("dir_%s_world_err_deg" % mode, worst_world, "deg", ANGLE_TOL_DEG,
		"keys -> world: no skew from the camera yaw or the axes")
	_row("dir_%s_speed_spread" % mode, (hi - lo) / maxf(lo, 0.001), "x", SPEED_TOL,
		"[game data] input normalised: a diagonal is no faster than a cardinal")

## The class dash: the burst goes where the keys point, at one speed, for all 8 directions.
func _dash() -> void:
	var worst := 0.0
	var lo := 1e9
	var hi := 0.0
	var kit_was := P.arch
	P.set_arch("")      # the class dash: core physics (a kit's own dash shape is its combo check's job)
	for key in DIRS:
		var ideal: Vector2 = (DIRS[key][1] as Vector2).normalized()
		_start(false)
		for a in DIRS[key][0]:
			Input.action_press(a)
		for i in 3:
			m._process(DT)
		# the press goes in as one sim step: a key's "just pressed" never clears while the check drives
		# frames by hand inside one engine frame, so a real Shift would stay pressed into every later run
		P.inp["dash"] = true
		m.step(DT)
		var d := Vector2.ZERO
		var spd := 0.0
		for i in 12:
			m._process(DT)
			if d == Vector2.ZERO and P.roll_t > 0.0:
				d = P.roll_dir
				spd = P.roll_speed
		var e := absf(rad_to_deg(d.angle_to(ideal))) if d != Vector2.ZERO else 180.0
		print("MFEEL dir dash   %-2s world off %4.2f deg  speed %5.3f m/s" % [key, e, spd])
		worst = maxf(worst, e)
		lo = minf(lo, spd)
		hi = maxf(hi, spd)
		for a in DIRS[key][0]:
			Input.action_release(a)
		for i in 40:
			m._process(DT)      # the dash runs out and the brake stops you before the next
	P.set_arch(kit_was)
	_row("dir_dash_world_err_deg", worst, "deg", ANGLE_TOL_DEG, "a dash goes where the keys point, diagonals too")
	_row("dir_dash_speed_spread", (hi - lo) / maxf(lo, 0.001), "x", SPEED_TOL, "one dash speed for all 8 directions")

func _start(glide: bool) -> void:
	var up := HunterMove.glide_height - 0.3 if glide else 0.0
	reset.call(flat + Vector3(0, up, 0), not glide)
	m.acc = 0.0
	cam.yaw = 0.0
	cam.yaw_to = 0.0
	cam.snap(P.pos)
	for i in 3:
		m._process(DT)

## Screen heading in degrees (0 = right, 90 = up) of a world ground direction from where the hunter stands.
func _screen_deg(dir: Vector2) -> float:
	if dir.length() < 0.001:
		return 0.0
	var d := dir.normalized()
	var a := cam.unproject_position(P.pos)
	var b := cam.unproject_position(P.pos + Vector3(d.x, 0, d.y))
	return rad_to_deg(atan2(-(b.y - a.y), b.x - a.x))

func _row(key: String, v: float, unit: String, cap: float, note: String) -> void:
	var pass_ := v <= cap + 1e-6
	var verdict := "ok" if pass_ else "FAIL"
	print("MFEEL %-26s = %7.3f %-6s target %-14s %s   (%s)" % [key, v, unit, "<= %s" % str(cap), verdict, note])
	if not pass_:
		bad += 1
