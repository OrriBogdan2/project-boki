extends RefCounted
## Vex's Coin Blast sticks to any placed object or shield it hits (docs/heroes/gunslinger.md, source row "The grenade
## sticks to dynamic objects"), run inside --gunslinger-combo-check (tools/hero_combo_check.gd): an aegis, a Rink
## Wall and a Tenzo rock hold it, it rides a wall that moves, and when the wall breaks or runs out it drops to the
## ground and still blasts a foe in its cone. A wall of her own team lets it through.
const SPOT := 5.0            # m east of her where the wall stands
const REACH := 1.5           # m a moved wall carries the coin
var C                        # the combo check (ok, ac, helpers)

func _init(check) -> void:
	C = check

func run(m: Match, P: Hunter, K: GunslingerKit, T: Hunter, home: Vector3) -> void:
	var west := Vector2(-1, 0)
	var east := Vector2(1, 0)
	var far := home + Vector3(30, 0, 8)
	var aegis := func() -> Dictionary:       # Albert's raised shield: stays in front of its bearer, who faces her
		T.teleport(home + Vector3(SPOT + 1.0, 0, 0))
		C.ac.aim_at(T, home)
		var e := {"length": 4.2, "hp": 160.0, "time": 99.0, "follow": true, "dist": 0.95, "block": "enemy"}
		return m.verbs.add_wall(T, T.pos + Vector3(west.x, 0, west.y), west, e, 1.0)
	var rink := func() -> Dictionary:        # Neve's Rink Wall: a block of ice that slides and then stands 4.5 s
		var e := {"length": 3.0, "hp": 200.0, "time": 4.5, "move": true, "block": "enemy"}
		return m.verbs.add_wall(T, home + Vector3(SPOT, 0, 0), east, e, 1.0)
	var rock := func() -> Dictionary:        # Tenzo's Stone Row rock
		return HeroZones.rock(m, T, home + Vector3(SPOT, 0, 0), east, "vexc", 2.0, 9.0, 45.0, false)
	var walk := func(_w: Dictionary) -> void: T.teleport(T.pos + Vector3(REACH, 0, 0))     # the bearer steps on
	var slide := func(w: Dictionary) -> void: _slide(w, REACH)
	_case(m, P, K, T, home, far, "an aegis", aegis, walk, true)
	_case(m, P, K, T, home, far, "a Rink Wall", rink, slide, false)
	_case(m, P, K, T, home, far, "a Tenzo rock", rock, Callable(), true)
	_own_wall(m, P, K, T, home, far)

## One wall: she fires through the wall's spot, the coin sticks and follows `shift`, then the wall goes (broken, or
## run out when `broken` is false) and the coin falls and blasts the foe, which then stands in its cone.
func _case(m: Match, P: Hunter, K: GunslingerKit, T: Hunter, home: Vector3, far: Vector3, what: String,
		make: Callable, shift: Callable, broken: bool) -> void:
	var rattles0 := K.rattles
	var hits0 := K.direct_hits
	C.ac.fresh(T)
	T.teleport(far)
	P.teleport(home)
	C.ac.aim_at(P, home + Vector3(8.0, 0, 0))
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	var w: Dictionary = make.call()
	C.ac.step(m, 0.1)
	C.ac.tap(m, P)
	C.ac.step(m, 0.35)
	var b: Dictionary = K.burrs[-1] if not K.burrs.is_empty() else {}
	var at: Vector3 = b.get("pos", Vector3.ZERO)
	var stuck := not b.is_empty() and b.has("on") and absf(at.x - (home.x + SPOT)) < 1.3 and K.direct_hits == hits0
	C.ok("Vex coin: it sticks to %s" % what, stuck and float(b.get("fuse", -1.0)) > 0.0,
			"at %.2f of %.1f" % [at.x - home.x, SPOT])
	var moved := true
	if shift.is_valid():
		shift.call(w)
		C.ac.step(m, 0.1)
		var now: Vector3 = b.get("pos", Vector3.ZERO)
		moved = absf((now.x - at.x) - REACH) < 0.3
		C.ok("Vex coin: it rides %s as it moves" % what, moved and b.has("on"), "moved %.2f" % (now.x - at.x))
	var held: Vector3 = b.get("pos", Vector3.ZERO)
	if broken:
		m.verbs.absorb(w, 9999.0)
	else:
		w["t"] = 0.0
	C.ac.step(m, 0.03)
	var let_go := not b.has("on") and b.has("vy") and float(b.get("fuse", 0.0)) > 0.0
	T.teleport(Vector3(held.x - 3.0, home.y, held.z + 2.0))
	C.ac.step(m, 1.2)
	var ground_y: float = m.world.ground_at(held.x, held.z)
	var landed: float = (b.get("pos", held) as Vector3).y - ground_y
	var fell := landed < 0.5 and landed < held.y - ground_y
	var blasted: bool = K.rattles == rattles0 + 1 and C.ac.dmg(T) >= 10.0
	var goes := "breaks" if broken else "runs out"
	C.ok("Vex coin: when %s %s the coin drops to the ground and still blasts" % [what, goes],
			let_go and fell and blasted,
			"let go %s, %.2f m up, blasts %d, foe took %.0f" % [let_go, landed, K.rattles - rattles0, C.ac.dmg(T)])
	_clear(m, K)

## Her own team's wall (which blocks only enemies) lets the coin through: it does not stick to it.
func _own_wall(m: Match, P: Hunter, K: GunslingerKit, T: Hunter, home: Vector3, far: Vector3) -> void:
	T.teleport(far)
	P.teleport(home)
	C.ac.aim_at(P, home + Vector3(8.0, 0, 0))
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	var e := {"length": 3.0, "hp": 200.0, "time": 4.5, "move": true, "block": "enemy"}
	m.verbs.add_wall(P, home + Vector3(SPOT, 0, 0), Vector2(1, 0), e, 1.0)
	C.ac.tap(m, P)
	C.ac.step(m, 0.3)
	var b: Dictionary = K.burrs[-1] if not K.burrs.is_empty() else {}
	var x: float = (b["pos"] as Vector3).x - home.x if not b.is_empty() else 0.0
	C.ok("Vex coin: a wall of her own team lets it through", not b.is_empty() and not b.has("on") and x > SPOT + 1.0,
			"x %.2f" % x)
	_clear(m, K)

func _slide(w: Dictionary, by: float) -> void:
	w["a"] = (w["a"] as Vector2) + Vector2(by, 0)
	w["b"] = (w["b"] as Vector2) + Vector2(by, 0)

func _clear(m: Match, K: GunslingerKit) -> void:
	m.verbs.clear()
	C.ac.step(m, 1.2)
