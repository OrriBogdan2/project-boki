extends "res://tools/clip_shots.gd"
## --live-audit --shots-dir=<dir> [--wardens=a,b] [--size=1024] [--close]: audit render of Hunters as the game plays
## them (Models.hunter + the model's pose node), scratch-tree version of the e28953f4e4f harness. Per hunter and
## clip (idle, run, dash, jump, attack, hit) three frames: <dir>/<id>/<clip>_<k>.jpg on the match camera (fov 8, 66
## deg); with --close the same poses from eye height and knee height: <clip>_<k>_eye.jpg, <clip>_<k>_knee.jpg.
## --contract: native-flagged Hunters play their contract model; --video: see var video.
## marks.txt lists the model's kind (contract / native), tris and the state each clip was fed.

const DT := 1.0 / 30.0
const SIDE_YAW := -PI / 2.0
const THREE_Q_YAW := -PI / 2.0 - 0.55
const RUN_MPS := 5.0
const DASH_MPS := 9.0
const ATTACK_MOVES := {"archer": "arc_loose", "bulwark": "bul_throw", "gunslinger": "gunslinger_lmb", "thief": "thf_lmb_r"}
const DASH_MOVES := {"gunslinger": "gunslinger_dash", "thief": "thf_exdash"}
const SAMPLES := {"idle": [0.4, 1.0, 1.6], "run": [0.0, 0.12, 0.24], "dash": [0.0, 0.1, 0.2], "jump": [0.05, 0.3, 0.6],
	"attack": [0.1, 0.25, 0.45], "hit": [0.05, 0.15, 0.35]}
const CLIPS := ["idle", "run", "dash", "jump", "attack", "hit"]

var close := false
var native := false
var video := false  # --video: every frame (30 fps) of idle 1.2 s, run 1.0 s, attack 0.6 s as v0000.jpg ...
var vn := 0
var probe := false  # --probe: probe.tsv, the fish and hand bones per frame
var probe_rows: PackedStringArray = []

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
		if a == "--video": video = true
		if a == "--probe": probe = true
		if a == "--contract": WardenNative.contract_only = true  # the live contract model of a native-flagged Hunter
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	await tree.create_timer(2.5).timeout       # (the title's logo fades in real time, not in frames)
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
	marks.append("kind %s glb %s tris %d body_h %.2f" % ["native" if native else "contract", WardenGlb.path(id), bx[2], bx[1]])
	for clip in (["idle", "run", "attack"] if video else CLIPS):
		var yaw := SIDE_YAW if clip == "run" and not close else THREE_Q_YAW
		model.rotation.y = yaw
		var times: Array = SAMPLES[clip]
		if video:
			times = []
			for k in int({"idle": 1.2, "run": 1.0, "attack": 0.6}[clip] / DT):
				times.append(k * DT)
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
			if probe:
				_probe(model, clip, i)
			if want < times.size() and t + DT * 0.5 >= float(times[want]):
				await _shoot(model, dir, ("v%04d" % vn) if video else "%s_%d" % [clip, want], bx)
				vn += 1
				marks.append("%s %d t=%.3f state=%s" % [clip, want, t, str(s)])
				want += 1
		model.set_meta(WardenClips.STATE, {})
	var f := FileAccess.open(dir.path_join("marks.txt"), FileAccess.WRITE)
	f.store_string("\n".join(marks) + "\n")
	f.close()
	if probe:
		var pf := FileAccess.open(dir.path_join("probe.tsv"), FileAccess.WRITE)
		pf.store_string("\n".join(probe_rows) + "\n")
		pf.close()
	model.queue_free()

func _probe(model: Node3D, clip: String, i: int) -> void:
	var sk := WardenGlb.skeleton(model.get_node("Warden"))
	var fish := WardenProps.part(sk, "hand.R")
	if fish == null:
		return
	var hb := sk.find_bone("RightHand")
	if probe_rows.is_empty():
		_probe_geom(model, sk, fish, hb)
	var hp := sk.get_bone_global_pose(hb)
	var w := sk.global_transform * hp
	var grip := w * (fish.transform * Vector3(-0.175, -0.03, 0.0))
	var fist := w * fist_local
	var tip := w * (fish.transform * Vector3(-0.646, 0, 0))
	var trunk := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Spine02")).origin
	probe_rows.append("%s\t%d\tgrip-fist %.3f\tgrip %s\tfist %s\ttip %s\ttrunk %s" % [clip, i,
		grip.distance_to(fist), str(grip), str(fist), str(tip), str(trunk)])

var fist_local := Vector3.ZERO

func _probe_geom(model: Node3D, sk: Skeleton3D, fish: MeshInstance3D, hb: int) -> void:
	# fist centre: skinned verts with >0.6 weight on RightHand, bind pose, in the bone's rest frame
	var cen := Vector3.ZERO
	var cnt := 0
	for mi in model.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.skin == null or m.mesh == null or m == fish:
			continue
		for sidx in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(sidx)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bs = arr[Mesh.ARRAY_BONES]
			var ws = arr[Mesh.ARRAY_WEIGHTS]
			if bs == null:
				continue
			var per := (bs as PackedInt32Array).size() / vs.size() if bs is PackedInt32Array else (bs as PackedFloat32Array).size() / vs.size()
			for v in vs.size():
				for k in per:
					var bi := int(bs[v * per + k])
					var bname := m.skin.get_bind_name(bi)
					var jb := sk.find_bone(bname) if bname != "" else m.skin.get_bind_bone(bi)
					if jb == hb and float(ws[v * per + k]) > 0.6:
						cen += vs[v]
						cnt += 1
		var c := cen / maxf(cnt, 1)
		var rest := sk.get_bone_global_rest(hb)
		var in_sk: Vector3 = (sk.global_transform.affine_inverse() * m.global_transform) * c
		fist_local = rest.affine_inverse() * in_sk
		probe_rows.append("GEOM fist verts %d centre_in_bone %s hand_rest_origin %s" % [cnt, str(fist_local), str(rest.origin)])
		break
	var mesh := fish.mesh
	var arr := mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var prof := {}
	for v in vs:
		var kx := int(floor(v.x / 0.05))
		var e: Array = prof.get(kx, [1e9, -1e9, 1e9, -1e9])
		e[0] = minf(e[0], v.y); e[1] = maxf(e[1], v.y); e[2] = minf(e[2], v.z); e[3] = maxf(e[3], v.z)
		prof[kx] = e
	var ks := prof.keys()
	ks.sort()
	for k in ks:
		var e2: Array = prof[k]
		probe_rows.append("GEOM fishprof x=%.2f y[%.3f,%.3f] z[%.3f,%.3f]" % [k * 0.05, e2[0], e2[1], e2[2], e2[3]])
	probe_rows.append("GEOM fishxf %s scale-ish %s" % [str(fish.transform), str(fish.transform.basis.get_scale())])

func _shoot(model: Node3D, dir: String, name: String, bx: Array) -> void:
	if probe:
		return
	if close:
		for knee in [false, true]:
			_close_cam(bx, knee)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			tree.root.get_texture().get_image().save_jpg(dir.path_join("%s_%s.jpg" % [name, "knee" if knee else "eye"]), 0.93)
	else:
		_match_cam()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_jpg(dir.path_join(name + ".jpg"), 0.93)
