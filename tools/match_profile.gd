extends "res://tools/hitch_check.gd"
## --match-profile: a real 30-hunter expedition (ten squads of three, as the queue builds one) timed frame by
## frame at 1920x1080 for owner perf passes: the skyship ride and the drop, landing, a fight with every hunter
## brought round you, then an uplink charged and the lift taken. One sim step per frame (hitch-check
## fast-forwards the ride and the drop). Per phase: frame ms p50/p95/p99/max, the split (sim, visuals,
## other scripts, render submit, physics, rest = swap/driver/GPU wait), GPU ms, draws, CPU or GPU bound; then
## every frame over HITCH_MS with what it was spent on (shader compiles, first draws, sim sections, nodes
## spawned: UI or VFX, build steps). GDScript has no GC (reference counting), so no GC column.
##   jobq submit --needs gpu --only <worker> --tree <tree> -- --match-profile [--profile-view=1920x1080]
##   [--quality=...] [--hitch-seed=4101]
## Reports only: exits 0 once the match is done (or 1 if it never got to the extraction).

const VIEW := Vector2i(1920, 1080)
const HITCH_MS := 33.0  # ms: a frame past two vsyncs at 60 Hz is a visible hitch
const LAND_WAIT_S := 12.0  # s on the ground at most waiting for the last bots to land before the fight
const FIGHT_S := 15.0  # s of game time with all 30 hunters on top of you
const EXTRACT_S := 25.0  # s the uplink and the lift may take before the run gives up
const CHARGE_S := 6.0  # s the uplink charges (monster waves, a contested yard) before its lift opens
const AFTER_S := 3.0  # s run on after you rode the lift, unless the match ends first (1.6 s real time)
const FIGHT_R := Vector2(5.0, 14.0)  # m: the ring the other hunters are put on
const FAR_M := 60.0  # m from the camera: an emitter this far off is out of any view the match uses
const PHASES := ["ride", "drop", "land", "fight", "extract"]

var _added := {}  # "Control"/"VFX"/"3D"/"other" -> nodes that entered the tree this frame
var _pipes := 0  # pipeline compilations so far (Forward+/Mobile; Compatibility counts none)
var _bench = preload("res://tools/perf_bench.gd").new()  # its HUD draw hook (hud_us: the last canvas draw)
var _uplink := {}
var _rode_at := -1.0
var _hunters := 0


func run(main_node: Node) -> void:
	main_node.add_child(self)


func _ready() -> void:
	teams = int(ceil(Data.MATCH_PLAYERS / 3.0))
	fast_forward = false
	var view := VIEW
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--profile-view="):
			var wh := a.substr(15).split("x")
			view = Vector2i(int(wh[0]), int(wh[1]))
	get_window().size = view
	get_tree().node_added.connect(_on_added)
	super._ready()


func _on_added(n: Node) -> void:
	var k := "3D"
	if n is Control or n is CanvasLayer:
		k = "UI"
	elif n is GPUParticles3D or n is CPUParticles3D:
		k = "VFX"
	elif n is MeshInstance3D and n.get_parent() and String(n.get_parent().name).contains("Fx"):
		k = "VFX"
	elif not n is Node3D:
		k = "other"
	_added[k] = int(_added.get(k, 0)) + 1


