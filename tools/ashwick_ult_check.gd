extends RefCounted
## Linwick's ultimate on X, Flue Flight, for --ashwick-combo-check (docs/heroes/ashwick.md): the level gate,
## the lift-off telegraph and move, the steering lane, the capped turn, the early landing, the carpet's burn,
## slow and Char, bond only on a land (the best of hit or knock per cast), the cloak mid-flight, no Cinder
## mid-flight, a knockback speeding it up, a stun ending it, never over the abyss, the merge drop, the
## cooldown and the burst cap.

const BURST := preload("res://tools/ult_burst.gd")

var ak = null
var ok_fn: Callable

func _init(arch_check, ok_cb: Callable) -> void:
	ak = arch_check
	ok_fn = ok_cb

func ok(label: String, cond: bool, info := "") -> void:
	ok_fn.call(label, cond, info)

func run() -> void:
	await _flight()
	await _carpet()
	await _burst()

## Starts the flight toward `at` (cooldown cleared) and returns the jet.
func _cast(P: Hunter, at: Vector3) -> AshwickJet:
	var K: AshwickKit = P.ak
	K.cd["x"] = 0.0
	ak.aim_at(P, at)
	P.ak.use_x()
	return K.jet

func _flight() -> void:
	var r: Array = ak.setup("ashwick", 12.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: AshwickKit = P.ak
	var J := K.jet
	T.teleport(home + Vector3(0, 0, 6.0))
	T2.teleport(home + Vector3(-4.0, 0, 6.0))
	var listed: bool = Settings.ACTIONS.any(func(a): return a[0] == "hunter_ult")
	ok("ult: X is the hero ultimate (rebindable, its own action)", InputMap.has_action("hunter_ult") and listed)
	P.lvl = 5
	_cast(P, home + Vector3(10, 0, 0))
	ok("ult: no cast below level 6", not J.running() and float(K.cd["x"]) == 0.0 and J.flights == 0, "level %d" % P.lvl)
	P.lvl = 6
	var paid0 := HeroUlt.paid_total
	_cast(P, home + Vector3(10, 0, 0))
	ak.step(m, 0.05)
	var burst_up := AimKit.shown(P, "x_burst") and bool(AimKit.entry(P, "x_burst").get("all", false))
	ok(
		"ult cast: lifts off with the ember ring everyone sees", J.running() and burst_up and K.anim_id == "lw_jet",
		"move %s" % K.anim_id
	)
	ok(
		"ult cast: its own cooldown starts (32s)", absf(float(K.cd["x"]) - 32.0) < 0.2 and float(K.cd["e"]) == 0.0,
		"cd %.1f" % float(K.cd["x"])
	)
	ak.step(m, 0.25, func(): ak.aim_at(P, home + Vector3(10, 0, 0)))
	ok(
		"ult telegraph: the heading lane shows while flying", AimKit.shown(P, "x_steer"),
		"len %.1f" % float(AimKit.entry(P, "x_steer").get("len", 0.0))
	)
	ok(
		"ult: flies low, off the ground", P.pos.y - m.world.ground_at(P.pos.x, P.pos.z) > 0.2,
		"height %.2f" % (P.pos.y - home.y)
	)
	P.ak.use_x()
	var start := P.pos
	ok(
		"ult recast: X again lands early", not J.running() and J.early >= 1 and K.anim_id == "lw_land",
		"early %d" % J.early
	)
	ak.step(m, 0.3)
	ok(
		"ult recast: he stops soon after the early landing", P.pos.distance_to(start) < 1.6,
		"slid %.1f" % P.pos.distance_to(start)
	)
	# a full flight: about 9-10 bh in 1.4s
	P.teleport(home)
	_cast(P, home + Vector3(14, 0, 0))
	ak.step(m, 1.5, func(): ak.aim_at(P, home + Vector3(14, 0, 0)))
	var flown := Vector2(P.pos.x - home.x, P.pos.z - home.z).length()
	ok(
		"ult: a full flight covers about 9-10 body heights in 1.4s", not J.running() and flown > 15.0 and flown < 20.0,
		"%.1fm" % flown
	)
	ok("ult: the flight ends on its own with the landing move", J.landings >= 2 and K.anim_id == "lw_land")
	ok(
		"ult bond: nothing for a cast that lands on nobody", HeroUlt.paid_total == paid0,
		"paid %.2f" % (HeroUlt.paid_total - paid0)
	)
	P.ak.use_x()
	ok("ult: the cooldown denies a new flight", not J.running() and J.flights == 2, "cd %.1f" % float(K.cd["x"]))
	await _steer(m, P, K, home)
	await ak.done(m)

## Steering: the flight follows the cursor at no more than 120 degrees a second, so the carpet curves.
func _steer(m: Match, P: Hunter, K: AshwickKit, home: Vector3) -> void:
	var J := K.jet
	P.teleport(home)
	_cast(P, home + Vector3(12, 0, 0))
	ak.step(m, 0.3, func(): ak.aim_at(P, P.pos + Vector3(12, 0, 0)))
	var d0: Vector2 = J.flight["dir"]
	ak.step(m, 0.2, func(): ak.aim_at(P, P.pos + Vector3(0, 0, 12)))
	var d1: Vector2 = J.flight["dir"]
	var turned := rad_to_deg(absf(d0.angle_to(d1)))
	ok(
		"ult steer: the heading turns toward the cursor, capped at 120 deg/s",
		turned > 15.0 and turned <= 120.0 * 0.2 + 3.0, "%.0f deg in 0.2s" % turned
	)
	ak.step(m, 1.2, func(): ak.aim_at(P, P.pos + Vector3(0, 0, 12)))
	ok(
		"ult steer: the flight curves (it ends well to the side)", P.pos.z - home.z > 3.0 and P.pos.x - home.x > 3.0,
		"x %.1f z %.1f" % [P.pos.x - home.x, P.pos.z - home.z]
	)

func _carpet() -> void:
	var r: Array = ak.setup("ashwick", 12.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: AshwickKit = P.ak
	var J := K.jet
	T.teleport(home + Vector3(5.0, 0, 0))
	T2.teleport(home + Vector3(9.0, 0, 0.4))
	var paid0 := HeroUlt.paid_total
	_cast(P, home + Vector3(16, 0, 0))
	ak.step(m, 1.6, func(): ak.aim_at(P, home + Vector3(16, 0, 0)))
	ak.step(m, 0.7)
	var left := 0.0
	if not J.trail.is_empty():
		left = float(J.trail[-1]["until"]) - m.time
	ok(
		"ult payoff: a molten carpet along the flight that lasts about 4s",
		J.trail.size() >= 10 and left > 2.4 and left < 4.0, "pieces %d left %.1f" % [J.trail.size(), left]
	)
	var char_t := K.char_of(T) + 31.0 * float(K.burning(T))
	ok(
		"ult payoff: the carpet burns, slows and builds Char", ak.dmg(T) > 0.5 and T.slow_t > 0.0 and char_t > 0.0,
		"dmg %.1f slow %.2f char %.0f" % [ak.dmg(T), T.slow_t, char_t]
	)
	ok("ult payoff: the slow is about 30%", absf(T.slow_k - 0.3) < 0.01, "slow_k %.2f" % T.slow_k)
	var sent := HeroUlt.paid_total - paid0
	ok(
		"ult bond: burning a hunter fills it once per cast (a hit: 0.6, two hunters still 0.6)",
		absf(sent - 0.6) < 0.001, "sent %.2f" % sent
	)
	var stub := HeroUlt._bond_hook() == null
	ok(
		"ult bond: through the guarded KinBond.from_ult stub (Bond.add until ultbond lands)", stub and P.ult >= 0.6,
		"meter %.2f" % P.ult
	)
	# a knock with it tops the cast up to the knock's share
	ak.step(m, 4.0)
	ak.fresh(T)
	T.hp = 0.5
	T.teleport(home + Vector3(6.0, 0, 0))
	T2.teleport(home + Vector3(0, 0, -6.0))
	P.teleport(home)
	paid0 = HeroUlt.paid_total
	_cast(P, home + Vector3(16, 0, 0))
	ak.step(m, 1.6, func(): ak.aim_at(P, home + Vector3(16, 0, 0)))
	sent = HeroUlt.paid_total - paid0
	ok(
		"ult bond: a knock with the carpet counts as the cast's best event (0.7)",
		T.downed and absf(sent - 0.7) < 0.001, "downed %s sent %.2f" % [T.downed, sent]
	)
	T.downed = false
	ak.fresh(T)
	# a new flight with nobody near: the cloak works mid-flight, the Cinder Shot doesn't
	ak.step(m, 4.0)
	T.teleport(home + Vector3(0, 0, -5.0))
	T2.teleport(home + Vector3(-3.0, 0, -5.0))
	P.teleport(home)
	K.cd["e"] = 0.0
	_cast(P, home + Vector3(16, 0, 0))
	ak.step(m, 0.4, func(): ak.aim_at(P, home + Vector3(16, 0, 0)))
	var used0: int = K.cloaks
	P.ak.use_e()
	ok("ult: the Furnace Cloak works mid-flight (the flight goes on)", K.cloaks == used0 + 1 and J.running())
	var ch0 := K.ch_rmb
	P.ak.press_rmb()
	ak.step(m, 0.02)
	ok("ult: no Cinder Shot mid-flight", K.ch_rmb == ch0 and J.running())
	ak.step(m, 1.2, func(): ak.aim_at(P, home + Vector3(16, 0, 0)))
	# Ablaze in about 2.4s of standing in it (4 Char every 0.3s)
	ak.fresh(T)
	K.chars = {}
	K.ignites = {}
	var spot: Vector3 = J.trail[-1]["b"]
	ak.step(m, 1.4, func(): T.teleport(spot))
	var at_14 := K.burning(T)
	ak.step(m, 1.2, func(): T.teleport(spot))
	ok(
		"ult payoff: standing in it, Ablaze after about 2.4s", at_14 == 0 and K.burning(T) >= 1,
		"at 1.4s %d, at 2.6s %d" % [at_14, K.burning(T)]
	)
	await _abyss(m, P, K, home, m.world)
	await _knock_stun_merge(m, P, K, home)
	await ak.done(m)

## The carpet never forms over the abyss; he flies on over it.
func _abyss(m: Match, P: Hunter, K: AshwickKit, home: Vector3, W) -> void:
	var J := K.jet
	var hx := int(floor(home.x))
	var hz := int(floor(home.z))
	for dz in range(-4, 5):
		for dx in range(5, 8):
			W.kind[W.idx(hx + dx, hz + dz)] = World.T_VOID
	J.trail = []
	P.teleport(home)
	var skips := J.void_skips
	_cast(P, home + Vector3(16, 0, 0))
	ak.step(m, 1.5, func(): ak.aim_at(P, home + Vector3(16, 0, 0)))
	var over := false
	for t in J.trail:
		for p in [t["a"], t["b"]]:
			if W.ground_at((p as Vector3).x, (p as Vector3).z) <= World.VOID + 1.0:
				over = true
	ok(
		"ult abyss: the carpet never forms over the void, he flies across",
		not over and J.void_skips > skips and P.pos.x - home.x > 9.0,
		"skips %d x %.1f" % [J.void_skips - skips, P.pos.x - home.x]
	)
	for dz in range(-4, 5):
		for dx in range(5, 8):
			W.kind[W.idx(hx + dx, hz + dz)] = World.T_GROUND

## A knockback speeds the flight up; a stun ends it; a Boki merge drops it with nothing more laid.
func _knock_stun_merge(m: Match, P: Hunter, K: AshwickKit, home: Vector3) -> void:
	var J := K.jet
	P.teleport(home)
	_cast(P, home + Vector3(16, 0, 0))
	ak.step(m, 0.2, func(): ak.aim_at(P, home + Vector3(16, 0, 0)))
	var sp0 := float(J.flight["speed"])
	P.impulse(Vector2(0.0, 16.0))
	ak.step(m, 0.05, func(): ak.aim_at(P, home + Vector3(16, 0, 0)))
	ok(
		"ult: a knockback mid-flight speeds it up", J.boosts >= 1 and float(J.flight.get("speed", 0.0)) > sp0 + 3.0,
		"speed %.1f -> %.1f" % [sp0, float(J.flight.get("speed", 0.0))]
	)
	ak.step(m, 1.4)
	P.teleport(home)
	_cast(P, home + Vector3(16, 0, 0))
	ak.step(m, 0.3)
	P.stun_t = 0.5
	ak.step(m, 0.05)
	ok("ult: a stun ends the flight", not J.running() and P.roll_t <= 0.0)
	P.stun_t = 0.0
	P.teleport(home)
	_cast(P, home + Vector3(16, 0, 0))
	ak.step(m, 0.3)
	ok("merge hold: the flight is up before the merge", J.running())
	ok("merge hold: a merge is under way", ak.merge_now(P))
	var laid := J.laid
	ak.step(m, 0.6)
	ok(
		"merge hold: linwick's flight is dropped, nothing more is laid",
		not J.running() and J.laid == laid and P.roll_t <= 0.0, "laid +%d" % (J.laid - laid)
	)
	KinMerge.end(P, "test")

func _burst() -> void:
	var res: Dictionary = await BURST.run(ak, "ashwick", 4.0, func(m: Match, P: Hunter, T: Hunter):
		var home := P.pos
		T.teleport(home + Vector3(5.0, 0, 0))
		_cast(P, home + Vector3(16, 0, 0))
		ak.step(m, 1.5, func(): ak.aim_at(P, home + Vector3(16, 0, 0)))
		var end_p: Vector3 = P.ak.jet.trail[-1]["b"] if not P.ak.jet.trail.is_empty() else P.pos
		ak.step(m, 2.4, func(): T.teleport(end_p))
		P.teleport(T.pos + Vector3(-2.0, 0, 0))
		P.ak.cd["e"] = 0.0
		P.ak.use_e()
		ak.step(m, 0.4))
	var info := "ult %.0f, ult + merge %.0f of %d" % [res["ult"], res["total"], int(Data.CLASSES["light"]["hp"])]
	ok(
		"burst: Flue Flight then the merge never one-shots a full-health light hunter",
		bool(res["merged"]) and bool(res["alive"]), info
	)
