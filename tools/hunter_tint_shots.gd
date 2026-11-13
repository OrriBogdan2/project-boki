extends RefCounted
## --hunter-tint-shots --shots-dir=<dir> [--size=1920x1080]: every Hunter's colour as the game shows it, against
## its .glb as authored (the 11-11 "hunters read red" report). Writes at the window size:
## neutral.png (each .glb's own glTF materials, white key, grey ambient: the model as a glTF viewer shows it),
## select.png (the Hunters screen's turntable stage, HunterViewer, one per Hunter) and match.png / match_close.png
## (one of each Hunter in a real match's world and light at the match camera, then closer) and lit.png (each
## Hunter alone in the match's light, front 3/4, over its plain albedo: the .glb's paint, no light at all), printing
## each one's mean colour and red/blue ratio in both ("TINT"). Needs a renderer.

const GAP := 1.7              # m between Hunters in a row
const PER_ROW := 7
const ROW_GAP := 3.2          # m between the two rows (match shots)
const LIT_LAYER := 1 << 19   # the lit.png pass draws on this layer only
const STAGE := Vector2(270, 520)   # px: one Hunters-screen stage in the select sheet

var main: Node
var dir := ""

func run(main_node: Node) -> void:
	main = main_node
	var px := Vector2i(1920, 1080)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			px = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = px
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for id in Arch.ORDER:
		WardenGlb.neutral_rest(id)
	await _neutral()
	await _select()
	await _match()
	print("HUNTER-TINT-SHOTS done ", dir)
	main.get_tree().quit()

## Where the i-th Hunter stands in the two-row lineup (row 0 behind, row 1 in front).
func _spot(i: int, n: int) -> Vector3:
	var row := i / PER_ROW
	var in_row := mini(PER_ROW, n - row * PER_ROW)
	return Vector3((i % PER_ROW - (in_row - 1) * 0.5) * GAP, 0.0, (row - 0.5) * ROW_GAP)

func _grab(file: String, frames := 30) -> void:
	for i in frames:
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file))
	print("HUNTER-TINT-SHOT ", file)

## The .glb files on their own glTF materials: no toon pass, no look, no team.
func _neutral() -> void:
	var stage := Node3D.new()
	main.add_child(stage)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.5, 0.5, 0.5)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	stage.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 20, 0)
	stage.add_child(key)
	var n := Arch.ORDER.size()
	for i in n:
		var glb := (load(WardenGlb.path(Arch.ORDER[i])) as PackedScene).instantiate() as Node3D
		stage.add_child(glb)
		glb.position = Vector3(_spot(i, n).x, 2.4 * (1 - i / PER_ROW), 0.0)
		glb.rotation.y = PI
	var cam := Camera3D.new()
	cam.fov = 40.0
	stage.add_child(cam)
	cam.position = Vector3(0, 2.0, 9.5)
	cam.current = true
	await _grab("neutral.png")
	stage.queue_free()

## The Hunters screen's turntable stage (HunterViewer: its own light, the Hunter's rim colour), every Hunter's stage
## read off its SubViewport into one sheet.
func _select() -> void:
	var box := HBoxContainer.new()
	main.add_child(box)
	var views: Array = []
	for id in Arch.ORDER:
		var v := HunterViewer.make(id, STAGE, Vector2(90, 50), 1)
		box.add_child(v)
		views.append(v)
	for i in 240:
		await main.get_tree().process_frame
	for v in views:
		(v as HunterViewer).pivot.rotation.y = 0.0      # (face on, as the screen opens)
	for i in 3:
		await main.get_tree().process_frame
	var px := Vector2i(1920, 1080)
	var sheet := Image.create(px.x, px.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.06, 0.05, 0.09))
	var cell := Vector2i(px.x / PER_ROW, px.y / 2)
	for i in views.size():
		var img: Image = (views[i] as HunterViewer).vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var k := minf(float(cell.x) / img.get_width(), float(cell.y) / img.get_height())
		img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_LANCZOS)
		var at := Vector2i((i % PER_ROW) * cell.x + (cell.x - img.get_width()) / 2, (i / PER_ROW) * cell.y)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	sheet.save_png(dir.path_join("select.png"))
	print("HUNTER-TINT-SHOT select.png")
	box.queue_free()
	await main.get_tree().process_frame

