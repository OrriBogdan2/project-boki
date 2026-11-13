extends RefCounted
## --perf-bench, owner item 94: a fixed, repeatable load for before/after numbers. A 60 s busy
## expedition (6 Hunters in squads of 2 with their Boki, the ash storm, the Blight, outposts and a lair
## on the map, a fight: two rivals and a monster pack brought to you), then a farm run, the base demo
## (BaseDemo plus two Boki: 6 Boki, toys, snacks, an egg) with a Dash run at BASE_RACE_AT, and a hub run. Every frame is
## logged; each part ends with summary lines and the costliest match step sections and meshes, and a
## frame over 33 ms and 2x the 30 before it names the nodes that entered the tree in it.
##   timeout 1200 xvfb-run -a godot --rendering-driver opengl3 --audio-driver Dummy -- --perf-bench
##   [--bench-secs=60] [--bench-farm=20] [--bench-base=60] [--bench-out=/path/frames.csv] [--quality=medium]
##   [--bench-view=2560x1440]  (GPU runs: the window size, so render scale and fill cost show)
##   [--bench-shots=<dir>]  saves each zone part's default-camera frame (screen UI hidden) as <part>.jpg
##   [--bench-zone=<garden zone id or all>]  adds a "zone_<id>" part per zone: nine Boki out (6 residents,
##   the partner, 2 visitors), judged against the budget in content/rules/garden_zones.json ("BENCH budget"
##   lines say ok or FAIL, and the run exits 1 on any FAIL); the hub part is judged against the hub budget
## Software GL makes wall time mostly raster time: compare script ms, draws, tris and nodes between runs.
## The gate: a match p99 over P99_SLACK times the one recorded for this adapter, load, quality and length in
## tools/perf_baseline.json exits 1 (BENCH GATE FAIL). Record a new baseline by editing that file from a run.

const DT := 1.0 / 60.0
var view := Vector2i(640, 360)     # small window: a software rasterizer's fill time; counts are the same
const FIGHT_AT := 8.0               # s: when the fight is brought to you
const BASE_RACE_AT := 10.0          # s into the base part: the Dash starts
const SLOW_MS := 50.0               # ms: the DECISIONS 2026-11-08 ceiling for a frame after warm-up
const WARM_S := 3.0                 # s of the base part treated as warm-up
const SECTION_FRAMES := 120         # frames the base part's step timing samples
const MOBS := ["skitter", "brute", "spitter", "skitter", "bomber", "skitter"]

const BOKI_OUT := 9              # GARDEN.md 10.6: 6 residents + partner + 2 visitors
const VISITORS := ["zapple", "burrlet", "cindle"]   # species of the Boki past the nav sweep's six
const LIFE_STEPS := 100          # 10 Hz base_life steps timed for the script line (10 s of base life)
const NavCheck := preload("res://tools/garden_nav_check.gd")

var main: Node
var secs := 60.0
var farm_secs := 20.0
var base_secs := 60.0
var out_path := ""
var zone := ""
var shots_dir := ""      # --bench-shots=<dir>: each budgeted part's default-camera frame, UI hidden, as <part>.jpg
var failed := false      # a budget line said FAIL: the exit code carries it
var rows := PackedStringArray()
var hud_us := 0
var added := {}          # node name -> count, nodes that entered the tree this frame (named on a hitch)
const SLOW_MS := 33.0               # a frame over this counts as a hitch in the summary (under 30 fps)
const BASELINE := "res://tools/perf_baseline.json"
const P99_SLACK := 1.15             # the gate: match p99 may be at most 15% over the baseline
var match_p99 := 0.0
var vp: RID

func run(main_node: Node) -> void:
	setup(main_node)
	await _match()
	await _farm("farm", {})
	await _base()
	await _farm("hub", {"zone": GardenZones.HUB})
	var zones: Array = [zone] if zone != "" else []
	if zone == "all": zones = GardenZones.built()
	for id in zones:
		await _zone(id)
	_finish()

