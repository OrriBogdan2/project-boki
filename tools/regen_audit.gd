extends "res://tools/clip_shots.gd"
## --regen-audit --shots-dir=<dir> --wardens=a,b [--size=768] [--per-clip=10] [--fps=0] [--views=m,e,n,h,f] [--clips=a,b]:
## a Hunter's model as the
## game plays it (Models.hunter + WardenClips), every clip in its library, for a LIVE | NEW compare (run once without
## and once with --warden-variant=<art>_<tag>; docs/art/wardens/V95_SWAP.md "Regen from the turnaround").
## Per hunter <dir>/<id>/<view>/f00000.jpg.. for 5 views of every sample: m (match camera: fov 8 at 23 m),
## e (eye level, 4 m, 3/4), n (knee level, 4 m, 3/4), h (both hands close), f (both feet close).
## Extra views: y0..y3, eye level from 4 sides (the 3/4 front, then 90, 180, 270 degrees round the Hunter).
## Samples: the rest pose, then `per-clip` times evenly over each clip, or with --fps=N every 1/N s of it (a playing
## clip for an MP4, not a few stills). frames.txt: "<n> <clip> <t>".
## Needs a renderer.

const DT := 1.0 / 30.0
const THREE_Q_YAW := -PI / 2.0 - 0.55
var views: Array = ["m", "e", "n", "h", "f"]
var fps := 0.0


func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = []
	var names: Array = []
	var per_clip := 10
	frame_px = 768
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--wardens="):
			ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--clips="):
			names = Array(a.substr(8).split(",", false))
		if a.begins_with("--size="):
			frame_px = int(a.substr(7))
		if a.begins_with("--fps="):
			fps = float(a.substr(6))
		if a.begins_with("--views="):
			views = Array(a.substr(8).split(",", false))
		if a.begins_with("--per-clip="):
			per_clip = maxi(1, int(a.substr(11)))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	for id in ids:
		await _hunter(String(id), out.path_join(String(id)), names, per_clip)
	print("REGEN_AUDIT_DONE ", ids.size())
	tree.quit()


func _save_jpg(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_jpg(path, 0.92)


## The body's world box (visible meshes under Warden) -> [bottom y, height].
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


func _bone_at(sk: Skeleton3D, b: int) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(b).origin


## A close camera from the 3/4 front on the mid point of two bones, wide enough for both plus `pad` m round them.
func _close_on(sk: Skeleton3D, a: int, b: int, pad: float) -> void:
	var pa := _bone_at(sk, a)
	var pb := _bone_at(sk, b)
	var mid := (pa + pb) * 0.5
	var span := pa.distance_to(pb) + pad * 2.0
	cam.fov = 30.0
	var dist := maxf(0.5, span / (2.0 * tan(deg_to_rad(15.0))))
	cam.position = mid + Vector3(0, 0.25 * dist, dist)
	cam.look_at(mid)


func _shoot(model: Node3D, sk: Skeleton3D, hb: Array, fb: Array, dir: String, n: int) -> void:
	var name := "f%05d.jpg" % n
	var bx := _body_box(model)
	var lo: float = float(bx[0])
	var h := clampf(float(bx[1]), 1.2, 2.8)
	for v in views:
		match v:
			"m":
				cam.fov = 8.0
				cam.position = Vector3(0, 21.0, 9.4)
				cam.look_at(Vector3(0, 0.8, 0))
			"e", "n":
				cam.fov = rad_to_deg(2.0 * atan((h / 0.7) / (2.0 * 4.0)))
				cam.position = Vector3(0, lo + h * (0.92 if v == "e" else 0.28), 4.0)
				cam.look_at(Vector3(0, lo + h * 0.5, 0))
			"y0", "y1", "y2", "y3":
				cam.fov = rad_to_deg(2.0 * atan((h / 0.7) / (2.0 * 4.0)))
				var yaw := int(v.substr(1)) * PI * 0.5
				cam.position = Vector3(4.0 * sin(yaw), lo + h * 0.92, 4.0 * cos(yaw))
				cam.look_at(Vector3(0, lo + h * 0.5, 0))
			"h":
				_close_on(sk, hb[0], hb[1], 0.16)
			"f":
				_close_on(sk, fb[0], fb[1], 0.14)
		await _save_jpg(dir.path_join(v).path_join(name))


func _hunter(id: String, dir: String, names: Array, per_clip: int) -> void:
	for v in views:
		DirAccess.make_dir_recursive_absolute(dir.path_join(v))
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	for k in 60:  # (the first Hunter: past the splash)
		await tree.process_frame
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var sk := WardenGlb.skeleton(model.get_node("Warden"))
	var hb := [WardenSkeleton.find(sk, "hand.R"), WardenSkeleton.find(sk, "hand.L")]
	var foot := "foot" if WardenSkeleton.find(sk, "foot.R") >= 0 else "shin"
	var fb := [WardenSkeleton.find(sk, foot + ".R"), WardenSkeleton.find(sk, foot + ".L")]
	model.rotation.y = THREE_Q_YAW
	var rows: PackedStringArray = []
	for at in model.find_children("*", "AnimationTree", true, false):
		(at as AnimationTree).active = false
	sk.reset_bone_poses()
	for k in 10:
		await tree.process_frame
	await _shoot(model, sk, hb, fb, dir, 0)
	rows.append("0 rest 0.000")
	for at in model.find_children("*", "AnimationTree", true, false):
		(at as AnimationTree).active = true
	model.set_meta(WardenClips.STATE, {"vel": Vector3.ZERO, "face": THREE_Q_YAW, "grounded": true})
	for k in 20:
		sync.call("_process", DT)
	if clips == null:
		print("REGEN_AUDIT ", id, ": no clip library")
		model.queue_free()
		return
	if names.is_empty():
		for a in clips.lib.get_animation_list():
			names.append(String(a))
		names.sort()  # (as Strings: StringNames do not sort by their text)
	var n := 1
	for nm in names:
		if not clips.lib.has_animation(nm):
			print("REGEN_AUDIT missing clip ", nm)
			continue
		var length := clips.lib.get_animation(nm).length
		var count := per_clip if fps <= 0.0 else maxi(2, ceili(length * fps))
		for k in count:
			var t := minf(length * (k + 0.5) / count, length - 0.001)
			clips.force = {"clip": nm, "t": t}
			for j in 3:
				sync.call("_process", DT)
			await _shoot(model, sk, hb, fb, dir, n)
			rows.append("%d %s %.3f" % [n, nm, t])
			n += 1
	clips.force = {}
	var f := FileAccess.open(dir.path_join("frames.txt"), FileAccess.WRITE)
	f.store_string("\n".join(rows) + "\n")
	f.close()
	print("REGEN_AUDIT ", id, " frames ", n)
	model.queue_free()
