extends "res://tools/mob_pose_shots.gd"
## --mob-turnaround-shots --shots-dir=<dir> [--kinds=a,b]: every art/mobs model as the game builds it, on a real GPU
## (jobq --needs gpu), in the format of docs/art/mobs/TURNAROUND_SPEC.md. Per kind <dir>/<kind>/ holds front.png,
## three_q.png, side.png, back.png (a free camera round the standing monster, same distance for all four),
## match.png (the match camera, a Hunter beside it for scale), windup.png and death.png (the MobAnim poses a real
## fight shows), and <dir>/turnaround.tsv with each model's measured height and width in metres. Models only
## render here; nothing is edited. tools/mob_turnaround_sheet.py lays the PNGs out as one sheet per mob.

const COMMON := ["skitter", "spitter", "bomber", "glimmer", "brute", "warden", "sentinel", "bl_skitter", "bl_warden"]
const BOSSES := ["colossus", "serpent", "brood"]
const VIEW_PX := 512  # px, each free-camera view (square)
const MATCH_PX := 420  # px, the match camera crop
## yaw from the monster's front (-z in model space): front, 3/4 (its right side), side (facing left), back
const VIEWS := {"front": 0.0, "three_q": 0.785, "side": -1.5708, "back": 3.1416}

var cam: Camera3D
var sun: DirectionalLight3D
var backdrop: MeshInstance3D
var studio := true  # false for the Blight: its bodies only draw on the live island
var rows: Array = []
var hidden_vis: Array = []  # the meshes and lights the free views switched off
var hidden_ui: Array = []  # the CanvasLayers the free views switched off


func run(mn: Node) -> void:
	var kinds := await setup(mn)
	var want: Array = COMMON + BOSSES
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--kinds="):
			want = kinds
	cam = Camera3D.new()
	cam.fov = 28.0
	main.add_child(cam)
	var env := Environment.new()  # bright flat light, so every model reads the same whatever the island's sky
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e8e8ee")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.7
	cam.environment = env
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)  # from the top left
	main.add_child(sun)
	for k in want:
		await _kind(String(k))
	var f := FileAccess.open(out_dir.path_join("turnaround.tsv"), FileAccess.WRITE)
	f.store_string("kind\theight_m\twidth_m\tdepth_m\thunter_m\n" + "\n".join(rows) + "\n")
	print("MOBTURNAROUND DONE")
	main.get_tree().quit()


func _kind(kind: String) -> void:
	var p: Hunter = m.player
	var dir := out_dir.path_join(kind)
	DirAccess.make_dir_recursive_absolute(dir)
	p.teleport(_open_ground(p.pos) + Vector3(40, 0, 0))
	await _frames(40)
	var at := _open_ground(p.pos)
	studio = not kind.begins_with("bl_")
	var mb: Mob = _spawn(kind, at)
	if mb == null:
		print("MOBTURNAROUND skip %s: no spawn" % kind)
		return
	p.teleport(at + Vector3(60, 0, 0))  # far: it stays calm
	for i in 50:
		_hold(mb)
		await main.get_tree().process_frame
	var box := _bounds(mb)
	var hunter_h := _bounds(p).size.y
	rows.append("%s\t%.2f\t%.2f\t%.2f\t%.2f" % [kind, box.size.y, box.size.x, box.size.z, hunter_h])
	if box.size.length() < 0.2:  # a body the skinned bounds miss: a small box at its feet
		box = AABB(mb.pos + Vector3(-0.6, 0, -0.6), Vector3(1.2, 0.8, 1.2))
	var ctr := box.get_center() - mb.global_position  # (kept relative: a monster that drifts is followed)
	_world_on(false, mb)
	var dist := maxf(box.size.length(), 1.0) * 1.15 / tan(deg_to_rad(cam.fov * 0.5)) * 0.5
	_studio(mb.pos, dist * 1.6)
	backdrop.visible = studio
	for lb in mb.find_children("*", "Label3D", true, false):  # nameplates and bars stay out of the views
		(lb as Node3D).visible = false
	cam.make_current()
	for v in VIEWS:
		await _view(mb, ctr, dist, float(VIEWS[v]), 0.0)
		(await _shot()).save_png(dir.path_join(v + ".png"))
	# the match camera, a Hunter one body-width beside the monster
	p.teleport(at + Vector3(box.size.x * 0.5 + 1.2, 0, 0.3))
	backdrop.visible = false  # (the match frame shows the real island)
	_world_on(true, mb)
	m.cam.make_current()
	for i in 30:
		_hold(mb)
		m.cam.focus = mb.pos
		await main.get_tree().process_frame
	(await _grab(mb)).save_png(dir.path_join("match.png"))
	# the wind-up: the last frame of the real attack's tell, the 3/4 camera
	if mb is Boss:
		await _boss_windup(mb as Boss, kind, at, ctr, dist, dir.path_join("windup.png"))
	elif MobAnim.has_kind(kind) or kind.begins_with("bl_"):
		backdrop.visible = studio
		_world_on(false, mb)
		p.visible = true  # (a hidden target is no target: the tell never starts)
		cam.make_current()
		p.teleport(at + Vector3(4.5, 0, 0))
		mb.tgt = p
		mb.root_t = 0.0
		mb._begin_attack()
		var last: Image = null
		var seen := false
		for i in 240:
			await _view(mb, ctr, dist, 0.785, 0.0)
			if mb.st == "windup":
				seen = true
				if MobAnim.windup_k(mb.st_t, float(mb.md["windup"])) > 0.5:
					last = await _shot()  # (the latest one stays: the fullest gather)
			elif seen:
				break
		if last != null:
			last.save_png(dir.path_join("windup.png"))
		else:
			print("MOBTURNAROUND %s: no wind-up frame" % kind)
	backdrop.visible = studio
	_world_on(false, mb)
	cam.make_current()
	# the death move held at 0.4 of DEATH_S, the dissolve parked (a slow frame would otherwise eat the body)
	p.teleport(at + Vector3(60, 0, 0))
	mb.hurt(mb.hp + mb.max_hp, p, {"src": "shot"})
	for i in 6:
		mb.set_meta("dis_lag", 5.0)
		mb.death_t = MobAnim.DEATH_S * 0.4
		await _view(mb, ctr, dist, 0.785, 0.0)
	(await _shot()).save_png(dir.path_join("death.png"))
	print("MOBTURNAROUND %s h=%.2f hunter=%.2f" % [kind, box.size.y, hunter_h])
	if is_instance_valid(mb):
		mb.visible = false
	_world_on(true, null)
	await _frames(40)


