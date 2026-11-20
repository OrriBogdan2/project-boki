extends RefCounted
## --hunter-review-shots --shots-dir=<dir> [--arch=thief] [--only=a,b] [--every=4] [--cap=8]: review evidence tool (not shipped).
## Real Arena map, <arch> as the player. Per pose: the match camera (crop on the hunter) and 8 orbit cameras:
## eye-level (chest height) front / 3-4 / side / back and knee-height front / 3-4 / side / back.
## Clips are stepped at 30 fps without gaps (the springs see game-speed motion); a shot every <every> steps.

const DT := 1.0 / 30.0
const VIEWS := [["front", 0.0], ["q34", 45.0], ["side", -90.0], ["back", 180.0]]

var main: Node
var m: Match
var dir := "/tmp/hrs"
var arch := "thief"
var every := 4
var cap := 8
var match_only := false
var only: PackedStringArray = []
var cams: Array = []
var model: Node3D
var sync: Node
var clips: WardenClips
var seq := 0
var idx: PackedStringArray = ["seq\tpart\tclip\tframe\tt"]
var yaw0 := 0.0
var skel: Skeleton3D
var ccam: Camera3D
## close-ups (region scoring): [name, bone a, bone b, lerp, yaw deg, frame height m, camera rise m]
const CLOSE := [["face_front", "head", "head", 0.0, 0.0, 0.46, 0.0, 0.1], ["face_q34", "head", "head", 0.0, 45.0, 0.46, 0.0, 0.1],
	["face_side", "head", "head", 0.0, -90.0, 0.46, 0.0, 0.1], ["mouth_front", "head", "head", 0.0, 0.0, 0.26, 0.0, 0.09],
	["mouth_q34", "head", "head", 0.0, 35.0, 0.26, 0.0, 0.09], ["mouth_q34b", "head", "head", 0.0, -35.0, 0.26, 0.0, 0.09],
	["head_front", "head", "head", 0.0, 0.0, 0.8, 0.0, 0.25], ["head_side", "head", "head", 0.0, -90.0, 0.8, 0.0, 0.25],
	["head_back", "head", "head", 0.0, 180.0, 0.8, 0.0, 0.25], ["head_q34", "head", "head", 0.0, 45.0, 0.8, 0.0, 0.25],
	["bust_front", "hips", "head", 0.62, 0.0, 0.62, 0.0, 0.0], ["bust_side", "hips", "head", 0.62, -90.0, 0.62, 0.0, 0.0],
	["handL", "hand.L", "forearm.L", 0.3, 0.0, 0.62, 0.1, 0.0], ["handR", "hand.R", "forearm.R", 0.3, 0.0, 0.62, 0.1, 0.0],
	["handL_back", "hand.L", "forearm.L", 0.3, 180.0, 0.62, 0.1, 0.0], ["handR_back", "hand.R", "forearm.R", 0.3, 180.0, 0.62, 0.1, 0.0],
	["handL_side", "hand.L", "forearm.L", 0.3, 90.0, 0.62, 0.1, 0.0], ["handR_side", "hand.R", "forearm.R", 0.3, -90.0, 0.62, 0.1, 0.0],
	["feet_front", "foot.L", "foot.R", 0.5, 0.0, 0.6, 0.1, 0.0], ["feet_side", "foot.L", "foot.R", 0.5, -90.0, 0.6, 0.1, 0.0],
	["feet_back", "foot.L", "foot.R", 0.5, 180.0, 0.6, 0.1, 0.0],
	["hips_front", "hips", "hips", 0.0, 0.0, 0.7, 0.0, 0.0], ["hips_back", "hips", "hips", 0.0, 180.0, 0.7, 0.0, 0.0]]
