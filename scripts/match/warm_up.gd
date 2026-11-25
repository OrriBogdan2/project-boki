class_name WarmUp
extends RefCounted
## The loading screen's last step (Match.warm_up): draws what the match will draw, so the GPU builds its
## shaders before play.

var m: Match

func _init(match_node: Match) -> void:
	m = match_node

## Under the loading screen: draws every material in the match once on tiny stand-ins (a batch a
## frame, see _batches), then the m.world once from far above (every island, prop, wall, cloud
## layer and landmark in view), once close to the ground (grass, flowers, undergrowth) and once from
## where the match starts, with one of each effect in front of the camera, then stand-ins for what
## those views added (the effects), so the GPU compiles every shader before play instead of when the
## drop first shows it. The last frames double as the
## auto-quality benchmark (Settings.note_benchmark). progress(frac 0..1) as it goes.
func run(progress := Callable()) -> void:
	if DisplayServer.get_name() == "headless" or m.cam == null or m.world == null:
		return
	PerfLog.skip()
	var keep := [m.cam.global_transform, m.cam.fov, m.cam.far]
	var ctr := Vector3(m.world.w * 0.5, 0.0, m.world.h * 0.5)
	var ground := ctr
	if m.player and m.player.ai.has("land"): ground = m.player.ai["land"]
	ground.y = m.world.ground_at(ground.x, ground.z) if not m.world.is_void(ground.x, ground.z) else 0.0
	var views := [
		[ctr + Vector3(0, maxf(m.world.w, m.world.h) * 1.05, maxf(m.world.w, m.world.h) * 0.4), ctr, 62.0, 900.0],
		[ground + Vector3(0, 22.0, 11.0), ground, 40.0, 160.0],
		[ground + Vector3(0, 60.0, 30.0), ground, 40.0, 300.0],
	]
	# the sight-cone texture the toon shaders read once you've landed: set now, not on landing
	if not m._vis_tex_done:
		m._vis_tex_done = true
		RenderingServer.global_shader_parameter_set("vis_blocks", m.world.vis_texture())
		RenderingServer.global_shader_parameter_set("vis_size", Vector2(m.world.w, m.world.h))
	# every material in the match on every kind of geometry it's drawn with (hidden things too: aim
	# line and ring, gliders, auras, weapon effects, pickups, damage numbers, particles), as tiny
	# stand-ins just in front of the camera. The Compatibility renderer compiles a separate variant
	# of a shader for an object lit by an omni light, by a spot light, by both and by neither, so
	# the stand-ins are drawn once under each: the first muzzle flash after landing (an omni light
	# on everything round you) and the sky train's headlight sweeping an island no longer stall.
	# Done first and a batch at a time, so the views below find their shaders already built and no
	# single frame takes every compile at once.
	# a Boki makes its daze stars the first time it's dazed: one makes them now (hidden until then),
	# so their material is among the stand-ins
	# (each piece a slice: together they were one 160-320 ms "Preparing graphics" frame, item 33). Nothing in 3D
	# draws on the frames between them: the first full view of the map compiles every shader at once (an M5 GL
	# frame of 1.1 s); _batches draws the stand-ins alone first, then the views find their shaders built.
	var vp := m.get_viewport()
	var had_3d := vp.disable_3d
	vp.disable_3d = true
	# the build's last frame renders the Hud's map paint (MapPaint, a 2048 px bake, ~50-80 ms of GPU on an M5):
	# the first stand-ins wait a frame rather than land on top of it (a 126-140 ms frame)
	await m.get_tree().process_frame
	if not m.is_inside_tree():
		vp.disable_3d = had_3d
		return
	var tb := Time.get_ticks_usec()
	for k in m.kins:
		for pn in (k as Node).find_children("*", "Node", true, false):
			if pn is KinPuppet and pn.get("stars") == null and pn.get("body") != null:
				pn.call("_make_stars")
				break
		break
	tb = await _breathe(tb)
	if not m.is_inside_tree():
		vp.disable_3d = had_3d
		return
	if m.player: m.player.warm_marker()      # and the hit-marker balloon over a Hunter
	if m.ways_vfx: m.ways_vfx.prebuild()     # and the way-out seats' beacons (built on the match's first tick)
	tb = await _breathe(tb)
	if not m.is_inside_tree():
		vp.disable_3d = had_3d
		return
	if m.fx: KinTypeTrail.of(m.fx)     # and the Boki type trails (made when the first Boki is drawn)
	tb = await _breathe(tb)
	if not m.is_inside_tree():
		vp.disable_3d = had_3d
		return
	var seen := WarmStamp.warm_keys()      # what an earlier launch drew and the disk caches still hold
	var stamped := seen.size()
	var t0 := Time.get_ticks_msec()
	var batch_cb := func(f: float) -> void:
		if progress.is_valid(): progress.call(0.7 * f)
	var later: Array = []      # (stand-ins for the planning phase: _sweep_later)
	var mob_warm := _mob_stand_ins(later)
	var aim_warm := _aim_stand_in()      # (item 94c: the aim kit's one material draws only once somebody aims)
	vp.disable_3d = had_3d
	PerfLog.mark("warm.stand_ins")
	var batched: bool = await _batches(batch_cb, seen)
	var t_first := Time.get_ticks_msec()
	PerfLog.mark("warm.batches")
	if is_instance_valid(aim_warm): aim_warm.queue_free()
	# the mob and shader stand-ins stay, out of sight and still: freeing them cost the first view frame 0.5-0.7 s
	# (rp2g, cold cache), and their shaders stay built for the mobs and effects that use them later
	mob_warm.visible = false
	mob_warm.process_mode = Node.PROCESS_MODE_DISABLED
	if not batched:
		return
	var shown: Array = []
	for i in 3:
		var sm: MeshInstance3D = m.shot_pool[i]
		sm.visible = true
		shown.append(sm)
	for vi in views.size():
		var v: Array = views[vi]
		var at: Vector3 = v[1]
		m.cam.global_transform = Transform3D(Basis.looking_at(at - (v[0] as Vector3), Vector3.UP), v[0])
		m.cam.fov = v[2]
		m.cam.far = v[3]
		# one of each effect where the camera looks
		m.fx.burst(at + Vector3(0, 1, 0), Color.WHITE, 6)
		m.fx.ring(at, 1.5, Color.WHITE)
		m.fx.flash(at + Vector3(0, 1, 0), Color.WHITE)
		m.fx.spark(at + Vector3(0, 1, 0), Vector3.UP, Color.WHITE, 4)
		m.fx.slash(at + Vector3(0, 0.8, 0), 0.0, 2.0, 1.6, Color.WHITE)
		m.fx.beam(at + Vector3(0, 1, 0), at + Vector3(2, 1, 0), Color.WHITE)
		HeroVfx.of(m).prewarm(at + Vector3(0, 1, 0))
		var tg := m.fx.telegraph_circle(at, 1.5, Color(1, 0.3, 0.2))
		# the muzzle flash light lights whatever stands near a shot: the lit variants compile now too
		if m.muzzle_light:
			m.muzzle_light.global_position = at + Vector3(0, 1.0, 0)
			m.muzzle_light.light_energy = 0.05
		for k in shown.size():
			(shown[k] as MeshInstance3D).global_position = at + Vector3(k - 1.0, 1.0, 0)
		# the ground views draw with the sight cone on, as play does after landing
		RenderingServer.global_shader_parameter_set("vis_on", 0.0 if vi == 0 else 1.0)
		RenderingServer.global_shader_parameter_set("vis_focus", at)
		await m.get_tree().process_frame
		await m.get_tree().process_frame
		m.fx.end_telegraph(tg)
		if not m.is_inside_tree():
			return
		if progress.is_valid(): progress.call(0.7 + 0.2 * (vi + 1) / views.size())
	HeroVfx.of(m).prewarm_end()
	var t_views := Time.get_ticks_msec()
	PerfLog.mark("warm.views")
	# and the materials that only exist now (the effects just shown, the shots), the same way: a
	# telegraph is held up for it (the views' own are gone by now)
	var late_cb := func(f: float) -> void:
		if progress.is_valid(): progress.call(0.9 + 0.1 * f)
	var late_at := m.cam.global_position - m.cam.global_transform.basis.z * 6.0
	var tg_late := m.fx.telegraph_circle(late_at, 1.5, Color(1, 0.3, 0.2))
	# (and a still copy of a melee swoosh: the real one frees itself in a fifth of a second)
	m.fx.slash(late_at, 0.0, 2.0, 1.6, Color.WHITE)
	var swoosh: Node = null
	if m.fx.get_child_count() > 0 and m.fx.get_child(m.fx.get_child_count() - 1) is MeshInstance3D:
		swoosh = m.fx.get_child(m.fx.get_child_count() - 1).duplicate(0)
		m.add_child(swoosh)
		(swoosh as Node3D).global_position = late_at
	batched = await _batches(late_cb, seen)
	if not batched:
		return
	m.fx.end_telegraph(tg_late)
	if swoosh: swoosh.queue_free()
	for sm in shown: (sm as MeshInstance3D).visible = false
	if m.muzzle_light: m.muzzle_light.light_energy = 0.0
	RenderingServer.global_shader_parameter_set("vis_on", 0.0)
	m.cam.global_transform = keep[0]
	m.cam.fov = keep[1]
	m.cam.far = keep[2]
	var t_end := Time.get_ticks_msec()
	PerfLog.note("warm-up ms: stand-ins %d, views %d, late %d (%d of %d keys warm from the stamp)"
			% [t_first - t0, t_views - t_first, t_end - t_views, stamped, seen.size()])
	WarmStamp.save(seen)
	PerfLog.mark("build.warm_up")
	# the benchmark: a few frames of the opening view
	var times: Array = []
	var last := Time.get_ticks_usec()
	for i in 8:
		await m.get_tree().process_frame
		var now := Time.get_ticks_usec()
		if i >= 2: times.append((now - last) / 1000.0)
		last = now
	times.sort()
	if not times.is_empty():
		var setup := WarmStamp.setup_id()
		Settings.note_benchmark(float(times[int(times.size() / 2.0)]))
		# a first launch's auto quality can step down here (shadows, MSAA, very low's unshaded draw): the game goes
		# on, and comes back, at the new settings. The stand-ins draw once more under them, still behind the
		# loading screen, with a new soft-dot one (FxDot's low-settings shader: the first Boki wisp of play
		# compiled it), and the stamp follows the new settings
		if WarmStamp.setup_id() != setup:
			var dot := _dot_stand_in()
			m.add_child(dot)
			dot.position = Vector3(0, MOB_DEPTH, 0)
			await _batches(func(_f: float) -> void: pass, {})
			if is_instance_valid(dot): dot.queue_free()
			WarmStamp.save(seen)
	await DashPace.rehearse(m)
	PerfLog.skip()
	if not later.is_empty(): _sweep(m, later)      # (not awaited: it runs on into the planning phase)