## A lair boss's first tell (slam, spit, storm): the frame just before its first blow, the 3/4 camera.
func _boss_windup(b: Boss, kind: String, at: Vector3, ctr: Vector3, dist: float, path: String) -> void:
	backdrop.visible = true
	_world_on(false, b)
	m.player.visible = true
	cam.make_current()
	m.player.teleport(at + Vector3(8.0, 0, 0))
	b.tgt = m.player
	match kind:
		"colossus":
			b._atk_slam()
		"brood":
			b._atk_spit()
		_:
			b._atk_storm()
	for i in 240:
		await _view(b, ctr, dist, 0.785, 0.0)
		if b.atk_t >= b.atk_hit * 0.85 or b.atk == "":
			break
	(await _shot()).save_png(path)
	b._clear_attack()


func _spawn(kind: String, at: Vector3) -> Mob:
	if kind in BOSSES:
		var L: Dictionary = m.lairs.list.filter(func(x): return x["boss"] == kind)[0]
		m.lairs.activate(L)
		if L["state"] == "sealed":
			m.lairs.open(L, m.player, "dial")
		return L["boss_mob"]
	if kind.begins_with("bl_") and m.blight != null:
		return m.blight.spawn(kind, at, 1.0)
	return m.spawn_mob(kind, at)


## Keeps the monster standing where it is: no wander, no chase.
func _hold(mb: Mob) -> void:
	if is_instance_valid(mb) and not mb.dead and mb.st in ["idle", "chase"]:
		mb.root_t = 0.1


## Aims the free camera at `ctr`, `yaw` round from the monster's front.
func _view(mb: Mob, ctr: Vector3, dist: float, yaw: float, pitch: float) -> void:
	var a: float = mb.model.global_rotation.y + PI + yaw  # the model's front is -z: its camera sits that way
	var c := mb.global_position + ctr
	backdrop.position = mb.global_position
	cam.global_position = c + Vector3(sin(a) * cos(pitch), sin(pitch), cos(a) * cos(pitch)) * dist
	cam.look_at(c)
	await main.get_tree().process_frame


func _shot() -> Image:
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var s := mini(img.get_width(), img.get_height())
	var out := img.get_region(Rect2i((img.get_width() - s) / 2, (img.get_height() - s) / 2, s, s))
	out.resize(VIEW_PX, VIEW_PX, Image.INTERPOLATE_LANCZOS)
	return out


func _open_ground(near: Vector3) -> Vector3:
	return _ground(near, 6.0)


## World-space bounds of every visible mesh under `n` (the rest pose's skinned box; rings and shadows left out).
func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi as MeshInstance3D
		var low := String(n.get_path_to(mesh)).to_lower()
		if not mesh.is_visible_in_tree() or mesh.mesh == null or low.contains("ring") or low.contains("shadow"):
			continue
		var bb := mesh.global_transform * mesh.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out


## Shows or hides everything in the match but the monster and the studio (the world, props, grass, the Hunter).
func _world_on(on: bool, keep: Node) -> void:
	if on:
		for cl in hidden_ui:
			(cl as CanvasLayer).visible = true
		hidden_ui.clear()
		for vi in hidden_vis:
			if is_instance_valid(vi):
				(vi as VisualInstance3D).visible = true
		hidden_vis.clear()
	else:
		for cl in main.find_children("*", "CanvasLayer", true, false):  # nameplates, pickers, reward cards
			if (cl as CanvasLayer).visible:
				(cl as CanvasLayer).visible = false
				hidden_ui.append(cl)
	if not studio and keep != null:
		return
	for n in m.get_children():
		if n is Node3D and n != keep and n != m.cam:
			(n as Node3D).visible = on
	m.player.visible = on
	if not on and keep != null:  # lair props switch their own root back on: hide their meshes one by one
		for vi in m.find_children("*", "VisualInstance3D", true, false):
			if (vi as VisualInstance3D).visible and not keep.is_ancestor_of(vi) and not m.player.is_ancestor_of(vi):
				(vi as VisualInstance3D).visible = false
				hidden_vis.append(vi)


## A flat #E8E8EE dome and floor round the monster, so the world's props stay out of the views.
func _studio(at: Vector3, reach: float = 14.0) -> void:
	if backdrop == null:
		backdrop = MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 14.0
		sph.height = 28.0
		backdrop.mesh = sph
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("e8e8ee")
		mat.cull_mode = BaseMaterial3D.CULL_FRONT
		backdrop.material_override = mat
		var floor_mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 13.0
		cyl.bottom_radius = 13.0
		cyl.height = 0.02
		floor_mi.mesh = cyl
		floor_mi.material_override = mat
		floor_mi.position.y = 0.0
		backdrop.add_child(floor_mi)
		main.add_child(backdrop)
	backdrop.position = at
	backdrop.scale = Vector3.ONE * reach / 14.0
	(backdrop.get_child(0) as Node3D).position.y = 0.02