func _process(delta: float) -> void:
	if _rode_at >= 0.0 and not _end and (not is_instance_valid(m) or m.over):
		_finish()  # the match ended behind the lift (Match._end_soon): what came before it is the report
		return
	if m != null and not frames.is_empty() and not _end:
		var lf: Dictionary = frames[-1]
		lf["phys"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		lf["gpu"] = RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
		lf["added"] = _added.duplicate()
		if _bench.vp != vp_rid:
			_bench.vp = vp_rid
			_bench._hook_hud(m)
		lf["hud"] = _bench.hud_us / 1000.0
		var p := 0
		for info in [
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE
		]:
			p += RenderingServer.get_rendering_info(info)
		lf["pipes"] = p - _pipes
		_pipes = p
	_added.clear()
	super._process(delta)


## Each phase's line as it ends too, so a run cut short still reports the phases it got through.
func _set_phase(p: String) -> void:
	var fl: Array = frames.filter(func(f): return f["phase"] == phase and float(f["wall"]) > 0.0)
	if phase in PHASES and not fl.is_empty():
		print(_phase_line(phase, fl))
	super._set_phase(p)


func _next_phase() -> void:
	var P: Hunter = m.player
	match phase:
		"land":
			if phase_t >= 1.0 and not _pack_done:
				_pack_done = true
				_bring_pack()
			var up := m.hunters.any(func(h): return h.riding or h.dropping)
			if phase_t >= 3.0 and (not up or phase_t >= LAND_WAIT_S):
				_set_phase("fight")
				_bring_hunters()
		"fight":
			if phase_t >= FIGHT_S:
				_set_phase("extract")
				_start_uplink()
		"extract":
			if phase_t >= CHARGE_S and String(_uplink.get("state", "")) == "charging":
				_uplink["prog"] = 1.0  # a brawl round the yard contests it: the lift opens anyway
			if not P.extracted:
				P.hp = P.max_hp
				var at: Vector3 = _uplink.get("pos", P.pos)
				if P.flat_dist(at) > 0.5:
					P.teleport(at)  # (autoplay would walk off the lift)
			elif _rode_at < 0.0:
				_rode_at = phase_t
				print("HITCH rode the lift at t=%.2f" % m.time)
			if (_rode_at >= 0.0 and phase_t >= _rode_at + AFTER_S) or phase_t >= EXTRACT_S:
				_finish()
		_:
			super._next_phase()
	if m.time > 400.0 and not _end:
		print("HITCH stuck in phase ", phase)
		_finish()


## Every other hunter still in the match is put on a ring round you: a 30-hunter brawl.
func _bring_hunters() -> void:
	var P: Hunter = m.player
	var others: Array = m.hunters.filter(
		func(h): return h != P and not h.out and not h.extracted and not h.riding and not h.dropping
	)
	for i in others.size():
		var a := TAU * i / maxf(1.0, others.size())
		var r := lerpf(FIGHT_R.x, FIGHT_R.y, float(i % 3) / 2.0)
		var at: Vector3 = m.world.free_spot_near(P.pos + Vector3(cos(a), 0, sin(a)) * r, [], 0.6, 0.5, 8.0)
		var h: Hunter = others[i]
		h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	_hunters = m.hunters.size()
	print("HITCH fight: %d hunters round you at t=%.2f" % [others.size(), m.time])
	_census()


## The nodes running a _process of their own (the "other scripts" column), by script or class.
func _census() -> void:
	var by := {}
	for n in get_tree().root.find_children("*", "", true, false):
		if not n.is_processing() and not n.is_physics_processing() and not n.is_processing_internal():
			continue
		var sc: Script = n.get_script()
		var k: String = sc.resource_path.get_file() if sc and sc.resource_path != "" else n.get_class()
		by[k] = int(by.get(k, 0)) + 1
	var ks := by.keys()
	ks.sort_custom(func(a, b): return by[a] > by[b])
	print("PROFILE processing nodes: " + ", ".join(ks.slice(0, 16).map(func(k): return "%s %d" % [k, by[k]])))
	var cam := get_viewport().get_camera_3d()
	var em := {}  # parent -> [emitting CPU particle systems, their particles, how many past FAR_M from the camera]
	for n in get_tree().root.find_children("*", "CPUParticles3D", true, false):
		var p := n as CPUParticles3D
		if not p.emitting or not p.is_visible_in_tree():
			continue
		var up := p.get_parent()
		var k := "%s/%s" % [String(up.get_parent().name).rstrip("0123456789@"), String(up.name).rstrip("0123456789@")]
		var e: Array = em.get(k, [0, 0, 0])
		e[0] += 1
		e[1] += p.amount
		if cam and cam.global_position.distance_to(p.global_position) > FAR_M:
			e[2] += 1
		em[k] = e
	var ek := em.keys()
	ek.sort_custom(func(a, b): return em[a][1] > em[b][1])
	print(
		(
			"PROFILE emitting CPU particles by parent (systems, particles, past %.0f m): " % FAR_M
			+ ", ".join(ek.slice(0, 14).map(func(k): return "%s: %d, %d, %d" % [k, em[k][0], em[k][1], em[k][2]]))
		)
	)


## Your squad's uplink started with you on its lift spot, nearly charged, so the waves come, it opens and you ride.
func _start_uplink() -> void:
	var P: Hunter = m.player
	_uplink = m.exits.uplink_x() if m.exits else {}
	if _uplink.is_empty():
		print("HITCH no uplink on this map")
		return
	P.teleport(_uplink["pos"])
	m.exits.act(_uplink, "start", P, true)
	_uplink["prog"] = 0.9
	_uplink["wave_t"] = 0.0
	print("HITCH uplink started at %s t=%.2f" % [_uplink["name"], m.time])


func _finish() -> void:
	_end = true
	if not frames.is_empty() and float(frames[-1]["wall"]) <= 0.0:
		frames.pop_back()
	var lines: Array = []
	lines.append(
		(
			"PROFILE renderer=%s driver=%s adapter=%s window=%s quality=%s hunters=%d"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_current_rendering_driver_name(),
				RenderingServer.get_video_adapter_name(),
				str(get_window().size),
				str(Settings.get_v("quality")),
				_hunters
			]
		)
	)
	lines.append("PROFILE load %.0f ms, %d shader compiles while loading" % [load_ms, load_compiles])
	lines.append(
		(
			"PROFILE phase  frames   p50   p95   p99    max  >33ms | sim  vis other rend phys rest  gpu  hud "
			+ "| draws  bound"
		)
	)
	lines.append("PROFILE   (medians, ms; hud is the HUD's canvas draw, inside other or rest)")
	for ph in PHASES:
		var fl: Array = frames.filter(func(f): return f["phase"] == ph)
		if not fl.is_empty():
			lines.append(_phase_line(ph, fl))
	var tally := {}
	var hitches: Array = frames.filter(func(f): return float(f["wall"]) > HITCH_MS and f["phase"] in PHASES)
	for f in hitches:
		var c := _cause(f)
		var kind := c.get_slice(":", 0)
		tally["%s/%s" % [f["phase"], kind]] = int(tally.get("%s/%s" % [f["phase"], kind], 0)) + 1
	var tk := tally.keys()
	tk.sort_custom(func(a, b): return tally[a] > tally[b])
	lines.append(
		(
			"PROFILE hitches over %.0f ms by phase/cause: %s"
			% [HITCH_MS, ", ".join(tk.map(func(k): return "%s %d" % [k, tally[k]]))]
		)
	)
	hitches.sort_custom(func(a, b): return a["wall"] > b["wall"])
	for f in hitches.slice(0, 25):
		lines.append("PROFILE   %5.0f ms %-7s t=%6.2f  %s" % [float(f["wall"]), f["phase"], float(f["t"]), _cause(f)])
	var txt := "\n".join(lines)
	print(txt)
	if out_path != "":
		var fa := FileAccess.open(out_path, FileAccess.WRITE)
		if fa:
			fa.store_string(txt + "\n")
	get_tree().quit(0 if _rode_at >= 0.0 else 1)


