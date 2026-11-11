extends RefCounted
## --parity-bench-check: the parity bench panel (ParityBench) in the Training Area. The bar has a Bench
## button, the panel opens and closes, it reads the dummy you hit (damage per second, last hit), the
## crowd control it is under with its time left, and how far and how long the last knock moved it, and
## Reset clears it. A real match, the tutorial and the duel room have no bench.

var bad := 0
var _ended_at := Vector3.INF     # where the dummy stood when its knock ended
const DT := 1.0 / 60.0
const OPTS := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
const HIT := 200.0         # damage of the test hit
const STUN := 1.0          # s, stun of the test hit
const KNOCK := 4.0         # the test hit's shove, in its own direction (a short slide)
const CLEAR := 4.0         # m, the shove's way must have solid ground and nobody in it this far

func ok(cond: bool, what: String) -> void:
	print("PARITYBENCH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	var tree := main.get_tree()
	Save.no_write = true
	var d := Save.fresh()
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["cls"] = "medium"
	d["arch"] = "gunslinger"
	d["classes"] = ClassUnlock.legacy()
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	await m.start(OPTS.duplicate().merged({"training": true, "practice": true}))
	m.set_process(false)
	for i in 5: await tree.process_frame
	_bench(m)
	m.queue_free()
	await tree.process_frame
	for area in [{"tutorial": true}, Match.duel_opts()]:
		var o: Dictionary = OPTS.duplicate()
		o.merge(area, true)
		var other := Match.new()
		main.add_child(other)
		await other.start(o)
		other.set_process(false)
		var where := "the tutorial" if area.has("tutorial") else "the duel room"
		ok(ParityBench.of(other) == null, "no bench in " + where)
		other.queue_free()
		await tree.process_frame
	var rm := Match.new()
	main.add_child(rm)
	await rm.start({"teams": 2, "squad": 1, "tier": 0, "seed": 77, "no_drop": true})
	rm.set_process(false)
	ok(ParityBench.of(rm) == null, "a real match has no bench")
	rm.queue_free()
	print("PARITYBENCH DONE, failures: %d" % bad)
	tree.quit()

## Steps the match and the bench; remembers where the dummy was the moment its knock ended.
func _step(m: Match, b: ParityBench, secs: float) -> void:
	var t := 0.0
	while t < secs:
		var was := b.knocking
		m.step(DT)
		b._process(DT)
		if was and not b.knocking:
			_ended_at = b.target.pos
		t += DT

## A direction from the dummy with solid ground and no other body CLEAR metres ahead.
func _clear_dir(m: Match, D: Hunter) -> Vector2:
	for i in 16:
		var dir := Vector2.from_angle(TAU * i / 16.0)
		var at := Vector3(D.pos.x + dir.x * CLEAR, 0.0, D.pos.z + dir.y * CLEAR)
		var solid: bool = not m.world.is_void(at.x, at.z) and not m.world.is_block(at.x, at.z)
		var level: bool = absf(m.world.ground_at(at.x, at.z) - D.pos.y) < 0.4
		var crowded: bool = m.player.pos.distance_to(at) < 2.0
		for dm in m.arena.dummies:
			crowded = crowded or (dm["h"] != D and (dm["h"] as Hunter).pos.distance_to(at) < 2.0)
		if solid and level and not crowded:
			return dir
	return Vector2.ZERO

func _bench(m: Match) -> void:
	var pr := Practice.of(m)
	var b := ParityBench.of(m)
	ok(pr != null and b != null and pr.bar_btns.has("bench"), "the Training Area bar has a Bench button")
	if b == null or pr == null:
		return
	ok(not b.is_open(), "the bench starts closed")
	(pr.bar_btns["bench"] as Button).pressed.emit()
	ok(b.is_open(), "its button opens the panel")
	ok(b.lines().size() == 1, "nothing selected before a hit: %s" % str(b.lines()))
	var D: Hunter = m.arena.dummies[0]["h"]
	var dir := _clear_dir(m, D)
	ok(dir != Vector2.ZERO, "the test dummy has a clear way to be shoved")
	var from := D.pos
	var dealt := D.hurt(HIT, m.player, {"kb": dir * KNOCK, "stun": STUN})
	_step(m, b, 0.1)
	ok(b.target == D, "the dummy that was hit is selected")
	ok(dealt > 0.0 and is_equal_approx(float(m.arena.dummies[0]["last"]), dealt), "last hit is %.1f" % dealt)
	ok(b.lines()[1] == "Last hit  %d" % int(round(dealt)), "last hit reads %s" % b.lines()[1])
	var dps := Arena.dps_of(m.arena.dummies[0]["hits"], m.time)
	ok(dps > 0.0 and b.lines()[0] == "DPS  %d" % int(round(dps)), "rolling DPS reads %s" % b.lines()[0])
	var left := b.cc_until - m.time
	ok(b.cc_kind == "stun" and absf(left - (STUN - 0.1)) < 0.05, "stun, about 0.9 s left: " + b.lines()[2])
	_step(m, b, 0.5)
	ok(absf((b.cc_until - m.time) - (STUN - 0.6)) < 0.05, "the time left counts down: %s" % b.lines()[2])
	_step(m, b, 1.0)
	ok(b.lines()[2] == "CC  none", "the stun is over: %s" % b.lines()[2])
	var moved := Vector2(_ended_at.x - from.x, _ended_at.z - from.z).length()
	ok(not b.knocking and b.knock_time > 0.0 and b.knock_dist > 0.0, "a knock was read: %s" % b.lines()[3])
	ok(absf(b.knock_dist - moved) < 0.3, "knock %.2f m matches the dummy's move (%.2f m)" % [b.knock_dist, moved])
	b.reset()
	var cleared: bool = b.target == null and b.lines().size() == 1 and float(m.arena.dummies[0]["total"]) == 0.0
	ok(cleared, "reset clears the readout and the dummy's record")
	b.toggle()
	ok(not b.is_open(), "the button closes the panel")
