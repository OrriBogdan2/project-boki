extends RefCounted
## Sable's Vault loop and Bola (OWNER_REVIEW_1103 item 53), run inside --dancer-combo-check: five chained
## Vault -> empowered hit cycles all reset, each with a different flip from the last; no Shift press is lost in
## a fast loop; a single caught foe is Grounded and slowed, a pair stays stunned.

const CYCLES := 5
const BOLA_SLOW := 0.3       # the owner's default: the Bola's slow, over the Ground's 1.5s
var A

func run(a, m: Match, P: Hunter, K: ThiefKit, T: Hunter, T2: Hunter, home: Vector3) -> void:
	A = a
	_chain(m, P, K, T, home)
	_flips()
	_press_mid_flip(m, P, K, T, home)
	_press_in_flight(m, P, K, T, home)
	_miss(m, P, K, home)
	_air_reset(m, P, K, T, home)
	_bola(m, P, K, T, T2, home)

## Ready for a cycle: no flip, no bolt, nothing empowered, the charge spent or ready as asked.
func _calm(m: Match, P: Hunter, K: ThiefKit, T: Hunter, home: Vector3, foe_at: float) -> void:
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	A.step(m, 0.7)
	A.fresh(T)
	K.primed_t = 0.0
	K.haste_t = 0.0
	K.chain.gap_t = 0.0
	P.teleport(home)
	T.teleport(home + Vector3(foe_at, 0, 0))
	P.dashes = P.max_dashes()
	P.ex_cd = 0.0
	P.fire_cd = 0.0
	A.step(m, 0.1)
	A.aim_at(P, T.pos)

func _vault(P: Hunter, dir: Vector2) -> void:
	P.inp["move"] = dir
	P.do_dash()

func _click(m: Match, P: Hunter, T: Hunter) -> void:
	A.aim_at(P, T.pos)
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false

## Five cycles in a row: the charge can't come back on its own (it is spent, the regen is far off), so each next
## Vault is the reset's.
func _chain(m: Match, P: Hunter, K: ThiefKit, T: Hunter, home: Vector3) -> void:
	_calm(m, P, K, T, home, 6.0)
	var hits0 := K.primed_hits
	var flips: Array = []
	var back_at_once := true
	for i in CYCLES:
		P.teleport(home)
		_vault(P, Vector2(0, 1 if i % 2 == 0 else -1))
		flips.append(K.anim_id)
		A.step(m, 0.5)
		P.inp["move"] = Vector2.ZERO
		_click(m, P, T)
		var want: int = hits0 + i + 1
		A.step(m, 0.4)
		back_at_once = back_at_once and K.primed_hits == want and P.dashes >= P.max_dashes() - 0.01
	A.ok("dancer loop: %d chained Vault -> empowered hit cycles all reset (no cap)" % CYCLES,
			K.primed_hits == hits0 + CYCLES and back_at_once, "hits +%d" % [K.primed_hits - hits0])
	var repeats := 0
	for i in range(1, flips.size()):
		if flips[i] == flips[i - 1]: repeats += 1
	A.ok("dancer loop: a chain is a routine of flips, never one clip twice running", repeats == 0
			and flips.all(func(f): return f in ThiefKit.CARTWHEELS), str(flips))

## Every flip is a full turn off the ground with the crossbows tucked and the wings flaring, on the same beats.
func _flips() -> void:
	var good := ["thf_vault_r", "thf_vault_l", "thf_vault_f", "thf_vault_b", "thf_vault_twist"].all(_flip_ok)
	A.ok("dancer loop: every flip turns a full circle in the air, crossbows tucked, wings flared", good)

func _flip_ok(id: String) -> bool:
	var top := HunterAnim.km_sample(id, 0.2)
	var turn := absf(float(top["fz"])) + absf(float(top["fx"]))
	var tucked := absf((top["fl"] as Vector3).x) < 0.25 and absf((top["fr"] as Vector3).x) < 0.25
	var end: Array = KMovesDJ.MOVES[id]["keys"][-1]
	var whole := absf(float(end[1].get("fz", 0.0)) + float(end[1].get("fx", 0.0)))
	return turn > 2.0 and float(top["lift"]) > 0.3 and float(top["wg"]) >= 0.9 and tucked \
			and float(end[0]) == 0.48 and is_equal_approx(whole, 6.283)

## Shift mid-flip, long before the shared buffer's last 0.18s, with the bolt that resets it still to land.
func _press_mid_flip(m: Match, P: Hunter, K: ThiefKit, T: Hunter, home: Vector3) -> void:
	_calm(m, P, K, T, home, 3.0)
	_vault(P, Vector2(0, 1))
	A.step(m, 0.03)
	_click(m, P, T)
	A.step(m, 0.05)
	P.do_dash()
	var early := P.roll_t
	var first := K.anim_at
	var again := {"at": -1.0}
	A.step(m, 0.7, func():
		if K.anim_id in ThiefKit.CARTWHEELS and K.anim_at > first + 0.1 and float(again["at"]) < 0.0:
			again["at"] = m.time - first)
	P.inp["move"] = Vector2.ZERO
	A.ok("dancer loop: Shift pressed %.2fs before the flip ends isn't lost: the next Vault follows at once" % early,
			early > 0.18 and float(again["at"]) > 0.0 and float(again["at"]) < 0.56 and K.primed_t > 0.0,
			"next at %.2f, flip left %.2f, primed %.2f" % [again["at"], early, K.primed_t])

