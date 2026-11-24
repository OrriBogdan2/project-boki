extends RefCounted
## The fight worst case (DECISIONS 2026-11-08 performance budgets: VFX particles under 4,000 on screen, no frame over
## 50 ms after warm-up). First every Hunter alone, casting E then R at a dummy, so the particles and the nodes made
## by each kit are its own; then three trios of Hunters with their Boki sent out, fighting in one camp beside a
## monster camp, every Hunter casting E and R in waves. Run by --perf-bench --bench-fight and --perf-budget-check.
## Particles are counted with ParticleCount (every emitting, unpaused emitter, on screen or not: an upper bound).

const ARCHS := ["ashwick", "bulwark", "dolm", "dredge", "gunslinger", "juggernaut", "mage", "rimewright", "thief"]
const CAMP := ["brute", "skitter", "spitter", "skitter", "bomber", "brute", "skitter", "spitter"]
const SECS := 24.0  # s of the camp fight
const WAVE := 6.0  # s between casting waves (every Hunter: E, then R)
const R_AFTER := 0.6  # s from a wave's E to its R
const SAMPLE := 4  # frames between particle counts (it walks the whole tree)
const KIT_SECS := 4.0  # s a kit's E and R are watched for
const RING := 5.0  # m from the camp's middle to the Hunters
const PEAK_AT := 19.5  # s into the camp: 0.9 s after the fourth wave's R, the scene inventory at an FX peak
const QUIET_AT := 23.5  # s into the camp: the same inventory in the quiet before the run ends
const FightScene := preload("res://tools/perf/fight_scene.gd")

var bench  # the PerfBench: frames are logged and summed by it
var m: Match
var peak := {"n": 0, "by": {}, "t": 0.0, "nodes": 0}
var made := {}  # "Class:name" -> nodes that entered the tree after the warm-up
var kits := {}  # arch -> {n: particles over the quiet floor at its peak, made: nodes made}
var counting := false
var engine_us := 0  # us spent waiting on the engine's own frame (scene processing, animation, drawing)
var taken := {}  # script file -> nodes whose _process the bench calls itself during the camp (timed per script)
var phase_us := {"process rest": 0, "draw": 0, "between": 0, "physics ticks": 0}  # the engine wait, split
var t_pre := 0  # us: this frame's RenderingServer.frame_pre_draw, frame_post_draw, first physics tick
var t_post := 0
var t_phys := 0
var stamp_us := {}  # RenderingDevice timestamp name -> us of CPU from it to the next one (the draw, split)
var stamp_frame := -1
var stamp_frames := 0  # stamp sets read
var stamp_gpu_us := {}  # timestamp name -> us of GPU from it to the next one (the draw's steps)
var stamp_cpu_us := {}  # the same on the render thread's clock
var draws: Array = []  # [pre, post] us of the last few draws
var taken_us := {}  # script file -> us spent in those _process calls


func _init(perf_bench) -> void:
	bench = perf_bench


## The whole run; returns the camp fight's frames.
func run() -> Array:
	var main: Node = bench.main
	var o := Match.demo_opts()
	o.merge(
		{
			"teams": 3,
			"squad": 3,
			"total": 9,
			"no_drop": true,
			"god": true,
			"autoplay": true,
			"demo_kin": "cindle",
			"seed": 4101
		},
		true
	)
	o.erase("demo_match")
	o.erase("fresh_t")
	Game.goto("match", o)
	while not (main.current is Match and (main.current as Match).is_processing() and main.current.hud != null):
		await main.get_tree().process_frame
	m = main.current
	m.set_process(false)
	main.get_tree().node_added.connect(
		func(n: Node):
			if counting:
				var k := "%s:%s<%s" % [n.get_class(), String(n.name).rstrip("0123456789@"), FightScene.owner_name(n)]
				made[k] = int(made.get(k, 0)) + 1
	)
	await _each_kit()
	var fl: Array = await _camp()
	_report()
	return fl


