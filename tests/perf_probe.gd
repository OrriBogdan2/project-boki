extends Node
## Tooling (--perf-probe): plays one scripted expedition the way a player gets it (loading screen,
## planning map, skyship ride, the jump and glide down, landing, a look at the full map, a fight)
## and logs per phase: wall frame time, script time, draw calls, objects, primitives, memory, and the
## worst hitches with the build steps (PerfLog marks) that ran inside them.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --audio-driver Dummy -- --perf-probe
##   [--probe-out=/path/report.txt] [--probe-quick] [--probe-squad=3] [--probe-teams=40] [--quality=high]
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
var _added := {}            # nodes that entered the tree since the last frame, by class:name (named on the worst frames)
var casters := {}           # phase -> [shadow casters in the tree, casters within the sun's shadow distance]

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe-out="): out_path = a.substr(12)
		if a == "--probe-quick": quick = true
	vp_rid = get_viewport().get_viewport_rid()
	get_tree().node_added.connect(func(n: Node):
		var k := "%s:%s" % [n.get_class(), String(n.name).rstrip("0123456789@")]
		_added[k] = int(_added.get(k, 0)) + 1)
	Match.prof_on = true
	# a software rasterizer spends most of a frame filling pixels: a small window and no MSAA keep
	# the probe quick, and change none of the counts (draws, objects, primitives) or the CPU times
	if not "--probe-full" in OS.get_cmdline_user_args():
		get_window().size = Vector2i(640, 360)
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		Settings.v["msaa"] = 0
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	process_priority = -100
	Save.no_write = true      # never touches the dev save (the music list would write it)
	Save.d["tutorial"]["home"] = true
	var squad := 1
	var teams := 6       # --probe-teams=N: a full lobby (Data.MATCH_PLAYERS) for before/after match-size runs
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe-squad="): squad = int(a.substr(14))
		if a.begins_with("--probe-teams="): teams = int(a.substr(14))
	started_us = Time.get_ticks_usec()
	last_us = started_us
	Game.main.show_screen("match", {"teams": teams, "squad": squad, "tier": 0, "seed": 4101, "autoplay": true, "probe": true, "god": true})

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
		"d3d": RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"dsh": RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"dcv": RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"objs": _rinfo(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), "prims": _rinfo(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"rcpu": RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) + RenderingServer.get_frame_setup_time_cpu(),
		"hud": hud_us / 1000.0, "marks": marks, "t": m.time, "new": _added.duplicate() if wall > 60.0 else {}}
	_added.clear()
	if not frames.is_empty():
		frames[-1].merge({"draws": rec["draws"], "objs": rec["objs"], "prims": rec["prims"], "rcpu": rec["rcpu"], "d3d": rec["d3d"], "dsh": rec["dsh"], "dcv": rec["dcv"]}, true)
	# advance the match: quiet stretches run several steps per drawn frame so the probe stays short
	var k := 1
	match phase:
		"planning", "ride": k = 6
		"drop": k = 3
	var t0 := Time.get_ticks_usec()
	if k == 1:
		# the simulation step and the per-frame visuals (interpolation, animation, camera) apart
		m.step(DT)
		var t1 := Time.get_ticks_usec()
		m._process(0.0)
		rec["sim"] = (t1 - t0) / 1000.0
		rec["vis"] = (Time.get_ticks_usec() - t1) / 1000.0
	else:
		m._process(DT * k)
	var proc := (Time.get_ticks_usec() - t0) / 1000.0
	rec["proc"] = proc / k
	rec["steps"] = k
	frames.append(rec)
	phase_t += DT * k
	var nf: int = frames.filter(func(f): return f["phase"] == phase).size()
	if nf == 12:
		_casters()
		if phase in ["planning", "drop", "land", "fight"]:
			_breakdown()
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

