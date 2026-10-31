extends Node
## Tooling (--perf-probe): plays one scripted expedition the way a player gets it (loading screen,
## planning map, skyship ride, the jump and glide down, landing, a look at the full map, a fight)
## and logs per phase: wall frame time, script time, draw calls, objects, primitives, memory, and the
## worst hitches with the build steps (PerfLog marks) that ran inside them.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --audio-driver Dummy -- --perf-probe
##   [--probe-out=/path/report.txt] [--probe-quick] [--probe-squad=3] [--quality=high]
## A software-rendered GPU makes wall time mostly raster time, so read the CPU columns (script,
## render submit) and the counts; wall time is still where hitches show.

const DT := 1.0 / 60.0

var out_path := ""
var quick := false
var m: Match = null
var phase := "load"
var phase_t := 0.0          # sim seconds in this phase
var started_us := 0
var last_us := 0
var frames: Array = []      # {phase, wall, proc, steps, draws, objs, prims, rcpu, hud}
var load_frames: Array = []
var load_ms := 0.0
var landed_at := -1.0
var fought := false
var map_done := false
var hud_us := 0
var vp_rid: RID
var _hud_hooked := false
var _end := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe-out="): out_path = a.substr(12)
		if a == "--probe-quick": quick = true
	vp_rid = get_viewport().get_viewport_rid()
	# a software rasterizer spends most of a frame filling pixels: a small window and no MSAA keep
	# the probe quick, and change none of the counts (draws, objects, primitives) or the CPU times
	if not "--probe-full" in OS.get_cmdline_user_args():
		get_window().size = Vector2i(640, 360)
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		Settings.v["msaa"] = 0
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	process_priority = -100
	Save.d["tutorial"]["home"] = true
	var squad := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe-squad="): squad = int(a.substr(14))
	started_us = Time.get_ticks_usec()
	last_us = started_us
	Game.main.show_screen("match", {"teams": 6, "squad": squad, "tier": 0, "seed": 4101, "autoplay": true, "probe": true, "god": true})

func _rinfo(k: int) -> int:
	return RenderingServer.get_rendering_info(k)