func _step(n: int) -> void:
	for i in n:
		for h in m.hunters:
			h.hp = h.max_hp
		m.step(Match.DT)
		m.acc -= Match.DT  # _process steps on its own clock: without this every frame ran two steps
		m._process(Match.DT)
		_run_taken()
		var t_wait := Time.get_ticks_usec()
		t_pre = 0
		t_post = 0
		t_phys = 0
		await bench.main.get_tree().process_frame
		var t_back := Time.get_ticks_usec()
		engine_us += t_back - t_wait
		_split_wait(t_wait, t_back)


## The engine wait from t_wait to t_back in its phases: the rest of the scene's process, the draw, the gap before
## the next frame's physics ticks (input, audio) and the physics ticks (several when a frame runs long).
func _split_wait(t_wait: int, t_back: int) -> void:
	if t_pre == 0 or t_post == 0:
		return  # (no draw signals: headless)
	var phys := t_phys if t_phys > t_post else t_back
	phase_us["process rest"] += t_pre - t_wait
	phase_us["draw"] += t_post - t_pre
	phase_us["between"] += phys - t_post
	phase_us["physics ticks"] += t_back - phys


func _particles() -> Dictionary:
	return ParticleCount.by_owner(bench.main.get_tree().root)


## Every Hunter's E and R alone in front of an idle dummy (it stays, a punching bag in the camp), the rest idle.
func _each_kit() -> void:
	var P: Hunter = m.player
	var ctrl := {}
	for h in m.hunters:
		ctrl[h] = h.ctrl
		if h != P:
			h.ctrl = "idle"
	var at: Vector3 = m.world.free_spot_near(P.pos + Vector3(6, 0, 0), [], 1.0, 0.5, 6.0)
	at.y = m.world.ground_at(at.x, at.z)
	var T: Hunter = m.make_hunter("T", 5, "medium", "Target", "idle", {}, at, {"arch": "none"})
	T.max_hp = 1e6
	await _step(30)
	for arch in Arch.ids():
		P.set_arch(String(arch))
		_ready_kit(P)
		T.teleport(at)
		P.inp["aim"] = at + Vector3(0, 0.9, 0)
		await _step(60)
		var floor_n: int = ParticleCount.total(_particles())
		made.clear()
		counting = true
		var top := 0
		for f in int(KIT_SECS * 60.0):
			if f == 0:
				P.ak.use_e()
			if f == 60:
				P.ak.use_r()
			await _step(1)
			if f % SAMPLE == 0:
				top = maxi(top, ParticleCount.total(_particles()) - floor_n)
		counting = false
		kits[arch] = {"n": top, "made": made.values().reduce(func(a, b): return a + b, 0), "top": _top(made, 4)}
	for h in ctrl:
		h.ctrl = ctrl[h]


func _ready_kit(h: Hunter) -> void:
	h.unlock_all()
	h.lvl = 6
	h.slot_lv["ult"] = 1
	h.ak.cd["e"] = 0.0
	h.ak.cd["r"] = 0.0


