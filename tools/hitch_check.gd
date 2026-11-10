extends Node
## --hitch-check: one seeded expedition the way a player gets it (loading screen and warm-up, the
## planning map, the skyship ride, the jump, the glide down, landing and the first seconds on the
## ground, with a mob pack of every roaming kind a second after landing), timing every drawn frame and
## failing if one in the start/drop/landing stretch stalls.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --audio-driver Dummy -- --hitch-check
##   [--load-check | --load-check=home | --load-check=training]
##   [--hitch-out=/path/report.txt] [--hitch-squad=3] [--hitch-seed=4101] [--hitch-budget=ms] [--quality=...]
## Also runs headless (--headless): then nothing is drawn and only the script side is timed.
##
## Each frame is split into: sim (Match.step), visuals (Match._process: interpolation, animation,
## camera), other scripts (every other _process: HUD, effects, props; Performance.TIME_PROCESS
## minus the two), render (RenderingServer frame_pre_draw .. frame_post_draw: culling, draw
## submission, shader compiles inside the driver) and the rest (swap and the driver finishing the
## frame: on a software rasterizer, the raster itself and lazily-JIT'd shader variants). It also
## names the materials that were in view for the first time that frame (a first draw is where a GPU
## compiles a shader) and the PerfLog build steps that ran inside it.
##
## The budget (a frame in the ride, drop or landing phases that costs more fails the check):
##   - a real GPU: 100 ms, six frames at 60 fps; a frame that long is a visible hitch, while a
##     first-draw shader compile or a big synchronous spawn is 200 ms to seconds.
##   - a software rasterizer (llvmpipe, softpipe, SwiftShader: no GPU in the run environment): every
##     frame costs 250-2500 ms of plain rasterization (more with the whole map in view), so a fixed
##     number means nothing there; a frame fails if it costs more than 2.5x the median of the ten
##     frames each side of it and 1.2 s more than that median (the landing stall this check was
##     written for was 6.4 s against a 0.4 s median).
##   - headless: nothing renders; a frame's script time over 50 ms fails.
## --hitch-budget=ms overrides the fixed numbers. Loading-screen frames are reported, not judged.
## Whatever the timing, a frame in those phases that compiles a shader variant fails too (counted from
## writes to user://shader_cache, so run with a fresh user data dir, e.g. XDG_DATA_HOME=/tmp/x, to see
## them: with a warm cache a variant loads from disk instead). Timings on a busy machine (other
## processes on the same cores) are noisy; the compile count isn't.

const DT := 1.0 / 60.0
const JUDGED := ["ride", "drop", "land"]