## Inside warm_up's own CPU work under the loading screen: lets a frame draw once the work has had the CPU for
## PerfLog.SLICE_MS since `t0` (usec); returns the time the work goes on from. The --hitch-trace names the call.
func _breathe(t0: int) -> int:
	if Time.get_ticks_usec() - t0 <= int(PerfLog.SLICE_MS * 1000.0):
		return t0
	PerfLog.wait_begin()
	await m.get_tree().process_frame
	PerfLog.wait_end()
	return Time.get_ticks_usec()

## Stand-ins drawn in the first batch of warm_up; later batches grow while a batch's frames stay
## cheap and shrink when one costs more than FRAME_MS over a plain frame (a first draw is
## where a GPU compiles a shader), down to BATCH_MIN. Only how many frames the warm-up takes depends
## on it. From a cold shader cache a batch of 8 was a 400-560 ms frame on an RTX 4070, but batches of 1-2
## doubled an M5's warm-up (eight frames a batch, each ~30 ms with the map loaded; item 33).
const BATCH := 4
const BATCH_MIN := 2
const FRAME_MS := 45.0

## The stand-ins of warm_up, a batch a frame, each batch drawn once under each light setup.
## False if the match went away meanwhile.
## A mob kind's model is built when the first one spawns: a fight's pack mid-play compiled its materials
## then (a 400 ms frame on the bench at t=8 s). One model of each kind of roaming mob not in the match yet,
## out of sight below the map, so its materials join the stand-ins. (Bosses and wards are placed at build.)
## Also the kit effect and shader file stand-ins (_makers). Those go in `later` instead when the planning phase
## builds them (_sweep_later).
func _mob_stand_ins(later: Array) -> Node3D:
	var holder := Node3D.new()
	holder.name = "WarmMobs"
	m.add_child(holder)
	holder.position = Vector3(0, MOB_DEPTH, 0)
	var makers := _makers()
	if _sweep_later():
		later.append_array(makers)
	else:
		for mk: Callable in makers:
			var nd: Node3D = mk.call()
			if nd: holder.add_child(nd)
	# and a squad's drop rocket (built at launch, in the ride), and the soft dot's particles
	holder.add_child(DropRocket.model(Color.WHITE))
	holder.add_child(_dot_stand_in())
	return holder