const CLOSE_CLIPS := ["rest", "d_idle", "idle", "stance", "crouch_idle", "primed", "fall", "downed", "glide", "d_jump_air", "d_run", "run_f", "emote", "lmb_r", "stun"]

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var size := Vector2i(1600, 900)
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--shots-dir="): dir = s.substr(12)
		if s.begins_with("--arch="): arch = s.substr(7)
		if s.begins_with("--every="): every = int(s.substr(8))
		if s.begins_with("--cap="): cap = int(s.substr(6))
		if s.begins_with("--only="): only = s.substr(7).split(",")
		if s == "--match-only": match_only = true
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = size
	main.get_viewport().size = size
	m = Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts(arch))
	m.set_process(false)
	if main.get("fade") != null and main.fade:
		await main.fade.reveal(0.01)
	var A: Arena = m.arena
	var P: Hunter = m.player
	var spot := A.home + Vector3(0, 0, 4.0)
	P.teleport(Vector3(spot.x, m.world.ground_at(spot.x, spot.z), spot.z))
	P.vel = Vector3.ZERO
	for k in 30:
		m.step(DT)
		await main.get_tree().process_frame
	P.set_process(false)
	P.set_physics_process(false)
	model = P.model
	sync = model.get_node("Warden/Sync")
	sync.set_process(false)
	clips = sync.get("clips")
	for cl in main.get_tree().root.find_children("*", "CanvasLayer", true, false):
		cl.set("visible", false)
	m.cam.snap(P.pos)
	yaw0 = model.rotation.y
	_make_cams(model.global_position)
	var rec := "none"
	for fn in DirAccess.get_files_at("res://.godot/imported"):
		if fn.begins_with("sable.glb-") and fn.ends_with(".md5"):
			rec = FileAccess.get_file_as_string("res://.godot/imported/" + fn).replace("\n", " ")
	print("HRS glb %s md5 %s import %s scale %s" % [ProjectSettings.globalize_path("res://art/wardens/sable/sable.glb"),
		FileAccess.get_md5("res://art/wardens/sable/sable.glb"), rec, str(model.scale)])
	# rest pose
	for at in model.find_children("*", "AnimationTree", true, false):
		(at as AnimationTree).active = false
	var sk := WardenGlb.skeleton(model.get_node("Warden"))
	skel = sk
	ccam = Camera3D.new()
	m.add_child(ccam)
	ccam.fov = 30.0
	ccam.near = 0.05
	sk.reset_bone_poses()
	await _frames(4)
	await _shoot("rest", "rest", 0, 0.0)
	for at in model.find_children("*", "AnimationTree", true, false):
		(at as AnimationTree).active = true
	# driven states (the game's own state machine, no forced clip), 30 fps without gaps
	for spec in [["d_idle", 0.0, true], ["d_walk", 2.0, true], ["d_run", 4.6, true], ["d_sprint", 7.5, true], ["d_jump_air", 0.0, false]]:
		if not only.is_empty() and not only.has(String(spec[0])):
			continue
		clips.force = {}
		var face := model.rotation.y
		var fw := Vector3(-sin(face), 0, -cos(face))
		var up := Vector3.ZERO if bool(spec[2]) else Vector3(0, 3.0, 0)
		model.set_meta(WardenClips.STATE, {"vel": fw * float(spec[1]) + up, "face": face, "grounded": bool(spec[2])})
		for k in 20:
			sync.call("_process", DT)
		for i in 6:
			for k in 5:
				sync.call("_process", DT)
			await _shoot("drive", String(spec[0]), i, (i + 1) * 5 * DT)
	model.set_meta(WardenClips.STATE, {"vel": Vector3.ZERO, "face": model.rotation.y, "grounded": true})
	# every clip of the library, forced, stepped at 30 fps
	var names: Array = []
	for a in clips.lib.get_animation_list():
		names.append(String(a))
	names.sort()
	for nm in names:
		if not only.is_empty() and not only.has(String(nm)):
			continue
		var L := clips.lib.get_animation(nm).length
		var steps := maxi(2, int(floor(minf(L, 4.0) / DT)))
		var ev := every
		while steps / ev > cap:
			ev += 1
		clips.force = {"clip": nm, "t": 0.0}
		for k in 12:
			sync.call("_process", DT)
		for i in steps:
			var t := minf(i * DT, L - 0.001)
			clips.force = {"clip": nm, "t": t}
			sync.call("_process", DT)
			if i % ev == 0:
				await _shoot("clip", nm, i, t)
	clips.force = {}
	var f := FileAccess.open(dir.path_join("index.tsv"), FileAccess.WRITE)
	f.store_string("\n".join(idx) + "\n")
	f.close()
	print("HRS_DONE %d poses, %d clips" % [seq, names.size()])
	main.get_tree().quit(0)

