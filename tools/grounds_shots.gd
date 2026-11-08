extends RefCounted
## --grounds-shots --shots-dir=<dir> [--perf-secs=4]: the Training Grounds (the --arena map) on a real GPU
## (jobq submit --needs gpu): a top-down overview, ground-level shots at the start, in the Training Room and on
## each sky perch, and frame-time numbers at the start and on a perch (GROUNDSPERF lines: wall ms, GPU ms, CPU ms,
## draws, tris, objects, nodes). Also runs on the old Arena for the before number (no stations then).
## Software GL is no judge of any of this: only read the numbers from a real GPU.

const DT := 1.0 / 60.0
const VIEW := Vector2i(1280, 720)

var main: Node
var m: Match
var dir := "/tmp/grounds_shots"
var perf_secs := 4.0
var n := 0
var vp: RID

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
		if String(a).begins_with("--perf-secs="): perf_secs = float(String(a).substr(12))
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = VIEW
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	vp = main.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	m = Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts("gunslinger"))
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)
	var A: Arena = m.arena
	var P: Hunter = m.player
	await _perf("start")
	await _ground("start")
	P.teleport(A.home + Vector3(0, 0, -9.0))
	await _ground("room")
	var G = A.get("grounds")         # (untyped: the old Arena has none, for the before numbers)
	if G != null:
		await _overview()
		var seen := {}
		for s in G.stations:
			if seen.has(s["kind"]):
				continue
			seen[s["kind"]] = true
			var c: Vector3 = s["c"]
			P.teleport(Vector3(c.x, m.world.ground_at(c.x, c.z + 1.5), c.z + 1.5))      # in the ring, on the perch
			P.vel = Vector3.ZERO
			await _ground("perch_" + String(s["kind"]))
			if s["kind"] == "arch":
				await _perf("perch")
	print("GROUNDSSHOTS %d in %s" % [n, dir])
	main.get_tree().quit(0)

func _frames(k: int) -> void:
	for i in k:
		m.step(DT)
		await main.get_tree().process_frame

func _ground(what: String) -> void:
	m.cam.snap(m.player.pos)
	await _frames(20)
	m.cam.snap(m.player.pos)
	await _save(what)

## A camera of its own, straight down over the whole map.
func _overview() -> void:
	var cam := Camera3D.new()
	cam.fov = 45.0
	cam.near = 1.0
	cam.far = 600.0
	m.add_child(cam)
	cam.global_position = Vector3(72, 175, 72.5)
	cam.rotation = Vector3(-PI / 2.0, 0, 0)
	cam.current = true
	await _frames(10)
	await _save("topdown")
	cam.current = false
	m.cam.current = true
	cam.queue_free()
	await _frames(2)

func _save(what: String) -> void:
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	n += 1
	img.save_png(dir.path_join("%02d_%s.png" % [n, what]))

func _perf(where: String) -> void:
	await _frames(30)
	var frames := int(perf_secs * 60.0)
	var t0 := Time.get_ticks_usec()
	var gpu := 0.0
	var cpu := 0.0
	var draws := 0
	var tris := 0
	var objs := 0
	for i in frames:
		m.step(DT)
		await main.get_tree().process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		draws += int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		tris += int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		objs += int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	var wall := float(Time.get_ticks_usec() - t0) / 1000.0 / float(frames)
	var line := "GROUNDSPERF %-6s wall %.2f ms  gpu %.2f ms  cpu %.2f ms" % [where, wall, gpu / frames, cpu / frames]
	line += "  draws %d  tris %d  objs %d" % [draws / frames, tris / frames, objs / frames]
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	line += "  nodes %d  (%s)" % [nodes, RenderingServer.get_video_adapter_name()]
	print(line)