## Three trios round the camp's middle with a monster camp, Boki out, E and R in waves; returns the frames.
func _camp() -> Array:
	var P: Hunter = m.player
	var mid: Vector3 = P.pos
	var i := 0
	for h: Hunter in m.hunters:
		var a := TAU * (h.team + i * 0.11) / 3.0
		h.set_arch(ARCHS[i % ARCHS.size()])
		var at: Vector3 = m.world.free_spot_near(mid + Vector3(cos(a), 0, sin(a)) * RING, [], 1.0, 0.5, 6.0)
		h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
		i += 1
	for k in CAMP.size():
		var a := TAU * k / CAMP.size()
		var at: Vector3 = m.world.free_spot_near(mid + Vector3(cos(a), 0, sin(a)) * 3.0, [], 1.0, 0.5, 6.0)
		m.spawn_mob(CAMP[k], Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	await _step(20)
	for h in m.hunters:
		if h.kin is Kin:
			(h.kin as Kin).throw_to(mid)
	made.clear()
	counting = true
	Match.prof.clear()
	engine_us = 0
	Match.vprof.clear()
	Match.prof_on = true
	_take_process(bench.main.get_tree().root)
	if "--bench-novsync" in OS.get_cmdline_user_args():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)  # (after Settings applied the player's)
		print("BENCH fight vsync off: mode %d" % DisplayServer.window_get_vsync_mode())
	if "--bench-noshadow" in OS.get_cmdline_user_args():  # (a probe: what the shadow pass costs the frame's end)
		for l in bench.main.get_tree().root.find_children("*", "Light3D", true, false):
			(l as Light3D).shadow_enabled = false
		print("BENCH fight shadows off")
	if "--bench-nofx" in OS.get_cmdline_user_args():  # (a probe: what the effects cost the draw)
		m.fx.visible = false
		HeroVfx.of(m).visible = false
		print("BENCH fight fx off")
	if "--bench-noink" in OS.get_cmdline_user_args():  # (a probe: what the Hunters' ink outlines cost the draw)
		for h: Hunter in m.hunters:
			for shell in WardenMerge.inks(h.model) if h.model else []:
				(shell as Node3D).visible = false
			for n in h.model.find_children("*", "MeshInstance3D", true, false) if h.model else []:
				var mi := n as MeshInstance3D
				for si in mi.get_surface_override_material_count():
					if mi.get_surface_override_material(si):
						mi.get_surface_override_material(si).next_pass = null
		print("BENCH fight ink off")
	if "--bench-nopost" in OS.get_cmdline_user_args():  # (a probe: what glow and FXAA cost the draw)
		for we in bench.main.get_tree().root.find_children("*", "WorldEnvironment", true, false):
			(we as WorldEnvironment).environment.glow_enabled = false
		bench.main.get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		print("BENCH fight post off")
	for a in OS.get_cmdline_user_args():  # (a probe: the 3D at this scale of the window, so a small window can
		if a.begins_with("--bench-3d-scale="):  # draw 1080p and keep only the window's copy to the screen small)
			bench.main.get_viewport().scaling_3d_scale = float(a.substr(17))
			print("BENCH fight 3d scale %.2f" % bench.main.get_viewport().scaling_3d_scale)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	bench.main.get_tree().physics_frame.connect(_on_physics)
	var fl: Array = []
	var scene := FightScene.new()
	var last := Time.get_ticks_usec()
	var f := 0
	while f < int(SECS * 60.0):
		var wave_f := f % int(WAVE * 60.0)
		for h in m.hunters:
			if wave_f == 0:
				_ready_kit(h)
			if wave_f == 0:
				h.ak.use_e()
			if wave_f == int(R_AFTER * 60.0):
				h.ak.use_r()
		var t0 := Time.get_ticks_usec()
		await _step(1)
		var now := Time.get_ticks_usec()
		fl.append(bench._frame("fight", f, (now - last) / 1000.0, (now - t0) / 1000.0))
		last = now
		if f % SAMPLE == 0:
			_sample(f / 60.0)
			last = Time.get_ticks_usec()  # (the particle count walks the tree: it stays out of the frame times)
		if f == int(PEAK_AT * 60.0) or f == int(QUIET_AT * 60.0):
			scene.report(bench.main.get_tree().root, m, bench.main.get_viewport(), "peak" if f < QUIET_AT * 60.0 else "quiet")
			last = Time.get_ticks_usec()  # (so does the inventory)
		f += 1
	counting = false
	Match.prof_on = false
	print("BENCH fight engine wait (not Match code): %.2f ms per frame" % (engine_us / 1000.0 / fl.size()))
	_print_sections(Match.prof, "step", fl.size())
	_print_sections(Match.vprof, "visual", fl.size())
	_print_sections(taken_us, "node _process", fl.size())
	_print_sections(phase_us, "engine wait", fl.size())
	_print_sections(stamp_us, "draw stamps (cpu)", fl.size())
	_print_sections(stamp_gpu_us, "draw steps (gpu, each renderer stamp to the next)", stamp_frames, 40)
	_print_sections(stamp_cpu_us, "draw steps (cpu, the same)", stamp_frames, 40)
	_print_casters()
	_give_back()
	return fl


