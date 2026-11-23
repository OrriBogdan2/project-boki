extends RefCounted
## scratch render (job dir, copied into render trees only, never in the PR):
## --ostra-fix-shots --shots-dir=<dir> [--wardens=ostra] [--step=0.125] [--clips=a,b]
## Motley in a real match world and light (Match.start, mobs and other hunters hidden), filmed by the match's own
## camera (CamRig) at the match distance ("match", dist_mul 1) and pulled in ("close", dist_mul CLOSE_MUL), 1920x1080.
## 4 views: the model turned 0/90/180/270 deg from facing the camera. Writes <dir>/<cam>/bind_y<q>.jpg (rest pose,
## no clip) then <cam>/<clip>_y<q>_f<i>.jpg for every clip of the game lib (t = i*step, up to MAX_T), plus zoomed
## elbow shots (<dir>/zoom/<clip>_<side>_y<q>_f<i>.jpg) for ZOOM_CLIPS. crop.txt: per cam, the frame rect that holds
## the body in every frame (for side-by-side crops without scaling).
const CLOSE_MUL := 0.1
const MAX_T := 3.0
const SIDE := 1024              # px: saved crop, unscaled
var cur_model: Node3D
const ZOOM_CLIPS := ["idle", "stance", "walk_f", "mantle", "g_wave", "g_beckon", "g_pump", "swap", "swap_air"]
var main: Node
var tree: SceneTree
var dir := ""
var step := 0.125
var only: Array = []
var m: Match

func run(main_node: Node) -> void:
	main = main_node
	tree = main.get_tree()
	var id := "ostra"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
		if String(a).begins_with("--wardens="): id = String(a).substr(10)
		if String(a).begins_with("--step="): step = float(String(a).substr(7))
		if String(a).begins_with("--clips="): only = Array(String(a).substr(8).split(",", false))
	main.get_window().size = Vector2i(1920, 1080)
	main.get_viewport().size = Vector2i(1920, 1080)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 3, "tier": 0, "seed": 77, "no_drop": true, "god": true, "length": 1e9})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.visible = false
	for cl in main.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	var c := m.player.pos
	var marks: PackedStringArray = []
	for tag in ["live", "fix"]:
		WardenGlb._variants = {} if tag == "live" else {"ostra": "ostra_fix"}
		print("OSTRA_FIX_SHOTS pass ", tag, " glb ", WardenGlb.path(id))
		marks = await _pass(id, c, dir.path_join(tag))
	var f := FileAccess.open(dir.path_join("marks.txt"), FileAccess.WRITE)
	f.store_string("\n".join(marks) + "\n")
	f.close()
	print("OSTRA_FIX_SHOTS_DONE ", marks.size())
	tree.quit()

func _pass(id: String, c: Vector3, out: String) -> PackedStringArray:
	for sub in ["match", "close", "side", "zoom"]:
		DirAccess.make_dir_recursive_absolute(out.path_join(sub))
	var marks: PackedStringArray = []
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	m.add_child(model)
	cur_model = model
	model.global_position = Vector3(c.x, m.world.ground_at(c.x, c.z), c.z)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	for k in 25:
		await tree.process_frame
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var sk := WardenGlb.skeleton(model.get_node("Warden"))
	# rest pose
	for at in model.find_children("*", "AnimationTree", true, false):
		(at as AnimationTree).active = false
	sk.reset_bone_poses()
	for q in 4:
		model.rotation.y = PI + q * PI / 2.0
		for cam in ["match", "close", "side"]:
			_cam(cam, c)
			await _grab(out, cam, "bind_y%d.jpg" % q, 12)
	for at in model.find_children("*", "AnimationTree", true, false):
		(at as AnimationTree).active = true
	var names: PackedStringArray = clips.lib.get_animation_list()
	for clip in names:
		if not only.is_empty() and not only.has(clip):
			continue
		var length := clips.lib.get_animation(clip).length
		var st := step if ZOOM_CLIPS.has(clip) else step * 2.0
		var n := int(ceil(minf(length, MAX_T) / st)) + 1
		marks.append("%s %d %.3f %.3f" % [clip, n, length, st])
		for q in 4:
			model.rotation.y = PI + q * PI / 2.0
			model.set_meta(WardenClips.STATE, {"vel": Vector3.ZERO, "face": model.rotation.y, "grounded": true})
			clips.force = {"clip": clip, "t": 0.0}
			for k in 12:
				sync.call("_process", 1.0 / 30.0)
			for i in n:
				clips.force = {"clip": clip, "t": minf(i * st, length - 0.001)}
				sync.call("_process", 1.0 / 30.0)
				model.global_position = Vector3(c.x, m.world.ground_at(c.x, c.z), c.z)
				for cam in ["match", "close", "side"]:
					_cam(cam, c)
					await _grab(out, cam, "%s_y%d_f%03d.jpg" % [clip, q, i], 2)
				if ZOOM_CLIPS.has(clip) and i % 2 == 0:
					for side in ["L", "R"]:
						_zoom_cam(sk, side, q)
						await _grab(out, "zoom", "%s_%s_y%d_f%03d.jpg" % [clip, side, q, i], 2)
	clips.force = {}
	clips.force = {}
	model.queue_free()
	for k in 5:
		await tree.process_frame
	return marks

