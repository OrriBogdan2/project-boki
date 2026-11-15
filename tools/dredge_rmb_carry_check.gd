extends RefCounted
## Abyssal Hand thrown on the move (docs/heroes/dredge.md "Moving while casting"), for
## --dredge-combo-check: thrown at the top of a jump back he keeps that jump's backward speed while his height
## is held, then falls and brakes on the ground as after any jump; a dash's extra speed is not kept longer
## than without the hand; thrown on the ground he stays braced at a fifth of his walk.

const RUN_UP := 0.5          # s running back before the jump or the throw
const CARRY_MIN := 0.9       # share of the throw's speed still there at the miss, and of the miss's at the landing
const BRAKE_T := 0.3         # s on the ground after landing, keys let go (braking as after a plain jump)

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
	T.teleport(T.pos + Vector3(0, 0, 60))     # the hand flies out at nobody (a miss)
	var plain := _leap(m, P, home, false, false)
	var hand := _leap(m, P, home, false, true)
	var info := "throw %.2f m/s, at the miss %.2f (plain jump %.2f), landing %.2f, %.2f m (plain %.2f), " \
			+ "height %+.3f, braked to %.2f (plain %.2f)"
	ok(
		"hand mid-jump: the jump back keeps its speed while his height holds, then he lands and brakes",
		hand["v_end"] >= CARRY_MIN * hand["v_throw"] and hand["v_end"] >= plain["v_end"] - 0.05
		and hand["drift"] <= 0.05 and hand["dist"] > plain["dist"]
		and hand["v_land"] >= CARRY_MIN * hand["v_end"] and hand["v_brake"] <= plain["v_brake"] + 0.05,
		info % [hand["v_throw"], hand["v_end"], plain["v_end"], hand["v_land"], hand["dist"], plain["dist"],
			hand["drift"], hand["v_brake"], plain["v_brake"]]
	)
	var dash := _leap(m, P, home, true, false)
	var dash_hand := _leap(m, P, home, true, true)
	ok(
		"hand after an air dash: the dash's extra speed bleeds as without the hand (no stacking)",
		dash_hand["v_throw"] > P.base_speed and dash_hand["v_end"] <= dash["v_end"] + 0.05,
		"throw %.2f m/s, at the miss %.2f (no hand %.2f), run %.2f" % [
			dash_hand["v_throw"], dash_hand["v_end"], dash["v_end"], P.base_speed]
	)
	var ground := _ground_throw(m, P, home)
	ok(
		"hand on the ground while running back: braced at a fifth of his walk while it flies",
		ground["k"] >= 0.15 and ground["k"] <= 0.25, "%.2f of his run, %.2f m in flight" % [ground["k"], ground["dist"]]
	)
	await ak.done(m)

## Runs back, jumps (and air dashes when `dash`), throws the hand at the top (or the same moment without it when
## not `hand`) and holds back until landing: speeds at the throw, the miss and the landing, the reach from the jump.
func _leap(m: Match, P: Hunter, home: Vector3, dash: bool, hand: bool) -> Dictionary:
	var K: DredgeKit = P.ak
	var out := _run_back(m, P, home)
	var from := P.pos
	P.inp["jump"] = true
	_tick(m)
	P.inp["jump"] = false
	while P.vel.y > 0.0:
		_tick(m)
	if dash:
		P.do_dash()
		while P.roll_t > 0.0:
			_tick(m)
	out["v_throw"] = _hv(P)
	var y0 := P.pos.y
	var t := 0.0
	if hand:
		ak.tap(m, P)
		while K.flying:
			_tick(m)
			out["drift"] = maxf(out["drift"], absf(P.pos.y - y0))
	else:
		while t < float(K.rmb_def()["range"]) / float(K.rmb_def()["speed"]):
			_tick(m)
			t += ak.DT
	out["v_end"] = _hv(P)
	while not P.grounded:
		out["v_land"] = _hv(P)
		_tick(m)
	out["dist"] = P.flat_dist(from)
	P.inp["move"] = Vector2.ZERO
	ak.step(m, BRAKE_T)
	out["v_brake"] = _hv(P)
	ak.step(m, 1.0)
	return out

func _ground_throw(m: Match, P: Hunter, home: Vector3) -> Dictionary:
	var K: DredgeKit = P.ak
	_run_back(m, P, home)
	var v_run := _hv(P)
	ak.tap(m, P)
	ak.step(m, 0.05)
	var from := P.pos
	ak.step(m, 0.25)
	var out := {"k": P.flat_dist(from) / 0.25 / maxf(0.01, v_run), "dist": 0.0}
	while K.flying:
		_tick(m)
	out["dist"] = P.flat_dist(from)
	P.inp["move"] = Vector2.ZERO
	ak.step(m, 1.0)
	return out

## Back at home with the hand ready, facing -x, running back toward +x for RUN_UP.
func _run_back(m: Match, P: Hunter, home: Vector3) -> Dictionary:
	var K: DredgeKit = P.ak
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.dashes = P.max_dashes()
	P.ex_cd = 0.0
	K.next_barge = 0.0
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	ak.aim_at(P, home + Vector3(-10.0, 0, 0))
	P.inp["move"] = Vector2(1, 0)     # (+x: open ground, the abyss is 9 m behind -x)
	ak.step(m, RUN_UP)
	return {"drift": 0.0, "v_land": 0.0}

## One frame with the camps cleared first, as ak.step does: a respawned mob in the arm's line would be grabbed
## and the reel would hold his height (this check is about a miss).
func _tick(m: Match) -> void:
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	m.step(ak.DT)

func _hv(P: Hunter) -> float:
	return Vector2(P.vel.x, P.vel.z).length()
