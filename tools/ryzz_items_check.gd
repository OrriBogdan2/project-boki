extends RefCounted
## Ryzz items 70-74: faster autos and a longer Wirerun (70), Skycall's orb fling and pull
## (71), the committed Skycall vector (73) and the Storm Rod's single Static (74). Item 72 (Kitefall's Static
## spread) is in tools/vv_ult_check.gd. Runs inside --mage-combo-check and reports through its ok().

const DT := 1.0 / 60.0
const ANGLES := 8
const MAX_OFF_DEG := 5.0

var hc: RefCounted
var ac: RefCounted
var m: Match
var P: Hunter
var T: Hunter
var T2: Hunter
var K: MageKit
var home: Vector3
var arrows_shown := true

func ok(what: String, cond: bool, info := "") -> void:
	hc.ok(what, cond, info)

func run(combo_check: RefCounted, archetype_check: RefCounted) -> void:
	hc = combo_check
	ac = archetype_check
	var r: Array = ac.setup("mage", 4.0, "", true)
	m = r[0]
	P = r[1]
	T = r[2]
	T2 = r[3]
	home = r[4]
	K = P.ak
	_park()
	_item_70()
	await _item_71()
	await _item_73()
	await _item_74()
	await ac.done(m)

func _park() -> void:
	T.teleport(home + Vector3(30, 0, 8))
	T2.teleport(home + Vector3(30, 0, -8))
	P.teleport(home)
	K.sparks.clear()
	K.motes.clear()
	K.strikes.clear()
	ac.step(m, 0.1)

func _item_70() -> void:
	var dash: Dictionary = K.dash_def()
	var wpn: Dictionary = P.wpn
	ok("items 70, 116: autos every 0.648 s, bolt speed 37",
			is_equal_approx(float(wpn["rate"]), 0.648)
			and is_equal_approx(float(wpn["speed"]), 37.0), "%s %s" % [wpn["rate"], wpn["speed"]])
	ok("item 70: Wirerun 7.5 to 13 m at 40 m/s, hold 0.6 s", is_equal_approx(float(dash["dist"][0]), 7.5)
			and is_equal_approx(float(dash["dist"][1]), 13.0) and is_equal_approx(float(dash["speed"]), 40.0)
			and is_equal_approx(float(dash["hold"]), 0.6))
	ok("item 70: the lane preview scales with the charge (full hold = 13 m)",
			is_equal_approx(K.wire_len(0.6), 13.0) and is_equal_approx(K.wire_len(0.0), 7.5))
	var text := String(Arch.def("mage")["card"]["weapons"]["coilcaster"])
	ok("items 70, 116: the card says every 0.65s", text.contains("every 0.65s"), text)
	_park()
	P.fire_cd = 0.0
	P.inp["fire"] = true
	var shots: Array[float] = []
	var last_n := P.shot_n
	var t := 0.0
	while t < 2.2:
		m.step(DT)
		t += DT
		if P.shot_n != last_n:
			last_n = P.shot_n
			shots.append(t)
	P.inp["fire"] = false
	var gap := shots[1] - shots[0] if shots.size() > 1 else 0.0
	ok("items 70, 116: held fire shoots every 0.648 s",
			shots.size() >= 3 and absf(gap - 0.648) < 0.05, "gap %.3f" % gap)

# ------------------------------------------------------------------ item 71
## Casts Skycall on a circle at `at`, drags toward `drag_to`, lets go and runs the 0.8 s plus the fling.
func _skycall(at: Vector3, drag_to: Vector3) -> void:
	K.cd["e"] = 0.0
	ac.aim_at(P, at)
	P.inp["e_down"] = true
	P.ak.use_e()
	ac.step(m, 0.1, func(): ac.aim_at(P, drag_to))
	P.inp["e_down"] = false
	ac.step(m, 1.5)

func _orb(at: Vector3) -> void:
	K.motes.clear()
	K.motes.append({"pos": at, "t": 6.0, "node": K.own_node(), "owner": T})

func _item_71() -> void:
	var fling := float(K.e_def()["fling_dist"])
	var old_fling := 11.0
	_park()
	P.dashes = 0.0
	_orb(home + Vector3(6, 0, 0))
	_skycall(home + Vector3(6, 0, 0), home + Vector3(2, 0, 0))
	ok("item 71: an orb 6 m away dragged toward her arrives and resets Wirerun",
			K.motes.is_empty() and P.dashes >= P.max_dashes(), "orbs %d dashes %.2f" % [K.motes.size(), P.dashes])
	_park()
	P.dashes = 0.0
	_orb(home + Vector3(10.5, 0, 0))
	_skycall(home + Vector3(10.5, 0, 0), home + Vector3(6, 0, 0))
	var left := K.motes.size() == 1 and (K.motes[0]["pos"] as Vector3).x < home.x + 10.5 - 0.5
	ok("item 71: an orb 10.5 m away (out of the 9 m reach) does not reset it, and is flung short",
			P.dashes < 1.0 and left, "dashes %.2f orbs %d" % [P.dashes, K.motes.size()])
	_park()
	_orb(home + Vector3(5, 0, 0))
	_skycall(home + Vector3(5, 0, 0), home + Vector3(5, 0, 9))
	var moved := 0.0
	if K.motes.size() == 1:
		moved = hc._flat(K.motes[0]["pos"], home + Vector3(5, 0, 0))
	ok("item 71: a sideways fling is at most 60% of the old 11 m", moved > 3.0 and moved <= 0.6 * old_fling + 0.01
			and absf(moved - fling) < 0.6 and K.motes[0]["owner"] == P, "%.1f m" % moved)
	_park()
	_orb(home + Vector3(5, 0, 0))
	_skycall(home + Vector3(5, 0, 0), home + Vector3(11, 0, 0))
	moved = hc._flat(K.motes[0]["pos"], home + Vector3(5, 0, 0)) if K.motes.size() == 1 else 0.0
	ok("item 71: an away fling is at most 60% of the old 11 m", moved > 3.0 and moved <= 0.6 * old_fling + 0.01,
			"%.1f m" % moved)

