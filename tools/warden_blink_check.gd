extends RefCounted
## --warden-blink-check: the eyelid blink (WardenBlink, warden_anim/<art>.json "blink"). Every art/wardens .glb with lid
## bones has a blink and every one without has none; each closed pose is the deepest the art's own clips shut the lid;
## on each Hero that blinks, the lids reach closed and come back to the clip's pose, a double blink shuts twice, the
## gap is 2-6 s, and with the camera past the far-camera distance there is no blink and nothing runs per frame.
## --warden-blink-shots --shots-dir=<dir>: a close-up of each Hero with lids, open (left) and closed (right),
## blink_<art>.png. Needs a renderer. Never touches the save.

const DT := 1.0 / 60.0
const TOL := 0.03               # rad (m for a lid that slides): "at" a pose
const OPEN_K := 0.6             # a lid this far from closed counts as open for the shot
const CLOSE_M := 1.1            # m from the face to the close-up camera
const FAR_M := WardenGlb.FAR_HIDE_D + 0.5

var bad := 0
var holder: Node3D
var cam: Camera3D

func ok(cond: bool, what: String) -> void:
	print("BLINK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node, mode := "check") -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.make_current()
	if mode == "shots":
		await _shots(main)
		return
	_scan()
	for id in WardenGlb.ART:
		if not (WardenClips.data(String(WardenGlb.ART[id])).get("blink", {}) as Dictionary).is_empty():
			_hero(String(id))
	print("WARDEN_BLINK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Every .glb: lid bones <-> a blink block naming each of them.
func _scan() -> void:
	var none: Array = []
	for art_name in DirAccess.get_directories_at(WardenGlb.DIR):
		var p := "%s/%s/%s.glb" % [WardenGlb.DIR, art_name, art_name]
		if not ResourceLoader.exists(p):
			continue
		var glb := (load(p) as PackedScene).instantiate() as Node3D
		var sk := WardenGlb.skeleton(glb)
		var lids: Array = []
		for bi in sk.get_bone_count():
			if sk.get_bone_name(bi).begins_with("lid"):
				lids.append(sk.get_bone_name(bi))
		if not lids.is_empty():
			var n := _lid_verts(glb, sk)
			print("BLINK %s: lids skin %d vertices%s" % [art_name, n, "" if n > 0 else " (moves nothing: art lane)"])
		glb.free()
		var cfg: Dictionary = WardenClips.data(art_name).get("blink", {})
		var named: Array = (cfg.get("turn", {}) as Dictionary).keys() + (cfg.get("move", {}) as Dictionary).keys()
		var miss := lids.filter(func(b): return not b in named)
		ok(miss.is_empty() and named.all(func(b): return b in lids),
				"%s: lids %s, blink names %s" % [art_name, str(lids), str(named)])
		if lids.is_empty():
			none.append(art_name)
	print("BLINK no lids (docs/art/wardens/BLINK.md): ", ", ".join(none))

## How many vertex weights of the .glb's skinned meshes ride a lid bone: 0 means the lids move no mesh.
static func _lid_verts(glb: Node3D, sk: Skeleton3D) -> int:
	var n := 0
	for node in glb.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.skin == null:
			continue
		var lid := PackedByteArray()
		lid.resize(mi.skin.get_bind_count())
		for b in mi.skin.get_bind_count():
			var bi := mi.skin.get_bind_bone(b)
			if bi < 0:
				bi = sk.find_bone(mi.skin.get_bind_name(b))
			lid[b] = 1 if bi >= 0 and sk.get_bone_name(bi).begins_with("lid") else 0
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var bones := arr[Mesh.ARRAY_BONES] as PackedInt32Array
			var weights := arr[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
			for i in bones.size():
				if weights[i] > 0.05 and lid[bones[i]] == 1:
					n += 1
	return n

func _model(id: String) -> Node3D:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	holder.add_child(m)
	return m

func _head(sk: Skeleton3D) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, "head")).origin

## How far lid l is from closed: radians, or metres for a lid that slides.
static func off_closed(sk: Skeleton3D, l: Array) -> float:
	if l[2] != null:
		return sk.get_bone_pose_position(int(l[0])).distance_to(l[2])
	return sk.get_bone_pose_rotation(int(l[0])).angle_to(l[1])

static func span(sk: Skeleton3D, l: Array) -> float:
	var rest := sk.get_bone_rest(int(l[0]))
	if l[2] != null:
		return rest.origin.distance_to(l[2])
	return rest.basis.get_rotation_quaternion().angle_to(l[1])

func _hero(id: String) -> void:
	var art_name := String(WardenGlb.ART[id])
	var m := _model(id)
	var w := m.get_node("Warden")
	var sk := WardenGlb.skeleton(w)
	var sync := w.get_node("Sync") as WardenGlb.Sync
	var blink := w.get_node_or_null("Blink") as WardenBlink
	ok(blink != null and blink.lids.size() > 0, "%s: blinks" % art_name)
	if blink == null:
		m.free()
		return
	_deepest(art_name, sk, sync.clips.lib, blink)
	ok(not blink.is_processing() and blink.timer.wait_time >= WardenBlink.EVERY.x \
			and blink.timer.wait_time <= WardenBlink.EVERY.y, "%s: asleep, next blink in %.1f s" % [art_name,
			blink.timer.wait_time])
	var head := _head(sk)
	cam.position = head + Vector3(0, 0, -FAR_M)
	blink._due()
	ok(not blink.near() and not blink.is_processing(), "%s: no blink %.1f m away (far camera)" % [art_name, FAR_M])
	cam.position = head + Vector3(0, 0, -CLOSE_M)
	ok(blink.near(), "%s: near at %.1f m" % [art_name, CLOSE_M])
	for times in [1, 2]:
		blink.start(times)
		var shut := 0
		var was_shut := false
		var frames := 0
		var open_end := false
		while blink.is_processing() and frames < 120:
			sync._process(DT)
			var clip_pose: Array = []
			for l in blink.lids:
				clip_pose.append([sk.get_bone_pose_rotation(int(l[0])), sk.get_bone_pose_position(int(l[0]))])
			blink._process(DT)
			frames += 1
			var all_shut: bool = blink.lids.all(func(l): return off_closed(sk, l) < TOL)
			if all_shut and not was_shut:
				shut += 1
			was_shut = all_shut
			if not blink.is_processing():
				open_end = _at_clip(sk, blink.lids, clip_pose)
		var want_t: float = WardenBlink.SHUT_T * times + WardenBlink.GAP_T * (times - 1)
		ok(shut == times and open_end and absf(frames * DT - want_t) < 2.5 * DT,
				"%s: %d blink(s) shut %d times, fully open after %.2f s (want %.2f)" % [art_name, times, shut,
				frames * DT, want_t])
	m.free()

## Every lid back on the clip's own pose (rotation, position) once the blink is over.
static func _at_clip(sk: Skeleton3D, lids: Array, clip_pose: Array) -> bool:
	for i in lids.size():
		var bi := int(lids[i][0])
		if not sk.get_bone_pose_rotation(bi).is_equal_approx(clip_pose[i][0]) \
				or not sk.get_bone_pose_position(bi).is_equal_approx(clip_pose[i][1]):
			return false
	return true

## The blink's closed pose is the deepest the art's own clips shut each lid.
func _deepest(art_name: String, sk: Skeleton3D, lib: AnimationLibrary, blink: WardenBlink) -> void:
	for l in blink.lids:
		var bone := sk.get_bone_name(int(l[0]))
		var rest := sk.get_bone_rest(int(l[0]))
		var rq := rest.basis.get_rotation_quaternion()
		var best := 0.0
		var deep: Variant = null
		for an in lib.get_animation_list():
			var a := lib.get_animation(an)
			for ti in a.get_track_count():
				if a.track_get_path(ti).get_concatenated_subnames() != bone:
					continue
				var slides := a.track_get_type(ti) == Animation.TYPE_POSITION_3D
				if not slides and a.track_get_type(ti) != Animation.TYPE_ROTATION_3D:
					continue
				for k in a.track_get_key_count(ti):
					var v: Variant = a.track_get_key_value(ti, k)
					var d := rest.origin.distance_to(v) if slides else rq.angle_to(v)
					if d > best:
						best = d
						deep = v
		var miss := INF
		if deep is Quaternion and l[2] == null:
			miss = (deep as Quaternion).angle_to(l[1])
		elif deep is Vector3 and l[2] != null:
			miss = (deep as Vector3).distance_to(l[2])
		ok(miss < TOL, "%s %s: closed is the clips' deepest (off by %.3f)" % [art_name, bone, miss])

func _shots(main: Node) -> void:
	var tree := main.get_tree()
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"),
		"stars": 0.0})
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-30, 160, 0), 40.0)
	cam.fov = 30.0
	var made := 0
	for id in WardenGlb.ART:
		var art_name := String(WardenGlb.ART[id])
		if (WardenClips.data(art_name).get("blink", {}) as Dictionary).is_empty():
			continue
		var m := _model(id)
		var w := m.get_node("Warden")
		var sk := WardenGlb.skeleton(w)
		var blink := w.get_node("Blink") as WardenBlink
		blink.timer.stop()
		var frames := 0
		await tree.process_frame
		while frames < 240 and (frames < 30 or not _open(sk, blink)):
			await tree.process_frame
			frames += 1
		var head := _head(sk)
		cam.look_at_from_position(head + Vector3(-0.3, 0.05, -CLOSE_M), head, Vector3.UP)
		Engine.time_scale = 0.0
		var open_img := await _grab(tree)
		blink.left = 1
		blink.t = WardenBlink.DOWN_T + WardenBlink.HOLD_T * 0.5
		blink.set_process(true)
		var shut_img := await _grab(tree)
		var shut_ok: bool = blink.lids.all(func(l): return off_closed(sk, l) < TOL)
		blink.set_process(false)
		Engine.time_scale = 1.0
		var pair := Image.create(open_img.get_width() * 2, open_img.get_height(), false, Image.FORMAT_RGBA8)
		pair.blit_rect(open_img, Rect2i(Vector2i.ZERO, open_img.get_size()), Vector2i.ZERO)
		pair.blit_rect(shut_img, Rect2i(Vector2i.ZERO, shut_img.get_size()), Vector2i(open_img.get_width(), 0))
		pair.resize(pair.get_width() / 2, pair.get_height() / 2)
		pair.save_png(out.path_join("blink_%s.png" % art_name))
		ok(shut_ok, "%s: shot blink_%s.png (open | closed)" % [art_name, art_name])
		made += 1
		m.free()
	print("WARDEN_BLINK_SHOTS %d in %s, failures: %d" % [made, out, bad])
	tree.quit(1 if bad > 0 else 0)

## The clip has every lid open (not mid one of its own blinks).
static func _open(sk: Skeleton3D, blink: WardenBlink) -> bool:
	return blink.lids.all(func(l): return off_closed(sk, l) >= OPEN_K * span(sk, l))

func _grab(tree: SceneTree) -> Image:
	await tree.process_frame
	await tree.process_frame
	var img := tree.root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