## What _mob_stand_ins makes, one Callable (-> Node3D or null) each: a model of each roaming mob kind not in the
## match yet, the kit effect libraries' own shaders, which a kit's first cast built mid-play (LDFx on the bench's
## ride, a 200 ms frame; CareLook, HeroVfx a second after landing; DJFx draws its own, DashPace.rehearse; a
## library's particle shaders run in an emitter drawn with each of its spatial shaders), and every shader file on
## a quad (a particle one in an emitter): a material made only when first needed (the last-alive aura, a downed
## hunter's wisp, a kit's ice strip) compiled its shader mid-match. Those the match already has share their key
## and add nothing; a later launch's stamp skips the rest.
func _makers() -> Array:
	var out: Array = []
	var have := {}
	for mb in m.mobs:
		if is_instance_valid(mb): have[(mb as Mob).mkind] = true
	for k in Data.MOBS:
		var md: Dictionary = Data.MOBS[k]
		if have.has(k) or md.get("boss", false) or md.get("ward", false):
			continue
		out.append(func() -> Node3D: return Models.mob(k))
	for lib: Script in [LDFx, VVFx, CareLook, UltLook, HeroVfx]:
		out.append(func() -> Node3D: return _lib_quads(lib))
	for fn in _shader_files():
		out.append(func() -> Node3D: return _shader_quad(fn))
	return out

