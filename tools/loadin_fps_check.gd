extends Node
## --loadin-fps-check: a real expedition's first seconds in real time, the way the Play button starts one
## (the home screen's options: Data.MATCH_PLAYERS hunters in squads of 3, loading screen and warm-up, then
## the skyship). Logs every frame's wall time from the loading screen up to LOOK_S seconds after it has
## gone, with the engine's own monitors (draw calls, objects, nodes, physics, memory), and judges the
## frames after the screen: none may run under MIN_FPS and the average must reach AVG_FPS.
##   godot -- --loadin-fps-check [--loadin-out=report.txt] [--loadin-csv=frames.csv] [--loadin-seed=4101]
##   [--loadin-res=1920x1080] [--loadin-secs=30] [--loadin-split]
## --loadin-split (a probe, not judged): after the screen the check calls Match._process and every other script
## _process itself and times each by file, and times the draw from the renderer's pre/post-draw signals, so the
## report names where a frame's main-thread time goes.
## Frame times swing with the box, so like --hitch-check it is "advisory" off a GPU host
## (docs/CHECKS_TIMING.md) and strict with --timing-strict. Headless draws nothing: only the frame
## count and node growth per frame are judged (the spawn burst limit).

const MIN_FPS := 30.0  # no frame after the loading screen runs slower than this
const AVG_FPS := 60.0  # the average over the look window
const BURST_NODES := 400  # nodes one frame may add after the loading screen (headless-safe spawn limit)
const SOFTWARE_RES := Vector2i(640, 360)

var out_path := ""
var csv_path := ""
var seed_v := 4101
var res := Vector2i(1920, 1080)
var look_s := 30.0
var advisory := false
var headless := false
var software := false
var frames: Array = []  # wall ms, loading 1/0, draws, objs, nodes, phys, proc, mem, vram, steps, cpu ms, marks,
# render cpu ms (the viewport's culling + draw submission), frame setup cpu ms, gpu ms
var loading_ms := 0.0
var last_us := 0
var t0_us := 0
var shown_us := 0
var main_node: Node
var steps_total := 0  # sim steps taken after the screen
var last_time := -1.0  # Match.time last frame
var sole_reads0 := 0  # BootSole.reads when the screen went
var last_cpu := 0.0  # cpu_ms() at the last frame
var split := false  # --loadin-split: time the scripts' _process by file and the draw
var split_us := {}  # phase -> {section -> usec summed over that phase's frames}
var split_n := {}  # phase -> frames
var taken := {}  # script file -> nodes whose _process the check calls itself
var split_m: Match
var t_pre := 0
var t_post := 0
var last_split := 0  # usec of the last split frame (a draw older than it was already counted)


## The calling thread's CPU time so far in ms (Linux schedstat; -1 elsewhere). A shared box stretches a frame's wall
## time with its other jobs, but not the main thread's own CPU time: that is what a change to the scripts moves.
static func cpu_ms() -> float:
	var f := FileAccess.open("/proc/thread-self/schedstat", FileAccess.READ)
	if f == null:
		return -1.0
	return float(f.get_line().split(" ")[0]) / 1.0e6