var out_path := ""
var m: Match = null
var phase := "load"
var phase_t := 0.0
var started_us := 0
var last_us := 0
var frames: Array = []
var load_frames: Array = []
var load_ms := 0.0
var landed_at := -1.0
var vp_rid: RID
var _end := false
var _pre_us := 0
var _render_us := 0
var _proc_end_us := 0      # when the last _process of the frame finished (the Tail node below)
var _walk_us := 0
var _compiles := 0         # shader variants in user://shader_cache so far (a new file = a compile)
var load_compiles := 0
var _seen := {}            # material/shader key -> true once it has been in view
var _seen_ready := false
var software := false
var headless := false
var budget_ms := -1.0
var seed_v := 4101
var squad := 3
var load_only := false     # --load-check: stop at the reveal and judge the loading screen
var home_only := false     # --load-check=home: the title-to-home swap instead (see _home_check)
var trace := false
var training := false      # --load-check=training: the Training Area's load instead of an expedition's
var shots_dir := ""        # --load-shots=dir: a screenshot of the loading screen every half second (skews timings)
var _shot_t := 0.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hitch-out="): out_path = a.substr(12)
		if a.begins_with("--hitch-budget="): budget_ms = float(a.substr(15))
		if a.begins_with("--hitch-seed="): seed_v = int(a.substr(13))
		if a.begins_with("--hitch-squad="): squad = int(a.substr(14))
		if a == "--hitch-trace": trace = true; PerfLog.trace_slices = true
		if a.begins_with("--load-shots="): shots_dir = a.substr(13)
		if a == "--load-check": load_only = true
		if a == "--load-check=home": load_only = true; home_only = true
		if a == "--load-check=training":
			load_only = true
			training = true
	headless = DisplayServer.get_name() == "headless"
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	software = not headless and (adapter.contains("llvmpipe") or adapter.contains("softpipe") or adapter.contains("swiftshader") or adapter.contains("swrast"))
	vp_rid = get_viewport().get_viewport_rid()
	if not headless:
		# a software rasterizer spends most of a frame filling pixels: a small window and no MSAA
		# keep the run short without changing what's drawn
		if software and not "--hitch-full" in OS.get_cmdline_user_args():
			get_window().size = Vector2i(640, 360)
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			Settings.v["msaa"] = 0
		RenderingServer.viewport_set_measure_render_time(vp_rid, true)
		RenderingServer.frame_pre_draw.connect(func(): _pre_us = Time.get_ticks_usec())
		RenderingServer.frame_post_draw.connect(func(): _render_us = Time.get_ticks_usec() - _pre_us)
	process_priority = -100
	var tail := Tail.new()
	tail.owner_check = self
	tail.process_priority = 100000
	add_child(tail)
	Save.no_write = true      # never writes the save (the music list alone would)
	Save.d["tutorial"]["home"] = true
	if Save.d["roster"].is_empty():
		# a kin of your own comes down with you, as in a real expedition (in memory only)
		var tk := Save.new_kin("zapple", "Pip")
		Save.d["roster"].append(tk)
		Save.d["active"] = tk["uid"]
	started_us = Time.get_ticks_usec()
	last_us = started_us
	print("HITCH renderer=%s adapter=%s software=%s headless=%s seed=%d squad=%d" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), software, headless, seed_v, squad])
	if home_only:
		_home_check()
		return
	_cache_count()      # what an earlier launch left in the cache is not this run's compiles
	# "probe" keeps the loading screen and the warm-up, as a real expedition has them
	if training:
		var opts := {"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": seed_v}
		opts.merge({"no_drop": true, "autoplay": true, "probe": true})
		Game.main.show_screen("match", opts)
		return
	Game.main.show_screen("match", {"teams": 6, "squad": squad, "tier": 0, "seed": seed_v, "autoplay": true, "probe": true, "god": true, "plan_t": 3.0})

