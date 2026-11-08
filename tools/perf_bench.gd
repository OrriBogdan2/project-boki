extends RefCounted
## --perf-bench, owner item 94: a fixed, repeatable load for before/after numbers. A 60 s busy
## expedition (6 Hunters in squads of 2 with their Boki, the ash storm, the Blight, outposts and a lair
## on the map, a fight: two rivals and a monster pack brought to you), then a farm run. Every frame is
## logged; each part ends with summary lines and the costliest match step sections and meshes, and a
## frame over 33 ms and 2x the 30 before it names the nodes that entered the tree in it.
##   timeout 1200 xvfb-run -a godot --rendering-driver opengl3 --audio-driver Dummy -- --perf-bench
##   [--bench-secs=60] [--bench-farm=20] [--bench-out=/path/frames.csv] [--quality=medium] [--bench-stress]
## --bench-stress: the 60-actor load (10 trios = 30 Hunters, every Boki kept out beside its Hunter, no fight).
## Software GL makes wall time mostly raster time: compare script ms, draws, tris and nodes between runs.
## The gate: a match p99 over P99_SLACK times the one recorded for this adapter, load, quality and length in
## tools/perf_baseline.json exits 1 (BENCH GATE FAIL). Record a new baseline by editing that file from a run.

const DT := 1.0 / 60.0
const VIEW := Vector2i(640, 360)     # small window: a software rasterizer's fill time; counts are the same
const FIGHT_AT := 8.0               # s: when the fight is brought to you
const MOBS := ["skitter", "brute", "spitter", "skitter", "bomber", "skitter"]

