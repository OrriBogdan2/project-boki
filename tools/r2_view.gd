extends "res://tools/clip_shots.gd"
## --r2-view --shots-dir=<dir> [--wardens=dolm,rimewright,dredge] [--size=640] [--tag=x]: the player's view of a Hunter
## model with its animation playing, 30 fps JPG frames at the match camera (66 degrees, 23 m, narrow fov), in the game's
## own Models.hunter + WardenClips path. <dir>/<id>/f0000.jpg ...; timeline (s): idle 0-3, run 3-6, attack 1 6-8,
## attack 2 8-10. <dir>/<id>/marks.txt: first frame of each part and the attack contact frames (fastest hand).
## <dir>/<id>/true_cam.jpg: one frame at the game's real fov 32. Needs a renderer.

const DT := 1.0 / 30.0
const RUN_MPS := 5.0
const SIDE_YAW := -PI / 2.0
var THREE_Q_YAW := -PI / 2.0 - 0.55
const ATTACKS := {"dolm": ["lmb_throw", "lmb_punch"], "dredge": ["shot", "throw"], "rimewright": ["dart_r", "spear"]}
const POST_COUNT := 14
const POST_SPACING := 0.5

var posts: Array = []
var close := false

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = ["dolm", "rimewright", "dredge"]
	frame_px = 640
	if OS.get_cmdline_user_args().has("--close"):
		THREE_Q_YAW = SIDE_YAW
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--size="): frame_px = int(a.substr(7))
		if a == "--close": close = true
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	_match_cam()
	_posts()
	for id in ids:
		await _hunter(String(id), out.path_join(String(id)))
	print("R2_VIEW_DONE ", ids.size())
	tree.quit()

func _match_cam() -> void:
	if close:
		var k := 1.2
		cam.fov = 14.0
		cam.position = Vector3(0, 1.0 * k, 12.0 * k)
		cam.look_at(Vector3(0, 1.0 * k, 0))
		return
	cam.fov = 8.0
	cam.position = Vector3(0, 21.0, 9.4)
	cam.look_at(Vector3(0, 0.8, 0))

func _posts() -> void:
	var mat := Models.toon(Color("1c2a14"), false)
	for i in POST_COUNT:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.02, 0.5)
		post.mesh = box
		post.material_override = mat
		post.position = Vector3((i - POST_COUNT / 2.0) * POST_SPACING, 0.01, 0.35)
		holder.add_child(post)
		posts.append(post)

func _scroll(mps: float) -> void:
	var span := POST_COUNT * POST_SPACING
	for p in posts:
		p.position.x = fposmod((p as Node3D).position.x - mps * DT + span / 2.0, span) - span / 2.0

func _save(dir: String, i: int) -> void:
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_jpg(dir.path_join("f%04d.jpg" % i), 0.93)

func _hunter(id: String, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	for k in 25:
		await tree.process_frame
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var sk := WardenGlb.skeleton(model.get_node("Warden"))
	var hands := [WardenSkeleton.find(sk, "hand.R"), WardenSkeleton.find(sk, "hand.L")]
	var marks: PackedStringArray = []
	var n := 0
	# idle, 3 s
	model.rotation.y = THREE_Q_YAW
	model.set_meta(WardenClips.STATE, {"vel": Vector3.ZERO, "face": THREE_Q_YAW, "grounded": true})
	for k in 20:
		sync.call("_process", DT)
	marks.append("idle %d" % n)
	for i in 90:
		sync.call("_process", DT)
		await _save(dir, n)
		n += 1
	# run, 3 s (the game's locomotion hand-off: the state carries the speed)
	model.rotation.y = SIDE_YAW
	var fw := Vector3(1, 0, 0)
	model.set_meta(WardenClips.STATE, {"vel": fw * RUN_MPS, "face": SIDE_YAW, "grounded": true})
	for k in 20:
		sync.call("_process", DT)
		_scroll(RUN_MPS)
	marks.append("run %d" % n)
	for i in 90:
		sync.call("_process", DT)
		_scroll(RUN_MPS)
		await _save(dir, n)
		n += 1
	# two attacks, 2 s each, standing, the keyed clip as the game plays it
	model.rotation.y = THREE_Q_YAW
	for ai in 2:
		var clip: String = ATTACKS[id][ai]
		model.set_meta(WardenClips.STATE, {"vel": Vector3.ZERO, "face": THREE_Q_YAW, "grounded": true})
		clips.force = {}
		for k in 15:
			sync.call("_process", DT)
		var length := clips.lib.get_animation(clip).length
		marks.append("atk%d %d %s len=%.2f" % [ai + 1, n, clip, length])
		var best := 0.0
		var best_i := n
		var prev: Array = []
		for i in 60:
			clips.force = {"clip": clip, "t": minf(fmod(i * DT, length + 0.3), length - 0.001)}
			sync.call("_process", DT)
			var cur: Array = []
			for h in hands:
				cur.append(sk.global_transform * sk.get_bone_global_pose(h).origin)
			if not prev.is_empty():
				var sp := 0.0
				for j in cur.size():
					sp = maxf(sp, (cur[j] as Vector3).distance_to(prev[j]))
				if sp > best and i * DT < length:
					best = sp
					best_i = n
			prev = cur
			await _save(dir, n)
			n += 1
		marks.append("atk%d_contact %d" % [ai + 1, best_i])
		clips.force = {}
	model.set_meta(WardenClips.STATE, {})
	# one frame at the game's real fov
	model.rotation.y = THREE_Q_YAW
	cam.fov = 32.0
	cam.position = Vector3(0, 23.0 * sin(deg_to_rad(66.0)), 23.0 * cos(deg_to_rad(66.0)))
	cam.look_at(Vector3(0, 0.8, 0))
	sync.call("_process", DT)
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_jpg(dir.path_join("true_cam.jpg"), 0.93)
	_match_cam()
	var f := FileAccess.open(dir.path_join("marks.txt"), FileAccess.WRITE)
	f.store_string("\n".join(marks) + "\n")
	f.close()
	model.queue_free()