func _process(_delta: float) -> void:
	if _end or home_only:
		return
	var now := Time.get_ticks_usec()
	var wall := (now - last_us - _walk_us) / 1000.0
	_walk_us = 0
	var marks := PerfLog.between(last_us, now)
	var last_us_prev := last_us
	last_us = now
	var c0 := Time.get_ticks_usec()
	var new_c := _cache_count()
	_compiles += new_c
	_walk_us += Time.get_ticks_usec() - c0
	if m == null:
		load_compiles += new_c
		var ld := _loading_node()
		if shots_dir != "" and ld:
			_shot_t += wall / 1000.0
			if _shot_t >= 0.5:
				_shot_t = 0.0
				var img := get_viewport().get_texture().get_image()
				if img: img.save_png("%s/load_%03d.png" % [shots_dir, load_frames.size()])
		load_frames.append({"wall": wall, "marks": marks, "render": _render_us / 1000.0, "compiles": new_c,
			"slice": _slices_between(last_us_prev, now),
			"proc": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, "phys": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"spin": int(ld.get("spin_draws")) if ld and ld.get("spin_draws") != null else -1, "stage": String(ld.get("stage_label")) if ld and ld.get("stage_label") != null else ""})
		var cur = Game.main.current
		if cur is Match and (cur as Match).is_processing() and (cur as Match).hud != null:
			m = cur
			m.set_process(false)
			load_ms = (now - started_us) / 1000.0
			phase = "first"
			if load_only:
				_finish_load()
		return
	# what the last frame cost outside our own stepping (known only now)
	if not frames.is_empty():
		var lf: Dictionary = frames[-1]
		lf["other"] = maxf(0.0, (_proc_end_us - int(lf["t_end"])) / 1000.0 - float(lf.get("walk", 0.0)))
		lf["render"] = _render_us / 1000.0
		lf["rest"] = maxf(0.0, wall - float(lf["proc_total"]) - float(lf["other"]) - float(lf["render"]))
		lf["wall"] = wall
		lf["draws"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		lf["marks"] = marks
		lf["compiles"] = new_c
	var k := 1
	match phase:
		"planning", "ride": k = 6
		"drop": k = 3
	# the first moments of the ride and the last of the drop are judged frame by frame
	if phase == "ride" and phase_t < 1.0: k = 1
	if phase == "drop" and m.player and m.player.pos.y - m.world.ground_at(m.player.pos.x, m.player.pos.z) < 8.0: k = 1
	Match.prof_on = true
	Match.prof.clear()
	var t0 := Time.get_ticks_usec()
	m.step(DT)
	var t1 := Time.get_ticks_usec()
	var secs: Dictionary = Match.prof.duplicate()
	Match.prof_on = false
	for i in k - 1:
		m.step(DT)
	var t2 := Time.get_ticks_usec()
	Match.prof_on = true
	Match.vprof.clear()
	m._process(DT if k == 1 else 0.0)
	Match.prof_on = false
	var vsecs: Dictionary = Match.vprof.duplicate()
	var t3 := Time.get_ticks_usec()
	var rec := {"phase": phase, "t": m.time, "k": k, "sim": (t1 - t0) / 1000.0, "sim_extra": (t2 - t1) / 1000.0,
		"vis": (t3 - t2) / 1000.0, "proc_total": (t3 - t0) / 1000.0, "wall": 0.0, "new": [], "marks": [], "t_end": t3, "secs": secs, "vsecs": vsecs}
	if not headless:
		var w0 := _walk_us
		rec["new"] = _new_in_view()
		rec["walk"] = (_walk_us - w0) / 1000.0
	frames.append(rec)
	if trace:
		_trace_lights()
		# for lining frames up with an outside sampler (gdb stacks): wall clock, phase, sim time
		print("HITCH-TRACE %.3f %s t=%.2f prev_wall=%.0f" % [Time.get_unix_time_from_system(), phase, m.time, float(frames[-2]["wall"]) if frames.size() > 1 else 0.0])
	phase_t += DT * k
	_next_phase()

func _set_phase(p: String) -> void:
	phase = p
	phase_t = 0.0

func _next_phase() -> void:
	var P: Hunter = m.player
	match phase:
		"first":
			if phase_t >= 0.25:
				_set_phase("planning" if m.skydrop and m.skydrop.planning else "ride")
		"planning":
			if not (m.skydrop and m.skydrop.planning): _set_phase("ride")
		"ride":
			if not P.riding: _set_phase("drop")
		"drop":
			if not P.dropping:
				_set_phase("land")
				landed_at = m.time
		"land":
			if phase_t >= 1.0 and not _pack_done:
				_pack_done = true
				_bring_pack()
			if phase_t >= 3.0:
				_finish()
	if m.time > 200.0 and not _end:
		print("HITCH stuck in phase ", phase)
		_finish()

## A second on the ground, one of each roaming mob kind spawns round you (a fight's pack): a kind's first
## model mid-play compiled its materials then, unless the warm-up built one (WarmUp._mob_stand_ins).
var _pack_done := false
func _bring_pack() -> void:
	var P: Hunter = m.player
	var kinds: Array = []
	for k in Data.MOBS:
		if not Data.MOBS[k].get("boss", false) and not Data.MOBS[k].get("ward", false):
			kinds.append(k)
	for i in kinds.size():
		var a := TAU * i / kinds.size()
		var at: Vector3 = m.world.free_spot_near(P.pos + Vector3(cos(a), 0, sin(a)) * 7.0, [], 1.0, 0.5, 6.0)
		m.spawn_mob(kinds[i], Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	print("HITCH pack: %d mobs (%s) at t=%.2f" % [kinds.size(), ",".join(kinds), m.time])

## Materials in the camera's view this frame that weren't in view on any frame before (from the
## first judged frame on). A first draw is where shaders compile, so these name what a stall drew.
func _new_in_view() -> Array:
	var w0 := Time.get_ticks_usec()
	var cam := get_viewport().get_camera_3d()
	var out: Array = []
	if cam == null:
		return out
	var planes := cam.get_frustum()
	var cpos := cam.global_position
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasItem and not (n as CanvasItem).visible:
			continue
		if n is Node3D and not (n as Node3D).visible:
			continue
		for ch in n.get_children(): stack.append(ch)
		if not (n is GeometryInstance3D):
			continue
		var gi := n as GeometryInstance3D
		var ab := gi.global_transform * gi.get_aabb()
		var inside := true
		for pl in planes:
			var nv := ab.position + Vector3(ab.size.x if pl.normal.x < 0.0 else 0.0, ab.size.y if pl.normal.y < 0.0 else 0.0, ab.size.z if pl.normal.z < 0.0 else 0.0)
			if pl.distance_to(nv) > 0.0:
				inside = false; break
		if not inside:
			continue
		if gi.visibility_range_end > 0.0 and cpos.distance_to(ab.get_center()) > gi.visibility_range_end + gi.visibility_range_end_margin:
			continue
		for key in _mat_keys(gi):
			if not _seen.has(key):
				_seen[key] = true
				if _seen_ready: out.append("%s (%s)" % [key, _node_path(n)])
	_seen_ready = true
	_walk_us += Time.get_ticks_usec() - w0
	return out

## What a draw of this instance compiles: each surface's material (shader + render mode) and the
## kind of geometry (mesh, multimesh, particles, label, skinned).
func _mat_keys(gi: GeometryInstance3D) -> Array:
	var kind := gi.get_class()
	var mats: Array = []
	var mesh: Mesh = null
	if gi is MeshInstance3D: mesh = (gi as MeshInstance3D).mesh
	elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh: mesh = (gi as MultiMeshInstance3D).multimesh.mesh
	elif gi is CPUParticles3D: mesh = (gi as CPUParticles3D).mesh
	if gi.material_override:
		mats.append(gi.material_override)
	elif mesh:
		for si in mesh.get_surface_count():
			var mt: Material = (gi as MeshInstance3D).get_active_material(si) if gi is MeshInstance3D else mesh.surface_get_material(si)
			mats.append(mt)
	if gi.material_overlay: mats.append(gi.material_overlay)
	if gi is MeshInstance3D and (gi as MeshInstance3D).skeleton != NodePath(""): kind += "+skin"
	var out: Array = []
	for mt in mats:
		var chain: Material = mt
		while chain != null:
			out.append("%s:%s" % [kind, _mat_name(chain)])
			chain = chain.next_pass
	if mats.is_empty():
		out.append(kind + ":default")
	return out

func _mat_name(mt: Material) -> String:
	if mt is ShaderMaterial:
		var sh: Shader = (mt as ShaderMaterial).shader
		return "shader " + (sh.resource_path.get_file() if sh and sh.resource_path != "" else str(sh.get_instance_id() if sh else 0))
	if mt is StandardMaterial3D:
		var s := mt as StandardMaterial3D
		return "std t%d s%d c%d a%d e%d tex%d bb%d v%d" % [s.transparency, s.shading_mode, s.cull_mode, int(s.albedo_texture != null), int(s.emission_enabled), int(s.texture_filter), s.billboard_mode, int(s.vertex_color_use_as_albedo)]
	return mt.get_class()

func _node_path(n: Node) -> String:
	var parts: Array = []
	var x := n
	for i in 3:
		if x == null or x == m: break
		parts.push_front(String(x.name))
		x = x.get_parent()
	return "/".join(parts)

## Trace: the lights in the match whose state changed since the last frame (which lights touch
## an object decides which shader variant it compiles in the Compatibility renderer).
var _lights := {}
func _trace_lights() -> void:
	var now := {}
	for n in m.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		now[l.get_instance_id()] = "%s vis=%s e=%.2f at=%s sh=%s" % [_node_path(l), l.is_visible_in_tree(), l.light_energy, str(l.global_position.snapped(Vector3.ONE * 2.0)), l.shadow_enabled]
	for k in now:
		if _lights.get(k, "") != now[k]: print("HITCH-LIGHT ", now[k])
	for k in _lights:
		if not now.has(k): print("HITCH-LIGHT gone ", _lights[k])
	_lights = now

## The build's slices that ended inside (t0, t1]: "  [slice 34 ms at where]".
func _slices_between(t0: int, t1: int) -> String:
	var out := ""
	for sl in PerfLog.slices:
		if int(sl[0]) > t0 and int(sl[0]) <= t1:
			out += "  [slice %.0f ms%s]" % [float(sl[1]), (" at " + String(sl[2])) if String(sl[2]) != "" else ""]
	return out

func _loading_node() -> Node:
	for ch in Game.main.get_children():
		var sc = ch.get_script()
		if sc and String(sc.resource_path).ends_with("loading.gd"):
			return ch
	return null

## --load-check: the loading screen from the click to the reveal. Every frame of it should be
## short enough that the screen keeps moving (and the window never looks hung):
##   - a real GPU: no frame over 100 ms.
##   - a software rasterizer or headless: a frame's time outside drawing (wall minus the render
##     submit, which on llvmpipe is the raster itself) over 150 ms fails. Timings on a busy machine
##     are noisy: compare runs back to back.
## and the spinner has to have drawn on every frame the loading screen was up (its draw count goes
## up each frame; a frame that blocks would show as one step).
func _finish_load() -> void:
	_end = true
	var lines: Array = []
	lines.append("LOAD renderer=%s adapter=%s window=%s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), str(get_window().size)])
	var fl := load_frames.duplicate()
	var budget := budget_ms if budget_ms > 0.0 else (150.0 if (software or headless) else 100.0)
	var cpu_only := software or headless
	var over := 0
	var worst := 0.0
	var worst_cpu := 0.0
	for f in fl:
		var cpu := float(f["wall"]) - float(f["render"])
		f["cpu"] = cpu
		worst = maxf(worst, float(f["wall"]))
		worst_cpu = maxf(worst_cpu, cpu)
		if (cpu if cpu_only else float(f["wall"])) > budget: over += 1
	lines.append("LOAD total %.0f ms over %d frames; longest frame %.0f ms (%.0f ms outside drawing); %d frames over %.0f ms%s" % [load_ms, fl.size(), worst, worst_cpu, over, budget, " (judged outside drawing)" if cpu_only else ""])
	# the spinner: frames the loading screen was up on, and how many of them drew it
	var up := 0
	var drawn := 0
	var prev := -1
	for f in fl:
		var sp := int(f["spin"])
		if sp < 0:
			prev = -1
			continue
		if prev >= 0:
			up += 1
			if sp > prev: drawn += 1
		prev = sp
	var walls: Array = fl.map(func(f): return float(f["wall"]))
	walls.sort()
	if not walls.is_empty():
		var p95: float = walls[mini(walls.size() - 1, int(walls.size() * 0.95))]
		lines.append("LOAD frame ms p50 %.1f p95 %.1f max %.1f" % [walls[walls.size() / 2], p95, walls[-1]])
	lines.append("LOAD spinner drew on %d of %d loading-screen frames" % [drawn, up])
	var ranked := fl.duplicate()
	ranked.sort_custom(func(a, b): return float(a["cpu" if cpu_only else "wall"]) > float(b["cpu" if cpu_only else "wall"]))
	lines.append("LOAD longest frames (wall, outside drawing, render, process, physics of the frame before, shader compiles, stage shown, build steps inside):")
	for f in ranked.slice(0, 12):
		lines.append("LOAD   %7.0f %7.0f %7.0f %6.0f %5.0f  c%-3d %-22s %s%s" % [float(f["wall"]), float(f["cpu"]), float(f["render"]), float(f["proc"]), float(f["phys"]), int(f["compiles"]), String(f["stage"]),
			", ".join((f["marks"] as Array).map(func(mk): return "%s %.0f" % [mk[1], mk[2]])), String(f["slice"])])
	var steps := {}
	for mk in PerfLog.marks:
		steps[mk[1]] = float(steps.get(mk[1], 0.0)) + float(mk[2])
	var sk := steps.keys()
	sk.sort_custom(func(a, b): return steps[a] > steps[b])
	lines.append("LOAD build steps (total ms): " + ", ".join(sk.slice(0, 16).map(func(k): return "%s %.0f" % [k, steps[k]])))
	for nt in PerfLog.notes: lines.append("LOAD note: " + String(nt))
	var spin_ok := up == 0 or drawn >= up - 1
	var ok := over == 0 and spin_ok and up > 0
	lines.append("LOAD %s" % ("PASS" if ok else "FAIL (%d slow frames%s%s)" % [over, "" if spin_ok else ", spinner skipped frames", "" if up > 0 else ", no loading screen seen"]))
	var txt := "\n".join(lines)
	print(txt)
	if out_path != "":
		var fa := FileAccess.open(out_path, FileAccess.WRITE)
		if fa: fa.store_string(txt + "\n")
	get_tree().quit(0 if ok else 1)

## --load-check=home: the title screen, then the click to the farm (ink wipe, the farm building
## behind it, the reveal), timing every frame until the farm has been on screen for a second.
## Judged like the loading screen: no frame over the budget (outside drawing on a software
## rasterizer), and the spinner on the ink keeps turning once it shows.
func _home_check() -> void:
	Game.main.show_screen("title", {})
	var t := 0.0
	while t < 2.5:
		await get_tree().process_frame
		t += get_process_delta_time()
	var fl: Array = []
	var t0 := Time.get_ticks_usec()
	var last := t0
	var built_ms := -1.0
	var shown_ms := -1.0
	var fd: ScreenFade = Game.main.fade
	PerfLog.reset()
	Game.main.show_screen("home", {})
	while true:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		fl.append({"wall": (now - last) / 1000.0, "render": _render_us / 1000.0, "spin": int(fd.get("spin_draws")) if fd.get("spin_draws") != null else 0, "covered": fd.covered, "marks": PerfLog.between(last, now), "slice": _slices_between(last, now)})
		last = now
		var cur = Game.main.current
		if built_ms < 0.0 and cur != null and cur.get_script() != null and String(cur.get_script().resource_path).ends_with("home.gd") and cur.is_node_ready() and cur.get("player") != null and cur.get("building") != true and cur.get("root_ui") != null:
			built_ms = (now - t0) / 1000.0
		if built_ms >= 0.0 and shown_ms < 0.0 and not fd.covered:
			shown_ms = (now - t0) / 1000.0
		if shown_ms >= 0.0 and (now - t0) / 1000.0 > shown_ms + 1000.0:
			break
		if (now - t0) > 60 * 1000000:
			break
	_end = true
	var lines: Array = []
	var cpu_only := software or headless
	var budget := budget_ms if budget_ms > 0.0 else (150.0 if cpu_only else 100.0)
	var worst := 0.0; var worst_cpu := 0.0; var over := 0
	for f in fl:
		f["cpu"] = float(f["wall"]) - float(f["render"])
		worst = maxf(worst, float(f["wall"])); worst_cpu = maxf(worst_cpu, float(f["cpu"]))
		if float(f["cpu"] if cpu_only else f["wall"]) > budget: over += 1
	lines.append("LOAD home: built %.0f ms, revealed %.0f ms after the click; longest frame %.0f ms (%.0f ms outside drawing); %d frames over %.0f ms%s" % [built_ms, shown_ms, worst, worst_cpu, over, budget, " (judged outside drawing)" if cpu_only else ""])
	# the ink's spinner: once it shows after the click, it should draw every frame while the ink stays up
	var up := 0; var drawn := 0; var prev := -1; var started := false
	var base_spin := int(fl[0]["spin"]) if not fl.is_empty() else 0
	for f in fl:
		var sp := int(f["spin"])
		if started and bool(f["covered"]):
			up += 1
			if sp > prev: drawn += 1
		elif not started and sp > base_spin:
			started = true
		prev = sp
	lines.append("LOAD spinner on the ink drew on %d of %d frames after it showed" % [drawn, up])
	var ranked := fl.duplicate()
	ranked.sort_custom(func(a, b): return float(a["cpu" if cpu_only else "wall"]) > float(b["cpu" if cpu_only else "wall"]))
	lines.append("LOAD longest frames (wall, outside drawing, render, build steps inside):")
	for f in ranked.slice(0, 8):
		lines.append("LOAD   %7.0f %7.0f %7.0f  %s%s" % [float(f["wall"]), float(f["cpu"]), float(f["render"]), ", ".join((f["marks"] as Array).map(func(mk): return "%s %.0f" % [mk[1], mk[2]])), String(f["slice"])])
	var ok := over == 0 and built_ms >= 0.0 and drawn >= up - 1
	lines.append("LOAD %s" % ("PASS" if ok else "FAIL"))
	var txt := "\n".join(lines)
	print(txt)
	if out_path != "":
		var fa := FileAccess.open(out_path, FileAccess.WRITE)
		if fa: fa.store_string(txt + "\n")
	get_tree().quit(0 if ok else 1)

## Runs after every other _process in the frame: marks where the scripts ended.
class Tail extends Node:
	var owner_check
	func _process(_d: float) -> void:
		owner_check._proc_end_us = Time.get_ticks_usec()

func _judge(f: Dictionary, med: float) -> float:
	## the frame's cost against its budget (> 1 fails), the extra steps of a fast-forwarded frame left out
	var cost := float(f["wall"]) - float(f.get("sim_extra", 0.0))
	if headless:
		return float(f["proc_total"] - f["sim_extra"] + f.get("other", 0.0)) / (budget_ms if budget_ms > 0.0 else 50.0)
	if software and budget_ms <= 0.0:
		return cost / maxf(med * 2.5, med + 1200.0)
	return cost / (budget_ms if budget_ms > 0.0 else 100.0)

## The typical cost of the frames around frame i (ten each side, itself left out): what the view
## costs to draw there, so a spike is judged against its neighbours, not against a lighter view.
func _local_median(i: int) -> float:
	var v: Array = []
	for j in range(maxi(0, i - 10), mini(frames.size(), i + 11)):
		if j != i: v.append(float(frames[j]["wall"]) - float(frames[j].get("sim_extra", 0.0)))
	if v.is_empty(): return 0.0
	v.sort()
	return v[v.size() / 2]

func _median(list: Array, key: String) -> float:
	var v: Array = []
	for f in list: v.append(float(f.get(key, 0.0)) - float(f.get("sim_extra", 0.0)) if key == "wall" else float(f.get(key, 0.0)))
	if v.is_empty(): return 0.0
	v.sort()
	return v[v.size() / 2]

## Shader variants the engine has compiled and cached (user://shader_cache: one file per variant).
## Counted every frame, a jump means that frame compiled shaders. Only a cold cache shows them:
## with a warm one a variant loads from disk instead (cheaper, still not free).
## A file is a shader version and grows as variants of it compile, so files and sizes both count.
var _sizes := {}
func _cache_count() -> int:
	var n := 0
	var stack: Array = ["user://shader_cache"]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		var da := DirAccess.open(d)
		if da == null: continue
		for f in da.get_files():
			var pth: String = d + "/" + f
			var sz := FileAccess.get_size(pth) if FileAccess.file_exists(pth) else 0
			if int(_sizes.get(pth, -1)) != sz:
				_sizes[pth] = sz
				n += 1
		for sub in da.get_directories(): stack.append(d + "/" + sub)
	return n

func _line(f: Dictionary) -> String:
	var s := "%7.0f ms  %-8s t=%5.2f  sim %.1f (+%.1f x%d)  vis %.1f  other %.1f  render %.1f  rest %.1f  draws %d  shader compiles %d" % [float(f["wall"]), f["phase"], float(f["t"]),
		float(f["sim"]), float(f["sim_extra"]), int(f["k"]), float(f["vis"]), float(f.get("other", 0.0)), float(f.get("render", 0.0)), float(f.get("rest", 0.0)), int(f.get("draws", 0)), int(f.get("compiles", 0))]
	var secs: Dictionary = f.get("secs", {})
	if float(f["sim"]) > 20.0 and not secs.is_empty():
		var ks := secs.keys()
		ks.sort_custom(func(a, b): return secs[a] > secs[b])
		s += "  sim sections: " + ", ".join(ks.slice(0, 4).map(func(k): return "%s %.1f" % [k, secs[k] / 1000.0]))
	var vs: Dictionary = f.get("vsecs", {})
	if float(f["vis"]) > 20.0 and not vs.is_empty():
		var vk := vs.keys()
		vk.sort_custom(func(a, b): return vs[a] > vs[b])
		s += "  visual sections: " + ", ".join(vk.slice(0, 4).map(func(k): return "%s %.1f" % [k, vs[k] / 1000.0]))
	if not (f["marks"] as Array).is_empty():
		s += "  steps: " + ", ".join((f["marks"] as Array).map(func(mk): return "%s %.0f" % [mk[1], mk[2]]))
	return s

func _finish() -> void:
	_end = true
	# the last frame's tail isn't known: drop it
	if not frames.is_empty() and float(frames[-1]["wall"]) <= 0.0: frames.pop_back()
	var lines: Array = []
	lines.append("HITCH renderer=%s adapter=%s window=%s quality=%s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(),
		str(get_window().size), str(Settings.get_v("quality"))])
	var lw: Array = load_frames.map(func(f): return float(f["wall"]))
	lw.sort()
	var steps := {}
	for mk in PerfLog.marks:
		steps[mk[1]] = float(steps.get(mk[1], 0.0)) + float(mk[2])
	var sk := steps.keys()
	sk.sort_custom(func(a, b): return steps[a] > steps[b])
	lines.append("HITCH loading screen %.0f ms over %d frames, worst %.0f ms, %d shader compiles; build steps: %s" % [load_ms, load_frames.size(), lw[-1] if lw.size() > 0 else 0.0, load_compiles,
		", ".join(sk.slice(0, 10).map(func(k): return "%s %.0f" % [k, steps[k]]))])
	var meds := {}
	for ph in ["first", "planning", "ride", "drop", "land"]:
		var fl: Array = frames.filter(func(f): return f["phase"] == ph)
		if fl.is_empty(): continue
		meds[ph] = _median(fl, "wall")
		var worst: Dictionary = fl[0]
		for f in fl:
			if float(f["wall"]) > float(worst["wall"]): worst = f
		var nc := 0
		for f in fl: nc += int(f.get("compiles", 0))
		lines.append("HITCH phase %-8s %4d frames  median %6.0f ms  worst %6.0f ms  shader compiles %d" % [ph, fl.size(), meds[ph], float(worst["wall"]), nc])
	if landed_at >= 0.0:
		var after: Array = frames.filter(func(f): return f["phase"] == "land" and float(f["t"]) <= landed_at + 1.5)
		var stall := 0.0
		for f in after: stall = maxf(stall, float(f["wall"]))
		lines.append("HITCH landing stall (worst frame in the first 1.5 s on the ground, landed at t=%.2f): %.0f ms" % [landed_at, stall])
	var start: Array = frames.filter(func(f): return f["phase"] in ["first", "planning"] or (f["phase"] == "ride" and int(f["k"]) == 1))
	var sw := 0.0
	for f in start: sw = maxf(sw, float(f["wall"]))
	lines.append("HITCH start-of-match stall (worst frame from the reveal to the first second of the ride): %.0f ms" % sw)
	var ranked := frames.duplicate()
	ranked.sort_custom(func(a, b): return a["wall"] > b["wall"])
	lines.append("HITCH worst frames (wall; sim, visuals, other scripts, render submit, rest = swap/driver):")
	for f in ranked.slice(0, 8):
		lines.append("HITCH   " + _line(f))
		for nm in (f["new"] as Array).slice(0, 10):
			lines.append("HITCH       first in view: " + String(nm))
		if (f["new"] as Array).size() > 10:
			lines.append("HITCH       ... and %d more first in view" % ((f["new"] as Array).size() - 10))
	# every frame after the reveal that compiled shaders, with what came into view on it
	for f in frames:
		if int(f.get("compiles", 0)) > 0:
			lines.append("HITCH compiled %d: " % int(f["compiles"]) + _line(f))
			for nm in (f["new"] as Array).slice(0, 6):
				lines.append("HITCH       first in view: " + String(nm))
	# script spikes cost the same on any GPU: the frames whose own step + visuals took longest
	var by_script := frames.filter(func(f): return f["phase"] != "first")
	by_script.sort_custom(func(a, b): return float(a["sim"]) + float(a["vis"]) > float(b["sim"]) + float(b["vis"]))
	lines.append("HITCH worst script frames (one step + visuals, extra fast-forward steps left out):")
	for f in by_script.slice(0, 5):
		lines.append("HITCH   %.1f ms  " % (float(f["sim"]) + float(f["vis"])) + _line(f))
	var fails := 0
	var worst_j := 0.0
	for i in frames.size():
		var f: Dictionary = frames[i]
		if not f["phase"] in JUDGED: continue
		var j := _judge(f, _local_median(i))
		worst_j = maxf(worst_j, j)
		if j > 1.0:
			fails += 1
			lines.append("HITCH FAIL over budget (%.1fx): %s" % [j, _line(f)])
		elif int(f.get("compiles", 0)) > 0 and not headless:
			# a shader compiled mid-drop: a stall on any GPU, however fast this one drew it
			fails += 1
			lines.append("HITCH FAIL compiled %d shader variant(s) during %s: %s" % [int(f["compiles"]), f["phase"], _line(f)])
	var bdesc := ("headless script %.0f ms" % (budget_ms if budget_ms > 0.0 else 50.0)) if headless else (("software: 2.5x the frames around it and +1.2 s") if software and budget_ms <= 0.0 else ("%.0f ms" % (budget_ms if budget_ms > 0.0 else 100.0)))
	lines.append("HITCH budget %s; worst judged frame at %.2f of budget; %s" % [bdesc, worst_j, "PASS" if fails == 0 else "FAIL (%d frames)" % fails])
	var txt := "\n".join(lines)
	print(txt)
	if out_path != "":
		var fa := FileAccess.open(out_path, FileAccess.WRITE)
		if fa: fa.store_string(txt + "\n")
	get_tree().quit(0 if fails == 0 else 1)