var main: Node
var secs := 60.0
var farm_secs := 20.0
var out_path := ""
var teams := 3            # --bench-teams / --bench-squad: 10 trios is the Extraction budget (30 Hunters)
var squad := 2
var stress := false       # --bench-stress: 30 Hunters with all 30 Boki out, nothing brought to you
const STRESS_OUT_S := 2.0           # s between sends: a Boki back on its Hunter's shoulder is sent out again
var rows := PackedStringArray()
var hud_us := 0
var added := {}          # node name -> count, nodes that entered the tree this frame (named on a hitch)
const SLOW_MS := 33.0               # a frame over this counts as a hitch in the summary (under 30 fps)
const BASELINE := "res://tools/perf_baseline.json"
const P99_SLACK := 1.15             # the gate: match p99 may be at most 15% over the baseline
var match_p99 := 0.0
var vp: RID

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bench-secs="): secs = float(a.substr(13))
		if a.begins_with("--bench-farm="): farm_secs = float(a.substr(13))
		if a.begins_with("--bench-out="): out_path = a.substr(12)
		if a.begins_with("--bench-teams="): teams = int(a.substr(14))
		if a.begins_with("--bench-squad="): squad = int(a.substr(14))
	stress = "--bench-stress" in OS.get_cmdline_user_args()
	if stress:
		teams = 10
		squad = 3
	Save.no_write = true
	Save.d["tutorial"]["home"] = true
	main.get_window().size = VIEW
	main.get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	vp = main.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	rows.append("part,frame,wall_ms,script_ms,process_ms,hud_ms,render_cpu_ms,draws,tris,objects,nodes")
	await _match()
	await _farm()
	print("BENCH quality=%s renderer=%s adapter=%s" % [Settings.quality(),
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	if out_path != "":
		var fa := FileAccess.open(out_path, FileAccess.WRITE)
		if fa: fa.store_string("\n".join(rows) + "\n")
	main.get_tree().quit(_gate())

## 1 when the match p99 regressed past P99_SLACK of the baseline for this setup, else 0.
func _gate() -> int:
	var key := "%s|%dx%d%s|%s|%ds" % [RenderingServer.get_video_adapter_name(), teams, squad,
		" stress" if stress else "", Settings.quality(), int(secs)]
	var base = JSON.parse_string(FileAccess.get_file_as_string(BASELINE)) if FileAccess.file_exists(BASELINE) else {}
	if not (base is Dictionary and base.has(key)):
		print("BENCH GATE no baseline for '%s'" % key)
		return 0
	var cap := float(base[key]["p99"]) * P99_SLACK
	print("BENCH GATE %s: match p99 %.1f ms, cap %.1f (baseline %.1f +15%%)" % [
		"PASS" if match_p99 <= cap else "FAIL", match_p99, cap, float(base[key]["p99"])])
	return 0 if match_p99 <= cap else 1

func _match() -> void:
	var o := Match.demo_opts()
	o.merge({"teams": teams, "squad": squad, "total": teams * squad, "raid": "ash", "blight": true, "no_drop": true,
		"god": true,
		"autoplay": true, "demo_kin": "cindle", "seed": 4101}, true)
	o.erase("demo_match")
	o.erase("fresh_t")
	Game.goto("match", o)
	var m: Match = null
	while m == null:
		await main.get_tree().process_frame
		var cur = main.current
		if cur is Match and (cur as Match).is_processing() and (cur as Match).hud != null:
			m = cur
	m.set_process(false)
	var steps := {}
	for mk in PerfLog.marks:
		steps[mk[1]] = float(steps.get(mk[1], 0.0)) + float(mk[2])
	var sk := steps.keys()
	sk.sort_custom(func(a, b): return steps[a] > steps[b])
	print("BENCH match build (ms): " + ", ".join(sk.slice(0, 6).map(func(k): return "%s %.0f" % [k, steps[k]])))
	_hook_hud(m)
	main.get_tree().node_added.connect(func(n: Node):
		var k := "%s:%s" % [n.get_class(), String(n.name).rstrip("0123456789@")]
		added[k] = int(added.get(k, 0)) + 1)
	Match.prof_on = true
	Match.prof.clear()
	Match.vprof.clear()
	var fl: Array = []
	var last := Time.get_ticks_usec()
	var fought := stress
	var out_at := 0.0
	var boki_out := 0
	var P: Hunter = m.player
	P.max_hp *= 20.0      # the fight must not end the run: "god" stops nothing once a rival stomps you
	while is_instance_valid(m) and m.time < secs:
		P.hp = P.max_hp
		if not fought and m.time >= FIGHT_AT:
			_bring_fight(m)
			fought = true
		if stress and m.time >= out_at:
			out_at = m.time + STRESS_OUT_S
			boki_out = _boki_out(m)
		var t0 := Time.get_ticks_usec()
		m._process(DT)        # one frame as the game runs it: one DT step, then the visuals (it stepped twice before)
		var script_ms := (Time.get_ticks_usec() - t0) / 1000.0
		await main.get_tree().process_frame
		var now := Time.get_ticks_usec()
		fl.append(_frame("match", fl.size(), (now - last) / 1000.0, script_ms))
		var wall: float = fl[-1]["wall"]
		if fl.size() > 30 and wall > SLOW_MS and wall > 2.0 * _avg(fl.slice(-31, -1), "wall"):
			print("BENCH hitch t=%.2f %.0f ms (script %.1f, top %s %.1f, render cpu %.1f), new nodes: %s" % [
				m.time, wall, script_ms, Match.prof_top, Match.prof_top_us / 1000.0, fl[-1]["rcpu"],
				added])
		added.clear()
		last = now
	_summary("match", fl)
	if stress:
		print("BENCH stress: %d Hunters, %d Boki out at the last send" % [m.hunters.size(), boki_out])
	var ks := Match.prof.keys()
	ks.sort_custom(func(a, b): return Match.prof[a] > Match.prof[b])
	var per := ks.slice(0, 10).map(func(k): return "%s %.2f" % [k, Match.prof[k] / 1000.0 / fl.size()])
	print("BENCH match step sections (ms per frame): " + ", ".join(per))
	var vk := Match.vprof.keys()
	vk.sort_custom(func(a, b): return Match.vprof[a] > Match.vprof[b])
	print("BENCH match visual sections (ms per frame): " + ", ".join(vk.slice(0, 8).map(
		func(k): return "%s %.2f" % [k, Match.vprof[k] / 1000.0 / fl.size()])))
	_meshes()
	Match.prof_on = false
	if "--bench-ablate" in OS.get_cmdline_user_args():
		await _ablate()

## --bench-ablate: what each script's _process and each engine node class's internal process costs, by
## turning it off for a few frames (process ms, against a fresh reference each time).
func _ablate() -> void:
	var by := {}
	for n in main.get_tree().root.find_children("*", "", true, false):
		var k := ""
		if n.get_script() != null and n.is_processing():
			k = (n.get_script() as Script).resource_path.get_file()
		elif n is AnimationMixer or n is CPUParticles3D or n is Skeleton3D or n is GPUParticles3D:
			k = n.get_class()
		if k != "":
			if not by.has(k): by[k] = []
			by[k].append(n)
	var cost := {}
	for k in by:
		var ref := await _proc_ms(20)
		for n in by[k]: _set_on(n, false)
		cost[k] = ref - await _proc_ms(20)
		for n in by[k]: if is_instance_valid(n): _set_on(n, true)
	var ks := cost.keys()
	ks.sort_custom(func(a, b): return cost[a] > cost[b])
	print("BENCH ablate (script or class: nodes, ms saved off): " + ", ".join(ks.slice(0, 14).map(
		func(k): return "%s: %d, %.2f" % [k, by[k].size(), cost[k]])))

func _set_on(n: Node, on: bool) -> void:
	if n.get_script() != null:
		n.set_process(on)
	else:
		n.set_process_internal(on)

func _proc_ms(frames: int) -> float:
	var s := 0.0
	for i in frames:
		await main.get_tree().process_frame
		s += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	return s / frames

## Two rivals and a monster pack around the player, so the last part of the run is a fight.
func _bring_fight(m: Match) -> void:
	var P: Hunter = m.player
	var n := 0
	for h in m.hunters:
		if h.team != P.team and n < 2:
			h.teleport(P.pos + Vector3(5.0 + n * 2.0, 0.0, 3.0 - n * 6.0))
			n += 1
	for i in MOBS.size():
		var a := TAU * i / MOBS.size()
		var at: Vector3 = m.world.free_spot_near(P.pos + Vector3(cos(a), 0, sin(a)) * 6.0, [], 1.0, 0.5, 6.0)
		m.spawn_mob(MOBS[i], Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))

## --bench-stress: sends every Hunter's shouldered Boki out beside it; returns how many are out.
func _boki_out(m: Match) -> int:
	var n := 0
	for k in m.kins:
		var kn := k as Kin
		if kn.owner_h == null or kn.dead:
			continue
		if kn.state == "shoulder":
			kn.throw_to(kn.owner_h.pos + Vector3(2.5, 0.0, 1.5))
		elif kn.state == "active":
			n += 1
	return n

func _farm() -> void:
	Game.goto("home")
	for i in 30:
		await main.get_tree().process_frame
	var fl: Array = []
	var last := Time.get_ticks_usec()
	var t := 0.0
	while t < farm_secs:
		await main.get_tree().process_frame
		var now := Time.get_ticks_usec()
		var wall := (now - last) / 1000.0
		last = now
		fl.append(_frame("farm", fl.size(), wall, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0))
		t += DT
	_summary("farm", fl)
	_meshes()

func _frame(part: String, i: int, wall: float, script_ms: float) -> Dictionary:
	var f := {"wall": wall, "script": script_ms, "proc": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"hud": hud_us / 1000.0,
		"rcpu": RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
		"draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"tris": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"objs": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))}
	rows.append("%s,%d,%.2f,%.3f,%.3f,%.3f,%.3f,%d,%d,%d,%d" % [part, i, wall, script_ms, f["proc"], f["hud"],
		f["rcpu"], f["draws"], f["tris"], f["objs"], f["nodes"]])
	return f

## Times the HUD's canvas draw (it redraws every frame) by wrapping its draw callback, as --perf-probe does.
func _hook_hud(m: Match) -> void:
	var h = m.hud
	var cb := Callable(h, "_draw_all")
	if h.c.draw.is_connected(cb):
		h.c.draw.disconnect(cb)
		h.c.draw.connect(func():
			var t0 := Time.get_ticks_usec()
			h._draw_all()
			hud_us = Time.get_ticks_usec() - t0 + h.panels.used_us      # (the panel canvas: HudPanels)
			h.panels.used_us = 0)

func _avg(fl: Array, key: String) -> float:
	var s := 0.0
	for f in fl: s += float(f[key])
	return s / maxf(1.0, fl.size())

func _summary(part: String, fl: Array) -> void:
	var w: Array = fl.map(func(f): return float(f["wall"]))
	w.sort()
	var cut := maxi(1, w.size() / 100)
	var low := 0.0
	for k in cut: low += float(w[w.size() - 1 - k])
	low /= cut
	var sc: Array = fl.map(func(f): return float(f["script"]))
	sc.sort()
	var p99 := float(w[int((w.size() - 1) * 0.99)])
	if part == "match": match_p99 = p99
	var sc99 := float(sc[int((sc.size() - 1) * 0.99)])
	print("BENCH %s: %d frames, wall avg %.1f ms, p99 %.1f ms (1%% low %.1f fps), %d frames over %d ms" % [part,
		fl.size(), _avg(fl, "wall"), p99, 1000.0 / maxf(low, 0.001), w.filter(func(x): return x > SLOW_MS).size(),
		SLOW_MS])
	print("BENCH %s cpu: match script avg %.2f ms p99 %.2f ms, process %.2f ms, hud %.2f ms, render cpu %.2f ms" % [
		part, _avg(fl, "script"), sc99, _avg(fl, "proc"), _avg(fl, "hud"), _avg(fl, "rcpu")])
	print("BENCH %s scene: draws %.0f, tris %.0fk, objects %.0f, nodes %.0f, emitters %d, lights %d, shadowed %d" % [
		part, _avg(fl, "draws"), _avg(fl, "tris") / 1000.0, _avg(fl, "objs"), _avg(fl, "nodes"),
		_count("GPUParticles3D") + _count("CPUParticles3D"), _count("Light3D"), _shadow_lights()])
	print("BENCH %s memory: textures %.0f MB, buffers %.0f MB" % [part,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0])

func _count(cls: String) -> int:
	return main.get_tree().root.find_children("*", cls, true, false).size()

func _shadow_lights() -> int:
	var lights := main.get_tree().root.find_children("*", "Light3D", true, false)
	return lights.filter(func(l): return (l as Light3D).shadow_enabled and (l as Light3D).is_visible_in_tree()).size()

## The heaviest meshes in the scene (visible instances x triangles), grouped by mesh resource.
func _meshes() -> void:
	var by := {}
	for n in main.get_tree().root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var tris := 0
		for si in mi.mesh.get_surface_count():
			if mi.mesh is ArrayMesh:
				var il := (mi.mesh as ArrayMesh).surface_get_array_index_len(si)
				tris += (il if il > 0 else (mi.mesh as ArrayMesh).surface_get_array_len(si)) / 3
		var key := String(mi.name).rstrip("0123456789@")
		if key == "" or key.begins_with("@"):
			var up := mi.get_parent()
			var up2 := up.get_parent()
			var nm2 := String(up2.name) if up2 else ""
			key = "%s/%s" % [nm2.rstrip("0123456789@"), String(up.name).rstrip("0123456789@")]
		if mi.mesh.resource_path != "":
			key = mi.mesh.resource_path.get_file()
		var g: Array = by.get(key, [0, 0, 0])
		g[0] += 1
		g[1] += tris
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: g[2] += 1
		by[key] = g
	var ks := by.keys()
	ks.sort_custom(func(a, b): return by[a][1] > by[b][1])
	var top := ks.slice(0, 12).map(func(k): return "%s: %d, %.1fk, %d" % [k, by[k][0], by[k][1] / 1000.0, by[k][2]])
	print("BENCH heaviest meshes (name: instances, total tris k, shadow casters): " + ", ".join(top))
	var em := {}
	for n in main.get_tree().root.find_children("*", "CPUParticles3D", true, false):
		var p := n as CPUParticles3D
		var key := "%s/%s%s" % [String(p.get_parent().name).rstrip("0123456789@"), String(p.name).rstrip("0123456789@"),
			"" if p.emitting and p.is_visible_in_tree() else " (idle)"]
		em[key] = int(em.get(key, 0)) + 1
	var ek := em.keys()
	ek.sort_custom(func(a, b): return em[a] > em[b])
	print("BENCH CPU particle emitters (parent/name: count): " + ", ".join(ek.slice(0, 10).map(
		func(k): return "%s: %d" % [k, em[k]])))
