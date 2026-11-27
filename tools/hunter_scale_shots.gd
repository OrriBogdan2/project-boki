extends "res://tools/gameplay_media.gd"
## --hunter-scale-shots --shots-dir=<dir> [--hero=arch,arch]: each hero standing on the same open ground, shot at the
## old match size (every hunter at Hunter.VIS_SCALE 1.12) and at its own body.match_k, as <dir>/<hero>_<before|after>.png
## (no HUD) and <hero>_<before|after>_hud.png (with the overhead plate). Prints a HSCALE row per hero: on-screen
## body height in px at 1080p (feet to the top of the head), the model scale, and the hit radius (must not change).
## --gaps (no renderer needed): every archetype, at the old and the new size, prints a GAP row with the model's top
## (back props too) over the feet in m and the px (at 1080p) between the bottom of its own plate and of a rival's
## plate and that top
## (negative: the plate covers the model). Needs a renderer for the shots (jobq --needs gpu); 1920x1080 so the px read
## against a 1080p reference.

const SIZE := Vector2i(1920, 1080)
const HEROES := ["juggernaut", "gunslinger", "mage"]  # Kael, Vex, Sparkle (arch ids)
const SETTLE := 40  # frames (steps of 1/60 s) the hero idles before each shot
const WARDEN_SKIN := preload("res://tools/warden_skin.gd")
const PITCH_CLEAN := preload("res://tools/pitch_clean.gd")
const ROOM := 12  # tiles of open floor wanted all round the shot spot
const PLATE_H := 17.0  # px a plate hangs under its anchor (HudPlate._frame_rect: bars and frame)
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
	if OS.get_cmdline_user_args().has("--gaps"):
		await _gaps(heroes if heroes != HEROES else [])
		main.get_tree().quit(0)
		return
	var passes := ["before", "after"]
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--only="):
			passes = [String(a).substr(7)]
	for hero in heroes:
		await _start(hero, "cindle")
		for h in m.hunters:
			h.out = h != m.player  # alone on the ground: no squad mate or rival stands in the measure
		for k in m.kins:
			k.model.visible = false
		var top_h: Variant = Arch.body(hero).get("top_h")
		var own_k := Arch.match_k(hero)
		var at := _arena_spot(m.player.pos)
		_bare_floor(at)
		await _settle(at)  # one pose for both sizes: a shot only swaps the size
		for pass_name in passes:
			# "before" is main's code: the old size, the plates' old height (no top_h clearance)
			_draw_k(hero, 1.0 if pass_name == "before" else own_k)
			Arch.body(hero)["top_h"] = 0.0 if pass_name == "before" else top_h
			m.player.render(0.0, 1.0)
			await _shot(hero, pass_name)
		Arch.body(hero)["top_h"] = top_h
		m.queue_free()
	main.get_tree().quit(0)


## Draws the hero at match_k `k` (the data every plate and effect reads), keeping Kael's grow on the size it started at.
func _draw_k(hero: String, k: float) -> void:
	var was := m.player.vis_k
	Arch.body(hero)["match_k"] = k
	m.player.fit_scale()
	if m.player.model.has_meta("base_scale"):
		m.player.model.set_meta("base_scale", (m.player.model.get_meta("base_scale") as Vector3) * m.player.vis_k / was)


## The spot nearest `p` with the most open floor all round it that the island has (up to ROOM tiles from any cliff
## or the void): the standard match floor, no cliff edge or dark void in the frame.
func _arena_spot(p: Vector3) -> Vector3:
	var w: World = m.world
	for room in range(ROOM, 3, -2):
		var best := Vector3.INF
		var best_d := 1e9
		for z in range(int(p.z) - 24, int(p.z) + 25):
			for x in range(int(p.x) - 24, int(p.x) + 25):
				if w.tile_kind(x + 0.5, z + 0.5) != World.T_GROUND or w.edge_dist(x, z, room) <= room:
					continue
				var d := Vector2(x + 0.5 - p.x, z + 0.5 - p.z).length()
				if d < best_d:
					best_d = d
					best = Vector3(x + 0.5, 0.0, z + 0.5)
		if best_d < 1e9:
			print("ARENA %d tiles of floor all round, %.1f m from the spawn" % [room, best_d])
			return _ground(best)
	return _ground(p)


