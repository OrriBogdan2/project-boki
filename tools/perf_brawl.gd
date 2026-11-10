extends RefCounted
## --perf-bench --bench-brawl: the fight-hitch load (decision 2026-11-08: no frame over 50 ms after
## warm-up). Ten trios of bots on the Hollow Crown, everyone pulled into one brawl round the Crown,
## every Boki thrown out and every slot pressed in turn (E, right click, C, both gloves, dash, R) with
## a full bond meter, nobody dying so the load holds. Each frame is timed; a frame over SPIKE_MS
## prints the step and visuals sections it spent most in, the nodes that entered the tree and the
## pipelines compiled in it. Ends with p50 / p99 / max and the spike counts.
##   jobq submit --needs gpu --tree <tree> -- --perf-bench --bench-brawl [--bench-secs=40]

const DT := 1.0 / 60.0
const SETTLE := 3.0        # s after the match starts before the brawl is called (the drop settles)
const SPIKE_MS := 33.0     # a frame longer than this is a spike (two frames at 60 fps)
const BUDGET_MS := 50.0    # the decision's line
const PRESS_GAP := 0.35    # s between one bot's slot presses
const PRESSES := ["sig", "sec", "kin_ab", "gear1", "gear2", "dash", "ult"]
const RING := 9.0          # m: radius of the circle the trios are set out on

var bench                  # the PerfBench that runs this (frame rows, node counter)
var gloves: Array = []     # every active glove id, handed out two per bot

func run(b, main: Node, secs: float) -> void:
	bench = b
	for id in Gear.ALL:
		if Gear.active(String(id)): gloves.append(String(id))
	var o := Match.demo_opts()
	o.merge({"map": "hollowcrown", "teams": 10, "squad": 3, "total": 30, "god": true, "no_drop": true,
		"autoplay": true, "seed": 4101}, true)
	o.erase("demo_match")
	o.erase("fresh_t")
	o.erase("live_lair")
	Game.goto("match", o)
	var m: Match = null
	while m == null:
		await main.get_tree().process_frame
		var cur = main.current
		if cur is Match and (cur as Match).is_processing() and (cur as Match).hud != null:
			m = cur
	m.set_process(false)
	main.get_tree().node_added.connect(bench.count_node)
	Match.prof_on = true
	var walls := PackedFloat32Array()
	var last := Time.get_ticks_usec()
	var called := false
	var press_n := 0
	while is_instance_valid(m) and m.time < SETTLE + secs:
		if not called and m.time >= SETTLE:
			_gather(m)
			called = true
		if called:
			press_n += _drive(m)
		var before := _sections()
		var pipes := _pipelines()
		var t0 := Time.get_ticks_usec()
		m._process(DT)
		var script_ms := (Time.get_ticks_usec() - t0) / 1000.0
		await main.get_tree().process_frame
		var now := Time.get_ticks_usec()
		var wall := (now - last) / 1000.0
		last = now
		bench.add_row("brawl", walls.size(), wall, script_ms)
		if called:
			walls.append(wall)
			if wall > SPIKE_MS:
				_spike(m, wall, script_ms, before, _pipelines() - pipes)
		bench.added.clear()
	Match.prof_on = false
	_report(walls, press_n)

## Every hunter round the Crown's middle: each trio on its own spot of a ring, facing in.
func _gather(m: Match) -> void:
	var mid := Vector3(m.world.w * 0.5, 0.0, m.world.h * 0.5)      # (one tile is one metre)
	var teams := {}
	for h in m.hunters:
		teams[h.team] = true
	var ti := teams.keys()
	var gi := 0
	for h in m.hunters:
		var a := TAU * ti.find(h.team) / ti.size() + 0.25 * (gi % 3)
		var p: Vector3 = m.world.free_spot_near(mid + Vector3(cos(a), 0, sin(a)) * RING, [], 1.0, 0.5, 6.0)
		h.teleport(Vector3(p.x, m.world.ground_at(p.x, p.z), p.z))
		h.unlock_all()
		h.max_hp *= 20.0
		h.gear[0] = {"id": gloves[gi % gloves.size()], "rar": 1}
		h.gear[1] = {"id": gloves[(gi + 1) % gloves.size()], "rar": 1}
		gi += 1

## One frame of orders: everyone stays alive, aims at the nearest rival, keeps its Boki out and
## presses its next slot when its turn comes. Returns how many presses were made.
func _drive(m: Match) -> int:
	var n := 0
	var turn := int(m.time / PRESS_GAP)
	for i in m.hunters.size():
		var h: Hunter = m.hunters[i]
		h.hp = h.max_hp
		var foe := _nearest_foe(m, h)
		if foe: h.inp["aim"] = foe.pos + Vector3(0, 0.9, 0)
		var k: Kin = h.kin
		if k and k.state == "shoulder" and k.throw_cd <= 0.0:
			KinCommand.tap(h)
		if (turn + i) % 3 != 0 or h.get_meta("brawl_turn", -1) == turn:
			continue
		h.set_meta("brawl_turn", turn)
		var key: String = PRESSES[(turn / 3 + i) % PRESSES.size()]
		if key == "ult": h.ult = 1.0
		h.inp[key] = true
		n += 1
	return n

func _nearest_foe(m: Match, h: Hunter) -> Hunter:
	var best: Hunter = null
	var bd := INF
	for o in m.hunters:
		if o.team == h.team or o.out: continue
		var d: float = o.pos.distance_squared_to(h.pos)
		if d < bd:
			bd = d
			best = o
	return best

func _sections() -> Dictionary:
	var s := {}
	for k in Match.prof: s["step:" + String(k)] = int(Match.prof[k])
	for k in Match.vprof: s["vis:" + String(k)] = int(Match.vprof[k])
	return s

func _pipelines() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE) \
		+ RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW) \
		+ RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)

## One spike: where the frame went (sections over 1 ms), what entered the tree, pipelines compiled.
func _spike(m: Match, wall: float, script_ms: float, before: Dictionary, pipes: int) -> void:
	var now := _sections()
	var d := {}
	for k in now:
		var us := int(now[k]) - int(before.get(k, 0))
		if us >= 1000: d[k] = us
	var ks := d.keys()
	ks.sort_custom(func(a, b): return d[a] > d[b])
	var top := ks.slice(0, 5).map(func(k): return "%s %.1f" % [k, d[k] / 1000.0])
	var nodes: Array = bench.added.keys()
	nodes.sort_custom(func(a, b): return bench.added[a] > bench.added[b])
	var nn: Array = nodes.slice(0, 6).map(func(k): return "%s x%d" % [k, bench.added[k]])
	print("BENCH spike t=%.2f wall %.1f script %.1f pipelines %d | %s | new: %s" % [m.time, wall, script_ms, pipes,
		", ".join(top), ", ".join(nn)])

func _report(walls: PackedFloat32Array, presses: int) -> void:
	var w := Array(walls)
	w.sort()
	if w.is_empty(): return
	var over := w.filter(func(x): return x > SPIKE_MS).size()
	var bad := w.filter(func(x): return x > BUDGET_MS).size()
	print("BENCH brawl: %d frames, %d presses, p50 %.1f ms, p99 %.1f ms, max %.1f ms, spikes>%d %d, over %d ms %d" % [
		w.size(), presses, w[w.size() / 2], w[int((w.size() - 1) * 0.99)], w[-1], SPIKE_MS, over, BUDGET_MS, bad])