## Reads the --bench-* arguments and sizes the window; --perf-budget-check shares it.
func setup(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bench-secs="): secs = float(a.substr(13))
		if a.begins_with("--bench-farm="): farm_secs = float(a.substr(13))
		if a.begins_with("--bench-base="): base_secs = float(a.substr(13))
		if a.begins_with("--bench-out="): out_path = a.substr(12)
		if a.begins_with("--bench-view="):
			var wh := a.substr(13).split("x")
			view = Vector2i(int(wh[0]), int(wh[1]))
		if a.begins_with("--bench-zone="): zone = a.substr(13)
		if a.begins_with("--bench-shots="): shots_dir = a.substr(14)
	Save.no_write = true
	Save.d["tutorial"]["home"] = true
	main.get_window().size = view
	main.get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	vp = main.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	rows.append("part,frame,wall_ms,script_ms,process_ms,hud_ms,render_cpu_ms,gpu_ms,draws,tris,objects,nodes")

func _finish() -> void:
	var win := main.get_window()
	print("BENCH hunters=%d boki_wisps=%s quality=%s renderer=%s adapter=%s window=%dx%d 3d_scale=%.2f" % [hunters,
		wisps, Settings.quality(),
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), win.size.x,
		win.size.y, win.scaling_3d_scale])
	if out_path != "":
		var fa := FileAccess.open(out_path, FileAccess.WRITE)
		if fa: fa.store_string("\n".join(rows) + "\n")
	main.get_tree().quit(1 if failed else 0)

func _match() -> Array:
	var o := Match.demo_opts()
	o.merge({"teams": teams, "squad": squad, "total": hunters, "raid": "ash", "blight": true,
		"no_drop": true, "god": true, "autoplay": true, "demo_kin": "cindle", "seed": 4101, "boki_wisps": wisps}, true)
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
	_emitters()
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
	return fl

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

func _farm(part: String, params: Dictionary) -> void:
	if part == "hub": Content.rules("farm_build")["base_mode"] = true      # the hub only exists in base mode
	var was = main.current
	Game.goto("home", params)
	while main.current == was or main.current == null or main.current.get("root_ui") == null or main.fade.covered:
		await main.get_tree().process_frame      # the home is built and the ink wipe is off it
	for i in 30:
		await main.get_tree().process_frame
	await _frames(part)
	if part == "hub":      # same scene, horizon hidden: the islands' own cost (GARDEN 10.7 step 9)
		for n in Game.main.current.get_children():
			if String(n.name).begins_with("Horizon_"): n.visible = false
		await _frames("hub_bare")

func _frames(part: String) -> void:
	var fl: Array = []
	var last := Time.get_ticks_usec()
	var t := 0.0
	while t < farm_secs:
		await main.get_tree().process_frame
		var now := Time.get_ticks_usec()
		var wall := (now - last) / 1000.0
		last = now
		fl.append(_frame(part, fl.size(), wall, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0))
		t += DT
	_summary(part, fl)
	_meshes()
	if part != "farm" and part != "hub_bare":
		await _budget(part, fl)
		_vfx_inventory(part)

## A garden zone with nine Boki out (GARDEN.md 10.6: 6 residents, the partner, 2 visitors), as a farm part.
func _zone(id: String) -> void:
	var nav := NavCheck.new()
	nav.main = main
	nav.zone = "" if id == GardenZones.start() else id
	FarmUnlocks.rules()["base_mode"] = true
	nav._save()
	for i in BOKI_OUT - Save.d["roster"].size():
		var rec := Save.new_kin(VISITORS[i % VISITORS.size()], "V%d" % i)
		Care.ensure(rec)
		rec["zone"] = id
		Save.d["roster"].append(rec)
	await _farm("zone_" + id, {"zone": id})

