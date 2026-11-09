extends RefCounted
## --hotpath-check: the per-step hot paths that were rewritten for speed still mean what the plain code
## meant. World.ground_at, is_block, occupy and los are compared with the slow one-call-per-tile versions
## on random points of the Training Area, and HunterTimers.tick counts every named timer down to zero.

var main: Node
var fails := 0

func ok(cond: bool, what: String) -> void:
	print("HOTPATH %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Game.goto("match", Match.arena_opts())
	while not (main.current is Match and (main.current as Match).is_processing()):
		await main.get_tree().process_frame
	var m: Match = main.current
	var w: World = m.world
	var rng := RandomNumberGenerator.new()
	rng.seed = 1108
	var bad_g := 0
	var bad_b := 0
	var bad_o := 0
	var bad_l := 0
	for i in 3000:
		var x := rng.randf_range(-2.0, w.w + 2.0)
		var z := rng.randf_range(-2.0, w.h + 2.0)
		var y := rng.randf_range(-2.0, 6.0)
		if w.ground_at(x, z) != _ref_ground(w, x, z): bad_g += 1
		if w.is_block(x, z) != _ref_block(w, x, z): bad_b += 1
		var r := rng.randf_range(0.2, 0.6)
		if w.occupy(x, z, r, y, i % 2 == 0) != _ref_occupy(w, x, z, r, y, i % 2 == 0): bad_o += 1
		var b := Vector3(x + rng.randf_range(-12.0, 12.0), y, z + rng.randf_range(-12.0, 12.0))
		if w.los(Vector3(x, y, z), b, y + 1.1) != _ref_los(w, Vector3(x, y, z), b, y + 1.1): bad_l += 1
	ok(bad_g == 0, "ground_at matches the plain tile read (%d of 3000 differ)" % bad_g)
	ok(bad_b == 0, "is_block matches (%d differ)" % bad_b)
	ok(bad_o == 0, "occupy matches the ring of ground_at calls (%d differ)" % bad_o)
	ok(bad_l == 0, "los matches is_block plus ground_at per sample (%d differ)" % bad_l)
	var h: Hunter = m.player
	h.sig_cd = 1.0
	h.coyote = 0.1
	h.phase_t = 0.0
	HunterTimers.tick(h, 0.25)
	var ticked := is_equal_approx(h.sig_cd, 0.75) and h.coyote == 0.0 and h.phase_t == 0.0
	ok(ticked, "HunterTimers: counts down and stops at zero")
	print("HOTPATH DONE %d failures" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

func _ref_ground(w: World, x: float, z: float) -> float:
	var ix := int(floor(x))
	var iz := int(floor(z))
	if not w.inb(ix, iz) or w.kind[w.idx(ix, iz)] == World.T_VOID:
		return World.VOID
	if w.stairs.has(w.idx(ix, iz)):
		return w.ground_at(x, z)           # (the stairs blend is the one path the fast code still calls)
	return w.level[w.idx(ix, iz)] * World.LEVEL

func _ref_block(w: World, x: float, z: float) -> bool:
	var ix := int(floor(x))
	var iz := int(floor(z))
	return w.inb(ix, iz) and w.kind[w.idx(ix, iz)] == World.T_BLOCK

func _ref_occupy(w: World, x: float, z: float, r: float, y: float, guard: bool) -> float:
	var bt := w._block_hit(x, z, r * World.BLOCK_BODY - World.BLOCK_SKIN, y)
	if bt > 0.0:
		return bt
	var worst := 0.0
	var hit := false
	for o in World.OCC_RING:
		var g := w.ground_at(x + o.x * r, z + o.y * r)
		if g > y + World.STEP:
			worst = maxf(worst, g)
			hit = true
	if hit:
		return maxf(worst, World.WALL_MIN)
	if guard and w.ground_at(x, z) <= World.VOID + 1.0:
		return -1.0
	return 0.0

func _ref_los(w: World, a: Vector3, b: Vector3, y: float) -> bool:
	var d := Vector2(b.x - a.x, b.z - a.z)
	var n := int(d.length() / 0.4) + 1
	for i in range(1, n):
		var t := float(i) / n
		var px := a.x + d.x * t
		var pz := a.z + d.y * t
		if w.is_block(px, pz) and w.ground_at(px, pz) + World.BLOCK_H > y:
			return false
		if w.ground_at(px, pz) > y + 0.2:
			return false
	return true