## CheckRegistry entry point: "advisory" off a GPU host, strict with --timing-strict.
func run(main: Node, mode: String) -> void:
	advisory = mode == "advisory" and not "--timing-strict" in OS.get_cmdline_user_args()
	main_node = main
	main.add_child(self)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--loadin-out="):
			out_path = a.substr(13)
		elif a.begins_with("--loadin-csv="):
			csv_path = a.substr(13)
		elif a.begins_with("--loadin-seed="):
			seed_v = int(a.substr(14))
		elif a.begins_with("--loadin-secs="):
			look_s = float(a.substr(14))
		elif a.begins_with("--loadin-res="):
			var p := a.substr(13).split("x")
			res = Vector2i(int(p[0]), int(p[1]))
		elif a == "--loadin-split":
			split = true
	headless = DisplayServer.get_name() == "headless"
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	var soft := ["llvmpipe", "softpipe", "swiftshader", "swrast"]
	software = not headless and soft.any(func(s): return adapter.contains(s))
	if not headless:
		get_window().size = SOFTWARE_RES if software else res
	process_priority = -100
	if split:
		RenderingServer.frame_pre_draw.connect(func(): t_pre = Time.get_ticks_usec())
		RenderingServer.frame_post_draw.connect(func(): t_post = Time.get_ticks_usec())
	if not headless:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	Save.no_write = true
	Save.d["tutorial"]["home"] = true
	if Save.d["roster"].is_empty():
		var tk := Save.new_kin("zapple", "Pip")
		Save.d["roster"].append(tk)
		Save.d["active"] = tk["uid"]
	t0_us = Time.get_ticks_usec()
	last_us = t0_us
	# the Play button's options (Home._start_match), made to play itself so the ride and drop run
	var o := {"teams": ceili(Data.MATCH_PLAYERS / 3.0), "squad": 3, "total": Data.MATCH_PLAYERS, "tier": 0}
	o.merge({"seed": seed_v, "autoplay": true, "probe": true, "god": true})
	Game.main.show_screen("match", o)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var wall := (now - last_us) / 1000.0
	var marks := PerfLog.between(last_us, now)
	last_us = now
	var cpu_now := cpu_ms()
	var cpu := cpu_now - last_cpu
	last_cpu = cpu_now
	var cur = Game.main.current
	var loading: bool = Game.main._ld != null and is_instance_valid(Game.main._ld)
	var ready_now: bool = cur is Match and (cur as Match).is_processing() and (cur as Match).hud != null
	if shown_us == 0 and ready_now and not loading:
		shown_us = now
		loading_ms = (now - t0_us) / 1000.0
		sole_reads0 = BootSole.reads
		Match.prof_on = true  # from here the sim and visual sections are summed (Match.prof, Match.vprof)
		if split:
			split_m = cur as Match
			split_m.set_process(false)
			_take_process(get_tree().root)
	elif split and split_m != null and is_instance_valid(split_m):
		_split_frame(wall, now)
	var steps := 0
	if shown_us > 0 and cur is Match:
		if last_time >= 0.0:
			steps = roundi(((cur as Match).time - last_time) / (1.0 / 60.0))
		last_time = (cur as Match).time
		steps_total += steps
	var step := ""
	var vp := get_viewport().get_viewport_rid()
	for mk in marks:
		step += "%s %.0f " % [mk[1], mk[2]]
	(
		frames
		. append(
			[
				wall,
				0 if shown_us > 0 else 1,
				int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
				int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
				steps,
				cpu,
				step.strip_edges(),
				RenderingServer.viewport_get_measured_render_time_cpu(vp) if not headless else 0.0,
				RenderingServer.get_frame_setup_time_cpu() if not headless else 0.0,
				RenderingServer.viewport_get_measured_render_time_gpu(vp) if not headless else 0.0,
			]
		)
	)
	if shown_us > 0 and (now - shown_us) / 1e6 >= look_s:
		_finish()
	elif (now - t0_us) / 1e6 > 300.0:
		print("LOADIN stuck: no match after 300 s")
		get_tree().quit(1)


func _judged() -> Array:
	return frames.filter(func(f): return int(f[1]) == 0)


func _pct(sorted_ms: Array, p: float) -> float:
	if sorted_ms.is_empty():
		return 0.0
	return float(sorted_ms[clampi(int(ceil(p * sorted_ms.size())) - 1, 0, sorted_ms.size() - 1)])


## The five costliest sections of a profile dictionary (us totals), as ms per `n`.
func _top(prof: Dictionary, n: int) -> String:
	var ks := prof.keys()
	ks.sort_custom(func(a, b): return prof[a] > prof[b])
	return ", ".join(ks.slice(0, 22).map(func(k): return "%s %.2f" % [k, float(prof[k]) / 1000.0 / n]))


