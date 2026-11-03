extends RefCounted
## --tier-map-perf: the Riven Wilds' cost against the Hollow Crown's, the same match on each (tier 2,
## six squads of three bots, the player one of them, seed 4101), after a warm-up match (so neither pays
## the first shader compiles), in two rounds (Hollow Crown, Riven Wilds, Hollow Crown, Riven Wilds) and
## each map's best round kept, so a burst of load from something else on the machine doesn't decide it:
##   - load: building the match (world, meshes, spawns) until it can play
##   - sim: ms per match step (60 a second) with the bots playing: everything that runs per tick
##   - view: draw calls and objects drawn per frame with the camera at SPOTS landings in turn (median landing)
##   - frame: wall time per drawn frame there (median and 95th percentile)
## Budget (the map is 2.4x the area): a sim step at most SIM_BUDGET x the Hollow Crown's (far monsters
## and wild Boki sleep, MobSleep) and the median drawn frame at most FRAME_BUDGET x (the ground and
## scatter are drawn in chunks with draw distances, so what is off screen costs nothing). The load is
## held to LOAD_BUDGET x: the build still grows with the ground (docs/DEBT.md, "Riven Wilds load").
## Draw calls and objects are reported, not judged: at a landing they follow what stands there (the
## train at a stop, a thick wood), not the map's size. Headless only the load and sim are judged
## (nothing is drawn). Run drawn:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --audio-driver Dummy -- --tier-map-perf

const LOAD_BUDGET := 1.9
const SIM_BUDGET := 1.25
const FRAME_BUDGET := 1.3
const ROUNDS := 2
const SPOTS := 6            # landings the frames are timed at
const SETTLE := 8           # frames at a spot before timing (the camera, first draws)
const PER_SPOT := 24        # frames timed at each spot
const SIM_STEPS := 300      # match steps timed for the sim cost
const DRAWS := RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
const OBJECTS := RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME

func run(c) -> void:
	var drawn := DisplayServer.get_name() != "headless"
	await _measure(c.main, "tutorial")
	var best := {}
	for _round in ROUNDS:
		for id in ["hollowcrown", "riven"]:
			var row: Dictionary = await _measure(c.main, id)
			if not best.has(id):
				best[id] = row
				continue
			for k in ["load", "sim", "med", "p95", "draws", "objs"]:
				best[id][k] = minf(float(best[id][k]), float(row[k]))
	var hc: Dictionary = best["hollowcrown"]
	var rv: Dictionary = best["riven"]
	for row in [hc, rv]:
		print("TIERMAP perf %-12s load %6.0f ms  sim %5.2f ms/step  frame median %6.1f ms p95 %6.1f ms" % [
			row["id"], row["load"], row["sim"], row["med"], row["p95"]])
		print("TIERMAP perf %-12s draws %5.0f  objects %5.0f  mobs %d (%d asleep)  step ms: %s" % [
			row["id"], row["draws"], row["objs"], row["mobs"], row["asleep"], row["top"]])
		print("TIERMAP perf %-12s build ms: %s" % [row["id"], row["build"]])
	_judge(c, "load (ms)", rv["load"], hc["load"], LOAD_BUDGET)
	_judge(c, "sim (ms per step)", rv["sim"], hc["sim"], SIM_BUDGET)
	if drawn:
		_judge(c, "median frame (ms)", rv["med"], hc["med"], FRAME_BUDGET)

func _judge(c, what: String, riven: float, crown: float, budget: float) -> void:
	c.ok("%s %.1f is within %.2fx the Hollow Crown's %.1f" % [what, riven, budget, crown],
		riven <= crown * budget + 0.05, "(%.2fx)" % (riven / maxf(0.01, crown)))

func _measure(main: Node, id: String) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var m := Match.new()
	main.add_child(m)
	var o := {"teams": 6, "squad": 3, "tier": 2, "seed": 4101, "no_drop": true, "autoplay": true, "god": true}
	o["map"] = id
	if id == "tutorial":
		o = {"tutorial": true, "teams": 1, "squad": 1, "seed": 4101, "no_drop": true}
	m.start(o)
	var row := {"id": id, "load": (Time.get_ticks_usec() - t0) / 1000.0, "build": _build_steps()}
	row.merge(await _view(main, m, 1 if id == "tutorial" else SPOTS))
	row.merge(_sim(m, 30 if id == "tutorial" else SIM_STEPS))
	row["mobs"] = m.mobs.size()
	row["asleep"] = m.mobs.filter(func(mb): return mb.asleep).size()
	m.queue_free()
	for _f in 3:
		await main.get_tree().process_frame
	return row

## Frames drawn with the camera at the map's landings, spread round it (where squads come down and
## play starts), the same count on every map. Draws and objects: the median landing (one thick wood
## doesn't stand for the whole map).
func _view(main: Node, m: Match, count: int) -> Dictionary:
	var walls: Array = []
	var draws: Array = []
	var objs: Array = []
	var all: Array = m.world.spawns
	for i in count:
		m.player.teleport(all[int(float(i) * all.size() / count) % all.size()])
		m.cam.snap(m.player.pos)
		var last := Time.get_ticks_usec()
		var spot_draws := 0.0
		var spot_objs := 0.0
		for f in SETTLE + PER_SPOT:
			await main.get_tree().process_frame
			var now := Time.get_ticks_usec()
			if f >= SETTLE:
				walls.append((now - last) / 1000.0)
				spot_draws += RenderingServer.get_rendering_info(DRAWS)
				spot_objs += RenderingServer.get_rendering_info(OBJECTS)
			last = now
		draws.append(spot_draws / PER_SPOT)
		objs.append(spot_objs / PER_SPOT)
	return {"med": _median(walls), "p95": _pick(walls, 0.95), "draws": _median(draws), "objs": _median(objs)}

static func _median(xs: Array) -> float:
	return _pick(xs, 0.5)

static func _pick(xs: Array, at: float) -> float:
	var sorted := xs.duplicate()
	sorted.sort()
	return float(sorted[mini(int(sorted.size() * at), sorted.size() - 1)])

## The slowest steps of the build just done (PerfLog's marks), for the report.
static func _build_steps() -> String:
	var by := {}
	for mk in PerfLog.marks: by[String(mk[1])] = float(by.get(String(mk[1]), 0.0)) + float(mk[2])
	var keys := by.keys()
	keys.sort_custom(func(a, b): return by[a] > by[b])
	return ", ".join(keys.slice(0, 7).map(func(k): return "%s %.0f" % [k, by[k]]))

## Match steps on their own (the match's frame loop paused), with the costliest sections of the step.
func _sim(m: Match, steps: int) -> Dictionary:
	m.set_process(false)
	Match.prof.clear()
	Match.prof_on = true
	var t0 := Time.get_ticks_usec()
	for _i in steps:
		m.step(Match.DT)
	var per := (Time.get_ticks_usec() - t0) / 1000.0 / steps
	Match.prof_on = false
	var sections := Match.prof.keys()
	sections.sort_custom(func(a, b): return Match.prof[a] > Match.prof[b])
	var top := ", ".join(sections.slice(0, 6).map(func(k): return "%s %.2f" % [k, Match.prof[k] / 1000.0 / steps]))
	return {"sim": per, "top": top}
