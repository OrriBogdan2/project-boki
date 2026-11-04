extends RefCounted
## Sable's feel pass (item 7 of the 1103 review), run inside --dancer-combo-check (tools/dancer_jug_check.gd): the
## Cartwheel's distance, time and speed curve against the source's measured one, the empowered bolt's damage and
## window, the Vault back on the hit's own step, the reset loop's pace, and a click mid-flip kept until the bolt
## can go. The source numbers are in docs/heroes/thief.md, "Feel pass (item 7)".

const GROUND_M := 4.5        # m: the ground Cartwheel (sheet: 105-144 px, about 4.5m)
const GROUND_S := 0.48       # s: start to upright (sheet: 0.45-0.5s)
const PEAK_MS := [14.0, 17.0]        # m/s: the sheet's peak, 15-16.5 m/s ...
const PEAK_AT := [0.08, 0.27]        # s: ... at +0.1 to 0.27s
const AIR_M := 8.4           # m: the air Cartwheel (sheet: 225 px over about 0.95s)
const EMP_K := 2.34          # the empowered bolt over a plain one (data: +214 on a 160 bolt)
const LOOP_S := 1.4          # s: the footage's reset loop (0187 -> 0194); ours keeps up with it
var A

func run(a, m: Match, P: Hunter, K: ThiefKit, T: Hunter, home: Vector3) -> void:
	A = a
	_ground(m, P, K, home)
	_air(m, P, K, home)
	_empowered(m, P, K, T, home)
	_window(m, P, K, home)
	_loop(m, P, K, T, home)
	_buffer(m, P, K, T, home)
	_calm(m, P, K)

## Nothing empowered or hasted, standing still, the Vault ready.
func _calm(m: Match, P: Hunter, K: ThiefKit) -> void:
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	A.step(m, 0.6)
	K.primed_t = 0.0
	K.haste_t = 0.0
	P.dashes = P.max_dashes()
	P.fire_cd = 0.0

## Runs a Cartwheel already started, noting where and when it ends and its fastest step.
func _track(m: Match, P: Hunter, from: Vector3, secs: float) -> Dictionary:
	var s := {"last": P.pos, "t": 0.0, "peak": 0.0, "peak_at": 0.0, "end": -1.0, "dist": 0.0}
	A.step(m, secs, func():
		var last: Vector3 = s["last"]
		var v: float = Vector2(P.pos.x - last.x, P.pos.z - last.z).length() / A.DT
		if s["end"] < 0.0 and v > s["peak"]:
			s["peak"] = v
			s["peak_at"] = s["t"]
		if s["end"] < 0.0 and P.roll_t <= 0.0:
			s["end"] = s["t"]
			s["dist"] = P.flat_dist(from)
		s["last"] = P.pos
		s["t"] = float(s["t"]) + A.DT)
	return s

func _ground(m: Match, P: Hunter, K: ThiefKit, home: Vector3) -> void:
	_calm(m, P, K)
	P.teleport(home)
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	var s := _track(m, P, home, 0.7)
	P.inp["move"] = Vector2.ZERO
	A.ok("dancer feel: the ground Cartwheel is the source's, 4.5m in 0.48s (off the global dash feel)",
			absf(float(s["dist"]) - GROUND_M) < 0.35 and absf(float(s["end"]) - GROUND_S) < 0.05
			and K.dash_feel()["dist"] == 1.0,
			"%.2f m in %.2f s" % [s["dist"], s["end"]])
	A.ok("dancer feel: it bursts to about 15 m/s near 0.15s, then runs down into the hasted run",
			float(s["peak"]) >= PEAK_MS[0] and float(s["peak"]) <= PEAK_MS[1]
			and float(s["peak_at"]) >= PEAK_AT[0] and float(s["peak_at"]) <= PEAK_AT[1],
			"peak %.1f m/s at %.2f s" % [s["peak"], s["peak_at"]])

func _air(m: Match, P: Hunter, K: ThiefKit, home: Vector3) -> void:
	_calm(m, P, K)
	P.teleport(home)
	P.do_jump()
	A.step(m, 0.1)
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	P.inp["move"] = Vector2.ZERO
	var s := _track(m, P, home, 1.6)
	A.ok("dancer feel: from a jump it carries about 8.4m and ends as she lands (under the source's 0.95s)",
			absf(float(s["dist"]) - AIR_M) < 1.2 and float(s["end"]) <= 1.0 and P.grounded,
			"%.2f m in %.2f s" % [s["dist"], s["end"]])