## A part against GARDEN.md 10.6 (the hub against its own column). Draws and objects are the scene itself: the
## screen UI (a quarter to a half of a frame's draws, the same in every scene) is hidden for a few frames and
## read then. Nodes and the emitting particle systems are the whole tree's; the frame is the average of the run;
## base_life is the cost of one 10 Hz step with every Boki out, timed apart from the frame.
func _budget(part: String, fl: Array) -> void:
	var B: Dictionary = GardenZones.rules()["budget_hub" if part == "hub" else "budget"]
	var emit := 0
	for cls in ["GPUParticles3D", "CPUParticles3D"]:
		var all := main.get_tree().root.find_children("*", cls, true, false)
		emit += all.filter(func(n): return n.emitting and n.is_visible_in_tree()).size()
	var home = main.current
	home.root_ui.visible = false
	for cl in home.find_children("*", "CanvasLayer", true, false):
		cl.visible = false
	for i in 8:
		await main.get_tree().process_frame
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
		main.get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [shots_dir, part], 0.9)
	var got := {"draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"nodes": _peak(fl, "nodes"), "emitters": emit, "frame_ms": _avg(fl, "wall"), "base_life_ms": _life_ms(home)}
	if Settings.quality() == "low": B = B.merged({"frame_ms": B["frame_ms_low"]}, true)
	print("BENCH %s boki out: %d, draws with the UI: %.0f" % [part, home.kins.size(), _avg(fl, "draws")])
	var held: Dictionary = GardenZones.rules()["ratchet"].get(Settings.quality(), {}).get(part, {})
	var bad := false
	for k in got:
		var over: bool = float(got[k]) > float(B[k])
		var limit: float = float(held.get(k, B[k]))      # a measured ceiling stands in until the target is met
		var good: bool = float(got[k]) <= limit
		bad = bad or not good
		var verdict := "ok"
		if not good: verdict = "FAIL (past the held %.1f)" % limit
		elif over: verdict = "over target, held at %.1f" % limit
		print("BENCH budget %s %s: %.2f of %.1f %s" % [part, k, got[k], B[k], verdict])
	failed = failed or bad
	print("BENCH budget %s: %s" % [part, "FAIL" if bad else "ok"])

## ms per 10 Hz BaseLife step with the home's Boki out (0 where the home has no base life, like the hub).
func _life_ms(home) -> float:
	if home.life == null:
		return 0.0
	var t0 := Time.get_ticks_usec()
	for i in LIFE_STEPS:
		home.life.step(1.0 / 10.0)
	return (Time.get_ticks_usec() - t0) / 1000.0 / LIFE_STEPS

func _peak(fl: Array, key: String) -> float:
	var m := 0.0
	for f in fl: m = maxf(m, float(f[key]))
	return m

## The base demo played for base_secs: the garden's Boki on their own (toys, snacks, naps) and a Dash.
func _base() -> void:
	var d := BaseDemo.save()
	for spec in [["burrlet", "Bean"], ["pebbit", "Gran"]]:
		var rec := Save.new_kin(spec[0], spec[1])
		Care.ensure(rec)
		d["roster"].append(rec)
	main.current.queue_free()
	var home = await main._hb_home()
	BaseDemo.new().stage(home)
	var fl: Array = []
	var last := Time.get_ticks_usec()
	var t := 0.0
	var raced := false
	hud_us = 0
	var slow := PackedStringArray()
	while t < base_secs:      # real seconds: the garden runs on the frame's own delta
		if not raced and t >= BASE_RACE_AT:
			home.hrace.use()
			raced = true
			print("BENCH base race started: %s" % (home.hrace.run != null))
		await main.get_tree().process_frame
		var now := Time.get_ticks_usec()
		fl.append(_frame("base", fl.size(), (now - last) / 1000.0, 0.0))
		if fl[-1]["wall"] > SLOW_MS and t > WARM_S:
			slow.append("%.1fs %.0fms" % [t, fl[-1]["wall"]])      # (printed at the end: a print can stall a frame)
		last = now
		t += fl[-1]["wall"] / 1000.0
	_summary("base", fl)
	print("BENCH base slow frames after warm-up: ", ", ".join(slow.slice(0, 24)))
	await _sections(home)
	_meshes()

## The costliest per-frame steps of the garden: home._process off, its steps timed by hand for SECTION_FRAMES.
func _sections(home) -> void:
	var steps := {"sky": home._update_sky, "hover": func(_d): home._update_hover(), "move_kin": home._move_kin,
		"care": home._care_tick, "separate": home._separate_kin, "life": home.life.step, "econ": home.hecon.tick,
		"race": home.hrace.tick, "shove": home.hshove.tick,
		"seek": home.hseek.tick, "volley": home.hvolley.tick, "bubbles": home._update_bubbles, "gather": home.hg.tick,
		"snack": home.hsp.tick, "work": home.hw.tick, "incub": home.hinc.tick}
	var us := {}
	home.set_process(false)
	for i in SECTION_FRAMES:
		for k in steps:
			var t0 := Time.get_ticks_usec()
			steps[k].call(DT)
			us[k] = int(us.get(k, 0)) + Time.get_ticks_usec() - t0
		await main.get_tree().process_frame
	home.set_process(true)
	var ks := us.keys()
	ks.sort_custom(func(a, b): return us[a] > us[b])
	var top := ks.slice(0, 8).map(func(k): return "%s %.2f" % [k, us[k] / 1000.0 / SECTION_FRAMES])
	print("BENCH base steps (ms per frame): " + ", ".join(top))

func _frame(part: String, i: int, wall: float, script_ms: float) -> Dictionary:
	var f := {"wall": wall, "script": script_ms, "proc": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"hud": hud_us / 1000.0,
		"rcpu": RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
		"gpu": RenderingServer.viewport_get_measured_render_time_gpu(vp),
		"draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"tris": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"objs": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))}
	rows.append("%s,%d,%.2f,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%d,%d,%d" % [part, i, wall, script_ms, f["proc"], f["hud"],
		f["rcpu"], f["gpu"], f["draws"], f["tris"], f["objs"], f["nodes"]])
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
	var slow := w.filter(func(x): return x > SLOW_MS).size()
	print("BENCH %s: %d frames, wall avg %.1f ms, p99 %.1f ms (1%% low %.1f fps), max %.1f ms, over %.0f ms: %d" % [
		part, fl.size(), _avg(fl, "wall"), p99, 1000.0 / maxf(low, 0.001), w[-1], SLOW_MS, slow])
	var cpu_line := "BENCH %s cpu: match script avg %.2f ms p99 %.2f ms, process %.2f ms, hud %.2f ms, " + \
		"render cpu %.2f ms, gpu %.2f ms"
	print(cpu_line % [
		part, _avg(fl, "script"), sc99, _avg(fl, "proc"), _avg(fl, "hud"), _avg(fl, "rcpu"), _avg(fl, "gpu")])
	print("BENCH %s scene: draws %.0f, tris %.0fk, objs %.0f, nodes %.0f, fx %d, lights %d, shadowed %d, casters %d" % [
		part, _avg(fl, "draws"), _avg(fl, "tris") / 1000.0, _avg(fl, "objs"), _avg(fl, "nodes"),
		_count("GPUParticles3D") + _count("CPUParticles3D"), _count("Light3D"), _shadow_lights(), _casters()])
	print("BENCH %s memory: textures %.0f MB, buffers %.0f MB" % [part,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0])

## Particle systems still emitting (a GPU one simulates every frame even off screen), by owner name.
func _emitters() -> void:
	var by := {}
	for cls in ["GPUParticles3D", "CPUParticles3D"]:
		for n in main.get_tree().root.find_children("*", cls, true, false):
			if not n.get("emitting"):
				continue
			var up := String(n.get_parent().name).rstrip("0123456789@")
			var key := "%s/%s" % [up, String(n.name).rstrip("0123456789@")]
			by[key] = int(by.get(key, 0)) + 1
	var ks := by.keys()
	ks.sort_custom(func(a, b): return by[a] > by[b])
	print("BENCH emitting particles (%d): %s" % [by.values().reduce(func(a, b): return a + b, 0),
		", ".join(ks.slice(0, 10).map(func(k): return "%s %d" % [k, by[k]]))])

## Every particle system, Decal and see-through glow card of the part, grouped by owner path (the keep/cut list
## in docs/GARDEN_PERF.md starts from these lines): "BENCH vfx <part> <kind> <owner/name> xN (emitting or shown)".
func _vfx_inventory(part: String) -> void:
	var by := {}
	for n in main.current.find_children("*", "Node3D", true, false):
		var kind := _vfx_kind(n)
		if kind == "" or not n.is_visible_in_tree():
			continue
		var key := "%s %s" % [kind, _owner_path(n)]
		if kind == "emitter" and not "Aura" in key:
			key += " amount %d at %s" % [n.amount, (n as Node3D).global_position.snapped(Vector3.ONE * 0.5)]
		by[key] = int(by.get(key, 0)) + 1
	var ks := by.keys()
	ks.sort()
	for k in ks:
		print("BENCH vfx %s %s x%d" % [part, k, by[k]])

const FX_SHADERS := [      # the see-through light and glow shaders ("card" lines of the vfx inventory)
	"glow", "ring", "mote", "spark", "light_shaft", "waterfall", "updraft", "wind", "seat_beam", "exit_beam",
	"glowball", "fx_dot", "care_glow", "care_disc", "care_ice", "cloud_puff", "kin_aura", "boki_wisp", "wisp_core",
	"blob_shadow"]

func _vfx_kind(n: Node3D) -> String:
	if n is GPUParticles3D or n is CPUParticles3D:
		return "emitter" if n.emitting else ""
	if n is Decal:
		return "decal"
	if not n is GeometryInstance3D:
		return ""
	var mats: Array[Material] = [(n as GeometryInstance3D).material_override]
	var mesh: Mesh = null
	if n is MeshInstance3D:
		mesh = (n as MeshInstance3D).mesh
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
		mesh = (n as MultiMeshInstance3D).multimesh.mesh
	for i in (mesh.get_surface_count() if mesh != null else 0):
		mats.append(mesh.surface_get_material(i))
	for m in mats:
		var sm := m as ShaderMaterial
		if sm != null and sm.shader != null and sm.shader.resource_path.get_file().get_basename() in FX_SHADERS:
			return "card:" + sm.shader.resource_path.get_file().get_basename()
	return ""

func _owner_path(n: Node) -> String:
	var names := PackedStringArray()
	var cur := n
	while cur != null and names.size() < 4 and cur != main.get_tree().root:
		var nm := String(cur.name).rstrip("0123456789")
		names.append(cur.get_class() if nm.begins_with("@") else nm)
		cur = cur.get_parent()
	names.reverse()
	return "/".join(names)

func _count(cls: String) -> int:
	return main.get_tree().root.find_children("*", cls, true, false).size()

func _casters() -> int:
	var all := main.get_tree().root.find_children("*", "MeshInstance3D", true, false)
	var on := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return all.filter(func(m): return m.cast_shadow != on and m.is_visible_in_tree()).size()

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
	_owners()

## Draw passes per piece of the open scene (its direct children, the grouping the draw fixes work on): a
## visible mesh or MultiMesh costs one pass per surface, two where its material has an outline next_pass.
func _owners() -> void:
	var by := {}
	var scene: Node = main.current
	for n in scene.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		var mesh: Mesh = null
		if gi is MeshInstance3D:
			mesh = gi.mesh
		elif gi is MultiMeshInstance3D and gi.multimesh:
			mesh = gi.multimesh.mesh
		if mesh == null or not gi.is_visible_in_tree():
			continue
		var passes := 0
		for si in mesh.get_surface_count():
			var mat: Material = gi.material_override if gi.material_override else mesh.surface_get_material(si)
			passes += 2 if mat and mat.next_pass else 1
		var top: Node = gi
		var under: Node = gi      # the level below `top`: the home's world root holds most pieces
		while top.get_parent() != scene:
			under = top
			top = top.get_parent()
		var key := "%s/%s" % [String(top.name).rstrip("0123456789@"), String(under.name).rstrip("0123456789@")]
		by[key] = int(by.get(key, 0)) + passes
	var ks := by.keys()
	ks.sort_custom(func(a, b): return by[a] > by[b])
	print("BENCH draw passes by owner: " + ", ".join(ks.slice(0, 20).map(func(k): return "%s %d" % [k, by[k]])))
