extends RefCounted
## Presses while the Abyssal Hand's arm is out, before it hooks anyone (docs/heroes/dredge.md, Cancels), for
## --dredge-combo-check. The source locks only the pull (the wiki: only the dash and the air dash while it
## pulls), so the gun, the Anchor Drop and the Brass Broadside all go at once and the arm flies on; a second
## Abyssal Hand is refused (one arm, its cooldown already running).

const INTO_FLIGHT := 0.3     # s after the throw: past the 0.2 s coil-back, the arm a few metres out
const SETTLE := 2.5          # s for the arm to miss and whatever was cast with it to finish

var ak = null
var ok_fn: Callable

func _init(arch_check, ok_cb: Callable) -> void:
	ak = arch_check
	ok_fn = ok_cb

func ok(label: String, cond: bool, info := "") -> void:
	ok_fn.call(label, cond, info)

func run() -> void:
	var r: Array = ak.setup("dredge", 6.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: DredgeKit = P.ak
	T.teleport(T.pos + Vector3(0, 0, 60))     # the arm flies out at nobody (a miss)
	var away := home + Vector3(0, 0, -10.0)

	_throw(m, P, away)
	var ch0 := K.ch_rmb
	var hook := K.hook_sd
	ak.tap(m, P)
	ok(
		"arm out: a second Abyssal Hand is refused, the first arm flies on",
		K.flying and is_same(K.hook_sd, hook) and K.ch_rmb == ch0 and K.grapples == 0,
		"flying %s, charges %.2f -> %.2f" % [K.flying, ch0, K.ch_rmb]
	)
	ak.step(m, SETTLE)

	_throw(m, P, away)
	var shots0 := P.shot_n
	P.inp["fire"] = true
	ak.step(m, 0.1)
	P.inp["fire"] = false
	ok("arm out: the gun fires, the arm flies on", P.shot_n > shots0 and K.flying, "volleys +%d" % (P.shot_n - shots0))
	ak.step(m, SETTLE)

	_throw(m, P, away)
	K.use_e()
	ak.step(m, ak.DT)
	ok("arm out: E winds the Anchor up at once, the arm flies on", K.wind > 0.0 and K.flying, "wind %.2f" % K.wind)
	ak.step(m, SETTLE)

	_throw(m, P, away)
	var B := K.broadside
	var waves0 := B.waves
	K.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)
	ak.step(m, ak.DT)
	var both := B.charging() and K.flying
	var tw := 0.0
	while K.flying and tw < 1.5:
		ak.step(m, ak.DT)
		tw += ak.DT
	var missed := not K.flying and K.pull.is_empty() and B.running()
	ak.step(m, 2.0)
	ok(
		"arm out: X starts the Broadside at once, the arm flies on to its miss, both waves go",
		both and missed and B.waves == waves0 + 2, "charging with the arm out %s, miss mid-ult %s, waves +%d" % [
			both, missed, B.waves - waves0]
	)
	await ak.done(m)

## Throws the arm at `at` from a fresh cooldown and steps into its flight.
func _throw(m: Match, P: Hunter, at: Vector3) -> void:
	var K: DredgeKit = P.ak
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	ak.aim_at(P, at)
	ak.tap(m, P)
	ak.step(m, INTO_FLIGHT)
	ok("arm out: the arm is in flight", K.flying and not K.hook_sd.is_empty())