# ------------------------------------------------------------------ item 73
## Foe (alone, then with a neighbour) dragged: its displacement must sit within 5 degrees of the committed vector.
func _drag_case(angle: float, tap: bool, with_neighbour: bool) -> float:
	_park()
	var at := home + Vector3(7, 0, 0)
	ac.fresh(T)
	T.teleport(at)
	if with_neighbour:
		ac.fresh(T2)
		T2.teleport(at + Vector3(0.5, 0, 0.4))
	ac.step(m, 0.3)
	var want := Vector2(1, 0) if tap else Vector2.from_angle(angle)
	var from := T.pos
	K.cd["e"] = 0.0
	ac.aim_at(P, at)
	P.inp["e_down"] = not tap
	P.ak.use_e()
	if not tap:
		ac.step(m, 0.1, func(): ac.aim_at(P, at + Vector3(want.x, 0, want.y) * 3.0))
		P.inp["e_down"] = false
		m.step(DT)
	else:
		m.step(DT)
	m.step(DT)
	var shown := AimKit.shown(P, "e_arrow0")
	# after the commit: she walks off and the cursor sweeps round
	var sweep := func():
		P.teleport(home + Vector3(-2, 0, 6))
		ac.aim_at(P, at + Vector3(0, 0, 8) * sin(m.time * 9.0) + Vector3(-5, 0, 0))
	ac.step(m, 2.4, sweep)
	var got := Vector2(T.pos.x - from.x, T.pos.z - from.z)
	arrows_shown = arrows_shown and shown
	return rad_to_deg(got.angle_to(want)) if got.length() > 0.5 else 180.0

func _item_73() -> void:
	var worst := 0.0
	for i in ANGLES:
		var off := absf(_drag_case(TAU * i / ANGLES, false, false))
		worst = maxf(worst, off)
	ok("item 73: 8 drag angles, every dummy moves within 5 deg of the committed direction", worst <= MAX_OFF_DEG,
			"worst %.1f deg" % worst)
	ok("item 73: the committed arrow shows in the circle for every drag", arrows_shown)
	var tap_off := absf(_drag_case(0.0, true, false))
	ok("item 73: a tap uses the default away from her at the commit, within 5 deg", tap_off <= MAX_OFF_DEG,
			"%.1f deg" % tap_off)
	var near_off := absf(_drag_case(2.2, false, true))
	ok("item 73: with a neighbour inside the circle too, still within 5 deg", near_off <= MAX_OFF_DEG,
			"%.1f deg" % near_off)
	_park()
	K.cd["e"] = 0.0
	ac.aim_at(P, home + Vector3(7, 0, 0))
	P.inp["e_down"] = true
	P.ak.use_e()
	ac.step(m, 0.1, func(): ac.aim_at(P, home + Vector3(7.2, 0, 0.3)))
	P.inp["e_down"] = false
	ac.step(m, 0.1)
	var d: Vector2 = K.strikes[0]["dir"]
	ok("item 73: a tiny drag falls back to the tap default (away from her)", d.x > 0.99, str(d))
	ok("item 73: the arrow is up during the countdown", AimKit.shown(P, "e_arrow0"))
	ac.step(m, 1.5)

# ------------------------------------------------------------------ item 74
func _item_74() -> void:
	_park()
	ac.fresh(T)
	T.teleport(home + Vector3(5, 0, 0))
	ac.step(m, 0.2)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	ac.aim_at(P, T.pos)
	ac.hold(m, P, 1.0)
	ac.step(m, 0.3)
	var after_hit := K.spark_n(T)
	var orb_made := K.motes.size() >= 1
	if orb_made:
		T.teleport((K.motes[0]["pos"] as Vector3) + Vector3(0.5, 0, 0))
	var worst := 0
	var t := 0.0
	while t < 3.5:
		ac.step(m, 0.25, func(): T.vel = Vector3.ZERO)
		t += 0.25
		worst = maxi(worst, K.spark_n(T))
	ok("item 74: a Rod hit leaves exactly 1 Static, and the orb standing by it adds none for 4 s",
			after_hit == 1 and worst == 1 and orb_made, "after %d worst %d orb %s" % [after_hit, worst, orb_made])
	ok("item 74: the orb is still there as a pickup", K.motes.size() == 1)