func _make_cams(p: Vector3) -> void:
	var s := model.scale.y
	var t15 := tan(deg_to_rad(15.0))
	for lvl in [["eye", 1.25, 0.92, 2.3], ["knee", 0.45, 0.55, 1.35]]:
		for v in VIEWS:
			var c := Camera3D.new()
			m.add_child(c)
			c.fov = 30.0
			var a := yaw0 + deg_to_rad(float(v[1]))
			var dirv := Vector3(-sin(a), 0, -cos(a))
			var d := float(lvl[3]) * s / (2.0 * t15)
			c.near = maxf(0.05, d - 1.4 * s)
			c.global_position = p + Vector3(0, float(lvl[1]) * s, 0) + dirv * d
			c.look_at(p + Vector3(0, float(lvl[2]) * s, 0))
			cams.append(["%s_%s" % [lvl[0], v[0]], c])

func _frames(k: int) -> void:
	for i in k:
		await main.get_tree().process_frame

func _shoot(part: String, clip: String, frame: int, t: float) -> void:
	var vp := main.get_viewport()
	m.cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var c2 := m.cam.unproject_position(model.global_position + Vector3(0, 0.9 * model.scale.y, 0))
	c2 *= float(img.get_width()) / vp.get_visible_rect().size.x
	var x0 := clampi(int(c2.x) - 100, 0, img.get_width() - 200)
	var y0 := clampi(int(c2.y) - 100, 0, img.get_height() - 200)
	img.get_region(Rect2i(x0, y0, 200, 200)).save_png(dir.path_join("%04d_match.png" % seq))
	if seq == 0:
		img.save_jpg(dir.path_join("match_full.jpg"), 0.92)
		print("HRS match crop %d %d scale %f" % [x0, y0, float(img.get_width()) / vp.get_visible_rect().size.x])
	if match_only:
		idx.append("%d\t%s\t%s\t%d\t%.3f" % [seq, part, clip, frame, t])
		seq += 1
		return
	for c in cams:
		(c[1] as Camera3D).current = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		img = vp.get_texture().get_image()
		var w := img.get_height()
		var sq := img.get_region(Rect2i((img.get_width() - w) / 2, 0, w, w))
		sq.resize(768, 768, Image.INTERPOLATE_LANCZOS)
		sq.save_jpg(dir.path_join("%04d_%s.jpg" % [seq, c[0]]), 0.85)
	if CLOSE_CLIPS.has(clip):
		var s := model.scale.y
		for cc in CLOSE:
			var ia := skel.find_bone(String(cc[1]))
			var ib := skel.find_bone(String(cc[2]))
			if ia < 0 or ib < 0:
				continue
			var pa: Vector3 = skel.global_transform * skel.get_bone_global_pose(ia).origin
			var pb: Vector3 = skel.global_transform * skel.get_bone_global_pose(ib).origin
			var tg := pa.lerp(pb, float(cc[3]))
			tg.y += float(cc[7]) * s
			var a := yaw0 + deg_to_rad(float(cc[4]))
			var dirv := Vector3(-sin(a), 0, -cos(a))
			var d := float(cc[5]) * s / (2.0 * tan(deg_to_rad(15.0)))
			var off := dirv * d + Vector3(0, float(cc[6]) * s, 0)
			ccam.global_position = tg + off.normalized() * d
			ccam.look_at(tg)
			ccam.current = true
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			img = vp.get_texture().get_image()
			var w2 := img.get_height()
			var sq2 := img.get_region(Rect2i((img.get_width() - w2) / 2, 0, w2, w2))
			sq2.resize(768, 768, Image.INTERPOLATE_LANCZOS)
			sq2.save_jpg(dir.path_join("%04d_close_%s.jpg" % [seq, cc[0]]), 0.88)
	m.cam.current = true
	idx.append("%d\t%s\t%s\t%d\t%.3f" % [seq, part, clip, frame, t])
	seq += 1
