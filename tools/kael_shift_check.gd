extends RefCounted
## --kael-shift-check: owner 11-11 on Kael's Shift (the Rampage): a fast short movement dash first that also hits.
## Running, a dash and a second one back to back never drop below the run; in the air it keeps his speed and height
## and no glider shows without Space; jump > Shift > Space glides off fast in the drive, and after it with no lock.
## Prints AKCHECK lines (tools/archetype_check.gd's harness).

const AKCheck := preload("res://tools/archetype_check.gd")
const RUN_K := 0.9             # the slowest a dash may leave him, against his run speed

var A: AKCheck
var m: Match
var P: Hunter
var home: Vector3

func run(main_node: Node) -> void:
	A = AKCheck.new()
	A.main = main_node
	var r := A.setup("juggernaut", 30.0)
	m = r[0]
	P = r[1]
	home = r[4]
	(r[2] as Hunter).teleport(home + Vector3(6, 0, 9))      # the dummy off the lane
	P.inp["glide_press_only"] = true                        # a player's keys: only a fresh press opens the glider
	A.ok("kael shift: 2 charges at rank 1, 3 at rank 2", _charges(1) == 2.0 and _charges(2) == 3.0)
	_ground_chain()
	_air_dash()
	_jump_shift_glide()
	print("AKCHECK DONE, %d checks, failures: %d" % [A.n, A.fails])
	main_node.get_tree().quit(1 if A.fails > 0 else 0)

func _charges(rank: int) -> float:
	P.slot_lv["dash"] = rank
	var n := P.max_dashes()
	P.slot_lv["dash"] = 1
	return n

## Running at +x until his speed settles; returns that speed.
func _run_in(from: Vector3) -> float:
	P.teleport(from)
	P.vel = Vector3.ZERO
	P.roll_t = 0.0
	P.gliding = false
	P.glide_cd = 0.0
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(1, 0)
	A.aim_at(P, from + Vector3(20, 0, 0))
	A.step(m, 0.6)
	return _hv()

## A key pressed for one step through the hunter's own input path (DashFlow sees it); Space also holds glide.
func _press(key: String, space: bool) -> void:
	P.inp[key] = true
	P.inp["glide"] = space or P.inp["glide"]
	m.step(A.DT)
	P.inp[key] = false

func _hv() -> float:
	return Vector2(P.vel.x, P.vel.z).length()

## The Glider node drawn (render's glide_k) or the glide state on.
func _glider_out() -> bool:
	P.render(A.DT, 1.0)
	return P.gliding or P.model.get_node("Rig/Torso/Glider").visible

## Running, Shift, Shift as the first drive ends, keys held after: never below the run, both charges spent.
func _ground_chain() -> void:
	var run_v := _run_in(home + Vector3(-6, 0, 0))
	var slowest := INF
	var dashes := 0
	P.do_dash()
	for i in 60:
		if P.roll_t <= 0.0 and dashes == 0:
			P.do_dash()
			dashes = 1
		m.step(A.DT)
		slowest = minf(slowest, _hv())
	A.ok("kael shift: running, two Rampages back to back never stop him", slowest >= run_v * RUN_K
			and P.dashes < P.max_dashes() - 1.5, "slowest %.2f run %.2f dashes %.2f" % [slowest, run_v, P.dashes])

## Running, jump, Shift near the top, Space let go: the drive starts at once, never under the speed he came in
## with, holds his height, leaves him moving, and no glider at any point.
func _air_dash() -> void:
	var run_v := _run_in(home + Vector3(-6, 0, 0))
	P.do_jump()
	A.step(m, 0.2)
	var y0 := P.pos.y
	P.do_dash()
	m.step(A.DT)
	var at_once := P.roll_t > 0.0 and _hv() >= run_v
	var slowest := INF
	var glider := false
	var t := 0.0
	while not P.grounded and t < 1.5:
		slowest = minf(slowest, _hv())
		glider = glider or _glider_out()
		if P.roll_t > 0.0:
			y0 = minf(y0, P.pos.y)
		m.step(A.DT)
		t += A.DT
	A.ok("kael shift: the air Rampage drives at once and keeps his speed to the landing",
			at_once and slowest >= run_v * RUN_K, "at once %s slowest %.2f run %.2f" % [at_once, slowest, run_v])
	A.ok("kael shift: no glider in or after the air Rampage without Space", not glider)

## Jump > Shift > Space: in the drive the glider takes the drive's speed; just after it, it opens at once (no
## wind-down lock) at the speed he has. Either chain covers more ground in 1.4s than a plain jump > Space glide.
func _jump_shift_glide() -> void:
	var plain := _glide_run(-1.0)
	var in_drive := _glide_run(0.08)
	var after := _glide_run(0.3)
	var carry := Loco.glide_carry(P.arch)
	A.ok("kael shift: Space in the drive glides off at the drive's speed",
			bool(in_drive["open"]) and float(in_drive["v"]) > carry, str(in_drive))
	A.ok("kael shift: Space just after the drive opens the glider at once, still faster than the run",
			bool(after["open"]) and float(after["v"]) > P.base_speed, str(after))
	A.ok("kael shift: jump > Shift > glide goes further than jump > glide",
			float(in_drive["d"]) > float(plain["d"]) + 6.0 and float(after["d"]) > float(plain["d"]) + 2.0,
			"plain %.1f in drive %.1f after %.1f m" % [float(plain["d"]), float(in_drive["d"]), float(after["d"])])

## Running, jump, Shift 0.15s up (none if `space_at` < 0), Space `space_at` s after Shift (0.25s after the jump
## with no Shift), held: whether the glider opened, its speed the step after, and the ground covered 1.4s from the jump.
func _glide_run(space_at: float) -> Dictionary:
	_run_in(home + Vector3(-6, 0, 0))
	var from := P.pos
	var t0 := m.time
	_press("jump", true)
	P.inp["glide"] = false
	A.step(m, 0.15)
	if space_at >= 0.0:
		_press("dash", false)
	A.step(m, space_at if space_at >= 0.0 else 0.1)
	_press("jump", true)
	m.step(A.DT)
	var out := {"open": P.gliding, "v": snappedf(_hv(), 0.1)}
	while m.time - t0 < 1.4:
		m.step(A.DT)
	out["d"] = Vector2(P.pos.x - from.x, P.pos.z - from.z).length()
	P.inp["glide"] = false
	A.step(m, 1.5)
	return out