## A kit effect library's spatial shaders on quads, each with an emitter per particle shader of the library.
static func _lib_quads(lib: Script) -> Node3D:
	var box := Node3D.new()
	var spatial: Array[Shader] = []
	var particles: Array[Shader] = []
	for v in lib.get_script_constant_map().values():
		if v is Shader and (v as Shader).get_mode() == Shader.MODE_SPATIAL: spatial.append(v)
		elif v is Shader and (v as Shader).get_mode() == Shader.MODE_PARTICLES: particles.append(v)
	for sh in spatial:
		var mi := MeshInstance3D.new()
		mi.mesh = _fx_quad(sh)
		box.add_child(mi)
		for ps in particles:
			var p := GPUParticles3D.new()
			p.amount = 1
			p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
			var pm := ShaderMaterial.new()
			pm.shader = ps
			p.process_material = pm
			p.draw_pass_1 = _fx_quad(sh)
			box.add_child(p)
	return box

## The shader files of res://shaders (their imported names).
static func _shader_files() -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at("res://shaders"):
		var fn := f.trim_suffix(".remap")
		if fn.ends_with(".gdshader"): out.append(fn)
	return out

## A stand-in for one shader file: a quad with it (a particle shader in an emitter), or null.
static func _shader_quad(fn: String) -> Node3D:
	var sh := load("res://shaders/" + fn) as Shader
	if sh == null:
		return null
	if sh.get_mode() == Shader.MODE_SPATIAL:
		var mi := MeshInstance3D.new()
		mi.mesh = _fx_quad(sh)
		return mi
	if sh.get_mode() == Shader.MODE_PARTICLES:
		var p := GPUParticles3D.new()
		p.amount = 1
		p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
		var pm := ShaderMaterial.new()
		pm.shader = sh
		p.process_material = pm
		p.draw_pass_1 = QuadMesh.new()
		return p
	return null

