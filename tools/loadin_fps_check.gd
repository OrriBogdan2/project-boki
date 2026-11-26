extends Node
## --loadin-fps-check: a real expedition's first seconds in real time, the way the Play button starts one
## (the home screen's options: Data.MATCH_PLAYERS hunters in squads of 3, loading screen and warm-up, then
## the skyship). Logs every frame's wall time from the loading screen up to LOOK_S seconds after it has
## gone, with the engine's own monitors (draw calls, objects, nodes, physics, memory), and judges the
## frames after the screen: none may run under MIN_FPS and the average must reach AVG_FPS.
##   godot -- --loadin-fps-check [--loadin-out=report.txt] [--loadin-csv=frames.csv] [--loadin-seed=4101]
##   [--loadin-res=1920x1080] [--loadin-secs=30]
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
var frames: Array = []  # [wall ms, loading (1/0), draws, objects, nodes, phys ms, proc ms, mem MB, vram MB, marks]
var loading_ms := 0.0
var last_us := 0
var t0_us := 0
var shown_us := 0
var main_node: Node


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
	headless = DisplayServer.get_name() == "headless"
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	software = not headless and ["llvmpipe", "softpipe", "swiftshader", "swrast"].any(func(s): return adapter.contains(s))
	if not headless:
		get_window().size = SOFTWARE_RES if software else res
	process_priority = -100
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
	var cur = Game.main.current
	var loading: bool = Game.main._ld != null and is_instance_valid(Game.main._ld)
	var ready_now: bool = cur is Match and (cur as Match).is_processing() and (cur as Match).hud != null
	if shown_us == 0 and ready_now and not loading:
		shown_us = now
		loading_ms = (now - t0_us) / 1000.0
	var step := ""
	for mk in marks:
		step += "%s %.0f " % [mk[1], mk[2]]
	frames.append(
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
			step.strip_edges(),
		]
	)
	if shown_us > 0 and (now - shown_us) / 1e6 >= look_s:
		_finish()
	elif (now - t0_us) / 1e6 > 300.0:
		print("LOADIN stuck: no match after 300 s")
		get_tree().quit(1)


func _judged() -> Array:
	return frames.filter(func(f): return int(f[1]) == 0)


func _pct(sorted_ms: Array, p: float) -> float:
	return float(sorted_ms[clampi(int(ceil(p * sorted_ms.size())) - 1, 0, sorted_ms.size() - 1)]) if not sorted_ms.is_empty() else 0.0


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
	lines.append(
		"LOADIN loading screen %.0f ms over %d frames, worst frame %.0f ms" % [loading_ms, load_f.size(), _pct(load_w, 1.0)]
	)
	var j := _judged()
	var w: Array = j.map(func(f): return float(f[0]))
	var sum := 0.0
	for x in w:
		sum += float(x)
	w.sort()
	var avg_fps := 1000.0 * w.size() / maxf(sum, 1.0)
	var worst_ms := _pct(w, 1.0)
	var slow := w.filter(func(x): return float(x) > 1000.0 / MIN_FPS).size()
	lines.append(
		(
			"LOADIN first %.0f s after the screen: %d frames, avg %.1f fps, min %.1f fps (worst %.0f ms), p99 %.1f ms, p50 %.1f ms, %d frames under %.0f fps"
			% [look_s, w.size(), avg_fps, 1000.0 / maxf(worst_ms, 0.001), worst_ms, _pct(w, 0.99), _pct(w, 0.5), slow, MIN_FPS]
		)
	)
	var ranked := j.duplicate()
	ranked.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	lines.append("LOADIN worst frames after the screen (ms; draws, objects, nodes, phys ms, proc ms, mem MB, vram MB):")
	for f in ranked.slice(0, 10):
		lines.append("LOADIN   %6.0f ms  %d draws %d obj %d nodes  phys %.1f proc %.1f  mem %.0f vram %.0f  %s" % [f[0], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9]])
	var burst := 0
	for i in range(1, j.size()):
		burst = maxi(burst, int(j[i][4]) - int(j[i - 1][4]))
	lines.append("LOADIN most nodes added in one frame after the screen: %d (limit %d)" % [burst, BURST_NODES])
	var fails := 0
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
			fc.store_line("ms,loading,draws,objects,nodes,phys_ms,proc_ms,mem_mb,vram_mb,steps")
			for f in frames:
				fc.store_line("%.2f,%d,%d,%d,%d,%.2f,%.2f,%.0f,%.0f,%s" % f)
	get_tree().quit(0 if fails == 0 or advisory else 1)
