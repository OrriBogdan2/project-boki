extends "res://tools/archetype_check.gd"
## --miss-fx-check: a missed projectile ends visibly (MissFx). For each of the 12 kits a shot of their LMB
## kind (a weapon bullet) and of their RMB kind (an ability shot) is fired into a cliff face and into open air:
## each makes one pooled puff in the kit's colour, the wall one small and solid, the range one wider and
## fainter. A hit makes none, a stage-owned look makes none, and a hundred misses in a row keep the pool at its
## cap and make no new node. Prints AKCHECK lines.

const SHOT_V := 20.0           # m/s the test shots fly at
const AIR_S := 0.3             # s of life for an open-air shot
const SPAM := 100              # misses in a row for the pool-cap check

var m: Match
var P: Hunter
var fxd: DJFx
var wall_at := Vector3.ZERO

func run(main_node: Node) -> void:
	main = main_node
	main_node.set_meta("miss_fx_check", self)
	var r := setup("gunslinger", 14.0)
	m = r[0]
	P = r[1]
	var tgt: Hunter = r[2]
	tgt.teleport(Vector3(0, 0, 0) + r[4] + Vector3(0, 0, 9.0))
	fxd = DJFx.of(m)
	fxd.prewarm(P.pos)
	var warm_made := fxd.made
	var home: Vector3 = r[4]
	var lv: int = r[5]
	for dz in range(-2, 3):
		var i: int = m.world.idx(int(floor(home.x)) + 6, int(floor(home.z)) + dz)
		m.world.level[i] = lv + 3
	wall_at = home + Vector3(5.0, 0.9, 0)
	for id in Arch.ids():
		P.set_arch(id)
		var col := MissFx.colour_of(P)
		for kind in ["weapon", "abil"]:
			var extra := {} if kind == "weapon" else {"src": "abil"}
			var w := _fire(home, 1.0, extra)
			var wall_ok := w.size() == 1 and _col(w[0]) == Color(col, 1.0)
			wall_ok = wall_ok and is_equal_approx(_size(w[0]), MissFx.WALL_SIZE)
			ok("%s %s into a wall: one puff, small, in the kit colour" % [id, kind], wall_ok, str(w.size()))
			var a := _fire(home, -1.0, extra)
			var air_ok := a.size() == 1 and is_equal_approx(_size(a[0]), MissFx.RANGE_SIZE)
			air_ok = air_ok and is_equal_approx(_col(a[0]).a, MissFx.RANGE_ALPHA)
			ok("%s %s into open air: one wider, fainter puff" % [id, kind], air_ok, str(a.size()))
	m.fx.own_look = true
	var owned := _fire(home, 1.0, {})
	m.fx.own_look = false
	ok("a stage-owned look draws no puff", owned.is_empty())
	tgt.teleport(home + Vector3(3.0, 0, 0))
	_clear()
	m.spawn_shot(P, home + Vector3(0, 0.9, 0), Vector2(SHOT_V, 0), 1.0, 2.0, 0.2, Color.WHITE, {})
	step(m, 0.4)
	ok("a shot that hits draws no miss puff", fxd.live.is_empty())
	_clear()
	for i in SPAM:
		_fire(home, 1.0 if i % 2 == 0 else -1.0, {})
	var capped := fxd.made == warm_made and fxd.live.size() <= DJFx.POOL_CAP
	var info := "%d made, %d live" % [fxd.made, fxd.live.size()]
	ok("%d misses: the pool stays at its cap, no node made" % SPAM, capped, info)
	print("AKCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Fires one shot east from `home` (into the cliff when wall >= 0, with a short life into the air otherwise),
## runs the match until it ends and returns the puffs it made.
func _fire(home: Vector3, wall: float, extra: Dictionary) -> Array:
	_clear()
	var life := 2.0 if wall >= 0.0 else AIR_S
	var at := home + Vector3(0, 0.9, 0) if wall >= 0.0 else home + Vector3(-6, 0.9, 6)
	var v := Vector2(SHOT_V, 0) if wall >= 0.0 else Vector2(SHOT_V * 0.5, 0)
	m.spawn_shot(P, at, v, 1.0, life, 0.2, Color.WHITE, extra)
	step(m, 0.6 if wall >= 0.0 else AIR_S + 0.1)
	return fxd.live.duplicate()

func _clear() -> void:
	for e in fxd.live:
		(e["node"] as Node3D).visible = false
	fxd.live.clear()

func _col(e: Dictionary) -> Color:
	return (e["mat"] as ShaderMaterial).get_shader_parameter("color")

func _size(e: Dictionary) -> float:
	return (e["s0"] as Vector3).x