## One of each Hunter in a real match (its world, light and post), at the match camera and closer.
func _match() -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 3, "tier": 0, "seed": 77, "no_drop": true, "god": true, "length": 1e9})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var c := m.player.pos
	var n := Arch.ORDER.size()
	for i in n:
		var id: String = Arch.ORDER[i]
		var h := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[i % 4], Arch.signature(id), "",
				PlayerLook.neutral(), id)
		m.add_child(h)
		var p := c + _spot(i, n) + Vector3(0, 0, 4.0)
		h.global_position = Vector3(p.x, m.world.ground_at(p.x, p.z), p.z)
	for h in m.hunters:
		h.visible = false
	m.cam.snap(c + Vector3(0, 0, 4.0))
	await _grab("match.png")
	m.cam.dist_mul = 0.45
	m.cam.snap(c + Vector3(0, 0, 4.0))
	await _grab("match_close.png")
	await _lit(m, c)

## Each Hunter in the match's own light (row 0) over the same .glb in its bare albedo, unlit (row 1), alone on
## LIT_LAYER through a camera with a cleared background, and the mean colour of each in both.
func _lit(m: Match, c: Vector3) -> void:
	m.cam.cull_mask &= ~LIT_LAYER
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	m.add_child(vp)
	var cam := Camera3D.new()
	cam.cull_mask = LIT_LAYER
	cam.environment = m.env.environment.duplicate()
	cam.environment.background_mode = Environment.BG_CLEAR_COLOR
	cam.fov = 30.0
	vp.add_child(cam)
	var n := Arch.ORDER.size()
	var gap := 1.8
	for i in n:
		var id: String = Arch.ORDER[i]
		var h := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
		var ring := h.get_node_or_null("TeamRing")
		if ring:
			(ring as Node3D).visible = false
		var raw := (load(WardenGlb.path(id)) as PackedScene).instantiate() as Node3D
		for mi in raw.find_children("*", "MeshInstance3D", true, false):
			for si in (mi as MeshInstance3D).mesh.get_surface_count():
				var src := (mi as MeshInstance3D).mesh.surface_get_material(si) as BaseMaterial3D
				var um := StandardMaterial3D.new()
				um.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				if src:
					um.albedo_texture = src.albedo_texture
					um.albedo_color = src.albedo_color
				(mi as MeshInstance3D).set_surface_override_material(si, um)
		for k in 2:
			var nd: Node3D = h if k == 0 else raw
			m.add_child(nd)
			nd.global_position = c + Vector3((i - (n - 1) * 0.5) * gap, -2.6 * k, 0.0)
			nd.rotation.y = PI + 0.5      # (front 3/4)
			for vi in nd.find_children("*", "VisualInstance3D", true, false):
				(vi as VisualInstance3D).layers = LIT_LAYER
	cam.position = c + Vector3(0.0, 1.2, 27.0)
	cam.look_at(c + Vector3(0.0, -0.4, 0.0))
	cam.make_current()
	for i in 30:
		await main.get_tree().process_frame
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(dir.path_join("lit.png"))
	print("HUNTER-TINT-SHOT lit.png")
	# each Hunter's cell: its column on screen, above the rows' split (lit) and below it (albedo)
	var split := int(cam.unproject_position(c + Vector3(0, -0.4, 0)).y)
	for i in n:
		var x0 := int(cam.unproject_position(c + Vector3((i - n * 0.5) * gap, 0, 0)).x)
		var x1 := int(cam.unproject_position(c + Vector3((i + 1 - n * 0.5) * gap, 0, 0)).x)
		var means: Array = []
		for rows in [[0, split], [split, img.get_height()]]:
			var sum := Vector3.ZERO
			var cnt := 0
			for y in range(rows[0], rows[1], 2):
				for x in range(x0, x1, 2):
					var px := img.get_pixel(x, y)
					if px.a > 0.9:
						sum += Vector3(px.r, px.g, px.b)
						cnt += 1
			means.append(sum / maxf(cnt, 1))
		var g: Vector3 = means[0]
		var a: Vector3 = means[1]
		var line := "TINT %-11s match %.2f %.2f %.2f R/B %.2f | albedo %.2f %.2f %.2f R/B %.2f"
		print(line % [Arch.ORDER[i], g.x, g.y, g.z, g.x / maxf(g.z, 0.01), a.x, a.y, a.z, a.x / maxf(a.z, 0.01)])
