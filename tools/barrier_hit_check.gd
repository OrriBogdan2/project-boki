extends "res://tools/hero_pair_check.gd"
## --barrier-hit-check [--shots-dir=<dir>]: a shot into Albert's front shield (bulwark), a Tenzo rock (dolm) and
## Neve's Rimewall (rimewright) each spawns exactly one hit ripple (scripts/combat/barrier_ripple.gd) on the
## barrier's face, in that barrier's colour; the hit that breaks it is bigger; a shot at a Hunter spawns none.
## The same hit reads as blocked (Juice.blocked): one deflect spark in the barrier's colour and one metallic tick,
## and no damage hit (no hit event, no hurt flash on the owner).
## With --shots-dir, a screenshot of each plain and breaking hit (needs a renderer).

const SHOT_AT := 0.07      # s after the hit: the ring is spreading, the flash still lit
var shots_dir := ""

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): shots_dir = a.substr(12)
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
		if main.get("fade") != null:
			await main.fade.reveal(0.01)      # lift the boot splash (logo fade too), or every shot is the logo
	await _albert()
	await _tenzo()
	await _neve()
	print("PAIRCHECK barrier hits DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _albert() -> void:
	var r := setup("bulwark", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, 0.4, func(): P.inp["sec_hold"] = true)
	var wall: Dictionary = (P.ak as BulwarkKit).wall
	ok("albert: front shield raised", not wall.is_empty() and m.verbs.walls.has(wall))
	await _probe("albert", m, T, wall, "albert")

func _tenzo() -> void:
	var r := setup("dolm", 9.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	m.spawn_shot(T, P.pos + Vector3(2.0, 0.95, 0), Vector2(-30, 0), 20.0, 0.5, 0.15, Color.RED, {})
	step(m, 0.3)
	ok("tenzo: a shot that hits a Hunter makes no barrier ripple", _rings(m).is_empty(), "%d" % _rings(m).size())
	P.ak.cd["e"] = 0.0
	P.inp["aim"] = home + Vector3(3.4, 0.9, 0)
	P.ak.use_e()
	step(m, 1.0)
	var rs := rocks(m)
	ok("tenzo: Stone Row raised", rs.size() == 3, "rocks %d" % rs.size())
	await _probe("tenzo", m, T, rs[1], "rock")

func _neve() -> void:
	var r := setup("rimewright", 14.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	P.ak.cd["e"] = 0.0
	P.inp["aim"] = home + Vector3(6.0, 0.9, 0)
	P.ak.use_e()
	step(m, 1.6)
	ok("neve: Rimewall raised", m.verbs.walls.size() == 1, "walls %d" % m.verbs.walls.size())
	await _probe("neve", m, T, m.verbs.walls[0], "rimewall")

## One shot into `wall` (spawned by T, 3m past its middle, flying at it): one ripple in the wall's colour; then
## the wall nearly gone, a second shot that breaks it: one bigger ripple.
func _probe(who: String, m: Match, T: Hunter, wall: Dictionary, tag: String) -> void:
	var col: Color = wall["col"]
	var ticks: Array = []
	var hits: Array = []
	var on_tick := func(n: String, _at, _db, _pitch) -> void: if n == Juice.BLOCK_TICK: ticks.append(n)
	var on_hit := func(_by, _target, _d, _tags) -> void: hits.append(1)
	Sfx.played.connect(on_tick)
	CombatBus.hit_landed.connect(on_hit)
	var plain := _shoot(m, T, wall)
	step(m, SHOT_AT)
	Sfx.played.disconnect(on_tick)
	CombatBus.hit_landed.disconnect(on_hit)
	var owner_h: Ent = wall["by"]
	ok("%s: it reads as blocked, a metallic tick" % who, ticks.size() == 1, "%d ticks" % ticks.size())
	ok("%s: it reads as blocked, a deflect spark in the barrier's colour" % who, _sparked(m, col), "no spark")
	ok("%s: it is no damage hit" % who, hits.is_empty() and owner_h.flash_t <= 0.0,
			"%d hit events, flash %.2f" % [hits.size(), owner_h.flash_t])
	var rings := _rings(m)
	ok("%s: a shot into the barrier spawns one ripple" % who, rings.size() == 1 and plain, "%d rings" % rings.size())
	if rings.size() == 1:
		var c: Color = (rings[0].material_override as ShaderMaterial).get_shader_parameter("color")
		var info := "hue %.2f vs %.2f" % [c.h, col.h]
		ok("%s: the ripple wears the barrier's colour" % who, absf(c.h - col.h) < 0.06, info)
	var small := _size(rings)
	await _snap(m, tag + "_hit")
	step(m, 0.6)
	ok("%s: the ripple is gone after it spreads" % who, _rings(m).is_empty(), "%d" % _rings(m).size())
	wall["hp"] = 1.0
	_shoot(m, T, wall)
	step(m, SHOT_AT)
	var big := _size(_rings(m))
	var stronger := not m.verbs.walls.has(wall) and big > small * 1.5
	ok("%s: the hit that breaks it is stronger" % who, stronger, "%.2f vs %.2f" % [big, small])
	await _snap(m, tag + "_break")
	await done(m)                   # one match on screen at a time

## Fired along x at the wall's middle from the far side; steps until the wall takes it. Whether it did.
func _shoot(m: Match, T: Hunter, wall: Dictionary) -> bool:
	var mid: Vector2 = ((wall["a"] as Vector2) + (wall["b"] as Vector2)) * 0.5
	var hp0: float = wall["hp"]
	var from := Vector3(mid.x + 4.0, float(wall["y"]) + 1.0, mid.y)
	m.spawn_shot(T, from, Vector2(-30, 0), 20.0, 0.5, 0.15, Color.RED, {})
	for i in 30:
		m.step(DT)
		if wall["hp"] != hp0:
			return true
	return false

## Is a deflect spark in `col`'s hue (the blocker's) still flying?
func _sparked(m: Match, col: Color) -> bool:
	return m.fx.sparks.any(func(p: CPUParticles3D): return p.emitting and absf(p.color.h - col.h) < 0.06)

func _rings(m: Match) -> Array:
	return m.verbs.ripple.get_children().filter(func(c): return c.visible)

func _size(rings: Array) -> float:
	return (rings[0] as Node3D).basis.get_scale().x if not rings.is_empty() else 0.0

func _snap(m: Match, tag: String) -> void:
	if shots_dir == "":
		return
	var rings := _rings(m)
	m.cam.snap(rings[0].global_position if not rings.is_empty() else m.player.pos)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(shots_dir.path_join("barrier_%s.png" % tag))