## True when _makers' stand-ins wait for the planning phase. On Forward+ and Mobile a new shader compiles on the
## first frame that draws 3D after its material exists, seen or not: under the loading screen the mob models and
## the ~80 shader files were two frames of 0.5-1 s (rp2g, cold cache), for mobs that spawn after landing and
## effects a match shows late or never. A match that opens with a planning phase (DropSquad) builds them there
## instead, a few a frame, before anyone can land, fight or cast. Compatibility compiles a shader only when it
## draws, so there they stay among the stand-ins.
func _sweep_later() -> bool:
	return RenderingServer.get_current_rendering_driver_name() != "opengl3" and m.skydrop != null \
			and m.skydrop.planning

const SWEEP_PER_FRAME := 2

## The stand-ins _sweep_later held back, SWEEP_PER_FRAME a frame, below the map, kept and still.
static func _sweep(mt: Match, makers: Array) -> void:
	var holder := Node3D.new()
	holder.name = "WarmLater"
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	mt.add_child(holder)
	holder.position = Vector3(0, MOB_DEPTH, 0)
	var t0 := Time.get_ticks_msec()
	for i in makers.size():
		if i > 0 and i % SWEEP_PER_FRAME == 0:
			await mt.get_tree().process_frame
			if not is_instance_valid(mt) or not mt.is_inside_tree():
				return
		var nd: Node3D = (makers[i] as Callable).call()
		if nd: holder.add_child(nd)
	PerfLog.note("warm-up: %d stand-ins built in the planning phase over %d ms%s" % [makers.size(),
			Time.get_ticks_msec() - t0, "" if mt.skydrop == null or mt.skydrop.planning else " (past its end)"])

## Particles drawn with FxDot's material (a Boki wisp's trail): its shader is made again with other code when the
## settings go low (Settings.lite), so after a quality step the redraw needs a new one of these.
func _dot_stand_in() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 1
	p.emitting = false
	p.mesh = QuadMesh.new()
	p.material_override = FxDot.material()
	return p

static func _fx_quad(sh: Shader) -> QuadMesh:
	var q := QuadMesh.new()
	var mt := ShaderMaterial.new()
	mt.shader = sh
	q.material = mt
	return q

const MOB_DEPTH := -600.0      # m: under every island and the void floor, so no view draws them

## The aim kit (AimKit: every kit's aim lines, rings and the Hem draw's fill line and perfect circle) draws one
## ArrayMesh that is empty until a Hunter aims, so the scan below never sees its material and the first
## aim after landing compiled its shader mid-play. A one-triangle mesh with the same material and vertex
## format stands in for it for the warm-up.
func _aim_stand_in() -> MeshInstance3D:
	var d := AimKit.layer(m)
	if d == null or d.mat == null:
		return null
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arr[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, d.mat)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.visible = false
	m.add_child(mi)
	return mi