var zc: Camera3D

var sc: Camera3D
var pc: Camera3D

## match / close: the match's own camera (CamRig) at dist_mul 1 / CLOSE_MUL; side: a level camera 3.6 m off at
## chest height in the same world and light, from the match camera's side, so the 4 model turns read as 4 sides.
func _cam(which: String, c: Vector3) -> void:
	if which == "side":
		if sc == null:
			sc = Camera3D.new()
			sc.fov = 40.0
			m.add_child(sc)
		var mid := cur_model.global_position + Vector3(0, 0.95, 0)
		var back := m.cam.global_position - mid
		back.y = 0.0
		sc.global_position = mid + back.normalized() * 3.6 + Vector3(0, 0.1, 0)
		sc.look_at(mid)
		sc.make_current()
		return
	# the match camera's own pose for this distance (CamRig.snap applies it at once), copied to a still camera so
	# the rig's follow/lead in later frames cannot pull Motley out of frame
	m.cam.dist_mul = 1.0 if which == "match" else CLOSE_MUL
	m.cam.snap(c)
	if pc == null:
		pc = Camera3D.new()
		m.add_child(pc)
	pc.fov = m.cam.fov
	pc.near = m.cam.near
	pc.far = m.cam.far
	var mid := cur_model.global_position + Vector3(0, 0.9, 0)
	var fwd := -m.cam.global_transform.basis.z
	pc.global_transform = Transform3D(m.cam.global_transform.basis, mid - fwd * (m.cam.global_position - c).length())
	pc.make_current()

## A camera 0.9 m off the elbow (forearm bone head), from the side the model shows the camera in view q.
func _zoom_cam(sk: Skeleton3D, side: String, q: int) -> void:
	if zc == null:
		zc = Camera3D.new()
		zc.fov = 40.0
		m.add_child(zc)
	var b := WardenSkeleton.find(sk, "forearm." + side)
	var at: Vector3 = sk.global_transform * sk.get_bone_global_pose(b).origin
	var to_cam: Vector3 = (m.cam.global_position - at)
	to_cam.y = 0.0
	to_cam = to_cam.normalized()
	zc.global_position = at + to_cam * 1.1 + Vector3(0, 0.1, 0)
	zc.look_at(at)
	zc.make_current()

## Saves a SIDE x SIDE crop (no scaling) centred on the hunter's middle as the current camera sees it.
func _grab(out: String, sub: String, file: String, frames: int) -> void:
	for i in frames:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	var at := Vector2(img.get_width() / 2.0, img.get_height() / 2.0)
	var side := mini(SIDE if sub != "match" else 512, img.get_height())
	var x := clampi(int(at.x) - side / 2, 0, img.get_width() - side)
	var y := clampi(int(at.y) - side / 2, 0, img.get_height() - side)
	img.get_region(Rect2i(x, y, side, side)).save_jpg(out.path_join(sub).path_join(file), 0.86)
