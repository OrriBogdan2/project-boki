extends RefCounted
## --move-feel-check's walking turn (docs/MOVEMENT_FEEL.md, decision 0061-source-walking-turn): every hunter's hard
## reversal and 90-degree cut at run speed against the reference's walking model (V -= (V - dir x |V|) x F dt,
## V += a dt, capped at run; HunterMove.walk). Times are interpolated inside the step so a few percent shows.

## key -> [op, target, unit, note], as move_feel_check's T.
const T := {
	"reverse_vs_source": ["~", [0.98, 1.03], "x", "[game data] A to D, 95% run: ln(1+2Fv/a)/2F + .95v/a"],
	"cut90_vs_source": ["~", [0.97, 1.10], "x", "[game data] cut to 10 deg: ln(1/tan 5deg)/(F+a/v), 60 Hz +5%"],
	"cut90_min_speed": [">=", 0.97, "x", "[game data] a cut arcs at run speed (the speed cap)"],
}
const SKIP := ["physics", "glide_spike", "default"]   # hunter_move.json rows that are not hunters


static func run(c) -> void:
	var P: Hunter = c.P
	var was := [P.cls, P.arch, P.wid, P.base_speed]
	var f := HunterMove.turn_friction
	c.ok(is_equal_approx(f, 1.0), "turn_friction = GroundFriction 1.0 (%s)" % f)
	for id: String in HunterMove.rules():
		if not HunterMove.rules()[id] is Dictionary or id in SKIP:
			continue
		P.cls = Arch.weight(id)
		P.set_arch(id)
		c._reset(c.flat + Vector3(-2.5, 0, 0))
		P.inp["move"] = Vector2(1, 0)
		c._steps(20)
		var v: float = c._hv(P).length()
		var a := P.ground_accel
		P.inp["move"] = Vector2(-1, 0)
		var tr := _cross(c, func() -> float: return -P.vel.x, 0.95 * v)
		var src_r := log(1.0 + 2.0 * f * v / a) / (2.0 * f) + 0.95 * v / a
		c.rec("reverse_vs_source", tr / src_r, T)
		c._reset(c.flat + Vector3(-2.5, 0, -2.5))
		P.inp["move"] = Vector2(1, 0)
		c._steps(20)
		P.inp["move"] = Vector2(0, 1)
		var low := [v]
		var t90 := _cross(c, func() -> float:
			low[0] = minf(low[0], c._hv(P).length())
			return -rad_to_deg(absf(c._hv(P).angle_to(Vector2(0, 1)))), -10.0)
		var src_c := log(1.0 / tan(deg_to_rad(5.0))) / (f + a / v)
		c.rec("cut90_vs_source", t90 / src_c, T)
		c.rec("cut90_min_speed", float(low[0]) / v, T)
		print("MFEEL turn %-10s run %.2f m/s accel %.0f: reverse %.3f s (source %.3f), cut %.3f s (source %.3f)" % [
			id, v, a, tr, src_r, t90, src_c])
	P.inp["move"] = Vector2.ZERO
	P.cls = was[0]
	P.set_arch(was[1])
	if P.wid != was[2]:
		P.equip(was[2])
	P.base_speed = was[3]


## Seconds of match steps until probe() rises to `at`, interpolated inside the last step (-1: never in 1 s).
static func _cross(c, probe: Callable, at: float) -> float:
	var was: float = probe.call()
	for i in 60:
		c.m.step(c.DT)
		var now: float = probe.call()
		if now >= at:
			return (i + (at - was) / maxf(1e-6, now - was)) * c.DT
		was = now
	return -1.0
