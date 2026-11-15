extends RefCounted
## --turntable-video --shots-dir=<dir> [--tt-ids=a,b] [--tt-secs=6] [--tt-no-lineup]: capture-only footage for the
## pitch video (ext/footage-hl-1113, never merged). Each Hunter as the game builds it (Models.hunter: same loader,
## toon materials and scale), idle playing, one full 360 turn in tt-secs at 30 fps on a neutral studio floor, 1920x1080.
## Writes <dir>/<id>/NNNN.jpg per frame, then <dir>/lineup/NNNN.jpg (all of them in a row, the camera drifting
## across) and <dir>/lineup.png. Encode with ffmpeg afterwards. Needs a renderer (jobq --needs gpu).

const ALL := ["gunslinger", "juggernaut", "dolm", "tender", "mage", "archer", "bulwark", "ashwick", "rimewright",
	"dredge", "thief", "ostra"]
const LINE := ["archer", "juggernaut", "gunslinger", "bulwark", "rimewright", "ashwick", "dolm", "mage",
	"dredge", "tender", "thief", "ostra"]
const W := 1920
const H := 1080
const FPS := 30.0
const HIDE := ["TeamRing", "Glider", "Halo", "Focus"]
const BACK := Color("575a66")   # the studio backdrop: sky horizon, fog and far floor all meet in it

var tree: SceneTree
var holder: Node3D
var cam: Camera3D
var disc: MeshInstance3D
var out := "user://turntable"
var secs := 6.0
var env_res: Environment
var zoom := {"bulwark": 1.15}   # --tt-zoom=id:f,...: camera distance factor where skinned bounds miss a raised weapon

func run(main: Node) -> void:
	tree = main.get_tree()
	var ids: Array = ALL.duplicate()
	var lineup := true
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--shots-dir="):
			out = s.substr(12)
		if s.begins_with("--tt-ids="):
			ids = Array(s.substr(9).split(","))
		if s.begins_with("--tt-secs="):
			secs = float(s.substr(10))
		if s.begins_with("--tt-zoom="):
			for kv in s.substr(10).split(","):
				zoom[kv.get_slice(":", 0)] = float(kv.get_slice(":", 1))
		if s == "--tt-no-lineup":
			lineup = false
	if out.is_relative_path():
		out = ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(W, H)
	main.get_viewport().size = Vector2i(W, H)
	main.get_viewport().msaa_3d = Viewport.MSAA_4X
	_stage(main)
	for id in ids:
		await _turn(String(id))
	if lineup:
		await _lineup()
	print("TURNTABLE_DONE")
	tree.quit()

func _hunter(id: String) -> Node3D:
	var h := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	h.set_meta("anim_seed", 1)
	for nm in HIDE:
		var n := h.find_child(nm, true, false)
		if n and n is Node3D:
			(n as Node3D).visible = false
	return h

func _sync(h: Node) -> Node:
	var s := h.get_node_or_null("Warden/Sync")
	if s:
		s.set_process(false)
	return s

## One step of idle for every sync: t seconds into the idle clip (looping).
func _idle(syncs: Array, t: float) -> void:
	for s in syncs:
		if s == null:
			continue
		var clips: WardenClips = (s as Node).get("clips")
		if clips:
			var ln := 2.4
			if clips.lib and clips.lib.has_animation("idle"):
				ln = maxf(clips.lib.get_animation("idle").length, 0.5)
			clips.force = {"clip": "idle", "t": fmod(t, ln)}
		(s as Node).call("_process", 1.0 / FPS)

func _bounds(h: Node3D) -> AABB:
	var acc := AABB()
	var first := true
	for vi in h.find_children("*", "VisualInstance3D", true, false):
		var v := vi as VisualInstance3D
		if not v.is_visible_in_tree() or v is GPUParticles3D or v is CPUParticles3D or v is Light3D:
			continue
		var bb := v.global_transform * v.get_aabb()
		if bb.size.length() > 12.0:
			continue
		if first:
			acc = bb
			first = false
		else:
			acc = acc.merge(bb)
	return acc

