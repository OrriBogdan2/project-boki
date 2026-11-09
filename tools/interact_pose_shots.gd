extends RefCounted
## --interact-pose-shots --shots-dir=<dir> [--wardens=a,b,c]: strips of the interact beats in a real match, one row per
## Hunter (Albert, Cinder and Sable by default): the lift (press, reach, lift, settle) and a chest's hold, then walking
## off. <dir>/interact_strip.png. Needs a renderer.

const DT := 1.0 / 60.0
const SIZE := 300
const LIFT_AT := [0.0, 0.14, 0.28, 0.45, 0.62, 0.8]      # s after the press
const CHEST_AT := 0.5          # s into the chest hold
const CAM_DIST := 3.4          # in head heights
const CAM_HEIGHT := 0.5        # of the head height: the look point over the feet
const CAM_RISE := 0.7          # the camera sits above, looking down past the grass
const YAW := -2.4              # rad: three-quarter front

var tree: SceneTree
var cam: Camera3D
var vp: SubViewport            # its own view of the match world: no HUD in the strip

func _frame(m: Match, h: Hunter) -> void:
	m.step(DT)
	h.render(DT, 1.0)
	var sync: Node = h.model.get_node("Warden/Sync")
	sync.set_process(false)
	sync.call("_process", DT)

func _grab() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)      # the viewport's own format differs per renderer
	return img

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = ["bulwark", "ashwick", "thief"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--wardens="):
			ids = Array(a.substr(10).split(",", false))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var cols := LIFT_AT.size() + 2
	var strip := Image.create(SIZE * cols, SIZE * ids.size(), false, Image.FORMAT_RGBA8)
	for row in ids.size():
		var r: Array = A.setup(String(ids[row]), 11.0, "", true)
		var m: Match = r[0]
		var h: Hunter = r[1]
		vp = SubViewport.new()
		vp.size = Vector2i(SIZE, SIZE)
		vp.world_3d = main.get_viewport().world_3d
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		main.add_child(vp)
		cam = Camera3D.new()
		vp.add_child(cam)
		cam.fov = 26.0
		cam.make_current()
		h.face = YAW
		for g in m.find_children("*", "MultiMeshInstance3D", true, false):
			if String(g.name).begins_with("Grass") or String(g.name).begins_with("Bushes"):
				g.visible = false     # the strip shows knees and hands, not the lawn in front of them
		for f in 40:
			_frame(m, h)
			await tree.process_frame
		var c := 0
		var sk := h.model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var head := sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, "head")).origin
		var tall := maxf(head.y - h.global_position.y, 0.8)
		var look := h.global_position + Vector3(0, CAM_HEIGHT * tall, 0)
		var fwd := -h.model.global_transform.basis.z      # in front of the face, whichever way the model's front is
		if h.model.global_transform.basis.z.dot(Vector3(sin(YAW), 0, cos(YAW))) > 0.0:
			fwd = -fwd
		fwd = fwd.rotated(Vector3.UP, 0.6)                 # three-quarter
		cam.global_position = look + (fwd + Vector3(0, CAM_RISE, 0)) * CAM_DIST * tall
		cam.look_at(look)
		var t := 0.0
		h.set_hold("lift", HunterAnim.LIFT_T)
		for at in LIFT_AT:
			while t < float(at) - 0.001:
				_frame(m, h)
				t += DT
			await tree.process_frame
			strip.blit_rect(await _grab(), Rect2i(0, 0, SIZE, SIZE), Vector2i(SIZE * c, SIZE * row))
			c += 1
		for f in 40:
			_frame(m, h)
		t = 0.0
		while t < CHEST_AT:
			h.set_hold("chest", 0.15)
			_frame(m, h)
			t += DT
		await tree.process_frame
		strip.blit_rect(await _grab(), Rect2i(0, 0, SIZE, SIZE), Vector2i(SIZE * c, SIZE * row))
		c += 1
		h.vel = Vector3(4, 0, 0)
		for f in 6:
			h.vel = Vector3(4, 0, 0)
			_frame(m, h)
		await tree.process_frame
		strip.blit_rect(await _grab(), Rect2i(0, 0, SIZE, SIZE), Vector2i(SIZE * c, SIZE * row))
		vp.queue_free()
		m.queue_free()
	strip.save_png(out.path_join("interact_strip.png"))
	print("INTERACT_SHOTS_DONE")
	tree.quit()
