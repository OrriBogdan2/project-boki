extends RefCounted
## --hunter-diag-shots --shots-dir=<dir> [--wardens=bulwark,archer,...] (hero ids; default all 13): per Hunter, under
## <dir>/<art name>/: bind_*.png (the skeleton reset to its rest, no clip, no retarget) and idle_*.png (the game's idle:
## HunterAnim + clips + Sync) each as _3q, _side (close) and _match (the match camera, true pixels). Prints
## DIAG_SCALE lines: the largest scale a bone's pose puts on its rest (1 = none), bind and idle, and the model's scale.
## Diagnosis only (job 20261119-145816-a5, hunter stretch). Needs a renderer.

const CAM_PITCH := 66.0
const CAM_DIST := 23.0
const CAM_FOV := 32.0

var holder: Node3D
var cam: Camera3D
var tree: SceneTree

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := "/tmp/hunter_diag"
	var ids: Array = WardenGlb.ART.keys()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(","))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	_stage(main)
	for id in ids:
		await _hero(String(id), out.path_join(String(WardenGlb.ART[id])))
	print("HUNTER_DIAG_DONE")
	tree.quit()

func _stage(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"), "stars": 0.0})
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 60)
	ground.mesh = pm
	ground.material_override = Models.toon(Color("4f7a3e"), false)
	holder.add_child(ground)
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.make_current()

func _hero(id: String, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var h := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	holder.add_child(h)
	var anim := HunterAnim.new(h)
	var w := h.get_node_or_null("Warden")
	var sk: Skeleton3D = WardenGlb.skeleton(w) if w else null
	print("DIAG_MODEL %s scale=%s warden_scale=%s" % [id, h.scale, (w as Node3D).scale if w else "-"])
	h.rotation.y = PI * 0.75
	for k in 90:
		anim.update(1.0 / 60.0, {"fired": 99.0, "face": h.rotation.y, "grounded": true})
		await tree.process_frame
	await _shots(h, dir, "idle")
	print("DIAG_SCALE %s idle %s" % [id, _scale_dev(sk)])
	# bind: nothing drives the bones any more, the skeleton back on its rest
	var sync := w.get_node_or_null("Sync") if w else null
	if sync:
		sync.set_process(false)
	for m in h.find_children("*", "AnimationMixer", true, false):
		(m as AnimationMixer).active = false
	if sk:
		sk.reset_bone_poses()
	for k in 4:
		await tree.process_frame
	await _shots(h, dir, "bind")
	print("DIAG_SCALE %s bind %s" % [id, _scale_dev(sk)])
	h.queue_free()
	await tree.process_frame

## The biggest departure of a bone's global pose from its rest: "max_axis_scale bone | min_axis_scale bone".
func _scale_dev(sk: Skeleton3D) -> String:
	if sk == null:
		return "no skeleton"
	var hi := 1.0
	var lo := 1.0
	var hib := ""
	var lob := ""
	for b in sk.get_bone_count():
		var d := sk.get_bone_global_pose(b).basis * sk.get_bone_global_rest(b).basis.inverse()
		var s := d.get_scale()
		var mx := maxf(s.x, maxf(s.y, s.z))
		var mn := minf(s.x, minf(s.y, s.z))
		if mx > hi:
			hi = mx
			hib = sk.get_bone_name(b)
		if mn < lo:
			lo = mn
			lob = sk.get_bone_name(b)
	return "max %.2f %s | min %.2f %s" % [hi, hib, lo, lob]

func _grab() -> Image:
	await tree.process_frame
	await tree.process_frame
	var img := tree.root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func _shots(h: Node3D, dir: String, tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		return      # (no pixels: the DIAG_ lines still print)
	var tall := 2.0
	for vi in h.find_children("*", "VisualInstance3D", true, false):
		var v := vi as VisualInstance3D
		if v.is_visible_in_tree() and not (v is Light3D):
			tall = maxf(tall, (v.global_transform * v.get_aabb()).end.y)
	for yaw in [["3q", PI * 0.75], ["side", PI * 0.5]]:
		h.rotation.y = float(yaw[1])
		cam.fov = 30.0
		cam.position = Vector3(0, tall * 0.5, (tall * 0.5 + 0.3) / tan(deg_to_rad(15.0)))
		cam.rotation = Vector3(-0.02, 0, 0)
		var img := await _grab()
		var half := img.get_height() * 3 / 4
		img.get_region(Rect2i((img.get_width() - half) / 2, 0, half, img.get_height())).save_png(dir.path_join("%s_%s.png" % [tag, yaw[0]]))
	h.rotation.y = PI * 0.75
	var p := deg_to_rad(CAM_PITCH)
	cam.fov = CAM_FOV
	cam.position = Vector3(0, 1.0, 0) + Vector3(0, sin(p), cos(p)) * CAM_DIST
	cam.rotation = Vector3(-p, 0, 0)
	var img2 := await _grab()
	var a := cam.unproject_position(Vector3(-1.4, 3.0, -1.0))
	var b := cam.unproject_position(Vector3(1.4, -0.3, 1.6))
	img2.get_region(Rect2i(Vector2i(a), Vector2i(b - a))).save_png(dir.path_join("%s_match.png" % tag))
