extends Node
## --hitch-check: one seeded expedition the way a player gets it (loading screen and warm-up, the
## planning map, the skyship ride, the jump, the glide down, landing and the first seconds on the
## ground), timing every drawn frame and failing if one in the start/drop/landing stretch stalls.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --audio-driver Dummy -- --hitch-check
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
var trace := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hitch-out="): out_path = a.substr(12)
		if a.begins_with("--hitch-budget="): budget_ms = float(a.substr(15))
		if a.begins_with("--hitch-seed="): seed_v = int(a.substr(13))
		if a.begins_with("--hitch-squad="): squad = int(a.substr(14))
		if a == "--hitch-trace": trace = true
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
	# "probe" keeps the loading screen and the warm-up, as a real expedition has them
	Game.main.show_screen("match", {"teams": 6, "squad": squad, "tier": 0, "seed": seed_v, "autoplay": true, "probe": true, "god": true, "plan_t": 3.0})

func _process(_delta: float) -> void:
	if _end:
		return
	var now := Time.get_ticks_usec()
	var wall := (now - last_us - _walk_us) / 1000.0
	_walk_us = 0
	var marks := PerfLog.between(last_us, now)
	last_us = now
	var c0 := Time.get_ticks_usec()
	var new_c := _cache_count()
	_compiles += new_c
	_walk_us += Time.get_ticks_usec() - c0
	if m == null:
		load_compiles += new_c
		load_frames.append({"wall": wall, "marks": marks})
		var cur = Game.main.current
		if cur is Match and (cur as Match).is_processing() and (cur as Match).hud != null:
			m = cur
			m.set_process(false)
			load_ms = (now - started_us) / 1000.0
			phase = "first"
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
	var t0 := Time.get_ticks_usec()
	m.step(DT)
	var t1 := Time.get_ticks_usec()
	for i in k - 1:
		m.step(DT)
	var t2 := Time.get_ticks_usec()
	m._process(DT if k == 1 else 0.0)
	var t3 := Time.get_ticks_usec()
	var rec := {"phase": phase, "t": m.time, "k": k, "sim": (t1 - t0) / 1000.0, "sim_extra": (t2 - t1) / 1000.0,
		"vis": (t3 - t2) / 1000.0, "proc_total": (t3 - t0) / 1000.0, "wall": 0.0, "new": [], "marks": [], "t_end": t3}
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
			if phase_t >= 3.0:
				_finish()
	if m.time > 200.0 and not _end:
		print("HITCH stuck in phase ", phase)
		_finish()

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
	var bdesc := ("headless script %.0f ms" % (budget_ms if budget_ms > 0.0 else 50.0)) if headless else (("software: 2.5x the frames around it and +1.2 s") if software and budget_ms <= 0.0 else ("%.0f ms" % (budget_ms if budget_ms > 0.0 else 100.0)))
	lines.append("HITCH budget %s; worst judged frame at %.2f of budget; %s" % [bdesc, worst_j, "PASS" if fails == 0 else "FAIL (%d frames)" % fails])
	var txt := "\n".join(lines)
	print(txt)
	if out_path != "":
		var fa := FileAccess.open(out_path, FileAccess.WRITE)
		if fa: fa.store_string(txt + "\n")
	get_tree().quit(0 if fails == 0 else 1)
