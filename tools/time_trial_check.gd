extends RefCounted
## --time-trial-check: the Training Grounds' time trial. Ten gates, a start and a finish arch and the pad are
## built; the course asks for a dash, a wall kick, the pad and a glide (the kick tower can't be climbed with a
## plain jump, the glide tower only by the pad); a scripted run with real inputs goes start -> ten gates ->
## finish and sets this Hunter's best; a dash gate walked through doesn't count; a slower run keeps the best;
## a Hunter swap or a fall ends the run; a v13 save migrates to an empty best list. Prints TIMETRIALCHECK PASS/FAIL.

const DT := 1.0 / 60.0
const RUN_CAP := 120.0          # [s] a scripted run that takes longer has got stuck
const DASH_AT := 3.0            # [m] the scripted run dashes this far before a dash gate

var main: Node
var fails := 0
var n := 0

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	printerr("TIMETRIALCHECK %-46s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d["time_trial"] = {}
	var m := Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts("gunslinger"))
	m.set_process(false)
	var T: TimeTrial = m.arena.grounds.trial
	_built(m, T)
	_heights(m, T)
	_full_run(m, T)
	_dash_gate(m, T)
	_slower_and_swap(m, T)
	_migrate()
	print("TIMETRIALCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()

func _built(m: Match, T: TimeTrial) -> void:
	var moves := {}
	for g in T.gates:
		moves[g.move] = true
	var placed := T.start != Vector3.INF and T.finish != Vector3.INF and T.pad_at != Vector3.INF
	ok("ten gates, start and finish arch, pad", T.gates.size() == 10 and placed, "%d gates" % T.gates.size())
	ok("the gates ask for dash, kick, pad, glide", moves.has("dash") and moves.has("kick") and moves.has("pad")
		and moves.has("glide"), str(moves.keys()))
	var on_floor := [T.start, T.finish, T.pad_at].all(func(p): return m.world.island_id(p.x, p.z) == "floor")
	ok("the course is on the open floor", on_floor)

## The kick tower is four terraces (over a plain jump and mantle), the glide tower more than a kick reaches.
func _heights(m: Match, T: TimeTrial) -> void:
	var kick := _gate(T, "kick")
	var kick_top := m.world.ground_at(kick.at.x, kick.at.z)
	var glide_top := T.pad_land.y
	var cap := Hunter.JUMP_V * Hunter.JUMP_V / (2.0 * Hunter.H_GRAV) + Hunter.MANTLE_REACH
	ok("kick tower is out of a plain jump's reach", kick_top > cap, "%.1f m vs %.1f" % [kick_top, cap])
	ok("glide tower is out of a wall kick's reach", glide_top > WallMoves.HOP_CLIMB_CAP + cap, "%.1f m" % glide_top)

func _gate(T: TimeTrial, move: String) -> TimeTrial.Gate:
	for g in T.gates:
		if g.move == move:
			return g
	return null

## Real inputs from behind the start arch to the finish: steer at the next gate, dash before a dash gate,
## jump and kick at the kick tower, step on the pad, glide once falling toward a glide gate.
func _full_run(m: Match, T: TimeTrial) -> void:
	var P: Hunter = m.player
	var t := _drive(m, T)
	var info := "gate %d, %.2f s" % [T.next_i, T.last_time]
	ok("a run with real inputs finishes all ten gates", t > 0.0 and not T.running, info)
	ok("the run used a wall kick", int(P.stats.get("wall_kicks", 0)) > 0, str(P.stats.get("wall_kicks", 0)))
	ok("the finish is this Hunter's best", is_equal_approx(TimeTrial.best("gunslinger"), snappedf(T.last_time, 0.01)),
		"%.2f" % TimeTrial.best("gunslinger"))
	ok("another Hunter has no best yet", TimeTrial.best("thief") == 0.0)

## Drives one run; returns its time (0 when it didn't finish inside RUN_CAP).
func _drive(m: Match, T: TimeTrial) -> float:
	var P: Hunter = m.player
	var back := (T.start - T.gates[0].at)
	back.y = 0.0
	P.teleport(T.start + back.normalized() * 3.0)
	P.vel = Vector3.ZERO
	var t := 0.0
	var dashed := -1
	var was_on := false
	while t < RUN_CAP:
		for k in ["jump", "dash", "glide"]:
			P.inp[k] = false
		var g: TimeTrial.Gate = T.gates[T.next_i] if T.running and T.next_i < T.gates.size() else null
		var tgt := T.finish if T.running else T.start
		if g:
			tgt = T.pad_at if g.move == "pad" and P.pad.is_empty() and P.pos.y < g.at.y - 3.0 else g.at
		var to := Vector2(tgt.x - P.pos.x, tgt.z - P.pos.z)
		P.inp["move"] = to.normalized()
		if g and g.move == "dash" and P.grounded and to.length() < DASH_AT and dashed != T.next_i:
			P.inp["dash"] = true
			dashed = T.next_i
		if g and g.move == "kick" and P.pos.y < g.at.y - 1.5 and to.length() < 3.5:
			var falling := not P.grounded and P.vel.y <= 0.5
			P.inp["jump"] = P.grounded or (falling and P.wall_touch_t > 0.0)
		if g and g.move == "glide" and not P.grounded and P.pad.is_empty():
			P.inp["glide"] = true
		m.step(DT)
		t += DT
		was_on = was_on or T.running
		if was_on and not T.running:
			return T.last_time
	return 0.0

## A dash gate walked through doesn't count.
func _dash_gate(m: Match, T: TimeTrial) -> void:
	var P: Hunter = m.player
	var i := T.gates.find(_gate(T, "dash"))
	T.running = true
	T.run_arch = P.arch
	T.next_i = i
	var g: TimeTrial.Gate = T.gates[i]
	P.teleport(g.at - Vector3(0, TimeTrial.BODY_UP, 0))
	P.roll_t = 0.0
	T.tick(DT)
	ok("a dash gate walked through doesn't count", T.next_i == i)
	P.roll_t = 0.2
	T.tick(DT)
	ok("a dash gate dashed through counts", T.next_i == i + 1)
	T.stop()

## A slower time keeps the best; a Hunter swap and a fall each end a run.
func _slower_and_swap(m: Match, T: TimeTrial) -> void:
	var b := TimeTrial.best("gunslinger")
	ok("a slower run keeps the best", not TimeTrial.record("gunslinger", b + 5.0) and TimeTrial.best("gunslinger") == b)
	ok("a faster run takes it", TimeTrial.record("gunslinger", b - 1.0) and TimeTrial.best("gunslinger") < b)
	var P: Hunter = m.player
	T.running = true
	T.run_arch = P.arch
	m.arena.set_arch("thief")
	T.tick(DT)
	ok("a Hunter swap ends the run", not T.running and m.player.arch == "thief")
	T.running = true
	m.player.teleport(Vector3(60, -20, 25))
	m.arena.grounds.tick(DT)
	ok("a fall ends the run", not T.running)

func _migrate() -> void:
	var old := {"v": 13, "roster": []}
	var good := Save.migrate(old)
	var bests = old.get("time_trial", null)
	var empty: bool = bests is Dictionary and (bests as Dictionary).is_empty()
	ok("a v13 save gets an empty best list", good and int(old["v"]) == Save.VERSION and empty)
	ok("a fresh save has one", Save.fresh().get("time_trial", null) is Dictionary)
