extends RefCounted
## --boki-cost --sets=cindle,puddlet,zapple,pebbit/kestrike,cairnback,gibbelle,kestrike [--copies=1] [--secs=6]
## [--shots-dir=<dir>]: what a set of rigged Bokis costs to draw, set against set on the same GPU in one run. Each set
## stands with two hunters in the match camera at 1920x1080 and idles for --secs; --copies repeats the Bokis (a stress
## that lifts the cost out of the noise); "~id" is that species without its rigged model. One line per set: triangles
## and draw calls in the frame, GPU and CPU render time of that view (median), and the whole frame with vsync off.
## Needs a renderer (jobq submit --needs gpu).

const VIEW := Vector2i(1920, 1080)
const WARM_FRAMES := 30
const GAP := 1.5            # metres between Bokis, as the review sheets space them

var main: Node
var shots: RefCounted

func run(m: Node) -> void:
	main = m
	shots = (load("res://tools/boki_rig_shots.gd") as GDScript).new()
	shots.main = m
	var sets: Array = []
	var copies := 1
	var secs := 6.0
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sets="): sets = Array(a.substr(7).split("/"))
		if a.begins_with("--copies="): copies = int(a.substr(9))
		if a.begins_with("--secs="): secs = float(a.substr(7))
		if a.begins_with("--shots-dir="): out = a.substr(12)
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	print("BOKI_COST renderer=%s adapter=%s copies=%d" % [RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(), copies])
	await _measure("hunters only", [], 0, secs, "")
	for i in sets.size():
		var file := "" if out == "" else out.path_join("cost_%d.png" % i)
		await _measure(String(sets[i]), Array(String(sets[i]).split(",")), copies, secs, file)
	print("BOKI_COST_DONE")
	main.get_tree().quit()

func _measure(label: String, ids: Array, copies: int, secs: float, file: String) -> void:
	var vp: SubViewport = shots._stage(VIEW)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.fov = shots.MATCH_FOV
	var p := deg_to_rad(shots.MATCH_PITCH)
	cam.position = Vector3(0, sin(p), cos(p)) * shots.MATCH_DIST
	cam.rotation = Vector3(-p, 0, 0)
	var classes: Array = Data.CLASSES.keys()
	for i in 2:
		var h := Models.hunter(String(classes[i]), Data.TEAM_COLORS[i], String(Data.CLASSES[classes[i]]["weapon"]))
		vp.add_child(h)
		h.position = Vector3((i - 0.5) * 2.0, 0, 2.0)
	for c in copies:
		for i in ids.size():
			var k := _kin(String(ids[i]))
			vp.add_child(k)
			k.position = Vector3((i - (ids.size() - 1) * 0.5) * GAP, 0, -c * GAP)
			k.rotation.y = PI * 0.8
	var rid := vp.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for i in WARM_FRAMES:
		await RenderingServer.frame_post_draw
	var gpu: Array = []
	var cpu: Array = []
	var wall: Array = []
	var last := Time.get_ticks_usec()
	var stop := last + int(secs * 1e6)
	while last < stop:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		wall.append((now - last) / 1000.0)
		last = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
	var seen := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
	var tris := RenderingServer.viewport_get_render_info(rid, seen,
		RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	var draws := RenderingServer.viewport_get_render_info(rid, seen,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	print("BOKI_COST set=[%s] tris=%d draws=%d gpu_ms=%.3f cpu_ms=%.3f frame_ms=%.3f frame_p95_ms=%.3f frames=%d" % [
		label, tris, draws, _at(gpu, 0.5), _at(cpu, 0.5), _at(wall, 0.5), _at(wall, 0.95), wall.size()])
	if file != "":
		vp.get_texture().get_image().save_png(file)
	vp.queue_free()
	await main.get_tree().process_frame

## "~id" is the body the game draws for a species that has no rigged model.
func _kin(id: String) -> Node3D:
	if not id.begins_with("~"):
		return shots.rigged_kin(id)
	BokiRig.enabled = false
	var k := Models.kin(id.substr(1))
	BokiRig.enabled = true
	return k

func _at(values: Array, q: float) -> float:
	values.sort()
	return float(values[int((values.size() - 1) * q)])