## Every node (but Match) running a script _process: the engine stops calling it and _run_taken calls it instead, same
## dt, timed per script file. The engine wait then no longer hides the Hunter and Boki rigs, springs and look scripts.
## Nodes made later in the fight stay with the engine (they land in the wait line).
func _take_process(n: Node) -> void:
	if n != m and n.get_script() != null and n.is_processing() and n.has_method("_process"):
		var k := String((n.get_script() as Script).resource_path).get_file()
		if not taken.has(k):
			taken[k] = []
			taken_us[k] = 0
		taken[k].append(n)
		n.set_process(false)
	for c in n.get_children():
		_take_process(c)


func _run_taken() -> void:
	var dt: float = bench.main.get_process_delta_time()
	for k in taken:
		var t0 := Time.get_ticks_usec()
		for n in taken[k]:
			if is_instance_valid(n) and n.is_inside_tree():
				n._process(dt)
		taken_us[k] += Time.get_ticks_usec() - t0


## The visible shadow casters by who made them (each is drawn again per cascade: the frame end's biggest cost).
func _print_casters() -> void:
	var by := {}
	for n in bench.main.get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and g.is_visible_in_tree():
			var k := "%s<%s" % [g.get_class(), FightScene.owner_name(g)]
			by[k] = int(by.get(k, 0)) + 1000  # (_print_sections prints thousandths)
	_print_sections(by, "shadow casters (count)", 1)


func _on_pre_draw() -> void:
	t_pre = Time.get_ticks_usec()


func _on_post_draw() -> void:
	t_post = Time.get_ticks_usec()
	_add_stamps()


## The renderer's own timestamps (captured while the bench measures render time, a frame or two late): matched to
## the pre/post-draw clocks of the frame they fall in, the draw splits into before the first viewport (scene and
## instance updates, skinning, particles), the viewports and after the last one (frame end, present).
func _add_stamps() -> void:
	draws.append([t_pre, t_post])
	if draws.size() > 8:
		draws.pop_front()
	var rd := RenderingServer.get_rendering_device()
	if rd == null or rd.get_captured_timestamps_count() < 2 or rd.get_captured_timestamps_frame() == stamp_frame:
		return
	stamp_frame = rd.get_captured_timestamps_frame()
	_add_steps(rd)
	var first := rd.get_captured_timestamp_cpu_time(0)
	var last := rd.get_captured_timestamp_cpu_time(rd.get_captured_timestamps_count() - 1)
	for d in draws:
		if d[0] <= first and last <= d[1]:
			stamp_us["before viewports"] = int(stamp_us.get("before viewports", 0)) + first - d[0]
			stamp_us["viewports"] = int(stamp_us.get("viewports", 0)) + last - first
			stamp_us["after viewports"] = int(stamp_us.get("after viewports", 0)) + d[1] - last
			stamp_us["(frames matched)"] = int(stamp_us.get("(frames matched)", 0)) + 1000
			return


