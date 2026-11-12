extends RefCounted
## --aim-near-check: the cursor on, under or within a body width of your own Hunter says nothing about a way
## to face (the source never spins the body when the cursor crosses the model). Sweeps the cursor across and
## around the body: inside the circle the aim direction must not move and the body must not turn more than
## 30 degrees in one tick; shots fired with the cursor inside it must go along the held aim.

const DT := 1.0 / 60.0
const STEP_DEG := 30.0       # the most the body may turn in one tick while the cursor is inside the circle
const FAN_DEG := 25.0        # a round's widest allowed miss of the held aim (the widest shotgun fan)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("AIMNEAR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _match(main: Node) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	for other in m.hunters:
		if other != m.player:
			other.ctrl = "idle"
			other.teleport(m.player.pos + Vector3(40, 0, 40))
	for i in 20:
		m.step(DT)
	return m

func _turn_deg(a: float, b: float) -> float:
	return absf(rad_to_deg(angle_difference(a, b)))

## One tick with the cursor at `off` from the body (flat, m). Returns the body's turn this tick, in degrees.
func _tick(m: Match, off: Vector2) -> float:
	var P: Hunter = m.player
	var before := P.face
	P.inp["aim"] = P.pos + Vector3(off.x, 0.9, off.y)
	m.step(DT)
	return _turn_deg(before, P.face)

## Cursor along a line past the body (z = `side`), x from -3 to 3 m at `step` m per tick.
func _sweep(m: Match, side: float, step: float, tag: String) -> void:
	var P: Hunter = m.player
	var circle := P.r * Hunter.AIM_MIN_BODIES
	var x := -3.0
	for i in 40:
		_tick(m, Vector2(x, side))
	var worst := 0.0
	var held := true
	var last := P.aim_dir()
	while x <= 3.0:
		var off := Vector2(x, side)
		var turn := _tick(m, off)
		var d := P.aim_dir()
		if off.length() <= circle:
			worst = maxf(worst, turn)
			held = held and d == last
		last = d
		x += step
	ok(held, "%s: the aim direction holds while the cursor is inside the circle" % tag)
	ok(worst <= STEP_DEG, "%s: body turns %.1f deg at most per tick inside the circle" % [tag, worst])

## Cursor jittering around the body, LMB held: where the rounds go.
func _jitter(m: Match, tag: String) -> void:
	var P: Hunter = m.player
	var circle := P.r * Hunter.AIM_MIN_BODIES
	for i in 20:
		_tick(m, Vector2(-3.0, 0.0))
	var hold := P.aim_dir()
	var worst_turn := 0.0
	var worst_shot := 0.0
	var rounds := 0
	P.inp["fire"] = true
	for i in 90:
		var a := float(i) * 2.4
		var off := Vector2(cos(a), sin(a)) * circle * (0.1 + 0.9 * float(i % 7) / 7.0)
		P.ammo = int(P.wpn.get("mag", 30))
		worst_turn = maxf(worst_turn, _tick(m, off))
		for s in m.shots:
			if s["by"] == P and not s.has("_seen"):
				s["_seen"] = true
				rounds += 1
				worst_shot = maxf(worst_shot, absf(rad_to_deg((s["vel"] as Vector2).angle_to(hold))))
	P.inp["fire"] = false
	print("AIMNEAR %s jitter: %d rounds, worst %.1f off the aim, turn %.1f deg" % [tag, rounds, worst_shot, worst_turn])
	ok(worst_turn <= STEP_DEG, "%s: jittering under the body never turns it %.0f deg a tick" % [tag, STEP_DEG])
	ok(rounds > 0 and worst_shot <= FAN_DEG, "%s: rounds fired from under the body hold the aim" % tag)

func run(main: Node) -> void:
	Save.no_write = true
	for side in [0.0, 0.1, 0.5]:
		for step in [0.05, 0.4]:
			var m := _match(main)
			_sweep(m, side, step, "sweep z=%.1f %.2f m/tick" % [side, step])
			m.queue_free()
			await main.get_tree().process_frame
	var m2 := _match(main)
	_jitter(m2, "default hero")
	m2.queue_free()
	await main.get_tree().process_frame
	print("AIMNEAR DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
