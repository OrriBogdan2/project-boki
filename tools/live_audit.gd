extends "res://tools/clip_shots.gd"
## --live-audit --shots-dir=<dir> [--wardens=a,b] [--size=1024] [--close]: audit render of Hunters as the game plays
## them (Models.hunter + the model's pose node), scratch-tree version of the e28953f4e4f harness. Per hunter and
## clip (idle, run, dash, jump, attack, hit) three frames: <dir>/<id>/<clip>_<k>.jpg on the match camera (fov 8, 66
## deg); with --close the same poses from eye height and knee height: <clip>_<k>_eye.jpg, <clip>_<k>_knee.jpg.
## marks.txt lists the model's kind (contract / native), tris and the state each clip was fed.

const DT := 1.0 / 30.0
const SIDE_YAW := -PI / 2.0
const THREE_Q_YAW := -PI / 2.0 - 0.55
const RUN_MPS := 5.0
const DASH_MPS := 9.0
const ATTACK_MOVES := {
	"archer": "arc_loose", "bulwark": "bul_throw", "gunslinger": "gunslinger_lmb", "thief": "thf_lmb_r"
}
const DASH_MOVES := {"gunslinger": "gunslinger_dash", "thief": "thf_exdash"}
const SAMPLES := {
	"idle": [0.4, 1.0, 1.6],
	"run": [0.0, 0.12, 0.24],
	"dash": [0.0, 0.1, 0.2],
	"glide": [0.2, 0.6, 1.0],
	"jump": [0.05, 0.3, 0.6],
	"attack": [0.1, 0.25, 0.45],
	"hit": [0.05, 0.15, 0.35]
}
const CLIPS := ["idle", "run", "dash", "glide", "jump", "attack", "hit"]
const FILM := {"idle": 1.6, "run": 0.9, "dash": 0.5, "glide": 1.0, "hit": 0.6, "attack": 1.0}

var close := false
var film := false
var native := false


func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = Arch.ORDER.duplicate()
	frame_px = 1024
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--wardens="):
			ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--size="):
			frame_px = int(a.substr(7))
		if a == "--close":
			close = true
		if a == "--film":
			film = true
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	await tree.create_timer(2.5).timeout  # (the title's logo fades in real time, not in frames)
	for id in ids:
		await _hunter(String(id), out.path_join(String(id)))
	print("LIVE_AUDIT_DONE ", ids.size())
	tree.quit()


func _match_cam() -> void:
	cam.fov = 8.0
	cam.position = Vector3(0, 21.0, 9.4)
	cam.look_at(Vector3(0, 0.8, 0))


## The body's world box (visible meshes under Warden) -> [bottom y, height, tris].
func _body_box(model: Node3D) -> Array:
	var lo := 1e9
	var hi := -1e9
	var tris := 0
	for mi in model.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.is_visible_in_tree() or m.mesh == null:
			continue
		var bb := m.global_transform * m.get_aabb()
		lo = minf(lo, bb.position.y)
		hi = maxf(hi, bb.end.y)
		for s in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(s)
			if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null:
				tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return [lo, hi - lo, tris]


## Full-body close view: fov 30 and the distance that fits the body in 85% of the frame, from eye or knee height.
func _close_cam(bx: Array, knee: bool) -> void:
	var h := float(bx[1])
	var cy: float = float(bx[0]) + h * 0.5
	var dist := h / (0.85 * 2.0 * tan(deg_to_rad(15.0)))
	cam.fov = 30.0
	cam.position = Vector3(0, float(bx[0]) + h * (0.3 if knee else 0.88), dist)
	cam.look_at(Vector3(0, cy, 0))


func _forward(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func _state(id: String, clip: String, yaw: float, t: float) -> Dictionary:
	var fw := _forward(yaw)
	var s := {"face": yaw, "grounded": true, "vel": Vector3.ZERO}
	match clip:
		"run":
			s["vel"] = fw * RUN_MPS
		"dash":
			s["vel"] = fw * DASH_MPS
			if not native and DASH_MOVES.has(id):
				s["kmove"] = DASH_MOVES[id]
				s["kmove_t"] = t
		"glide":
			s["grounded"] = false
			s["gliding"] = true
			s["vel"] = fw * 6.0 + Vector3(0.0, -1.5, 0.0)
		"jump":
			s["grounded"] = false
			s["vel"] = fw * 4.0 + Vector3(0.0, 3.0 - t * 8.0, 0.0)
		"attack":
			s["swing_n"] = 1
			s["kmove"] = ATTACK_MOVES.get(id, "")
			s["kmove_t"] = t
		"hit":
			s["hit_t"] = t
			s["hit_k"] = Oomph.HEAVY_FLINCH
			s["hit_dir"] = Vector2(0, -1)
	return s


func _hunter(id: String, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	for k in 30:
		await tree.process_frame
	var poser := model.get_node_or_null("Warden/Native")
	native = poser != null
	if poser == null:
		poser = model.get_node("Warden/Sync")
	poser.set_process(false)
	var marks: PackedStringArray = []
	var bx := _body_box(model)
	var kind := "native" if native else "contract"
	marks.append("kind %s glb %s tris %d body_h %.2f" % [kind, WardenGlb.path(id), bx[2], bx[1]])
	for clip in FILM.keys() if film else CLIPS:
		var yaw := SIDE_YAW if clip == "run" and not close else THREE_Q_YAW
		model.rotation.y = yaw
		var times: Array = SAMPLES[clip]
		if film:  # every 2nd step (15 fps) over a clip's span
			times = []
			for j in int(float(FILM[clip]) / (2.0 * DT)):
				times.append(j * 2.0 * DT)
		# settle: the pre-state (standing, or running for a hit/jump) for 25 frames, then the clip's own state
		var s := _state(id, "idle" if clip != "dash" else "run", yaw, 0.0)
		model.set_meta(WardenClips.STATE, s)
		for k in 25:
			poser.call("_process", DT)
		var n := 0
		var steps := int(float(times[-1]) / DT) + 1
		var want := 0
		for i in steps:
			var t := i * DT
			s = _state(id, clip, yaw, t)
			model.set_meta(WardenClips.STATE, s)
			poser.call("_process", DT)
			if want < times.size() and t + DT * 0.5 >= float(times[want]):
				await _shoot(model, dir, "%s_%d" % [clip, want], bx)
				marks.append("%s %d t=%.3f state=%s" % [clip, want, t, str(s)])
				want += 1
		model.set_meta(WardenClips.STATE, {})
	var f := FileAccess.open(dir.path_join("marks.txt"), FileAccess.WRITE)
	f.store_string("\n".join(marks) + "\n")
	f.close()
	model.queue_free()


func _shoot(_model: Node3D, dir: String, name: String, bx: Array) -> void:
	if close:
		for knee in [false, true]:
			_close_cam(bx, knee)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var shot := "%s_%s.jpg" % [name, "knee" if knee else "eye"]
			tree.root.get_texture().get_image().save_jpg(dir.path_join(shot), 0.93)
	else:
		_match_cam()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_jpg(dir.path_join(name + ".jpg"), 0.93)