## The draw's steps from the renderer's own stamps: GPU and CPU us from each stamp to the next, by the stamp's name,
## and the whole span. Without the engine's --gpu-profile flag only the viewport's own begin and end stamps exist;
## with it the passes show (shadows, opaque, transparent, post, canvas). The GPU clock reads in ns on Vulkan.
func _add_steps(rd: RenderingDevice) -> void:
	stamp_frames += 1
	var n := rd.get_captured_timestamps_count()
	for i in n - 1:
		var k := rd.get_captured_timestamp_name(i)
		var gpu := int((rd.get_captured_timestamp_gpu_time(i + 1) - rd.get_captured_timestamp_gpu_time(i)) / 1000.0)
		var cpu := rd.get_captured_timestamp_cpu_time(i + 1) - rd.get_captured_timestamp_cpu_time(i)
		stamp_gpu_us[k] = int(stamp_gpu_us.get(k, 0)) + gpu
		stamp_cpu_us[k] = int(stamp_cpu_us.get(k, 0)) + cpu
	var whole := "(first to last stamp)"
	var gpu_all := int((rd.get_captured_timestamp_gpu_time(n - 1) - rd.get_captured_timestamp_gpu_time(0)) / 1000.0)
	var cpu_all := rd.get_captured_timestamp_cpu_time(n - 1) - rd.get_captured_timestamp_cpu_time(0)
	stamp_gpu_us[whole] = int(stamp_gpu_us.get(whole, 0)) + gpu_all
	stamp_cpu_us[whole] = int(stamp_cpu_us.get(whole, 0)) + cpu_all


func _on_physics() -> void:
	if t_phys == 0 and t_post != 0:
		t_phys = Time.get_ticks_usec()


func _give_back() -> void:
	RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)
	RenderingServer.frame_post_draw.disconnect(_on_post_draw)
	bench.main.get_tree().physics_frame.disconnect(_on_physics)
	for k in taken:
		for n in taken[k]:
			if is_instance_valid(n):
				n.set_process(true)
	taken.clear()


## The costliest sections of the match step or visuals, ms per frame (Match._prof labels).
static func _print_sections(by: Dictionary, what: String, frames: int, limit := 12) -> void:
	var ks := by.keys()
	ks.sort_custom(func(a, b): return by[a] > by[b])
	var per := ks.slice(0, limit).map(func(k): return "%s %.2f" % [k, by[k] / 1000.0 / maxi(frames, 1)])
	print("BENCH fight %s sections (ms per frame): %s" % [what, ", ".join(per)])


func _sample(t: float) -> void:
	var by := _particles()
	var n: int = ParticleCount.total(by)
	if n > int(peak["n"]):
		peak = {"n": n, "by": by, "t": t, "nodes": _vfx_nodes()}


## The effect nodes drawing now: emitting emitters plus the shown meshes and labels of Fx and HeroVfx.
func _vfx_nodes() -> int:
	var n := 0
	for root in [m.fx, HeroVfx.of(m)]:
		for c in (root as Node).find_children("*", "GeometryInstance3D", true, false):
			n += 1 if (c as Node3D).is_visible_in_tree() and not (c is GPUParticles3D or c is CPUParticles3D) else 0
	for by_cls in ["GPUParticles3D", "CPUParticles3D"]:
		for c in bench.main.get_tree().root.find_children("*", by_cls, true, false):
			n += 1 if c.get("emitting") else 0
	return n


static func _top(by: Dictionary, n: int) -> String:
	var ks := by.keys()
	ks.sort_custom(func(a, b): return by[a] > by[b])
	return ", ".join(ks.slice(0, n).map(func(k): return "%s %d" % [k, by[k]]))


func _report() -> void:
	var ks := kits.keys()
	ks.sort_custom(func(a, b): return kits[a]["n"] > kits[b]["n"])
	for k in ks:
		print(
			"FIGHT kit %-11s E+R particles +%d, nodes made %d (%s)" % [k, kits[k]["n"], kits[k]["made"], kits[k]["top"]]
		)
	print(
		(
			"FIGHT peak t=%.1f s: particles %d, vfx nodes %d; by owner: %s"
			% [peak["t"], peak["n"], peak["nodes"], _top(peak["by"], 10)]
		)
	)
	print(
		(
			"FIGHT nodes made in the camp fight %d: %s"
			% [made.values().reduce(func(a, b): return a + b, 0), _top(made, 12)]
		)
	)
