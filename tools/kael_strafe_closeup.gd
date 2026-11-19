extends "res://tools/clip_shots.gd"
## --kael-strafe-closeup --shots-dir=<dir> [--mode=before|after] [--strafe-s=3]: Kael strafes left then right, close,
## full body at the true gait, frames to <dir>/<mode>/fNNN.png plus <dir>/<mode>/measure.txt (planted-foot slip m/s per
## direction, tools/foot_slide_check.gd's rule). "before" drops loco.side_foot_mps (what 50f11e64e75^ had), "after"
## keeps the live kael.json. Floor posts scroll against his velocity, so a planted foot stays on its post. GPU only.

const AUDIT := preload("res://tools/anim_audit.gd")
const DT := 1.0 / 30.0
const HUNTER := "juggernaut"
const FACE := PI + 0.55        # facing the camera, turned a little: a 3/4 front view
const SPACING := 0.4
const GRID := 14
const WARM_S := 1.2
const SKIP_S := 0.8            # s after each switch left out of the slip read: the blend is still turning round

var posts: Array = []
var face_yaw := FACE
var measure_only := false
var span := SPACING * GRID

func run(main: Node) -> void:
	tree = main.get_tree()
	Save.no_write = true
	var out := ""
	var mode := "after"
	var secs := 3.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--mode="): mode = a.substr(7)
		if a.begins_with("--strafe-s="): secs = float(a.substr(11))
		if a.begins_with("--face="): face_yaw = float(a.substr(7))
		if a == "--measure-only": measure_only = true
	var px := Vector2i(960, 1080)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = px
	main.get_viewport().size = px
	_stage(main)
	var model := Models.hunter(Arch.weight(HUNTER), Data.TEAM_COLORS[0], Arch.signature(HUNTER), "", PlayerLook.neutral(), HUNTER)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	for k in 20:
		await tree.process_frame
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	if mode == "before":
		(clips.d["loco"] as Dictionary).erase("side_foot_mps")
	print("KAEL_SIDE_FOOT ", mode, " ", clips.d["loco"].get("side_foot_mps", "none"))
	model.rotation.y = face_yaw
	var sk := WardenGlb.skeleton(model.get_node("Warden"))
	var head := sk.get_bone_global_pose(WardenSkeleton.find(sk, "head")).origin.y * sk.global_transform.basis.get_scale().y
	# camera: waist-high, fov fitting the figure (head height ~ 'head') into ~70 % of the 1080 px
	var height := head * 1.12
	cam.fov = 20.0
	var dist := (height / 0.70) * 0.5 / tan(deg_to_rad(cam.fov * 0.5)) * (1080.0 / 1080.0)
	cam.position = Vector3(0.0, height * 0.42 + 0.35, dist)
	cam.look_at(Vector3(0, height * 0.40, 0))
	_posts()
	var speed := float(HunterMove.of(HUNTER)["speed"])
	var right := Vector3(cos(face_yaw), 0, -sin(face_yaw))
	var dirs := [["L", -right], ["R", right]]
	var lines: Array = []
	var n := 0
	DirAccess.make_dir_recursive_absolute(out.path_join(mode))
	for d in dirs:
		var vel: Vector3 = (d[1] as Vector3) * speed
		model.set_meta(WardenClips.STATE, {"vel": vel, "face": face_yaw, "grounded": true})
		if n == 0:
			for k in int(WARM_S / DT):
				sync.call("_process", DT)
				_scroll(vel, DT)
		var fr: Array = []
		for k in int(secs / DT):
			sync.call("_process", DT)
			_scroll(vel, DT)
			fr.append(AUDIT.points(sk))
			if not measure_only:
				await _grab(out.path_join(mode).path_join("f%03d.png" % n))
			n += 1
		var slip := _slip(fr, vel, int(SKIP_S / DT))
		lines.append("%s %.2f" % [d[0], slip])
		print("KAEL_STRAFE ", mode, " ", d[0], " slip m/s ", "%.2f" % slip, " speed ", speed)
	var f := FileAccess.open(out.path_join(mode).path_join("measure.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\nframes %d\nspeed %.2f\n" % [n, speed])
	f.close()
	print("KAEL_STRAFE_DONE ", mode, " frames ", n)
	tree.quit()

## Mean flat speed of a planted foot against the ground, the frames after `skip` (foot_slide_check's rule).
func _slip(fr: Array, vel: Vector3, skip: int) -> float:
	fr = fr.slice(skip)
	var total := 0.0
	var cnt := 0
	for f in ["foot.L", "foot.R"]:
		var lo := INF
		var hi := -INF
		for p in fr:
			lo = minf(lo, (p[f] as Vector3).y)
			hi = maxf(hi, (p[f] as Vector3).y)
		for i in range(1, fr.size() - 1):
			if (fr[i][f] as Vector3).y > lo + AUDIT.PLANT_BAND * maxf(hi - lo, 0.02):
				continue
			var fv: Vector3 = ((fr[i + 1][f] as Vector3) - (fr[i - 1][f] as Vector3)) / (2.0 * DT)
			total += Vector2(vel.x + fv.x, vel.z + fv.z).length()
			cnt += 1
	return total / maxi(cnt, 1)

func _posts() -> void:
	var mat := Models.toon(Color("e8e0c0"), false)
	var mat2 := Models.toon(Color("1c2a14"), false)
	for ix in GRID:
		for iz in GRID:
			var post := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.07, 0.02, 0.07) if (ix + iz) % 2 == 0 else Vector3(0.05, 0.015, 0.05)
			post.mesh = box
			post.material_override = mat if (ix + iz) % 2 == 0 else mat2
			post.position = Vector3((ix - GRID / 2.0) * SPACING, 0.01, (iz - GRID / 2.0) * SPACING)
			holder.add_child(post)
			posts.append(post)

func _scroll(vel: Vector3, dt: float) -> void:
	for p in posts:
		var q := (p as Node3D).position
		q.x = fposmod(q.x - vel.x * dt + span / 2.0, span) - span / 2.0
		q.z = fposmod(q.z - vel.z * dt + span / 2.0, span) - span / 2.0
		(p as Node3D).position = q