func _finish() -> void:
	var lines: Array = []
	lines.append(
		(
			"LOADIN renderer=%s adapter=%s window=%s seed=%d players=%d"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name(),
				str(get_window().size),
				seed_v,
				Data.MATCH_PLAYERS
			]
		)
	)
	var load_f := frames.filter(func(f): return int(f[1]) == 1)
	var load_w: Array = load_f.map(func(f): return float(f[0]))
	load_w.sort()
	var lf := "LOADIN loading screen %.0f ms over %d frames, worst frame %.0f ms"
	lines.append(lf % [loading_ms, load_f.size(), _pct(load_w, 1.0)])
	var j := _judged()
	var w: Array = j.map(func(f): return float(f[0]))
	var sum := 0.0
	for x in w:
		sum += float(x)
	w.sort()
	var avg_fps := 1000.0 * w.size() / maxf(sum, 1.0)
	var worst_ms := _pct(w, 1.0)
	var slow := w.filter(func(x): return float(x) > 1000.0 / MIN_FPS).size()
	var ff := "LOADIN first %.0f s after the screen: %d frames, avg %.1f fps, min %.1f fps (worst %.0f ms), "
	ff += "p99 %.1f ms, p50 %.1f ms, %d frames under %.0f fps"
	var min_fps := 1000.0 / maxf(worst_ms, 0.001)
	lines.append(ff % [look_s, w.size(), avg_fps, min_fps, worst_ms, _pct(w, 0.99), _pct(w, 0.5), slow, MIN_FPS])
	var ranked := j.duplicate()
	ranked.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	lines.append("LOADIN worst frames after the screen (ms; draws, objects, nodes, phys, proc, mem, vram, steps):")
	for f in ranked.slice(0, 10):
		var wf := "LOADIN   %6.0f ms  %d draws %d obj %d nodes  phys %.1f proc %.1f  mem %.0f vram %.0f"
		wf += "  %d steps  cpu %.1f  rcpu %.1f setup %.1f gpu %.1f  %s"
		lines.append(wf % [f[0], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9], f[10], f[12], f[13], f[14], f[11]])
	var cpus: Array = j.map(func(f): return float(f[10]))
	cpus.sort()
	var cpu_sum := 0.0
	for x in cpus:
		cpu_sum += float(x)
	lines.append(
		(
			(
				"LOADIN main-thread cpu a frame (other jobs cannot stretch it):"
				+ " avg %.1f ms, p50 %.1f, p99 %.1f, max %.1f"
			)
			% [cpu_sum / maxi(cpus.size(), 1), _pct(cpus, 0.5), _pct(cpus, 0.99), _pct(cpus, 1.0)]
		)
	)
	var rs := [0.0, 0.0, 0.0]
	for f in j:
		for k in 3:
			rs[k] += float(f[12 + k])
	var rf := "LOADIN render a frame (ms avg): cpu %.1f (culling + draw submission), frame setup %.1f, gpu %.1f"
	lines.append(rf % [rs[0] / maxi(j.size(), 1), rs[1] / maxi(j.size(), 1), rs[2] / maxi(j.size(), 1)])
	if split:
		for ph in split_us:
			var n := int(split_n.get(ph, 1))
			lines.append("LOADIN split %s, %d frames (ms a frame): %s" % [ph, n, _top(split_us[ph], n)])
	var per_frame := float(steps_total) / maxi(w.size(), 1)
	var sf2 := "LOADIN sim steps %d in %d frames (%.1f a frame; 1.0 is real time)"
	lines.append(sf2 % [steps_total, w.size(), per_frame])
	lines.append("LOADIN where the sim goes (ms a frame): " + _top(Match.prof, maxi(w.size(), 1)))
	lines.append("LOADIN where a frame's visuals go (ms a frame): " + _top(Match.vprof, maxi(w.size(), 1)))
	var burst := 0
	for i in range(1, j.size()):
		burst = maxi(burst, int(j[i][4]) - int(j[i - 1][4]))
	lines.append("LOADIN most nodes added in one frame after the screen: %d (limit %d)" % [burst, BURST_NODES])
	# the deck lift reads boot soles (a CPU skin of every boot vertex): only your squad's riders, and not every frame
	var sole_reads := BootSole.reads - sole_reads0
	var sole_limit := (ceili(float(w.size()) / SkyDeck.SOLE_EVERY) + 2) * 3
	var sf := "LOADIN boot-sole reads after the screen: %d in %d frames (limit %d: a squad of 3 every %d frames)"
	lines.append(sf % [sole_reads, w.size(), sole_limit, SkyDeck.SOLE_EVERY])
	var fails := 0
	if sole_reads > sole_limit:
		fails += 1
		lines.append("LOADIN FAIL %d boot-sole reads (limit %d)" % [sole_reads, sole_limit])
	if burst > BURST_NODES:
		fails += 1
		lines.append("LOADIN FAIL %d nodes in one frame" % burst)
	if not headless:
		if slow > 0:
			fails += 1
			lines.append("LOADIN FAIL %d frames under %.0f fps" % [slow, MIN_FPS])
		if avg_fps < AVG_FPS:
			fails += 1
			lines.append("LOADIN FAIL average %.1f fps under %.0f" % [avg_fps, AVG_FPS])
	lines.append("LOADIN %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	var txt := "\n".join(lines)
	if advisory and fails > 0:
		txt = txt.replace(" FAIL", " ADVISORY")
	print(txt)
	if out_path != "":
		var fa := FileAccess.open(out_path, FileAccess.WRITE)
		if fa:
			fa.store_string(txt + "\n")
	if csv_path != "":
		var fc := FileAccess.open(csv_path, FileAccess.WRITE)
		if fc:
			fc.store_line("ms,loading,draws,objects,nodes,phys_ms,proc_ms,mem_mb,vram_mb,sim_steps,cpu_ms,marks,rcpu,setup,gpu")
			for f in frames:
				fc.store_line("%.2f,%d,%d,%d,%d,%.2f,%.2f,%.0f,%.0f,%d,%.2f,%s,%.2f,%.2f,%.2f" % f)
	get_tree().quit(0 if fails == 0 or advisory else 1)


## (--loadin-split) Every node but this one and Match running a script _process: the engine stops calling it and
## _split_frame calls it, timed per script file. Nodes made later stay with the engine (they land in "rest").
func _take_process(n: Node) -> void:
	if n != self and n != split_m and n.get_script() != null and n.is_processing() and n.has_method("_process"):
		var k := String((n.get_script() as Script).resource_path).get_file()
		if not taken.has(k):
			taken[k] = []
		taken[k].append(n)
		n.set_process(false)
	for c in n.get_children():
		_take_process(c)


## (--loadin-split) One frame: the last draw (pre to post-draw), Match._process, each taken script file, and the
## rest of the wall time since the last frame (engine process, physics, other nodes, waits).
func _split_frame(wall: float, now: int) -> void:
	var dt := get_process_delta_time()
	var draw := t_post - t_pre if t_post > t_pre and t_pre > last_split else 0
	last_split = now
	var used := draw
	# by phase: planning on the deck, in the air (the jump, the glide down), on the ground
	var p := split_m.player
	var ph := "plan" if split_m.skydrop and split_m.skydrop.planning else "ground"
	if ph == "ground" and p and (p.dropping or p.gliding):
		ph = "air"
	split_n[ph] = int(split_n.get(ph, 0)) + 1
	_add(ph, "draw", draw)
	var v0 := _vsum()
	var t0 := Time.get_ticks_usec()
	split_m._process(dt)
	var t1 := Time.get_ticks_usec()
	var vis := _vsum() - v0
	_add(ph, "match visuals", vis)
	_add(ph, "match steps+rest", t1 - t0 - vis)
	used += t1 - t0
	for k in taken:
		var a := Time.get_ticks_usec()
		for n in taken[k]:
			if is_instance_valid(n) and n.is_inside_tree():
				n._process(dt)
		var b := Time.get_ticks_usec()
		_add(ph, k, b - a)
		used += b - a
	_add(ph, "rest", maxi(0, int(wall * 1000.0) - used))


func _add(ph: String, k: String, us: int) -> void:
	var d: Dictionary = split_us.get(ph, {})
	d[k] = int(d.get(k, 0)) + us
	split_us[ph] = d


func _vsum() -> int:
	var t := 0
	for k in Match.vprof:
		t += int(Match.vprof[k])
	return t