## Shadow casters: every visible mesh that casts, and those within the sun's shadow distance of the
## camera (what the shadow pass can draw; a software GL renderer reports no shadow draws of its own).
## The near ones are listed by owner (the node under the match) and name with --probe-casters.
func _casters() -> void:
	var cam := get_viewport().get_camera_3d()
	var dist := 0.0
	for n in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		if (n as DirectionalLight3D).shadow_enabled and (n as Node3D).is_visible_in_tree():
			dist = maxf(dist, (n as DirectionalLight3D).directional_shadow_max_distance)
	var all := 0
	var near := 0
	var groups := {}
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or not gi.is_visible_in_tree():
			continue
		all += 1
		if cam == null or cam.global_position.distance_to((gi.global_transform * gi.get_aabb()).get_center()) > dist:
			continue
		near += 1
		if "--probe-casters" in OS.get_cmdline_user_args():
			# owner: the nearest ancestor with a named script class (Hunter, Mob, Kin, World, Fx ...)
			var own := "?"
			var up: Node = gi.get_parent()
			while up:
				var sc: Script = up.get_script()
				if sc and sc.get_global_name() != "":
					own = "%s/%s" % [sc.get_global_name(), String(up.name).rstrip("0123456789@_")]
					break
				up = up.get_parent()
			var k := "%s .. %s:%s" % [own, gi.get_class(), String(gi.name).rstrip("0123456789@_")]
			groups[k] = int(groups.get(k, 0)) + 1
	casters[phase] = [all, near]
	print("PROBE casters %s: %d in the tree, %d within %.0f m of the camera" % [phase, all, near, dist])
	var ks := groups.keys()
	ks.sort_custom(func(a, b): return groups[a] > groups[b])
	for k in ks.slice(0, 40):
		print("PROBE   caster %5d  %s" % [groups[k], k])

