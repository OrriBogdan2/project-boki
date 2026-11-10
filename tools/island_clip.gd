extends RefCounted
## --island-clip --shots-dir=<dir>: GPU before/after media for the deep islands (IslandDepth). On the
## tier-0 match map (three islands) and the Training Area (one): a hunter glides in under the rim,
## steers into the side and climbs up, at the match camera, 12 fps (<dir>/<where>_<n>/f000.png...);
## a side view of each map's islands (<dir>/silhouette_<where>.png); and the frame time with the
## match camera over an island edge ("ICLIP perf"). Runs on builds without IslandDepth too (the
## before clips), so it reads the underside through World.under when it's there. Needs a renderer.

const STEPS_PER_FRAME := 5       # 60 Hz steps per 12 fps frame
const CLIP_S := 3.5

var main: Node
var dir := "user://island_clip"
var chk

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	const CHK := "res://tools/island_depth_check.gd"
	chk = load(CHK).new() if ResourceLoader.exists(CHK) else null
	await _map({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true}, "match", 3)
	await _map(Match.arena_opts(), "training", 1)
	print("ICLIP DONE")
	main.get_tree().quit()

func _map(o: Dictionary, where: String, want: int) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var h: Hunter = m.hunters[0]
	for o2 in m.hunters:
		o2.ctrl = "idle"
	h.ctrl = "local"
	m.opts["god"] = true
	if m.hud: m.hud.visible = false
	for i in 30: m.step(Match.DT)
	var edges := _edges(m.world)
	var done := {}
	for e in edges:
		if done.has(e["isl"]) or done.size() >= want: continue
		done[e["isl"]] = true
		await _clip(m, h, e, dir.path_join("%s_%d" % [where, done.size()]))
	if not edges.is_empty():
		await _perf(m, h, edges[0], where)
		await _silhouette(m, edges[0], where)
	m.queue_free()
	await main.get_tree().process_frame

## Rims with open air out past them (island_depth_check's, when this build has it).
func _edges(w: World) -> Array:
	if chk: return chk._edges(w, 40)
	var out: Array = []
	for k in 4000:
		if out.size() >= 40: break
		var g := w.random_ground()
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var open := true
			for dd in [1.1, 2.0, 3.0, 4.0, 5.0]:
				if not w.is_void(g.x + d.x * dd, g.z + d.y * dd): open = false
			if not open or w.is_void(g.x, g.z): continue
			var ex := g.x
			var ez := g.z
			while not w.is_void(ex + d.x * 0.25, ez + d.y * 0.25):
				ex += d.x * 0.25
				ez += d.y * 0.25
			var top := w.ground_at(g.x, g.z)
			var isl := w.island[w.idx(int(floor(g.x)), int(floor(g.z)))]
			out.append({"ex": ex, "ez": ez, "dir": d, "top": top, "rock": top - 3.0, "isl": isl})
			break
	return out

## Glide in under rim e toward the island, steering into its side; the camera follows.
func _clip(m: Match, h: Hunter, e: Dictionary, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var d: Vector2 = e["dir"]
	var y0: float = float(e["rock"]) - 2.0      # under the rim tile's rock
	h.out = false
	h.downed = false
	h.hp = h.max_hp
	h.teleport(Vector3(e["ex"] - d.x * 0.25, y0, e["ez"] - d.y * 0.25))
	h.grounded = false
	h.vel = Vector3(-d.x * 4.0, 0.0, -d.y * 4.0)
	h.lfloat = {}
	h.pad = {}
	h.grap = {}
	h.grap_cd = 0.0
	h.gliding = true
	h.glide_fuel = 1.0
	h.last_gy = e["top"]
	h.kb_t = -9.0
	for i in 8: await _frame(m, h)
	var t := 0.0
	var n := 0
	var climbed := false
	var landed := false
	while t < CLIP_S:
		for s in STEPS_PER_FRAME:
			# Once up and standing on top, let go of the stick: the Training Area pad is only a
			# few metres across, so holding on would walk the hunter off its far side.
			landed = landed or (climbed and h.grounded and h.pos.y > float(e["top"]) - 0.9)
			h.inp["move"] = Vector2.ZERO if landed else -d
			h.inp["glide"] = not h.mantling() and not landed
			h.inp["aim"] = h.pos + Vector3(-d.x * 4.0, 0.9, -d.y * 4.0)
			m.step(Match.DT)
			t += Match.DT
			if h.mantling(): climbed = true
		await _frame(m, h)
		m.get_viewport().get_texture().get_image().save_png(out.path_join("f%03d.png" % n))
		n += 1
	var on_top := h.grounded and h.pos.y > float(e["top"]) - 0.9
	print("ICLIP %s start %.1fm under the top, climbed %s, on top %s (%d frames)"
			% [out.get_file(), float(e["top"]) - y0, climbed, on_top, n])

## The frame time with the match camera on an island edge: 240 frames, vsync off.
func _perf(m: Match, h: Hunter, e: Dictionary, where: String) -> void:
	h.teleport(Vector3(e["ex"] - (e["dir"] as Vector2).x * 2.0, e["top"], e["ez"] - (e["dir"] as Vector2).y * 2.0))
	h.grounded = true
	h.vel = Vector3.ZERO
	h.gliding = false
	h.lfloat = {}
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for i in 30: await _frame(m, h)
	var t0 := Time.get_ticks_usec()
	var prims := 0.0
	for i in 240:
		await _frame(m, h)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var ms := (Time.get_ticks_usec() - t0) / 240000.0
	print("ICLIP perf %s: %.2f ms a frame, %.0f primitives drawn" % [where, ms, prims / 240.0])

## A side view of the island behind rim e, from out over the abyss, a little below its top.
func _silhouette(m: Match, e: Dictionary, where: String) -> void:
	var d: Vector2 = e["dir"]
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 600.0
	m.add_child(cam)
	var at := Vector3(e["ex"] - d.x * 6.0, float(e["top"]) - 8.0, e["ez"] - d.y * 6.0)
	cam.position = at + Vector3(d.x * 42.0, 2.0, d.y * 42.0) + Vector3(d.y, 0, -d.x) * 14.0
	cam.look_at(at)
	cam.current = true
	for i in 6: await main.get_tree().process_frame
	m.get_viewport().get_texture().get_image().save_png(dir.path_join("silhouette_%s.png" % where))
	cam.queue_free()

## Draws one frame without stepping the match: the camera and the models catch up.
func _frame(m: Match, h: Hunter) -> void:
	var span := STEPS_PER_FRAME * Match.DT
	if m.cam and m.player:
		Input.warp_mouse(m.cam.unproject_position(h.pos))
	m.hitstop = 0.0
	m.slowmo = 0.0
	m.acc = Match.DT * 0.999 - DashPace.frame_dt(m, span)
	m._process(span)
	await main.get_tree().process_frame