func _batches(progress: Callable, seen: Dictionary) -> bool:
	# the camera sees only the stand-ins meanwhile (their own render layer), from the scan on: the
	# first frames back in 3D drew the whole map with every shader compiling at once (item 33: a
	# 4-5 s frame on an RTX 4090). The lights, shadows and environment that pick a shader's variant
	# are all still there.
	var keep_mask := m.cam.cull_mask
	m.cam.cull_mask = LAYER
	var list: Array = await _sources(seen)
	if not m.is_inside_tree():
		return false
	if list.is_empty():
		m.cam.cull_mask = keep_mask
		return true
	var cb := m.cam.global_transform.basis
	var front := m.cam.global_position - cb.z * 6.0
	var wl := _lights()
	# (a camera culls lights by their layers too: every light joins the stand-ins' layer meanwhile,
	# or they'd all draw unlit)
	# (and the sun lights and shadows only the stand-ins meanwhile: its shadow pass drew the whole map
	# every frame, 8 frames a batch)
	var lights := m.find_children("*", "Light3D", true, false)
	var keep_layers: Array = []
	var keep_cull: Array = []
	for l in lights:
		keep_layers.append((l as Light3D).layers)
		keep_cull.append((l as Light3D).light_cull_mask)
		(l as Light3D).layers |= LAYER
		if l is DirectionalLight3D:
			(l as Light3D).light_cull_mask = LAYER
	# what a frame costs with nothing new in it, to tell a batch's own cost from plain drawing
	await m.get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	await m.get_tree().process_frame
	var plain := (Time.get_ticks_usec() - t0) / 1000.0
	if not m.is_inside_tree():
		return false
	# (only the Compatibility renderer compiles a variant per light setup; Forward+ and Mobile shade lights from
	# clusters in one shader, so there one setup is enough: a quarter of the frames a batch takes)
	var setups := [[false, false]]
	# (and there a batch's first frame compiles all it needs: its second added no pipeline on rp2g)
	var frames := 1
	if RenderingServer.get_current_rendering_driver_name() == "opengl3":
		setups = [[false, false], [true, false], [false, true], [true, true]]
		frames = 2
	var n := BATCH
	var i := 0
	var batches := 0
	while i < list.size():
		var batch: Array = list.slice(i, mini(i + n, list.size()))
		t0 = Time.get_ticks_usec()
		var pxs: Array = []
		var cols := int(ceil(sqrt(float(batch.size()))))
		for k in batch.size():
			if not is_instance_valid(batch[k]):
				continue
			# (a big batch's stand-ins are made over a few frames, hidden; they show together below)
			t0 = await _breathe(t0)
			if not m.is_inside_tree():
				return false
			var px := _proxy(batch[k])
			if px == null:
				continue
			px.visible = false
			m.add_child(px)
			_to_layer(px)
			var gx := (float(k % cols) / maxf(1.0, cols - 1) - 0.5) * 2.4
			var gy := (float(int(k / float(cols))) / maxf(1.0, cols - 1) - 0.5) * 1.4
			px.global_transform = Transform3D(cb.scaled(Vector3.ONE * 0.04), front + cb.x * gx + cb.y * gy)
			pxs.append(px)
		for px in pxs: (px as Node3D).visible = true
		t0 = Time.get_ticks_usec()
		var worst := 0.0
		# on Compatibility two frames under each light setup (with one, a variant or two still slipped through
		# to the ride: --hitch-check from a cold shader cache)
		for setup in setups:
			wl[0].visible = setup[0]
			wl[1].visible = setup[1]
			for _f in frames:
				await m.get_tree().process_frame
				if not m.is_inside_tree():
					return false
				var now := Time.get_ticks_usec()
				worst = maxf(worst, (now - t0) / 1000.0)
				t0 = now
		batches += 1
		for px in pxs: (px as Node).queue_free()
		i += batch.size()
		progress.call(float(i) / list.size())
		var extra := worst - plain
		if extra > FRAME_MS:
			n = maxi(BATCH_MIN, int(n / 2.0))
		elif extra < FRAME_MS * 0.6:
			n = mini(n * 2, 512)
	await m.get_tree().process_frame
	for li in lights.size():
		if is_instance_valid(lights[li]):
			(lights[li] as Light3D).layers = keep_layers[li]
			(lights[li] as Light3D).light_cull_mask = keep_cull[li]
	for l in wl: (l as Node).queue_free()
	m.cam.cull_mask = keep_mask
	PerfLog.note("warm-up: %d stand-ins in %d batches" % [list.size(), batches])
	return m.is_inside_tree()

## The render layer warm_up's stand-ins draw on (nothing else in the game uses it).
const LAYER := 1 << 19
func _to_layer(px: Node) -> void:
	if px is VisualInstance3D: (px as VisualInstance3D).layers = LAYER
	for ch in px.get_children(): _to_layer(ch)

