extends "res://tools/clip_shots.gd"
## --stomp-shots --shots-dir=<dir> [--wardens=a,b] [--size=240]: every Hunter's own stomp (StompLook, content/rules/
## stomps.json) on its 3D model, seen from the side and a little in front, through one beat of Stomp: <dir>/<id>/
## fNNN.png at the beat phases in PHASES. Each strip has its wind-up, its top and the hit at the same frames (the hit
## is Stomp.SLAM), so a sheet of all 13 shows the looks differ and the impacts line up.
## Needs a renderer (jobq submit --needs gpu).

const PHASES := [0.0, 0.2, 0.4, 0.52, 0.66, 0.8, 0.9]
const DT := 1.0 / 60.0
const YAW := -PI / 2.0 + 0.45     # facing screen right, turned a little toward the camera
const SPLASH_FRAMES := 150        # frames the title splash stays over the first shots

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = Arch.ORDER.duplicate()
	frame_px = 240
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--size="): frame_px = int(a.substr(7))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	cam.fov = 16.0
	for k in SPLASH_FRAMES:
		await tree.process_frame
	for id in ids:
		await _hunter(String(id), out.path_join(String(id)))
	print("STOMP_SHOTS_DONE ", ids.size())
	tree.quit()

func _hunter(id: String, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	model.rotation.y = YAW
	for k in 20:
		await tree.process_frame
	var sync := model.get_node_or_null("Warden/Sync")
	if sync:
		sync.set_process(false)
	_frame(model)
	var anim := HunterAnim.new(model)
	var state := {"stomp": 0.0, "stomp_style": StompLook.default_for(id), "grounded": true, "face": YAW}
	# a beat and a bit to settle into the pose, then one beat, shot at each phase
	var beat := 0.0
	var per_s := float(Stomp.BEATS) / Stomp.TIME
	for i in PHASES.size():
		var want := 1.0 + float(PHASES[i])
		while beat < want - 0.0001:
			beat = minf(beat + DT * per_s, want)
			state["stomp"] = beat
			anim.update(DT, state)
			if sync:
				sync.call("_process", DT)
		await _grab(dir.path_join("f%03d.png" % i))
	model.queue_free()
	await tree.process_frame

## The camera on the model's drawn bounds, with room above for a raised weapon or a hop.
func _frame(model: Node3D) -> void:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var vi := mi as MeshInstance3D
		if not vi.is_visible_in_tree() or vi.mesh == null:
			continue
		var b := vi.global_transform * vi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var tall := maxf(box.size.y, 1.0) * 1.6
	var mid := Vector3(0, box.size.y * 0.6, 0)
	cam.position = mid + Vector3(0, 0.15 * tall, tall / (2.0 * tan(deg_to_rad(cam.fov) * 0.5)))
	cam.look_at(mid)