## What's on screen right now, grouped by node name (chunk numbers stripped): instances in view,
## draws they make (outline passes and shadows counted), triangles. Approximate: frustum test on the
## bounding box, visibility ranges honoured.
func _breakdown() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var planes := cam.get_frustum()
	var cpos := cam.global_position
	var groups := {}
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children(): stack.append(ch)
		if not (n is GeometryInstance3D) or not (n as Node3D).is_visible_in_tree():
			continue
		var gi := n as GeometryInstance3D
		var mesh: Mesh = null
		var inst := 1
		if gi is MeshInstance3D: mesh = (gi as MeshInstance3D).mesh
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh:
			mesh = (gi as MultiMeshInstance3D).multimesh.mesh
			inst = (gi as MultiMeshInstance3D).multimesh.instance_count
		elif gi is CPUParticles3D: mesh = (gi as CPUParticles3D).mesh; inst = (gi as CPUParticles3D).amount
		if mesh == null:
			continue
		var ab := gi.global_transform * gi.get_aabb()
		var inside := true
		for pl in planes:
			# the frustum's planes face out: the box is outside if even its corner furthest inward is over one
			var nv := ab.position + Vector3(ab.size.x if pl.normal.x < 0.0 else 0.0, ab.size.y if pl.normal.y < 0.0 else 0.0, ab.size.z if pl.normal.z < 0.0 else 0.0)
			if pl.distance_to(nv) > 0.0:
				inside = false; break
		if not inside:
			continue
		if gi.visibility_range_end > 0.0 and cpos.distance_to(ab.get_center()) > gi.visibility_range_end:
			continue
		var tris := 0
		for si in mesh.get_surface_count():
			var il := 0
			if mesh is ArrayMesh: il = (mesh as ArrayMesh).surface_get_array_index_len(si)
			tris += (il if il > 0 else ((mesh as ArrayMesh).surface_get_array_len(si) if mesh is ArrayMesh else 300)) / 3
		var mat: Material = gi.material_override
		var passes := mesh.get_surface_count() * (2 if mat and mat.next_pass else 1)
		var nm := String(n.name)
		var parts := nm.split("_")
		if parts.size() >= 3 and parts[-1].is_valid_int() and parts[-2].is_valid_int(): nm = "_".join(parts.slice(0, -2))
		nm = nm.rstrip("0123456789@")
		if nm == "" or nm.begins_with("@"): nm = gi.get_class() + ":" + String(n.get_parent().name).rstrip("0123456789@")
		var g: Array = groups.get(nm, [0, 0, 0, 0])
		g[0] += 1; g[1] += passes; g[2] += tris * inst
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: g[3] += 1
		groups[nm] = g
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a][1] > groups[b][1])
	var tot := [0, 0, 0, 0]
	for k in keys:
		for i in 4: tot[i] += groups[k][i]
	print("PROBE breakdown %s: %d nodes, %d draws, %dk tris, %d shadow casters (top groups: name nodes draws tris_k casters)" % [phase, tot[0], tot[1], tot[2] / 1000, tot[3]])
	for k in keys.slice(0, 22):
		var g: Array = groups[k]
		print("PROBE   %-28s %5d %5d %7.1f %5d" % [k, g[0], g[1], g[2] / 1000.0, g[3]])

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
			hud_us = Time.get_ticks_usec() - t0 + h.panels.used_us      # (the panel canvas: HudPanels)
			h.panels.used_us = 0)
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
	var si := _stats(fl, "sim"); var vi := _stats(fl, "vis"); var hd := _stats(fl, "hud")
	print("PROBE phase %s draws by pass: 3D %.0f, shadows %.0f, canvas (HUD) %.0f" % [ph, _stats(fl, "d3d")[0], _stats(fl, "dsh")[0], _stats(fl, "dcv")[0]])
	if ph in ["land", "fight"] and not Match.prof.is_empty():
		var tot := 0
		for k in Match.prof: tot += int(Match.prof[k])
		var ks := Match.prof.keys()
		ks.sort_custom(func(a, b): return Match.prof[a] > Match.prof[b])
		var nsteps := maxi(1, fl.size())
		print("PROBE step sections %s (ms per step): %s" % [ph, ", ".join(ks.map(func(k): return "%s %.2f" % [k, Match.prof[k] / 1000.0 / nsteps]))])
	Match.prof.clear()
	print("PROBE phase %s: %d frames, wall avg %.1f max %.1f ms, script %.2f ms (sim %.2f, visuals %.2f, hud draw %.2f), draws %.0f (max %.0f), prims %.0fk" % [ph, fl.size(), w[0], w[3], pr[0], si[0], vi[0], hd[0], dr[0], dr[3], pm[0] / 1000.0])

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
	lines.append("PROBE %-9s %6s %8s %8s %8s %8s %8s %7s %7s %9s %8s %11s" % ["phase", "frames", "wall_avg", "wall_p95", "wall_max", "script", "scr_max", "rcpu", "hud", "draws", "prims_k", "casters"])
	for ph in ["first", "planning", "ride", "drop", "land", "map", "fight"]:
		var fl: Array = frames.filter(func(f): return f["phase"] == ph)
		if fl.is_empty(): continue
		var w := _stats(fl, "wall"); var pr := _stats(fl, "proc"); var rc := _stats(fl, "rcpu"); var hd := _stats(fl, "hud")
		var dr := _stats(fl, "draws"); var pm := _stats(fl, "prims")
		var ca: Array = casters.get(ph, [0, 0])
		lines.append("PROBE %-9s %6d %8.1f %8.1f %8.1f %8.2f %8.2f %7.2f %7.2f %4.0f/%4.0f %8.0f %5d/%5d" % [ph, fl.size(), w[0], w[2], w[3], pr[0], pr[3], rc[0], hd[0], dr[0], dr[3], pm[0] / 1000.0, ca[0], ca[1]])
	# hitches: the slowest frames after loading, against the median of their phase
	var after := frames.duplicate()
	after.sort_custom(func(a, b): return a["wall"] > b["wall"])
	lines.append("PROBE worst frames (wall ms, script ms, render cpu ms, phase, sim t, build steps inside):")
	for f in after.slice(0, 8):
		lines.append("PROBE   %7.1f %7.2f %7.1f hud %5.1f %-9s t=%5.1f %s" % [f["wall"], f.get("proc", 0.0), f.get("rcpu", 0.0), f.get("hud", 0.0), f["phase"], f.get("t", 0.0), ", ".join((f["marks"] as Array).map(func(mk): return "%s %.0f" % [mk[1], mk[2]]))])
		if not (f.get("new", {}) as Dictionary).is_empty():
			lines.append("PROBE           new nodes: %s" % str(f["new"]))
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