func _phase_line(ph: String, fl: Array) -> String:
	var w: Array = fl.map(func(f): return float(f["wall"]))
	w.sort()
	var pc := func(q: float) -> float: return w[mini(w.size() - 1, int(w.size() * q))]
	var over := w.filter(func(x): return x > HITCH_MS).size()
	var a := {}
	for k in ["sim", "vis", "other", "render", "phys", "rest", "gpu", "hud", "draws"]:
		a[k] = _median(fl, k)
	var cpu: float = a["sim"] + a["vis"] + a["other"] + a["render"] + a["phys"]
	var bound := "GPU" if a["gpu"] > cpu else "CPU"
	var fmt := "PROFILE %-7s %5d %5.1f %5.1f %5.1f %6.1f %5d | " + "%4.1f ".repeat(8) + "| %5.0f  %s"
	var line := (
		fmt
		% [
			ph,
			fl.size(),
			pc.call(0.5),
			pc.call(0.95),
			pc.call(0.99),
			w[-1],
			over,
			a["sim"],
			a["vis"],
			a["other"],
			a["render"],
			a["phys"],
			a["rest"],
			a["gpu"],
			a["hud"],
			a["draws"],
			bound
		]
	)
	for key in ["secs", "vsecs"]:  # the average ms per frame of each sim / visuals section
		var tot := {}
		for f in fl:
			for k in f.get(key, {}):
				tot[k] = int(tot.get(k, 0)) + int(f[key][k])
		var ks := tot.keys()
		ks.sort_custom(func(x, y): return tot[x] > tot[y])
		line += (
			"\nPROFILE   %s %s: %s"
			% [
				ph,
				"sim" if key == "secs" else "visuals",
				", ".join(ks.slice(0, 8).map(func(k): return "%s %.2f" % [k, tot[k] / 1000.0 / fl.size()]))
			]
		)
	return line


