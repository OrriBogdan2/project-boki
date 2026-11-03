extends RefCounted
## --tier-map-perf: the Riven Wilds' cost against the Hollow Crown's, the same match on each (tier 2,
## six squads of three bots, the player one of them, seed 4101), one after the other in one run after a
## warm-up match (so neither pays the first shader compiles):
##   - load: building the match (world, meshes, spawns) until it can play
##   - frame: wall time per drawn frame while the bots play, with the camera at SPOTS landings in turn
##     (median and 95th percentile), script time per frame, and draw calls and objects in view (0
##     headless); the match step's costliest sections (Match.prof, ms in all) and how many monsters sleep
## Budget (the map is 2.4x the area; streaming keeps what a frame costs to what is near the camera):
##   load at most LOAD_BUDGET x the Hollow Crown's, frames at most FRAME_BUDGET x (median and p95),
##   draw calls and objects at most DRAW_BUDGET x.
## Run it drawn for the frame numbers (headless only times the scripts):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --audio-driver Dummy -- --tier-map-perf

const LOAD_BUDGET := 1.5
const FRAME_BUDGET := 1.15
const DRAW_BUDGET := 1.15
const SPOTS := 8           # landings the frames are timed at
const SETTLE := 12          # frames at a spot before timing (the camera, first draws)
const PER_SPOT := 30        # frames timed at each spot
const DRAWS := RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
const OBJECTS := RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME

func run(c) -> void:
	await _measure(c.main, "tutorial")
	var hc: Dictionary = await _measure(c.main, "hollowcrown")
	var rv: Dictionary = await _measure(c.main, "riven")
	for row in [hc, rv]:
		print("TIERMAP perf %-12s load %6.0f ms  frame median %6.1f ms p95 %6.1f ms  script %5.2f ms" % [
			row["id"], row["load"], row["med"], row["p95"], row["script"]])
		print("TIERMAP perf %-12s draws %5.0f  objects %5.0f  mobs %d (%d asleep)  step ms: %s" % [
			row["id"], row["draws"], row["objs"], row["mobs"], row["asleep"], row["top"]])
	_judge(c, "load", rv["load"], hc["load"], LOAD_BUDGET, "ms")
	_judge(c, "median frame", rv["med"], hc["med"], FRAME_BUDGET, "ms")
	_judge(c, "95th percentile frame", rv["p95"], hc["p95"], FRAME_BUDGET, "ms")
	_judge(c, "draw calls", rv["draws"], hc["draws"], DRAW_BUDGET, "")
	_judge(c, "objects in view", rv["objs"], hc["objs"], DRAW_BUDGET, "")

func _judge(c, what: String, riven: float, crown: float, budget: float, unit: String) -> void:
	c.ok("%s %.0f%s is within %.2fx the Hollow Crown's %.0f%s" % [what, riven, unit, budget, crown, unit],
		riven <= crown * budget + 1.0, "(%.2fx)" % (riven / maxf(0.01, crown)))

func _measure(main: Node, id: String) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var m := Match.new()
	main.add_child(m)
	var o := {"teams": 6, "squad": 3, "tier": 2, "seed": 4101, "no_drop": true, "autoplay": true, "god": true}
	o["map"] = id
	if id == "tutorial":
		o = {"tutorial": true, "teams": 1, "squad": 1, "seed": 4101, "no_drop": true}
	m.start(o)
	var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var walls: Array = []
	var sums := {"script": 0.0, "draws": 0.0, "objs": 0.0}
	Match.prof.clear()
	Match.prof_on = true
	for spot in _spots(m, 1 if id == "tutorial" else SPOTS):
		m.player.teleport(spot)
		m.cam.snap(m.player.pos)
		var last := Time.get_ticks_usec()
		for f in SETTLE + PER_SPOT:
			await main.get_tree().process_frame
			var now := Time.get_ticks_usec()
			if f >= SETTLE:
				walls.append((now - last) / 1000.0)
				sums["script"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
				sums["draws"] += RenderingServer.get_rendering_info(DRAWS)
				sums["objs"] += RenderingServer.get_rendering_info(OBJECTS)
			last = now
	Match.prof_on = false
	var asleep := m.mobs.filter(func(mb): return mb.asleep).size()
	var sections := Match.prof.keys()
	sections.sort_custom(func(a, b): return Match.prof[a] > Match.prof[b])
	var top := ", ".join(sections.slice(0, 5).map(func(k): return "%s %.0f" % [k, Match.prof[k] / 1000.0]))
	var mobs := m.mobs.size()
	m.queue_free()
	for _f in 3:
		await main.get_tree().process_frame
	walls.sort()
	var k := maxf(1.0, walls.size())
	return {"id": id, "load": load_ms, "med": walls[walls.size() / 2] if not walls.is_empty() else 0.0,
		"p95": walls[int(walls.size() * 0.95)] if not walls.is_empty() else 0.0, "script": sums["script"] / k,
		"draws": sums["draws"] / k, "objs": sums["objs"] / k, "mobs": mobs, "asleep": asleep, "top": top}

## Where frames are timed: the map's landings, spread round it (where squads come down and play
## starts), the same count on every map.
static func _spots(m: Match, count: int) -> Array:
	var all: Array = m.world.spawns
	var out: Array = []
	for i in count:
		out.append(all[int(float(i) * all.size() / count) % all.size()])
	return out
