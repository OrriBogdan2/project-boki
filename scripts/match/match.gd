class_name Match
extends Node3D
## One PvPvE extraction match: islands, hunters and their kin, monsters, wild kin, chests and exits.
## The simulation runs at a fixed 60 steps per second; visuals interpolate between steps.

const DT := 1.0 / 60.0

var opts := {}
var world: World
var skytrain: SkyTrain = null   # the loop train, on maps that have one
var fx: Fx
var cam: CamRig
var hud: Node = null
var env: WorldEnvironment
var hunters: Array = []
var kins: Array = []
var mobs: Array = []
var shots: Array = []
var pickups: Array = []     # {pos, vel, kind:"gem"|"seed"|"tonic", v, key, node, t}
var boxes: Array = []       # deathboxes, see Life
var beacons: Array = []     # revive beacons, see Beacons
var chests: Array = []      # {pos, open, prog, node}: the one locked chest (KeyChest); "free" ones need no key
var keys: KeyRun = null     # who carries the chest keys, and the Shrublings (host / offline)
var shrines: Array = []     # {pos, used, prog, node}
var breaks: Array = []      # {i, pos, kind, node, dead}
var brk: Breakables
var ring_n := 0
var pellet_hits := {}        # shotgun volley + target -> slugs landed
var air_rings: Array = []   # {pos, dir, node, cd: {hunter nid: time}}
var wpicks: Array = []      # pickups on the ground: gear {gear}, tunings {tune}, treasure {val}, each with id, pos, rar, node
var wdrop_n := 0
var warden_done := false
var meteor_at := -1.0       # when the meteor shower starts
var meteor_end := -1.0
var meteor_next := 0.0
var meteors: Array = []     # {at, t, tele}
var glimmer_done := false
# ---- tutorial
var tut: Tutorial = null    # the first-match tutorial (scripts/match/tutorial.gd)
var exits: Exits = null     # the ways out: skiff docks, rift hatches, outpost uplinks (see Exits)
var lairs: Lairs = null     # boss lairs: sealed arenas, their bosses and Rare Eggs (see Lairs)
var truce: Truce = null     # emotes and truces between squads (see Truce)
var skydrop: DropSquad = null  # the planning phase before the ship sets off, drop leaders and formations (see DropSquad)
var spawn_plan: SpawnPlan = null   # which of the map's candidate spawns are live this match (see SpawnPlan)
var time := 0.0
var acc := 0.0
var player: Hunter = null
var over := false
var result := {}
var shot_pool: Array[MeshInstance3D] = []
var nid_n := 0
var feed: Array = []        # kill feed lines {text, t}
var pings: Array = []       # {pos, col, t}
var bubbles: Array = []     # {ent, text, t, cat}
var interact := {}          # what F would do right now for the local player
var paused := false
var duel: Duel = null
var arena: Arena = null   # the Arena (opts "arena") or the training area's practice tools
var shot_n := 0          # the duel room: you and one sparring bot (opts "duel")
var slowmo := 0.0
var slow_k := 0.35
var killcam_text := ""
var cam_style := ""
var swing_hits := {}
var ride_procs := {}       # kin damage riders on shots: "shooter>target" -> last proc time
var aim_y := 0.0
## Shots and ability projectiles bend up or down to the height of what you aimed at, so you can
## hit someone a terrace or two above or below. Further than this and the cliff takes it.
const AIM_DY_MAX := 2.6
var hitstop := 0.0
var aim_line: MeshInstance3D
var aim_ring: MeshInstance3D
var muzzle_light: OmniLight3D
var raid := "clear"                # the raid condition: rolled per match from the seed (RaidLook)
var sight_k := 1.0                 # sight range under the raid condition (RaidLook.SIGHT)
var raid_fx: Node3D = null         # blowing ash / drifting fog that follows the camera (RaidLook.storm_fx)
var blight: BlightDir = null       # the Blight: its spawns, its scaling and what it hears (BlightDir)
var music_dir: MusicDir = null     # the layered score's levels (scripts/match/music_dir.gd)
var collapse_warned := false
var rng := RandomNumberGenerator.new()
var pending_input := {"base": false, "dash": false, "jump": false, "sig": false, "util1": false, "util2": false, "util3": false, "util4": false, "throw": false, "skill": false, "ult": false, "sec": false, "gear1": false, "gear2": false, "swap": false}
var zones: Array = []      # hero areas: dome, sanctuary, well
var fields: Fields = null  # patches made by kin abilities (Thorn Patch)
var verbs: Verbs = null    # walls, reflect windows, tethers, traps, bridges and yanks left by abilities
var displace: Displace = null     # abilities moving someone else's body (online too: its owner's game moves it)
var _later: Array = []     # [due time, Callable]: delayed ability steps, on match time (not wall-clock timers)

## Run cb after `delay` seconds of match time: delayed effects, echoes, landing blasts. Unlike a
## SceneTree timer it pauses with the match, keeps step with headless sims and dies with the match.
func later(delay: float, cb: Callable) -> void:
	_later.append([time + maxf(0.0, delay), cb])

func _run_later() -> void:
	if _later.is_empty():
		return
	var due: Array = []
	for it in _later:
		if float(it[0]) <= time: due.append(it)
	for it in due:
		_later.erase(it)
		(it[1] as Callable).call()
var _bond_cb: Callable
var _combo_cb: Callable
var player_lost: Array = []  # your kin left behind when you went down: {uid, kin, holder}
var tracked: Array = []      # your kin a rival in this match is holding: {kin, holder}
var track_t := 8.0
var kstat := {"kin_ab": 0, "auto": 0, "combo": 0, "ult": 0, "swap": 0, "left": 0}   # counts for tests
var bot_brain := Bot.new()
var seed_val := 0
var length := 360.0
var net_on := false
var tier := 0
var T: Dictionary = {}
var bot_diff := "medium"         # how good the bot hunters are this run (Data.BOT_DIFF)
var bot_cfg: Dictionary = {}
var is_host := true
var drop_n := 0
var ents_by_id := {}
var _net_seen_rec := {}
var _rev_out := {}
var _net_rev_t := 0.0
var _finish_now := false
var rolling: Rolling = null     # a rolling 30-minute session (opts "rolling"): waves, join-in-progress, late-joiner levels (scripts/match/rolling.gd)
var sess_t0 := 0.0              # session time when this match's clock started (rolling: when your wave set off; else 0)
var ships: Array = []           # the other drop waves' skyships (rolling sessions); `ship` is your own
var _bot_names: Array = []
func sess_time() -> float: return sess_t0 + time     # the session clock: seconds since the session began (the match clock unless you joined a rolling session part-way)
func sess_len() -> float: return Rolling.SESSION if rolling else length     # the whole session (a rolling session: Rolling.SESSION)
func at_sess(k: float) -> float: return k * sess_len() - sess_t0     # match time at a share of the session (negative if before you joined)

func _ready() -> void:
	set_process(false)

## Builds the whole match in one go (checks, tools, tests).
func start(o: Dictionary) -> void:
	_start(o)       # nothing waits without a stage callback, so this runs straight through

## The same build spread over frames under the loading screen: progress(frac 0..1) after each step.
func start_staged(o: Dictionary, progress: Callable) -> void:
	_stage_cb = progress
	await _start(o)
	_stage_cb = Callable()
	if world: world.stage_cb = Callable()

var _stage_cb := Callable()
## Loaded on a worker thread while the loading screen comes up (Main.show_screen): compiling it
## on the main thread was the longest single stall of the build.
const HUD_SCRIPT := "res://scripts/ui/hud.gd"
static var _prefetching := {}

## Starts loading resources the build will need on a worker thread (Main.show_screen calls it as
## the loading screen comes up).
static func prefetch(paths: Array) -> void:
	for p in paths:
		if _prefetching.has(p) or ResourceLoader.has_cached(p):
			continue
		if ResourceLoader.load_threaded_request(p) == OK:
			_prefetching[p] = true

## A resource from prefetch (waiting for the worker if it isn't done yet), or loaded right here.
static func take_prefetched(path: String) -> Resource:
	if _prefetching.has(path):
		_prefetching.erase(path)
		var r := ResourceLoader.load_threaded_get(path)
		if r != null:
			return r
	return load(path)
## Roughly how long each step takes (ms, measured with --perf-probe), for the loading bar.
const STAGE_MS := {"build.generate": 250, "world.terrain": 450, "world.roots": 40, "world.scatter_plan": 350, "world.scatter_batches": 250,
	"world.walls": 650, "world.grass": 450, "world.sky": 60, "world.landmarks": 120, "world.air": 20, "build.systems": 40, "build.pads_exits": 80,
	"build.hunters": 250, "build.mobs": 200, "build.chests": 60, "build.spawns": 200, "build.hud": 150, "build.finish": 30}
var _stage_done_ms := 0.0

## Inside a long build step under the loading screen: lets a frame draw once the step has had the
## CPU for PerfLog.SLICE_MS, so the spinner keeps turning. Built in one go (checks, tools) it never
## waits, and waiting changes nothing the build computes.
func _slice() -> void:
	if _stage_cb.is_valid() and is_inside_tree() and PerfLog.slice_due():
		PerfLog.wait_begin()
		await get_tree().process_frame
		PerfLog.wait_end()

## One build step finished: log it, and when building under the loading screen let a frame draw.
func _stage(label: String) -> void:
	PerfLog.mark(label)
	if _stage_cb.is_valid() and is_inside_tree():
		_progress(label)
		await get_tree().process_frame
		PerfLog.skip()

## The world's own steps (World.build_meshes waits the frame itself).
func _world_step(label: String) -> void:
	_progress(label)

func _progress(label: String) -> void:
	_stage_done_ms += float(STAGE_MS.get(label, 50))
	var tot := 0.0
	for k in STAGE_MS: tot += float(STAGE_MS[k])
	_stage_cb.call(clampf(_stage_done_ms / tot, 0.0, 1.0), "map" if label == "build.generate" or label.begins_with("world.") else "spawn")

## Under the loading screen: draws every material in the match once on tiny stand-ins (a batch a
## frame, see _warm_batches), then the world once from far above (every island, prop, wall, cloud
## layer and landmark in view), once close to the ground (grass, flowers, undergrowth) and once from
## where the match starts, with one of each effect in front of the camera, then stand-ins for what
## those views added (the effects), so the GPU compiles every shader before play instead of when the
## drop first shows it. The last frames double as the
## auto-quality benchmark (Settings.note_benchmark). progress(frac 0..1) as it goes.
func warm_up(progress := Callable()) -> void:
	if DisplayServer.get_name() == "headless" or cam == null or world == null:
		return
	PerfLog.skip()
	var keep := [cam.global_transform, cam.fov, cam.far]
	var ctr := Vector3(world.w * 0.5, 0.0, world.h * 0.5)
	var ground := ctr
	if player and player.ai.has("land"): ground = player.ai["land"]
	ground.y = world.ground_at(ground.x, ground.z) if not world.is_void(ground.x, ground.z) else 0.0
	var views := [
		[ctr + Vector3(0, maxf(world.w, world.h) * 1.05, maxf(world.w, world.h) * 0.4), ctr, 62.0, 900.0],
		[ground + Vector3(0, 22.0, 11.0), ground, 40.0, 160.0],
		[ground + Vector3(0, 60.0, 30.0), ground, 40.0, 300.0],
	]
	# the sight-cone texture the toon shaders read once you've landed: set now, not on landing
	if not _vis_tex_done:
		_vis_tex_done = true
		RenderingServer.global_shader_parameter_set("vis_blocks", world.vis_texture())
		RenderingServer.global_shader_parameter_set("vis_size", Vector2(world.w, world.h))
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
	for k in kins:
		for pn in (k as Node).find_children("*", "Node", true, false):
			if pn is KinPuppet and pn.get("stars") == null and pn.get("body") != null:
				pn.call("_make_stars")
				break
		break
	if player: player.warm_marker()      # and the hit-marker balloon over a Hunter
	var seen := {}
	var batch_cb := func(f: float) -> void:
		if progress.is_valid(): progress.call(0.7 * f)
	var aim_warm := _warm_aim_stand_in()      # (item 94c: the aim kit's one material draws only once somebody aims)
	var batched: bool = await _warm_batches(batch_cb, seen)
	if is_instance_valid(aim_warm): aim_warm.queue_free()
	if not batched:
		return
	var shown: Array = []
	for i in 3:
		var sm: MeshInstance3D = shot_pool[i]
		sm.visible = true
		shown.append(sm)
	for vi in views.size():
		var v: Array = views[vi]
		var at: Vector3 = v[1]
		cam.global_transform = Transform3D(Basis.looking_at(at - (v[0] as Vector3), Vector3.UP), v[0])
		cam.fov = v[2]; cam.far = v[3]
		# one of each effect where the camera looks
		fx.burst(at + Vector3(0, 1, 0), Color.WHITE, 6)
		fx.ring(at, 1.5, Color.WHITE)
		fx.flash(at + Vector3(0, 1, 0), Color.WHITE)
		fx.spark(at + Vector3(0, 1, 0), Vector3.UP, Color.WHITE, 4)
		fx.slash(at + Vector3(0, 0.8, 0), 0.0, 2.0, 1.6, Color.WHITE)
		fx.beam(at + Vector3(0, 1, 0), at + Vector3(2, 1, 0), Color.WHITE)
		HeroVfx.of(self).prewarm(at + Vector3(0, 1, 0))
		var tg := fx.telegraph_circle(at, 1.5, Color(1, 0.3, 0.2))
		# the muzzle flash light lights whatever stands near a shot: the lit variants compile now too
		if muzzle_light:
			muzzle_light.global_position = at + Vector3(0, 1.0, 0)
			muzzle_light.light_energy = 0.05
		for k in shown.size():
			(shown[k] as MeshInstance3D).global_position = at + Vector3(k - 1.0, 1.0, 0)
		# the ground views draw with the sight cone on, as play does after landing
		RenderingServer.global_shader_parameter_set("vis_on", 0.0 if vi == 0 else 1.0)
		RenderingServer.global_shader_parameter_set("vis_focus", at)
		await get_tree().process_frame
		await get_tree().process_frame
		fx.end_telegraph(tg)
		if not is_inside_tree():
			return
		if progress.is_valid(): progress.call(0.7 + 0.2 * (vi + 1) / views.size())
	HeroVfx.of(self).prewarm_end()
	# and the materials that only exist now (the effects just shown, the shots), the same way: a
	# telegraph is held up for it (the views' own are gone by now)
	var late_cb := func(f: float) -> void:
		if progress.is_valid(): progress.call(0.9 + 0.1 * f)
	var late_at := cam.global_position - cam.global_transform.basis.z * 6.0
	var tg_late := fx.telegraph_circle(late_at, 1.5, Color(1, 0.3, 0.2))
	# (and a still copy of a melee swoosh: the real one frees itself in a fifth of a second)
	fx.slash(late_at, 0.0, 2.0, 1.6, Color.WHITE)
	var swoosh: Node = null
	if fx.get_child_count() > 0 and fx.get_child(fx.get_child_count() - 1) is MeshInstance3D:
		swoosh = fx.get_child(fx.get_child_count() - 1).duplicate(0)
		add_child(swoosh)
		(swoosh as Node3D).global_position = late_at
	batched = await _warm_batches(late_cb, seen)
	if not batched:
		return
	fx.end_telegraph(tg_late)
	if swoosh: swoosh.queue_free()
	for sm in shown: (sm as MeshInstance3D).visible = false
	if muzzle_light: muzzle_light.light_energy = 0.0
	RenderingServer.global_shader_parameter_set("vis_on", 0.0)
	cam.global_transform = keep[0]; cam.fov = keep[1]; cam.far = keep[2]
	PerfLog.mark("build.warm_up")
	# the benchmark: a few frames of the opening view
	var times: Array = []
	var last := Time.get_ticks_usec()
	for i in 8:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		if i >= 2: times.append((now - last) / 1000.0)
		last = now
	times.sort()
	if not times.is_empty():
		Settings.note_benchmark(float(times[times.size() / 2]))
	await DashPace.rehearse(self)
	PerfLog.skip()

## Stand-ins drawn in the first batch of warm_up; later batches grow while a batch's frames stay
## cheap and shrink when one costs more than WARM_FRAME_MS over a plain frame (a first draw is
## where a GPU compiles a shader). Only how many frames the warm-up takes depends on it.
const WARM_BATCH := 8
const WARM_FRAME_MS := 45.0

## The stand-ins of warm_up, a batch a frame, each batch drawn once under each light setup.
## False if the match went away meanwhile.
## The aim kit (AimKit: every kit's aim lines, rings and the Hem draw's fill line and perfect circle) draws one
## ImmediateMesh that is empty until a Hunter aims, so the scan below never sees its material and the first
## aim after landing compiled its shader mid-play. A one-triangle mesh with the same material and vertex
## format stands in for it for the warm-up.
func _warm_aim_stand_in() -> MeshInstance3D:
	var d := AimKit.layer(self)
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
	add_child(mi)
	return mi

func _warm_batches(progress: Callable, seen: Dictionary) -> bool:
	var list: Array = await _warm_sources(seen)
	if not is_inside_tree():
		return false
	if list.is_empty():
		return true
	var basis := cam.global_transform.basis
	var front := cam.global_position - basis.z * 6.0
	var wl := _warm_lights()
	# the camera sees only the stand-ins meanwhile (their own render layer): the lights, shadows and
	# environment that pick a shader's variant are all still there, but each batch's frame no longer
	# draws the whole map again
	var keep_mask := cam.cull_mask
	cam.cull_mask = WARM_LAYER
	# (a camera culls lights by their layers too: every light joins the stand-ins' layer meanwhile,
	# or they'd all draw unlit)
	var lights := find_children("*", "Light3D", true, false)
	var keep_layers: Array = []
	for l in lights:
		keep_layers.append((l as Light3D).layers)
		(l as Light3D).layers |= WARM_LAYER
	# what a frame costs with nothing new in it, to tell a batch's own cost from plain drawing
	await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	await get_tree().process_frame
	var plain := (Time.get_ticks_usec() - t0) / 1000.0
	if not is_inside_tree():
		return false
	var n := WARM_BATCH
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
			var px := _warm_proxy(batch[k])
			if px == null:
				continue
			add_child(px)
			_warm_layer(px)
			var gx := (float(k % cols) / maxf(1.0, cols - 1) - 0.5) * 2.4
			var gy := (float(k / cols) / maxf(1.0, cols - 1) - 0.5) * 1.4
			px.global_transform = Transform3D(basis.scaled(Vector3.ONE * 0.04), front + basis.x * gx + basis.y * gy)
			pxs.append(px)
		var worst := 0.0
		# two frames under each light setup (with one, a variant or two still slips through to the
		# ride: --hitch-check from a cold shader cache)
		for setup in [[false, false], [true, false], [false, true], [true, true]]:
			wl[0].visible = setup[0]; wl[1].visible = setup[1]
			for _f in 2:
				await get_tree().process_frame
				if not is_inside_tree():
					return false
				var now := Time.get_ticks_usec()
				worst = maxf(worst, (now - t0) / 1000.0)
				t0 = now
		batches += 1
		for px in pxs: (px as Node).queue_free()
		i += batch.size()
		progress.call(float(i) / list.size())
		var extra := worst - plain
		if extra > WARM_FRAME_MS:
			n = maxi(4, n / 2)
		elif extra < WARM_FRAME_MS * 0.4:
			n = mini(n * 2, 512)
	await get_tree().process_frame
	for li in lights.size():
		if is_instance_valid(lights[li]): (lights[li] as Light3D).layers = keep_layers[li]
	for l in wl: (l as Node).queue_free()
	cam.cull_mask = keep_mask
	PerfLog.note("warm-up: %d stand-ins in %d batches" % [list.size(), batches])
	return is_inside_tree()

## The render layer warm_up's stand-ins draw on (nothing else in the game uses it).
const WARM_LAYER := 1 << 19
func _warm_layer(px: Node) -> void:
	if px is VisualInstance3D: (px as VisualInstance3D).layers = WARM_LAYER
	for ch in px.get_children(): _warm_layer(ch)

## One instance of each material and kind of geometry in the match (see _warm_key) not in seen yet,
## for warm_up's stand-ins (adds them to seen). Walks the tree a slice at a time so the loading
## screen keeps moving.
func _warm_sources(seen: Dictionary) -> Array:
	var list: Array = []
	var stack: Array = [self]
	var t0 := Time.get_ticks_usec()
	while not stack.is_empty():
		if Time.get_ticks_usec() - t0 > int(PerfLog.SLICE_MS * 1000.0):
			await get_tree().process_frame
			if not is_inside_tree():
				return []
			t0 = Time.get_ticks_usec()
		var n = stack.pop_back()
		if not is_instance_valid(n):
			continue
		for ch in (n as Node).get_children(): stack.append(ch)
		if n is Skeleton3D:
			# skinned meshes run a skinning shader of their own, first when one is drawn: a copy of
			# one rig of each make (its meshes follow it, their skeleton path is relative)
			var sk := "skel:" + ",".join(n.get_children().filter(func(c): return c is MeshInstance3D).map(func(c): return str((c as MeshInstance3D).mesh.get_instance_id() if (c as MeshInstance3D).mesh else 0)))
			if not seen.has(sk) and seen.size() < 2000:
				seen[sk] = true
				list.append(n)
			continue
		if not (n is GeometryInstance3D):
			continue
		var key := _warm_key(n as GeometryInstance3D)
		if key.is_empty() or seen.has(key):
			continue
		seen[key] = true
		list.append(n)
		if list.size() >= 900:
			break
	return list

## What decides which shader variants an instance compiles: the kind of geometry and each surface's
## shader (a StandardMaterial3D by the features its generated shader depends on). Empty: draws nothing.
static func _warm_key(gi: GeometryInstance3D) -> String:
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
	elif gi is Label3D or gi is Sprite3D:
		var sb := gi as GeometryInstance3D
		var parts: Array = [kind, sb.get("billboard"), sb.get("shaded"), sb.get("double_sided"), sb.get("no_depth_test"), sb.get("fixed_size"),
			sb.get("alpha_cut"), sb.get("texture_filter"), sb.get("transparent"), sb.material_override]
		return str(parts)
	else:
		return ""
	if mesh == null or mesh.get_surface_count() == 0:
		return ""
	var mats: Array = []
	if gi.material_override:
		mats.append(_warm_mat_key(gi.material_override))
	else:
		for si in mesh.get_surface_count():
			var mt: Material = (gi as MeshInstance3D).get_active_material(si) if gi is MeshInstance3D else mesh.surface_get_material(si)
			mats.append(_warm_mat_key(mt))
	if gi.material_overlay:
		mats.append("+" + _warm_mat_key(gi.material_overlay))
	return kind + ":" + ",".join(mats)

static var _mat_keys := {}
static func _warm_mat_key(mt: Material) -> String:
	if mt == null:
		return "default"
	var id := mt.get_instance_id()
	if _mat_keys.has(id):
		return _mat_keys[id]
	if _mat_keys.size() > 20000: _mat_keys.clear()
	var s := ""
	if mt is ShaderMaterial:
		var sh: Shader = (mt as ShaderMaterial).shader
		s = "sh%d" % (sh.get_instance_id() if sh else 0)
	elif mt is BaseMaterial3D:
		# the generated shader depends on its switches and modes and on which textures are set,
		# not on colours and amounts
		s = "std"
		for pr in mt.get_property_list():
			if not (int(pr["usage"]) & PROPERTY_USAGE_STORAGE):
				continue
			var t := int(pr["type"])
			if t == TYPE_BOOL or t == TYPE_INT:
				s += "%d" % int(mt.get(pr["name"]))
			elif t == TYPE_OBJECT:
				s += "1" if mt.get(pr["name"]) is Texture else "0"
	else:
		s = mt.get_class()
	if mt.next_pass:
		s += ">" + _warm_mat_key(mt.next_pass)
	_mat_keys[id] = s
	return s

## A tiny copy of an instance that draws with the same shaders.
func _warm_proxy(src: Node3D) -> Node3D:
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
		if px is CPUParticles3D:
			var cp := px as CPUParticles3D
			cp.amount = mini(cp.amount, 4)
			cp.local_coords = true
			cp.one_shot = false
			cp.emitting = true
			cp.preprocess = maxf(cp.preprocess, 0.2)
	if px == null:
		return null
	if not (src is CPUParticles3D or src is Label3D or src is Sprite3D):
		px.material_override = gsrc.material_override
		px.material_overlay = gsrc.material_overlay
	px.cast_shadow = gsrc.cast_shadow
	px.visibility_range_end = 0.0
	px.visibility_range_begin = 0.0
	return px

## The lights a stand-in can be lit by in play: an omni like the muzzle flash and the lamps, and a
## spot like the sky train's headlight, both covering the grid of stand-ins.
func _warm_lights() -> Array:
	var basis := cam.global_transform.basis
	var front := cam.global_position - basis.z * 6.0
	var o := OmniLight3D.new()
	o.omni_range = 4.0
	o.light_energy = 0.05
	o.shadow_enabled = false
	add_child(o)
	o.global_position = front - basis.z * 0.5
	var sp := SpotLight3D.new()
	sp.spot_range = 14.0
	sp.spot_angle = 35.0
	sp.light_energy = 0.05
	sp.shadow_enabled = false
	add_child(sp)
	sp.global_transform = Transform3D(basis, cam.global_position)
	return [o, sp]

## Tooling (--perf-probe): microseconds per section of step(), summed while prof_on.
static var prof_on := false
static var prof := {}
var _prof_t := 0
func _prof(lbl: String) -> void:
	if prof_on:
		var now := Time.get_ticks_usec()
		if _prof_t > 0 and lbl != "pre": prof[lbl] = int(prof.get(lbl, 0)) + now - _prof_t
		_prof_t = now

## Tooling (--hitch-check): microseconds per section of _process (the per-frame visuals).
static var vprof := {}
var _vprof_t := 0
func _vprof(lbl: String) -> void:
	if prof_on:
		var now := Time.get_ticks_usec()
		if _vprof_t > 0 and lbl != "pre": vprof[lbl] = int(vprof.get(lbl, 0)) + now - _vprof_t
		_vprof_t = now

var _render_n := 0
func _render_now(e: Ent, cf: Vector3, near2: float) -> bool:
	if e.dead or e.lod_dt > 0.2:
		return true
	if Vector2(e.pos.x - cf.x, e.pos.z - cf.z).length_squared() < near2:
		return true
	return (_render_n + e.get_instance_id()) % 4 == 0

## Monsters, kin, chests, crates, shrines and loot are each several meshes; from the skyship the
## whole map is in view and they'd be thousands of draws, a few pixels each. Past a distance (more
## for big pieces, Settings q("draw") scales it) they're skipped; the play and drop views never reach it.
const RANGE_SMALL := 80.0
const RANGE_BIG := 125.0
static func _draw_range(root: Node) -> void:
	var k := float(Settings.q("draw"))
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children(): stack.append(ch)
		if n is GeometryInstance3D and not (n is Label3D) and (n as GeometryInstance3D).visibility_range_end <= 0.0:
			var gi := n as GeometryInstance3D
			var sz := gi.get_aabb().size * gi.global_transform.basis.get_scale().abs() if gi.is_inside_tree() else gi.get_aabb().size
			gi.visibility_range_end = (RANGE_SMALL if maxf(sz.x, maxf(sz.y, sz.z)) < 0.35 else RANGE_BIG) * k
			gi.visibility_range_end_margin = 6.0

## Small parts (eyes, buckles, gems, pebbles) stop casting shadows: every caster is drawn again in each
## shadow cascade, and at this camera height their shadows are a pixel or two.
const SHADOW_MIN := 0.28
static func _trim_shadows(root: Node) -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh and mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				var sz := mi.mesh.get_aabb().size * mi.scale.abs()
				if maxf(sz.x, maxf(sz.y, sz.z)) < SHADOW_MIN:
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for ch in n.get_children():
			if not (ch is MultiMeshInstance3D):
				stack.append(ch)

func _start(o: Dictionary) -> void:
	ShadowPolicy.watch_particles(get_tree())      # no particle system casts a shadow (item 94)
	PerfLog.reset()
	_stage_done_ms = 0.0
	opts = o
	if o.get("tutorial", false): tut = Tutorial.new(self)
	seed_val = int(o.get("seed", randi()))
	rng.seed = seed_val
	seed(seed_val)
	# real expeditions happen on the big map and start from the skyship
	big = not (o.get("tutorial", false) or o.get("training", false)) and o.get("big", true)
	length = float(o.get("length", Data.MATCH["length"] * (1.7 if big else 1.0)))
	if Rolling.enabled(o):
		# a rolling session: the waves, which one you're in, who's out there already (sets length and sess_t0)
		rolling = Rolling.new(self)
		rolling.plan(o)
	tier = clampi(int(o.get("tier", 0)), 0, Data.TIERS.size() - 1)
	T = Data.TIERS[tier]
	bot_diff = String(o.get("bot_diff", Settings.get_v("bot_diff")))
	if not Data.BOT_DIFF.has(bot_diff):
		bot_diff = Data.auto_bot_diff(tier, int(Save.d.get("extracts", 0)), o.get("tutorial", false) or o.get("training", false))
	bot_cfg = Data.BOT_DIFF[bot_diff]
	_build_env()
	music_dir = MusicDir.new()
	music_dir.start(self)
	Sfx.play_ambience("match")
	world = World.new()
	world.name = "World"
	world.biome = T["biome"].duplicate()
	world.clouds = T["clouds"]
	add_child(world)
	# real expeditions are on a hand-made map, and so is the tutorial (a small calm one); training keeps a generated one
	var layout := {}
	# --procgen (or opts.procedural): the old island generator instead, as a fallback
	if big and not o.get("procedural", false) and not "--procgen" in OS.get_cmdline_user_args():
		layout = WideLayout.pick(o, rolling != null, tier)     # a rolling session gets the wide Skyreach; otherwise the expedition map
	elif o.get("tutorial", false):
		layout = World.load_layout("tutorial")
	elif o.get("arena", false):
		layout = World.load_layout("arena")     # the practice arena (scripts/match/arena.gd)
	map_name = String(layout.get("name", ""))
	if _stage_cb.is_valid(): world.stage_cb = _world_step
	if not layout.is_empty():
		await world.generate_authored(layout, seed_val)
	else:
		world.generate(seed_val, World.BIG_SIZE if big else 64, World.BIG_ISLANDS if big else 7)
	await _stage("build.generate")
	await world.build_meshes()
	RaidLook.tune_world(world, raid)
	if DepthCues.k() > 0.0: add_child(DepthCues.new(self))
	world.stage_cb = Callable()
	fx = Fx.new(); fx.name = "Fx"; add_child(fx)
	brk = Breakables.new(self)
	fields = Fields.new(self)
	verbs = Verbs.new(self)
	displace = Displace.new(self)
	if world.layout_id != "" and not o.get("tutorial", false):
		biomes = BiomeRun.new(self)
		if biomes.active():
			biomes.decorate()
			biomes.place_hazards()
		else:
			biomes.free_up(); biomes = null
	# the combat systems listen to hits and statuses: bond meter and combos
	_bond_cb = func(a, t, amt, tags): Bond.on_hit(a, t, amt, tags)
	_combo_cb = func(t, st, by, dur): Combos.record(t, st, by, dur)
	CombatBus.hit_landed.connect(_bond_cb)
	CombatBus.status_applied.connect(_combo_cb)
	add_child(HunterFeats.new(self))      # the feats Hunter challenges count
	cam = CamRig.new(); cam.name = "Cam"; add_child(cam)
	cam.lead = float(Settings.get_v("cam_lead"))
	cam_style = String(Settings.get_v("cam_style"))
	cam.use_style(cam_style)
	_build_shot_pool()
	if o.has("net"):
		net_on = true
		is_host = Net.me == String(o["net"]["host"])
		Net.begin_match("kf-" + String(o["net"]["mid"]), String(o["net"]["host"]), self)
	await _stage("build.systems")
	await _spawn_pads_and_exits()
	await _stage("build.pads_exits")
	await _spawn_hunters()
	if tut: tut.setup()
	await _stage("build.hunters")
	if not opts.get("tutorial", false) and not opts.get("duel", false) and not opts.get("arena", false):
		await _spawn_mobs()        # the tutorial brings its own monsters, one step at a time
	await _stage("build.mobs")
	if not opts.get("duel", false) and not opts.get("arena", false):
		await _spawn_chests()
	await _stage("build.chests")
	if not world.train_route.is_empty() and not opts.get("duel", false) and not opts.get("arena", false):
		skytrain = SkyTrain.new()
		skytrain.name = "SkyTrain"
		add_child(skytrain)
		skytrain.setup(self)
	await _slice()
	Beacons.place(self)
	await _slice()
	if not opts.get("arena", false):
		await _spawn_breakables()
	await _slice()
	for rg in world.rings:
		var rn := Models.air_ring()
		rn.position = rg["pos"]
		rn.rotation.y = atan2(float(rg["dir"].x), float(rg["dir"].y))
		add_child(rn)
		air_rings.append({"pos": rg["pos"], "dir": rg["dir"], "node": rn, "cd": {}})
	if o.get("break_demo", false) and player and not breaks.is_empty():
		# test: stand by some breakables with two found weapons on the ground
		var b0: Vector3 = breaks[0]["pos"]
		for b in breaks:
			if b["kind"] == "keg": b0 = b["pos"]; break
		player.teleport(b0 + Vector3(2.2, 0, 0.6))
		spawn_gear("quickstep_boots", 3, b0 + Vector3(1.6, 0, 1.8), "", false)
		spawn_gear("bastion_plate", 4, b0 + Vector3(3.0, 0, 1.6), "", false)
	if o.get("chest_demo", false) and player: PolishTools.chest_row(self)     # test: crate/chest/pot/keg in a row
	if player and (has_meta("stairs_demo") or o.get("chest_demo", false)): PolishTools.clear_mobs(self)
	if not opts.get("duel", false) and not opts.get("arena", false):
		await _spawn_wild()
	await _slice()
	if not (opts.get("duel", false) or opts.get("tutorial", false) or opts.get("training", false)):
		# the map is fixed; what's out on it this time isn't (rare kin, vaults, item caches, boss lairs)
		spawn_plan = SpawnPlan.new(self)
		spawn_plan.build(layout)
		if lairs: lairs.plug_into(spawn_plan)     # which boss lairs are live this match
		spawn_plan.roll(seed_val)
		if opts.has("live_lair"):
			# a fixed roll for a filmed match (the Demo match): this lair is live, in place of another
			var keep: Array = spawn_plan.of("boss").filter(func(c): return String(c["name"]) == String(opts["live_lair"]))
			if not keep.is_empty() and not keep[0]["active"]:
				var on: Array = spawn_plan.active_of("boss")
				if not on.is_empty(): on[-1]["active"] = false
				keep[0]["active"] = true
		await spawn_plan.spawn_all()
	if lairs: lairs.ensure_live()
	if BlightDir.enabled(opts) and big and world.layout_id != "tutorial":
		# the Blight: Wardens on the islands from the start, Skitters later (scripts/match/blight_dir.gd)
		blight = BlightDir.new(self)
		blight.setup()
	if rolling:
		rolling.after_setup()      # the map as picked over as the session is old
	if not (opts.get("duel", false) or opts.get("arena", false) or opts.get("tutorial", false)):
		keys = KeyRun.new(self)
		keys.setup()               # who carries the chest keys, and the Shrublings
	await _slice()
	_trim_shadows(self)
	for list in [mobs, kins, chests, breaks, shrines, wpicks]:
		for it in list:
			var nd = it if it is Node else (it as Dictionary).get("node")
			if nd is Node: _draw_range(nd)
	await _stage("build.spawns")
	skydrop = DropSquad.new(self)
	skydrop.setup()
	if opts.get("demo_match", false): _demo_drop()
	await _slice()
	var Hud = take_prefetched(HUD_SCRIPT)
	hud = Hud.new()
	hud.name = "Hud"
	await _slice()
	add_child(hud)
	# (set up in slices under the loading screen: kept still and hidden until it's whole)
	var hud_mode := hud.process_mode
	hud.process_mode = Node.PROCESS_MODE_DISABLED
	hud.visible = false
	await hud.setup(self)
	hud.process_mode = hud_mode
	hud.visible = true
	if player and player.dropping and tut == null:
		hud.toast("Steer to choose where you land", Color("f3eee2"))
	if skydrop.planning and player:
		hud.open_map(true)
	if player:
		cam.snap(player.pos)
	if opts.get("duel", false) and player:
		duel = Duel.new()
		duel.setup(self)
		duel.attach_keys()
		hud.toast("Duel room  ·  B sets up the bot  ·  Backspace resets", Color("f3eee2"))
	if player and duel == null and not opts.get("tutorial", false) and (opts.get("arena", false) or opts.get("practice", false)):
		# the Arena, and the same practice tools on the training island (dummies, swaps, kit card)
		arena = Arena.new()
		arena.setup(self, "arena" if opts.get("arena", false) else "practice")
	Practice.attach(self)      # the practice areas' bottom bar, J hero picker and wheel zoom
	await _stage("build.hud")
	_build_aim()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Bridge.kin_lines_for_match(self)
	await _stage("build.finish")
	set_process(true)

func next_id(prefix: String) -> String:
	nid_n += 1
	return "%s%d" % [prefix, nid_n]

# ------------------------------------------------------------------ setup
func _build_env() -> void:
	env = WorldEnvironment.new()
	var sky: Color = T["sky"]
	var amb: Color = T["ambient"]
	var cl: Array = T["clouds"]
	env.environment = Look.environment({"top": sky.darkened(0.2), "mid": sky.lerp(amb, 0.35), "horizon": (cl[1] as Color).lerp(T["sun"], 0.5).lightened(0.15),
		"below": cl[0], "ambient": amb, "ambient_energy": 0.5, "fog": (cl[1] as Color).lightened(0.12).lerp(Color("4a5aa8"), 0.35), "sun_col": T["sun"]})
	add_child(env)
	var sun := Look.lights(self, T["sun"], 1.0, Vector3(-55, -35, 0), 60.0)
	sun.shadow_opacity = 0.8
	# the raid condition: rolled from the seed on real expeditions, clear otherwise (scripts/match/raid_look.gd)
	raid = RaidLook.pick(opts, seed_val)
	RaidLook.apply(env.environment, sun, get_node_or_null("Fill") as DirectionalLight3D, T, raid)
	sight_k = float(RaidLook.SIGHT.get(raid, 1.0))
	RenderingServer.global_shader_parameter_set("vis_dark", 1.0 if "--shot-bright" in OS.get_cmdline_user_args() else float(RaidLook.VIS_DARK.get(raid, 0.7)))     # (--shot-bright: map screenshots without the sight shading)
	RenderingServer.global_shader_parameter_set("vis_ally_range", VIEW_RANGE * sight_k)
	raid_fx = RaidLook.storm_fx(raid)
	if raid_fx:
		add_child(raid_fx)

## How far a hunter sees under this raid condition (crouching shortens it, as before).
func view_range(crouched := false) -> float:
	return (14.0 if crouched else VIEW_RANGE) * sight_k

func _build_shot_pool() -> void:
	var mesh := Models.sphere(0.5, 10)
	for i in 160:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = Models.glow_mat(Color.WHITE)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		# a soft halo round every bolt, so shots glow instead of reading as specks (Oomph.shot_look)
		var halo := MeshInstance3D.new()
		halo.name = "Halo"
		halo.mesh = mesh
		halo.material_override = Models.glow_mat(Color(1, 1, 1, 0.3))
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.scale = Vector3(2.3, 2.3, 1.5)
		mi.add_child(halo)
		add_child(mi)
		shot_pool.append(mi)

func _spawn_pads_and_exits() -> void:
	for pd in world.pads:
		await _slice()
		var n := Models.jump_pad(Color("8fe3c8"))
		n.position = pd["pos"]
		n.rotation.y = atan2(-(pd["land"].x - pd["pos"].x), -(pd["land"].z - pd["pos"].z))
		add_child(n)
		pd["node"] = n
		# where it goes: a sign over the pad, and the flight path and landing ring when you're close
		var to_role: String = world.islands[pd["to"]]["role"] if pd["to"] < world.islands.size() else ""
		var lbl := Label3D.new()
		var to_name: String = String(world.islands[pd["to"]].get("name", "")) if pd["to"] < world.islands.size() else ""
		lbl.text = "to " + (to_name if to_name != "" else String({"heart": "the Heart", "camp": "the monster camp", "nest": "the Boki nest", "grove": "the grove", "shrine": "the shrine"}.get(to_role, "the next island")))
		lbl.font = UI.big; lbl.font_size = 34; lbl.pixel_size = 0.01; lbl.outline_size = 10
		lbl.modulate = Color("c9fff0"); lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lbl.no_depth_test = true
		lbl.position = pd["pos"] + Vector3(0, 1.3, 0)
		add_child(lbl)
		var arc := Node3D.new()
		var a: Vector3 = pd["pos"]; var b: Vector3 = pd["land"]
		var dist := Vector2(b.x - a.x, b.z - a.z).length()
		var hh := maxf(a.y, b.y) - a.y + 2.5 + dist * 0.12
		var dm := Models.sphere(0.07, 8)
		var mat := Models.glow_mat(Color("bff7e6"))
		for i in range(1, 18):
			var k := i / 18.0
			var mi := MeshInstance3D.new(); mi.mesh = dm; mi.material_override = mat
			mi.position = Vector3(lerpf(a.x, b.x, k), lerpf(a.y, b.y, k) + 4.0 * hh * k * (1.0 - k) + 0.3, lerpf(a.z, b.z, k))
			arc.add_child(mi)
		var ring := MeshInstance3D.new()
		var rm := PlaneMesh.new(); rm.size = Vector2(1.6, 1.6); ring.mesh = rm
		ring.material_override = Models.ring_mat(Color("8fe3c8"))
		ring.position = b + Vector3(0, 0.05, 0)
		arc.add_child(ring)
		arc.visible = false
		add_child(arc)
		pd["arc"] = arc
	await _slice()
	exits = Exits.new()
	await exits.setup(self)
	await _slice()
	truce = Truce.new(self)
	lairs = Lairs.new()
	lairs.setup(self)

func make_hunter(id: String, team: int, cls: String, pname: String, ctrl: String, kin_rec: Dictionary, at: Vector3, kit := {}, kin_rec2 := {}) -> Hunter:
	var h := Hunter.new()
	if cls == "" or not Data.CLASSES.has(cls):
		cls = ["light", "medium", "heavy"][rng.randi_range(0, 2)]
	if String(kit.get("weapon", "")) == "?":
		kit = kit.duplicate()
		# bots get an archetype of their class, and a weapon from its family
		if ctrl != "local" and String(kit.get("arch", "")) in ["", "?"]:
			kit["arch"] = Arch.pick_for(cls, "%s|%s" % [id, str(seed_val)])
		var pool: Array = Data.CLASSES[cls]["weapons"]
		if Arch.exists(String(kit.get("arch", ""))) and Arch.weight(String(kit["arch"])) == cls:
			pool = Arch.weapons(String(kit["arch"]))
		kit["weapon"] = pool[rng.randi_range(0, pool.size() - 1)]
	h.init_hunter(self, id, team, cls, pname, ctrl, kit)
	h.lives = 99 if (opts.get("tutorial", false) or opts.get("training", false)) else int(T.get("lives", 2))
	if opts.get("tutorial", false) or opts.get("training", false) or opts.get("duel", false) or opts.get("sandbox", false) or opts.get("unlocked", false):
		h.unlock_all()        # practice modes (and the sim's scripted player) start with the whole kit
	elif ctrl == "bot":
		var gr := RandomNumberGenerator.new(); gr.seed = hash("%s|%s|gear" % [id, str(seed_val)])      # (its own stream: the match's rolls stay put)
		GearDrops.bot_start(h, gr, bot_diff)       # bots start with some gear, more of it on harder settings
	add_child(h)
	h.teleport(at)
	hunters.append(h)
	ents_by_id[id] = h
	if not kin_rec.is_empty():
		var k := Kin.new()
		k.init_kin(self, id + "k", kin_rec["species"], kin_rec, h)
		add_child(k)
		k.teleport(at + Vector3(1.0, 0, 0.7))        # out at your side (KinFollow)
		kins.append(k)
		ents_by_id[k.nid] = k
		h.kin = k
		h.apply_kin_bonus()        # its owner bonus points (max health, armor, shield, regen, speed)
		if Mutations.owner_stat(kin_rec, "armor") > 0.0:
			h.refresh_gear(); h.armor = h.max_armor      # a Crystal kin hardens its hunter's armor
	if TWO_KIN and not kin_rec2.is_empty() and not kin_rec.is_empty():
		# (retired) everyone brought two kin: the second waited on the bench until you swapped
		var k2 := Kin.new()
		k2.init_kin(self, id + "k2", kin_rec2["species"], kin_rec2, h)
		add_child(k2)
		k2.teleport(at)
		k2.bench()
		kins.append(k2)
		ents_by_id[k2.nid] = k2
		h.kin2 = k2
	return h

## Who B would take you to: the teammate nearest the cursor on screen (alive, standing, not out).
func base_target(h: Hunter) -> Hunter:
	var mates: Array = hunters.filter(func(o): return o != h and o.team == h.team and not o.out and not o.downed and not o.extracted and not o.dropping and not o.riding)
	if mates.is_empty():
		return null
	if h != player or mates.size() == 1:
		return mates[0]
	var mp := get_viewport().get_mouse_position()
	var best: Hunter = mates[0]; var bd := 1e9
	for o in mates:
		var sp := cam.unproject_position(o.pos) if not cam.is_position_behind(o.pos) else Vector2(1e6, 1e6)
		var d := sp.distance_to(mp)
		if d < bd: bd = d; best = o
	return best

## How high the player is over the ground under them (over the abyss: over the last ground they stood on).
func player_altitude() -> float:
	if player == null:
		return 0.0
	var g := world.ground_at(player.pos.x, player.pos.z) if not world.is_void(player.pos.x, player.pos.z) else player.last_gy
	return maxf(0.0, player.pos.y - g)

## One kin per expedition: a short, readable kit. Flip back on to bring a benched second kin again.
const TWO_KIN := false

func my_kit() -> Dictionary:
	return {"weapon": String(opts.get("weapon", Save.d.get("weapon", ""))), "perk": "", "arch": String(opts.get("arch", Save.d.get("arch", "")))}

func bot_kit() -> Dictionary:
	# the weapon is picked once the bot's class is known (see make_hunter): any of its class's
	return {"weapon": "?", "perk": ""}

var _kin_seed_n := 0
## A seed for a wild or bot kin's inborn rolls (Unique: size, looks, habits), made from the match
## seed: the same every run of a seeded match, and neither rng nor the global stream is touched.
func kin_seed(tag: String) -> int:
	_kin_seed_n += 1
	return hash("%d|%s|%d" % [seed_val, tag, _kin_seed_n]) & 0x7fffffff

var map_name := ""     # the authored map's name, for where a kin was caught
## Where a point is, for a caught kin's record: {map, island, biome, tier, tier_name}.
func where_at(p: Vector3) -> Dictionary:
	var w := {"map": map_name, "tier": tier, "tier_name": String(T.get("name", ""))}
	if world:
		var ii := world.island_of(p.x, p.z)
		if ii >= 0 and ii < world.islands.size():
			var nm := String((world.islands[ii] as Dictionary).get("name", ""))
			if nm != "": w["island"] = nm
		var b := world.biome_at(p.x, p.z)
		if b != "": w["biome"] = b
	return w

var _bot_iv_n := 0
func bot_kin_record() -> Dictionary:
	var sp: String = Data.common_kin()[rng.randi_range(0, Data.common_kin().size() - 1)]
	var rec := Save.new_kin(sp, "", kin_seed("bot"))
	rec["trust"] = rng.randf_range(40, 80)
	rec["level"] = rng.randi_range(1, 4 + tier * 3)
	Evo.simulate(rec, rng)
	# IVs from the match seed (a new kin's come from its clock-based uid, so a seeded match would
	# give bots different stats every run); their own generator, so the match's rng stream is untouched
	var ivr := RandomNumberGenerator.new()
	ivr.seed = hash("%d|bot_ivs|%d" % [seed_val, _bot_iv_n])
	_bot_iv_n += 1
	rec["ivs"] = Care.roll_ivs(ivr)
	return rec

func _spawn_hunters() -> void:
	var n_teams := int(opts.get("teams", 4))
	var squad := int(opts.get("squad", 1))
	# one starting island per squad, spread out as far as possible
	var by_isl := {}
	for sp in world.spawns:
		var ii := world.island_of(sp.x, sp.z)
		if not by_isl.has(ii): by_isl[ii] = sp
	var pool: Array = by_isl.values()
	pool.shuffle()
	var spots: Array = []
	if pool.size() > 0:
		spots.append(pool.pop_back())
	while pool.size() > 0:
		var best := 0; var bd := -1.0
		for i in pool.size():
			var dmin := 1e9
			for q in spots: dmin = minf(dmin, Vector2(pool[i].x - q.x, pool[i].z - q.z).length())
			if dmin > bd: bd = dmin; best = i
		spots.append(pool[best]); pool.remove_at(best)
	# more squads than islands: share the bigger islands, still as far apart as possible
	if spots.size() < n_teams:
		var rest: Array = world.spawns.filter(func(q): return not spots.has(q))
		while spots.size() < n_teams and rest.size() > 0:
			var best := 0; var bd := -1.0
			for i in rest.size():
				var dmin := 1e9
				for q in spots: dmin = minf(dmin, Vector2(rest[i].x - q.x, rest[i].z - q.z).length())
				if dmin > bd: bd = dmin; best = i
			spots.append(rest[best]); rest.remove_at(best)
	if spots.is_empty():
		spots = world.spawns.duplicate()
	if tut:
		spots = [tut.stop("land")]
	var names: Array = Data.BOT_NAMES.duplicate(); names.shuffle()
	_bot_names = names
	if net_on:
		_spawn_net_hunters(spots, names)
		return
	if rolling:
		# who's already out there, then your wave's ship over the quiet side and its squads' spots under it
		rolling.populate_before(names)
		_setup_ship()
		spots = rolling.spots_along(ship, n_teams)
	var total := int(opts.get("total", 999))
	var made := 0
	var mates: Array = opts.get("mates", [])
	for t in n_teams:
		var base: Vector3 = spots[t % spots.size()] if spots.size() > 0 else world.random_ground()
		for s in squad:
			if made >= total and not (t == 0 and s == 0):
				break
			await _slice()
			made += 1
			var at := base
			if s > 0:
				for _k in 30:
					var q := base + Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6))
					if not world.is_void(q.x, q.z) and not world.is_block(q.x, q.z) and absf(world.ground_at(q.x, q.z) - base.y) < 0.3:
						at = Vector3(q.x, world.ground_at(q.x, q.z), q.z); break
			if t == 0 and s == 0 and not opts.get("spectate", false):
				var rec: Dictionary = Save.active_kin()
				var rec2: Dictionary = Save.second_kin()
				if opts.has("demo_kin"):
					var ids: Array = Data.common_kin()
					var sp0 := String(opts["demo_kin"])
					rec = Save.new_kin(sp0 if Data.KIN.has(sp0) else "cindle", "", kin_seed("demo"))
					rec["name"] = Data.KIN[rec["species"]]["name"]
					rec["trust"] = 95.0
					if opts.has("demo_kin_lv"):
						var lt := String(opts["demo_kin_lv"]).split(":")
						rec["level"] = int(lt[0])
						if lt.size() > 1: rec["trust"] = float(lt[1])
					rec2 = Save.new_kin(String(ids[(ids.find(rec["species"]) + 1) % ids.size()]), "", kin_seed("demo"))
				player = make_hunter("p0", 0, String(opts.get("cls", Data.class_of_save())), Save.d.get("name", "Hunter"), "bot" if opts.get("autoplay", false) else "local", rec, at, my_kit(), rec2)
				if opts.get("autoplay", false):
					player.ai = bot_brain.new_mind(rng, 0.7)
				at = PolishTools.stairs_start(self, at)     # test: --at-stairs[=N|E|W|S|N]
				if opts.has("at_xz"):
					# test: start at a given spot (map screenshots, --at=x,z)
					var axz := String(opts["at_xz"]).split(",")
					at = Vector3(float(axz[0]), 0, float(axz[1]))
					at.y = world.ground_at(at.x, at.z)
				if opts.has("zoom_hold"): set_meta("zoom_hold", float(opts["zoom_hold"]))
				player.teleport(at)
				Equal.start(self, player)       # gloves, boots and utility from home, capped by tier; nothing else (equal.gd)
				if player.kin:
					_apply_treat(player.kin)
				_start_drop(player, at)
				continue
			var mate: Dictionary = mates[s - 1] if t == 0 and s > 0 and s <= mates.size() else {}
			var h := make_bot(t, at, names, mate)
			_start_drop(h, at)

## A rival bot hunter for squad t, standing at `at` (the drop is up to the caller). `mate`: your
## squadmate the lobby dealt ({name, arch}, see Prematch.deal_mates), else a random one.
func make_bot(t: int, at: Vector3, names: Array, mate := {}) -> Hunter:
	var bk := bot_kit()
	var bname := "Bot"
	if not mate.is_empty():
		bname = String(mate["name"])
		bk["arch"] = String(mate["arch"])
	elif names.size() > 0:
		bname = names.pop_back()
	var brec := bot_kin_record()
	# a rival who's holding one of your lost kin may be out here with it
	var held := _held_for_match(t)
	if not held.is_empty():
		bname = String(held["holder"])
		brec = (held["rec"] as Dictionary).duplicate(true)
	var cls := Arch.weight(String(bk.get("arch", "")))
	var own_kin := bot_kin_record() if rng.randf() < 0.6 else {}
	var h := make_hunter(next_id("b"), t, cls, bname, "bot", brec, at, bk, own_kin)
	if not held.is_empty() and h.kin:
		(h.kin as Kin).lost_uid = String(brec.get("uid", ""))
		(h.kin as Kin).lost_from = "you"
		tracked.append({"kin": h.kin, "holder": h})
	h.ai = bot_brain.new_mind(rng, float(opts.get("bot_skill", bot_cfg["skill"])), bot_cfg)
	h.tonics = 3
	# rivals carry a little treasure: worth taking from their box
	if rng.randf() < 0.35 + 0.15 * tier:
		h.pack.append(Loot.valuable(Loot.roll_valuable(rng, mini(tier, 2))))
	if rng.randf() < 0.2: h.rift_keys = 1     # now and then a rival brings a key (and knows where the hatches are)
	if time > 0.0 and h.kin:
		_draw_range(h.kin)      # (as the kin made at the start get)
	return h

## Every match starts in the sky. Hunters glide down from above their squad's side of the map
## and steer to wherever they want to land.
func _start_drop(h: Hunter, at: Vector3) -> void:
	if opts.get("no_drop", false):
		return
	if big and time < 1.0:
		# everyone boards the skyship; bots plan to jump when it passes nearest their spot
		if ship.is_empty(): _setup_ship()
		h.riding = true
		h.ai["land"] = at
		var a: Vector3 = ship["a"]; var b: Vector3 = ship["b"]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var k := clampf(Vector2(at.x - a.x, at.z - a.z).dot(ab) / ab.length_squared(), 0.04, 0.97)
		h.ai["jump_at"] = clampf(k * float(ship["dur"]) - 2.2 + rng.randf_range(-0.8, 0.8), 0.6, float(ship["ride"]) - 0.5)
		h.teleport(ship_pos())
		return
	# straight above your squad's landing spot, so letting go of the keys still lands you safely
	var off := Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0))
	if world.is_void(at.x + off.x, at.z + off.z):
		off = Vector3.ZERO
	h.teleport(at + off + Vector3(0, 26.0, 0))
	h.dropping = true
	h.diving = true
	h.drop_from = Vector2(at.x + off.x, at.z + off.z)
	h.grounded = false
	h.gliding = true
	h.glide_k = 1.0
	h.ai["land"] = at

# ---- the skyship
const SHIP_Y := 40.0
const SHIP_SPEED := 11.0
var big := false
var ship := {}
var biomes: BiomeRun = null     # biome regions on an authored map (spawn tables, rarity, mutations, traps)

func _setup_ship() -> void:
	if rolling:
		# your wave's ship flies over the less crowded side (Rolling.new_ship), starting now
		if ship.is_empty(): ship = rolling.new_ship(0.0)
		return
	var ang := rng.randf() * TAU
	var c := Vector3(world.w / 2.0 + rng.randf_range(-10, 10), SHIP_Y, world.h / 2.0 + rng.randf_range(-10, 10))
	var dir := Vector3(cos(ang), 0, sin(ang))
	var half := world.w * 0.6
	# "ride" is the last moment to jump: still over the islands on the far side
	ship = {"a": c - dir * half, "b": c + dir * half, "dur": 2.0 * half / SHIP_SPEED, "ride": (half + 34.0) / SHIP_SPEED, "dir": dir}
	var n := Models.skyship()
	n.rotation.y = atan2(-dir.x, -dir.z)
	add_child(n)
	ship["node"] = n

func ship_pos() -> Vector3:
	return ship_pos_of(ship)

## Where a skyship is now (each drop wave's ship sets off at its own "t0", match time).
func ship_pos_of(s: Dictionary) -> Vector3:
	if s.is_empty() or not s.has("a"):
		return Vector3.ZERO
	return (s["a"] as Vector3).lerp(s["b"], clampf((time - float(s.get("t0", 0.0))) / float(s["dur"]), 0.0, 1.0))

## The skyship a hunter rides (a rolling session's later waves have their own; otherwise `ship`).
func ship_of(h: Hunter) -> Dictionary:
	if h != null and h.has_meta("ship"):
		return h.get_meta("ship")
	return ship

## When a bot aboard should jump to come down on a spot: as the ship passes nearest it.
func plan_jump(h: Hunter, at: Vector3) -> void:
	var s := ship_of(h)
	if s.is_empty() or not s.has("a"):
		return
	h.ai["land"] = at
	var a: Vector3 = s["a"]; var b: Vector3 = s["b"]
	var st := float(s.get("t0", 0.0))
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var k := clampf(Vector2(at.x - a.x, at.z - a.z).dot(ab) / ab.length_squared(), 0.04, 0.97)
	h.ai["jump_at"] = clampf(st + k * float(s["dur"]) - 2.2 + randf_range(-0.5, 0.5), maxf(st + 0.6, time + 0.2), st + float(s["ride"]) - 0.5)

## Off the ship. A squadmate waiting on the drop leader can't jump by themselves (force: they're
## jumping with the leader, or the ship has reached the end of its run).
func ship_jump(h: Hunter, force := false) -> void:
	if not h.riding:
		return
	if not force and skydrop and skydrop.waits(h):
		if h == player and hud:
			hud.toast_small("%s leads the drop  ·  %s to go solo" % [skydrop.leader(h.team).pname, Settings.key_cap("separate")], Color("ffd27a"))
		return
	h.riding = false
	var off := Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
	var hs := ship_of(h)
	h.teleport(ship_pos_of(hs) + Vector3(0, -1.5, 0) + off)
	h.dropping = true
	h.diving = true
	h.drop_from = Vector2(h.pos.x, h.pos.z)
	h.gliding = true
	h.glide_k = 1.0
	h.grounded = false
	h.vel = hs["dir"] * 3.0
	if h == player:
		sfx("whoosh", null, -2.0)
		if hud and not force:
			hud.toast("Steer with %s%s%s%s  ·  %s opens your glider early" % [Settings.key_cap("up"), Settings.key_cap("left"), Settings.key_cap("down"), Settings.key_cap("right"), Settings.key_cap("jump")], Color("cfeaff"))
		elif hud:
			hud.toast("Gliding in formation  ·  %s to break away" % Settings.key_cap("separate"), Color("cfeaff"))
	if skydrop and skydrop.is_lead(h):
		skydrop.on_lead_jump(h)

func _update_ship(dt: float) -> void:
	_update_one_ship(ship, dt)

## One skyship along its line, and everyone aboard it: jump when it's time, or at the end of its run.
func _update_one_ship(s: Dictionary, dt: float) -> void:
	if s.is_empty() or s.get("gone", false):
		return
	var st := float(s.get("t0", 0.0))
	var n: Node3D = s["node"]
	# drawn along the line past the end too, so it sails off over the clouds
	n.position = (s["a"] as Vector3).lerp(s["b"], (time - st) / float(s["dur"])) + Vector3(0, 1.4 + sin(time * 1.3) * 0.25, 0)
	for pn in ["PropL", "PropR"]:
		(n.get_node(pn) as Node3D).rotation.z += dt * 14.0
	var done := time >= st + float(s["ride"])
	for h in hunters:
		if h.riding and not is_same(ship_of(h), s):
			continue
		if h.riding and h.remote and is_host and time > st + float(s["ride"]) + 6.0:
			# someone who dropped connection aboard: stop counting them as still in the match
			h.riding = false
			eliminate(h, null, "left", true)
			continue
		if not h.riding or h.remote:
			continue
		var auto: bool = h.ctrl == "bot" or opts.get("autoplay", false)
		var lead: Hunter = skydrop.leader(h.team) if skydrop else null
		if lead and lead != h and lead.remote and not h.drop_solo and not lead.riding and lead.dropping:
			# online: the leader jumped on their own machine; join them
			ship_jump(h, true)
			h.drop_follow = lead
			h.drop_slot = skydrop._free_slot(lead)
			continue
		if skydrop and skydrop.waits(h):
			continue          # jumps with the leader
		if done or (auto and time >= float(h.ai.get("jump_at", 0.0))):
			ship_jump(h, done)
	if done and time > st + float(s["dur"]) * 1.5:
		n.queue_free()
		s["node"] = null
		s["gone"] = true

func on_drop_landed(h: Hunter) -> void:
	h.inv_t = maxf(h.inv_t, 2.0)     # a moment to get your bearings after landing
	h.set_meta("landed_t", time)     # bots leave a fresh lander be for a while (Bot.fresh)
	if world.is_block(h.pos.x, h.pos.z):
		var best := h.pos; var bd := 1e9
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				var q := Vector3(floor(h.pos.x) + dx + 0.5, 0, floor(h.pos.z) + dz + 0.5)
				if not world.is_void(q.x, q.z) and not world.is_block(q.x, q.z):
					var d := Vector2(dx, dz).length()
					if d < bd: bd = d; best = Vector3(q.x, world.ground_at(q.x, q.z), q.z)
		h.teleport(best)
	DropFeel.land(self, h)
	if blight: blight.on_landed(h)
	if rolling: rolling.on_landed(h)

func _apply_treat(k: Kin) -> void:
	match String(Save.d.get("treat", "")):
		"treat_power": k.power *= 1.25
		"treat_hardy": k.max_hp *= 1.4; k.hp = k.max_hp
		"treat_calm": k.trust = minf(100.0, k.trust + 12.0)

func _spawn_mobs() -> void:
	if net_on and not is_host:
		return
	for c in world.camp_spots:
		await _slice()
		var p: Vector3 = c["pos"]
		var comp: Array
		match String(c.get("kind", "normal")):
			"heavy": comp = ["brute", "spitter", "skitter", "sentinel"]
			"light":
				var lr := rng.randf()
				comp = ["skitter", "skitter"] if lr < 0.4 else (["spitter", "skitter"] if lr < 0.7 else ["bomber", "skitter"])
			_:
				var nr := rng.randf()
				if nr < 0.15 * tier + 0.2:
					comp = ["brute", "skitter", "bomber"]
				elif nr < 0.5:
					comp = ["skitter", "bomber", "spitter"]
				elif nr < 0.75:
					comp = ["sentinel", "skitter", "skitter"]
				else:
					comp = ["spitter", "skitter", "bomber"]
		# a camp in a biome region spawns from that region's table instead
		var bcomp: Array = biomes.camp_comp(c) if biomes else []
		if not bcomp.is_empty(): comp = bcomp
		var made: Array = []
		for kk in comp:
			var q := p
			for _t in 20:
				var cand := p + Vector3(rng.randf_range(-1.8, 1.8), 0, rng.randf_range(-1.8, 1.8))
				if not world.is_void(cand.x, cand.z) and not world.is_block(cand.x, cand.z):
					q = Vector3(cand.x, world.ground_at(cand.x, cand.z), cand.z); break
			var smb := spawn_mob(kk, q)
			if biomes: biomes.dress(smb)
			made.append(smb)
		if rolling: rolling.note_camp(p, comp, made)     # (cleared camps come back in a rolling session)

func spawn_mob(kk: String, at: Vector3) -> Mob:
	at = _clear_spot(at)
	var mb := Mob.new()
	mb.init_mob(self, next_id("m"), kk, at, float(T.get("mob", 1.0)) if not T.is_empty() else 1.0)
	add_child(mb)
	if time > 0.0: _draw_range(mb)
	mobs.append(mb)
	ents_by_id[mb.nid] = mb
	return mb

## Gunfire and explosions you can't see show up on the minimap as sound pings.
var sound_pings: Array = []    # {pos, t, kind, key}
func note_sound(by, at: Vector3, kind: String) -> void:
	if blight:
		blight.noise(at, kind, by)       # the Blight hunts by noise
	if player == null or player.out:
		return
	if by is Ent and (by as Ent).team == player.team:
		return
	var d := Vector2(at.x - player.pos.x, at.z - player.pos.z).length()
	if d > 48.0 or (by is Hunter and not (by as Hunter).unseen and d < 20.0):
		return
	var key: String = (by as Ent).nid if by is Ent else str(at.snapped(Vector3(4, 4, 4)))
	for sp in sound_pings:
		if sp["key"] == key and time - float(sp["t"]) < 0.7:
			return
	sound_pings.append({"pos": at, "t": time, "kind": kind, "key": key})
	if sound_pings.size() > 40:
		sound_pings.pop_front()

## A Warden shrieked: heard across the island, and a warning for whoever's close.
func on_blight_shriek(b: Mob) -> void:
	blight_ping(b.pos, "shriek")
	if player and not player.out and player.flat_dist(b) < 26.0 and hud:
		var lv: float = (b as Blight).lvl
		hud.toast("A Watcher shrieked  ·  the Blight is coming" if lv >= 0.35 else "A Watcher spotted you  ·  get out of its light", Color("ff7a3a"))

## The Blight on the minimap: a mark where you hear something you can't see.
func blight_ping(at: Vector3, kind := "blight") -> void:
	if player == null or player.out:
		return
	if Vector2(at.x - player.pos.x, at.z - player.pos.z).length() > 40.0:
		return
	sound_pings.append({"pos": at, "t": time, "kind": kind, "key": "bl" + str(at.snapped(Vector3(3, 3, 3)))})
	if sound_pings.size() > 40:
		sound_pings.pop_front()

## The menu's "I'm stuck": hop to the nearest open ground (not a way out of falling).
func unstick() -> void:
	if player == null or player.out or player.downed or player.dropping or player.riding:
		return
	if world.is_void(player.pos.x, player.pos.z) and not player.grounded:
		return
	var p := world.free_spot_near(player.pos, [], 1.0, 0.5)
	player.teleport(Vector3(p.x, world.ground_at(p.x, p.z), p.z))
	player.vel = Vector3.ZERO

## Room for something new to appear: off rocks and walls, not boxed in, and not inside another
## monster or kin. Spots the map already placed stay put when they're fine.
func _clear_spot(at: Vector3) -> Vector3:
	if world == null or world.is_void(at.x, at.z):
		return at
	var near: Array = []
	for mb in mobs:
		if not mb.dead and mb.flat_dist(at) < 3.0: near.append(mb.pos)
	for k in kins:
		if not k.dead and Vector2(k.pos.x - at.x, k.pos.z - at.z).length() < 3.0: near.append(k.pos)
	var p := world.free_spot_near(at, near, 1.1, 0.42, 6.0)
	return Vector3(p.x, maxf(p.y, world.ground_at(p.x, p.z)), p.z)

func _spawn_chests() -> void:
	for cs in world.chest_spots:
		await _slice()
		add_chest(cs["pos"])
	for sp in world.shrine_spots:
		await _slice()
		var n := Models.shrine()
		n.position = sp
		add_child(n)
		shrines.append({"pos": sp, "used": false, "prog": 0.0, "node": n})
	for isl in world.islands:
		if isl.has("nest"):
			var n := Models.nest()
			n.position = isl["nest"]
			add_child(n)

# ------------------------------------------------------------------ breakables and found weapons
func add_chest(p: Vector3) -> Dictionary:
	var n := Models.chest()
	n.position = p
	n.rotation.y = rng.randf() * TAU
	add_child(n)
	KeyChest.dress(n)
	var c := {"pos": p, "open": false, "prog": 0.0, "node": n}
	chests.append(c)
	return c

func _spawn_breakables() -> void:
	for b in world.break_spots:
		await _slice()
		_add_break(String(b["kind"]), b["pos"])
	if opts.get("training", false) and player:
		# something to smash right where you start
		for t in [[Vector3(-2.0, 0, 1.2), "crate"], [Vector3(-2.6, 0, 2.2), "pot"]]:
			var q: Vector3 = player.pos + t[0]
			if world.is_void(q.x, q.z) or world.is_block(q.x, q.z):
				continue
			q.y = world.ground_at(q.x, q.z)
			_add_break(t[1], q)
		# a gear rack: gear to try (an active glove goes in your Q slot, the rest in theirs), in two
		# staggered rows 2.6 m apart so their name tags don't run into each other (one row 1.8 m apart
		# printed "Fissure GlMirror GloHook GIce Bridge Glove"); spots off the island are skipped for
		# the next free one, so all six make it onto the ground
		var spots: Array = []
		for row in [[-2.4, 0.0], [-4.6, 1.3], [0.0, 1.3], [2.4, 0.0], [4.6, 1.3]]:
			# across the row from the middle out: 0, 2.6, -2.6, 5.2 ... (or 1.3, -1.3, 3.9 ... staggered)
			for k in 6:
				var x := (float(row[1]) + float((k + (1 if row[1] == 0.0 else 0)) / 2) * 2.6) * (1.0 if k % 2 == 0 else -1.0)
				if Vector2(x, float(row[0])).length() <= 6.2:
					spots.append(Vector3(x, 0, float(row[0])))
		var used: Array = [Vector3(-2.0, 0, 1.2), Vector3(-2.6, 0, 2.2), Vector3(1.4, 0, 1.6), Vector3(3.6, 0, 2.6), Vector3(-3.6, 0, 2.6), Vector3(0, 0, 4.0)]
		for gid in ["blink", "quake", "bubble", "bastion_plate", "windstep_boots", "vest"]:
			for off in spots:
				var q2: Vector3 = player.pos + off
				if used.any(func(u): return (u as Vector3).distance_to(off) < 2.3):
					continue
				if world.is_void(q2.x, q2.z) or world.is_block(q2.x, q2.z) or absf(world.ground_at(q2.x, q2.z) - player.pos.y) > 1.7:
					continue
				used.append(off)
				q2.y = world.ground_at(q2.x, q2.z)
				spawn_gear(gid, 2, q2)
				break
		# the way into the duel room: a glowing pad next to where you start
		if not opts.get("duel", false):
			for off in [Vector3(3.6, 0, 2.6), Vector3(-3.6, 0, 2.6), Vector3(3.6, 0, -1.0), Vector3(0, 0, 4.0)]:
				var dq: Vector3 = player.pos + off
				if world.is_void(dq.x, dq.z) or world.is_block(dq.x, dq.z):
					continue
				dq.y = world.ground_at(dq.x, dq.z)
				duel_pad = dq
				var pad := Models.jump_pad(Color("ff8a7a"))
				pad.position = dq
				add_child(pad)
				var lbl := Label3D.new()
				lbl.text = "DUEL ROOM\n%s to enter" % Settings.key_cap("interact")
				lbl.font = UI.big; lbl.font_size = 40; lbl.pixel_size = 0.01; lbl.outline_size = 12
				lbl.modulate = Color("ffb0a0"); lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lbl.no_depth_test = true
				# drawn after every other see-through thing (pad glow, pickup beams), so nothing covers it
				lbl.render_priority = 100; lbl.outline_render_priority = 99
				lbl.position = dq + Vector3(0, 2.7, 0)
				add_child(lbl)
				break
	# the gear lying in the open is the same for everyone in an online match
	var wr := RandomNumberGenerator.new(); wr.seed = seed_val * 31 + 7
	for i in world.weapon_spots.size():
		var wsp: Vector3 = world.weapon_spots[i]
		var gg := GearDrops.roll_gear(wr, 1 if tier >= 2 else 0, 0, -1, biomes.slot_lean_at(wsp) if biomes else {})
		spawn_gear(String(gg["id"]), int(gg["rar"]), wsp, "ws%d" % i, false)

func _add_break(kind_s: String, at: Vector3) -> void:
	var n := Models.breakable(kind_s)
	n.position = at
	n.rotation.y = rng.randf() * TAU
	add_child(n)
	breaks.append({"i": breaks.size(), "pos": at, "kind": kind_s, "node": n, "dead": false})

## Motes drifting off a pickup in a colour (a Brand tuning, a Soul Ember), so you can spot it from afar.
func _element_motes(n: Node3D, col: Color, unique: bool) -> void:
	var p := CPUParticles3D.new()
	p.amount = 18 if unique else 10
	p.lifetime = 1.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.45
	p.direction = Vector3.UP; p.spread = 25.0
	p.initial_velocity_min = 0.4; p.initial_velocity_max = 1.1
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.05; p.scale_amount_max = 0.11
	var sm := SphereMesh.new(); sm.radius = 0.5; sm.height = 1.0; sm.radial_segments = 6; sm.rings = 3
	p.mesh = sm
	p.material_override = Models.glow_mat(Color(col, 0.9))
	p.position = Vector3(0, 0.7, 0)
	n.add_child(p)

## Treasure on the ground: a valuable for the backpack.
func spawn_val(item: Dictionary, at: Vector3) -> void:
	wdrop_n += 1
	var vd: Dictionary = Loot.VALUABLES.get(String(item.get("id", "")), {})
	var n := Models.gear_drop(vd.get("col", Color("ffd36a")), int(vd.get("rar", 1)))
	n.position = at
	add_child(n)
	if String(item.get("id", "")) == "soul_ember":
		_element_motes(n, Color("9ff0e0"), true)
	wpicks.append({"id": "v%d" % wdrop_n, "pos": at, "val": String(item.get("id", "")), "item": item, "rar": int(vd.get("rar", 1)), "node": n, "wid": "", "ammo": -1})

# ------------------------------------------------------------------ gear
var gpads: Array = []        # pocket jump pads {pos, t, node}
var smokes: Array = []       # smoke clouds {pos, r, t, node}
var plats: Array = []        # emergency platforms {tiles, t, node}

## A piece of gear on the ground. Online, whoever drops it tells the others (id "wdrop"; the fixed
## ground spots pass their own ids and send nothing: every client rolls the same ones).
func spawn_gear(gid: String, rar: int, at: Vector3, id := "", send := true) -> void:
	if id == "":
		wdrop_n += 1
		id = "g%s_%d" % [player.nid if player else "x", wdrop_n]
	var n := GearModels.drop(Gear.slot_of(gid), Gear.ALL[gid]["col"], rar)
	n.position = at
	add_child(n)
	wpicks.append({"id": id, "pos": at, "gear": gid, "rar": rar, "node": n, "wid": "", "ammo": -1})
	if net_on and send:
		net_event(["wdrop", id, "gear", rar, _r(at.x), _r(at.y), _r(at.z), gid])

## A weapon tuning on the ground (WeaponUps): walk over it and the upgrade is yours for the run.
func spawn_tune(pid: String, at: Vector3, id := "", send := true) -> void:
	if id == "":
		wdrop_n += 1
		id = "t%s_%d" % [player.nid if player else "x", wdrop_n]
	var pd: Dictionary = Data.PERKS[pid]
	var n := GearModels.tuning(pd["col"], (pd["wup"] as Dictionary).has("brand"))
	n.position = at
	add_child(n)
	if (pd["wup"] as Dictionary).has("brand"):
		_element_motes(n, pd["col"], true)
	wpicks.append({"id": id, "pos": at, "tune": pid, "rar": 3 if (pd["wup"] as Dictionary).has("brand") else 2, "node": n, "wid": "", "ammo": -1})
	if net_on and send:
		net_event(["wdrop", id, "tune", 2, _r(at.x), _r(at.y), _r(at.z), pid])

## Takes a piece of gear off the ground into its slot; what was in the slot drops at your feet.
func _take_gear(h: Hunter, wp: Dictionary, from_net := false) -> void:
	wpicks.erase(wp)
	(wp["node"] as Node3D).queue_free()
	if from_net:
		return
	if net_on:
		net_event(["wtake", wp["id"], h.nid])
	var slot := Gear.slot_on(h, String(wp["gear"]))      # a glove: its twin's slot, a free one, or the weaker (Gloves)
	var old: Dictionary = h.gear[slot]
	h.gear[slot] = {"id": wp["gear"], "rar": int(wp["rar"])}
	h.gear_cd[slot] = 0.0
	h.refresh_gear()
	if not old.is_empty():
		var ba := randf() * TAU
		spawn_gear(String(old["id"]), int(old["rar"]), Vector3(h.pos.x + cos(ba) * 0.9, h.ground(), h.pos.z + sin(ba) * 0.9))
	var col: Color = Data.RARITY[clampi(int(wp["rar"]), 0, Data.RARITY.size() - 1)]["color"]
	sfx("pickup", h.pos, 0.0, 0.9)
	fx.ring(h.pos, 1.4, col, 0.35)
	if h == player and hud:
		hud.toast(Loot.name_of(Loot.gear(String(wp["gear"]), int(wp["rar"]))) + "  ·  " + Loot.sub_of(Loot.gear(String(wp["gear"]), int(wp["rar"]))), col)

## Walking over a tuning applies it (to bots too); one you've maxed stays on the ground.
func _take_tune(h: Hunter, wp: Dictionary, from_net := false) -> void:
	var pid := String(wp["tune"])
	if not from_net and not h.perk_open(pid):
		return
	wpicks.erase(wp)
	(wp["node"] as Node3D).queue_free()
	if from_net:
		return
	if net_on:
		net_event(["wtake", wp["id"], h.nid])
	h.add_perk(pid)
	var pd: Dictionary = Data.PERKS[pid]
	sfx("bond", h.pos, -4.0, 1.3)
	fx.ring(h.pos, 1.6, pd["col"], 0.35)
	fx.burst(h.pos + Vector3(0, 1.0, 0), pd["col"], 14, 3.0, 0.5, -2.0)
	if h == player and hud:
		hud.toast("%s  ·  %s" % [pd["name"], pd["desc"]], pd["col"])

## Fire the active on a gear slot.
func use_gear(h: Hunter, slot: int) -> void:
	var g: Dictionary = h.gear[slot]
	if g.is_empty() or h.downed or h.out or h.riding or h.dropping or float(h.gear_cd[slot]) > 0.0:
		return
	var gid: String = g["id"]
	if not Gear.active(gid):
		return
	var gd: Dictionary = Gear.ALL[gid]
	h.gear_cd[slot] = Gear.cd_of(gid, int(g.get("rar", 1)))      # gloves never rank: the rarity is their only strength
	var col: Color = gd["col"]
	h.reveal_t = maxf(h.reveal_t, 0.6)
	if h == player:
		h._ab_feedback("gear%d" % slot, "cast")
	if gd.has("effects"):
		# newer gloves are built from the same effect blocks as abilities, scaled by rarity
		Effects.run(Gear.effects_of(gid, int(g.get("rar", 1))), h, {"slot": "gear", "ability": gid, "level": 1})
		sfx("skill", h.pos, -4.0, 1.0)
		return
	match gid:
		"gust_fan":
			var d := h.aim_dir()
			h.vel = Vector3(d.x * 9.0, 13.0, d.y * 9.0)
			h.grounded = false
			h.glide_cd = 0.0
			h.shot_down = false
			h.glide_fuel = minf(1.0, h.glide_fuel + 0.35)
			fx.burst(h.pos + Vector3(0, 0.4, 0), col, 20, 5.0, 0.5, -2.0, 1.0)
			sfx("glide", h.pos, 0.0, 1.5)
		"platform":
			var tiles: Array = []
			var y := h.pos.y - 0.1
			if not h.grounded and h.over_void():
				y = maxf(h.lip_y - 0.2, h.pos.y - 0.4) if h.below_lip else h.pos.y - 0.4
			var lv := int(round(y / World.LEVEL))
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var tx := int(floor(h.pos.x)) + dx; var tz := int(floor(h.pos.z)) + dz
					if world.inb(tx, tz) and world.kind[world.idx(tx, tz)] == World.T_VOID:
						var i := world.idx(tx, tz)
						tiles.append([i, int(world.level[i])])
						world.kind[i] = World.T_GROUND
						world.level[i] = clampi(lv, 0, 255)
			var n := Models.gear_platform(col)
			n.position = Vector3(floor(h.pos.x) + 0.5, lv * World.LEVEL, floor(h.pos.z) + 0.5)
			add_child(n)
			plats.append({"tiles": tiles, "t": 8.0, "node": n})
			if h.pos.y < lv * World.LEVEL:
				h.pos.y = lv * World.LEVEL + 0.05
				h.vel.y = 0.0
			h.glide_fuel = 1.0
			h.shot_down = false
			sfx("shield", h.pos, 0.0, 0.8)
		"shock":
			Abil._blast(h, h.pos, 3.4, 12.0, 13.0, col, 5.0, "gear")
		"rocket":
			# straight up: a column of thrust that also cools your glider, so you can keep going
			var d := h.aim_dir()
			h.vel = Vector3(h.vel.x * 0.5 + d.x * 2.0, 17.0, h.vel.z * 0.5 + d.y * 2.0)
			h.grounded = false
			h.glide_cd = 0.0
			h.shot_down = false
			h.roll_t = 0.0
			h.glide_fuel = minf(1.0, h.glide_fuel + 0.5)
			fx.burst(h.pos + Vector3(0, 0.2, 0), col, 26, 6.0, 0.5, -1.0, 1.2, Vector3.DOWN, 30.0)
			sfx("glide", h.pos, 0.0, 0.7)
		"skyhook":
			# hook a point toward the cursor and swing up to it: onto a ledge above you if there is
			# one there, otherwise straight up into the air
			var d := h.aim_dir()
			var aim: Vector3 = h.inp.get("aim", h.pos)
			var reach := clampf(Vector2(aim.x - h.pos.x, aim.z - h.pos.z).length(), 2.0, 9.0)
			var tx := h.pos.x + d.x * reach; var tz := h.pos.z + d.y * reach
			var gy := world.ground_at(tx, tz)
			var to := Vector3(h.pos.x + d.x * 3.0, h.pos.y + 8.0, h.pos.z + d.y * 3.0)
			if gy > World.VOID + 1.0 and not world.is_block(tx, tz) and gy > h.pos.y - 1.0:
				to = Vector3(tx, gy + 1.2, tz)
			h.launch_to(to, 0.55)
			h.glide_cd = 0.0
			fx.bolt(h.pos + Vector3(0, 1.2, 0), to, Color(col, 0.9))
			sfx("throw", h.pos, -2.0, 0.7)
		"hover":
			# a second jump in the air (or a big hop on the ground) and the glider ready right after
			h.vel.y = maxf(h.vel.y, 11.0)
			h.grounded = false
			h.glide_cd = 0.0
			h.roll_t = 0.0
			fx.ring(h.pos, 1.2, col, 0.3)
			fx.burst(h.pos, col, 14, 3.0, 0.4, 2.0, 1.0, Vector3.DOWN, 50.0)
			sfx("jump", h.pos, -2.0, 1.3)

func _update_gear_fx(dt: float) -> void:
	for gp in gpads.duplicate():
		gp["t"] = float(gp["t"]) - dt
		if float(gp["t"]) <= 0.0:
			(gp["node"] as Node3D).queue_free(); gpads.erase(gp); continue
		var top: Node3D = (gp["node"] as Node3D).get_node_or_null("Top")
		if top: top.scale = Vector3.ONE * (1.0 + sin(time * 6.0) * 0.06)
		for h in hunters:
			if h.out or h.downed or h.remote or not h.grounded:
				continue
			if h.flat_dist(gp["pos"]) < 0.8 and absf(h.pos.y - float(gp["pos"].y)) < 0.6 and float(gp["cd"].get(h.nid, -9.0)) < time:
				gp["cd"][h.nid] = time + 1.0
				var hv := Vector2(h.vel.x, h.vel.z)
				var d: Vector2 = hv.normalized() if hv.length() > 0.5 else h.aim_dir()
				h.vel = Vector3(d.x * maxf(hv.length(), 6.0), 17.0, d.y * maxf(hv.length(), 6.0))
				h.grounded = false
				h.glide_cd = 0.0
				fx.burst(gp["pos"] + Vector3(0, 0.3, 0), Color("8ff0c8"), 16, 5.0, 0.4, -2.0)
				sfx("jump", h.pos, -2.0, 0.8)
	for sm in smokes.duplicate():
		sm["t"] = float(sm["t"]) - dt
		var n: Node3D = sm["node"]
		n.scale = Vector3.ONE * clampf(float(sm["t"]), 0.0, 1.0)
		if float(sm["t"]) <= 0.0:
			n.queue_free(); smokes.erase(sm)
	for pl in plats.duplicate():
		pl["t"] = float(pl["t"]) - dt
		var n: Node3D = pl["node"]
		if float(pl["t"]) < 1.5:
			n.visible = int(time * 8.0) % 2 == 0
		if float(pl["t"]) <= 0.0:
			for tv in pl["tiles"]:
				world.kind[int(tv[0])] = World.T_VOID
				world.level[int(tv[0])] = int(tv[1])
			n.queue_free(); plats.erase(pl)

## Inside a smoke cloud?
func in_smoke(p: Vector3) -> bool:
	for sm in smokes:
		if Vector2(p.x - sm["pos"].x, p.z - sm["pos"].z).length() < float(sm["r"]):
			return true
	return false

## Takes a ground pickup for a hunter: gear into its slot, a tuning onto the weapon.
func take_pick(h: Hunter, wp: Dictionary, from_net := false) -> void:
	if wp.has("val"):
		return
	if wp.has("tune"):
		_take_tune(h, wp, from_net)
	else:
		_take_gear(h, wp, from_net)

## What pressing interact on a ground item will do, for the prompt.
func _pickup_label(h: Hunter, wp: Dictionary) -> String:
	var it := Pack.ground_item(wp)
	var k := Settings.key_cap("interact")
	var nm := Loot.name_of(it)
	var fill := "%d/%d" % [h.pack.size(), h.pack_cap]
	var gid := String(it.get("id", ""))
	var cur: Dictionary = h.gear[Gear.slot_on(h, gid)] if Gear.ALL.has(gid) else {}
	var into_hand := Gear.ALL.has(gid) and (cur.is_empty() or Loot.value(it) > Loot.value(Loot.gear(String(cur["id"]), int(cur["rar"]))) or not Pack.wants(h, it))
	if opts.get("training", false):
		return "Press %s to take %s  ·  %s" % [k, nm, Loot.sub_of(it)]
	if into_hand:
		var swap_txt := ("  ·  yours goes in your pack (%s)" % fill) if not cur.is_empty() else ""
		return "Press %s to wear %s  ·  %s%s" % [k, nm, Loot.sub_of(it), swap_txt]
	if Pack.room(h):
		return "Press %s to pack %s  (%s)  ·  %s" % [k, nm, fill, Loot.sub_of(it)]
	return "Backpack full (%s)  ·  %s to swap something out for %s" % [fill, k, nm]

func _update_wpicks(dt: float) -> void:
	for wp in wpicks:
		var n: Node3D = wp["node"]
		var sp: Node3D = n.get_node("Spin")
		sp.rotation.y += dt * 1.6
		sp.position.y = 0.7 + sin(time * 2.4 + float(wp["pos"].x)) * 0.08
	# tunings are taken by walking over them; bots also grab gear that beats what they wear
	for h in hunters:
		if h.out or h.downed or h.dropping or h.riding or h.remote:
			continue
		for wp in wpicks:
			if wp.has("val") or h.flat_dist(wp["pos"]) >= 1.4 or absf(h.pos.y - float(wp["pos"].y)) >= 1.0:
				continue
			if wp.has("tune") and (h.flat_dist(wp["pos"]) < 1.1 or h.ctrl == "bot"):
				take_pick(h, wp)
				break
			if wp.has("gear") and h.ctrl == "bot" and GearDrops.bot_wants(h, String(wp["gear"]), int(wp["rar"])):
				take_pick(h, wp)
				break

## Air rings: anyone flying through one gets thrown forward along their own heading, the glider
## pops open and gets a little fuel back, so a chain of rings carries you across a long gap.
func _update_rings(dt: float) -> void:
	if player and not player.out and int(time * 4.0) % 4 == 0:
		for rg in air_rings:
			if player.pos.distance_to(rg["pos"]) < 9.0:
				_tip("rings", "Glowing rings in the air between islands: jump off the edge, glide (hold %s) and fly through them for a burst of speed. Fast gliders barely sink." % Settings.key_cap("jump"))
				break
	for rg in air_rings:
		# rings stand straight up facing along the route; they don't spin
		for h in hunters:
			if h.remote or h.grounded or h.out or h.downed or h.riding or not h.pad.is_empty():
				continue
			var c: Vector3 = rg["pos"]
			var body: Vector3 = h.pos + Vector3(0, 0.8, 0)
			if body.distance_to(c) > 1.6:
				continue
			if float(rg["cd"].get(h.nid, -9.0)) > time:
				continue
			rg["cd"][h.nid] = time + 3.0
			ring_n += 1
			h.add_stat("rings")
			var hv := Vector2(h.vel.x, h.vel.z)
			var rd: Vector2 = rg["dir"]
			var d: Vector2 = hv.normalized() if hv.length() > 1.0 else rd
			if absf(d.dot(rd)) > 0.5:
				d = rd if d.dot(rd) > 0.0 else -rd    # line up with the ring
			var spd := minf(maxf(hv.length(), Hunter.GLIDE_SPEED) + 4.0, Hunter.GLIDE_MAX)
			h.vel.x = d.x * spd; h.vel.z = d.y * spd
			h.vel.y = maxf(h.vel.y, 2.0)
			h.glide_fuel = minf(1.0, h.glide_fuel + 0.35)
			if not h.gliding and not h.dropping:
				h.glide_cd = 0.0
				h.gliding = true
			fx.ring(c, 1.6, Color("8fe3ff"), 0.3)
			fx.burst(c, Color("cff6ff"), 14, 4.0, 0.35, 0.0)
			sfx("whoosh", c, -2.0 if h == player else -10.0, 1.3)

## Breakables are solid: push bodies out, and dashing straight through one smashes it.
var _break_grid := {}
var _break_grid_n := -1
func _collide_breaks() -> void:
	if breaks.is_empty():
		return
	var bodies: Array = []
	for h in hunters:
		if h.hittable() and h.grap.is_empty(): bodies.append(h)
	for mb in mobs:
		if not mb.dead: bodies.append(mb)
	# breakables never move: bucketed once into 4m cells, each body checks the 3x3 cells round it
	if _break_grid_n != breaks.size():
		_break_grid_n = breaks.size()
		_break_grid.clear()
		for b in breaks:
			var key := Vector2i(floori(float(b["pos"].x) / SEP_CELL), floori(float(b["pos"].z) / SEP_CELL))
			if _break_grid.has(key): (_break_grid[key] as Array).append(b)
			else: _break_grid[key] = [b]
	for e in bodies:
		var ck := Vector2i(floori(e.pos.x / SEP_CELL), floori(e.pos.z / SEP_CELL))
		var near: Array = []
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var cell = _break_grid.get(ck + Vector2i(dx, dz))
				if cell != null: near.append_array(cell)
		if near.size() > 1:
			near.sort_custom(func(x, y): return int(x["i"]) < int(y["i"]))
		for b in near:
			if b["dead"]:
				continue
			var bp: Vector3 = b["pos"]
			if absf(e.pos.y - bp.y) > 0.6:
				continue
			var d := Vector2(e.pos.x - bp.x, e.pos.z - bp.z)
			var mind: float = e.r + 0.36
			var l := d.length()
			if l >= mind:
				continue
			if e is Hunter and (e as Hunter).roll_t > 0.0 and not e.remote:
				brk.hit(b, e)
				continue
			var nrm := d / l if l > 0.0001 else Vector2(1, 0)
			var push := nrm * (mind - l)
			if world.occupy(e.pos.x + push.x, e.pos.z + push.y, e.r, e.pos.y, e.grounded) == 0.0:
				e.pos.x += push.x; e.pos.z += push.y

## Wild Boki are scarce on purpose (owner's call): catching one should feel like a goal, not a
## given. Only about a quarter of the map's wild spots are live in a match (at least 2), picked with
## a generator of their own so the match's random stream (and every seeded test) is unchanged; the
## rare Boki spots (SpawnPlan) are separate and stay as they were.
const WILD_LIVE := 0.25
const WILD_MIN := 2

func _spawn_wild() -> void:
	if net_on and not is_host:
		return
	var spots: Array = world.wild_spots
	var pick := RandomNumberGenerator.new()
	pick.seed = hash([seed_val, "wild_live"])
	var order: Array = range(spots.size())
	for i in range(order.size() - 1, 0, -1):
		var j := pick.randi_range(0, i)
		var tmp = order[i]; order[i] = order[j]; order[j] = tmp
	var live := {}
	for i in mini(spots.size(), maxi(WILD_MIN, int(round(spots.size() * WILD_LIVE)))):
		live[order[i]] = true
	for si in spots.size():
		var p: Vector3 = spots[si]
		var sp: String = Data.common_kin()[rng.randi_range(0, Data.common_kin().size() - 1)]
		var rec := Save.new_kin(sp, "", kin_seed("wild"))
		rec["level"] = rng.randi_range(T["kin_lvl"][0], T["kin_lvl"][1])
		Evo.simulate(rec, rng)
		rec["shimmer"] = Shiny.roll_wild(rng, tier)   # a rare colour you'll want to catch (1 in 4096, x1.5 in the Hollow)
		Mutations.roll_wild(rec, rng, tier)          # and now and then a rare mutation (more in harder tiers)
		# (every spot still rolls, so the draws match; only the live ones get a Boki)
		if live.has(si):
			await _slice()
			spawn_wild(rec, p)

func spawn_wild(rec: Dictionary, at: Vector3, dazed := false) -> Kin:
	at = _clear_spot(at)
	var k := Kin.new()
	k.init_kin(self, next_id("w"), rec["species"], rec, null)
	add_child(k)
	k.teleport(at)
	k.home = at
	kins.append(k)
	ents_by_id[k.nid] = k
	if net_on:
		_net_seen_rec[k.nid] = rec
	if dazed:
		k.hp = 1.0
		k._daze()
	return k

# ------------------------------------------------------------------ queries
func local_player() -> Hunter:
	return player

## Where the mouse points, at the right height: on a foe under the cursor at that foe's height,
## otherwise on the ground under the cursor. Aiming on your own height made shots at someone a
## terrace above (or below) drift sideways past them, because the camera looks down at an angle.
func _mouse_aim() -> Vector3:
	var base_y := player.pos.y + 0.95
	var mp := get_viewport().get_mouse_position()
	var best: Ent = null
	var bd := 52.0
	for e in foes_of(player.team):
		if e.dead or not e.visible:
			continue
		if absf(e.hit_y() - player.pos.y) > World.LEVEL * 3.0:
			continue
		# (below an island's lip that's their balloon, at ground level: it's what shots hit)
		var sp := cam.unproject_position(Vector3(e.pos.x, e.hit_y() + 0.8, e.pos.z))
		var d := sp.distance_to(mp)
		if d < bd:
			bd = d; best = e
	if best:
		var q := cam.mouse_on_plane(best.hit_y() + 0.95)
		aim_y = best.hit_y()
		return Vector3(q.x, base_y, q.z)
	aim_y = player.pos.y
	var p := cam.mouse_on_plane(base_y)
	for _i in 2:
		var g := world.ground_at(p.x, p.z)
		if g <= World.VOID + 1.0 or absf(g - player.pos.y) > World.LEVEL * 3.0:
			break
		p = cam.mouse_on_plane(g + 0.95)
		aim_y = g
	return Vector3(p.x, base_y, p.z)

## How much grip the ground has here (ice patches in a frost region make it slippery).
func ground_grip(p: Vector3) -> float:
	return biomes.grip(p) if biomes else 1.0

func foes_of(team: int) -> Array:
	var out: Array = []
	for h in hunters:
		if h.team != team and h.hittable() and not h.downed:
			out.append(h)
	for k in kins:
		if k.dead or k.is_wild():
			continue
		if k.team != team and k.hittable():
			out.append(k)
	if team != -2:
		for mb in mobs:
			if not mb.dead:
				out.append(mb)
	return out

func dmg_mult(h: Hunter) -> float:
	if h == null: return 1.0
	var bot_k := float((h.ai.get("diff", {}) as Dictionary).get("dmg", 1.0)) if h.ctrl == "bot" and h != player else 1.0
	return bot_k * (0.5 if h.weak_t > 0.0 else 1.0) * (1.25 if h.bless_t > 0.0 else 1.0) * (1.0 + h.gear_stat("dmg")) * (Life.R["sickness_dmg"] if h.sick_t > 0.0 else 1.0)

func sfx(n: String, p = null, vol := 0.0, pitch := 1.0) -> void:
	Sfx.play(n, p, vol, 0.07, pitch)

## Legacy door for world events (a boss slam, a lair gate): a big hit at `at`, caused by nobody on your team. Shake.incoming_big is the real one.
func shake(a: float, at: Vector3) -> void:
	Shake.incoming_big(self, at, a)

func direction_word(from: Vector3, to: Vector3) -> String:
	var d := Vector2(to.x - from.x, to.z - from.z)
	var a := rad_to_deg(atan2(d.y, d.x))
	var words := ["east", "southeast", "south", "southwest", "west", "northwest", "north", "northeast"]
	return "to the " + words[int(round(fposmod(a, 360.0) / 45.0)) % 8]

func ping(p: Vector3, col: Color) -> void:
	pings.append({"pos": p, "col": col, "t": 0.0})
	sfx("ping", null, -10.0)

## Squad members' colours on the map and their pings (in squad order).
const MATE_COLS := [Color("ffd23f"), Color("5fd0ff"), Color("8ff0a0"), Color("ff9be8"), Color("ffa25f")]
func mate_col(h: Hunter) -> Color:
	var i := 0
	for x in hunters:
		if x == h: break
		if x.team == h.team: i += 1
	return MATE_COLS[i % MATE_COLS.size()]

const SQUAD_PING_T := 45.0
## A squad ping: one per hunter (a new one moves it), seen by their squad on the map, the minimap and
## as a marker in the world; it lasts a while or until its owner takes it down. `kind`: "", "enemy" or "loot".
func squad_ping(h: Hunter, p: Vector3, from_net := false, kind := "") -> void:
	if h == null:
		return
	if not world.is_void(p.x, p.z):
		p.y = world.ground_at(p.x, p.z)
	else:
		p.y = 0.0
	unping(h, true)
	pings.append({"pos": p, "col": PingInput.color(self, h, kind), "t": 0.0, "by": h, "team": h.team,
		"life": SQUAD_PING_T, "kind": kind})
	if player and h.team == player.team:
		sfx("ping", null, -6.0, 1.15)
	if net_on and not from_net:
		net_event(["sping", h.nid, p.x, p.y, p.z, kind])
	if skydrop:
		skydrop.on_ping(h, p)
	if not from_net:
		for b in hunters:
			if b != h and b.team == h.team and b.ctrl == "bot" and not b.remote and not b.out:
				b.ai["ping_goal"] = {"pos": p, "until": time + 30.0, "by": h}

func unping(h: Hunter, quiet := false, from_net := false) -> void:
	for pg in pings.duplicate():
		if pg.get("by") == h:
			pings.erase(pg)
			for b in hunters:
				if b.ctrl == "bot" and b.ai.has("ping_goal") and (b.ai["ping_goal"] as Dictionary).get("by") == h:
					b.ai.erase("ping_goal")
	if not quiet and net_on and not from_net:
		net_event(["unping", h.nid])

func my_ping() -> Dictionary:
	for pg in pings:
		if player and pg.get("by") == player: return pg
	return {}

func kin_bark(k: Kin, txt: String, cat: String, life := 0.0) -> void:
	if tut and tut.card_up():
		return        # (the tutorial banner has the floor)
	for b in bubbles:
		if b["ent"] == k:
			bubbles.erase(b); break
	bubbles.append({"ent": k, "text": txt, "t": 0.0, "cat": cat, "life": maxf(life, BokiLines.bubble_s())})
	if k.owner_h == player:
		var s := "kin_happy"
		if cat in ["refuse", "hesitate", "scared", "revive_low", "ignore", "low_hp", "yelp", "comfort", "sniper"]: s = "kin_unsure"
		elif cat in ["callout", "wild", "behind", "hunter", "pack", "boss", "egg", "loot", "exit", "collapse", "storm", "cover"]: s = "kin_alert"
		sfx(s, null, -3.0, Unique.voice(k.rec))     # in its own voice, above the louder combat layer
	elif player and k.owner_h and k.owner_h.team == player.team and cat in ["behind", "hunter", "sniper", "pack", "boss", "egg"]:
		sfx("kin_alert", k.pos, -8.0, Unique.voice(k.rec))   # a squadmate's Boki calling something out

## A Boki's callout ping (KinCompanion): a labelled marker over the spot for a few seconds, on the
## minimap too, for its squad. Returns the ping so a moving target can be followed.
func kin_ping(k: Kin, p: Vector3, col: Color, label: String) -> Dictionary:
	for pg in pings:
		if pg.get("kin") == k:
			pings.erase(pg); break
	var pg := {"pos": p, "col": col, "t": 0.0, "life": 5.0, "kin": k, "label": label, "team": k.team}
	pings.append(pg)
	if k.owner_h == player or (player and k.team == player.team):
		sfx("ping", null, -9.0, 1.3)
	return pg

var feed_all: Array = []

func add_feed(t: String) -> void:
	feed_all.append("%d %s" % [int(time), t])
	feed.append({"text": t, "t": 0.0})
	if feed.size() > 5:
		feed.pop_front()

# ------------------------------------------------------------------ events
func on_damage(target: Ent, by: Ent, d: float, o: Dictionary) -> void:
	# (damage a kin's owner shield soaked still counts as an attack)
	if truce: truce.on_damage(target, by, d + float(o.get("soaked", 0.0)))
	var tags: Array = o.get("tags", [])
	if tags.is_empty():
		tags = [String(o.get("src", "primary")) if o.get("src", "") != "" else "primary"]
	if o.get("stun", 0.0) > 0.0: tags = tags + ["stun"]
	CombatBus.hit_landed.emit(by, target, d, tags)
	KinFollow.on_damage(target, by, d)
	var crit: bool = o.get("crit", false)
	var src: String = o.get("src", "")
	Oomph.react(self, target, by, d, o)     # flinch, stagger, hit-shake (the gameplay side of oomph)
	if target is Hunter and (target as Hunter).kin and by != target and src != "burn":
		var tk: Kin = (target as Hunter).kin
		if tk.comp: tk.comp.on_owner_hit(d, by)       # its Boki flinches with it
	var credit: Ent = by
	if by is Kin and by.owner_h:
		credit = by.owner_h
	DashReset.note(target, credit)
	if target is Hunter and target != credit:
		(target as Hunter).dmg_taken += d
		if by is Blight: kstat["bl_dmg"] = float(kstat.get("bl_dmg", 0.0)) + d
	if credit is Hunter and target != credit:
		credit.dmg_done += d
		if o.has("leech") and target.team != credit.team and not credit.remote:
			credit.heal(d * float(o["leech"]))     # a Void weapon drains what it deals
		if not credit.remote and target.team != credit.team and src != "burn":
			Bond.add(credit, d / 320.0)        # (the merge meter: overcharge and the Bond IV apply there)
		if not credit.remote and target.team != credit.team and not (target is Hunter and (target as Hunter).downed):
			credit.gain_xp(d * (0.6 if target is Hunter else 0.35))
			var lv: int = credit.armor_gain(d * (1.0 if target is Hunter else 0.33))
			if lv >= 0:
				_armor_up(credit)
				if "--simtest" in OS.get_cmdline_user_args(): print("ARMOR %s -> %s" % [credit.pname, Hunter.ARMOR_TIERS[lv][0]])
	var mine := credit == player or (target == player)
	var armor_hit: bool = o.get("armor", false) or (target is Hunter and (target as Hunter).armor > 0.5)
	var col := HudStyle.dmg_col(crit, armor_hit, target == player, target is Kin and target.owner_h == player)
	# only numbers that involve you: other fights nearby don't spray digits over yours
	if mine:
		fx.number(target.pos + Vector3(0, 1.5 if target is Hunter else 1.0, 0), d, col, crit)
	# archetype passives feed on what happens (Marks, Chambers, Rage, Focus...)
	if credit is Hunter and (credit as Hunter).ak and target != credit and not credit.remote:
		(credit as Hunter).ak.note_hit(target)
		(credit as Hunter).ak.on_deal(target, d, o)
	if target is Hunter and (target as Hunter).ak and not target.remote:
		(target as Hunter).ak.on_take(by, d, o)
	# impact: hitstop and shake by tier (docs/DASHES_AND_ABILITY_FEEL.md §5.4-5.5), from what the hit did
	if src != "burn":
		var tier := Feel.hitstop(self, by, target, d, o)
	if credit == player and target != player and src != "burn":
		sfx("crit" if crit else "hit", target.pos, -4.0 if crit else -6.0, 1.25 if armor_hit else randf_range(0.92, 1.08))
		if hud: hud.hitmarker(crit, armor_hit)
		if tut and by == player and target is Mob: tut.on_hit()
	if target == player and by and hud:
		hud.hurt_from(by.pos)
	if target == player:
		sfx(HeroSfx.of(player, "hurt", "hurt"), null, -4.0)
		if hud: hud.hurt_flash(d)
	Juice.hit(self, target, by, d, o, crit, armor_hit)

## Cancels anything a hunter had going: a sword charge, a sniper wind-up.
func cancel_abilities(h: Hunter) -> void:
	h.charge = {}
	h.warm_t = 0.0
	h.mel_hold = 0.0
	h.strike_at_end = {}

func knock(h: Hunter, by: Ent, _o: Dictionary) -> void:
	if h.downed or h.out:
		return
	cancel_abilities(h)
	h.downed = true
	h.downs += 1
	KinTrack.drop_carried(self, h, h.pos)
	if by is Blight: kstat["bl_knock"] = int(kstat.get("bl_knock", 0)) + 1      # (tests: what the Blight did)
	h.down_hp = Data.MATCH["down_hp"]
	h.hp = 0.0
	h.revive = 0.0
	h.cloak_t = 0.0
	h.reload_t = 0.0
	h.grap = {}
	var credit: Ent = by
	if by is Kin and by.owner_h:
		credit = by.owner_h
	if h == player:
		# getting knocked hits hard: slow time, flash red, pull the camera in
		_slow(0.55, 0.3)
		if hud: hud.flash(Color("ff3a2a"), 0.3)
		Sfx.duck(0.6)
		killcam_text = ("Knocked down by %s" % credit.pname) if credit is Hunter and credit != h else "You're down"
	if credit is Hunter and credit != h:
		credit.knocks += 1
		# the knock reward: a dash refresh for the knocker and assisters, a small heal (DashReset), armor and XP
		if not credit.downed and credit.team != h.team:
			DashReset.takedown(credit, h)
			if credit.armor_gain(Hunter.ARMOR_KNOCK_XP) >= 0: _armor_up(credit)
			credit.gain_xp(90.0)
		add_feed("%s knocked %s" % [HeroTitle.of_hunter(credit), HeroTitle.of_hunter(h)])
		if credit.kin and credit.kin.comp and credit.kin.state != "downed":
			credit.kin.comp.on_knock(h.pos)
		if credit == player:
			_reward_moment(h.pos)
			if player.kin and player.kin.state != "downed":
				BokiChatter.say(self, player.kin, "kill")
	else:
		add_feed("%s went down" % HeroTitle.of_hunter(h))
	if rolling: rolling.on_knock(h, credit)      # bounties, and XP by the level gap
	sfx("knock", h.pos, 0.0)
	HeroSfx.voice(self, h, "down")
	fx.burst(h.pos + Vector3(0, 0.8, 0), Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()], 24, 5.0, 0.6)
	Juice.knock(self, h, credit)
	if net_on and not h.remote:
		net_event(["knock", h.nid, credit.nid if credit else ""])
	if h.kin and h.kin.comp and h.kin.state != "downed":
		h.kin.comp.on_owner_down()
	if h == player:
		if h.kin and h.kin.state != "downed":
			BokiChatter.say(self, h.kin, "owner_down")
	_check_team(h.team)

func freeze_frame(t: float) -> void:
	hitstop = maxf(hitstop, t)

## Armor went up a tier: a coloured ring for everyone to see, and a callout for you.
func _armor_up(h: Hunter) -> void:
	var col := h.armor_col()
	fx.ring(h.pos, 2.4, Color(col, 0.9), 0.45)
	fx.burst(h.pos + Vector3(0, 1.0, 0), col, 14, 3.5, 0.5)
	if h == player:
		sfx("revive", null, -6.0)
		if hud: hud.toast("Armor upgraded  ·  %s" % String(Hunter.ARMOR_TIERS[h.armor_tier][0]), col)

func _reward_moment(at: Vector3) -> void:
	_slow(0.22, 0.35)
	freeze_frame(0.07)
	if hud: hud.flash(Color.WHITE, 0.25)
	fx.ring(at, 3.0, Color(1, 0.95, 0.8, 0.9), 0.35)
	fx.burst(at + Vector3(0, 1.0, 0), Color("ffd23f"), 26, 6.0, 0.6, 6.0, 1.2)
	Sfx.duck(0.25)
	sfx("kill", null, -2.0)

func _slow(t: float, k: float) -> void:
	if net_on:
		return
	slow_k = k if slowmo <= 0.0 else minf(slow_k, k)
	slowmo = maxf(slowmo, t)

## A hero's ultimate going off: punch the camera for the one who used it.
func ult_moment(h: Hunter) -> void:
	var col: Color = h.accent()
	fx.ring(h.pos, 4.5, Color(col, 0.9), 0.45)
	fx.burst(h.pos + Vector3(0, 1.2, 0), col, 30, 6.0, 0.6, 2.0, 1.3)
	if h == player:
		if hud: hud.flash(col, 0.22)
		freeze_frame(0.05)

func _check_team(team: int) -> void:
	if opts.get("tutorial", false) or opts.get("training", false):
		return
	var members: Array = hunters.filter(func(x): return x.team == team and not x.out and not x.extracted)
	if members.is_empty():
		return
	for x in members:
		if not x.downed:
			return
		if x.kin and not x.kin.dead and x.kin.state not in ["downed"] and x.kin.hp > 0.0:
			return
		if x.kin2 and not x.kin2.dead and x.kin2.hp > 0.0:
			return
	for x in members:
		if not x.remote:
			eliminate(x, x.last_hit_by, "team wiped")
	_team_gone(team)

## The whole team is down or dead with nobody to bring them back: everyone's dead for good.
func _team_gone(team: int) -> void:
	if Life.team_alive(self, team):
		return
	for x in hunters:
		if x.team == team and x.out and not x.remote:
			Life.make_gone(self, x)

func revive_hunter(h: Hunter, by: Ent) -> void:
	if h.remote:
		return
	if net_on:
		net_event(["up", h.nid])
	h.downed = false
	h.hp = h.max_hp * Life.R["revive_hp"]
	h.armor = 0.0
	h.revive = 0.0
	h.inv_t = 1.5
	sfx("revive", h.pos, 0.0)
	fx.ring(h.pos, 1.8, Color("9ee2a0"), 0.4)
	add_feed("%s is back up" % h.pname)
	if h.kin and h.kin.comp and h.kin.state != "downed" and by != h.kin:
		h.kin.comp.on_owner_up()
	if by is Hunter and by != h:
		(by as Hunter).revives += 1

func eliminate(h: Hunter, by: Ent, why: String, final := false) -> void:
	if h.out:
		return
	h.deaths += 1
	if by is Blight: kstat["bl_out"] = int(kstat.get("bl_out", 0)) + 1
	if h.lives > 1 and not h.remote and not over and not final:
		_lose_life(h, by, why)
		return
	cancel_abilities(h)
	if h.ak: h.ak.drop_holds()      # an out hunter's kit no longer ticks: a channel (Hearth Call) would hang on
	h.out = true
	h.downed = false
	if net_on and not h.remote:
		net_event(["out", h.nid, by.nid if by else "", why])
	var credit: Ent = by
	if by is Kin and by.owner_h:
		credit = by.owner_h
	if credit is Hunter and credit != h and credit.team != h.team:
		credit.kills += 1
		DashReset.takedown(credit, h)
	add_feed(out_text(HeroTitle.of_hunter(h), why))
	if why != "abyss": Juice.kill(self, h, credit)
	h.set_meta("died_why", why)
	h.set_meta("died_at", time)
	var waiting := false
	if net_on: KinTrack.drop_carried(self, h, h.pos)       # (offline, Life.drop_box does it at the box)
	if not net_on and not h.remote:
		# everything they carried goes into a deathbox where they fell. While a teammate is still
		# in the fight they can bring them back at it (or at a revive beacon)
		var bx := Life.drop_box(self, h, why)
		h.lost_gems = h.gems
		h.gems = 0; h.seeds = {}; h.caught = []
		Life.kin_on_death(self, h, bx)
		waiting = Life.team_alive(self, h.team) and not opts.get("training", false) and not opts.get("tutorial", false)
		if not waiting:
			Life.make_gone(self, h)
	elif net_on and not is_host and not h.remote:
		net_event(["spill", _r(h.pos.x), _r(h.pos.y), _r(h.pos.z), h.gems, h.seeds, h.caught])
	elif not world.is_void(h.pos.x, h.pos.z) and not h.remote:
		var n := mini(10, int(ceil(h.gems / 5.0)))
		for i in n:
			drop("gem", h.pos + Vector3(0, 0.5, 0), maxi(1, h.gems / maxi(1, n)))
		for s in h.seeds:
			drop("seed", h.pos + Vector3(0, 0.5, 0), int(h.seeds[s]), s)
		for rec in h.caught:
			spawn_wild(rec, h.pos, true)
	if net_on:
		h.lost_gems = h.gems
		h.gems = 0; h.seeds = {}; h.caught = []
		# the kin they brought are left behind, dazed, for anyone to collect
		_leave_kin(h)
		h.gone = true
	if h == player:
		if not waiting:
			result = {"extracted": false, "why": why}
			_end_soon(2.2)
		if why != "abyss":
			_slow(0.8, 0.3)
		killcam_text = ("Taken out by %s" % credit.pname) if credit is Hunter and credit != h else ("You fell" if why == "abyss" else ("Hit by the Sky Train" if why == "train" else "You're out"))
	elif credit == player and player and not player.out:
		# taking out the last rival squad gets the big moment
		var rivals := hunters.any(func(x): return x.team != player.team and not x.out and not x.extracted)
		if not rivals:
			_slow(1.0, 0.22)
			if hud:
				hud.flash(Color("ffd23f"), 0.3)
				hud.toast("Last squad down", Color("ffd23f"))
			Sfx.duck(1.0)
	_check_last()

## The kill feed line for someone going out.
static func out_text(who: String, why: String) -> String:
	match why:
		"abyss": return "%s fell into the abyss" % who
		"train": return "%s was hit by the Sky Train" % who
	return "%s is out" % who

## Hit by the sky train (SkyTrain._kill_zone): a loud crash, a big burst and the body flung down
## the line. A hunter goes straight out, no wisp (a spare life still saves them), their deathbox
## where they were hit; monsters and kin take far more than they can survive.
func train_hit(e: Ent, fwd: Vector3, spd := 8.0) -> void:
	var at: Vector3 = e.pos
	var f2 := Vector2(fwd.x, fwd.z).normalized()
	var kb := f2 * (14.0 + spd * 1.2)
	sfx("train_hit", at, 4.0)
	sfx("boom", at, -2.0, 0.6)
	fx.burst(at + Vector3(0, 1.0, 0), Color("ffcf6a"), 40, 9.0, 0.6, 12.0, 1.6, Vector3(fwd.x, 0.6, fwd.z), 70.0)
	fx.burst(at + Vector3(0, 0.8, 0), Color(1, 1, 1, 0.9), 26, 6.0, 0.5, 4.0, 1.3)
	fx.burst(at + Vector3(0, 0.4, 0), Color("6b5a4a"), 16, 4.0, 0.7, 10.0, 1.2)
	fx.ring(at, 3.6, Color(1.0, 0.75, 0.4, 0.9), 0.45)
	fx.flash(at + Vector3(0, 1.0, 0), Color("fff2c0"), 1.4, 0.1)
	Shake.incoming_big(self, at, 0.9)
	if e is Hunter:
		var h: Hunter = e
		if h.out or h.extracted or h.remote:
			return
		cancel_abilities(h)
		h.last_hit_by = null
		h.grap = {}; h.pad = {}; h.roll_t = 0.0
		var fling := {"t": time, "from": at, "v": Vector3(kb.x, 9.0, kb.y), "spin": 1.0 if randf() < 0.5 else -1.0}
		eliminate(h, null, "train")
		if h.out:
			h.set_meta("fling", fling)      # (with a spare life they're already gliding back in)
		if h == player:
			freeze_frame(0.08)
			if hud: hud.flash(Color("fff2c0"), 0.35)
	else:
		e.hurt(9999.0, null, {"src": "train", "kb": kb, "lift": 7.0})
		if e is Mob and not e is Boss and not e.dead:
			e.dead = true

## Losing a life: some of what you carry spills where you went down, and you glide back in
## somewhere quiet with full health and a moment of protection.
func _lose_life(h: Hunter, by: Ent, why: String) -> void:
	cancel_abilities(h)
	h.lives -= 1
	var lose := int(ceil(h.gems * 0.3))
	if lose > 0 and not world.is_void(h.pos.x, h.pos.z):
		if net_on and not is_host:
			net_event(["spill", _r(h.pos.x), _r(h.pos.y), _r(h.pos.z), lose, {}, []])
		else:
			var n := mini(5, lose)
			for i in n:
				# the last pile takes the remainder so nothing is lost to rounding
				drop("gem", h.pos + Vector3(0, 0.5, 0), (lose / n) + (lose % n if i == n - 1 else 0))
	elif lose > 0:
		h.lost_gems += lose
	h.gems -= lose
	if net_on:
		net_event(["up", h.nid])
	var credit: Ent = by.owner_h if by is Kin and by.owner_h else by
	if credit is Hunter and credit != h and credit.team != h.team:
		credit.kills += 1
		DashReset.takedown(credit, h)
	if h.lives < 50:
		add_feed("%s lost a life (%d left)" % [h.pname, h.lives])
	h.downed = false
	h.down_hp = 0.0
	h.revive = 0.0
	h.hp = h.max_hp
	h.armor = h.max_armor
	h.inv_t = 3.0
	h.vel = Vector3.ZERO
	h.grap = {}; h.pad = {}; h.charge = {}; h.roll_t = 0.0
	h.stun_t = 0.0
	# the safest place: the spawn farthest from anyone who isn't on your team
	var best: Vector3 = world.spawns[0] if world.spawns.size() > 0 else world.random_ground()
	var bd := -1.0
	for sp in world.spawns:
		var dmin := 1e9
		for o in hunters:
			if o.team != h.team and not o.out and not o.extracted:
				dmin = minf(dmin, Vector2(o.pos.x - sp.x, o.pos.z - sp.z).length())
		if dmin > bd: bd = dmin; best = sp
	var was: bool = opts.get("no_drop", false)
	opts["no_drop"] = false
	_start_drop(h, best)
	opts["no_drop"] = was
	if h.kin and h.kin.state == "downed":
		h.kin.hp = h.kin.max_hp * 0.5
	if h == player and h.lives < 50:
		killcam_text = ""
		_slow(0.6, 0.35)
		if hud:
			hud.flash(Color("ff3a2a"), 0.35)
			hud.toast(("Last life. Be careful" if h.lives == 1 else "%d lives left" % h.lives) + ("  ·  you dropped %d gems" % lose if lose > 0 else ""), Color("ffb0a0"))

func _check_last() -> void:
	var teams := {}
	for h in hunters:
		if not h.out and not h.extracted:
			teams[h.team] = true
	if teams.size() <= 1 and exits and (rolling == null or rolling.waves_left() == 0):
		exits.on_last_team()

func on_fell(e: Ent) -> void:
	if e is Hunter and opts.get("autoplay", false):
		print("FELL ", e.pname, " hist=", e.get_meta("hist", []))
	if e is Hunter:
		if e.out:
			return
		sfx("fall", e.pos, 0.0)
		# swallowed by the cloud sea a few metres under the islands: a whoosh, a puff, a quick fade
		sfx("whoosh", e.pos, -3.0, 0.7)
		fx.burst(e.pos + Vector3(0, 0.8, 0), Color(0.92, 0.94, 1.0, 0.8), 18, 4.0, 0.6, -1.0, 1.2)
		if e == player and hud:
			hud.flash(Color(0.05, 0.04, 0.12), 0.6)
		if duel and e == duel.bot:
			# knocked off the island in the duel room: that's a knock, then a fresh round
			duel.stats["knocks"] = int(duel.stats["knocks"]) + 1
			duel.round_n += 1
			hud.toast("Off the edge! Round to you", Color("8fe3c8"))
			duel.reset()
			return
		if e == player and S_dev_god():
			var back: Vector3 = tut.respawn() if tut else e.ai.get("land", world.spawns[0] if world.spawns.size() > 0 else world.random_ground())
			e.teleport(back)
			if tut:
				hud.toast("Back to your last stop. Try again", Color("f3eee2"))
			e.vel = Vector3.ZERO
			return
		var by: Ent = e.last_hit_by if time - e.kb_t < 4.0 else null
		eliminate(e, by, "abyss")
	elif e is Mob:
		fx.burst(e.pos + Vector3(0, 0.6, 0), Color(0.92, 0.94, 1.0, 0.8), 10, 3.0, 0.5, -1.0, 1.0)
		e.dead = true
		e._cancel_tele()
		on_mob_dead(e, e.last_hit_by, {"src": "fall"})
	elif e is Kin:
		e.dead = true


## Test (--abyss-demo=fall|grab): run off a rim that faces the camera, then either let go and drop
## beside the island ("fall") or hold back toward it and catch the ledge ("grab").
func _abyss_demo(mode: String) -> void:
	if not has_meta("abyss_demo"):
		var at := Vector3.INF
		var p0 := player.pos
		for k in 4000:
			var g := world.random_ground() if k > 0 else p0
			if g.distance_to(p0) > 60.0 and k < 3000: continue
			var ok := not world.is_void(g.x, g.z) and world.is_void(g.x, g.z + 1.0) and not world.sheer.has(world.idx(int(g.x), int(g.z)))
			for s in [-1.5, -0.75, 0.0, 0.75, 1.5]:
				if absf(world.ground_at(g.x + s, g.z) - world.ground_at(g.x, g.z)) > 0.05 or world.is_block(g.x + s, g.z - 0.5): ok = false
				for dz in [1.0, 2.0, 3.0, 5.0, 8.0]:
					if not world.is_void(g.x + s, g.z + dz): ok = false
			if ok:
				at = Vector3(floor(g.x) + 0.5, world.ground_at(g.x, g.z), floor(g.z) + 0.5); break
		if at == Vector3.INF: at = p0
		player.teleport(at - Vector3(0, 0, 2.0))
		player.vel = Vector3.ZERO
		set_meta("abyss_demo", {"t0": time})
		for o in hunters:
			if o != player: o.teleport(world.random_ground())
		return
	var t: float = time - float(get_meta("abyss_demo")["t0"])
	player.inp["glide"] = false
	if t < 0.3:
		player.inp["move"] = Vector2.ZERO
	elif t < 0.8:
		player.inp["move"] = Vector2(0, 1)      # run toward the camera and jump off the edge
		if t >= 0.55 and t < 0.55 + DT * 1.5: player.inp["jump"] = true
	elif mode == "dip":
		# (feelfix) the reference's repeated dips: fall, glide back up, let go and fall again, glide home
		player.inp["glide"] = (t > 1.7 and t < 2.5) or t > 3.4
		player.inp["move"] = Vector2(0, -1) if t > 3.4 else Vector2.ZERO
	else:
		player.inp["move"] = Vector2(0, -1) if mode == "grab" else Vector2.ZERO

func S_dev_god() -> bool:
	return bool(opts.get("god", false)) or bool(opts.get("tutorial", false)) or bool(opts.get("training", false)) or Game.god

const BOSS_GEM_DROPS := 4     # a lair boss's gems come as this many big drops (same total)
func on_mob_dead(mb: Mob, by: Ent, _o: Dictionary) -> void:
	if net_on:
		net_event(["mobdead", mb.nid, by.nid if by else ""])
	var credit: Ent = by
	if by is Kin and by.owner_h:
		credit = by.owner_h
	if credit == player:
		if tut: tut.kills += 1
		player.add_stat("mobs")
	if biomes: biomes.on_mob_dead(mb)
	KeyCarry.on_mob_dead(self, mb)
	if lairs: lairs.on_mob_dead(mb, credit)
	var big_mob: bool = mb.mkind in ["brute", "warden"] or mb.md.get("boss", false)
	sfx("die_big" if big_mob else "die_small", mb.pos, -5.0, randf_range(0.9, 1.15))
	if credit == player: sfx("kill", null, -12.0, 1.4)
	fx.burst(mb.pos + Vector3(0, 0.6, 0), mb.md["color"], 22, 5.0, 0.6)
	Juice.mob_dead(self, mb, credit, big_mob)
	if not world.is_void(mb.pos.x, mb.pos.z) and not _o.get("self", false):
		# a lair boss pays its gems out as a few big ones (fewer drops, each worth having); the rest scatter small
		var gn := int(mb.md["gems"])
		var big_n := BOSS_GEM_DROPS if mb is Boss else gn
		for i in big_n:
			drop("gem", mb.pos + Vector3(0, 0.6, 0), int(round(3 * float(T["loot"]) * float(gn) / float(big_n))))
		if mb.md.get("stag", false) and not (mb is Boss) and rng.randf() < 0.6:
			drop("armor", mb.pos + Vector3(0, 0.6, 0), 25)
		# guards, the Warden, the Glimmerkin and the Blight drop gear and weapon tunings (content/rules/gear.json)
		GearDrops.run_table(self, mb.mkind, mb.pos + Vector3(0, 0, 0.4), rng, {"h": credit if credit is Hunter else null, "bonus": biomes.rarity_bonus_at(mb.pos) if biomes else 0})
		if mb.mkind == "warden":
			# the Warden guards the best things: treasure, maybe a Soul Ember
			spawn_val(Loot.valuable(Loot.roll_valuable(rng, 2)), mb.pos + Vector3(0, 0, -0.9))
			if rng.randf() < 0.5:
				spawn_val(Loot.valuable("soul_ember"), mb.pos + Vector3(0.9, 0, -0.6))
		elif mb.mkind == "brute" and rng.randf() < 0.25:
			spawn_val(Loot.valuable(Loot.roll_valuable(rng, 0 if tier == 0 else 1)), mb.pos + Vector3(0, 0, -0.8))
		if mb.mkind == "glimmer":
			if credit is Hunter: add_feed("%s caught the Glimmerkin's treasure" % credit.pname)
		if mb.mkind == "bl_warden":
			# a Warden's lamp holds something worth the risk: armor, often a tonic
			drop("armor", mb.pos + Vector3(0, 0.6, 0), 25)
			if rng.randf() < 0.4: drop("tonic", mb.pos + Vector3(0.4, 0.6, 0), 1)
		if rng.randf() < (0.35 if mb.mkind == "brute" else (0.0 if mb is Blight or mb is Boss else 0.12)):
			drop("seed", mb.pos + Vector3(0, 0.6, 0), 1, Data.pick_seed())
		# a Rift Key: always from the Warden, sometimes from an elite (one that can be staggered, or a rare one)
		if exits and not exits.list.is_empty() and (mb.mkind == "warden" or ((mb.md.get("stag", false) or mb.rarity >= 3) and mb.mkind != "glimmer" and rng.randf() < 0.06)):
			exits.drop_key(mb.pos)
	# the big ones are worth a perk to whoever brought them down
	if mb.mkind in ["warden", "brute"] and credit is Hunter and not (credit as Hunter).remote and (mb.mkind == "warden" or rng.randf() < 0.5):
		PerkOrbs.drop(self, "boss" if mb.mkind == "warden" else "brute", mb.pos, 0, credit as Hunter)      # the Warden: a fan of three
	if credit == player and player.kin and randf() < 0.15:
		BokiChatter.say(self, player.kin, "kill")

func on_kin_down(k: Kin) -> void:
	if k.owner_h == player:
		add_feed("%s is down" % k.rec.get("name", "Your Boki"))
		if hud:
			hud.toast("%s is down  ·  %s" % [k.rec.get("name", "Your Boki"), "run into it to pick it up" if not k.down_void else "it will come round on its own"], Color("ffb0a0"))
	elif k.owner_h and k.owner_h.ctrl == "bot" and k.owner_h.kin == k and k.owner_h.kin2 and (k.owner_h.kin2 as Kin).hp > 0.0:
		k.owner_h.get_tree().create_timer(0.6, false).timeout.connect(func(): if is_instance_valid(k.owner_h): k.owner_h.swap_kin())
	KinNet.event(self, "down", k)
	_check_team(k.team)

## Its owner scooped it up, or it came round on its own.
func on_kin_up(k: Kin, rescued: bool) -> void:
	if k.owner_h == player and hud:
		hud.toast("%s is back%s" % [k.rec.get("name", "Your Boki"), "" if rescued else " (it came round)"], k.sp["color"])
	KinNet.event(self, "scoop" if rescued else "round", k)

# ------------------------------------------------------------------ kin combat events
## A kin used an ability: its name pops up over it so you can read the fight.
func on_kin_ability(k: Kin, def: AbilitySpec, auto: bool) -> void:
	kstat["kin_ab"] += 1
	if auto: kstat["auto"] += 1
	if k.owner_h == null or k.unseen:
		return
	if player and k.flat_dist(player) < 20.0:
		fx.word(k.pos + Vector3(0, 1.3 + k.r, 0), def.display_name, KinText.color(def).lerp(Color.WHITE, 0.25), false)
	if k.owner_h == player:
		player.add_stat("kin_abilities")
		if auto and hud and not train.has("_auto_told"):
			train["_auto_told"] = true

func on_kin_swap(h: Hunter, now_k: Kin, _was: Kin) -> void:
	kstat["swap"] += 1
	fx.burst(h.pos + Vector3(0, 1.5, 0), now_k.sp["color"], 18, 3.5, 0.5)
	fx.ring(h.pos, 1.4, now_k.sp["color"], 0.3)
	sfx("swap", h.pos, -4.0)
	if h == player:
		train["_swapped"] = true
		if hud: hud.toast("%s is out" % now_k.rec.get("name", Data.KIN[now_k.species]["name"]), now_k.sp["color"])

func on_bond_ready(h: Hunter) -> void:
	if h.kin and is_instance_valid(h.kin) and not h.kin.dead:
		(h.kin as Kin).fire_trigger("on_bond_full", {"at": h.pos})
	if h != player:
		return
	sfx("bond", null, -3.0)
	fx.word(h.pos + Vector3(0, 2.3, 0), "BOND READY", Color("ffd23f"), true)
	var ud := KinMerge.def_for(h.kin) if h.kin else null
	if hud and ud:
		hud.toast("Bond full!  %s: %s" % [Settings.key_cap("ultimate"), ud.display_name], Color("ffd23f"))

func on_merge(h: Hunter, k: Kin, u: MergeSpec) -> void:
	kstat["ult"] += 1
	var form: Dictionary = h.merge_st["form"]
	KinNet.event(self, "merge", h, h.pos)
	if h != player and player and h.flat_dist(player) < 40.0:
		add_feed("%s became %s" % [h.pname, form["name"]])
	if h == player:
		player.add_stat("ults")
		if hud:
			hud.toast_small(String(form["name"]).to_upper(), form["glow"])

func on_merge_end(h: Hunter, why: String) -> void:
	if h == player and hud and why in ["time", "throw"]:
		hud.toast_small("FUSION ENDED", Color("ffd84a"))

func on_combo(target: Ent, own: Node, c: Dictionary) -> void:
	kstat["combo"] += 1
	var col := Color(String(c.get("color", "#ffd23f")))
	fx.word(target.pos + Vector3(0, 1.9, 0), String(c.get("label", "COMBO")), col, true)
	fx.ring(target.pos, 1.3, col, 0.3)
	sfx("combo", target.pos, -2.0)
	if own == player:
		player.add_stat("combos")
		if hud and int(player.stats.get("combos", 0)) == 1:
			hud.toast("%s!  %s" % [String(c.get("name", "Combo")), String(c.get("desc", ""))], col)

# ------------------------------------------------------------------ lost kin
## A rival holding one of your lost kin turns up in some expeditions (one per match at most).
func _held_for_match(team_i: int) -> Dictionary:
	if opts.get("training", false) or opts.get("tutorial", false) or team_i == 0 or not tracked.is_empty() or net_on:
		return {}
	for L in Save.d.get("lost_kin", []):
		if String(L.get("where", "")) == "rival" and rng.randf() < 0.5:
			return {"holder": String(L["holder"]), "rec": L["rec"]}
	return {}

## Your bond lets you feel where a lost kin is: a ping now and then while a rival here carries it.
func _update_tracking(dt: float) -> void:
	if tracked.is_empty() or player == null or player.out:
		return
	track_t -= dt
	if track_t > 0.0:
		return
	track_t = 22.0
	for tr in tracked:
		var k: Kin = tr["kin"]
		var h: Hunter = tr["holder"]
		if k.dead or h.out:
			continue
		var at: Vector3 = k.pos if k.state != "bench" else h.pos
		ping(at, Color("ffd23f"))
		note_sound(null, at, "kin")
		add_feed("You sense %s %s. %s has it." % [k.rec.get("name", "your Boki"), direction_word(player.pos, at), h.pname])

## Online: the Boki a hunter brought stay behind (KinLoss: safe tiers send them home, the others drop them to guard).
func _leave_kin(h: Hunter) -> void:
	for kk in [h.kin, h.kin2]:
		if kk == null or not is_instance_valid(kk):
			continue
		KinLoss.on_owner_out(self, h, kk, Vector3.INF)

## The Demo match (title screen): your bot squadmate leads the drop and picks the spot between a
## live boss lair and the nearest outpost uplink, so you glide down in formation and land right by both.
func _demo_drop() -> void:
	if player == null or skydrop == null or not skydrop.planning or lairs == null or exits == null:
		return
	var mates: Array = hunters.filter(func(x): return x != player and x.team == player.team and x.ctrl == "bot")
	var ups: Array = exits.of_kind("outpost")
	if mates.is_empty() or ups.is_empty():
		return
	var best := Vector3.INF
	var bd := 1e9
	for L in lairs.list:
		if not L["active"]:
			continue
		for x in ups:
			var d := Vector2((L["c"] as Vector3).x - (x["pos"] as Vector3).x, (L["c"] as Vector3).z - (x["pos"] as Vector3).z).length()
			if d < bd:
				bd = d
				# a third of the way from the uplink to the lair: both in sight once you're down
				best = (x["pos"] as Vector3).lerp(L["c"], 0.35)
	if best == Vector3.INF:
		return
	best = world.free_spot_near(best, [], 1.0, 0.6, 14.0)
	var lead: Hunter = mates[0]
	skydrop.leads[player.team] = lead
	lead.ai["land"] = best
	skydrop._bot_ping[lead.nid] = maxf(0.3, skydrop.plan_len - 1.5)
	print("DEMO drop: %s leads to %s (lair to uplink %.0fm)" % [lead.pname, best.snapped(Vector3(0.1, 0.1, 0.1)), bd])

func giant_free(k: Kin) -> bool:
	k._end_merge("left")
	return true

## Gives a hunter one of their kin back (out of a deathbox, or caught back up): it hops on your
## shoulder, or onto the bench if you already have one out.
func give_kin(h: Hunter, rec: Dictionary) -> Kin:
	var k := Kin.new()
	k.init_kin(self, KinLoss.kin_id(self, h), rec["species"], rec, h)
	add_child(k)
	k.teleport(h.pos + Vector3(1.0, 0, 0.7))
	kins.append(k)
	ents_by_id[k.nid] = k
	if h.kin == null or (h.kin as Kin).dead:
		h.kin = k
		h.apply_kin_bonus()
	else:
		h.kin2 = k
		k.bench()
	for L in player_lost.duplicate():
		if String(L["uid"]) == String(rec.get("uid", "")):
			player_lost.erase(L)
	return k

## A rival just took one of your kin: they're marked, and you're faster running them down.
func kin_stolen(thief: Hunter, rec: Dictionary) -> void:
	if player == null:
		return
	player.chase = thief
	ping(thief.pos, Color("ffd23f"))
	if hud:
		hud.toast("%s took %s! Chase them down: they're marked, and you're faster heading their way" % [thief.pname, rec.get("name", "your Boki")], Color("ffd23f"))

## Who has one of your squad's Boki right now (an enemy still in the match), or null (KinTrack).
func kin_thief() -> Hunter:
	return KinTrack.captor_for(self, player.team) if player else null

func _tick_chase() -> void:
	if player == null:
		return
	var th := kin_thief()
	player.chase = th
	if th:
		th.reveal_t = maxf(th.reveal_t, 0.5)     # the captor can't hide (their map spot pings every bond_ping_s: KinTrack.tick)
	KinTrack.tick(self, Match.DT)

## Where each of your lost kin ends up when the match is over (KinLoss.resolve).
func _resolve_lost() -> Array:
	return KinLoss.resolve(self)

func on_wild_dazed(k: Kin) -> void:
	if player and k.flat_dist(player) < 10.0:
		add_feed("The wild %s is knocked out. Hold %s beside it to scan it." % [Data.KIN[k.species]["name"], Settings.key_cap("interact")])

## A monster's stagger window opened.
func on_stag_open(mb: Mob) -> void:
	if player and not player.out and player.flat_dist(mb) < 14.0:
		sfx("warn", mb.pos, -10.0, 1.5)
		_tip("stagger", "A purple ring means %s can be staggered. Hit it with an ability (%s, %s or %s) for a big hit, a long stun and your cooldown back." % [mb.md["name"], Settings.key_cap("signature"), Settings.key_cap("ultimate"), Settings.key_cap("gear1")])

## Someone landed an ability in a stagger window. Runs where the monster lives (the host online).
var stag_n := 0

func on_stagger(mb: Mob, by: Ent, ab: String) -> void:
	stag_n += 1
	var sc: Ent = (by as Kin).owner_h if by is Kin and (by as Kin).owner_h else by
	if sc is Hunter: (sc as Hunter).add_stat("staggers")
	fx.ring(mb.pos, mb.r + 1.8, Color("c47aff"), 0.4)
	fx.burst(mb.pos + Vector3(0, 1.0, 0), Color("e0b0ff"), 30, 6.0, 0.6, 2.0, 1.2)
	fx.flash(mb.pos + Vector3(0, 1.0, 0), Color("e0b0ff"), 1.4, 0.1)
	sfx("crit", mb.pos, 2.0, 0.7)
	sfx("boom", mb.pos, -4.0, 1.6)
	freeze_frame(0.08)
	var hunter: Hunter = by as Hunter if by is Hunter else (by.owner_h if by is Kin else null)
	if net_on:
		net_event(["stg", mb.nid, hunter.nid if hunter else "", ab])
	_stagger_reward(mb, hunter, ab)

func _stagger_reward(mb: Mob, hunter: Hunter, ab: String) -> void:
	if hunter == null or hunter.remote:
		return
	if ab == "e":
		hunter.sig_cd = 0.0
	elif ab in ["kin", "k1", "k2"] and hunter.kin:
		(hunter.kin as Kin).runner.reset()
	if hunter == player:
		var what: String = {"e": "Cooldown back", "kin": (player.kin.rec.get("name", "Your Boki") if player.kin else "Your Boki") + "'s abilities are ready again"}.get("kin" if ab in ["k1", "k2"] else ab, "")
		hud.toast("Staggered %s!%s" % [mb.md["name"], ("  " + what) if what != "" else ""], Color("e0b0ff"))
		train["_stagger"] = true

## Someone's armor just shattered: a clear sound and burst so the attacker knows to push.
func on_armor_break(h: Hunter, by: Ent) -> void:
	fx.burst(h.pos + Vector3(0, 1.0, 0), Color("7ac8ff"), 22, 5.0, 0.5, 6.0, 1.0)
	fx.ring(h.pos, 1.4, Color("7ac8ff"), 0.3)
	var credit: Ent = by.owner_h if by is Kin and by.owner_h else by
	Juice.armor_break(self, h, credit)
	if credit == player and hud:
		hud.toast_small("ARMOR BROKEN", Color("7ac8ff"))
		hud.hitmarker(true, true)
	elif h == player and hud:
		hud.toast_small("Armor down", Color("7ac8ff"))

## Knocked into a wall: stunned for a moment, which is the whole point of knockback near walls.
func on_wall_slam(e: Ent) -> void:
	fx.burst(e.pos + Vector3(0, 0.9, 0), Color("e6dccb"), 16, 4.0, 0.4)
	fx.ring(e.pos, 1.2, Color("fff27a"), 0.3)
	sfx("knock", e.pos, -2.0, 1.2)
	var sc: Ent = e.last_hit_by
	if sc is Kin and (sc as Kin).owner_h: sc = (sc as Kin).owner_h
	if sc is Hunter and sc != e: (sc as Hunter).add_stat("slams")
	if hud and player and (e == player or e.last_hit_by == player): hud.toast_small("WALL SLAM", Color("fff27a"))

## Sight. Each hunter sees a cone in front of them (where they aim) out to VIEW_RANGE, plus a
## small circle all around; a team shares what its members see. Walls and high ground block
## sight, tall grass hides you from anyone outside it, and crouching shrinks both distances.
## Firing or getting hit gives you away to anyone with a clear line, whichever way they face.
const VIEW_RANGE := 24.0
const VIEW_COS := 0.6          # about 106 degrees wide
const NEAR_SENSE := 3.2

func can_see(team_i: int, target: Hunter) -> bool:
	if target.team == team_i or target.downed:
		return true
	return sees(team_i, target.pos, target.crouch, target.reveal_t > 0.0)

func sees(team_i: int, p: Vector3, crouched := false, revealed := false) -> bool:
	var in_grass := world.in_bush(p.x, p.z) or in_smoke(p)
	var near := 1.6 if crouched else NEAR_SENSE
	# (muzzle flashes and a Warden's light give you away at full range, whatever the raid condition)
	var rng := VIEW_RANGE + 2.0 if revealed else view_range(crouched)
	for h in hunters:
		if h.team != team_i or h.out or h.extracted or h.riding:
			continue
		var rel := Vector2(p.x - h.pos.x, p.z - h.pos.z)
		var d := rel.length()
		if d < near:
			return true
		# sneaking (Ctrl) slows you but lets you see further, as in Supervive
		if d > rng * (1.25 if h.crouch else 1.0) * (1.0 + h.gear_stat("sight")) or (in_grass and not revealed):
			continue
		if not revealed and rel.normalized().dot(h.aim_dir()) < VIEW_COS:
			continue
		if world.los(h.pos, p, h.pos.y + 1.1) or world.los(h.pos, p + Vector3(0, 0.6, 0), h.pos.y + 1.6):
			return true
	return false

var _vis_t := 0.0
var crouch_on := false
var _vis_tex_done := false
func _update_vision() -> void:
	# the dimming outside your view cone, drawn by the toon shaders
	var looking: bool = player != null and not player.out and not player.extracted and not player.dropping and not player.riding and not opts.get("arena", false)
	if looking and not _vis_tex_done:
		_vis_tex_done = true
		RenderingServer.global_shader_parameter_set("vis_blocks", world.vis_texture())
		RenderingServer.global_shader_parameter_set("vis_size", Vector2(world.w, world.h))
	RenderingServer.global_shader_parameter_set("vis_on", 1.0 if looking else 0.0)
	if looking:
		RenderingServer.global_shader_parameter_set("vis_focus", player.model.global_position if player.model else player.pos)
		RenderingServer.global_shader_parameter_set("vis_dir", player.aim_dir())
		RenderingServer.global_shader_parameter_set("vis_range", view_range() * (1.25 if player.crouch else 1.0))
		# teammates light up what they see too (up to three)
		var n := 0
		for h in hunters:
			if n >= 3: break
			if h == player or h.team != player.team or h.out or h.extracted or h.riding or h.dropping:
				continue
			var ad: Vector2 = h.aim_dir()
			RenderingServer.global_shader_parameter_set("vis_ally%d" % n, Vector4(h.pos.x, h.pos.z, ad.x, ad.y))
			n += 1
		RenderingServer.global_shader_parameter_set("vis_allies", float(n))
	_vis_t -= get_process_delta_time()
	if _vis_t > 0.0:
		return
	_vis_t = 0.05
	for h in hunters:
		h.unseen = looking and h != player and not can_see(player.team, h)
	for k in kins:
		var o: Hunter = k.owner_h
		k.unseen = looking and o != null and o.team != player.team and k.state != "shoulder" and not sees(player.team, k.pos)

func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("vis_on", 0.0)
	SeeThrough.off()
	Capture.teardown(self)           # scan beams and hums outlive the match otherwise
	Sfx.reset_scene_audio()          # every sound the match started stops with it, owner item 103
	box_hums.clear()
	Beacons.stop_sounds(self)
	if biomes: biomes.free_up()
	if duel:
		duel.teardown()
	if arena:
		arena.teardown()
	if _bond_cb.is_valid() and CombatBus.hit_landed.is_connected(_bond_cb):
		CombatBus.hit_landed.disconnect(_bond_cb)
	if _combo_cb.is_valid() and CombatBus.status_applied.is_connected(_combo_cb):
		CombatBus.status_applied.disconnect(_combo_cb)

func on_perfect_dodge(h: Hunter) -> void:
	fx.ring(h.pos, 1.3, Color("9af0ff"), 0.3)
	fx.burst(h.pos + Vector3(0, 0.9, 0), Color("cff6ff"), 12, 3.5, 0.4)
	sfx("dash", h.pos, -2.0, 1.4)
	if h == player:
		_slow(0.25, 0.4)
		hud.toast("Perfect dodge!  Next shots crit", Color("9af0ff"))

## Catching a ledge just happens, the way Supervive pulls you up a lip: no message, just a
## quick pull-up with a puff and a grab sound.
func on_ledge_grab(_h: Hunter) -> void:
	pass

# ------------------------------------------------------------------ pickups
func drop(kind_s: String, at: Vector3, v: int, key := "", pid := "", vel0 = null) -> void:
	if net_on and not is_host and pid == "":
		return
	if pid == "":
		drop_n += 1
		pid = "d%d" % drop_n
	var n: Node3D
	match kind_s:
		"gem": n = Models.gem()
		"seed": n = Models.seed_bag(Data.CROPS[key]["color"])
		"tonic": n = Models.tonic()
		"armor": n = Models.armor_shard()
		"key": n = ExitModels.rift_key()
		"ckey": n = KeyModels.pickup()
		_: n = UtilityBelt.pickup_model(kind_s) if UtilityBelt.is_item(kind_s) else Models.gem()
	add_child(n)
	n.position = at
	var a := randf() * TAU
	var v0: Vector3 = vel0 if vel0 != null else Vector3(cos(a) * randf_range(1.5, 3.5), randf_range(4.0, 7.0), sin(a) * randf_range(1.5, 3.5))
	pickups.append({"id": pid, "pos": at, "vel": v0, "kind": kind_s, "v": v, "key": key, "node": n, "t": 0.0})
	if net_on and is_host:
		net_event(["drop", pid, kind_s, v, key, _r(at.x), _r(at.y), _r(at.z), _r(v0.x), _r(v0.y), _r(v0.z)])

func _update_pickups(dt: float) -> void:
	for p in pickups.duplicate():
		p["t"] += dt
		var pos: Vector3 = p["pos"]
		var g := world.ground_at(pos.x, pos.z)
		if skytrain:
			var dk := skytrain.deck_y(pos, 0.6)
			if dk > World.VOID + 1.0 and (g < dk or g > pos.y + 0.9): g = dk
		var v: Vector3 = p["vel"]
		var grabbed := false
		if p["t"] > 0.5:
			for h in hunters:
				if h.out or h.extracted or h.downed or h.remote:
					continue
				if net_on and not is_host and h != player:
					continue
				if p["kind"] == "ckey" and not KeyChest.has_room(h):
					continue      # a full key stack leaves the key on the ground, glinting
				if p["kind"] == "key" and h.rift_keys >= BeltKeys.cap("rift_key"):
					continue      # one Rift Key at a time (BeltKeys); the next waits on the ground
				var d: float = Vector2(h.pos.x - pos.x, h.pos.z - pos.z).length()
				if d < 2.2 and absf(h.pos.y - pos.y) < 2.0 and UtilityBelt.can_take(h, String(p["kind"])):
					var dir: Vector3 = (h.pos + Vector3(0, 0.6, 0) - pos)
					v = dir.normalized() * (6.0 + (2.2 - d) * 6.0)
					if dir.length() < 0.6:
						_collect(h, p)
						grabbed = true
					break
		if grabbed:
			continue
		if v.length() < 20.0:
			v.y -= 20.0 * dt
		pos += v * dt
		if g > World.VOID + 1.0 and pos.y < g + 0.3 and pos.y > g - 1.0:
			pos.y = g + 0.3
			v = Vector3(v.x * 0.6, -v.y * 0.3 if v.y < -2.0 else 0.0, v.z * 0.6)
		p["pos"] = pos; p["vel"] = v
		var n: Node3D = p["node"]
		n.position = pos + Vector3(0, sin(time * 3.0 + p["v"]) * 0.06, 0)
		n.rotation.y += dt * 2.0
		if pos.y < -12.0:
			n.queue_free(); pickups.erase(p)

func _collect(h: Hunter, p: Dictionary) -> void:
	p["node"].queue_free()
	pickups.erase(p)
	if net_on:
		net_event(["take", p["id"]])
	match p["kind"]:
		"gem": h.gems += int(round(float(p["v"]) * PerkOrbs.gem_mult(h)))
		"seed": h.seeds[p["key"]] = int(h.seeds.get(p["key"], 0)) + int(p["v"])
		"tonic", "armor": UtilityBelt.pickup(h, UtilityBelt.item_of(p["kind"]), 1)
		"ckey": KeyRun.on_pickup(self, h)
		"key":
			h.rift_keys += 1
			if h == player:
				hud.toast("+1 Rift Key: opens any rift hatch, quietly, any time", ExitModels.HATCH)
				sfx("unlock", null, -6.0, 1.2)
		_: if UtilityBelt.is_item(String(p["kind"])): UtilityBelt.pickup(h, String(p["kind"]), int(p["v"]))
	if h == player:
		sfx("pickup", null, -8.0, 1.0 + minf(0.4, h.gems * 0.004))
		if p["kind"] == "seed":
			hud.toast("+%d %s seed" % [p["v"], Data.CROPS[p["key"]]["name"]], Data.CROPS[p["key"]]["color"])

# ------------------------------------------------------------------ shots
func spawn_shot(by: Ent, at: Vector3, v2: Vector2, dmg: float, life: float, size: float, col: Color, extra := {}) -> void:
	var mi: MeshInstance3D = null
	var vr := size          # the drawn radius (Oomph.shot_look), kept for the tracer stretch
	for s in shot_pool:
		if not s.visible:
			mi = s; break
	if mi and extra.get("melee", false):
		mi = null          # a melee strike is invisible; the swing has its own effect
	if mi:
		mi.visible = true
		# readability: what can hurt you is the brightest, hottest thing on screen; your own and your
		# team's shots are smaller and dimmer so they never hide an incoming one
		var look: Array = Oomph.shot_look(self, by, col, size)
		var vis_col: Color = look[0]
		var vis_size: float = look[1]
		if player and by.team == player.team and String(extra.get("src", "")) == "abil":
			vis_col = vis_col.lerp(Color.WHITE, 0.25)      # your right click reads clearly over your own gunfire (pop)
			vis_size *= 1.2
		mi.material_override.set_shader_parameter("color", vis_col)
		var halo := mi.get_node_or_null("Halo") as MeshInstance3D
		if halo:
			halo.material_override.set_shader_parameter("color", Color(vis_col.lightened(0.2), float(look[2])))
		mi.scale = Vector3.ONE * vis_size
		if not Oomph.legacy: vr = vis_size * 0.5
		mi.global_position = at
	if not extra.has("dy") and not extra.get("mob", false) and not extra.get("cos", false) and not extra.get("melee", false):
		var src: Hunter = by as Hunter if by is Hunter else ((by as Kin).owner_h as Hunter if by is Kin and (by as Kin).owner_h else null)
		if src and src.inp.has("aim_y"):
			var dyv: float = float(src.inp["aim_y"]) - src.pos.y
			if absf(dyv) > 0.3 and absf(dyv) <= AIM_DY_MAX:
				var aimp: Vector3 = src.inp["aim"]
				extra = extra.duplicate()
				extra["dy"] = dyv
				extra["dyd"] = maxf(1.0, Vector2(aimp.x - at.x, aimp.z - at.z).length())
				extra["y0"] = at.y
				extra["gmax"] = maxf(src.pos.y, float(src.inp["aim_y"]))
	var team := by.team
	if duel and not extra.get("cos", false):
		duel.note_shot(by)
	shot_n += 1
	var sd := {"vr": vr, "sid": shot_n, "pos": at, "vel": v2, "dmg": dmg, "team": team, "by": by, "life": life, "life0": life, "r": size, "col": col, "x": extra, "node": mi, "prev": at, "start": at}
	if extra.has("deco") or extra.get("rope", false):
		sd["deco"] = _make_deco(String(extra.get("deco", "")), col, size, extra.get("rope", false))
	shots.append(sd)
	if net_on and not extra.get("cos", false) and not extra.get("melee", false) and not by.remote:
		var kind := 1 if extra.get("mob", false) else 0
		if extra.get("pierce_terrain", false): kind = 2      # the copy has to fly through walls too
		net_event(["s", _r(at.x), _r(at.y), _r(at.z), _r(v2.x), _r(v2.y), snappedf(life, 0.01), snappedf(size, 0.01), col.to_html(false), float(extra.get("boom", 0.0)), team, kind])
	if by is Hunter and not extra.get("melee", false):
		fx.flash(at, col.lightened(0.4), 0.22, 0.05)
		note_sound(by, at, "shot")

func _update_shots(dt: float) -> void:
	for s in shots.duplicate():
		s["life"] -= dt
		var p: Vector3 = s["pos"]
		s["prev"] = p
		var v: Vector2 = s["vel"]
		var sx0: Dictionary = s["x"]
		if sx0.has("decel"):
			# slugs slow down and stop
			var sp0 := v.length()
			var sp1 := maxf(0.0, sp0 - float(sx0["decel"]) * dt)
			if sp1 <= 0.5:
				_shot_end(s, p, null)
				continue
			v = v * (sp1 / sp0)
			s["vel"] = v
		var step := Vector3(v.x, 0, v.y) * dt
		var n := int(ceil(step.length() / 0.25))
		var hit := false
		var sx: Dictionary = s["x"]
		for i in n:
			p += step / n
			if sx.has("lob"):
				var tr0 := Vector2(p.x - (s["start"] as Vector3).x, p.z - (s["start"] as Vector3).z).length()
				var tot := float(s["life0"]) * (s["vel"] as Vector2).length()
				p.y = (s["start"] as Vector3).y + sin(clampf(tr0 / maxf(0.1, tot), 0.0, 1.0) * PI) * float(sx["lob"])
			elif sx.has("dy"):
				# climbing or dipping toward the height you aimed at
				var trav := Vector2(p.x - (s["start"] as Vector3).x, p.z - (s["start"] as Vector3).z).length()
				p.y = float(sx["y0"]) + float(sx["dy"]) * clampf(trav / float(sx["dyd"]), 0.0, 1.0)
			# domes stop shots fired at them from outside
			if _dome_blocks(s, p):
				_shot_end(s, p, null)
				hit = true; break
			# terrain and rocks
			var gp := world.ground_at(p.x, p.z)
			var over_ok: bool = sx.has("dy") and gp <= float(sx["gmax"]) + 0.05
			# an Abyssal Hand pierces terrain: it flies over rocks and props and through cliff faces
			var pierces: bool = sx.get("pierce_terrain", false)
			var rock_hit: bool = world.is_block(p.x, p.z) and gp + World.BLOCK_H > p.y and not pierces
			if rock_hit or (gp > p.y and not over_ok and not pierces):
				if int(sx.get("bounce", 0)) > 0:
					# ricochet: flip whichever way took it into the wall and keep going
					var back := p - step / n
					var bv: Vector2 = s["vel"]
					var gx := world.ground_at(p.x, back.z)
					if (world.is_block(p.x, back.z) and gx + World.BLOCK_H > p.y) or gx > p.y: bv.x = -bv.x
					else: bv.y = -bv.y
					s["vel"] = bv
					sx["bounce"] = int(sx["bounce"]) - 1
					if sx.has("hitset"): sx["hitset"] = {}
					fx.burst(back, s["col"], 6, 3.0, 0.2, 2.0)
					sfx("click", back, -6.0, 1.6)
					p = back
					s["pos"] = p
					hit = true; break
				_shot_end(s, p, null, "wall")
				hit = true; break
			var vr: String = verbs.shot_check(s, p) if verbs else ""
			if vr == "end":
				_shot_end(s, p, null, "wall")
				hit = true; break
			elif vr == "bounce":
				p = s["pos"]
				hit = true; break
			var bh := _shot_break(s, p)
			if not bh.is_empty():
				if not s["x"].get("cos", false) and not s["x"].has("boom") and not s["x"].get("mob", false):
					brk.hit(bh, s["by"])
				_shot_end(s, p, null)
				hit = true; break
			for e in _shot_targets(s):
				if Vector2(e.pos.x - p.x, e.pos.z - p.z).length() < e.r + s["r"] + HIT_SLACK and (shot_height_ok(e, p.y) or shot_from_above_ok(s, e, p.y)):
					if sx.has("hitset"):
						# piercing / boomerang shots hit each thing once per pass and fly on
						var key: int = e.get_instance_id()
						if (sx["hitset"] as Dictionary).has(key):
							continue
						sx["hitset"][key] = true
						_shot_hit(s, p, e)
						if not sx.get("pierce", false) and not sx.get("return", false):
							_shot_end(s, p, e, "hit")
							hit = true; break
						continue
					_shot_end(s, p, e, "hit")
					hit = true; break
			if hit:
				break
		if hit:
			continue
		s["pos"] = p
		if sx.get("return", false) and is_instance_valid(s["by"]):
			if sx.get("back", false):
				# a boomerang homes back on whoever threw it and is caught there
				var by: Ent = s["by"]
				var to := Vector2(by.pos.x - p.x, by.pos.z - p.z)
				if to.length() < 0.9:
					_shot_end(s, p, null, "caught")
					continue
				s["vel"] = to.normalized() * (s["vel"] as Vector2).length()
				var pp: Vector3 = s["pos"]
				pp.y = lerpf(p.y, by.pos.y + 0.95, 0.2)
				s["pos"] = pp
			elif s["life"] <= 0.0:
				sx["back"] = true
				sx["hitset"] = {}
				s["life"] = float(s["life0"]) * 1.6
				sfx("whoosh", p, -6.0, 1.5)
				if String(sx.get("src", "")) == "abil": sfx("ab_whirr", p, -8.0, 1.15)     # (on its way back)
				continue
		if s["life"] <= 0.0:
			_shot_end(s, p, null, "expire")

## Shots fly level, so a target one terrace above or below still gets hit. Two terraces up and the
## shot goes under them into the cliff; two down and it sails over their head.
func shot_height_ok(e: Ent, y: float) -> bool:
	var b := shot_band(e)
	return y > b.x and y < b.y

## A shot fired from a terrace above its target (a level shot, or one the aim didn't bend) still hits a body
## standing up to ABOVE_SLACK below the top of its band: the muzzle sits ~1m over the shooter's feet, so from
## 1-2 terraces up a level shot would otherwise sail over the head. Only while the shot is still higher than the
## body's feet, so it can't hit a body on a floor far below (and walls and terraces still stop it before that).
const ABOVE_SLACK := 1.2
func shot_from_above_ok(s: Dictionary, e: Ent, y: float) -> bool:
	var b := shot_band(e)
	var st := s["start"] as Vector3      # (fired from higher GROUND, not a jump or a glide over the same floor)
	return st.y > b.y - 0.3 and y > b.x and y < b.y + ABOVE_SLACK and world.ground_at(st.x, st.z) > shot_stance_y(e) + 0.8

## A shot's centre this close to the edge of a body's hit circle (radius `r`) still connects, so a
## bullet touching the circle of radius r + HIT_SLACK hits. That circle is what hit markers draw.
const HIT_SLACK := 0.08
## Someone this far or less above their terrace (a hop) is still standing on it, as far as shots go.
const HOP_STAND := 1.2

## The height a body is shot as if standing at: its feet; ground level below an island's lip (the
## balloon); its terrace while it hops; and HOP_STAND under its feet once it's higher in the air.
func shot_stance_y(e: Ent) -> float:
	var fy := e.hit_y()
	var g := e.ground()
	if g > World.VOID + 1.0 and fy > g:
		fy = maxf(g, fy - HOP_STAND)
	return fy

## Shots flying between these heights (x..y) hit this body.
func shot_band(e: Ent) -> Vector2:
	var top: float = 1.5 if e is Hunter else maxf(0.9, e.r * 2.2)
	var fy := shot_stance_y(e)
	return Vector2(fy - 0.45, fy + top + 0.9)

func _shot_break(s: Dictionary, p: Vector3) -> Dictionary:
	for b in breaks:
		if not b["dead"] and absf(p.y - (float(b["pos"].y) + 0.4)) < 0.75 and Vector2(b["pos"].x - p.x, b["pos"].z - p.z).length() < 0.36 + float(s["r"]):
			return b
	return {}

func _shot_targets(s: Dictionary) -> Array:
	var x: Dictionary = s["x"]
	var out: Array = []
	if x.has("lob"):
		return out       # a lobbed shell sails over everyone and comes down where it was aimed
	if x.get("cos", false):
		# a remote shooter's bullet stops on whatever it visibly hits; the owner reports the damage
		for h in hunters:
			if h.team != s["team"] and h.hittable(): out.append(h)
		for mb in mobs:
			if not mb.dead and not x.get("mob", false): out.append(mb)
		return out
	if x.get("mob", false):
		for h in hunters:
			if h.hittable() and not h.downed and h.phase_t <= 0.0: out.append(h)
		for k in kins:
			if not k.is_wild() and k.hittable(): out.append(k)
		return out
	for h in hunters:
		if h.team != s["team"] and h.hittable() and h.phase_t <= 0.0: out.append(h)
	for k in kins:
		if k.team != s["team"] and k.hittable(): out.append(k)
	for mb in mobs:
		if not mb.dead: out.append(mb)
	return out

func _shot_end(s: Dictionary, at: Vector3, e: Ent, why := "") -> void:
	shots.erase(s)
	if s.has("deco") and is_instance_valid(s["deco"]):
		(s["deco"] as Node3D).queue_free()
	# data-driven abilities: effects that go off where the shot ends, on what it hit, or on the wall
	# that stopped it
	var fxx: Dictionary = s["x"]
	if fxx.get("kx") is Callable and not fxx.get("cos", false):
		# a kin grammar shot (KinExec): it applies its own effects and followups
		(fxx["kx"] as Callable).call(s, at, e, why if not (e != null and fxx.has("hitset")) else "end")
	elif not fxx.get("cos", false) and is_instance_valid(s["by"]) and not s["by"].dead:
		var c2: Dictionary = (fxx.get("fx_ctx", {}) as Dictionary).duplicate()
		c2["at"] = at
		c2["end"] = why
		c2["dir"] = (s["vel"] as Vector2).normalized()
		if e: c2["target"] = e
		if e and fxx.has("fx_hit") and not _swing_seen(fxx, e):          # (a swing's strikes run a rider once per foe)
			Effects.run(fxx["fx_hit"], s["by"], c2)
		if why == "wall" and fxx.has("fx_wall"):
			Effects.run(fxx["fx_wall"], s["by"], c2)
		if fxx.has("fx_end"):
			Effects.run(fxx["fx_end"], s["by"], c2)
	if s["node"]:
		s["node"].visible = false
	if why == "caught" and String(fxx.get("src", "")) == "abil":
		AbilityFx.caught(self, s["by"], s["col"])
	elif e == null and String(fxx.get("src", "")) == "abil" and not fxx.get("cos", false):
		AbilityFx.fizzle(self, at, s["col"])      # a right click that missed still ends visibly
	if fxx.has("hitset"):
		if e == null: fx.burst(at, s["col"], 5, 2.0, 0.25, 6.0, 0.6)
		return        # piercing shots already dealt their hits on the way
	_shot_apply(s, at, e)

func _swing_seen(x: Dictionary, e: Ent) -> bool:
	return x.has("swing") and swing_hits.has("%s|%s" % [x["swing"], e.nid if e.nid != "" else str(e.get_instance_id())])

## A piercing or boomerang shot passing through something: its on-hit effects and damage, then on.
func _shot_hit(s: Dictionary, at: Vector3, e: Ent) -> void:
	var fxx: Dictionary = s["x"]
	if fxx.get("kx") is Callable and not fxx.get("cos", false):
		(fxx["kx"] as Callable).call(s, at, e, "pass")
	elif not fxx.get("cos", false) and is_instance_valid(s["by"]) and fxx.has("fx_hit"):
		var c2: Dictionary = (fxx.get("fx_ctx", {}) as Dictionary).duplicate()
		c2["at"] = at; c2["target"] = e; c2["end"] = "hit"
		Effects.run(fxx["fx_hit"], s["by"], c2)
	_shot_apply(s, at, e)

func _shot_apply(s: Dictionary, at: Vector3, e: Ent) -> void:
	var x: Dictionary = s["x"]
	if e is Hunter:
		(e as Hunter).marker_hit()      # hit through the balloon / ring: it flashes, so the rule is learned
	if x.get("cos", false):
		if x.get("boom", 0.0) > 0.0:
			fx.ring(at, x["boom"], Color("ffb070"), 0.3)
			fx.burst(at, Color("ffb070"), 26, 6.0, 0.5, 6.0, 1.3)
			sfx("boom", at, 0.0)
		else:
			fx.burst(at, s["col"], 5, 2.0, 0.25, 6.0, 0.6)
		return
	if x.has("boom"):
		_boom(s, at)
		return
	if e == null:
		fx.burst(at, s["col"], 5, 2.0, 0.25, 6.0, 0.6)
		return
	var by: Ent = s["by"]
	var dmg: float = s["dmg"]
	if x.has("swing"):
		# one swing hits each thing once, however many of its strikes reach it
		var key := "%s|%s" % [x["swing"], e.nid if e.nid != "" else str(e.get_instance_id())]
		if swing_hits.has(key):
			return
		swing_hits[key] = time
		if swing_hits.size() > 200:
			swing_hits.clear()
		fx.burst(at + Vector3(0, 0.3, 0), s["col"], 8, 3.5, 0.25, 4.0)
		sfx("hit", at, -4.0, 0.8)
	var crit := false
	if e.stun_t > 0.0 and not x.get("mob", false):
		dmg *= 1.5
		crit = true
	if x.get("crit", false) and not crit:
		dmg *= 1.5
		crit = true
	var trav := Vector2(at.x - s["start"].x, at.z - s["start"].z).length()
	if x.has("far") and trav > float(x["far"]):
		dmg *= 1.25
	if x.has("near"):
		# a sniper round needs room: half damage point-blank, full from half its range
		dmg *= lerpf(float(x["near"][0]), 1.0, clampf(trav / maxf(0.1, float(x["near"][1])), 0.0, 1.0))
	if x.has("farf") and trav > float(x["farf"][0]):
		dmg *= lerpf(1.0, float(x["farf"][1]), clampf((trav - float(x["farf"][0])) / maxf(0.1, float(x["farf"][2]) - float(x["farf"][0])), 0.0, 1.0))
	if x.has("tip") and trav + 0.25 >= float(x["tip"][0]):
		# the blade's sweet spot
		dmg *= 1.0 + float(x["tip"][1])
		fx.burst(at + Vector3(0, 0.4, 0), Color("fff6c0"), 10, 4.5, 0.3, 4.0)
	if x.has("pg"):
		# a shotgun volley: the first slug on someone does a fixed share of the whole volley,
		# the rest split what's left, so landing every slug still adds up to the full volley
		var pk := "%s|%s" % [x["pg"], e.nid if e.nid != "" else str(e.get_instance_id())]
		var n: int = int(pellet_hits.get(pk, 0))
		pellet_hits[pk] = n + 1
		if pellet_hits.size() > 300:
			pellet_hits.clear()
		var total: float = dmg * float(x["pn"])
		dmg = total * float(x["pf"]) if n == 0 else total * (1.0 - float(x["pf"])) / maxf(1.0, float(x["pn"]) - 1.0)
	var dir: Vector2 = (s["vel"] as Vector2).normalized()
	var o := {"src": "shot", "crit": crit}
	if float(x.get("kb", 0.0)) > 0.0:
		o["kb"] = dir * float(x["kb"])
	if x.has("burn"): o["burn"] = x["burn"]
	if x.has("slow"): o["slow"] = x["slow"]
	if x.has("root"): o["root"] = x["root"]
	if x.has("stun"): o["stun"] = x["stun"]
	if x.has("leech"): o["leech"] = x["leech"]
	if x.has("kbi"): o["kbi"] = x["kbi"]
	if x.has("blight"): o["blight"] = x["blight"]
	if x.has("wallstun"): o["wallstun"] = x["wallstun"]
	if x.has("ab"): o["ab"] = x["ab"]
	for kk in ["burn_for", "slow_k", "dr"]:
		if x.has(kk): o[kk] = x[kk]
	if x.has("ride_dmg") and by:
		# a kin's damage rider on your shots procs at most once a second on each target
		var pk := "%s>%s" % [by.nid, e.nid]
		if float(ride_procs.get(pk, -9.0)) < time - 1.0:
			ride_procs[pk] = time
			dmg += float(x["ride_dmg"])
		if ride_procs.size() > 400: ride_procs.clear()
	if x.get("hook", false) and by:
		# drag it back toward whoever threw the hook
		var back := Vector2(by.pos.x - e.pos.x, by.pos.z - e.pos.z)
		o["kb"] = back.normalized() * clampf(back.length() * 2.2, 6.0, 15.0)
		o["lift"] = 3.0
		o["slow"] = 2.0
		fx.bolt(by.pos + Vector3(0, 0.95, 0), e.pos + Vector3(0, 0.8, 0), Color("e0b05a"))
		net_fx(["bolt", _r(by.pos.x), _r(by.pos.y + 0.95), _r(by.pos.z), _r(e.pos.x), _r(e.pos.y + 0.8), _r(e.pos.z), "e0b05a"])
	if x.get("bolas", false):
		# a second foe close by gets tangled too, and both are stunned
		for f in foes_of(int(s["team"])):
			if f != e and f.flat_dist(e) < 2.2 and absf(f.pos.y - e.pos.y) < 1.5:
				o["stun"] = 1.0
				f.hurt(dmg, by, o.duplicate())
				fx.bolt(e.pos + Vector3(0, 0.8, 0), f.pos + Vector3(0, 0.8, 0), Color("d8c9b0"))
				break
	e.hurt(dmg, by, o)
	if x.has("mark"):
		KinRules.mark(e, String(x["mark"][0]), float(x["mark"][1]), float(x["mark"][2]))
	if x.get("blinkto", false) and by is Hunter and not by.remote and not by.downed:
		# Shadow Knife: appear behind whoever it hit
		var back := Vector2(e.pos.x - by.pos.x, e.pos.z - by.pos.z).normalized()
		var to := Vector3(e.pos.x + back.x * 1.1, 0, e.pos.z + back.y * 1.1)
		if not world.is_void(to.x, to.z) and not world.is_block(to.x, to.z):
			fx.ghost(by.position, by.face, (by as Hunter).accent(), float((by as Hunter).cdat["scale"]))
			by.teleport(Vector3(to.x, world.ground_at(to.x, to.z), to.z))
			by.vel = Vector3.ZERO
			(by as Hunter).crit_t = maxf((by as Hunter).crit_t, 1.5)
			sfx("cloak", by.pos, -2.0, 1.6)

## Shapes that ride on top of an ability's shot so it reads as what it is: a spinning disc, a hook
## with its rope back to the thrower, a glowing orb.
func _make_deco(kind_s: String, col: Color, size: float, rope: bool) -> Node3D:
	var n := Node3D.new()
	n.top_level = true
	match kind_s:
		"disc":
			var d := Models.part(n, Models.cyl(size * 2.6, size * 2.6, 0.06, 18), Models.toon(col, true, 0.9), Vector3.ZERO)
			d.name = "Spin"
			Models.part(d, Models.box(size * 5.0, 0.08, 0.1), Models.glow_mat(Color(col.lightened(0.5), 0.9)), Vector3.ZERO)
		"hook":
			var hk := Models.part(n, Models.box(0.12, 0.12, 0.5), Models.toon(Color("d8c9a8"), true, 0.4), Vector3.ZERO)
			hk.name = "Spin"
			for sx in [-1.0, 1.0]:
				Models.part(hk, Models.box(0.08, 0.08, 0.32), Models.toon(col, true, 0.8), Vector3(sx * 0.12, 0, -0.22), Vector3.ONE, Vector3(0, sx * 0.7, 0))
		"orb":
			var o := Models.part(n, Models.sphere(size * 1.6, 12), Models.glow_mat(Color(col, 0.75)), Vector3.ZERO)
			o.name = "Spin"
			Models.part(n, Models.sphere(size * 2.6, 12), Models.glow_mat(Color(col, 0.18)), Vector3.ZERO)
	if rope:
		var r := MeshInstance3D.new()
		r.mesh = Models.box(0.05, 0.05, 1.0)
		r.material_override = Models.glow_mat(Color(col.lightened(0.2), 0.85))
		r.name = "Rope"
		r.top_level = true
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(r)
	add_child(n)
	return n

func _render_deco(s: Dictionary, alpha: float) -> void:
	var n: Node3D = s["deco"]
	if not is_instance_valid(n):
		return
	var at := (s["prev"] as Vector3).lerp(s["pos"], alpha)
	n.global_position = at
	var v: Vector2 = s["vel"]
	var sp := n.get_node_or_null("Spin") as Node3D
	if sp:
		if String((s["x"] as Dictionary).get("deco", "")) == "disc":
			sp.rotation.y = time * 22.0
		elif v.length() > 0.5:
			sp.rotation.y = atan2(-v.x, -v.y)
	var rope := n.get_node_or_null("Rope") as MeshInstance3D
	var by = s["by"]
	if rope and is_instance_valid(by) and by is Node3D:
		var a: Vector3 = (by as Node3D).position + Vector3(0, 0.95 if by is Hunter else 0.5, 0)
		if a.distance_to(at) > 0.1:
			rope.global_position = (a + at) * 0.5
			rope.look_at(at, Vector3.UP if absf((at - a).normalized().y) < 0.95 else Vector3.RIGHT)
			rope.scale = Vector3(1, 1, a.distance_to(at))

func _boom(s: Dictionary, at: Vector3) -> void:
	var x: Dictionary = s["x"]
	var radius: float = x["boom"]
	fx.ring(at, radius, Color("ffb070"), 0.3)
	fx.burst(at, Color("ffb070"), 26, 6.0, 0.5, 6.0, 1.3)
	var small: bool = x.get("boom_small", false)
	fx.flash(at, Color("ffd9a0"), radius * 0.45, 0.08)
	sfx("boom", at, 0.0 if not small else -9.0, 1.0 if not small else 1.5)
	var by: Ent = s["by"]
	if not x.get("mob", false):
		for b in breaks:
			if not b["dead"] and Vector2(b["pos"].x - at.x, b["pos"].z - at.z).length() < radius + 0.36 and absf(float(b["pos"].y) + 0.4 - at.y) < 2.0:
				brk.hit(b, by)
	for e in _shot_targets(s):
		var d := Vector2(e.pos.x - at.x, e.pos.z - at.z).length()
		if d < radius + e.r and absf(e.pos.y + 0.5 - at.y) < 2.0:
			var f := 1.0 - 0.45 * minf(1.0, d / radius)
			var dir := Vector2(e.pos.x - at.x, e.pos.z - at.z).normalized()
			var o := {"src": "boom", "kb": dir * float(x.get("boom_kb", 8.0)) * f, "lift": (7.0 if not small else 1.5) * f}
			if x.has("ab"): o["ab"] = x["ab"]
			if x.has("burn"): o["burn"] = x["burn"]
			if x.has("slow"): o["slow"] = x["slow"]
			e.hurt(float(s["dmg"]) * f, by, o)

# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	if paused and not net_on:
		return
	_tips()
	if music_dir: music_dir.tick(self, delta)
	if hitstop > 0.0 and not net_on:
		hitstop -= delta
		_gather_input()
		return
	var d := DashPace.frame_dt(self, minf(delta, 0.1))
	if slowmo > 0.0:
		slowmo -= d
		d *= slow_k
	_gather_input()
	acc += d
	var steps := 0
	while acc >= DT and steps < 6:
		acc -= DT
		steps += 1
		step(DT)
	var alpha := acc / DT
	_vprof("pre")
	if opts.has("boki_demo"):
		BokiDemo.frame(self)
	elif opts.has("arch_demo"):
		ArchDemo.frame(self)       # screenshot tooling: one part of an archetype kit, timed to the shot
	KeysDemo.frame(self)           # screenshot tooling: --keys-demo=thicket|chest|glint|shrub
	_update_vision()
	SeeThrough.for_match(self)     # trees and pillars over your hunter or Boki thin out
	_vprof("vision")
	if world.wall_mat:
		var fp := player.model.global_position + Vector3(0, 0.8, 0) if player and player.model and not player.out else Vector3(0, -999, 0)
		world.wall_mat.set_shader_parameter("focus", fp)
	for e in hunters: e.render(delta, alpha)
	_vprof("hunters")
	# monsters and wild kin well away from the view animate at a quarter rate (each catches up with
	# the time it skipped); near ones every frame
	_render_n += 1
	var cf := cam.focus
	var near2 := pow(34.0 * maxf(1.0, cam.zoom), 2.0)
	if raid_fx:
		raid_fx.position = Vector3(cf.x, cf.y, cf.z)
	for e in kins:
		if _render_now(e, cf, near2):
			e.render(delta + e.lod_dt, alpha)
			e.lod_dt = 0.0
		else:
			e.lod_dt += delta
		if e.unseen or (e.owner_h and (e.owner_h as Hunter).unseen and e.state == "shoulder"):
			e.visible = false
	for e in mobs:
		if _render_now(e, cf, near2):
			e.render(delta + e.lod_dt, alpha)
			e.lod_dt = 0.0
		else:
			e.lod_dt += delta
	_vprof("kins_mobs")
	if verbs: verbs.render(alpha)
	for s in shots:
		if s.has("deco"):
			_render_deco(s, alpha)
		if String((s["x"] as Dictionary).get("src", "")) == "abil":
			AbilityFx.trail(self, s, (s["prev"] as Vector3).lerp(s["pos"], alpha))
		if s["node"]:
			var mi: MeshInstance3D = s["node"]
			mi.global_position = (s["prev"] as Vector3).lerp(s["pos"], alpha)
			var v: Vector2 = s["vel"]
			if v.length() > 1.0:
				mi.look_at(mi.global_position + Vector3(v.x, 0, v.y), Vector3.UP)
				var r: float = s.get("vr", s["r"])
				mi.scale = Vector3(r * 2.0, r * 2.0, Oomph.tracer_len(r, v.length(), float((s["x"] as Dictionary).get("tracer", 1.0))))
	_vprof("verbs_shots")
	cam.follow_mode = String(Settings.get_v("cam_follow"))
	var sty := String(Settings.get_v("cam_style"))
	if sty != cam_style:
		cam_style = sty
		cam.use_style(sty)
	cam.lead_vel = Vector3.ZERO      # (movefeel) only a live glide leans the view (set below)
	if player and player.riding:
		# aboard the skyship: a low view from just behind and above it, looking ahead along its
		# course over the islands, like riding the bus in a battle royale
		var ps := ship_of(player)
		var sd: Vector3 = ps.get("dir", Vector3.FORWARD)
		cam.yaw_to = atan2(-sd.x, -sd.z)
		cam.chase_to = 1.0
		cam.top_to = 0.0
		cam.zoom_to = 56.0 / cam.dist
		if time < 0.5:
			# boarding: start already behind the ship rather than swinging through it
			cam.chase = 1.0; cam.yaw = cam.yaw_to; cam.zoom = cam.zoom_to
		var fp := ship_pos_of(ps) + sd * 27.0
		cam.follow(Vector3(fp.x, (SHIP_Y - 11.0) / 0.6, fp.z), delta, false)
	elif player and not player.out and not player.downed:
		cam.chase_to = 0.0
		cam.yaw_to = 0.0
		if player.dropping:
			# the drop: looking down over your shoulder, pulled back while you're high up
			var gy: float = world.ground_at(player.pos.x, player.pos.z) if not world.is_void(player.pos.x, player.pos.z) else 0.0
			var hk := clampf((player.pos.y - gy) / SHIP_Y, 0.0, 1.0)
			cam.zoom_to = lerpf(1.05, 1.7, hk)
			cam.top_to = clampf(hk * 0.7, 0.0, 0.6)
		else:
			# high in the air or out over the abyss the camera pulls back so you can see where you'll land
			# the camera only eases back while gliding, so jumps and falls never change the framing
			# sneaking (Ctrl) pulls the camera well back for a wide look around [Supervive]
			cam.zoom_to = 1.25 if player.gliding else (1.45 if player.crouch and player.grounded else 1.0)
			if train.has("_sizes"): cam.zoom_to = 0.5     # (--size-demo screenshots)
			if has_meta("zoom_hold"): cam.zoom_to = float(get_meta("zoom_hold"))     # (--arena-demo screenshots)
			cam.zoom_to *= cam.user_zoom        # (1 outside the practice areas)
			# high up, the camera pulls back with your altitude so you can still read the ground
			var alt := player_altitude()
			if alt > 4.0:
				cam.zoom_to *= 1.0 + clampf((alt - 4.0) / 24.0, 0.0, 0.7)
			cam.top_to = 0.0
		cam.lead_vel = cam_lead_vel()
		cam.follow(player.render_pos(alpha), delta, not player.dropping)
	elif player and (player.downed or player.out):
		# death camera: frame you and whoever got you
		var foc := player.prev.lerp(player.pos, alpha)
		if player.pos.y < -2.0:
			foc = cam.focus
		var killer: Ent = player.last_hit_by
		if killer is Kin and killer.owner_h: killer = killer.owner_h
		if killer is Hunter and killer != player and not killer.out and killer.flat_dist(player) < 16.0:
			foc = foc.lerp(killer.pos, 0.5 if player.downed else 0.85)
		cam.zoom_to = 0.8
		# dead and waiting on your team: after a moment, watch a teammate who's still in it
		var mate := spectating()
		if mate:
			foc = mate.prev.lerp(mate.pos, alpha)
			cam.zoom_to = 1.0
		cam.follow(foc, delta, false)
	elif player:
		cam.follow(cam.focus, delta, false)
	_vprof("camera")
	_update_aim(alpha)
	_vprof("aim")
	for pd in world.pads:
		var top: Node3D = pd["node"].get_node("Top")
		top.scale = Vector3.ONE * (1.0 + sin(time * 5.0) * 0.06)
		if pd.has("arc") and player:
			var near := Vector2(player.pos.x - pd["pos"].x, player.pos.z - pd["pos"].z).length() < 6.0
			(pd["arc"] as Node3D).visible = near or player.pad.size() > 0 and (player.pad["to"] as Vector3).distance_to(pd["land"]) < 0.5
	for b in bubbles.duplicate():
		b["t"] += delta
		if b["t"] > float(b.get("life", 2.6)): bubbles.erase(b)
	for p in pings.duplicate():
		p["t"] += delta
		if p["t"] > float(p.get("life", 4.0)): pings.erase(p)
	for f in feed.duplicate():
		f["t"] += delta
		if f["t"] > 6.0: feed.erase(f)

## (movefeel) The camera leans a little ahead of a glide so you see where you're going (CamRig.lead_vel).
func cam_lead_vel() -> Vector3:
	if player == null or not player.gliding or player.out:
		return Vector3.ZERO
	var ahead := 3.0 if player.dropping else 1.0      # the drop leans further, to see the ground ahead
	return Vector3(player.vel.x, 0.0, player.vel.z) * ahead

func _gather_input() -> void:
	if player == null or player.out or opts.get("tut_test", false):
		return       # (the tutorial test drives the player itself)
	var mv := Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down"))
	if mv.length() > 1.0:
		mv = mv.normalized()
	# the camera only turns during the skyship ride and the drop after it: keys stay screen-relative
	if absf(cam.yaw) > 0.001:
		mv = mv.rotated(-cam.yaw)
	player.inp["move"] = mv
	# dropping in without steering over the abyss: drift toward the nearest island so letting go
	# of the keys never drops you into the void
	if player.dropping and mv.length() < 0.1 and world.is_void(player.pos.x, player.pos.z):
		var best := Vector3.INF; var bd := 1e9
		for sp in world.spawns + world.portal_spots:
			var d := Vector2(sp.x - player.pos.x, sp.z - player.pos.z).length()
			if d < bd: bd = d; best = sp
		if best != Vector3.INF and bd > 0.8:
			player.inp["move"] = Vector2(best.x - player.pos.x, best.z - player.pos.z).normalized()
	player.inp["aim"] = _mouse_aim()
	player.inp["aim_ray"] = cam.mouse_ray()
	player.inp["aim_y"] = aim_y      # the height of whatever you're pointing at (shots climb or dip to it)
	# a bow draw in hand ignores the mouse drifting over a panel: only the button coming up looses it
	var over_ui: bool = hud != null and hud.mouse_on_ui() and player.draw_t < 0.0
	player.inp["fire"] = Input.is_action_pressed("fire") and not paused and not over_ui
	if paused and player.draw_t >= 0.0:
		player.draw_t = -1.0           # a menu opened mid-draw: the draw is dropped, nothing is loosed
	var map_up: bool = hud != null and hud.map_open()      # the map takes the mouse buttons
	var on_panel: bool = hud != null and hud.mouse_on_panel()      # ... and so do the item windows under the cursor
	PingInput.poll(self, map_up)
	if paused:
		player.inp["move"] = Vector2.ZERO
	if KinCommand.poll(player, get_process_delta_time(), paused or map_up or on_panel) == "tap":       # G: tap sics / calls back, hold opens the order wheel
		pending_input["throw"] = true
	player.inp["interact"] = Input.is_action_pressed("interact")
	if lairs and not lairs.puzzle_of(player).is_empty():
		var pad := Input.get_connected_joypads().size() > 0 and (Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.is_joy_button_pressed(0, JOY_BUTTON_X))
		player.inp["interact"] = player.inp["interact"] or (player.inp["fire"] and not (hud and hud.mouse_on_ui())) or pad
		player.inp["fire"] = false
	# hold Space or Mouse 5 (Mouse 4 works too) in the air to glide; the mouse buttons never jump
	player.inp["glide"] = (Input.is_action_pressed("jump") or Input.is_action_pressed("glide")) and not paused
	player.inp["glide_btn"] = Input.is_action_pressed("glide") and not paused     # (movefeel) opens the glider with no tap/hold wait
	player.inp["dash_down"] = Input.is_action_pressed("dash") and not paused     # hold-shaped dashes (Slide, Rampage)
	var quick: bool = Settings.get_v("cast_on_press")
	player.inp["sec_hold"] = Input.is_action_pressed("secondary") and not paused and not on_panel
	# crouch: hold by default, or tap to toggle (the web version defaults to toggle, so you never
	# hold Ctrl while pressing W, which closes the browser tab)
	if Settings.get_v("crouch_toggle"):
		if Input.is_action_just_pressed("crouch") and not paused:
			crouch_on = not crouch_on
		if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("dash"):
			crouch_on = false
	else:
		crouch_on = Input.is_action_pressed("crouch") and not paused
	player.inp["crouch"] = crouch_on
	# the kit: Q glove, E kin ability, C throw kin, R bond, 1 2 3 the utility belt (the second kin
	# ability and kin swap are retired)
	if Input.is_action_just_pressed("base") and not paused and duel == null and not opts.get("arena", false):
		pending_input["base"] = true
	var slot_of := {"dash": "dash", "secondary": "sec", "signature": "kin", "ultimate": "ult"}      # (gloves don't rank)
	for a in [["dash", "dash"], ["jump", "jump"], ["signature", "sig"], ["util1", "util1"], ["util2", "util2"], ["util3", "util3"], ["util4", "util4"], ["ultimate", "ult"], ["secondary", "sec"], ["gear1", "gear1"], ["gear2", "gear2"]]:
		if a[0] in ["util2", "util3", "util4"] and arena != null:
			continue       # the Arena's 2-7 swap archetypes (and nothing wears out there)
		if (map_up or on_panel) and a[0] in ["secondary", "throw"]:
			continue       # right click takes your ping down while the map is up (and casts nothing over a window)
		if a[0] == "secondary" and aim_hold != "" and aim_hold != "secondary" and Input.is_action_just_pressed("secondary"):
			aim_hold = ""          # right click while aiming something else cancels the cast
			continue
		if slot_of.has(a[0]) and player and Input.is_action_just_pressed(a[0]) and not paused:
			var sl: String = slot_of[a[0]]
			if Input.is_key_pressed(KEY_ALT) and player.can_level(sl) and int(player.slot_lv[sl]) > 0:
				player.level_slot(sl)       # Alt + key: put a point into it
				continue
			if int(player.slot_lv[sl]) == 0:
				pending_input[a[1]] = true      # locked: the press unlocks it if you have a point
				continue
		var aimable: bool = a[0] in ["signature", "ultimate", "gear1", "gear2", "secondary"] and not quick and not (player.ak != null and a[0] == "secondary")
		if a[0] == "secondary" and player.runner and player.runner.def_of("utility") and not player.runner.def_of("utility").charge.is_empty():
			aimable = false       # a charge-up starts on the press and fires on the release
		if a[0] in Gloves.KEYS and (player.gear[Gloves.KEYS.find(a[0])] as Dictionary).is_empty():
			aimable = false
		if a[0] == "signature" and player.ak != null and player.ak.e_on_press():
			aimable = false       # a self-centred E goes off on the press (no cursor preview)
		if aimable:
			# hold to see where it will land, let go to cast it
			if Input.is_action_just_pressed(a[0]) and not paused:
				aim_hold = a[0]
			if aim_hold == a[0] and not Input.is_action_pressed(a[0]):
				aim_hold = ""
				pending_input[a[1]] = true
			continue
		if Input.is_action_just_pressed(a[0]):
			pending_input[a[1]] = true
	if Input.is_action_just_pressed("hunter_ult") and player and not paused:
		HunterKeys.ult_pressed(player)

func _unhandled_input(event: InputEvent) -> void:
	if tut and tut.intro and event.is_pressed() and not event.is_echo() and not event.is_action_pressed("menu") and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		tut.ack()
		get_viewport().set_input_as_handled()
		return
	if hud and hud.map_open() and (event.is_action_pressed("menu") or event.is_action_pressed("map")):
		hud.close_map()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("map") and hud and player and not over and not Overlay.is_open() and hud.map_allowed():
		hud.open_map(false)
		get_viewport().set_input_as_handled()
		return
	if skydrop and player and not player.out and not paused:
		if event.is_action_pressed("pass_lead") and skydrop.pass_lead(player):
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("separate") and skydrop.separate(player):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("menu") and hud and (hud.swap_open() or hud.pack_open()):
		hud.close_swap(); hud.close_pack()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu") and not over and not result.get("ending", false) and not Overlay.is_open():
		Overlay.open_pause("match")
	elif event.is_action_pressed("inventory") and hud and player and not player.out and not opts.get("training", false):
		hud.toggle_pack()

## Called by the Overlay whenever one of its menus opens over this match.
func on_menu_opened() -> void:
	paused = true
	if not Overlay.closed.is_connected(_on_menu_closed):
		Overlay.closed.connect(_on_menu_closed, CONNECT_ONE_SHOT)

func _on_menu_closed() -> void:
	paused = false
	if not over:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func step(dt: float) -> void:
	if over:
		return
	if skydrop and skydrop.planning:
		# planning the drop: the ship waits at the edge of the map and the match clock waits with it
		# (keys pressed meanwhile don't carry over: a Space now must not jump you off at the edge)
		for k in pending_input: pending_input[k] = false
		skydrop.tick_plan(dt)
		if String(opts.get("map_demo", "")) == "plan" and player and skydrop.clock > 1.2 and not has_meta("map_demo_done"):
			# test: your ping on a vault, beside the bots' picks
			set_meta("map_demo_done", true)
			var vs: Array = spawn_plan.active_of("vault") if spawn_plan else []
			squad_ping(player, vs[0]["pos"] if not vs.is_empty() else world.spawns[0])
		_update_ship(dt)
		if net_on:
			Net.tick(dt)
		return
	if tut and tut.intro:
		tut.intro_wait(dt)      # (the intro card: the match waits for a key or two seconds)
		return
	time += dt
	if Game.god and player and not player.out:
		# admin god mode: full health, endless ammo, nothing on cooldown
		player.hp = player.max_hp
		player.ammo = int(player.wpn["mag"])
		player.sig_cd = 0.0
		player.ult = 1.0
		player.dashes = player.max_dashes()
		player.glide_fuel = 1.0
		if player.downed: revive_hunter(player, player)
	if opts.get("ability_demo", false) and player and not player.dropping:
		var best: Ent = null; var bd := 1e9
		for f in foes_of(player.team):
			if player.flat_dist(f) < bd: bd = player.flat_dist(f); best = f
		if best:
			player.inp["aim"] = best.pos + Vector3(0, 0.9, 0)
			player.inp["fire"] = bd < 10.0
			if bd > 6.0: player.inp["move"] = player.dir_to(best)
			else: player.inp["move"] = Vector2.ZERO
		if int(time * 60.0) % 90 == 0: player.inp["sig"] = true
		if time > 4.0 and int(time * 60.0) % 240 == 0:
			player.ult = 1.0; player.inp["ult"] = true
	if opts.get("life_demo", false) and player and time < 0.05 and not beacons.is_empty():
		# test: stand by a revive beacon with a teammate's deathbox next to it
		var bc: Vector3 = beacons[0]["pos"]
		player.teleport(world.free_spot_near(bc + Vector3(-3.0, 0, 2.5), [bc], 1.5, 0.4, 8.0))
		for x in hunters:
			if x.team == player.team and x != player:
				x.teleport(world.free_spot_near(bc + Vector3(-1.5, 0, 3.0), [bc, player.pos], 1.2, 0.4, 8.0))
				x.gems = 60
				x.ctrl = "idle"
				if opts.get("boxrev_demo", false): x.lives = 1
				eliminate(x, null, "knocked out")
				break
	if opts.has("lost_demo") and player and time > 0.3 and not has_meta("lost_demo_done"):
		# test: a Boki left behind. "rival": a rival with a Boki goes out next to you; "you": you go out
		# (Duos, your squadmate carries on) and your Boki is left where you fell
		set_meta("lost_demo_done", true)
		if String(opts["lost_demo"]) == "you":
			for x in hunters:
				if x.team == player.team and x != player: x.ctrl = "idle"
			player.lives = 1
			eliminate(player, null, "knocked out")
		else:
			for x in hunters:
				if x.team != player.team and x.kin and not x.out:
					x.teleport(world.free_spot_near(player.pos + Vector3(3.0, 0, 1.5), [player.pos], 1.0, 0.4, 8.0))
					if x.kin.state != "shoulder": x.kin.teleport(x.pos + Vector3(0.8, 0, 0))
					x.lives = 1
					eliminate(x, null, "knocked out")
					break
	if opts.get("boxrev_demo", false) and player and time > 0.3:
		# test: bring the teammate back at their deathbox (the channel's light, the kneel, the hum)
		for b in boxes:
			if b["owner"] != player and b["owner"].team == player.team and Life.soul_here(self, b):
				if player.flat_dist(b["pos"]) > 0.6 and player.box_t <= 0.0:
					player.teleport(b["pos"] + Vector3(0.5, 0, 0.3))
				player.inp["interact"] = true
				break
	if (opts.get("pack_demo", false) or opts.get("bag_demo", false)) and player and time > 1.0 and not has_meta("pack_demo_done") and hud:
		# test: a full backpack. pack_demo picks up treasure (the swap window); bag_demo opens the backpack
		set_meta("pack_demo_done", true)
		player.pack_cap = 6
		var gk: Array = Gear.ALL.keys()
		player.pack = [Loot.gear("skylark_boots", 2), Loot.valuable("sky_pearl"), Loot.gear(String(gk[1 % gk.size()]), 2), Loot.gear("vest", 1), Loot.valuable("old_coin"), Loot.valuable("kin_idol")]
		player.gear[Gear.slot_on(player, String(gk[0]))] = {"id": String(gk[0]), "rar": 3}
		player.refresh_gear()
		var pat := world.free_spot_near(player.pos + Vector3(1.0, 0, 0.6), [player.pos], 0.6)
		spawn_val(Loot.valuable("crown_shard"), Vector3(pat.x, world.ground_at(pat.x, pat.z), pat.z))
		var pat2 := world.free_spot_near(player.pos + Vector3(-1.4, 0, 1.0), [player.pos, pat], 0.6)
		spawn_gear("gale_mantle", 3, Vector3(pat2.x, world.ground_at(pat2.x, pat2.z), pat2.z), "", false)
		if opts.get("pack_demo", false):
			Pack.take_ground(self, player, wpicks[wpicks.size() - 2])
		else:
			hud.toggle_pack()
	if opts.get("gear_demo", false) and player and time > 1.0 and not has_meta("gear_demo_done") and hud:
		set_meta("gear_demo_done", true)
		GearDrops.demo(self)
	if opts.get("mates_demo", false) and player:
		# test: the squad UI. One teammate gets knocked, one dies into a deathbox, and the first is
		# picked back up a few seconds later (frames under the minimap and the ally alerts up top)
		var mates: Array = hunters.filter(func(x): return x.team == player.team and x != player)
		if time < 0.05:
			for i in mates.size():
				var x: Hunter = mates[i]
				x.ctrl = "idle"
				x.teleport(world.free_spot_near(player.pos + Vector3(-4.0 + 3.0 * i, 0, -3.0 + 1.5 * i), [player.pos], 1.2, 0.4, 10.0))
		if mates.size() >= 3:
			if time > 1.0 and time < 1.1 and not mates[0].downed: knock(mates[0], null, {})
			if mates[0].downed and not opts.has("mates_revive") or (opts.has("mates_revive") and time < float(opts.get("mates_revive", 0.0))): mates[0].revive = 0.0
			if time > 1.6 and time < 1.7 and not mates[1].out: eliminate(mates[1], null, "knocked out")
			if time > 1.2: mates[2].hp = mates[2].max_hp * 0.4; mates[2].armor = mates[2].max_armor * 0.5; mates[2].slow_t = 2.0
			if opts.has("mates_revive") and time > float(opts["mates_revive"]) and mates[0].downed:
				revive_hunter(mates[0], player)
			# test: an enemy standing on the knocked teammate (the stomp signal), kept alive for the shot
			if opts.get("stomp_demo", false) and mates[0].downed and time > 1.3:
				mates[0].down_hp = maxf(mates[0].down_hp, 55.0)
				for e in hunters:
					if e.team != player.team and not e.out:
						e.ctrl = "idle"
						e.teleport(mates[0].pos + Vector3(0.4, 0, 0.2))
						break
			# test: walk up to the dead teammate's deathbox and open the loot window
			if opts.get("loot_demo", false) and time > 2.0 and not has_meta("loot_demo_done") and hud:
				set_meta("loot_demo_done", true)
				var lb: Dictionary = Life.box_of(self, mates[1])
				if not lb.is_empty():
					var ids: Array = Gear.ALL.keys()
					if ids.size() > 1:
						(lb["gear"] as Array).append({"id": String(ids[0]), "rar": 3})
						(lb["gear"] as Array).append({"id": String(ids[1]), "rar": 1})
					lb["pack"] = [Loot.valuable("crown_shard"), Loot.gear("quilted_coat", 3), Loot.valuable("old_coin"), Loot.valuable("soul_ember")]
					player.pack = [Loot.valuable("sky_pearl"), Loot.gear("magpie", 1), Loot.valuable("kin_idol"), Loot.gear("windstep_boots", 2), Loot.valuable("old_coin")]
					lb["gems"] = int(lb.get("gems", 0)) + 25
					lb["empty"] = false
					player.teleport(lb["pos"] + Vector3(0.8, 0, 0.6))
					hud.open_loot(lb)
	if opts.get("ledge_demo", false) and player and time < 0.05:
		# test: start just off the edge of your island, a few metres below the lip
		var p0 := player.pos
		for i in 60:
			var q := p0 + Vector3(0.5 * i, 0, 0)
			if world.is_void(q.x, q.z):
				player.teleport(Vector3(q.x + 1.0, player.pos.y - 4.0, q.z)); player.grounded = false
				break
	if opts.has("aim_demo") and player:
		var demo_gloves := String(opts.get("glove", "")).split(",", false)      # --glove=a[,b]: Q, V
		for gi in mini(2, demo_gloves.size()):
			if (player.gear[gi] as Dictionary).is_empty():
				player.gear[gi] = {"id": demo_gloves[gi], "rar": 2}
		aim_hold = String(opts["aim_demo"])
		player.inp["aim"] = player.pos + Vector3(4.0, 0, -3.0)
	if opts.get("sandbox_demo", false) and player:
		# test hook: lob the utility at the nearest dummy, then dodge
		var tgt: Ent = null; var bd := 1e9
		for mb in mobs:
			if not mb.dead and player.flat_dist(mb) < bd: bd = player.flat_dist(mb); tgt = mb
		if tgt: player.inp["aim"] = tgt.pos + Vector3(0, 0.95, 0)
		if time > 0.8 and time - DT <= 0.8: pending_input["sec"] = true
		if time > 2.6 and time - DT <= 2.6: pending_input["dash"] = true
		if time > 1.6: player.inp["fire"] = true
	if "--kin-lineup" in OS.get_cmdline_user_args() and player and not train.has("_lineup"):
		# test: every species in a row in front of you, glowing as if out in a fight
		train["_lineup"] = true
		var i := 0
		for spid in Data.KIN.keys():
			var q := player.pos + Vector3(-3.0 + i * 1.3, 0, -2.2)
			var w := spawn_wild(Save.new_kin(spid), q)
			w.home = q
			w.set_meta("lineup", true)
			i += 1
		cam.zoom_to = 0.55
	if "--size-demo" in OS.get_cmdline_user_args() and player:
		# test: an extra small and an extra large Vespyx side by side, held still (their rings show
		# the hitbox), and the camera in close
		if not train.has("_sizes"):
			var ws: Array = []
			for si in 2:
				var srec := Save.new_kin("cindle", "", kin_seed("demo"))
				srec["dna"]["size"] = -2.8 if si == 0 else 2.8
				srec["level"] = 6
				var sq := player.pos + Vector3(-1.2 + si * 2.4, 0, 1.6)
				var sw := spawn_wild(srec, sq)
				sw.home = sq
				sw.set_meta("lineup", true)
				ws.append(sw)
			train["_sizes"] = ws
		for sw in train["_sizes"]:
			if is_instance_valid(sw): sw.wander_to = sw.home
	if opts.get("kin_demo", false) and player:
		# test hook: throw the kin at the nearest dummy, use Q, then V, then the bond ultimate, then swap
		var tgt: Ent = null; var bd := 1e9
		for mb in mobs:
			if not mb.dead and player.flat_dist(mb) < bd: bd = player.flat_dist(mb); tgt = mb
		if tgt: player.inp["aim"] = tgt.pos + Vector3(0, 0.95, 0)
		var tick := func(at_t: float) -> bool:
			if time > at_t and not train.has("_demo_%d" % int(at_t * 10.0)):
				train["_demo_%d" % int(at_t * 10.0)] = true
				return true
			return false
		if tick.call(0.6): pending_input["throw"] = true
		if tick.call(1.6): pending_input["sig"] = true
		if tick.call(3.4): pending_input["skill"] = true
		if tick.call(5.2): player.ult = 1.0; pending_input["ult"] = true
		if tick.call(11.0): pending_input["swap"] = true
		if time > 1.0: player.inp["fire"] = true
	if opts.get("carry_demo", false) and cam:
		cam.zoom_to = 0.4          # (screenshots: close and low enough to see the kin on you)
		cam.pitch = deg_to_rad(42.0)
	if opts.get("carry_demo", false) and player and time < 0.05 and not opts.get("glide_demo", false) and not train.has("_open"):
		# (screenshots: step out onto open ground, away from the racks and crates)
		train["_open"] = true
		var best := player.pos; var bs := -1
		for ring_r in [6.0, 9.0, 12.0]:
			for i in 16:
				var q: Vector3 = player.pos + Vector3(cos(TAU * i / 16.0), 0, sin(TAU * i / 16.0)) * float(ring_r)
				var score := 0
				for dx in range(-3, 4):
					for dz in range(-3, 4):
						if not world.is_void(q.x + dx, q.z + dz) and not world.is_block(q.x + dx, q.z + dz) and not world.in_bush(q.x + dx, q.z + dz): score += 1
				if score > bs: bs = score; best = Vector3(q.x, world.ground_at(q.x, q.z), q.z)
		player.teleport(best)
	if opts.get("carry_demo", false) and player and not player.dropping and not opts.get("glide_demo", false) and not opts.get("rival_demo", false):
		# test hook: walk a slow circle with your kin riding along (mount, perch or shoulder)
		player.inp["move"] = Vector2(cos(time * 0.6), sin(time * 0.6)) * 0.6 if time > 0.4 else Vector2.ZERO
		player.inp["aim"] = player.pos + Vector3(cos(time * 0.6), 0.9, sin(time * 0.6)) * 4.0
	if opts.get("merge_demo", false) and player and time > 0.8 and not train.has("_merge"):
		train["_merge"] = true
		player.slot_lv["ult"] = maxi(1, int(player.slot_lv["ult"]))
		player.ult = 1.0
		player.merge_cd = 0.0
		if KinMerge.cast(player):
			player.merge_st["t"] = 60.0          # held for the screenshot
			player.merge_st["T"] = 60.0
	if opts.get("rival_demo", false) and player and not train.has("_rival") and time > 0.3:
		# test hook: the nearest rival hunter steps up 5m in front of you (for the hover panel)
		train["_rival"] = true
		var rv: Hunter = null
		for h in hunters:
			if h.team != player.team:
				rv = h; break
		if rv == null:
			# (the sandbox has no rivals: one steps in, with a kin)
			var rk := Save.new_kin(String(opts.get("rival_kin", "zapple")))
			rk["name"] = "Fizz"
			rv = make_hunter("rival", 7, "light", "Rook", "idle", rk, player.pos + Vector3(4.5, 0, -1.5), bot_kit())
		var spot := player.pos; var bs := -1
		for ring_r in [4.0, 5.0, 3.0]:
			for i in 12:
				var q: Vector3 = player.pos + Vector3(cos(TAU * i / 12.0), 0, sin(TAU * i / 12.0)) * float(ring_r)
				if world.is_void(q.x, q.z) or world.is_block(q.x, q.z) or world.in_bush(q.x, q.z) or absf(world.ground_at(q.x, q.z) - player.pos.y) > 0.3:
					continue
				var score := 0
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						if not world.is_void(q.x + dx, q.z + dz) and not world.is_block(q.x + dx, q.z + dz) and not world.in_bush(q.x + dx, q.z + dz): score += 1
				if score > bs: bs = score; spot = Vector3(q.x, world.ground_at(q.x, q.z), q.z)
		rv.teleport(spot)
		rv.vel = Vector3.ZERO
		rv.ctrl = "idle"
	if opts.get("rival_demo", false) and player and train.has("_rival"):
		player.inp["move"] = Vector2.ZERO
		if "--debug-rival" in OS.get_cmdline_user_args() and int(time * 60.0) % 60 == 0:
			for h in hunters:
				if h != player: print("RIVAL ", h.pname, " ", h.pos, " vis ", h.visible, " unseen ", h.unseen, " out ", h.out, " team ", h.team)
	if "--juice-demo" in OS.get_cmdline_user_args() and player and not player.dropping:
		# screenshots of hits (Juice): a rival steps up 4m away, holds still, and takes fire
		if hud: hud.guide_hidden = true
		if not train.has("_jt"):
			Settings.v["tips"] = false
			if "--demo-slow" in OS.get_cmdline_user_args(): Engine.time_scale = 0.2   # (software-rendered screenshots catch the short flashes)
			var q := demo_clear_spot(4.0)
			var jt := make_hunter("jtarget", 7, "medium", "Rook", "idle", {}, Vector3(q.x, world.ground_at(q.x, q.z), q.z), bot_kit())
			jt.lives = 1
			train["_jt"] = jt
		var jt2: Hunter = train["_jt"]
		if is_instance_valid(jt2) and not jt2.out:
			player.inp["aim"] = jt2.pos + Vector3(0, 0.95, 0)
			player.inp["move"] = Vector2.ZERO
			player.inp["fire"] = time > 0.6
	if "--rmb-demo" in OS.get_cmdline_user_args() and player and not player.dropping:
		# screenshots of a weapon's right click: a rival 5m away takes two shots, then the RMB at
		# 1.2s (held 1s if it charges); a trap is laid at the rival's feet and they step back onto it
		if hud: hud.guide_hidden = true
		if not train.has("_rt"):
			Settings.v["tips"] = false
			if "--demo-slow" in OS.get_cmdline_user_args(): Engine.time_scale = 0.2   # (software-rendered screenshots catch the short flashes)
			var q := demo_clear_spot(5.0)
			var rt := make_hunter("rtarget", 7, "medium", "Rook", "idle", {}, Vector3(q.x, world.ground_at(q.x, q.z), q.z), bot_kit())
			rt.lives = 1
			train["_rt"] = rt
		var rt2: Hunter = train["_rt"]
		if is_instance_valid(rt2) and not rt2.out:
			player.inp["aim"] = rt2.pos + Vector3(0, 0.95, 0)
			player.inp["move"] = Vector2.ZERO
			player.inp["fire"] = time > 0.5 and time < 0.75
			if time >= 1.2 and not train.has("_rt_sec"):
				train["_rt_sec"] = rt2.pos
				player.inp["sec"] = true
			player.inp["sec_hold"] = time >= 1.2 and time < 2.2
			if time >= 2.6 and time < 2.7 and train.has("_rt_sec"):
				rt2.teleport(train["_rt_sec"])
	if opts.get("cone_demo", false) and player:
		player.inp["aim"] = player.pos + Vector3(4.0, 0.95, -5.0)
		player.inp["crouch"] = opts.get("crouch_demo", false)
	if opts.get("wall_behind", false) and player and time < 0.05:
		for wi in world.walls:
			var wx: int = int(wi) % world.w; var wz: int = int(wi) / world.w
			var gi := world.idx(wx, wz - 1)
			if world.kind[gi] == World.T_GROUND and world.walls.has(world.idx(wx + 1, wz)) and world.walls.has(world.idx(wx - 1, wz)):
				player.teleport(Vector3(wx + 0.5, world.ground_at(wx + 0.5, wz - 0.5), wz - 0.5))
				break
	if opts.get("wall_demo", false) and player and time < 0.05:
		# stand in grass right beside a wall, with a rival hiding in grass nearby
		var spot := Vector3.INF; var rival_spot := Vector3.INF
		for bi in world.bush:
			var bx: int = int(bi) % world.w; var bz: int = int(bi) / world.w
			var near_wall := false
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					if world.walls.has(world.idx(bx + dx, bz + dz)): near_wall = true
			var p3 := Vector3(bx + 0.5, world.ground_at(bx + 0.5, bz + 0.5), bz + 0.5)
			if near_wall and spot == Vector3.INF:
				spot = p3
			elif spot != Vector3.INF and rival_spot == Vector3.INF and p3.distance_to(spot) > 3.0 and p3.distance_to(spot) < 9.0:
				rival_spot = p3
		if spot != Vector3.INF:
			player.teleport(spot)
			for h in hunters:
				if h.team != player.team:
					h.teleport(rival_spot if rival_spot != Vector3.INF else spot + Vector3(4, 0, 0))
					break
	if opts.get("ring_demo", false) and player and time < 0.05 and not air_rings.is_empty():
		var rg: Dictionary = air_rings[0]
		var rd: Vector2 = rg["dir"]
		player.teleport(rg["pos"] - Vector3(rd.x, 0, rd.y) * 5.0 + Vector3(0, -0.6, 0))
		player.grounded = false; player.gliding = true
		player.vel = Vector3(rd.x, 0, rd.y) * 9.6
	if opts.get("ring_demo", false) and player and player.gliding:
		player.inp["glide"] = true
		player.inp["move"] = Vector2(player.vel.x, player.vel.z).normalized()
	if String(opts.get("map_demo", "")) == "mid" and player and hud and time > 0.6 and not has_meta("map_demo_done"):
		# test: the map mid-match, with a few spawns scouted (found, empty and taken) and squad pings
		set_meta("map_demo_done", true)
		var n_k := 0
		for cnd in (spawn_plan.cands if spawn_plan else []):
			if cnd["cat"] in ["rare_kin", "cache"] and n_k < 6 and (n_k % 2 == 0 or cnd["active"]):
				cnd["known"][player.team] = true; n_k += 1
		for cnd in (spawn_plan.active_of("vault").slice(0, 1) if spawn_plan else []):
			if cnd["ref"] is Dictionary: cnd["ref"]["open"] = true
		for x in hunters:
			if x.team == player.team and x != player:
				squad_ping(x, world.free_spot_near(x.pos + Vector3(14, 0, -6), [], 1.0, 0.5, 12.0)); break
		squad_ping(player, player.pos + Vector3(-20, 0, 12))
		hud.open_map(false)
	if opts.has("drop_demo") and player and not ship.is_empty():
		# test: skip ahead to the middle of the ride, the leader jumps and steers; the squad follows
		var follow: bool = String(opts["drop_demo"]) == "follow"     # (a squadmate leads, you follow)
		if not has_meta("drop_demo_t"):
			set_meta("drop_demo_t", true)
			time = float(ship["dur"]) * 0.5 - 2.0
			if follow and skydrop: skydrop.pass_lead(player)
		if player.riding and time > float(ship["dur"]) * 0.5 - 1.0:
			if follow:
				var ld := skydrop.leader(player.team)
				if ld and ld.riding: ship_jump(ld)
			else:
				ship_jump(player)
		if player.dropping:
			player.inp["move"] = Vector2(0.8, -0.6).normalized() if fmod(time, 6.0) < 3.0 else Vector2(0.3, 1.0).normalized()
	if opts.get("truce_demo", false) and truce:
		truce.demo()
	if opts.has("see_demo") and player and not player.dropping and not has_meta("see_demo_done"):
		set_meta("see_demo_done", true)
		SeeThrough.demo(self, String(opts["see_demo"]))
	if opts.has("exit_demo") and exits and player and not player.dropping:
		exits.demo(String(opts["exit_demo"]))
	if (opts.get("raid_demo", false) or opts.get("chest_demo", false) or has_meta("stairs_demo")) and hud and not hud.guide_hidden:
		Settings.v["tips"] = false          # (screenshots of a raid condition: no tutorial cards)
		hud.guide_hidden = true
	if "--kit-demo" in OS.get_cmdline_user_args() and player and time > 0.3 and not train.has("_kitdemo"):
		# screenshots: hurt and with cracked armor, so the tonic (1) and armor kit (2) slots are both lit
		train["_kitdemo"] = true
		player.hp = player.max_hp * 0.6
		player.armor = player.max_armor * 0.25
	if opts.has("blight_demo") and blight and player and not player.dropping and time > 0.2:
		blight.demo(String(opts["blight_demo"]))
	if opts.has("teammate_demo"):
		KinCompanion.demo_tick(self, String(opts["teammate_demo"]))
	if opts.get("glide_demo", false) and player:
		if time < 0.05:
			player.teleport(player.pos + Vector3(0, 6, 0)); player.grounded = false
		player.inp["glide"] = true
		player.inp["move"] = Vector2(1, 0.3).normalized()
	if opts.get("dashglide_demo", false) and player:
		# test (movefeel): glide along, Shift at 0.7s, keep holding glide: the glider keeps the dash
		if time < 0.05:
			player.teleport(player.pos + Vector3(0, 7, 0)); player.grounded = false
			player.unlock_all()
		player.inp["glide"] = true
		player.inp["move"] = Vector2(1, 0.3).normalized()
		if time > 0.7 and time - DT <= 0.7: pending_input["dash"] = true
	if opts.get("dashpip_demo", false) and player:
		# test (HUD): on foot, spend the short dashes and then the long one, then stand still and refill
		player.inp["move"] = Vector2(1, 0.2).normalized() if time < 1.6 else Vector2.ZERO
		for t in [0.4, 0.9, 1.4]:
			if time > t and time - DT <= t: pending_input["dash"] = true
	if opts.has("abyss_demo") and player:
		_abyss_demo(String(opts["abyss_demo"]))
	if player and not player.out:
		if pending_input["base"]:
			pending_input["base"] = false
			player.start_base(base_target(player))
		for k in ["dash", "jump", "sig", "util1", "util2", "util3", "util4", "ult", "sec", "gear1", "gear2", "skill", "swap"]:
			if pending_input.get(k, false):
				player.inp[k] = true
				pending_input[k] = false
		if pending_input["throw"]:
			pending_input["throw"] = false
			KinCommand.tap(player)
		KinCommand.apply_pick(player)
	_prof("pre")
	SimLod.plan(self, dt)           # far, calm bots step at 20 Hz (decision 0022)
	for h in hunters:
		if h.ctrl == "bot" and not h.remote and not h.out and not h.extracted and SimLod.step_dt(h, dt) > 0.0:
			bot_brain.tick(self, h, SimLod.step_dt(h, dt))
	Capture.tick(self, dt)          # a running scan roots its hunter, after the bots have decided
	_prof("bots")
	if skytrain: skytrain.tick(dt)
	if opts.has("train_demo") and skytrain and player:
		_train_demo()
	if opts.has("balloon_demo") and player:
		_balloon_demo()
	if duel:
		duel.after_think()
		duel.tick(dt)
	if arena:
		arena.after_think()
		arena.tick(dt)
	_prof("train")
	for h in hunters: h.sim(SimLod.step_dt(h, dt))
	_prof("hunters")
	if opts.get("autoplay", false) and int(time * 60.0) % 15 == 0:
		for h in hunters:
			var hist: Array = h.get_meta("hist", [])
			hist.append("%.1f:(%.1f,%.1f,%.1f) v(%.1f,%.1f,%.1f) g%d f%.2f r%.2f gr%d void%d gl%d fuel%.1f kb%.1f dn%d st%.1f cd%.1f %s" % [time, h.pos.x, h.pos.y, h.pos.z, h.vel.x, h.vel.y, h.vel.z, int(h.grounded), h.fly_t, h.roll_t, int(h.grap.size() > 0), int(h.over_void()), int(h.gliding), h.glide_fuel, time - h.kb_t, int(h.downed), h.stun_t, h.grap_cd, String(h.ai.get("goal_kind", ""))])
			if hist.size() > 10: hist.pop_front()
			h.set_meta("hist", hist)
	if skydrop: skydrop.tick(dt)
	_prof("drop")
	for k in kins: k.sim(SimLod.kin_dt(k, dt))
	_prof("kins")
	for mb in mobs: mb.sim(dt)
	if blight: blight.tick(dt)
	_prof("mobs")
	_separate()
	_collide_breaks()
	brk.tick(dt)
	_prof("separate")
	_update_rings(dt)
	_update_shots(dt)
	_prof("shots")
	_update_pickups(dt)
	BeltKeys.tick(self)      # a full belt beside a key: the swap prompt (bots make room)
	_update_wpicks(dt)
	PerkOrbs.update(self, dt)
	_update_gear_fx(dt)
	_update_pads(dt)
	_prof("pickups")
	if not ship.is_empty() and not ship.get("gone", false):
		_update_ship(dt)
	for s in ships:
		_update_one_ship(s, dt)
	if rolling:
		rolling.tick(dt)
		if opts.has("rolling_demo"): rolling.demo(String(opts["rolling_demo"]))
	_update_interact(dt)
	_update_box_hums()
	_prof("interact")
	if opts.get("perk_demo", false) and player and time > 0.5 and time - dt <= 0.5:
		PerkOrbs.demo(self)      # test: a couple of perks taken and a boss's fan of orbs ahead
		if hud: hud.ability_feedback("sec", "deny")
	Life.tick_wisps(self, dt)
	Life.tick_stomps(self, dt)
	_tick_chase()
	Beacons.tick(self, dt)
	if not net_on:
		_watch_death()
	_update_dex(dt)
	_prof("life")
	if exits: exits.tick(dt)
	_prof("exits")
	if opts.get("hold_demo", false) and player:
		_hold_demo()
	if opts.get("plate_demo", false) and player:
		_plate_demo()
	if opts.has("hudref_demo"): HudRefDemo.tick(self)
	if lairs:
		lairs.bot_pickups()
		lairs.tick(dt)
		if opts.has("lair_demo") and player and not player.dropping:
			lairs.demo(String(opts["lair_demo"]))
	_prof("lairs")
	if truce: truce.tick(dt)
	if spawn_plan: spawn_plan.tick(dt)
	_prof("truce_spawns")
	_update_events()
	_update_zones(dt)
	fields.tick(dt)
	verbs.tick(dt)
	displace.tick(dt)
	_run_later()
	if biomes: biomes.tick(dt)
	_update_tracking(dt)
	if opts.get("tutorial", false):
		if opts.get("tut_test", false):
			TutorialDrive.drive(self)
			if "--tut-slow" in OS.get_cmdline_user_args():
				player.inp["move"] = (player.inp["move"] as Vector2) * 0.5     # test: walk, so your Boki can lead (screenshots)
		tut.update(dt)
	if opts.get("training", false) and duel == null:
		_update_training(dt)
	_update_rules(dt)
	_prof("rest")
	if net_on:
		_net_rev_t -= dt
		if _net_rev_t <= 0.0:
			_net_rev_t = 0.1
			_process_net_revives()
		Net.tick(dt)

func _ground_aim(h: Hunter) -> Vector3:
	var a: Vector3 = h.inp["aim"]
	var g := world.ground_at(a.x, a.z)
	return Vector3(a.x, g if g > World.VOID + 1.0 else h.pos.y, a.z)

const SEP_CELL := 4.0
func _separate() -> void:
	var bodies: Array = []
	for h in hunters:
		if h.hittable() and h.grap.is_empty(): bodies.append(h)
	for mb in mobs:
		if not mb.dead and not Shrubling.hidden(mb): bodies.append(mb)      # (you walk into a disguised Shrubling like any bush)
	for k in kins:
		if k.state in ["active", "wild", "dazed", "returning"] and not k.dead and not KinLoss.cradled(k): bodies.append(k)
	# only bodies in the same or a neighbouring 4m cell can touch (radii are well under 2m): a grid
	# instead of every pair, in the same pair order as before
	var grid := {}
	for i in bodies.size():
		var e: Ent = bodies[i]
		var key := Vector2i(floori(e.pos.x / SEP_CELL), floori(e.pos.z / SEP_CELL))
		if grid.has(key): (grid[key] as Array).append(i)
		else: grid[key] = [i]
	for i in bodies.size():
		var a: Ent = bodies[i]
		var ck := Vector2i(floori(a.pos.x / SEP_CELL), floori(a.pos.z / SEP_CELL))
		var near: Array = []
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var cell = grid.get(ck + Vector2i(dx, dz))
				if cell == null: continue
				for j in cell:
					if j > i: near.append(j)
		if near.is_empty():
			continue
		near.sort()
		for j in near:
			var b: Ent = bodies[j]
			if absf(a.pos.y - b.pos.y) > 1.0:
				continue
			var d := Vector2(b.pos.x - a.pos.x, b.pos.z - a.pos.z)
			var mind := a.r + b.r
			var l := d.length()
			if l < mind and l > 0.0001:
				var push := d / l * (mind - l) * 0.5
				var wa := 1.0 / a.mass(); var wb := 1.0 / b.mass()
				var tot := wa + wb
				var pa := -push * (wa / tot) * 2.0
				var pb := push * (wb / tot) * 2.0
				# bodies push each other around, but never off an edge
				if world.occupy(a.pos.x + pa.x, a.pos.z + pa.y, a.r, a.pos.y, a.grounded) == 0.0:
					a.pos.x += pa.x; a.pos.z += pa.y
				if world.occupy(b.pos.x + pb.x, b.pos.z + pb.y, b.r, b.pos.y, b.grounded) == 0.0:
					b.pos.x += pb.x; b.pos.z += pb.y

## --hold-demo (screenshots): every hunter in a row by you, each holding interact for something
## different, named after it.
## --plate-demo (screenshots): your squad beside you and rivals near and far, a few of them hurt,
## to see the overhead nameplates.
func _plate_demo() -> void:
	if has_meta("plate_demo_done"):
		for h in hunters:
			if h != player: h.inp["move"] = Vector2.ZERO
		return
	if time < 0.3:
		return
	set_meta("plate_demo_done", true)
	for mb in mobs: mb.dead = true; mb.visible = false
	var base: Vector3 = player.pos
	var mates := hunters.filter(func(x): return x != player and x.team == player.team)
	var foes := hunters.filter(func(x): return x.team != player.team)
	var spots := [Vector3(-2.6, 0, 0.6), Vector3(2.6, 0, 0.8)]
	var fspots := [Vector3(-3.5, 0, -4.5), Vector3(3.0, 0, -5.0), Vector3(-6.5, 0, -8.5), Vector3(5.5, 0, -10.5), Vector3(0.5, 0, -12.0), Vector3(8.0, 0, -6.0)]
	var place := func(h: Hunter, off: Vector3) -> void:
		var at := world.free_spot_near(base + off, [], 0.6, 0.5, 4.0)
		h.teleport(Vector3(at.x, world.ground_at(at.x, at.z), at.z))
		h.ctrl = "idle"; h.vel = Vector3.ZERO
	for i in mates.size():
		if i < spots.size(): place.call(mates[i], spots[i])
	for i in foes.size():
		if i < fspots.size(): place.call(foes[i], fspots[i])
		else: foes[i].teleport(world.random_ground())
	for i in hunters.size():
		var h: Hunter = hunters[i]
		if h != player and i % 3 == 1: h.hp = h.max_hp * 0.45
		if h != player and i % 3 == 2: h.armor = h.max_armor * 0.5

func _hold_demo() -> void:
	var ks: Array = Hunter.HOLD_KINDS
	if not has_meta("hold_demo_done"):
		set_meta("hold_demo_done", true)
		var base: Vector3 = player.pos
		var i := 0
		for h in hunters:
			h.ctrl = "idle"; h.inp["move"] = Vector2.ZERO
			var col := i % 4; var row := i / 4
			var at := base + Vector3((col - 1.5) * 2.4, 0, row * 2.6)
			at = world.free_spot_near(at, [], 0.6, 0.5, 3.0)
			h.teleport(Vector3(at.x, world.ground_at(at.x, at.z), at.z))
			h.face = 0.0
			i += 1
		for mb in mobs: mb.dead = true; mb.visible = false
		cam.zoom_to = 0.62; cam.zoom = 0.62
	var j := 0
	for h in hunters:
		if j < ks.size():
			h.set_hold(String(ks[j]))
			h.pname = String(ks[j])
			h.inp["aim"] = h.pos + Vector3(0, 0.9, 3.0)
		j += 1
	cam.zoom_to = 0.62

func _update_pads(dt: float) -> void:
	for pd in world.pads:
		pd["cd"] = maxf(0.0, pd["cd"] - dt)
		for h in hunters:
			if h.out or h.downed or h.fly_t > 0.0 or h.pad.size() > 0 or h.remote or h.vel.y > 0.5:
				continue
			var p: Vector3 = pd["pos"]
			if Vector2(h.pos.x - p.x, h.pos.z - p.z).length() < 0.8 and h.pos.y - p.y < 0.4 and h.pos.y - p.y > -0.3:
				h.pad_launch(pd["land"])
				sfx("jump", h.pos, -2.0, 0.8)
				fx.burst(h.pos + Vector3(0, 0.3, 0), Color("8fe3c8"), 16, 5.0, 0.5, 2.0)
		for k in kins:
			if k.state == "active" and Vector2(k.pos.x - pd["pos"].x, k.pos.z - pd["pos"].z).length() < 0.7:
				k.state = "returning"

var _dex_t := 0.0
var _shimmer_told := {}

## Wild kin you get a look at go in the Field Book (FieldBook). A shimmer gets called out.
func _update_dex(dt: float) -> void:
	_dex_t -= dt
	if _dex_t > 0.0 or player == null or player.out or opts.get("autoplay", false):
		return
	_dex_t = 1.0
	FieldBook.scan_sights(self)          # a wild Boki in view goes in the Field Book, with where you saw it
	for k in kins:
		if k.is_wild() and not k.dead and player.flat_dist(k) < 11.0:
			if Mutations.special(k.rec) and not _shimmer_told.has(k.nid):
				_shimmer_told[k.nid] = true
				var rare := " ".join(Mutations.tags(k.rec))
				hud.toast(("A shimmering %s! Its colours are rare" % Data.KIN[k.species]["name"]) if Mutations.of(k.rec).is_empty() else "%s %s %s! A rare mutation" % ["An" if "AEIOU".contains(rare.substr(0, 1)) else "A", rare, Data.KIN[k.species]["name"]], Color("fff6c0"))
				sfx("unlock", k.pos, -6.0, 1.3)
				if k.rec.get("shimmer", false):
					Shiny.sparkle(self, k.pos, k.species, 1.2)      # stars and a chime round it

## A deathbox revive is loud: a rising hum (spatial, carrying ~HUM_RANGE metres, so rivals close by
## hear it) with a soft ray of light over the box, from the moment the channel starts until it
## breaks or completes. Rivals who hear it get a sound ping on the minimap; bots come to look.
const HUM_RANGE := 30.0
const HUM_DB := 2.0
var box_hums := {}             # hum key -> its box, while that box's revive hum is playing
var _hum_seq := 0
func _update_box_hums() -> void:
	for b in boxes:
		var on: bool = time - float(b.get("rev_at", -9.0)) < 0.12
		var key: String = String(b.get("hum_key", ""))
		if on:
			if key == "":
				_hum_seq += 1
				key = "boxhum%d" % _hum_seq
				b["hum_key"] = key
			var prog := clampf(float(b.get("rev_prog", 0.0)), 0.0, 1.0)
			if not box_hums.has(key):
				box_hums[key] = b
				Sfx.loop_start(key, "revive_hum", b["pos"], HUM_DB, HUM_RANGE)
				_box_ray(b, true)
			Sfx.loop_set(key, b["pos"], 0.8 + 0.55 * prog)
			_box_ray_tick(b, prog)
			if int(time * 2.0) != int((time - DT) * 2.0):
				note_sound(b.get("rev_by"), b["pos"], "revive")
		elif key != "" and box_hums.has(key):
			_box_hum_stop(b)

func _box_hum_stop(b: Dictionary) -> void:
	var key: String = String(b.get("hum_key", ""))
	if key != "":
		box_hums.erase(key)
		Sfx.loop_stop(key)
	_box_ray(b, false)

## The soft column of light and the ring on the ground over a box while it's being revived.
func _box_ray(b: Dictionary, on: bool) -> void:
	var n = b.get("ray_node")
	if on and (n == null or not is_instance_valid(n)):
		var root := Node3D.new()
		root.name = "BoxRay"
		add_child(root)
		root.position = b["pos"]
		var col := MeshInstance3D.new()
		col.mesh = Models.cyl(0.55, 0.85, 7.0, 20)
		col.position = Vector3(0, 3.5, 0)
		col.material_override = Models.glow_mat(Color(0.62, 1.0, 0.7, 0.18))
		col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		col.name = "Col"
		root.add_child(col)
		var ring := MeshInstance3D.new()
		ring.mesh = Models.cyl(1.6, 1.6, 0.04, 32)
		ring.position = Vector3(0, 0.06, 0)
		ring.material_override = Models.glow_mat(Color(0.62, 1.0, 0.7, 0.3))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.name = "Ring"
		root.add_child(ring)
		b["ray_node"] = root
	elif not on and n != null and is_instance_valid(n):
		(n as Node).queue_free()
		b.erase("ray_node")

func _box_ray_tick(b: Dictionary, prog: float) -> void:
	var n = b.get("ray_node")
	if n == null or not is_instance_valid(n):
		return
	var pulse := 0.5 + 0.5 * sin(time * (5.0 + prog * 7.0))
	var col: MeshInstance3D = (n as Node3D).get_node("Col")
	var ring: MeshInstance3D = (n as Node3D).get_node("Ring")
	(col.material_override as ShaderMaterial).set_shader_parameter("color", Color(0.62, 1.0, 0.7, 0.1 + 0.16 * prog + 0.06 * pulse))
	col.scale = Vector3(1.0 + 0.15 * pulse, 0.6 + 0.4 * prog, 1.0 + 0.15 * pulse)
	col.position.y = 3.5 * col.scale.y
	var rs := 1.0 - 0.55 * prog
	ring.scale = Vector3(rs, 1.0, rs)
	(ring.material_override as ShaderMaterial).set_shader_parameter("color", Color(0.62, 1.0, 0.7, 0.25 + 0.3 * pulse))

func _update_interact(dt: float) -> void:
	for h in hunters:
		if h.out or h.extracted or h.downed or h.dropping:
			continue
		if not h.stomp.is_empty():
			if h == player:
				var so: Hunter = h.stomp["o"]
				interact = {"kind": "stomping", "label": "Stomping %s  ·  locked in" % so.pname, "col": Color("ff8a6a")}
			continue
		var want: bool = h.inp.get("interact", false)
		if not want:
			h.swap_hold = false
		var best := {}
		# 1. wisps, as in Supervive: standing on a downed teammate revives them and standing on a
		# downed enemy stomps them (both in Life.tick_wisps); holding interact executes them
		for o in hunters:
			if o == h or not o.downed or o.out or h.flat_dist(o) > Life.R["revive_radius"]:
				continue
			if o.team == h.team:
				if o.remote:
					_rev_out[o.nid] = float(_rev_out.get(o.nid, 0.0)) + dt / Life.R["revive_time"]
					o.revive += dt / Life.R["revive_time"]
				if h == player and best.is_empty():
					# your own revive bar, so you know it's working (and when it's blocked)
					if o.get_meta("stomped", false):
						best = {"kind": "revive", "ent": o, "label": "An enemy is standing on %s: revive blocked. Knock them off!" % o.pname, "col": Color("ff6a5a")}
					else:
						best = {"kind": "revive", "ent": o, "label": "Reviving %s  ·  stay in the ring" % o.pname, "col": Color("9ee2a0")}
			elif not o.remote:
				best = {"kind": "finish", "ent": o, "label": "Hold %s to stomp %s  (you'll be locked in)" % [Settings.key_cap("interact"), o.pname], "col": Color("ff8a6a")}
		if not want or best.get("kind", "") != "finish":
			h.finish_t = 0.0
		# 1b. deathboxes: bring a teammate back while their soul is there, or take everything
		if best.is_empty():
			for b in boxes:
				if h.flat_dist(b["pos"]) > 1.5 or absf(h.pos.y - float(b["pos"].y)) > 1.4:
					continue
				var o: Hunter = b["owner"]
				if o.team == h.team and o != h and Life.soul_here(self, b) and not o.remote:
					best = {"kind": "boxrev", "box": b, "label": BoxRevive.prompt(h, o), "col": Color("9ee2a0")}
					break
				if not b["empty"]:
					var whose: String = "your box" if o == h else o.pname + "'s box"
					var open_now: bool = h == player and hud != null and hud.loot_is(b)
					var lt := ("Press %s again to smart loot  ·  click items to take them" % Settings.key_cap("interact")) if open_now else ("Press %s to open %s  ·  twice to smart loot" % [Settings.key_cap("interact"), whose])
					best = {"kind": "loot", "box": b, "label": lt if h == player else "Hold %s to loot %s" % [Settings.key_cap("interact"), whose], "col": Life.box_color(b)}
					break
		if best.get("kind", "") not in ["boxrev", "loot"] or not want:
			h.box_t = 0.0
		if not want:
			h.set_meta("loot_hold", false)
			h.set_meta("box_broke", false)
			if h != player:              # nobody reads a bot's prompt: skip the scans (40 hunters)
				if exits: exits.let_go(h)
				continue
		# 2. scan a knocked-out wild kin (Capture; not in training: practice kin go home with nobody)
		if best.is_empty() and not opts.get("training", false):
			for k in kins:
				if KinLoss.scannable_by(h, k) and h.flat_dist(k) < float(Capture.rules()["range"]):
					best = {"kind": "catch", "ent": k, "label": CaptureHud.prompt(h, k)}
					break
		# 3. wear gear lying on the ground (tunings are taken by walking over them)
		if best.is_empty():
			var bd := 1.5
			for wp in wpicks:
				var d: float = h.flat_dist(wp["pos"])
				if d < bd and absf(h.pos.y - float(wp["pos"].y)) < 1.2 and wp.has("gear"):
					bd = d
					best = {"kind": "weapon", "wp": wp, "label": _pickup_label(h, wp), "col": Loot.col_of(Pack.ground_item(wp))}
				elif d < bd and absf(h.pos.y - float(wp["pos"].y)) < 1.2 and wp.has("val") and h == player:
					bd = d
					best = {"kind": "weapon", "wp": wp, "label": _pickup_label(h, wp), "col": Loot.col_of(Pack.ground_item(wp))}
		# 4. open a chest
		if best.is_empty():
			for c in chests:
				if not c["open"] and h.flat_dist(c["pos"]) < 1.6:
					best = KeyChest.prompt(h, c)
					break
		# 4. pray at a shrine
		if best.is_empty():
			for sh in shrines:
				if not sh["used"] and h.flat_dist(sh["pos"]) < 1.8:
					best = {"kind": "shrine", "shrine": sh, "label": "Hold " + Settings.key_cap("interact") + " to pray: heal, a blessing and a perk"}
					break
		# 5. the exits: call a skiff, unlock a hatch, start an uplink
		if exits:
			# (using an exit beats picking up a weapon or opening a chest that happens to be there)
			var ex := exits.interact_for(h)
			if best.is_empty() or (ex.has("act") and String(best.get("kind", "")) in ["weapon", "chest", "locked", "shrine"]): best = ex
		# 6. the lairs: work a gate's dial, light a rune
		if lairs:
			var lx := lairs.interact_for(h)
			if not lx.is_empty() and (best.is_empty() or not String(best.get("kind", "")) in ["revive", "finish", "boxrev", "loot", "catch", "exit"]): best = lx
		if h == player:
			interact = best
		if best.is_empty() or not want:
			continue
		match best["kind"]:
			"weapon":
				if not h.swap_hold:
					h.swap_hold = true
					if h == player and not opts.get("training", false):
						Pack.take_ground(self, h, best["wp"])
					else:
						take_pick(h, best["wp"])
			"finish":
				# a short hold commits you to the stomp (Life.start_stomp): no cancelling after that
				var o: Hunter = best["ent"]
				h.set_hold("windup")
				h.finish_t += dt
				if h.finish_t >= Life.R["stomp_commit"]:
					Life.start_stomp(self, h, o)
			"loot" when h == player and hud:
				# press to open the box's loot window; press again (with it open) to smart loot
				if not bool(h.get_meta("loot_hold", false)):
					h.set_meta("loot_hold", true)
					var b0: Dictionary = best["box"]
					if hud.loot_is(b0):
						var got := LootFull.smart(self, h, b0)
						if b0["empty"] or got > 0: hud.close_loot()
					else:
						hud.open_loot(b0)
			"boxrev":
				BoxRevive.hold(self, h, best["box"], dt)
			"loot":
				h.set_hold("loot")
				h.box_t = 0.0 if time - h.hurt_at < 0.1 else h.box_t + dt     # a hit starts the loot over
				if h.box_t >= Life.R["loot_time"]:
					h.box_t = 0.0
					Life.loot_box(self, h, best["box"])
			"catch":
				Capture.hold(self, h, best["ent"], dt)
			"chest":
				var c: Dictionary = best["chest"]
				h.set_hold("chest")
				c["prog"] += dt / float(ChestLoot.R()["hold_s"])
				if c["prog"] >= 1.0:
					_open_chest(h, c)
			"locked":
				KeyChest.deny(self, h, best["chest"])
			"shrine":
				var sh: Dictionary = best["shrine"]
				h.set_hold("shrine")
				sh["prog"] += dt / 1.2
				if sh["prog"] >= 1.0:
					_use_shrine(h, sh)
			"exit":
				var xa := String(best.get("act", ""))
				if xa in ["call", "start"]: h.set_hold("console")
				elif xa in ["open", "enter"]: h.set_hold("key")
				exits.hold(h, best, dt)
			"lair":
				if String(best.get("what", "")) == "rune": h.set_hold("rune")
				lairs.hold(h, best, dt)

func _catch(h: Hunter, k: Kin) -> void:
	if opts.get("training", false):
		return
	if net_on and not is_host:
		if k.catch_prog < 5.0:
			k.catch_prog = 5.0
			net_event(["catch", k.nid, h.nid])
		return
	k.dead = true
	k.visible = false
	var rec: Dictionary = k.rec.duplicate(true)
	rec["caught_at"] = where_at(k.pos)       # provenance: where it was caught (Save.register)
	if k.lost_from != "":
		# someone's lost kin: it keeps who it is, and we remember who has it now
		rec["lost_from"] = k.lost_from
		rec["prev_trust"] = float(k.rec.get("trust", 50.0))
		for L in player_lost:
			if L["kin"] == k: L["holder"] = h
		if k.lost_from == "you" and h == player:
			add_feed("You got %s back! Extract to bring it home." % rec.get("name", "your Boki"))
		elif k.lost_owner is Hunter and (k.lost_owner as Hunter).team != h.team:
			h.stolen_carry = true
			if k.lost_from == "you":
				kin_stolen(h, rec)
	else:
		rec["trust"] = 20.0
		rec["memory"] = []
	h.caught.append(rec)
	if net_on:
		net_event(["caught", k.nid, h.nid, rec, (k.lost_owner as Hunter).nid if k.lost_owner is Hunter else ""])
	KinTrack.on_caught(self, h, k, rec)
	if h == player:
		add_feed("%s is in your box (%d/%d). Extract to bring it home." % [Data.KIN[k.species]["name"], h.caught.size(), Capture.box_cap()])
		if player.kin and player.kin.state != "downed":
			BokiChatter.say(self, player.kin, "caught")

func _open_chest(h: Hunter, c: Dictionary, from_net := false) -> void:
	if c["open"] or (not from_net and not KeyChest.spend(h, c)):
		return      # (opening costs exactly one key; another game's open already paid in that game)
	c["open"] = true
	if blight: blight.noise(c["pos"], "chest", h)      # a chest lid is loud
	if h: h.add_stat("chests")
	if net_on and not from_net:
		net_event(["chest", chests.find(c), h.nid if h else ""])
	ChestLoot.open(self, h, c, from_net)

func _use_shrine(h: Hunter, sh: Dictionary, from_net := false) -> void:
	if sh["used"]:
		return
	sh["used"] = true
	if net_on and not from_net:
		net_event(["shr", shrines.find(sh), h.nid if h else ""])
	var n: Node3D = sh["node"]
	n.get_node("Crystal").visible = false
	n.get_node("Ring").visible = false
	sfx("heal", sh["pos"], 0.0, 1.2)
	fx.burst(sh["pos"] + Vector3(0, 1.6, 0), Color("8fe3c8"), 30, 5.0, 0.8, -2.0)
	fx.ring(sh["pos"], 4.0, Color("8fe3c8"), 0.5)
	if h and not h.remote:
		h.hp = h.max_hp
		h.bless_t = 20.0
		if h.kin and not h.kin.dead:
			h.kin.hp = h.kin.max_hp
		if h == player:
			hud.toast("Healed and blessed: +25% damage for 20s", Color("8fe3c8"))
		PerkOrbs.drop(self, "shrine", sh["pos"], 0, h)      # one or two perk orbs by the shrine

## Midway through, the Warden wakes on the heart island and guards it until someone brings it down.
# ---- training area
## [id, what to do, the action whose key it uses ("" for none)]
const TRAIN := [["move", "Walk around", "up"], ["dash", "Dash", "dash"], ["glide", "Jump, then hold Mouse 5 or Space in the air to glide", "jump"],
	["shoot", "Shoot a target dummy", "fire"], ["ability", "Use your E ability", "signature"], ["ult", "Fuse with your Boki (%s: open from the start here)", "ultimate"],
	["secondary", "Use your right click", "secondary"], ["glove", "Use your glove (pick one up from the rack first)", "gear1"],
	["crouch", "Sneak: slower, steadier aim, harder to spot", "crouch"],
	["throw", "Sic your Boki at a dummy", "throw"], ["combo", "Land a combo: shoot a foe your Boki just stunned or rooted", "fire"], ["tonic", "Heal with a tonic (belt slot 1)", "util1"],
	["stagger", "Stagger a big dummy: hit it with an ability while it has a purple ring", "signature"],
	["smash", "Break a crate or pot", "fire"], ["weapon", "Take a found weapon off the ground", "interact"],
	["ledge", "Dash off an edge and float back up", ""]]
var train := {}
var train_t := 0.0

var duel_pad := Vector3.INF

## The Demo match's landing grace: for the first fresh_t seconds after you land (Bot.fresh), until you
## hurt something yourself, nothing targets you (bots, even ones your Boki picked a fight with, and
## camp monsters) and stray hits from others' fights do no harm. Only in the Demo match.
var player_engaged := false
func demo_shielded(e: Ent) -> bool:
	return e != null and e == player and bool(opts.get("demo_match", false)) and not player_engaged and Bot.fresh(self, e)

## The Demo match (title screen): a real Duos expedition set up for filming. A fixed map roll, clear
## weather, no Blight, normal rivals (who leave you be for a minute after you land), on the Dusk Isles (the first tier where a Boki can be lost: one in
## a deathbox goes to whoever loots it); your bot squadmate leads the drop to land you between a live boss
## lair and an outpost uplink (_demo_drop). It plays on your save like any expedition (what you bring
## can be lost, what you extract is kept).
const DEMO_SEED := 5
static func demo_opts() -> Dictionary:
	return {"teams": Data.MATCH_PLAYERS / 2, "squad": 2, "total": Data.MATCH_PLAYERS, "tier": 1, "seed": DEMO_SEED,
		"raid": "clear", "blight": false, "fresh_t": Settings.DEMO_FRESH_T, "demo_match": true,
		"live_lair": "The Thornhive"}     # (the Hollow Crown: the Thornhive and Thornwood's uplink share an island)

## The Arena: a compact practice map with dummies, a sparring bot and the kit card (scripts/match/arena.gd).
static func arena_opts(arch_id := "") -> Dictionary:
	var o := {"arena": true, "training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 6262, "no_drop": true}
	if Arch.exists(arch_id):
		o["arch"] = arch_id; o["cls"] = Arch.weight(arch_id); o["weapon"] = Arch.signature(arch_id)
	return o

## The training pad that takes you to the duel room.
static func duel_opts() -> Dictionary:
	return {"training": true, "duel": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 5151, "no_drop": true}

func _update_training(dt: float) -> void:
	if player == null:
		return
	if duel_pad != Vector3.INF and player.flat_dist(duel_pad) < 1.3 and not player.downed:
		if Input.is_action_just_pressed("interact") and not paused:
			Game.start_match(duel_opts())
			return
	train_t += dt
	if player.downed and train_t > 2.0:
		revive_hunter(player, null)
	if opts.get("arena", false):
		return        # the Arena runs its own (scripts/match/arena.gd)
	var was_ult: bool = train.get("_ult_full", false)
	# everything recharges quickly here
	player.ult = minf(1.0, player.ult + dt / 6.0)
	player.sig_cd = maxf(0.0, player.sig_cd - dt * 2.0)
	for kk in [player.kin, player.kin2]:
		if kk: (kk as Kin).runner.tick(dt * 2.0)
	if player.tonics < 1: player.tonics = 3
	if not train.has("tonic") and player.hp >= player.max_hp and train_t > 1.0:
		player.hp = player.max_hp * 0.7     # a scratch, so the tonic has something to heal
	if player.inp["move"].length() > 0.1:
		train["_moved"] = float(train.get("_moved", 0.0)) + Vector2(player.pos.x - player.prev.x, player.pos.z - player.prev.z).length()
	var marks := {
		"move": float(train.get("_moved", 0.0)) > 4.0,
		"dash": player.roll_t > 0.0,
		"glide": player.gliding and not player.dropping,
		"shoot": player.dmg_done > 0.0,
		"ability": (player.ak != null and float(player.ak.cd["e"]) > 0.0) or (player.ak == null and player.kin != null and (player.kin as Kin).runner.has_slot("k1") and not (player.kin as Kin).runner.is_ready("k1")),
		"glove": float(player.gear_cd[0]) > 0.0,
		"combo": int(player.stats.get("combos", 0)) > 0,
		"crouch": player.crouch,
		"secondary": (player.ak != null and player.ak.last_variant != "") or (player.runner != null and player.runner.has_slot("utility") and not player.runner.is_ready("utility")),
		"ult": (player.ak != null and float(player.ak.cd["r"]) > 0.0) or (was_ult and player.ult < 0.5),
		"throw": player.kin != null and player.kin.st_throws > 0,
		"tonic": player.tonics < int(train.get("_tonics", player.tonics)),
		"ledge": player.grap.size() > 0 or player.mantle_k() > 0.0,
		"smash": train.get("_smash", false),
		"stagger": train.get("_stagger", false),
		"weapon": train.get("_weapon", false),
	}
	train["_ult_full"] = player.ult >= 0.99
	train["_tonics"] = player.tonics
	for k in marks:
		if marks[k] and not train.has(k):
			train[k] = true
			Sfx.play("unlock", null, -8.0)
			var left := train_rows().filter(func(t): return not train.has(t[0])).size()
			if hud: hud.toast(("Done: %s" % _train_label(k)) if left > 0 else "Training complete. Press Esc to head home whenever you like", Color("8ff0a0"))
			if left == 0:
				Save.d["tutorial"]["training"] = true
	# keep a few target dummies around you
	var alive := mobs.filter(func(x): return not x.dead)
	if alive.size() < 4 and int(train_t * 10.0) % 20 == 0:
		var at := world.random_ground(world.island_of(player.pos.x, player.pos.z))
		if Vector2(at.x - player.pos.x, at.z - player.pos.z).length() > 3.0:
			spawn_mob(["skitter", "spitter", "brute", "sentinel"][randi() % 4], at)

## The checklist for this hero: the secondary step only shows for heroes that have one.
func train_rows() -> Array:
	var rows := TRAIN.filter(func(t): return t[0] != "secondary" or (player != null and (player.ak != null or (player.runner != null and player.runner.has_slot("utility")))))
	return rows.map(func(t): return [t[0], _train_text(t), t[2]])

func _train_text(t: Array) -> String:
	return String(t[1]) % Settings.key_cap(String(t[2])) if String(t[1]).contains("%s") else String(t[1])

func _train_label(k: String) -> String:
	for t in TRAIN:
		if t[0] == k: return _train_text(t)
	return k

## Test hook (--balloon-demo=lip|glide|hop|self): hit markers. "lip" hangs a foe and a squadmate
## below an island's lip (balloons) and you shoot the foe's; "glide" holds them high over land
## (rings) and you shoot the low one through its ring; "hop" holds them mid-hop (no marker: the
## body is the target); "self" hangs you below the lip (your own faint balloon).
var _bdemo := {}
func _balloon_demo() -> void:
	var mode := String(opts["balloon_demo"])
	var foe: Hunter = null; var mate: Hunter = null
	for h in hunters:
		if h == player: continue
		if h.team != player.team and foe == null: foe = h
		elif h.team == player.team and mate == null: mate = h
	if _bdemo.is_empty():
		for mb in mobs: mb.queue_free()
		mobs.clear()
		for h in hunters:
			if h != player: h.ctrl = "idle"
		cam.zoom_to = 0.8
		# an island edge with open air beyond it, and a flat stretch of ground behind it
		for k in 4000:
			var g := world.random_ground()
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				var ok := not world.is_void(g.x, g.z)
				for dd in [1.6, 2.4, 3.2, 4.0]:
					for sd in [-2.0, 0.0, 2.0]:
						if not world.is_void(g.x + d.x * dd + d.y * sd, g.z + d.y * dd + d.x * sd): ok = false
				for dd in [0.0, -1.5, -3.0, -4.5]:
					for sd in [-3.0, 0.0, 3.0]:
						var x: float = g.x + d.x * dd + d.y * sd; var z: float = g.z + d.y * dd + d.x * sd
						if world.is_void(x, z) or world.is_block(x, z) or absf(world.ground_at(x, z) - g.y) > 0.05: ok = false
				if ok:
					var ex := g.x; var ez := g.z
					while not world.is_void(ex + d.x * 0.25, ez + d.y * 0.25):
						ex += d.x * 0.25; ez += d.y * 0.25
					_bdemo = {"edge": Vector3(ex, g.y, ez), "dir": d}
					break
			if not _bdemo.is_empty(): break
		if _bdemo.is_empty():
			push_warning("balloon demo: no edge found"); _bdemo = {"edge": player.pos, "dir": Vector2(1, 0)}
		for h in hunters:
			if h != player and h != foe and h != mate: h.teleport(world.random_ground())
	var e: Vector3 = _bdemo["edge"]; var d: Vector2 = _bdemo["dir"]
	var side := Vector2(-d.y, d.x)
	var hold := func(h: Hunter, p: Vector3, glide: bool) -> void:
		if h == null: return
		h.teleport(p); h.vel = Vector3.ZERO; h.grounded = false; h.pad = {}
		h.gliding = glide; h.inp["glide"] = glide; h.glide_fuel = 1.0; h.glide_cd = 0.0
		h.hp = h.max_hp; h.stun_t = 0.0; h.knock_t = 0.0; h.shot_down = false
	var stand := func(h: Hunter, p: Vector3) -> void:
		if h == null: return
		h.teleport(p); h.vel = Vector3.ZERO; h.grounded = true
		h.hp = h.max_hp
	var on := func(back: float, sd: float) -> Vector3:
		var x := e.x - d.x * back + side.x * sd; var z := e.z - d.y * back + side.y * sd
		return Vector3(x, world.ground_at(x, z), z)
	var shoot := false
	match mode:
		"lip":
			stand.call(player, on.call(2.2, 0.0))
			hold.call(foe, Vector3(e.x + d.x * 1.3 + side.x * 1.4, e.y - 2.6, e.z + d.y * 1.3 + side.y * 1.4), true)
			hold.call(mate, Vector3(e.x + d.x * 1.5 - side.x * 2.0, e.y - 2.0, e.z + d.y * 1.5 - side.y * 2.0), true)
			shoot = true
		"glide":
			stand.call(player, on.call(4.0, 0.0))
			hold.call(foe, on.call(1.6, 1.6) + Vector3(0, 2.3, 0), true)
			hold.call(mate, on.call(2.6, -2.4) + Vector3(0, 4.0, 0), true)
			shoot = true
		"hop":
			stand.call(player, on.call(4.0, 0.0))
			hold.call(foe, on.call(1.6, 1.6) + Vector3(0, 0.9, 0), false)
			hold.call(mate, on.call(2.6, -2.4) + Vector3(0, 1.1, 0), false)
			shoot = true
		"self":
			hold.call(player, Vector3(e.x + d.x * 1.3, e.y - 2.4, e.z + d.y * 1.3), true)
			stand.call(mate, on.call(1.5, 1.5))
			stand.call(foe, on.call(3.5, -2.0))
	if shoot and foe:
		# fire level along the island at the foe's marker (or body, mid-hop)
		var fy: float = shot_stance_y(foe)
		player.inp["aim"] = Vector3(foe.pos.x, fy + 0.95, foe.pos.z)
		player.inp["aim_y"] = player.pos.y
		player.inp["fire"] = fmod(time, 0.9) < 0.12
		player.inp["move"] = Vector2.ZERO
		player.ammo = maxi(player.ammo, 3)

## Test hook (--train-demo): ride the sky train from a stop; "--train-demo=track" stands you on the
## track ahead of the engine instead, "--train-demo=view" watches it from a pier. "walk" and "hit"
## start with the train already under way: "walk" stands you on a car and walks, strafes, jumps and
## shoots on it; "hit" stands you on the rails a couple of seconds ahead of the engine.
func _train_demo() -> void:
	var mode := String(opts["train_demo"]) if opts["train_demo"] is String else "ride"
	var st := skytrain
	if time < DT * 1.5 and mode in ["walk", "hit"]:
		var lg: Dictionary = st.legs[0]
		time = st.dwell + float(lg["t"]) * 0.3
		opts["train_t0"] = time
		st.tick(0.0)
		st.old = st.cur.duplicate()
	var since: float = time - float(opts.get("train_t0", 0.0))
	if not opts.has("train_init") and mode != "watch":
		opts["train_init"] = true
		cam.zoom_to = 0.8
		if mode == "track" or mode == "hit":
			# a stretch of open track ahead, level with the islands (not down under a bridge)
			var ps := st.head_s + 20.0
			if mode == "hit":
				# just a couple of seconds down the line, wherever the rails are level with the islands
				# open air round the rails somewhere ahead, then the clock moved on until the engine is
				# a couple of seconds away from it
				ps = st.head_s + 14.0
				while ps < st.head_s + st.loop_len and not (world.train_at(ps).y > -0.01 and _open_air(world.train_at(ps), 4.0)):
					ps += 1.0
				var t1 := time
				while time < t1 + 120.0 and not (st.head_v > st.speed * 0.8 and fposmod(ps - st.head_s, st.loop_len) < 11.0):
					time += 0.05
					st._place(time)
				st.old = st.cur.duplicate()
			while mode == "track" and ps < st.head_s + 120.0 and not (world.train_at(ps).y > -0.01 and world.train_at(ps - 6.0).y > -0.01 and world.is_void(world.train_at(ps).x, world.train_at(ps).z)):
				ps += 1.0
			opts["train_pin"] = world.train_at(ps)
			player.teleport(opts["train_pin"])
		elif mode == "view":
			var t: Transform3D = st.cur[2]
			player.teleport(world.free_spot_near(t.origin - t.basis.x * 4.0, [], 1.0, 0.4, 6.0))
		else:
			var t2: Transform3D = st.cur[2]
			player.teleport(t2.origin + Vector3(0, 0.05, 0))
		player.grounded = true
	if (mode == "track" or mode == "hit") and not player.downed and not player.out:
		# stand on the rails (pinned there: the track has no floor of its own) and wait for the engine
		player.pos = opts["train_pin"]; player.vel = Vector3.ZERO; player.grounded = true
		player.inp["move"] = Vector2.ZERO
		player.lives = 1
	if mode == "walk" and not player.out:
		# forward along the car, across it, a hop, then shooting from the deck
		var k := 2
		var tk: Transform3D = st.cur[k]
		var f2 := Vector2(-tk.basis.z.x, -tk.basis.z.z).normalized()
		var r2 := Vector2(tk.basis.x.x, tk.basis.x.z).normalized()
		player.inp["move"] = Vector2.ZERO
		if since > 0.4 and since < 1.0: player.inp["move"] = f2
		elif since > 1.0 and since < 1.5: player.inp["move"] = r2
		elif since > 1.5 and since < 2.3: player.inp["move"] = -f2
		if absf(since - 2.4) < DT * 0.5: player.inp["jump"] = true
		if since > 2.9:
			player.inp["aim"] = player.pos + Vector3(r2.x * 6.0, 0.9, r2.y * 6.0)
			player.inp["fire"] = fmod(since, 0.5) < 0.1
			player.ammo = maxi(player.ammo, 3)
	if int(time * 60.0) % 60 == 0:
		var t3: Transform3D = st.cur[2]
		print("TRAIN t=%.1f head=%.1f v=%.1f player=(%.1f,%.2f,%.1f) car2=(%.1f,%.2f,%.1f) grounded=%d hp=%.0f downed=%d out=%d" % [time, st.head_s, st.head_v, player.pos.x, player.pos.y, player.pos.z, t3.origin.x, t3.origin.y, t3.origin.z, int(player.grounded), player.hp, int(player.downed), int(player.out)])

## Nothing but air within `rad` of p (for the demos).
func _open_air(p: Vector3, rad: float) -> bool:
	for i in 12:
		var a := TAU * i / 12.0
		for d in [rad * 0.5, rad]:
			if not world.is_void(p.x + cos(a) * d, p.z + sin(a) * d):
				return false
	return true

# ------------------------------------------------------------------ hero zones
func add_zone(kind_s: String, at: Vector3, radius: float, dur: float, team_i: int, owner: Hunter, from_net := false) -> void:
	var col: Color = owner.accent() if owner else Color.WHITE
	var n := Node3D.new()
	add_child(n)
	n.position = at
	match kind_s:
		"dome":
			var mi := MeshInstance3D.new(); mi.mesh = Models.sphere(radius, 24)
			mi.material_override = Models.glow_mat(Color(col, 0.16))
			mi.scale = Vector3(1, 0.75, 1)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.add_child(mi)
		"sanctuary", "well":
			var ring := MeshInstance3D.new(); ring.mesh = Models.flat_quad(radius * 2.0)
			ring.material_override = Models.ring_mat(Color(col if kind_s == "sanctuary" else Color("b06ae0"), 0.9), 0.06)
			ring.position.y = 0.08
			n.add_child(ring)
	zones.append({"kind": kind_s, "pos": at, "r": radius, "t": 0.0, "dur": dur, "team": team_i, "owner": owner, "node": n, "tick": 0.0})
	if kind_s == "well":
		sfx("warn", at, -2.0, 1.4)
	if net_on and not from_net and owner:
		net_event(["zone", kind_s, _r(at.x), _r(at.y), _r(at.z), radius, dur, team_i, owner.nid])

func _dome_blocks(s: Dictionary, p: Vector3) -> bool:
	for z in zones:
		if z["kind"] != "dome" or z["team"] == s["team"]:
			continue
		var c: Vector3 = z["pos"]
		if Vector2(p.x - c.x, p.z - c.z).length() < z["r"] and Vector2(s["start"].x - c.x, s["start"].z - c.z).length() > z["r"]:
			fx.burst(p, Color(Color("f2d47a"), 0.8), 6, 2.0, 0.25, 0.0, 0.7)
			if z.has("hp"):
				# a Bastion's ring soaks shots until its health runs out
				z["hp"] = float(z["hp"]) - float(s["dmg"])
				var ow: Hunter = z.get("owner")
				if ow and is_instance_valid(ow) and ow.ak: ow.ak.on_block(float(s["dmg"]), s.get("by"))
				if float(z["hp"]) <= 0.0: z["dur"] = minf(float(z["dur"]), float(z["t"]) + 0.1)
			return true
	return false

func _update_zones(dt: float) -> void:
	for z in zones.duplicate():
		z["t"] += dt
		z["tick"] -= dt
		var n: Node3D = z["node"]
		var k: float = z["t"] / z["dur"]
		n.scale = Vector3.ONE * minf(1.0, z["t"] * 6.0) * (1.0 if k < 0.9 else (1.0 - k) * 10.0)
		var owner: Hunter = z["owner"]
		var mine: bool = owner != null and not owner.remote
		var c: Vector3 = z["pos"]
		if z["tick"] <= 0.0:
			z["tick"] = 0.25
			match String(z["kind"]):
				"sanctuary", "dome":
					# heal your own hunter and kin when standing inside a friendly area
					var amt := 12.0 * 0.25 if z["kind"] == "sanctuary" else 0.0
					if amt > 0.0:
						for h in hunters:
							if h.team == z["team"] and not h.remote and not h.downed and not h.out and h.flat_dist(c) < z["r"]:
								h.hp = minf(h.max_hp, h.hp + amt)
								if h.kin and h.kin.state == "active" and h.kin.flat_dist(c) < z["r"]:
									h.kin.hp = minf(h.kin.max_hp, h.kin.hp + amt)
						if z["kind"] == "sanctuary":
							fx.burst(c + Vector3(randf_range(-2, 2), 0.3, randf_range(-2, 2)), Color("9ee2a0"), 3, 1.5, 0.6, -2.0, 0.8)
				"well":
					fx.burst(c + Vector3(0, 0.5, 0), Color("b06ae0"), 8, -3.0, 0.4, 0.0, 0.8)
					if mine:
						for f in foes_of(z["team"]):
							var rel := Vector2(c.x - f.pos.x, c.z - f.pos.z)
							if rel.length() < z["r"] and rel.length() > 0.4:
								f.hurt(1.0, owner, {"kb": rel.normalized() * 4.5, "slow": 0.5, "src": "abil"})
		if z["t"] >= z["dur"]:
			if z["kind"] == "well" and mine:
				Abil._blast(owner, c, z["r"] * 0.6, 26.0, 7.0, Color("b06ae0"), 5.0)
			n.queue_free()
			zones.erase(z)

func _update_events() -> void:
	if opts.get("tutorial", false) or opts.get("training", false):
		return
	_update_meteors()
	if not glimmer_done and time > at_sess(0.5) and (not net_on or is_host):
		glimmer_done = true
		_spawn_glimmer()
	if warden_done or time < at_sess(0.4) or world.heart_spot == Vector3.INF:
		return
	warden_done = true
	if not net_on or is_host:
		var w := spawn_mob("warden", world.heart_spot + Vector3(0, 0, 1.5))
		w.st = "idle"
		if opts.get("watch_heart", false) and player:
			var wp := world.heart_spot + Vector3(0, 0, 5.0)
			player.teleport(Vector3(wp.x, world.ground_at(wp.x, wp.z), wp.z))
	sfx("warn", null, 0.0, 0.6)
	ping(world.heart_spot, Color("c9a0ff"))
	if player and not player.out:
		add_feed("The Watcher has woken on the center island")
		hud.toast("The Watcher wakes", Color("c9a0ff"))

# ---- mid-match events
## A meteor shower partway through: falling stars hit the ground where hunters are, knock them
## around and leave gems behind.
func _update_meteors() -> void:
	var dt := DT
	for mt in meteors.duplicate():
		mt["t"] = float(mt["t"]) - dt
		fx.telegraph_progress(mt["tele"], 1.0 - float(mt["t"]) / 1.5)
		if float(mt["t"]) <= 0.0:
			meteors.erase(mt)
			fx.end_telegraph(mt["tele"])
			_meteor_hit(mt["at"])
	if not big or (net_on and not is_host):
		return
	if meteor_at < 0.0 or (rolling and time > meteor_end + 1.0 and meteor_end > 0.0):
		if rolling:
			# a rolling session has a shower every few minutes: fresh gems for the late arrivals too
			meteor_at = rolling.next_meteor(maxf(time, meteor_end))
		else:
			meteor_at = length * 0.24 if not opts.get("meteor_test", false) else 1.5
		meteor_end = meteor_at + 16.0
	if time < meteor_at or time > meteor_end:
		return
	if time - dt < meteor_at:
		if rolling: rolling.stats["meteors"] += 1
		_announce("A meteor shower is coming down. Stars leave gems where they land", Color("ffcf8a"))
		if net_on: net_event(["anc", "meteor", 0, 0, 0])
	meteor_next -= dt
	if meteor_next > 0.0:
		return
	meteor_next = 0.35
	var alive: Array = []
	for h in hunters:
		if not h.out and not h.extracted and not h.riding: alive.append(h)
	if alive.is_empty():
		return
	var h: Hunter = alive[rng.randi() % alive.size()]
	for _t in 10:
		var a := rng.randf() * TAU
		var q := h.pos + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 7.0)
		if not world.is_void(q.x, q.z) and not world.is_block(q.x, q.z):
			var at := Vector3(q.x, world.ground_at(q.x, q.z), q.z)
			_meteor_start(at)
			if net_on: net_event(["met", _r(at.x), _r(at.y), _r(at.z)])
			break

func _meteor_start(at: Vector3) -> void:
	meteors.append({"at": at, "t": 1.5, "tele": fx.telegraph_circle(at, 1.7, Color("ffb04a"))})

func _meteor_hit(at: Vector3) -> void:
	fx.bolt(at + Vector3(2.5, 14.0, -3.0), at, Color("ffd9a0"))
	fx.ring(at, 1.7, Color("ffb070"), 0.3)
	fx.burst(at + Vector3(0, 0.3, 0), Color("ffcf8a"), 22, 6.0, 0.5, 6.0, 1.2)
	fx.dust(at, 10)
	sfx("boom", at, -3.0, 1.3)
	Shake.incoming_big(self, at, 0.35)
	for e in hunters + mobs + kins:
		if e.remote or not e.hittable() or (e is Hunter and (e as Hunter).riding):
			continue
		var to := Vector2(e.pos.x - at.x, e.pos.z - at.z)
		if to.length() < 1.7 + e.r and absf(e.pos.y - at.y) < 1.6:
			e.hurt(14.0, null, {"src": "boom", "kb": to.normalized() * 6.0, "lift": 5.0})
	if not net_on or is_host:
		for b in breaks:
			if not b["dead"] and Vector2(b["pos"].x - at.x, b["pos"].z - at.z).length() < 1.9:
				brk.hit(b, null)
	if rng.randf() < 0.6:
		drop("gem", at + Vector3(0, 0.6, 0), maxi(1, int(round(3 * float(T["loot"])))))

func _announce(text: String, col: Color) -> void:
	sfx("warn", null, -2.0, 0.8)
	add_feed(text)
	if hud and player and not player.out:
		hud.toast(text, col)

## A treasure kin appears on a random outer island and runs. Bring it down for a pile of gems
## and a good weapon before it slips away.
func _spawn_glimmer() -> void:
	if world.islands.size() < 2:
		return
	var ii := rng.randi_range(1, world.islands.size() - 1)
	var at := world.random_ground(ii)
	spawn_mob("glimmer", at)
	ping(at, Color("ffd25a"))
	_announce("A Glimmerkin appeared %s. Catch it before it escapes" % (direction_word(player.pos, at) if player else ""), Color("ffd25a"))
	if net_on: net_event(["anc", "glimmer", _r(at.x), _r(at.y), _r(at.z)])

func on_mob_escaped(mb: Mob) -> void:
	mb.hp = 0.0
	mb.dead = true
	mb._cancel_tele()
	fx.burst(mb.pos + Vector3(0, 0.6, 0), Color("fff4c0"), 24, 4.0, 0.7, -4.0)
	if net_on: net_event(["mobdead", mb.nid, ""])
	if player and player.flat_dist(mb) < 25.0:
		add_feed("The Glimmerkin got away")

## Out: how (skiff, hatch, uplink) and where, for the results screen.
func _extract(h: Hunter, how := "", where := "") -> void:
	if h.extracted:
		return
	h.extracted = true
	h.downed = false
	if not h.stomp.is_empty(): Life.end_stomp(self, h, "extract")
	cancel_abilities(h)
	if net_on and not h.remote:
		net_event(["ext", h.nid])
	var col: Color = {"skiff": ExitModels.DOCK, "hatch": ExitModels.HATCH, "uplink": ExitModels.UPLINK}.get(how, Color("8fe3c8"))
	sfx("portal", h.pos, -4.0 if how == "hatch" else 0.0, 1.3)
	fx.burst(h.pos + Vector3(0, 1.0, 0), col, 30, 5.0, 0.8, -4.0)
	Juice.extract(self, h, col)
	add_feed("%s extracted" % h.pname)
	if h.kin:
		if h.kin.comp: h.kin.comp.on_extract()
		h.kin.visible = false
	if h == player:
		if h.kin and h.kin.state != "downed":
			BokiChatter.say(self, h.kin, "extract")
		result = {"extracted": true, "why": "extracted", "how": how, "where": where}
		_end_soon(1.6)
		if opts.get("tut_test", false):
			print("TUT DONE extracted by %s at %s, t=%.1f" % [how, where, time])
			get_tree().create_timer(0.5).timeout.connect(func(): get_tree().quit())
	_check_last()

func _update_rules(_dt: float) -> void:
	var left := length - time
	if left < 30.0 and not collapse_warned:
		collapse_warned = true
		add_feed("The islands are falling! Get to an exit!")
		if player and player.kin: BokiChatter.say(self, player.kin, "storm")
		sfx("warn", null, 0.0)
	if left <= 0.0:
		for h in hunters:
			if not h.out and not h.extracted:
				eliminate(h, null, "abyss", true)
		if not over and result.is_empty():
			result = {"extracted": false, "why": "abyss"}
			_end_soon(1.5)

## You're dead but your team's still in it: you wait (and watch) for a box or beacon revive.
## Once nobody's left to bring you back, the expedition's over for you.
func _watch_death() -> void:
	for b in boxes:
		var n: Node3D = b["node"]
		if n:
			var soul: Node3D = n.get_node_or_null("Soul")
			if soul: soul.visible = Life.soul_here(self, b)
	if player == null or not player.out or result.get("ending", false) or over:
		return
	if player.gone or not Life.team_alive(self, player.team):
		var mate: Hunter = null
		for x in hunters:
			if x.team == player.team and x.extracted: mate = x
		if mate and not player.gone:
			# a teammate made it out: your kin went with them
			player.gone = true
			add_feed("Your Boki went home with %s" % mate.pname)
		Life.make_gone(self, player)
		result = {"extracted": false, "why": String(player.get_meta("died_why", "team wiped"))}
		_end_soon(2.2)

## The teammate the camera follows while you're dead, or null.
func spectating() -> Hunter:
	if player == null or not player.out or player.gone or time - float(player.get_meta("died_at", time)) < 2.5:
		return null
	for x in hunters:
		if x.team == player.team and x != player and not x.out and not x.extracted:
			return x
	return null

## Leave while dead and waiting on your team.
func give_up() -> void:
	if player and player.out and not result.get("ending", false):
		Life.make_gone(self, player)
		result = {"extracted": false, "why": String(player.get_meta("died_why", "knocked out"))}
		_end_soon(0.5)

func _end_soon(after: float) -> void:
	if result.get("ending", false):
		return
	result["ending"] = true
	if opts.get("sim_keep", false) and time < length:
		return      # (--rolling-sim: the session runs on to 30:00 after the player is done)
	get_tree().create_timer(after).timeout.connect(_finish)

func _finish() -> void:
	if over:
		return
	over = true
	if Overlay.is_open():
		if Overlay.closed.is_connected(_on_menu_closed):
			Overlay.closed.disconnect(_on_menu_closed)
		Overlay.close()
	if opts.get("training", false):
		# nothing from the training area carries over
		Game.goto("home")
		return
	var r := result.duplicate()
	r["time"] = time
	r["tier"] = tier
	if opts.get("tutorial", false):
		Save.d["tutorial"]["match"] = true
		r["tutorial"] = true
	if player:
		r["gems"] = player.gems
		r["lost_gems"] = player.lost_gems
		r["seeds"] = player.seeds.duplicate()
		r["caught"] = player.caught.duplicate(true)
		r["kills"] = player.kills
		r["knocks"] = player.knocks
		r["damage"] = int(player.dmg_done)
		r["taken"] = int(player.dmg_taken)
		r["downs"] = player.downs
		r["deaths"] = player.deaths
		r["revives"] = player.revives
		r["armor_tier"] = player.armor_tier
		r["belt"] = Equal.belt_home(player, result.get("extracted", false))
		r["backpack"] = Backpacks.home_tier(player, result.get("extracted", false))
		r["stats"] = player.stats.duplicate()
		r["lvl"] = player.lvl      # (class unlock goals: best level in a match)
		# weapons, gloves and treasure: home to the armory if you made it out, else what stayed behind
		if result.get("extracted", false):
			r["haul"] = Pack.haul(player)
		else:
			var lb := Life.box_of(self, player)
			r["lost_items"] = Pack._box_things(lb).map(func(c): return c["it"]) if not lb.is_empty() else Pack.haul(player)
		# a run that ended without getting out: your Boki stays close (and remembers it)
		if not result.get("extracted", false) and player.kin and player.kin.comp:
			player.kin.comp.on_loss()
		if player.kin:
			r["kin_say"] = BokiChatter.line(player.kin, "extract" if result.get("extracted", false) else "comfort")
		# what each kin you brought did, for its memories and growth
		r["kin_runs"] = []
		for kk in [player.kin, player.kin2]:
			if kk == null or not is_instance_valid(kk): continue
			var k: Kin = kk
			r["kin_runs"].append({"uid": String(k.rec.get("uid", "")), "events": k.events.duplicate(true), "trust": k.trust,
				"stats": {"hits": k.st_hits, "kos": k.st_kos, "throws": k.st_throws, "skills": k.st_skills,
				"revives": k.events.filter(func(e): return e["kind"] == "revived").size(), "caught": player.caught.size(),
				"won": 1 if result.get("extracted", false) else 0}})
		if is_instance_valid(player.kin):
			var k0: Kin = player.kin
			r["kin_events"] = k0.events.duplicate(true)
			r["kin_trust"] = k0.trust
		if not player_lost.is_empty():
			r["lost_kin"] = _resolve_lost()
		r["rivals"] = hunters.filter(func(x): return x.ctrl == "bot" and x.team != player.team).map(func(x): return x.pname)
	var placed := 1
	for h in hunters:
		if h.extracted and h != player:
			placed += 0
	r["placed"] = placed
	if rolling:
		r["rolling"] = {"joined_at": rolling.t0, "left_at": sess_time(), "session": Rolling.SESSION, "wave": rolling.join_i}
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if net_on:
		Net.end_match()
	Game.finish_match(r)

# ------------------------------------------------------------------ online
static func _r(v: float) -> float:
	return snappedf(v, 0.01)

func net_event(e: Array) -> void:
	if net_on:
		Net.event(e)

func net_fx(e: Array) -> void:
	if net_on:
		Net.event(["fx"] + e)

func _spawn_net_hunters(spots: Array, names: Array) -> void:
	var nd: Dictionary = opts["net"]
	var roster: Array = nd["roster"]
	var squad := int(nd.get("squad", 1))
	var team_slots := {}
	for r in roster:
		var t := int(r["team"])
		var base: Vector3 = spots[t % spots.size()]
		var slot := int(team_slots.get(t, 0))
		team_slots[t] = slot + 1
		var at := base + Vector3(slot * 1.1, 0, 0)
		if world.is_void(at.x, at.z) or world.is_block(at.x, at.z):
			at = base
		at.y = world.ground_at(at.x, at.z)
		var peer := String(r["peer"])
		var krec: Dictionary = r.get("kin", {})
		if krec.is_empty():
			krec = Save.new_kin("cindle")
		if peer == Net.me:
			var rec: Dictionary = Save.active_kin()
			player = make_hunter("P" + peer, t, String(r["cls"]), String(r["name"]), "local", rec, at, my_kit())
			Equal.start(self, player)
			if player.kin:
				_apply_treat(player.kin)
			_start_drop(player, at)
		else:
			var h := make_hunter("P" + peer, t, String(r["cls"]), String(r["name"]), "remote", krec, at, {"weapon": r.get("weapon", ""), "perk": "", "arch": String(r.get("arch", ""))})
			h.remote = true
			if h.kin:
				h.kin.remote = true
	if not is_host:
		return
	# the host fills the remaining squads and seats with bots
	var n_teams := int(nd.get("teams", 4))
	for t in n_teams:
		var have := int(team_slots.get(t, 0))
		for s in range(have, squad):
			var base: Vector3 = spots[t % spots.size()]
			var at := base + Vector3(s * 1.1, 0, 0.8)
			if world.is_void(at.x, at.z) or world.is_block(at.x, at.z):
				at = base
			at.y = world.ground_at(at.x, at.z)
			var h := make_hunter(next_id("b"), t, "", names.pop_back() if names.size() > 0 else "Bot", "bot", bot_kin_record(), at, bot_kit())
			h.ai = bot_brain.new_mind(rng, float(opts.get("bot_skill", bot_cfg["skill"])), bot_cfg)
			h.tonics = 3
			_start_drop(h, at)

## A hit on something another game owns goes to its owner.
func net_send_hit(target: Ent, dmg: float, by: Ent, o: Dictionary) -> bool:
	if not net_on:
		return false
	var kb: Vector2 = o.get("kb", Vector2.ZERO)
	Net.hit(target.nid, [_r(dmg), _r(kb.x), _r(kb.y), _r(float(o.get("lift", -1.0))), 1 if o.get("crit", false) else 0,
		_r(float(o.get("stun", 0.0))), _r(float(o.get("burn", 0.0))), _r(float(o.get("slow", 0.0))), _r(float(o.get("root", 0.0))),
		by.nid if by else "", String(o.get("src", "")), String(o.get("ab", "")), Displace.hit_extra(o)])
	return true

func _flags(h: Hunter) -> int:
	var f := 0
	if h.downed: f |= 1
	if h.out: f |= 2
	if h.extracted: f |= 4
	if h.cloak_t > 0.0: f |= 8
	if h.roll_t > 0.0: f |= 16
	if h.grounded: f |= 32
	if h.fortify_t > 0.0: f |= 64
	if h.reload_t > 0.0: f |= 128
	if h.gliding: f |= 256
	if h.dropping: f |= 512
	if h.riding: f |= 1024
	if h.reveal_t > 0.0: f |= 4096
	if h.crouch: f |= 8192
	if h.diving: f |= 16384
	# holding interact (an animation each): bit 2048, and which kind in bits 15-18
	var hk := Hunter.HOLD_KINDS.find(h.holding())
	if hk >= 0: f |= 2048 | ((hk + 1) << 15)
	return f

const KIN_STATES := ["shoulder", "flying", "flying_home", "active", "returning", "downed", "reviving", "wild", "dazed", "fused"]
const MOB_STATES := ["idle", "chase", "windup", "lunge", "recover"]

func _ser(e: Ent) -> Array:
	if e is Hunter:
		var h: Hunter = e
		return ["h", h.nid, _r(h.pos.x), _r(h.pos.y), _r(h.pos.z), _r(h.vel.x), _r(h.vel.y), _r(h.vel.z), _r(h.face), _r(h.hp), h.max_hp, _flags(h),
			_r(h.down_hp), _r(h.revive), h.team, h.cls, h.pname, _r(h.shield), _r(h.extract_prog), h.kills, h.knocks, int(h.dmg_done), _r(h.armor), h.max_armor, h.arch, h.wid] + KinNet.hunter_extra(h) + ArchKit.net_move(h) + GripNet.hunter_extra(h) + HunterNet.extra(h)
	if e is Kin:
		var k: Kin = e
		return ["k", k.nid, _r(k.pos.x), _r(k.pos.y), _r(k.pos.z), _r(k.face), _r(k.hp), _r(k.max_hp), KIN_STATES.find(k.state), k.species,
			k.owner_h.nid if k.owner_h else "", int(k.rec.get("level", 1)), String(k.rec.get("name", "")), _r(k.catch_prog), _r(k.vel.x), _r(k.vel.z),
			1 if k.rec.get("shimmer", false) else 0, String(k.rec.get("acc", "")), ",".join(Mutations.of(k.rec))] + KinNet.kin_extra(k)
	var mb: Mob = e
	var ms := ["m", mb.nid, _r(mb.pos.x), _r(mb.pos.y), _r(mb.pos.z), _r(mb.face), _r(mb.hp), _r(mb.max_hp), MOB_STATES.find(mb.st), mb.mkind,
		_r(mb.atk_dir.x), _r(mb.atk_dir.y), _r(mb.st_t), _r(mb.vel.x), _r(mb.vel.z), _r(mb.stag_open), _r(mb.stagger_t)]
	if mb is Blight:
		# the Blight: where a Warden's light points, how close it is to shrieking, and its strength
		var bb: Blight = mb
		ms.append_array([_r(bb.cone_a), _r(bb.spot), _r(bb.lvl), 1 if bb.tgt != null else 0])
	else:
		ms.append_array(KeyCarry.mob_extra(mb))      # key carrier flag, Shrubling pose (Net 0.15.3)
	return ms

## Snapshot of what this game owns: its player (mine=true), or the host's world (mine=false).
func net_snapshot(mine: bool) -> Array:
	var out: Array = []
	if mine:
		if player:
			out.append(_ser(player))
			if player.kin and not player.kin.dead:
				out.append(_ser(player.kin))
		return out
	for h in hunters:
		if not h.remote and h != player:
			out.append(_ser(h))
			if h.kin and not h.kin.dead: out.append(_ser(h.kin))
	for k in kins:
		if k.is_wild() and not k.dead: out.append(_ser(k))
	for mb in mobs:
		if not mb.dead: out.append(_ser(mb))
	return out

func net_receive(topic: String, data, from: String) -> void:
	if typeof(data) != TYPE_ARRAY:
		return
	match topic:
		"st": _net_state(data, from)
		"hit": for x in data: _net_hit_in(x)
		"ev": for x in data: _net_ev(x, from)

func _net_state(data: Array, from: String) -> void:
	var t_host := -1.0
	for it in data:
		if typeof(it) == TYPE_DICTIONARY:
			t_host = float(it.get("t", -1.0))
			continue
		if typeof(it) != TYPE_ARRAY or it.size() < 3:
			continue
		var nid := String(it[1])
		if Net.owns(nid):
			continue
		var e: Ent = ents_by_id.get(nid, null)
		if e == null:
			e = _net_make(it)
			if e == null:
				continue
		_net_apply(e, it)
	if t_host >= 0.0 and from == Net.host and absf(t_host - time) > 0.5:
		time = t_host

func _net_make(it: Array) -> Ent:
	var nid := String(it[1])
	match String(it[0]):
		"h":
			# the host says which archetype and weapon: a remote body always shows its real silhouette
			var rk := {"arch": String(it[24]) if it.size() > 24 else "", "weapon": String(it[25]) if it.size() > 25 else ""}
			var h := make_hunter(nid, int(it[14]), String(it[15]), String(it[16]), "remote", {}, Vector3(it[2], it[3], it[4]), rk)
			h.remote = true
			return h
		"k":
			var owner: Hunter = ents_by_id.get(String(it[10]), null)
			var rec := {"species": String(it[9]), "level": int(it[11]), "name": String(it[12]), "traits": Data.KIN[String(it[9])]["traits"].duplicate(), "trust": 50.0}
			if it.size() > 17:
				rec["shimmer"] = int(it[16]) == 1
				rec["acc"] = String(it[17])
			if it.size() > 18 and String(it[18]) != "":
				rec["mutations"] = Array(String(it[18]).split(","))
			var k := Kin.new()
			k.init_kin(self, nid, rec["species"], rec, owner)
			add_child(k)
			k.teleport(Vector3(it[2], it[3], it[4]))
			k.remote = true
			if owner == null:
				k.state = "wild"
			kins.append(k)
			ents_by_id[nid] = k
			if owner and owner.kin == null:
				owner.kin = k
			_net_seen_rec[nid] = rec
			KinLoss.apply_pending(self, k)
			return k
		"m":
			var mk := String(it[9])
			if not Data.MOBS.has(mk):
				return null
			var mb: Mob
			if Data.MOBS[mk].get("blight", false):
				var bl := Blight.new()
				bl.init_blight(self, nid, mk, Vector3(it[2], it[3], it[4]), float(it[19]) if it.size() > 19 else 0.1, blight)
				mb = bl
			elif mk == "shrubling":
				mb = Shrubling.new()
				(mb as Shrubling).init_shrub(self, nid, Vector3(it[2], it[3], it[4]))
			else:
				mb = Mob.new()
				mb.init_mob(self, nid, mk, Vector3(it[2], it[3], it[4]))
			add_child(mb)
			mb.remote = true
			mobs.append(mb)
			ents_by_id[nid] = mb
			return mb
	return null

func _net_apply(e: Ent, it: Array) -> void:
	e.net_pos = Vector3(it[2], it[3], it[4])
	e.net_t = time
	match String(it[0]):
		"h":
			var h: Hunter = e
			h.net_vel = Vector3(it[5], it[6], it[7])
			h.face = it[8]; h.hp = it[9]; h.max_hp = it[10]
			var f := int(it[11])
			h.downed = f & 1 != 0
			if f & 2 != 0 and not h.out:
				h.out = true
			if f & 4 != 0 and not h.extracted:
				h.extracted = true
			h.cloak_t = 0.3 if f & 8 != 0 else 0.0
			h.roll_t = 0.05 if f & 16 != 0 else 0.0
			h.grounded = f & 32 != 0
			h.fortify_t = 0.3 if f & 64 != 0 else 0.0
			h.gliding = f & 256 != 0
			h.dropping = f & 512 != 0
			h.riding = f & 1024 != 0
			h.diving = f & 16384 != 0
			if f & 4096 != 0: h.reveal_t = maxf(h.reveal_t, 0.3)
			h.crouch = f & 8192 != 0
			if f & 2048 != 0:
				var hk := ((f >> 15) & 15) - 1
				if hk >= 0 and hk < Hunter.HOLD_KINDS.size(): h.set_hold(String(Hunter.HOLD_KINDS[hk]), 0.3)
			h.down_hp = it[12]; h.revive = maxf(h.revive if h.revive > float(it[13]) and _rev_out.has(h.nid) else 0.0, float(it[13]))
			h.shield = it[17]; h.extract_prog = it[18]
			h.kills = int(it[19]); h.knocks = int(it[20]); h.dmg_done = float(it[21])
			if it.size() > 23:
				h.armor = float(it[22]); h.max_armor = float(it[23])
			KinNet.apply_hunter(h, it)
			ArchKit.apply_net_move(h, it)
			GripNet.apply_hunter(h, it)       # gloves, their cooldowns and the bond meter (the overhead row)
			HunterNet.apply(h, it)
		"k":
			var k: Kin = e
			k.face = it[5]; k.hp = it[6]; k.max_hp = it[7]
			var st: int = int(it[8])
			if st >= 0 and st < KIN_STATES.size():
				k.state = KIN_STATES[st]
			if k.dead:
				k.catch_prog = 0.0       # (it stood up again: a new scan may be asked for)
			k.catch_prog = maxf(k.catch_prog, float(it[13])) if k.catch_prog >= 5.0 else float(it[13])
			k.net_vel = Vector3(it[14], 0, it[15])
			k.dead = false
			KinNet.apply_kin(k, it)
		"m":
			var mb: Mob = e
			mb.face = it[5]; mb.hp = it[6]; mb.max_hp = it[7]
			var st: int = int(it[8])
			if st >= 0 and st < MOB_STATES.size():
				mb.st = MOB_STATES[st]
			mb.atk_dir = Vector2(it[10], it[11])
			mb.st_t = it[12]
			mb.net_vel = Vector3(it[13], 0, it[14])
			if it.size() > 16:
				mb.stag_open = float(it[15]); mb.stagger_t = float(it[16])
			if not (mb is Blight) and it.size() > 18:
				KeyCarry.apply_mob(mb, it)
			if mb is Blight and it.size() > 20:
				var bb: Blight = mb
				bb.cone_a = float(it[17]); bb.spot = float(it[18]); bb.lvl = float(it[19])
				bb.tgt = player if int(it[20]) == 1 else null     # (only "alerted or not" matters to a proxy's looks)

func _net_hit_in(x) -> void:
	if typeof(x) != TYPE_ARRAY or x.size() < 12:
		return
	var nid := String(x[0])
	if not Net.owns(nid):
		return
	var e: Ent = ents_by_id.get(nid, null)
	if e == null or e.dead:
		return
	var by: Ent = ents_by_id.get(String(x[10]), null)
	var o := {"src": String(x[11]), "crit": int(x[5]) == 1}
	if absf(float(x[2])) + absf(float(x[3])) > 0.0: o["kb"] = Vector2(x[2], x[3])
	if float(x[4]) >= 0.0: o["lift"] = float(x[4])
	if float(x[6]) > 0.0: o["stun"] = float(x[6])
	if float(x[7]) > 0.0: o["burn"] = float(x[7])
	if float(x[8]) > 0.0: o["slow"] = float(x[8])
	if float(x[9]) > 0.0: o["root"] = float(x[9])
	if x.size() > 12 and String(x[12]) != "": o["ab"] = String(x[12])
	if x.size() > 13: Displace.apply_hit_extra(o, x[13])      # wall stun, steer, burn time, slow strength
	e.hurt(float(x[1]), by, o)

func _net_ev(x, from: String) -> void:
	if typeof(x) != TYPE_ARRAY or x.size() < 1:
		return
	var who: Ent = null
	match String(x[0]):
		"zone":
			HeroZones.net_in(self, x)
		"disp":
			displace.net_in(x)
		"kcmd":
			KinNet.on_event(self, x)       # a Boki command or a merge going off in another game
		"kst":
			# a kit status (Grounded, Blight, Shred) landed on a body: its own game runs the rule
			KitStatus.from_net(self, x)
		"hex":
			# a Mage's Hex landed: the body's own game runs the rules, every game shows the critter
			who = ents_by_id.get(String(x[1]), null)
			if who is Hunter: Hex.apply(who as Hunter, float(x[2]), false)
		"s":
			var col := Color.html(String(x[8]))
			var ex := {"cos": true}
			if float(x[9]) > 0.0: ex["boom"] = float(x[9])
			if int(x[11]) == 1: ex["mob"] = true
			if int(x[11]) == 2: ex["pierce_terrain"] = true
			var fake := Ent.new(); fake.team = int(x[10]); fake.remote = true
			spawn_shot(fake, Vector3(x[1], x[2], x[3]), Vector2(x[4], x[5]), 0.0, float(x[6]), float(x[7]), col, ex)
			fake.free()
		"fx":
			match String(x[1]):
				"ring": fx.ring(Vector3(x[2], x[3], x[4]), float(x[5]), Color.html(String(x[6])), 0.35)
				"bolt": fx.bolt(Vector3(x[2], x[3], x[4]), Vector3(x[5], x[6], x[7]), Color.html(String(x[8])))
				"cone": fx.cone(Vector3(x[2], x[3], x[4]), Vector2(x[5], x[6]), 5.0, Color.html(String(x[7])))
				"hvfx": HeroVfx.of(self).net_in(x)
		"knock":
			who = ents_by_id.get(String(x[1]), null)
			if who is Hunter and not who.downed:
				var by: Ent = ents_by_id.get(String(x[2]), null)
				who.downed = true
				sfx("knock", who.pos, 0.0)
				HeroSfx.voice(self, who, "down")
				add_feed("%s knocked %s" % [by.pname, who.pname] if by is Hunter else "%s went down" % who.pname)
				if by is Hunter: DashReset.takedown(by, who)       # refreshes the hunters this game owns
				if by == player:
					player.knocks += 1
					_reward_moment(who.pos)
				_check_team(player.team if player else -9)
		"out":
			who = ents_by_id.get(String(x[1]), null)
			if who is Hunter and not who.out:
				var by: Ent = ents_by_id.get(String(x[2]), null)
				who.out = true
				if by is Hunter: DashReset.takedown(by, who)
				if by == player:
					player.kills += 1
				add_feed(out_text(who.pname, String(x[3])))
				if who.kin:
					who.kin.dead = true
					who.kin.visible = false
				_check_last()
		"up":
			who = ents_by_id.get(String(x[1]), null)
			if who is Hunter:
				who.downed = false
				who.revive = 0.0
				sfx("revive", who.pos, 0.0)
				_rev_out.erase(who.nid)
		"xc":
			if exits: exits.net_in(x)
		"bcn":
			Beacons.net_in(self, x)
		"emo":
			var eh: Hunter = ents_by_id.get(String(x[1]), null) as Hunter
			if truce and eh: truce.emote(eh, String(x[2]), true)
		"kc":
			# a Boki's callout (KinCompanion): its ping, its body turning, its bark here too
			var kk: Kin = ents_by_id.get(String(x[1]), null) as Kin
			if kk and kk.comp and x.size() >= 6:
				kk.comp.heard(String(x[2]), Vector3(float(x[3]), float(x[4]), float(x[5])))
		"sping":
			var ph: Hunter = ents_by_id.get(String(x[1]), null) as Hunter
			if ph:
				squad_ping(ph, Vector3(x[2], x[3], x[4]), true, String(x[5]) if x.size() > 5 else "")
		"unping":
			var uh: Hunter = ents_by_id.get(String(x[1]), null) as Hunter
			if uh: unping(uh, true, true)
		"lead":
			var lh: Hunter = ents_by_id.get(String(x[1]), null) as Hunter
			var lt: Hunter = ents_by_id.get(String(x[2]), null) as Hunter
			if skydrop and lh and lt: skydrop.pass_lead(lh, lt, true)
		"dsep":
			var sh: Hunter = ents_by_id.get(String(x[1]), null) as Hunter
			if skydrop and sh: skydrop.separate(sh, true)
		"ext":
			who = ents_by_id.get(String(x[1]), null)
			if who is Hunter and not who.extracted:
				who.extracted = true
				add_feed("%s extracted" % who.pname)
				if who.kin: who.kin.visible = false
				_check_last()
		"heal":
			who = ents_by_id.get(String(x[1]), null)
			if who is Hunter and not who.remote:
				who.heal(float(x[2]))
		"carry":
			who = ents_by_id.get(String(x[1]), null)
			if who is Hunter and not who.remote:
				CareUtil.set_carry(self, who, String(x[2]))
		"rev":
			who = ents_by_id.get(String(x[1]), null)
			if who is Hunter and not who.remote and who.downed:
				who.revive += float(x[2])
				if who.revive >= 1.0:
					revive_hunter(who, null)
		"blsh":
			# a Warden shrieked on the host's game
			who = ents_by_id.get(String(x[1]), null)
			if who is Blight and not who.dead:
				(who as Blight).shriek_fx()
		"blgone":
			who = ents_by_id.get(String(x[1]), null)
			if who is Blight and not who.dead:
				(who as Blight).burrow()
		"mobdead":
			who = ents_by_id.get(String(x[1]), null)
			if who is Mob and not who.dead:
				who.dead = true
				who._cancel_tele()
				fx.burst(who.pos + Vector3(0, 0.6, 0), who.md["color"], 22, 5.0, 0.6)
				sfx("kill", who.pos, -6.0, 1.3)
		"drop":
			if not is_host:
				drop(String(x[2]), Vector3(x[5], x[6], x[7]), int(x[3]), String(x[4]), String(x[1]), Vector3(x[8], x[9], x[10]))
		"take", "gone":
			for p in pickups:
				if p["id"] == String(x[1]):
					p["node"].queue_free()
					pickups.erase(p)
					break
			if String(x[0]) == "take" and is_host:
				net_event(["gone", String(x[1])])
		"met":
			_meteor_start(Vector3(x[1], x[2], x[3]))
		"stg":
			var smb: Ent = ents_by_id.get(String(x[1]), null)
			if smb is Mob:
				(smb as Mob).stagger_t = 2.2 if (smb as Mob).mkind == "warden" else 3.0
				(smb as Mob).stag_open = 0.0
				fx.ring(smb.pos, smb.r + 1.8, Color("c47aff"), 0.4)
				fx.burst(smb.pos + Vector3(0, 1.0, 0), Color("e0b0ff"), 30, 6.0, 0.6, 2.0, 1.2)
				sfx("crit", smb.pos, 2.0, 0.7)
				_stagger_reward(smb, ents_by_id.get(String(x[2]), null) as Hunter, String(x[3]))
		"anc":
			if String(x[1]) == "meteor":
				_announce("A meteor shower is coming down. Stars leave gems where they land", Color("ffcf8a"))
				return
			var aat := Vector3(x[2], x[3], x[4])
			ping(aat, Color("ffd25a"))
			_announce("A Glimmerkin appeared %s. Catch it before it escapes" % (direction_word(player.pos, aat) if player else ""), Color("ffd25a"))
		"brk":
			var bi := int(x[1])
			if bi >= 0 and bi < breaks.size():
				brk.smash(breaks[bi], ents_by_id.get(String(x[2]), null), true)
		"wdrop":
			var seen := false
			for wp in wpicks:
				if wp["id"] == String(x[1]): seen = true
			if not seen:
				var wat := Vector3(x[4], x[5], x[6])
				if String(x[2]) == "tune" and Data.PERKS.has(String(x[7])): spawn_tune(String(x[7]), wat, String(x[1]), false)
				elif String(x[2]) == "gear" and Gear.ALL.has(String(x[7])): spawn_gear(String(x[7]), int(x[3]), wat, String(x[1]), false)
		"odrop", "otake":
			PerkOrbs.on_net(self, x)
		"wtake":
			for wp in wpicks:
				if wp["id"] == String(x[1]):
					take_pick(ents_by_id.get(String(x[2]), null), wp, true)
					break
		"zone":
			var zo: Ent = ents_by_id.get(String(x[8]), null)
			if zo is Hunter:
				add_zone(String(x[1]), Vector3(x[2], x[3], x[4]), float(x[5]), float(x[6]), int(x[7]), zo, true)
		"shr":
			var si := int(x[1])
			if si >= 0 and si < shrines.size():
				_use_shrine(ents_by_id.get(String(x[2]), null), shrines[si], true)
		"chest":
			var i := int(x[1])
			if i >= 0 and i < chests.size():
				_open_chest(ents_by_id.get(String(x[2]), null), chests[i], true)
		"spill":
			if is_host:
				var at := Vector3(x[1], x[2], x[3])
				if not world.is_void(at.x, at.z):
					var gems := int(x[4])
					var n := mini(10, int(ceil(gems / 5.0)))
					for i in n:
						drop("gem", at + Vector3(0, 0.5, 0), maxi(1, gems / maxi(1, n)))
					for s in x[5]:
						drop("seed", at + Vector3(0, 0.5, 0), int(x[5][s]), s)
					for rec in x[6]:
						spawn_wild(rec, at, true)
		"catch":
			if is_host:
				var k: Kin = ents_by_id.get(String(x[1]), null)
				var h: Hunter = ents_by_id.get(String(x[2]), null)
				if k and h and not k.dead and KinLoss.scannable_by(h, k) and not KinLoss.cradled(k):
					_catch(h, k)
		"caught":
			var k: Kin = ents_by_id.get(String(x[1]), null)
			if k:
				k.dead = true
				k.visible = false
			if player and String(x[2]) == player.nid and typeof(x[3]) == TYPE_DICTIONARY:
				var rec: Dictionary = x[3]
				player.caught.append(rec)
				sfx("scan_pop", player.pos, 0.0)
				add_feed("%s is in your box (%d/%d). Extract to bring it home." % [Data.KIN.get(String(rec.get("species", "cindle")), Data.KIN["cindle"])["name"], mini(player.caught.size(), Capture.box_cap()), Capture.box_cap()])
			var cap = ents_by_id.get(String(x[2]), null)
			var own = ents_by_id.get(String(x[4]), null) if x.size() > 4 else null
			if cap is Hunter and own is Hunter and typeof(x[3]) == TYPE_DICTIONARY:
				KinTrack.on_caught_net(self, cap, x[3], own)      # the captor and the owner learn of the bond
		"guard":
			KinLoss.on_guard_net(self, x)
		"gdrop":
			KinLoss.on_gdrop(self, String(x[1]), x[5], Vector3(x[2], x[3], x[4]))      # a captor fell: its Boki stands up again (owner's game)

func _process_net_revives() -> void:
	if _rev_out.is_empty():
		return
	for nid in _rev_out:
		if float(_rev_out[nid]) > 0.0:
			net_event(["rev", nid, _r(_rev_out[nid])])
			_rev_out[nid] = 0.0

# ------------------------------------------------------------------ first-time tips
var _tip_t := 0.0

## Screenshot demos: moves the player (once) to the nearest open, level stretch of ground at least
## 6m from the start's clutter (the duel pad and its post, the glove stands) and returns a spot
## `dist` metres east of them with a clear line of fire.
func demo_clear_spot(dist: float) -> Vector3:
	var best := Vector3.INF
	for pass_i in 2:
		best = _demo_open(dist, pass_i == 0)
		if best != Vector3.INF:
			break
	if best == Vector3.INF:
		print("DEMO no open ground")
		return world.free_spot_near(player.pos + Vector3(dist, 0, 0), [player.pos], 1.0, 0.45, 6.0)
	# monsters nearby would join in: send them to the far side of the map for the demo
	for mb in mobs:
		if Vector2(mb.pos.x - best.x, mb.pos.z - best.z).length() < 14.0:
			var far := world.free_spot_near(Vector3(world.w - best.x, 0, world.h - best.z), [], 1.0, 0.45, 30.0)
			mb.pos = far; mb.prev = far
	player.teleport(best)
	player.vel = Vector3.ZERO
	return best + Vector3(dist, 0, 0)

func _demo_open(dist: float, avoid_mobs: bool) -> Vector3:
	var best := Vector3.INF; var bd := 1e9
	var c0 := player.pos
	for iz in range(2, world.h - 2):
		for ix in range(2, world.w - 2):
			var q := Vector3(ix + 0.5, 0, iz + 0.5)
			var dd := Vector2(q.x - c0.x, q.z - c0.z).length()
			if dd < 6.0 or dd >= bd or world.is_void(q.x, q.z) or world.is_block(q.x, q.z):
				continue
			if avoid_mobs and mobs.any(func(mb): return Vector2(mb.pos.x - q.x, mb.pos.z - q.z).length() < 9.0):
				continue
			var gy := world.ground_at(q.x, q.z)
			var ok := true
			for dx in range(-2, int(dist) + 3):
				for dz in range(-2, 3):
					var x := q.x + dx; var z := q.z + dz
					var inner := absi(dz) <= 1 and dx >= -1 and dx <= int(dist) + 1
					if world.is_block(x, z) or (inner and (world.is_void(x, z) or absf(world.ground_at(x, z) - gy) > 0.8)):
						ok = false; break
				if not ok: break
			if ok:
				bd = dd; best = Vector3(q.x, gy, q.z)
	return best

func _tip(key: String, text: String) -> void:
	var seen: Dictionary = Save.d["tutorial"]
	if seen.get(key, false) or hud == null:
		return
	seen[key] = true
	hud.tip(text)

func _tips() -> void:
	if player == null or player.out or player.riding or opts.get("autoplay", false) or not Settings.get_v("tips") or Record.clean():
		return
	_tip_t += get_process_delta_time()
	if _tip_t < 1.0:
		return
	if player.dropping or opts.get("tutorial", false) or opts.get("arena", false):
		return
	_tip("move", "Hold left click to shoot  ·  Shift dashes  ·  hold Space to glide")
	if _tip_t > 14.0:
		if player.ak:
			_tip("ability", "%s sends your Boki (hold: orders)  ·  full bond: %s fuses" % [Settings.key_cap("throw"), Settings.key_cap("ultimate")])
		else:
			_tip("ability", "%s: your Boki's ability  ·  full bond: %s" % [Settings.key_cap("signature"), Settings.key_cap("ultimate")])
	if player.ult >= 1.0 and player.kin:
		var ud := KinMerge.def_for(player.kin)
		if ud and player.ak == null: _tip("ult", "Bond full  ·  %s fuses: %s" % [Settings.key_cap("ultimate"), ud.display_name])
		elif ud and int(player.slot_lv.get("ult", 0)) > 0:
			_tip("ult", "Bond full  ·  your next %s fuses: %s" % [Settings.key_cap("ultimate"), ud.display_name])
	var k: Kin = player.kin
	if k == null:
		return
	if _tip_t > 9.0:
		var near_foe := false
		for f in foes_of(player.team):
			if player.flat_dist(f) < 9.0:
				near_foe = true; break
		if near_foe:
			_tip("throw", "%s sends %s: its hit stuns, and stunned foes take crits" % [Settings.key_cap("throw"), k.rec.get("name", "your Boki")])
	if k.state == "active":
		var a1 := k.runner.def_of("k1")
		var a2 := k.runner.def_of("k2")
		_tip("skill", "Stun a foe with %s's %s, then shoot it: combo" % [k.rec.get("name", "your Boki"), a1.display_name if a1 else "ability"])
	if not interact.is_empty() and interact["kind"] == "catch":
		_tip("catch", "Hold %s to scan  ·  4s, rivals hear it  ·  extract to keep it" % Settings.key_cap("interact"))
	if exits and not interact.is_empty() and interact["kind"] == "exit":
		match String(interact["x"]["kind"]):
			"dock": _tip("exit_dock", "Call the skiff at the horn, hold out, board before it leaves")
			"hatch": _tip("exit_hatch", "A Rift Key opens this hatch (%s)  ·  three can drop through" % Settings.key_cap("interact"))
			"outpost": _tip("exit_uplink", "Start the uplink, hold the yard, then take the lift")
	if player.downed:
		_tip("down", "Down  ·  a trusting Boki may pick you up")

# ------------------------------------------------------------------ aim indicators
# ---- ability previews: hold E, R or Q to see the reach and where it lands
var aim_hold := ""
var ind_range: MeshInstance3D
var ind_area: MeshInstance3D
var ind_fill: MeshInstance3D
var ind_line: MeshInstance3D
var ind_fan: MeshInstance3D
var ind_wall: MeshInstance3D
## [shape, reach, size]: self (around you), dash (where you'll end up), line (length, width),
## area (a circle at the cursor within reach), cone (length, cosine of the half angle)
const AIM := {
	"cloak": ["self", 0.0, 1.2], "mend": ["self", 0.0, 5.0], "fortify": ["self", 0.0, 1.6], "dome": ["self", 0.0, 3.6],
	"blink": ["dash", 6.0, 0.8], "rocketjump": ["dash", 7.0, 2.4], "tether": ["line", 14.0, 0.35], "hook": ["line", 9.0, 0.45],
	"ram": ["line", 6.0, 1.3], "vanish": ["self", 0.0, 1.2], "dance": ["self", 0.0, 9.0], "skypierce": ["line", 26.0, 1.8],
	"sanctuary": ["self", 0.0, 4.2], "anchor": ["dash", 10.0, 3.6], "barrage": ["area", 11.0, 3.0], "bulwark": ["self", 0.0, 4.0],
	"quake": ["cone", 8.0, 0.55], "well": ["area", 10.0, 4.5],
	"fireball": ["area", 9.0, 1.9], "wave": ["cone", 5.0, 0.55], "snare": ["area", 9.0, 2.2], "chain": ["area", 9.0, 1.2],
	"slam": ["area", 7.0, 2.0], "gust": ["self", 0.0, 2.8],
}

func _build_indicators() -> void:
	var mk := func(mesh: Mesh, mat: Material) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh; mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		return mi
	ind_range = mk.call(Models.flat_quad(2.0), Models.ring_mat(Color(1, 1, 1, 0.35), 0.015))
	ind_area = mk.call(Models.flat_quad(2.0), Models.ring_mat(Color(1, 1, 1, 0.9), 0.06))
	ind_fill = mk.call(Models.cyl(1.0, 1.0, 0.01, 40), Models.glow_mat(Color(1, 1, 1, 0.14)))
	ind_line = mk.call(Models.box(1.0, 0.01, 1.0), Models.glow_mat(Color(1, 1, 1, 0.22)))
	ind_fan = mk.call(ArrayMesh.new(), Models.glow_mat(Color(1, 1, 1, 0.2)))
	ind_wall = mk.call(Models.box(1.0, 0.02, 1.0), Models.glow_mat(Color(1, 1, 1, 0.9)))

func _fan_mesh(length: float, cos_half: float) -> ArrayMesh:
	var half := acos(clampf(cos_half, -1.0, 1.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 20
	for i in n:
		var a0 := -half + 2.0 * half * i / n
		var a1 := -half + 2.0 * half * (i + 1) / n
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a1), 0, -cos(a1)) * length)
		st.add_vertex(Vector3(sin(a0), 0, -cos(a0)) * length)
	var am := ArrayMesh.new()
	st.commit(am)
	return am

func _update_indicators(alpha: float) -> void:
	if ind_range == null:
		_build_indicators()
	for n in [ind_range, ind_area, ind_fill, ind_line, ind_fan, ind_wall]: n.visible = false
	var p := player
	if p == null or p.out or p.downed or paused or (aim_hold == "" and p.charge_frac() < 0.0):
		return
	var id := ""
	var col := Color.WHITE
	var spec: Array = []
	var from_kin := false
	if p.charge_frac() >= 0.0:
		# a charge-up: the lane grows as you hold
		var ud: AbilityDef = p.runner.def_of("utility")
		var sp0: Array = ud.aim_spec()
		spec = ["line", lerpf(float(sp0[1]) * 0.5, float(sp0[1]), p.charge_frac()), float(sp0[2]) * (1.0 + p.charge_frac())]
		col = ud.color.lerp(Color.WHITE, 0.4 * p.charge_frac())
	match aim_hold if spec.is_empty() else "":
		"secondary":
			var ud2: AbilityDef = p.runner.def_of("utility") if p.runner else null
			if ud2 == null: return
			spec = ud2.aim_spec(); col = ud2.color
		"gear1", "gear2":
			var g0: Dictionary = p.gear[Gloves.KEYS.find(aim_hold)]
			if g0.is_empty(): return
			var gdf := Gear.def_of(String(g0["id"]))
			spec = gdf.aim_spec(); col = gdf.color
		"signature", "kin_skill":
			if p.kin == null: return
			var kd: AbilitySpec = (p.kin as Kin).runner.def_of("k1" if aim_hold == "signature" else "k2")
			if kd == null: return
			spec = KinText.aim((p.kin as Kin).effective("k1" if aim_hold == "signature" else "k2")); col = KinText.color(kd)
			from_kin = kd.from == "kin" and (p.kin as Kin).state == "active"
		"ultimate":
			var ud := KinMerge.def_for(p.kin) if p.kin else null
			if ud == null: return
			col = KinRules.cat_color("utility")
			spec = ["self", 0.0, 3.5]
	if spec.is_empty():
		return
	var at := p.prev.lerp(p.pos, alpha)
	if from_kin:
		at = (p.kin as Kin).prev.lerp((p.kin as Kin).pos, alpha)
	var aim: Vector3 = p.inp["aim"]
	var d := Vector2(aim.x - at.x, aim.z - at.z)
	var dir := d.normalized() if d.length() > 0.1 else p.aim_dir()
	var reach: float = spec[1]
	var size: float = spec[2]
	var gy := at.y + 0.07
	var set_col := func(mi: MeshInstance3D, a: float) -> void:
		var mat = mi.material_override
		if mat is ShaderMaterial:
			mat.set_shader_parameter("color", Color(col, a))
	match String(spec[0]):
		"self":
			ind_area.visible = true; ind_fill.visible = true
			ind_area.global_position = Vector3(at.x, gy, at.z); ind_area.scale = Vector3.ONE * size
			ind_fill.global_position = Vector3(at.x, gy, at.z); ind_fill.scale = Vector3(size, 1, size)
		"area", "dash":
			var dist := minf(d.length(), reach)
			var c2 := Vector2(at.x, at.z) + dir * dist
			var g := world.ground_at(c2.x, c2.y)
			var cy: float = (g if g > World.VOID + 1.0 else at.y) + 0.07
			ind_range.visible = true
			ind_range.global_position = Vector3(at.x, gy, at.z); ind_range.scale = Vector3.ONE * reach
			ind_area.visible = true; ind_fill.visible = true
			ind_area.global_position = Vector3(c2.x, cy, c2.y); ind_area.scale = Vector3.ONE * size
			ind_fill.global_position = Vector3(c2.x, cy, c2.y); ind_fill.scale = Vector3(size, 1, size)
		"line":
			ind_line.visible = true
			var mid := Vector2(at.x, at.z) + dir * reach * 0.5
			ind_line.global_position = Vector3(mid.x, gy, mid.y)
			ind_line.rotation = Vector3(0, atan2(-dir.x, -dir.y), 0)
			ind_line.scale = Vector3(size, 1, reach)
			# and a tick across its far end so the length reads
			ind_wall.visible = true
			var tip := Vector2(at.x, at.z) + dir * reach
			ind_wall.global_position = Vector3(tip.x, gy + 0.01, tip.y)
			ind_wall.rotation = Vector3(0, atan2(-dir.x, -dir.y), 0)
			ind_wall.scale = Vector3(maxf(size * 1.8, 0.9), 1, 0.12)
		"wall":
			# the wall's own footprint, across your aim, where it will stand
			var front := spec.size() > 3 and String(spec[3]) == "front"
			var dist2 := reach if front else minf(d.length(), reach)
			var wd := dir
			if from_kin:
				var od := Vector2(aim.x - p.pos.x, aim.z - p.pos.z)
				if od.length() > 0.3: wd = od.normalized()
			var c3 := Vector2(at.x, at.z) + dir * dist2
			var g3 := world.ground_at(c3.x, c3.y)
			var cy3: float = (g3 if g3 > World.VOID + 1.0 else at.y) + 0.08
			if not front:
				ind_range.visible = true
				ind_range.global_position = Vector3(at.x, gy, at.z); ind_range.scale = Vector3.ONE * reach
			ind_wall.visible = true
			ind_wall.global_position = Vector3(c3.x, cy3, c3.y)
			ind_wall.rotation = Vector3(0, atan2(-wd.x, -wd.y), 0)
			ind_wall.scale = Vector3(size, 1, 0.55)
			ind_line.visible = true
			ind_line.global_position = Vector3(c3.x, cy3 - 0.01, c3.y) + Vector3(wd.x, 0, wd.y) * 0.5
			ind_line.rotation = Vector3(0, atan2(-wd.x, -wd.y), 0)
			ind_line.scale = Vector3(size, 1, 1.0)
		"cone":
			ind_fan.mesh = _fan_mesh(reach, size)
			ind_fan.visible = true
			ind_fan.global_position = Vector3(at.x, gy, at.z)
			ind_fan.rotation = Vector3(0, atan2(-dir.x, -dir.y), 0)
	for mi in [ind_range, ind_area, ind_fill, ind_line, ind_fan, ind_wall]:
		set_col.call(mi, 0.35 if mi == ind_range else (0.9 if mi in [ind_area, ind_wall] else 0.22))

func _build_aim() -> void:
	aim_line = MeshInstance3D.new()
	aim_line.mesh = Models.box(0.05, 0.02, 1.0)
	aim_line.material_override = Models.glow_mat(Color(1, 1, 1, 0.22))
	aim_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(aim_line)
	aim_ring = MeshInstance3D.new()
	aim_ring.mesh = Models.flat_quad(1.2)
	aim_ring.material_override = Models.ring_mat(Color(1, 0.95, 0.8, 0.55), 0.18)
	aim_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(aim_ring)
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color("ffd9a0")
	muzzle_light.omni_range = 4.0
	muzzle_light.light_energy = 0.0
	add_child(muzzle_light)

func _update_aim(alpha: float) -> void:
	_update_indicators(alpha)
	if aim_line == null:
		return
	var p := player
	var show := p != null and not p.out and not p.extracted and not p.downed and not paused
	if show and p.ak != null and p.ak.own_aim_line():
		show = false          # the kit draws its own (two lines read as two aims)
	aim_line.visible = show
	aim_ring.visible = false
	muzzle_light.light_energy = 0.0
	if not show:
		return
	var at := p.prev.lerp(p.pos, alpha)
	var aim: Vector3 = p.inp["aim"]
	var d := Vector2(aim.x - at.x, aim.z - at.z)
	# max-range weapons: the line runs past the cursor
	var to_max := String(p.wpn.get("aim", "")) == "max"
	var dist := float(p.wpn["range"]) if to_max else minf(d.length(), float(p.wpn["range"]))
	if dist > 0.6:
		var dir := d.normalized()
		var y := at.y + 0.95 * float(p.cdat["scale"])
		var a := Vector3(at.x + dir.x * 0.6, y, at.z + dir.y * 0.6)
		var b := Vector3(at.x + dir.x * dist, y, at.z + dir.y * dist)
		aim_line.global_position = (a + b) * 0.5
		if a.distance_to(b) < 0.05:
			aim_line.visible = false
			return
		aim_line.look_at(b, Vector3.UP)
		aim_line.scale = Vector3(1, 1, a.distance_to(b))
	else:
		aim_line.visible = false
	# where your kin would land if you threw it now
	var k: Kin = p.kin
	if k and k.state == "shoulder" and k.settle >= 0.35:
		var t := Vector2(aim.x - at.x, aim.z - at.z)
		if t.length() > 9.0:
			t = t.normalized() * 9.0
		var g := world.ground_at(at.x + t.x, at.z + t.y)
		if g > World.VOID + 1.0:
			aim_ring.visible = true
			aim_ring.global_position = Vector3(at.x + t.x, g + 0.06, at.z + t.y)
			var col: Color = Data.KIN[k.species]["color"]
			aim_ring.material_override.set_shader_parameter("color", Color(col, 0.6))
	elif k and k.state == "active" and k.runner.is_ready("k1") and k.ready_to_fight():
		# your kin's ability lands at the cursor, as far as it can reach from the kin: a faint ring
		# shows where it would go (clamped to its reach) so cursor distance reads as range
		var kd: AbilitySpec = k.runner.def_of("k1")
		if kd:
			var spec: Array = KinText.aim(k.effective("k1"))
			if String(spec[0]) == "area":
				var from_p: Vector3 = k.pos if kd.from == "kin" else at
				var t2 := Vector2(aim.x - from_p.x, aim.z - from_p.z)
				var reach := float(spec[1])
				var clamped := t2.length() > reach
				if clamped:
					t2 = t2.normalized() * reach
				var g2 := world.ground_at(from_p.x + t2.x, from_p.z + t2.y)
				if g2 > World.VOID + 1.0:
					aim_ring.visible = true
					aim_ring.global_position = Vector3(from_p.x + t2.x, g2 + 0.06, from_p.z + t2.y)
					aim_ring.scale = Vector3.ONE * maxf(0.6, float(spec[2]) / 0.6)
					aim_ring.material_override.set_shader_parameter("color", Color(KinText.color(kd), 0.35 if clamped else 0.22))
	if not (k and k.state == "active"):
		aim_ring.scale = Vector3.ONE
	if p.muzzle_t > 0.0:
		var dir2 := p.aim_dir()
		muzzle_light.global_position = Vector3(at.x + dir2.x * 0.8, at.y + 1.0, at.z + dir2.y * 0.8)
		muzzle_light.light_energy = 2.2
