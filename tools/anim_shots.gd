extends RefCounted
## --anim-shots --warden=<id> --shots-dir=<dir> [--state=stomp|revive|drink|all] [--variant=new|proc] [--size=480]
## [--fov=30] [--grab=n,n]: a Hunter doing one of the three shared actions, driven through the game state (HunterAnim,
## then WardenClips) as Hunter hands it over: stomp (three Life.R stomp_cycles, the slam at 0.7 of each), revive
## (the kneel loop, 2 s) and drink (Hunter.DRINK_TIME): <dir>/<variant>/<state>/f000.png... at 15 fps.
## new: the clips. proc: the rig's procedural pose retargeted on this model. Needs a renderer.

const DT := 1.0 / 30.0
const CAM_Y := 1.0

var tree: SceneTree
var cam: Camera3D
var px := 480

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var id := "thief"
	var variant := "new"
	var which := "all"
	var fov := 30.0
	var grab: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--warden="): id = a.substr(9)
		if a.begins_with("--variant="): variant = a.substr(10)
		if a.begins_with("--state="): which = a.substr(8)
		if a.begins_with("--size="): px = int(a.substr(7))
		if a.begins_with("--fov="): fov = float(a.substr(6))
		if a.begins_with("--grab="): grab = Array(a.substr(7).split(",", false)).map(func(x): return int(x))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(px, px)
	main.get_viewport().size = Vector2i(px, px)
	var holder := _stage(main)
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var yaw := deg_to_rad(-125.0)
	model.rotation.y = yaw
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	var anim := HunterAnim.new(model)
	for k in 30:
		await tree.process_frame
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	if variant == "proc" and clips:
		clips.force = {"proc": true}
	cam.fov = fov
	# (framed on what is shown: a big Hunter, Albert's barrel, steps the camera back so the stomp foot stays in shot)
	var box := _shown_box(model)
	var cy := maxf(CAM_Y, box.get_center().y) if box.size.y > 0.0 else CAM_Y
	var dist := maxf(5.5, box.size.y * 1.35 / tan(deg_to_rad(fov) * 0.5) * 0.5)
	cam.position = Vector3(0, cy + 0.3, dist)
	cam.look_at(Vector3(0, cy, 0))
	var cycle: float = Life.R["stomp_cycle"]
	var lens := {"stomp": cycle * 3.0, "revive": 2.0, "drink": Hunter.DRINK_TIME}
	for st in lens:
		if which != "all" and which != st:
			continue
		var dir := out.path_join(variant).path_join(st)
		DirAccess.make_dir_recursive_absolute(dir)
		var t := 0.0
		var i := 0
		var step := 0
		while t < float(lens[st]):
			var s := {"vel": Vector3.ZERO, "face": yaw, "grounded": true, "crouch": 0.0, "fired": 99.0}
			match st:
				"stomp": s["stomp"] = fmod(t, cycle) / cycle
				"revive": s["reviving"] = true
				"drink": s["drink"] = t / Hunter.DRINK_TIME
			anim.update(DT, s)
			sync.call("_process", DT)
			t += DT
			if step % 2 == 0 and (grab.is_empty() or i in grab):
				await _grab(dir.path_join("f%03d.png" % i))
			if step % 2 == 0:
				i += 1
			step += 1
		print("ANIM_SHOTS %s %s %d" % [id, st, i])
	print("ANIM_SHOTS_DONE")
	tree.quit()

func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(path)

func _stage(main: Node) -> Node3D:
	var holder := Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"),
		"stars": 0.0})
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
	return holder

## The world box of the meshes shown under n (zero size: none).
func _shown_box(n: Node) -> AABB:
	var box := AABB()
	var any := false
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.is_visible_in_tree() or m.mesh == null:
			continue
		var b := m.global_transform * m.get_aabb()
		box = b if not any else box.merge(b)
		any = true
	return box