## One GAP row per archetype and size: "main" is the size before this rule, "now" the rule's.
func _gaps(heroes_arg := []) -> void:
	for hero in heroes_arg if not heroes_arg.is_empty() else Arch.ids():
		await _start(hero, "cindle")
		for h in m.hunters:
			h.out = h != m.player
		var at := _ground(m.player.pos)
		await _settle(at)
		var own_k := Arch.match_k(hero)
		for pass_name in ["main", "now", "fixed"]:
			_draw_k(hero, 1.0 if pass_name == "main" else own_k)
			m.player.render(0.0, 1.0)
			var p := m.player
			var up := _top_m(p.model) - p.position.y
			var column := _screen_y(p, up)
			var fixed: bool = pass_name == "fixed"
			var own := 2.7 * float(p.cdat["scale"])
			var rival := HudPlate.plate_offset(p)
			var k := float(SIZE.y) / main.get_viewport().get_visible_rect().size.y  # viewport px to 1080p px
			if fixed:
				own = HudPlate.up(p, own)
				rival = HudPlate.up(p, rival)
			print(
				(
					"GAP %s %s: top %.2f m (top_h %.3f), plate over it: own %.0f px, rival %.0f px (silh. %.0f, %.0f)"
					% [
						hero,
						pass_name,
						up,
						up / p.vis_k,
						(column - _screen_y(p, own * Arch.match_k(p.arch)) - PLATE_H) * k,
						(column - _screen_y(p, rival * Arch.match_k(p.arch)) - PLATE_H) * k,
						(_top(p.model) - _screen_y(p, own * Arch.match_k(p.arch)) - PLATE_H) * k,
						(_top(p.model) - _screen_y(p, rival * Arch.match_k(p.arch)) - PLATE_H) * k
					]
				)
			)
		m.queue_free()


## The screen y of the point `up` m over the hunter's feet, leaning with the body like the plates do.
func _screen_y(p: Hunter, up: float) -> float:
	return m.cam.unproject_position(p.position + m.cam.char_lean() * Vector3(0, up, 0)).y


func _settle(at: Vector3) -> void:
	var p := m.player
	p.teleport(at)
	p.vel = Vector3.ZERO
	m.cam.zoom = 1.0
	m.cam.snap(p.pos)
	for _i in SETTLE:
		_purge()
		p.inp["aim"] = p.pos + Vector3(8.0, 0.9, 0.0)  # side on to the camera: the weapon shows in profile
		m.step(STEP)
		m.cam.follow(p.pos, STEP, false)
		for h in m.hunters:
			h.render(STEP, 1.0)
		_clean()
	await main.get_tree().process_frame
	_clean()


## The floor round `at` as the match lays it, minus the dressing that would hide a hunter's legs or pull the eye: tall
## grass, rocks, camps and the chests go; the short grass and flowers stay (PitchClean.clear_deco).
func _bare_floor(at: Vector3) -> void:
	print("BARE ", PITCH_CLEAN.clear_deco(m, at, 16.0), " pieces of dressing hidden")
	for c in m.chests:
		if is_instance_valid(c.get("node")):
			(c["node"] as Node3D).visible = false


## The match's own aim line (the white line through a hunter that aims) and message cards stay out of the shot.
func _clean() -> void:
	var aim := m.get_node_or_null("AimKit") as Node3D
	if aim != null:
		aim.visible = false
	m.hud.msgs.clear()


func _shot(hero: String, pass_name: String) -> void:
	var p := m.player
	var hud := m.hud
	hud.visible = true
	_clean()
	await _save("%s_%s_hud.png" % [hero, pass_name])
	hud.visible = false
	await _save("%s_%s.png" % [hero, pass_name])
	hud.visible = true
	var feet := m.cam.unproject_position(p.position)
	var top := _top(p.model)
	var up := HudPlate.up(p, 2.7 * float(p.cdat["scale"])) * Arch.match_k(p.arch)
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


## The screen y of the highest point of the body's meshes.
func _top(model: Node3D) -> float:
	var top := 1e9
	for wp in _body_points(model):
		top = minf(top, m.cam.unproject_position(wp).y)
	return top


## The world y of the highest point of the body's meshes.
func _top_m(model: Node3D) -> float:
	var top := -1e9
	for wp in _body_points(model):
		top = maxf(top, wp.y)
	return top


## The body's meshes' world points: a Warden's skinned mesh counts its posed vertices, any other mesh its box corners.
func _body_points(model: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var stack: Array = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.name in SKIP:
			continue
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or not mi.is_visible_in_tree():
			continue
		if mi.skin:
			out.append_array(WARDEN_SKIN.points(mi))
		else:
			for c in 8:
				out.append(mi.global_transform * mi.get_aabb().get_endpoint(c))
	return out
