extends RefCounted
## --hunter-gpu-bench [--wardens=gunslinger,ashwick] [--tiers=n,25k,40k] [--bench-secs=8]: what the Hunter models
## cost to draw. Six Hunters (the list, repeated) and four Boki play their idle at the match camera under the
## game's light; one line per round with the mean GPU and CPU render time per frame, the frame time with no cap,
## draws and triangles. The first round is the shipped models; each tier is a round with the design variants
## art/wardens/<art>_<tier>/ (the detail pilot's 25k and 40k meshes), so one run compares them on one machine.
## Needs a real GPU:  jobq submit --tree . --needs gpu -- --hunter-gpu-bench --tiers=n,25k,40k

const HUNTERS := 6
const BOKI := 4
const GAP := 1.9              # m between models in a row
const WARMUP := 90            # frames before measuring: shaders compile, the first frames upload meshes
const CAM_PITCH := 66.0       # degrees: the default match camera (CamRig STYLES "supervive")
const CAM_DIST := 23.0
const CAM_FOV := 32.0

func run(main: Node) -> void:
	var tree := main.get_tree()
	var wardens := ["gunslinger", "ashwick"]
	var tiers: Array = [""]
	var secs := 8.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wardens="): wardens = Array(a.substr(10).split(","))
		if a.begins_with("--tiers="): tiers.append_array(a.substr(8).split(","))
		if a.begins_with("--bench-secs="): secs = float(a.substr(13))
	Save.no_write = true
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var view := main.get_viewport()
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
	print("HUNTER_GPU_BENCH view=%s quality=%s renderer=%s adapter=%s" % [view.size, Settings.quality(),
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	var arts := wardens.map(func(id): return String(WardenGlb.ART.get(id, id)))
	for tier in tiers:
		WardenGlb._variants = {}      # the round's models: what --warden-variant= would pick
		for art in arts:
			if tier != "": WardenGlb._variants[art] = "%s_%s" % [art, tier]
		var holder := _stage(main)
		var anims := _cast(holder, wardens)
		var sum := await _measure(tree, view.get_viewport_rid(), anims, secs)
		var models := ",".join(wardens.map(func(id): return WardenGlb.art(String(id))))
		print("HUNTER_GPU_BENCH models=%s frames=%d gpu_ms=%.3f render_cpu_ms=%.3f frame_ms=%.3f draws=%.0f tris=%.0f"
			% [models, sum["frames"], sum["gpu"], sum["cpu"], sum["wall"], sum["draws"], sum["tris"]])
		holder.queue_free()
		await tree.process_frame
	tree.quit()

## Six Hunters in a row facing the camera and four Boki in front: [HunterAnim, Hunter model] per Hunter.
func _cast(holder: Node3D, wardens: Array) -> Array:
	var anims: Array = []
	for i in HUNTERS:
		var id := String(wardens[i % wardens.size()])
		WardenGlb.set_model(id, true)
		var h := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
		h.position = Vector3((i - (HUNTERS - 1) * 0.5) * GAP, 0, 0)
		h.rotation.y = PI
		holder.add_child(h)
		anims.append([HunterAnim.new(h), h])
	var species := KinLib.kin_ids()
	for i in BOKI:
		var k := Models.kin(String(species[i]), {"level": 3})
		k.position = Vector3((i - (BOKI - 1) * 0.5) * GAP, 0, 2.0)
		holder.add_child(k)
	return anims

## The means per frame over `secs`, after the warm-up: gpu, cpu and wall in ms, draws, tris; and the frame count.
func _measure(tree: SceneTree, vp: RID, anims: Array, secs: float) -> Dictionary:
	var sum := {"gpu": 0.0, "cpu": 0.0, "wall": 0.0, "draws": 0.0, "tris": 0.0}
	var frames := 0
	var last := Time.get_ticks_usec()
	var until := 0
	while until == 0 or Time.get_ticks_msec() < until:
		for a in anims:
			var face := (a[1] as Node3D).rotation.y
			(a[0] as HunterAnim).update(1.0 / 60.0, {"fired": 99.0, "face": face, "grounded": true})
		await tree.process_frame
		var now := Time.get_ticks_usec()
		frames += 1
		if frames == WARMUP:
			until = Time.get_ticks_msec() + int(secs * 1000.0)
		elif frames > WARMUP:
			sum["gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			sum["cpu"] += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			sum["wall"] += (now - last) / 1000.0
			sum["draws"] += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			sum["tris"] += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		last = now
	for key in sum:
		sum[key] /= float(frames - WARMUP)
	sum["frames"] = frames - WARMUP
	return sum

## The shot tools' stage: the game's sky, sun and shadows, a ground, the match camera on the rows.
func _stage(main: Node) -> Node3D:
	var holder := Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"),
		"stars": 0.0})
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 60)
	ground.mesh = plane
	ground.material_override = Models.toon(Color("4f7a3e"), false)
	holder.add_child(ground)
	var cam := Camera3D.new()
	holder.add_child(cam)
	var pitch := deg_to_rad(CAM_PITCH)
	cam.fov = CAM_FOV
	cam.position = Vector3(0, 1.0, 1.0) + Vector3(0, sin(pitch), cos(pitch)) * CAM_DIST
	cam.rotation = Vector3(-pitch, 0, 0)
	cam.make_current()
	return holder
