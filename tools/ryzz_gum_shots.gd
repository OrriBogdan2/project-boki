extends RefCounted
## --ryzz-gum-shots --shots-dir=<dir> [--tag=<name>]: where Sparkle's gum bubble sits, on the real render path (GPU).
## Writes <dir>/<tag>_<state>_<view>.png head close-ups (states bind, idle, run, attack; views front, 3/4, profile at
## eye level), <tag>_game_<state>.png at the match camera (3x), and <tag>_sweep.txt: for every clip of her library,
## five samples of the gum's vertices in the head bone's frame (centre, top below the crown, drift from bind).

const STATES := ["bind", "idle", "run", "attack"]
const VIEWS := {"front": [0.0, 15.0], "3q": [40.0, 10.0], "profile": [90.0, 0.0]}  # [yaw deg, camera above deg]
const FRAMES := 80  # steps before a pose is shot
const SAMPLES := 5  # per clip, 0 .. 100 %
const CROP := 520  # px of a close-up
const GAME_PITCH := 66.0  # the match camera (CamRig STYLES "default")
const GAME_DIST := 23.0
const GAME_FOV := 32.0

var tree: SceneTree
var cam: Camera3D
var holder: Node3D
var tag := "after"
var out := ""


func run(main: Node) -> void:
	tree = main.get_tree()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--tag="):
			tag = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	_stage(main)
	for k in 90:
		await tree.process_frame  # (the loading cover is gone before the first shot)
	for st in STATES:
		await _state(String(st))
	var probe := _hunter()
	var has_gum_bone := WardenGlb.skeleton(probe.get_node("Warden")).find_bone("gum") >= 0
	probe.queue_free()
	if has_gum_bone:
		await _sweep()
	print("RYZZ_GUM_SHOTS_DONE")
	tree.quit()


func _stage(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	env.environment = Look.environment(
		{"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"), "stars": 0.0}
	)
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	ground.material_override = Models.toon(Color("4f7a3e"), false)
	holder.add_child(ground)
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.make_current()


func _hunter() -> Node3D:
	var h := Models.hunter(
		Arch.weight("mage"), Data.TEAM_COLORS[0], Arch.signature("mage"), "", PlayerLook.neutral(), "mage"
	)
	h.rotation.y = PI
	holder.add_child(h)
	return h


func _drive(an: HunterAnim, h: Node3D, st: String, frames: int) -> void:
	var fwd := Vector3(-sin(h.rotation.y), 0, -cos(h.rotation.y))
	for k in frames:
		var s := {"fired": 99.0, "face": h.rotation.y, "grounded": true}
		if st == "run":
			s["vel"] = fwd * 5.0
		if st == "attack" and k >= frames - 6:
			s["swing_n"] = 1
			s["combo"] = 0
		an.update(1.0 / 60.0, s)
		await tree.process_frame


## Stops the clips and rests every bone: the bind pose (a contract model: WardenSync and its tree; a native one: its
## AnimationPlayer).
func _freeze(h: Node3D) -> void:
	var sync := h.get_node_or_null("Warden/Sync")
	if sync:
		sync.set_process(false)
		sync.get("clips").tree.active = false
	for ap in h.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).active = false
	WardenGlb.skeleton(h.get_node("Warden")).reset_bone_poses()


## The face's centre (m): a fixed lift over the head bone (the lips sit just below it, the crown 0.28 above it).
func _face(h: Node3D) -> Vector3:
	var skel := WardenGlb.skeleton(h.get_node("Warden"))
	return skel.global_transform * skel.get_bone_global_pose(_head(skel)).origin + Vector3(0, 0.04, 0)


## The head bone: the contract's `head`, or a Meshy-native rig's `Head`.
func _head(skel: Skeleton3D) -> int:
	var bi := WardenSkeleton.find(skel, "head")
	return bi if bi >= 0 else skel.find_bone("Head")


func _grab() -> Image:
	await tree.process_frame
	await tree.process_frame
	var img := tree.root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _state(st: String) -> void:
	var h := _hunter()
	var an := HunterAnim.new(h)
	if st == "bind":
		await _drive(an, h, "idle", 4)
		_freeze(h)
		await tree.process_frame
	else:
		await _drive(an, h, st, FRAMES)
	var c := _face(h)
	cam.fov = 14.0
	for v in VIEWS:
		var yaw := deg_to_rad(float(VIEWS[v][0]))
		var up := deg_to_rad(float(VIEWS[v][1]))
		var dir := Vector3(sin(yaw) * cos(up), sin(up), cos(yaw) * cos(up))
		cam.position = c + dir * 3.2
		cam.look_at(c)
		var img := await _grab()
		var m := int((img.get_height() - CROP) / 2.0)
		img.get_region(Rect2i(int((img.get_width() - CROP) / 2.0), m, CROP, CROP)).save_png(
			out.path_join("%s_%s_%s.png" % [tag, st, v])
		)
	if st == "idle" or st == "run":
		var p := deg_to_rad(GAME_PITCH)
		cam.fov = GAME_FOV
		cam.position = Vector3(0, 1.0, 0) + Vector3(0, sin(p), cos(p)) * GAME_DIST
		cam.rotation = Vector3(-p, 0, 0)
		await _drive(an, h, st, 4)
		var img2 := await _grab()
		var a := cam.unproject_position(Vector3(-1.0, 2.2, -0.6))
		var b := cam.unproject_position(Vector3(1.0, -0.2, 1.0))
		var crop := img2.get_region(Rect2i(Vector2i(a), Vector2i(b - a)))
		crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
		crop.save_png(out.path_join("%s_game_%s.png" % [tag, st]))
	h.queue_free()
	await tree.process_frame


