extends "res://tools/clip_shots.gd"
## --live-audit --shots-dir=<dir> [--wardens=a,b] [--size=1024] [--close]: audit render of every Hunter model as the
## game plays it (Models.hunter + WardenClips). Per hunter: <dir>/<id>/bind.jpg (rest pose, no clip), then f0000.. at
## 30 fps: idle 0-2 s, run 2-4 s, first attack 4-5.5 s. marks.txt has the part starts and the attack contact frame.
## Match camera (default; fov 8 at 23 m, 66 deg) or --close (4 m, 3/4, fov set so the hunter fills 60% of the frame).

const DT := 1.0 / 30.0
const RUN_MPS := 5.0
const SIDE_YAW := -PI / 2.0
const THREE_Q_YAW := -PI / 2.0 - 0.55
const ATTACKS := {"archer": "loose", "juggernaut": "slash_r", "gunslinger": "lmb", "bulwark": "lmb_throw",
	"rimewright": "dart_r", "ashwick": "lance", "dolm": "lmb_throw", "mage": "lmb_l", "dredge": "shot",
	"tender": "shot_r", "thief": "lmb_r", "ostra": "orb"}
const POST_COUNT := 14
const POST_SPACING := 0.5

var posts: Array = []
var close := false

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = Arch.ORDER.duplicate()
	frame_px = 1024
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
	_posts()
	for id in ids:
		await _hunter(String(id), out.path_join(String(id)))
	print("LIVE_AUDIT_DONE ", ids.size())
	tree.quit()

func _match_cam() -> void:
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

func _save(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_jpg(dir.path_join(name), 0.93)

## The body's world box (visible meshes under Warden, no weapon FX) -> [bottom y, height].
func _body_box(model: Node3D) -> Array:
	var lo := 1e9
	var hi := -1e9
	for mi in model.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.is_visible_in_tree() or m.mesh == null:
			continue
		var bb := m.global_transform * m.get_aabb()
		lo = minf(lo, bb.position.y)
		hi = maxf(hi, bb.end.y)
	return [lo, hi - lo]

func _close_cam(model: Node3D) -> void:
	var bx := _body_box(model)
	var h := clampf(float(bx[1]), 1.2, 2.8)
	var cy: float = float(bx[0]) + h * 0.5
	cam.fov = rad_to_deg(2.0 * atan((h / 0.6) / (2.0 * 4.0)))
	cam.position = Vector3(0, cy, 4.0)
	cam.look_at(Vector3(0, cy, 0))

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
	# bind pose: no clip, the skeleton at its rest
	model.rotation.y = THREE_Q_YAW
	for at in model.find_children("*", "AnimationTree", true, false):
		(at as AnimationTree).active = false
	sk.reset_bone_poses()
	for k in 3:
		await tree.process_frame
	if close:
		_close_cam(model)
	else:
		_match_cam()
	for k in 10:
		await tree.process_frame
	await _save(dir, "bind.jpg")
	for at in model.find_children("*", "AnimationTree", true, false):
		(at as AnimationTree).active = true
	var hands := [WardenSkeleton.find(sk, "hand.R"), WardenSkeleton.find(sk, "hand.L")]
	var marks: PackedStringArray = ["clips %s" % ("yes" if clips else "none (procedural rig only)")]
	var n := 0
	model.set_meta(WardenClips.STATE, {"vel": Vector3.ZERO, "face": THREE_Q_YAW, "grounded": true})
	for k in 20:
		sync.call("_process", DT)
	marks.append("idle %d" % n)
	for i in 60:
		sync.call("_process", DT)
		await _save(dir, "f%04d.jpg" % n)
		n += 1
	var run_yaw := THREE_Q_YAW if close else SIDE_YAW
	model.rotation.y = run_yaw
	var fw := Vector3(-sin(run_yaw) * -1.0, 0, 0)
	fw = Vector3(sin(-run_yaw), 0, -cos(run_yaw)).normalized()
	model.set_meta(WardenClips.STATE, {"vel": fw * RUN_MPS, "face": run_yaw, "grounded": true})
	for k in 20:
		sync.call("_process", DT)
		_scroll(RUN_MPS * fw.x)
	marks.append("run %d" % n)
	for i in 60:
		sync.call("_process", DT)
		_scroll(RUN_MPS * fw.x)
		await _save(dir, "f%04d.jpg" % n)
		n += 1
	model.rotation.y = THREE_Q_YAW
	if clips and ATTACKS.has(id):
		var clip: String = ATTACKS[id]
		model.set_meta(WardenClips.STATE, {"vel": Vector3.ZERO, "face": THREE_Q_YAW, "grounded": true})
		clips.force = {}
		for k in 15:
			sync.call("_process", DT)
		var length := clips.lib.get_animation(clip).length
		marks.append("atk1 %d %s len=%.2f" % [n, clip, length])
		var best := 0.0
		var best_i := n
		var prev: Array = []
		for i in 45:
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
			await _save(dir, "f%04d.jpg" % n)
			n += 1
		marks.append("atk1_contact %d" % best_i)
		clips.force = {}
	else:
		marks.append("atk1 none")
		marks.append("atk1_contact %d" % (n - 1))
	model.set_meta(WardenClips.STATE, {})
	var f := FileAccess.open(dir.path_join("marks.txt"), FileAccess.WRITE)
	f.store_string("\n".join(marks) + "\n")
	f.close()
	model.queue_free()