## One instance of each material and kind of geometry in the match (see _key) not in seen yet,
## for warm_up's stand-ins (adds them to seen). Walks the tree a slice at a time so the loading
## screen keeps moving.
func _sources(seen: Dictionary) -> Array:
	var list: Array = []
	var stack: Array = [m]
	var t0 := Time.get_ticks_usec()
	while not stack.is_empty():
		if Time.get_ticks_usec() - t0 > int(PerfLog.SLICE_MS * 1000.0):
			await m.get_tree().process_frame
			if not m.is_inside_tree():
				return []
			t0 = Time.get_ticks_usec()
		var n = stack.pop_back()
		if not is_instance_valid(n):
			continue
		for ch in (n as Node).get_children(): stack.append(ch)
		if n is Skeleton3D:
			# skinned meshes run a skinning shader of their own, first when one is drawn: a copy of
			# one rig of each make (its meshes follow it, their skeleton path is relative)
			var sk := "skel:" + ",".join(n.get_children().filter(func(c): return c is MeshInstance3D).map(_key))
			if not seen.has(sk) and seen.size() < 2000:
				seen[sk] = true
				list.append(n)
			continue
		if not (n is GeometryInstance3D):
			continue
		var key := _key(n as GeometryInstance3D)
		if key.is_empty() or seen.has(key):
			continue
		seen[key] = true
		list.append(n)
		if list.size() >= 900:
			break
	return list

## What decides which shader variants an instance compiles: the kind of geometry and each surface's
## shader (a StandardMaterial3D by the features its generated shader depends on). Empty: draws nothing.
static func _key(gi: GeometryInstance3D) -> String:
	var kind := gi.get_class()
	var mesh: Mesh = null
	if gi is MeshInstance3D:
		mesh = (gi as MeshInstance3D).mesh
	elif gi is MultiMeshInstance3D:
		var mm := (gi as MultiMeshInstance3D).multimesh
		if mm == null: return ""
		mesh = mm.mesh
		kind += "%d%d%d" % [mm.transform_format, int(mm.use_colors), int(mm.use_custom_data)]
	elif gi is CPUParticles3D:
		mesh = (gi as CPUParticles3D).mesh
	elif gi is GPUParticles3D:
		# its process shader is compiled too, the first time it emits
		var gp := gi as GPUParticles3D
		mesh = gp.draw_pass_1
		kind += ">" + _mat_key(gp.process_material)
	elif gi is Label3D or gi is Sprite3D:
		var sb := gi as GeometryInstance3D
		var parts: Array = [kind, sb.get("billboard"), sb.get("shaded"), sb.get("double_sided"),
				sb.get("no_depth_test"), sb.get("fixed_size"),
			sb.get("alpha_cut"), sb.get("texture_filter"), sb.get("transparent"), _mat_key(sb.material_override)]
		return str(parts)
	else:
		return ""
	if mesh == null or mesh.get_surface_count() == 0:
		return ""
	var mats: Array = []
	if gi.material_override:
		mats.append(_mat_key(gi.material_override))
	else:
		for si in mesh.get_surface_count():
			var mt: Material = mesh.surface_get_material(si)
			if gi is MeshInstance3D:
				mt = (gi as MeshInstance3D).get_active_material(si)
			mats.append(_mat_key(mt))
	if gi.material_overlay:
		mats.append("+" + _mat_key(gi.material_overlay))
	return kind + ":" + ",".join(mats)

static var _mat_keys := {}
static func _mat_key(mt: Material) -> String:
	if mt == null:
		return "default"
	var id := mt.get_instance_id()
	if _mat_keys.has(id):
		return _mat_keys[id]
	if _mat_keys.size() > 20000: _mat_keys.clear()
	var s := ""
	if mt is ShaderMaterial:
		var sh: Shader = (mt as ShaderMaterial).shader
		s = "sh" + _code_hash(sh)
	else:
		# a generated shader (StandardMaterial3D, ParticleProcessMaterial...) depends on its switches and modes and
		# on which textures are set, not on colours and amounts (keyed by class alone, every particle process
		# material after the first was left out, and compiled when its emitter first ran mid-match)
		s = "std" if mt is BaseMaterial3D else mt.get_class()
		for pr in mt.get_property_list():
			if not (int(pr["usage"]) & PROPERTY_USAGE_STORAGE):
				continue
			var t := int(pr["type"])
			if t == TYPE_BOOL or t == TYPE_INT:
				s += "%d" % int(mt.get(pr["name"]))
			elif t == TYPE_OBJECT:
				s += "1" if mt.get(pr["name"]) is Texture else "0"
	if mt.next_pass:
		s += ">" + _mat_key(mt.next_pass)
	_mat_keys[id] = s
	return s