## The gum's vertices (surface of 138, skinned whole to the bone `gum`) in the head bone's frame, metres.
func _gum_pts(
	skel: Skeleton3D, gum_bi: int, head_bi: int, mi: MeshInstance3D, verts: PackedVector3Array, inv_bind: Transform3D
) -> PackedVector3Array:
	var to_head := (skel.global_transform * skel.get_bone_global_pose(head_bi)).affine_inverse()
	var gum_w := skel.global_transform * skel.get_bone_global_pose(gum_bi) * inv_bind
	var pts := PackedVector3Array()
	for v in verts:
		pts.append(to_head * (gum_w * (mi.transform * v)))
	return pts


func _sweep() -> void:
	var h := _hunter()
	var an := HunterAnim.new(h)
	await _drive(an, h, "idle", 4)
	var glb := h.get_node("Warden") as Node3D
	var sync: Node = h.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	clips.tree.active = false
	var skel := WardenGlb.skeleton(glb)
	var gum_bi := skel.find_bone("gum")
	var head_bi := _head(skel)
	var mi: MeshInstance3D
	var verts := PackedVector3Array()
	for n in skel.find_children("*", "MeshInstance3D", true, false):
		var msh := (n as MeshInstance3D).mesh
		for s in msh.get_surface_count():
			var vs: PackedVector3Array = msh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			if vs.size() == 138 and mi == null:
				mi = n
				verts = vs
	var inv_bind := Transform3D.IDENTITY
	for i in mi.skin.get_bind_count():
		if mi.skin.get_bind_name(i) == "gum" or mi.skin.get_bind_bone(i) == gum_bi:
			inv_bind = mi.skin.get_bind_pose(i)
	var crown := (
		(skel.global_transform * skel.get_bone_global_pose(head_bi)).affine_inverse()
		* WardenGlb.anchor(h, "anchor_head_top").global_position
	)
	skel.reset_bone_poses()
	var bind := _gum_pts(skel, gum_bi, head_bi, mi, verts, inv_bind)
	var ap := AnimationPlayer.new()
	glb.add_child(ap)
	ap.root_node = ap.get_path_to(glb)
	ap.add_animation_library("", clips.lib)
	var rows: Array = ["clip\tlen_s\tcentre_x\tcentre_y\tcentre_z\ttop_below_crown_cm\tmax_drift_cm"]
	rows.append("# head-bone frame, metres; crown at y=%.3f; bind: %s" % [crown.y, _stat(bind, crown)])
	for nm in clips.lib.get_animation_list():
		var ln := clips.lib.get_animation(nm).length
		var worst := 0.0
		var top := 9.0
		var ctr := Vector3.ZERO
		for k in SAMPLES:
			ap.play(nm)
			ap.seek(ln * k / float(SAMPLES - 1), true)
			ap.advance(0.0)
			var pts := _gum_pts(skel, gum_bi, head_bi, mi, verts, inv_bind)
			var cn := _centre(pts)
			ctr += cn / SAMPLES
			worst = maxf(worst, (cn - _centre(bind)).length())
			for p in pts:
				top = minf(top, crown.y - p.y)
		rows.append(
			"%s\t%.2f\t%.3f\t%.3f\t%.3f\t%.1f\t%.1f" % [nm, ln, ctr.x, ctr.y, ctr.z, top * 100.0, worst * 100.0]
		)
	var f := FileAccess.open(out.path_join("%s_sweep.txt" % tag), FileAccess.WRITE)
	f.store_string("\n".join(rows) + "\n")
	f.close()
	h.queue_free()


func _centre(pts: PackedVector3Array) -> Vector3:
	var s := Vector3.ZERO
	for p in pts:
		s += p
	return s / pts.size()


func _stat(pts: PackedVector3Array, crown: Vector3) -> String:
	var c := _centre(pts)
	var top := 9.0
	for p in pts:
		top = minf(top, crown.y - p.y)
	return "centre (%.3f, %.3f, %.3f) top %.1f cm below crown" % [c.x, c.y, c.z, top * 100.0]