## The empowered bolt: a plain bolt plus the source's bonus, ranks grow the bonus, Marks add flat; the Vault is
## back on the very step it lands.
func _empowered(m: Match, P: Hunter, K: ThiefKit, T: Hunter, home: Vector3) -> void:
	_calm(m, P, K)
	A.fresh(T)
	P.teleport(home)
	T.teleport(home + Vector3(6.0, 0, 0))
	A.aim_at(P, T.pos)
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	var plain := float(m.shots[-1]["dmg"])
	A.step(m, 0.5)
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	A.step(m, 0.5)
	P.inp["move"] = Vector2.ZERO
	A.aim_at(P, T.pos)
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	var emp := float(m.shots[-1]["dmg"])
	var hit := {"t": 0.0, "at": -1.0, "dashes": 0.0, "hits": K.primed_hits}
	A.step(m, 0.5, func():
		if float(hit["at"]) < 0.0 and K.primed_hits > int(hit["hits"]):
			hit["at"] = hit["t"]
			hit["dashes"] = P.dashes
		hit["t"] = float(hit["t"]) + A.DT)
	var ranks: Array = []
	for rk in [1, 2, 3]:
		P.slot_lv["dash"] = rk
		ranks.append(snappedf(K.empowered_k(), 0.001))
	P.slot_lv["dash"] = 1
	A.ok("dancer feel: the empowered bolt is a bolt plus the source's bonus (2.34x), the bonus +20% / +40% by rank",
			absf(emp / plain - EMP_K) < 0.01 and ranks == [2.34, 2.608, 2.876],
			"%.2f / %.2f = %.3f ranks %s" % [emp, plain, emp / plain, str(ranks)])
	A.ok("dancer feel: the Vault is back on the step the empowered bolt lands (its flight, 0.3s at most)",
			float(hit["at"]) >= 0.0 and float(hit["at"]) < 0.3 and float(hit["dashes"]) >= P.max_dashes() - 0.01,
			"landed at %.2f s dashes %.2f" % [hit["at"], hit["dashes"]])
	A.fresh(T)
	K.add_mark(T, 5, true)
	K.primed_on = T
	var on_emp := K.outgoing(T, 10.0 * EMP_K, {"src": "shot"})
	K.primed_on = null
	A.ok("dancer feel: Marks add 10% of a bolt each, the empowered one too (flat, as the source's +16 a stack)",
			absf(on_emp - (10.0 * EMP_K + 5.0)) < 0.01 and absf(K.outgoing(T, 10.0, {"src": "shot"}) - 15.0) < 0.01,
			"%.2f" % on_emp)
	A.fresh(T)

## The window: the speed lasts 2s, the empowered bolt waits 3s, then a bolt is plain again.
func _window(m: Match, P: Hunter, K: ThiefKit, home: Vector3) -> void:
	_calm(m, P, K)
	P.teleport(home)
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	A.step(m, 0.5)
	P.inp["move"] = Vector2.ZERO
	A.step(m, 1.35)
	var hasted := K.move_k() > 1.15
	A.step(m, 0.25)
	var hasted_after := K.move_k() > 1.0
	A.step(m, 0.8)
	var still := K.primed_t > 0.0
	A.step(m, 0.2)
	A.aim_at(P, P.pos + Vector3(-6.0, 0, 0))
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	A.ok("dancer feel: +18% speed for 2s; the empowered bolt waits 3s, then the next bolt is plain",
			hasted and not hasted_after and still and K.primed_t <= 0.0 and not K.last_bolt_emp,
			"haste %s/%s primed at 2.9s %s, after %.2f emp %s" % [hasted, hasted_after, still, K.primed_t,
					K.last_bolt_emp])

## The reset loop with LMB held: Vault, the bolt goes mid-flip, it lands, the Vault is back, Vault again as soon
## as she is up: two empowered hits inside the footage's 1.4s loop.
func _loop(m: Match, P: Hunter, K: ThiefKit, T: Hunter, home: Vector3) -> void:
	_calm(m, P, K)
	A.fresh(T)
	P.teleport(home)
	T.teleport(home + Vector3(6.0, 0, 0))
	var hits0 := K.primed_hits
	var lp := {"t": 0.0, "times": [], "side": 1.0}
	A.step(m, LOOP_S, func():
		A.aim_at(P, T.pos)
		P.inp["fire"] = true
		if P.roll_t <= 0.0 and P.dashes >= 1.0 and K.primed_t <= 0.0:
			lp["side"] = -float(lp["side"])
			P.inp["move"] = Vector2(0, float(lp["side"]))
			P.do_dash()
		if K.primed_hits - hits0 > (lp["times"] as Array).size():
			(lp["times"] as Array).append(lp["t"])
		lp["t"] = float(lp["t"]) + A.DT)
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	var times: Array = lp["times"]
	A.ok("dancer feel: the reset loop keeps the footage's pace (two empowered hits inside 1.4s, LMB held)",
			times.size() >= 2 and float(times[1]) <= LOOP_S, "hits at %s" % str(times))
	A.fresh(T)

## A click while the last bolt still cools, made mid-cartwheel, is kept and goes, empowered, before she is up.
func _buffer(m: Match, P: Hunter, K: ThiefKit, T: Hunter, home: Vector3) -> void:
	_calm(m, P, K)
	A.fresh(T)
	P.teleport(home)
	T.teleport(home + Vector3(6.0, 0, 0))
	A.aim_at(P, T.pos)
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	A.step(m, 0.1)
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	A.step(m, 0.1)
	var cooling := P.fire_cd
	var b0 := K.bolts
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	var went := {"mid_flip": false, "emp": false}
	A.step(m, 0.4, func():
		if K.bolts > b0 and not bool(went["emp"]):
			went["emp"] = K.last_bolt_emp
			went["mid_flip"] = P.roll_t > 0.0)
	P.inp["move"] = Vector2.ZERO
	A.ok("dancer feel: a click mid-flip while the bolt cools is kept and goes, empowered, before she is up",
			cooling > 0.1 and K.bolts == b0 + 1 and bool(went["emp"]) and bool(went["mid_flip"]),
			"cooling %.2f bolts +%d %s" % [cooling, K.bolts - b0, str(went)])
	A.fresh(T)
