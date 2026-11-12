extends RefCounted
## --base-check: B, basing to a teammate (BaseWheel picks, BaseRecall channels).
##  1. Holding B opens the wheel round the cursor; with one teammate it shows just them.
##  2. Letting go in the middle (the dead zone) cancels: no channel.
##  3. Pointing at a slice and letting go starts the CHANNEL_S channel to that teammate on the next fixed
##     step, with the circle (telegraph) under them.
##  4. A clean channel lands beside them after CHANNEL_S (not before), weakened, on the full cooldown.
##  5. Damage 2 s in cancels it: nothing kept, the telegraph gone, the short lockout.
##  6. Moving cancels it too; bots go through the same start and the same damage cancel.
## Never touches the save.

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("BCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _still(m: Match, p: Hunter, secs: float) -> void:
	var t := 0.0
	while t < secs - 1e-4:
		p.inp["move"] = Vector2.ZERO
		m.step(Match.DT)
		t += Match.DT


## A spot on solid ground about `r` m from `at` (the island's edge may be anywhere).
func _solid_near(m: Match, at: Vector3, r: float) -> Vector3:
	for k in 16:
		var q := at + Vector3(cos(TAU * k / 16.0), 0, sin(TAU * k / 16.0)) * r
		if not m.world.is_void(q.x, q.z) and not m.world.is_block(q.x, q.z) \
				and absf(m.world.ground_at(q.x, q.z) - at.y) < 1.5:
			return Vector3(q.x, m.world.ground_at(q.x, q.z), q.z)
	return at + Vector3(3, 0, 0)


## Holds B, points `delta` px from where the wheel opened, lets go; then one fixed step applies the pick.
func _wheel_pick(m: Match, p: Hunter, delta: Vector2) -> void:
	Input.action_press("base")
	BaseWheel.poll(p, 0.016, false)
	var w: Dictionary = p.inp.get("bwheel", {})
	if not w.is_empty():
		w["o"] = p.get_viewport().get_mouse_position() - delta     # the cursor ends up `delta` from the centre
	BaseWheel.poll(p, 0.016, false)
	Input.action_release("base")
	BaseWheel.poll(p, 0.016, false)
	p.inp["move"] = Vector2.ZERO
	m.step(Match.DT)


func run(main: Node) -> void:
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "no_drop": true, "seed": 77, "autoplay": true, "big": false})
	m.set_process(false)
	var p: Hunter = m.player
	p.ctrl = "local"
	var mate := BaseRecall.target(m, p)
	ok(mate != null, "a teammate to base to")
	if mate == null:
		main.get_tree().quit(1)
		return
	mate.ctrl = "idle"      # the landing is measured beside the mate, not where a wandering mate strolls off to
	_still(m, p, 0.5)
	# 1-2: the wheel opens on hold; the dead zone cancels
	Input.action_press("base")
	BaseWheel.poll(p, 0.016, false)
	ok(BaseWheel.is_open(p), "holding B opens the wheel")
	ok(BaseWheel.is_open(p) and (p.inp["bwheel"]["mates"] as Array) == [mate], "one teammate: the wheel shows them")
	BaseWheel.poll(p, 0.016, false)
	Input.action_release("base")
	BaseWheel.poll(p, 0.016, false)
	m.step(Match.DT)
	ok(not BaseWheel.is_open(p) and p.base_t <= 0.0, "letting go in the dead zone cancels (no channel)")
	# slice picking with several teammates: straight up is slice 0, the rest clockwise
	BaseWheel.open(p, Vector2(400, 300), [mate, mate, mate])
	BaseWheel.update(p, Vector2(400, 180), 0.016)
	var s_up := int(p.inp["bwheel"]["sel"])
	BaseWheel.update(p, Vector2(520, 380), 0.016)
	var s_right := int(p.inp["bwheel"]["sel"])
	BaseWheel.update(p, Vector2(405, 302), 0.016)
	ok(s_up == 0 and s_right == 1 and int(p.inp["bwheel"]["sel"]) == -1, "slices: up 0, lower right 1, centre none")
	p.inp.erase("bwheel")
	# 3: a slice starts the channel
	_wheel_pick(m, p, Vector2(0, -120))
	ok(p.base_t > BaseRecall.CHANNEL_S - 0.05 and p.base_to == mate, "letting go on a slice starts the channel")
	ok(p.base_tele != null and is_instance_valid(p.base_tele), "the circle under the teammate shows")
	# 4: completes at CHANNEL_S
	_still(m, p, BaseRecall.CHANNEL_S - 0.2)
	ok(p.base_t > 0.0, "still channelling at %.1f s" % (BaseRecall.CHANNEL_S - 0.2))
	_still(m, p, 0.3)
	var near := p.flat_dist(mate) < 2.5
	ok(near and p.base_t <= 0.0, "lands beside the teammate after %.1f s" % BaseRecall.CHANNEL_S)
	ok(absf(p.weak_t - BaseRecall.WEAK_S) < 0.2 and m.dmg_mult(p) < 1.0, "arrives weakened")
	ok(absf(p.base_cd - BaseRecall.CD_S) < 0.2, "on the full cooldown")
	ok(p.base_tele == null, "the circle is gone")
	# 5: damage at 2 s cancels, nothing kept
	p.base_cd = 0.0
	p.weak_t = 0.0
	p.teleport(_solid_near(m, mate.pos, 8.0))
	_still(m, p, 0.5)
	_wheel_pick(m, p, Vector2(120, 0))
	ok(p.base_t > 0.0, "second channel started")
	_still(m, p, 2.0)
	ok(absf(p.base_t - (BaseRecall.CHANNEL_S - 2.0)) < 0.1, "2 s in: %.2f s left" % p.base_t)
	var at := p.pos
	p.hurt(5.0, null, {"src": "test"})
	ok(p.base_t <= 0.0 and p.base_to == null and p.base_tele == null, "a hit at 2 s cancels the channel")
	ok(absf(p.base_cd - BaseRecall.LOCKOUT_S) < 0.05, "the short lockout after an interrupt")
	_still(m, p, BaseRecall.CHANNEL_S)
	ok(p.pos.distance_to(at) < 1.0, "no partial progress: never teleports")
	# 6: moving cancels; bots use the same rules
	p.base_cd = 0.0
	BaseRecall.start(p, mate)
	p.inp["move"] = Vector2(1, 0)
	m.step(Match.DT)
	p.inp["move"] = Vector2.ZERO
	ok(p.base_t <= 0.0, "moving cancels")
	mate.base_cd = 0.0
	BaseRecall.start(mate, BaseRecall.target(m, mate))
	ok(mate.base_t > 0.0 and mate.base_to == p, "a bot starts the same channel")
	mate.hurt(5.0, null, {"src": "test"})
	ok(mate.base_t <= 0.0 and mate.base_cd > 0.0, "and a hit cancels it the same way")
	m.queue_free()
	print("BCHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