## What a slow frame was spent on: its biggest part, named as finely as the frame's record allows.
func _cause(f: Dictionary) -> String:
	var parts := {
		"sim": float(f["sim"]),
		"visuals": float(f["vis"]),
		"scripts": float(f.get("other", 0.0)),
		"render": float(f.get("render", 0.0)),
		"physics": float(f.get("phys", 0.0)),
		"gpu/driver": maxf(0.0, float(f.get("rest", 0.0)) - float(f.get("phys", 0.0)))
	}
	var top := "sim"
	for k in parts:
		if parts[k] > parts[top]:
			top = k
	var compiles := int(f.get("compiles", 0)) + int(f.get("pipes", 0))
	var kind := top
	if compiles > 0 and top in ["render", "gpu/driver"]:
		kind = "shader compile"
	elif not (f["marks"] as Array).is_empty():
		kind = "build step"
	elif top in ["render", "gpu/driver"] and not (f["new"] as Array).is_empty():
		kind = "first draw"
	elif top == "scripts" and int(f.get("added", {}).get("UI", 0)) > 0:
		kind = "UI build"
	elif int(f.get("added", {}).get("VFX", 0)) > 4 and top != "sim":
		kind = "VFX spawn"
	var s := "%s: " % kind + ", ".join(parts.keys().map(func(k): return "%s %.1f" % [k, parts[k]]))
	s += " (hud draw %.1f)" % float(f.get("hud", 0.0))
	s += (
		"  compiles %d, new materials %d, nodes added %s"
		% [compiles, (f["new"] as Array).size(), str(f.get("added", {}))]
	)
	for key in ["secs", "vsecs"]:
		var d: Dictionary = f.get(key, {})
		if d.is_empty() or float(f["sim" if key == "secs" else "vis"]) < 8.0:
			continue
		var ks := d.keys()
		ks.sort_custom(func(x, y): return d[x] > d[y])
		s += "  %s: %s" % [key, ", ".join(ks.slice(0, 4).map(func(k): return "%s %.1f" % [k, d[k] / 1000.0]))]
	if not (f["marks"] as Array).is_empty():
		s += "  steps: " + ", ".join((f["marks"] as Array).map(func(mk): return "%s %.0f" % [mk[1], mk[2]]))
	for nm in (f["new"] as Array).slice(0, 3):
		s += "  [first: %s]" % nm
	return s
