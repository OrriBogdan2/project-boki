extends RefCounted
## --time-trial-check: the Training Grounds' time trial. Ten gates, a start and a finish arch and the pad are
## built; the course asks for a dash, a wall kick, the pad and a glide (the kick tower can't be climbed with a
## plain jump, the glide tower only by the pad); a scripted run with real inputs goes start -> ten gates ->
## finish and sets this Hunter's best; a dash gate walked through doesn't count; a slower run keeps the best;
## a Hunter swap or a fall ends the run; a v21 save migrates to an empty best list. Prints TIMETRIALCHECK PASS/FAIL.

const DT := 1.0 / 60.0
const RUN_CAP := 120.0  # [s] a scripted run that takes longer has got stuck
const DASH_AT := 3.0  # [m] the scripted run dashes this far before a dash gate

var main: Node
var fails := 0
var n := 0


func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	printerr("TIMETRIALCHECK %-46s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d["time_trial"] = {}
	var m := Match.new()
	main.add_child(m)
	m.start(Match.arena_opts("gunslinger"))
	m.set_process(false)
	var t: TimeTrial = m.arena.grounds.trial
	_built(m, t)
	_heights(m, t)
	_full_run(m, t)
	_dash_gate(m, t)
	_slower_and_swap(m, t)
	_migrate()
	print("TIMETRIALCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()


func _built(m: Match, t: TimeTrial) -> void:
	var moves := {}
	for g in t.gates:
		moves[g.move] = true
	var placed := t.start != Vector3.INF and t.finish != Vector3.INF and t.pad_at != Vector3.INF
	ok("ten gates, start and finish arch, pad", t.gates.size() == 10 and placed, "%d gates" % t.gates.size())
	ok(
		"the gates ask for dash, kick, pad, glide",
		moves.has("dash") and moves.has("kick") and moves.has("pad") and moves.has("glide"),
		str(moves.keys())
	)
	var on_floor := [t.start, t.finish, t.pad_at].all(func(p): return m.world.island_id(p.x, p.z) == "floor")
	ok("the course is on the open floor", on_floor)


## The kick tower is four terraces (over a plain jump and mantle), the glide tower more than a kick reaches.
func _heights(m: Match, t: TimeTrial) -> void:
	var kick := _gate(t, "kick")
	var kick_top := m.world.ground_at(kick.at.x, kick.at.z)
	var glide_top := t.pad_land.y
	var cap := HunterMove.JUMP_TIERS * World.LEVEL + 0.05
	ok("kick tower is out of a plain jump's reach", kick_top > cap, "%.1f m vs %.1f" % [kick_top, cap])
	ok("glide tower is out of a wall kick's reach", glide_top > cap + World.LEVEL, "%.1f m" % glide_top)


func _gate(t: TimeTrial, move: String) -> TimeTrial.Gate:
	for g in t.gates:
		if g.move == move:
			return g
	return null


## Real inputs from behind the start arch to the finish: steer at the next gate, dash before a dash gate,
## jump and kick at the kick tower, step on the pad, glide once falling toward a glide gate.
func _full_run(m: Match, t_v: TimeTrial) -> void:
	var p: Hunter = m.player
	var t := _drive(m, t_v)
	var info := "gate %d, %.2f s" % [t_v.next_i, t_v.last_time]
	ok("a run with real inputs finishes all ten gates", t > 0.0 and not t_v.running, info)
	ok("the run used a wall kick", int(p.stats.get("wall_kicks", 0)) > 0, str(p.stats.get("wall_kicks", 0)))
	ok(
		"the finish is this Hunter's best",
		is_equal_approx(TimeTrial.best("gunslinger"), snappedf(t_v.last_time, 0.01)),
		"%.2f" % TimeTrial.best("gunslinger")
	)
	ok("another Hunter has no best yet", TimeTrial.best("thief") == 0.0)


## Drives one run; returns its time (0 when it didn't finish inside RUN_CAP).
func _drive(m: Match, t_v: TimeTrial) -> float:
	var p: Hunter = m.player
	var back := t_v.start - t_v.gates[0].at
	back.y = 0.0
	p.teleport(t_v.start + back.normalized() * 3.0)
	p.vel = Vector3.ZERO
	var t := 0.0
	var dashed := -1
	var was_on := false
	while t < RUN_CAP:
		for k in ["jump", "dash", "glide"]:
			p.inp[k] = false
		var g: TimeTrial.Gate = t_v.gates[t_v.next_i] if t_v.running and t_v.next_i < t_v.gates.size() else null
		var tgt := t_v.finish if t_v.running else t_v.start
		if g:
			tgt = t_v.pad_at if g.move == "pad" and p.pad.is_empty() and p.pos.y < g.at.y - 3.0 else g.at
		var to := Vector2(tgt.x - p.pos.x, tgt.z - p.pos.z)
		p.inp["move"] = to.normalized()
		if g and g.move == "dash" and p.grounded and to.length() < DASH_AT and dashed != t_v.next_i:
			p.inp["dash"] = true
			dashed = t_v.next_i
		if g and g.move == "kick" and p.pos.y < g.at.y - 1.5 and to.length() < 3.5:
			var falling := not p.grounded and p.vel.y <= 0.5
			p.inp["jump"] = p.grounded or (falling and p.wall_touch_t > 0.0)
		if g and g.move == "glide" and not p.grounded and p.pad.is_empty():
			p.inp["glide"] = true
		m.step(DT)
		t += DT
		was_on = was_on or t_v.running
		if was_on and not t_v.running:
			return t_v.last_time
	return 0.0


## A dash gate walked through doesn't count.
func _dash_gate(m: Match, t: TimeTrial) -> void:
	var p: Hunter = m.player
	var i := t.gates.find(_gate(t, "dash"))
	t.running = true
	t.run_arch = p.arch
	t.next_i = i
	var g: TimeTrial.Gate = t.gates[i]
	p.teleport(g.at - Vector3(0, TimeTrial.BODY_UP, 0))
	p.roll_t = 0.0
	t.tick(DT)
	ok("a dash gate walked through doesn't count", t.next_i == i)
	p.roll_t = 0.2
	t.tick(DT)
	ok("a dash gate dashed through counts", t.next_i == i + 1)
	t.stop()


## A slower time keeps the best; a Hunter swap and a fall each end a run.
func _slower_and_swap(m: Match, t: TimeTrial) -> void:
	var b := TimeTrial.best("gunslinger")
	ok("a slower run keeps the best", not TimeTrial.record("gunslinger", b + 5.0) and TimeTrial.best("gunslinger") == b)
	ok("a faster run takes it", TimeTrial.record("gunslinger", b - 1.0) and TimeTrial.best("gunslinger") < b)
	var p: Hunter = m.player
	t.running = true
	t.run_arch = p.arch
	m.arena.set_arch("thief")
	t.tick(DT)
	ok("a Hunter swap ends the run", not t.running and m.player.arch == "thief")
	t.running = true
	m.player.teleport(Vector3(60, -20, 25))
	m.arena.grounds.tick(DT)
	ok("a fall ends the run", not t.running)


func _migrate() -> void:
	var old := {"v": 21, "roster": []}
	var good := Save.migrate(old)
	var bests = old.get("time_trial", null)
	var empty: bool = bests is Dictionary and (bests as Dictionary).is_empty()
	ok("a v21 save gets an empty best list", good and int(old["v"]) == Save.VERSION and empty)
	ok("a fresh save has one", Save.fresh().get("time_trial", null) is Dictionary)