## Shift with no charge while the bolt flies: not the long dash, a real Vault as it lands.
func _press_in_flight(m: Match, P: Hunter, K: ThiefKit, T: Hunter, home: Vector3) -> void:
	_calm(m, P, K, T, home, 9.0)
	_vault(P, Vector2(0, 1))
	A.step(m, 0.52)
	P.inp["move"] = Vector2.ZERO
	A.aim_at(P, T.pos)
	_click(m, P, T)
	P.inp["move"] = Vector2(0, -1)
	P.do_dash()
	var kept := K.chain.waiting and P.ex_cd <= 0.0 and P.roll_t <= 0.0
	var hits0 := K.primed_hits
	A.step(m, 0.5)
	P.inp["move"] = Vector2.ZERO
	A.ok("dancer loop: Shift while the empowered bolt flies waits for it, then a real Vault, not the long dash",
			kept and K.primed_hits == hits0 + 1 and not K.chain.waiting and P.ex_cd <= 0.0 and K.primed_t > 0.0,
			"kept %s hits +%d ex_cd %.2f primed %.2f" % [kept, K.primed_hits - hits0, P.ex_cd, K.primed_t])

## ... and if the bolt misses, the press still does what it always did.
func _miss(m: Match, P: Hunter, K: ThiefKit, home: Vector3) -> void:
	P.inp["fire"] = false
	A.step(m, 0.7)
	K.primed_t = 0.0
	P.teleport(home)
	P.dashes = P.max_dashes()
	P.ex_cd = 0.0
	A.step(m, 0.1)
	_vault(P, Vector2(0, 1))
	A.step(m, 0.52)
	P.inp["move"] = Vector2.ZERO
	A.aim_at(P, home + Vector3(-6.0, 0, 0))
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	P.do_dash()
	A.step(m, 0.5)
	A.ok("dancer loop: a miss still lets the waiting press go (the long dash, with no charge)",
			not K.chain.waiting and P.ex_cd > 0.0, "ex_cd %.2f" % P.ex_cd)

## From a jump the Vault is the air one (it runs on the long dash's cooldown): the reset gives that back too.
func _air_reset(m: Match, P: Hunter, K: ThiefKit, T: Hunter, home: Vector3) -> void:
	_calm(m, P, K, T, home, 6.0)
	P.do_jump()
	A.step(m, 0.1)
	_vault(P, Vector2(0, 1))
	var spent := P.ex_cd > 0.0
	A.step(m, 0.1)
	P.inp["move"] = Vector2.ZERO
	var hits0 := K.primed_hits
	_click(m, P, T)
	A.step(m, 0.4)
	A.ok("dancer loop: the reset gives the air Vault back too", spent and K.primed_hits == hits0 + 1
			and P.ex_cd <= 0.0, "spent %s ex_cd %.2f" % [spent, P.ex_cd])

func _bola(m: Match, P: Hunter, K: ThiefKit, T: Hunter, T2: Hunter, home: Vector3) -> void:
	_calm(m, P, K, T, home, 4.0)
	T2.teleport(home + Vector3(-30.0, 0, 0))
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	P.inp["sec_hold"] = false
	K.press_rmb()
	var seen := {"gnd": false, "slow": 0.0, "mult": 1.0, "stun": 0.0}
	A.step(m, 0.8, func():
		seen["stun"] = maxf(float(seen["stun"]), T.stun_t)
		if KitStatus.grounded(T):
			seen["gnd"] = true
			seen["slow"] = maxf(float(seen["slow"]), T.slow_t)
			seen["mult"] = T.slow_mult(0.5))
	A.ok("dancer Bola: one foe caught is Grounded and slowed 30% for the Ground's 1.5s, no stun",
			bool(seen["gnd"]) and absf(float(seen["slow"]) - 1.5) < 0.2 and float(seen["stun"]) <= 0.0
			and absf(float(seen["mult"]) - (1.0 - BOLA_SLOW)) < 0.01, str(seen))
	_calm(m, P, K, T, home, 4.0)
	T2.teleport(home + Vector3(7.0, 0, 0))
	A.fresh(T2)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	var pairs0 := K.bola_pairs
	K.press_rmb()
	A.step(m, 0.9)
	A.ok("dancer Bola: a pair in a line stays the stun and bonus damage", K.bola_pairs == pairs0 + 1
			and T.stun_t > 0.0 and T2.stun_t > 0.0 and A.dmg(T) >= 18.0, "dmg %.0f" % A.dmg(T))
	T2.teleport(home + Vector3(-30.0, 0, 0))
	A.fresh(T)
	A.fresh(T2)
	P.inp["sec_hold"] = false