func _turn(id: String) -> void:
	var h := _hunter(id)
	holder.add_child(h)
	var syncs := [_sync(h)]
	for k in 20:
		_idle(syncs, k / FPS)
		await tree.process_frame
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for k in 4:
		h.rotation.y = k * PI * 0.5
		_idle(syncs, 0.0)
		await tree.process_frame
		var bb := _bounds(h)
		lo = lo.min(bb.position)
		hi = hi.max(bb.end)
	lo.y = 0.0
	var tall := hi.y - lo.y
	var wide := maxf(hi.x - lo.x, hi.z - lo.z)
	cam.fov = 26.0
	var half_v := deg_to_rad(cam.fov * 0.5)
	var dist := maxf(tall * 0.5 / (tan(half_v) * 0.74), wide * 0.5 / (tan(half_v) * W / H * 0.5))
	dist *= float(zoom.get(id, 1.0))
	_fog(dist)
	var c := Vector3(0, tall * 0.5, 0)
	var pitch := deg_to_rad(9.0)
	cam.position = c + Vector3(0, sin(pitch), cos(pitch)) * dist
	cam.look_at(c)
	print("TT_FIT %s tall=%.2f wide=%.2f dist=%.2f" % [id, tall, wide, dist])
	var dir := out.path_join(id)
	DirAccess.make_dir_recursive_absolute(dir)
	var n := int(round(secs * FPS))
	for f in n:
		h.rotation.y = PI + 0.6 - TAU * f / n
		_idle(syncs, (20 + f) / FPS)
		await _grab(dir.path_join("%04d.jpg" % f))
	print("TT_HUNTER %s %d" % [id, n])
	h.queue_free()
	await tree.process_frame

func _lineup() -> void:
	disc.visible = false
	var gap := 1.5
	var hs: Array = []
	var syncs: Array = []
	for i in LINE.size():
		var h := _hunter(String(LINE[i]))
		h.rotation.y = PI
		h.position = Vector3((i - (LINE.size() - 1) * 0.5) * gap, 0, 0)
		holder.add_child(h)
		hs.append(h)
		syncs.append(_sync(h))
	for k in 20:
		_idle(syncs, k / FPS)
		await tree.process_frame
	cam.fov = 30.0
	var span := (LINE.size() - 1) * gap + 2.4
	var half_h := atan(tan(deg_to_rad(cam.fov * 0.5)) * float(W) / H)
	var dist := span * 0.5 / tan(half_h)
	var c := Vector3(0, 1.1, 0)
	_fog(dist)
	var dir := out.path_join("lineup")
	DirAccess.make_dir_recursive_absolute(dir)
	var n := int(round(secs * FPS))
	var pitch := deg_to_rad(9.0)
	for f in n:
		var u := float(f) / maxf(n - 1, 1)
		var yaw := deg_to_rad(lerpf(-8.0, 8.0, u))
		cam.position = c + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist * lerpf(1.03, 0.95, u)
		cam.look_at(c)
		_idle(syncs, (20 + f) / FPS)
		await _grab(dir.path_join("%04d.jpg" % f))
		if f == n / 2:
			await _grab(out.path_join("lineup.png"))
	print("TT_LINEUP %d" % n)
	# a closer dolly along the row, end to end (about five in frame at a time)
	dir = out.path_join("lineup_pan")
	DirAccess.make_dir_recursive_absolute(dir)
	var near := 7.5
	var half_x := (LINE.size() - 1) * gap * 0.5 - 2.6
	_fog(near)
	n = int(round(secs * 1.5 * FPS))
	for f in n:
		var u := float(f) / maxf(n - 1, 1)
		var x := lerpf(-half_x, half_x, smoothstep(0.0, 1.0, u))
		var at := Vector3(x, 1.0, 0)
		cam.fov = 30.0
		cam.position = at + Vector3(-1.2, sin(pitch) * near, cos(pitch) * near)
		cam.look_at(at)
		_idle(syncs, (20 + n + f) / FPS)
		await _grab(dir.path_join("%04d.jpg" % f))
	print("TT_LINEUP_PAN %d" % n)

## The floor fades into the backdrop from a little behind the subject (no horizon line in frame).
func _fog(subject_dist: float) -> void:
	env_res.fog_density = 1.0
	env_res.fog_depth_begin = subject_dist + 2.5
	env_res.fog_depth_end = subject_dist + 22.0
	env_res.fog_depth_curve = 1.0

func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := tree.root.get_texture().get_image()
	if path.ends_with(".png"):
		img.save_png(path)
	else:
		img.save_jpg(path, 0.93)

func _stage(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	env_res = Look.environment({"top": Color("1d2029"), "mid": Color("3a3e4a"), "horizon": BACK,
		"below": BACK, "stars": 0.0})
	env_res.fog_enabled = true
	env_res.fog_mode = Environment.FOG_MODE_DEPTH
	env_res.fog_light_color = BACK
	env_res.fog_light_energy = 1.0
	env_res.fog_sun_scatter = 0.0
	env_res.fog_sky_affect = 1.0
	env.environment = env_res
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-42, -35, 0), 30.0)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, 160, 0)
	rim.light_color = Color("cfe0ff")
	rim.light_energy = 0.55
	holder.add_child(rim)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	floor_mi.mesh = pm
	floor_mi.material_override = Models.toon(Color("6d6f78"), false)
	holder.add_child(floor_mi)
	disc = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.1
	cm.bottom_radius = 1.1
	cm.height = 0.02
	cm.radial_segments = 96
	disc.mesh = cm
	disc.position.y = 0.0
	disc.material_override = Models.toon(Color("80838e"), false)
	holder.add_child(disc)
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.make_current()