## A tiny copy of an instance that draws with the same shaders.
func _proxy(src: Node3D) -> Node3D:
	if src is Skeleton3D:
		var rig := src.duplicate(0) as Skeleton3D
		for ch in rig.get_children():
			if not (ch is MeshInstance3D): ch.free()
			else:
				(ch as MeshInstance3D).visibility_range_end = 0.0
				(ch as MeshInstance3D).visible = true
		rig.visible = true
		return rig
	var gsrc := src as GeometryInstance3D
	var px: GeometryInstance3D = null
	if src is MeshInstance3D:
		var mi := src as MeshInstance3D
		var p := MeshInstance3D.new()
		p.mesh = mi.mesh
		for si in mi.get_surface_override_material_count():
			p.set_surface_override_material(si, mi.get_surface_override_material(si))
		px = p
	elif src is MultiMeshInstance3D:
		var smm := (src as MultiMeshInstance3D).multimesh
		var mm := MultiMesh.new()
		mm.transform_format = smm.transform_format
		mm.use_colors = smm.use_colors
		mm.use_custom_data = smm.use_custom_data
		mm.mesh = smm.mesh
		mm.instance_count = 1
		if mm.transform_format == MultiMesh.TRANSFORM_3D: mm.set_instance_transform(0, Transform3D())
		else: mm.set_instance_transform_2d(0, Transform2D())
		if mm.use_colors: mm.set_instance_color(0, Color.WHITE)
		var p := MultiMeshInstance3D.new()
		p.multimesh = mm
		px = p
	else:
		# particles, labels, sprites: a copy with their own settings (a label shows every digit, so the
		# glyphs damage numbers use are in the font's atlas before the first hit)
		px = gsrc.duplicate(0) as GeometryInstance3D
		for ch in px.get_children(): ch.free()
		px.visible = true
		if px is Label3D: (px as Label3D).text = "0123456789!"
		if px is GPUParticles3D:
			var gq := px as GPUParticles3D
			gq.amount = mini(gq.amount, 4)
			gq.local_coords = true
			gq.one_shot = false
			gq.emitting = true
			gq.preprocess = maxf(gq.preprocess, 0.2)
		if px is CPUParticles3D:
			var cp := px as CPUParticles3D
			cp.amount = mini(cp.amount, 4)
			cp.local_coords = true
			cp.one_shot = false
			cp.emitting = true
			cp.preprocess = maxf(cp.preprocess, 0.2)
	if px == null:
		return null
	if not (src is CPUParticles3D or src is GPUParticles3D or src is Label3D or src is Sprite3D):
		px.material_override = gsrc.material_override
		px.material_overlay = gsrc.material_overlay
	px.cast_shadow = gsrc.cast_shadow
	px.visibility_range_end = 0.0
	px.visibility_range_begin = 0.0
	return px

## The lights a stand-in can be lit by in play: an omni like the muzzle flash and the lamps, and a
## spot like the sky train's headlight, both covering the grid of stand-ins.
func _lights() -> Array:
	var cb := m.cam.global_transform.basis
	var front := m.cam.global_position - cb.z * 6.0
	var o := OmniLight3D.new()
	o.omni_range = 4.0
	o.light_energy = 0.05
	o.shadow_enabled = false
	m.add_child(o)
	o.global_position = front - cb.z * 0.5
	var sp := SpotLight3D.new()
	sp.spot_range = 14.0
	sp.spot_angle = 35.0
	sp.light_energy = 0.05
	sp.shadow_enabled = false
	m.add_child(sp)
	sp.global_transform = Transform3D(cb, m.cam.global_position)
	return [o, sp]


## A shader by its code (the same on every launch, unlike its instance id: WarmStamp keeps these keys).
static var _code_hashes := {}
static func _code_hash(sh: Shader) -> String:
	if sh == null:
		return "0"
	var id := sh.get_instance_id()
	if not _code_hashes.has(id):
		_code_hashes[id] = sh.code.md5_text().substr(0, 12)
	return _code_hashes[id]
