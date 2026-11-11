extends RefCounted
## --camp-check: the camp monster leash (Mob.LEASH_M, docs/CAMP_PARITY.md). A skitter is pulled by a
## Hunter who backs away in a straight line, staying just inside its reach the whole way:
##   1. it never ends up more than LEASH_M (plus one lunge) from its camp;
##   2. past the leash it walks home and hits on the way don't turn it around;
##   3. it gets home with full health, and then it notices a Hunter in AGGRO_M again.

const DT := 1.0 / 60.0
const LUNGE_M := 2.6           # m: one lunge (12 m/s for 0.2 s) plus its body, the most it may overshoot
const RUN_M := 30.0            # m of clear ground the pull needs
const BACK_SPEED := 4.0        # m/s the Hunter backs away (slower than a skitter, so it keeps up)

var m: Match
var fails := 0
var n := 0

func ok(cond: bool, what: String) -> void:
	n += 1
	print("CAMP %-62s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond: fails += 1

func run(main: Node) -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	m.opts["god"] = true
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var lane := _clear_lane()
	ok(not lane.is_empty(), "found %d m of open ground for the pull" % int(RUN_M))
	if not lane.is_empty():
		_pull(lane[0], lane[1])
	print("CAMP DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## [start, direction] of a straight run of open, level-ish ground, or [] if none was found.
func _clear_lane() -> Array:
	var w := m.world
	for _try in 200:
		var at := w.random_ground()
		for i in 8:
			var dir := Vector2.RIGHT.rotated(TAU * i / 8.0)
			var clear := true
			var d := -2.0
			while clear and d <= RUN_M:
				var p := Vector2(at.x, at.z) + dir * d
				var level := absf(w.ground_at(p.x, p.y) - at.y) < 1.5
				clear = level and not w.is_void(p.x, p.y) and not w.is_block(p.x, p.y)
				d += 0.5
			if clear: return [at, dir]
	return []

func _ground(at: Vector3, dir: Vector2, d: float) -> Vector3:
	var p := Vector2(at.x, at.z) + dir * d
	return Vector3(p.x, m.world.ground_at(p.x, p.y), p.y)

func _pull(at: Vector3, dir: Vector2) -> void:
	var h: Hunter = m.hunters[0]
	for o in m.hunters:
		o.ctrl = "idle"
		if o != h: o.teleport(_ground(at, dir, -2.0) + Vector3(0, 0, 400.0))
	for k in m.kins.duplicate():
		m.kins.erase(k)
		k.queue_free()
	h.kin = null
	h.kin2 = null
	var mb := m.spawn_mob("skitter", at)
	mb.hp = mb.max_hp * 0.5
	at = mb.camp
	# it notices you and comes
	h.teleport(_ground(at, dir, 4.0))
	var t := 0.0
	while t < 2.0 and mb.st == "idle":
		m.step(DT)
		t += DT
	ok(mb.st != "idle", "a Hunter %.1f m off wakes it (AGGRO_M %.1f)" % [4.0, Mob.AGGRO_M])
	# back away, always a few metres in front of it, until it gives up
	var far := 0.0
	t = 0.0
	while t < 12.0 and not mb.homing:
		var back := Vector2(mb.pos.x - at.x, mb.pos.z - at.z).dot(dir) + 3.0
		h.teleport(_ground(at, dir, minf(back, RUN_M)))
		m.step(DT)
		t += DT
		far = maxf(far, mb.flat_dist(at))
	ok(mb.homing, "it gives up the chase (after %.1f s)" % t)
	t = 0.0
	while t < 1.0:
		m.step(DT)
		t += DT
		far = maxf(far, mb.flat_dist(at))
	var leash_txt := "it never gets past the leash: %.1f m from camp (LEASH_M %.1f)" % [far, Mob.LEASH_M]
	ok(far <= Mob.LEASH_M + LUNGE_M, leash_txt)
	# a hit on the way home doesn't turn it around
	mb.hurt(1.0, h, {"src": "test"})
	m.step(DT)
	ok(mb.homing and mb.tgt == null and mb.st == "idle", "a hit on the way home doesn't turn it around")
	h.teleport(_ground(at, dir, RUN_M) + Vector3(0, 0, 200.0))
	t = 0.0
	while t < 8.0 and mb.homing:
		m.step(DT)
		t += DT
	var home_txt := "it walks home (%.1f s, %.1f m off camp)" % [t, mb.flat_dist(at)]
	ok(not mb.homing and mb.flat_dist(at) < Mob.HOME_M + 0.5, home_txt)
	ok(is_equal_approx(mb.hp, mb.max_hp), "and is back to full health (%d / %d)" % [int(mb.hp), int(mb.max_hp)])
	h.teleport(_ground(at, dir, 4.0))
	t = 0.0
	while t < 2.0 and mb.st == "idle":
		m.step(DT)
		t += DT
	ok(mb.st != "idle", "home again, it notices a Hunter in reach")
