extends "res://tools/gameplay_media.gd"
## --hunter-scale-shots --shots-dir=<dir> [--hero=arch,arch]: each hero standing on the same open ground, shot at the
## old match size (Hunter.VIS_SCALE 1.12) and at the camera.json match_hunter_scale, as <dir>/<hero>_<before|after>.png
## (no HUD) and <hero>_<before|after>_hud.png (with the overhead plate). Prints a HSCALE row per hero: on-screen
## body height in px at 1080p (feet to the top of the head), the model scale, and the hit radius (must not change).
## Needs a renderer (jobq --needs gpu); 1920x1080 so the px read against a 1080p reference.

const SIZE := Vector2i(1920, 1080)
const HEROES := ["juggernaut", "gunslinger", "mage"]  # Kael, Vex, Sparkle (arch ids)
const SETTLE := 40  # frames (steps of 1/60 s) the hero idles before each shot
const WARDEN_SKIN := preload("res://tools/warden_skin.gd")
const SKIP := ["Glider", "Gun", "Shield", "TeamRing"]  # not the body: the glider, a held weapon, the hit ring


func run(main_node: Node) -> void:
	main = main_node
	var heroes: Array = HEROES
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--hero="):
			heroes = String(a).substr(7).split(",")
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	main.get_window().size = SIZE
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Settings.v["tips"] = false
	var after := Hunter.VIS_SCALE
	for hero in heroes:
		await _start(hero, "cindle")
		for h in m.hunters:
			h.out = h != m.player  # alone on the ground: no squad mate or rival stands in the measure
		for k in m.kins:
			k.model.visible = false
		var at := _ground(m.player.pos)
		await _settle(at)  # one pose for both sizes: the second shot only swaps the size, the clock does not move
		for pass_name in ["before", "after"]:
			Hunter.VIS_SCALE = 1.12 if pass_name == "before" else after
			m.player.render(0.0, 1.0)
			await _shot(hero, pass_name)
		m.queue_free()
	Hunter.VIS_SCALE = after
	main.get_tree().quit(0)


func _settle(at: Vector3) -> void:
	var p := m.player
	p.teleport(at)
	p.vel = Vector3.ZERO
	m.cam.zoom = 1.0
	m.cam.snap(p.pos)
	for _i in SETTLE:
		_purge()
		m.step(STEP)
		m.cam.follow(p.pos, STEP, false)
		for h in m.hunters:
			h.render(STEP, 1.0)
	await main.get_tree().process_frame


func _shot(hero: String, pass_name: String) -> void:
	var p := m.player
	var hud := m.hud
	hud.visible = true
	await _save("%s_%s_hud.png" % [hero, pass_name])
	hud.visible = false
	await _save("%s_%s.png" % [hero, pass_name])
	hud.visible = true
	var feet := m.cam.unproject_position(p.position)
	var top := _top(p.model)
	var up := HunterZone.PLATE_UP * float(p.cdat["scale"]) * Hunter.VIS_SCALE / 1.12
	var plate := m.cam.unproject_position(p.position + m.cam.char_lean() * Vector3(0, up, 0))
	# the viewport keeps the project's 1280x720 and the window shows it at 1920x1080: px are read at 1080p
	var k := float(SIZE.y) / main.get_viewport().get_visible_rect().size.y
	print(
		(
			"HSCALE %s %s: %.0f px tall, model scale %.3f, hit radius %.3f, plate anchor %.0f px over the head"
			% [hero, pass_name, (feet.y - top) * k, p.vis_k, p.hit_radius(), (top - plate.y) * k]
		)
	)


func _grab() -> Image:
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	return main.get_viewport().get_texture().get_image()


func _save(file: String) -> void:
	(await _grab()).save_png(dir.path_join(file))


## The screen y of the highest point of the body's meshes (a Warden's skinned mesh counts its posed vertices).
func _top(model: Node3D) -> float:
	var top := 1e9
	var stack: Array = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.name in SKIP:
			continue
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or not mi.is_visible_in_tree():
			continue
		var pts := PackedVector3Array()
		if mi.skin:
			pts = WARDEN_SKIN.points(mi)
		else:
			for c in 8:
				pts.append(mi.global_transform * mi.get_aabb().get_endpoint(c))
		for wp in pts:
			top = minf(top, m.cam.unproject_position(wp).y)
	return top