func _process(_delta: float) -> void:
	if _end:
		return
	var now := Time.get_ticks_usec()
	var wall := (now - last_us) / 1000.0
	var marks := PerfLog.between(last_us, now)
	last_us = now
	if m == null:
		var cur = Game.main.current
		load_frames.append({"wall": wall, "marks": marks})
		if cur is Match and (cur as Match).is_processing() and (cur as Match).hud != null:
			m = cur
			m.set_process(false)
			load_ms = (now - started_us) / 1000.0
			_hook_hud()
			phase = "first"
		return
	# the counts are for the frame that just drew
	var rec := {"phase": phase, "wall": wall, "draws": _rinfo(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objs": _rinfo(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), "prims": _rinfo(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"rcpu": RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) + RenderingServer.get_frame_setup_time_cpu(),
		"hud": hud_us / 1000.0, "marks": marks, "t": m.time}
	if not frames.is_empty():
		frames[-1].merge({"draws": rec["draws"], "objs": rec["objs"], "prims": rec["prims"], "rcpu": rec["rcpu"]}, true)
	# advance the match: quiet stretches run several steps per drawn frame so the probe stays short
	var k := 1
	match phase:
		"planning", "ride": k = 6
		"drop": k = 3
	var t0 := Time.get_ticks_usec()
	m._process(DT * k)
	var proc := (Time.get_ticks_usec() - t0) / 1000.0
	rec["proc"] = proc / k
	rec["steps"] = k
	frames.append(rec)
	phase_t += DT * k
	_next_phase()

func _set_phase(p: String) -> void:
	_print_phase(phase)
	phase = p
	phase_t = 0.0

func _next_phase() -> void:
	var P: Hunter = m.player
	match phase:
		"first":
			if phase_t >= 0.5: _set_phase("planning" if m.skydrop and m.skydrop.planning else "ride")
		"planning":
			if not (m.skydrop and m.skydrop.planning): _set_phase("ride")
		"ride":
			if not P.riding: _set_phase("drop")
		"drop":
			if not P.dropping:
				_set_phase("land")
				landed_at = m.time
		"land":
			if phase_t >= (1.5 if quick else 2.5):
				m.hud.open_map()
				_set_phase("map")
		"map":
			if phase_t >= 1.0:
				m.hud.close_map()
				_spawn_fight()
				_set_phase("fight")
		"fight":
			if phase_t >= (3.0 if quick else 5.0):
				_finish()
	if m.time > 200.0 and phase != "fight":
		print("PROBE stuck in phase ", phase)
		_finish()

func _spawn_fight() -> void:
	var P: Hunter = m.player
	var kinds := ["skitter", "brute", "spitter", "skitter", "bomber"]
	for i in kinds.size():
		var a := TAU * i / kinds.size()
		var at := m.world.free_spot_near(P.pos + Vector3(cos(a), 0, sin(a)) * 5.0, [], 1.0, 0.5, 6.0)
		m.spawn_mob(kinds[i], Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	fought = true

## Times the HUD's whole canvas draw (the full map included) by wrapping its draw callback.
func _hook_hud() -> void:
	var h = m.hud
	if h == null or _hud_hooked:
		return
	var cb := Callable(h, "_draw_all")
	if h.c.draw.is_connected(cb):
		h.c.draw.disconnect(cb)
		h.c.draw.connect(func():
			var t0 := Time.get_ticks_usec()
			h._draw_all()
			hud_us = Time.get_ticks_usec() - t0)
		_hud_hooked = true

func _stats(list: Array, key: String) -> Array:
	var v: Array = []
	for f in list: v.append(float(f.get(key, 0.0)))
	if v.is_empty(): return [0.0, 0.0, 0.0, 0.0]
	v.sort()
	var s := 0.0
	for x in v: s += x
	return [s / v.size(), v[v.size() / 2], v[int((v.size() - 1) * 0.95)], v[-1]]

## A phase's line as soon as it ends (so a probe cut short still says something).
func _print_phase(ph: String) -> void:
	if ph == "first" and load_frames.size() > 0:
		print("PROBE loaded in %.0f ms" % load_ms)
	var fl: Array = frames.filter(func(f): return f["phase"] == ph)
	if fl.is_empty(): return
	var w := _stats(fl, "wall"); var pr := _stats(fl, "proc"); var dr := _stats(fl, "draws"); var pm := _stats(fl, "prims")
	print("PROBE phase %s: %d frames, wall avg %.1f max %.1f ms, script %.2f ms, draws %.0f (max %.0f), prims %.0fk" % [ph, fl.size(), w[0], w[3], pr[0], dr[0], dr[3], pm[0] / 1000.0])

func _finish() -> void:
	_print_phase(phase)
	_end = true
	var lines: Array = []
	lines.append("PROBE renderer=%s size=%s msaa=%d shadows=%s quality=%s" % [RenderingServer.get_current_rendering_method(), str(get_viewport().get_visible_rect().size),
		get_viewport().msaa_3d, str(Settings.get_v("shadows")), str(Settings.get_v("quality"))])
	# the load: how long, the worst frames, and the build steps
	var lf := load_frames.duplicate()
	lf.sort_custom(func(a, b): return a["wall"] > b["wall"])
	lines.append("PROBE load total %.0f ms over %d frames; worst frame %.0f ms" % [load_ms, load_frames.size(), lf[0]["wall"] if lf.size() > 0 else 0.0])
	var steps := {}
	for mk in PerfLog.marks:
		steps[mk[1]] = float(steps.get(mk[1], 0.0)) + float(mk[2])
	var sk := steps.keys()
	sk.sort_custom(func(a, b): return steps[a] > steps[b])
	var build_total := 0.0
	for k in sk:
		if String(k).begins_with("build.") or String(k).begins_with("world.") or String(k).begins_with("map."): build_total += steps[k]
	lines.append("PROBE build steps total %.0f ms: %s" % [build_total, ", ".join(sk.slice(0, 14).map(func(k): return "%s %.0f" % [k, steps[k]]))])
	lines.append("PROBE %-9s %6s %8s %8s %8s %8s %8s %7s %7s %9s %8s" % ["phase", "frames", "wall_avg", "wall_p95", "wall_max", "script", "scr_max", "rcpu", "hud", "draws", "prims_k"])
	for ph in ["first", "planning", "ride", "drop", "land", "map", "fight"]:
		var fl: Array = frames.filter(func(f): return f["phase"] == ph)
		if fl.is_empty(): continue
		var w := _stats(fl, "wall"); var pr := _stats(fl, "proc"); var rc := _stats(fl, "rcpu"); var hd := _stats(fl, "hud")
		var dr := _stats(fl, "draws"); var pm := _stats(fl, "prims")
		lines.append("PROBE %-9s %6d %8.1f %8.1f %8.1f %8.2f %8.2f %7.2f %7.2f %4.0f/%4.0f %8.0f" % [ph, fl.size(), w[0], w[2], w[3], pr[0], pr[3], rc[0], hd[0], dr[0], dr[3], pm[0] / 1000.0])
	# hitches: the slowest frames after loading, against the median of their phase
	var after := frames.duplicate()
	after.sort_custom(func(a, b): return a["wall"] > b["wall"])
	lines.append("PROBE worst frames (wall ms, script ms, phase, sim t, build steps inside):")
	for f in after.slice(0, 8):
		lines.append("PROBE   %7.1f %7.2f %-9s t=%5.1f %s" % [f["wall"], f.get("proc", 0.0), f["phase"], f.get("t", 0.0), ", ".join((f["marks"] as Array).map(func(mk): return "%s %.0f" % [mk[1], mk[2]]))])
	lines.append("PROBE memory: textures %.1f MB, buffers %.1f MB, video %.1f MB, static %.1f MB, objects %d, nodes %d" % [
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_COUNT)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	var txt := "\n".join(lines)
	print(txt)
	if out_path != "":
		var fa := FileAccess.open(out_path, FileAccess.WRITE)
		if fa: fa.store_string(txt + "\n")
	get_tree().quit()
