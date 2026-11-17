extends "res://tools/warden_shots.gd"
## --shroud-shots --shots-dir=<dir>: the Empty's ten shrouds on one body (item 153). Writes contact.png (a flat-black
## silhouette row, the match camera at true pixels and enlarged, then a close row), poses.png (idle, run, jump, crouch
## and glide for every cut, at the match camera and close), and extras.png (hoods, trims, accessories).
## run.png has the run pose alone. Add --only=contact|run|poses|extras for one sheet, --cols=a,b,c for some of the
## cuts. Needs a renderer.

const BODY := {"unmasked": true, "colour": 5, "hollow": 0, "glow": 0, "ghost": 1, "aura": 0}
const POSE_NAMES := ["idle", "run", "jump", "crouch", "glide"]
const CUTS_PER_ROW := 5

var cuts: Array = []
var black: ShaderMaterial
var labels: Array = []

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var only := ""
	cuts = range(Shrouds.STYLES.size())
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--only="): only = a.substr(7)
		if a.begins_with("--cols="): cuts = Array(a.substr(7).split(",")).map(func(x): return int(x))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	_stage(main)
	if only in ["", "contact"]:
		await _contact(out)
	if only in ["", "run"]:
		await _poses(out, ["run"], "run")
	if only in ["", "poses"]:
		await _poses(out, POSE_NAMES, "poses_")
	if only in ["", "extras"]:
		await _extras(out)
	print("SHROUD_SHOTS_DONE")
	tree.quit()

func _empty(lk: Dictionary, at: Vector3, yaw: float) -> Node3D:
	var look := BODY.duplicate()
	look.merge(lk, true)
	var h := Models.hunter("medium", Data.TEAM_COLORS[0], "", "", look)
	h.position = at
	h.rotation.y = yaw
	var ring := h.get_node_or_null("TeamRing") as Node3D
	if ring: ring.visible = false
	h.get_node("Rig/Torso/Aim/Gun").free()      # empty-handed, as the creator shows you
	holder.add_child(h)
	anims.append([HunterAnim.new(h), h])
	return h

## Runs a body's animation into a state and copies it to the cloth.
func _state(i: int, st: String) -> void:
	var an: HunterAnim = anims[i][0]
	var h: Node3D = anims[i][1]
	var fwd := Vector3(-sin(h.rotation.y), 0, -cos(h.rotation.y))
	for k in 70 + i * 3:
		var s := {"fired": 99.0, "face": h.rotation.y, "grounded": true}
		match st:
			"run": s["vel"] = fwd * 5.5
			"jump":
				s["grounded"] = false
				s["vel"] = fwd * 2.0 + Vector3.UP * 3.0
			"crouch": s["crouch"] = 1.0
			"glide":
				s["grounded"] = false
				s["gliding"] = true
				s["vel"] = fwd * 7.0 + Vector3.DOWN * 2.0
		an.update(1.0 / 60.0, s)
	if st == "glide":
		var g := h.find_child("Glider", true, false) as Node3D
		if g: g.visible = false
	_sync()

func _sync() -> void:
	for a in anims:
		var sk := (a[1] as Node).find_child("ShroudBones", true, false) as ShroudSkin
		if sk: sk.sync_pose()

func _row_of(looks: Array, yaw := PI * 0.82, gap := GAP) -> Array:
	var row: Array = []
	for i in looks.size():
		row.append(_empty(looks[i], Vector3((i - (looks.size() - 1) * 0.5) * gap, 0, 0), yaw))
	return row

func _settle_idle() -> void:
	for i in anims.size():
		_state(i, "idle")

func _contact(out: String) -> void:
	var rows: Array = []
	for start in range(0, cuts.size(), CUTS_PER_ROW):
		var looks: Array = []
		for k in cuts.slice(start, start + CUTS_PER_ROW):
			looks.append({"shroud": k, "gender": 1})
		var row := _row_of(looks)
		_settle_idle()
		rows.append(await _match_crop(row, 2))
		rows.append(await _silhouette(row))
		_names(row, looks)
		rows.append(await _close(row))
		_clear()
		await tree.process_frame
	_stack(rows).save_png(out.path_join("contact.png"))
	if cuts.size() > CUTS_PER_ROW:
		var looks: Array = []
		for k in cuts:
			looks.append({"shroud": k, "gender": 1})
		var row := _row_of(looks, PI * 0.82, 1.9)
		_settle_idle()
		(await _match_crop(row, 1)).save_png(out.path_join("match_true_pixels.png"))
		(await _silhouette(row, 1)).save_png(out.path_join("silhouette_true_pixels.png"))
		_clear()
		await tree.process_frame

## The row at the match camera, cropped to it, at true pixels times k (nearest, so the pixels stay honest).
func _match_crop(row: Array, k: int) -> Image:
	var p := deg_to_rad(CAM_PITCH)
	cam.fov = CAM_FOV
	cam.position = Vector3(0, 1.0, 0) + Vector3(0, sin(p), cos(p)) * CAM_DIST
	cam.rotation = Vector3(-p, 0, 0)
	await _settle(4, false)
	_sync()
	var img := await _grab()
	var a := cam.unproject_position((row[0] as Node3D).position + Vector3(-1.2, 2.2, -1.0))
	var b := cam.unproject_position((row[row.size() - 1] as Node3D).position + Vector3(1.2, -0.2, 1.3))
	var crop := img.get_region(Rect2i(Vector2i(a), Vector2i(b - a)))
	crop.resize(crop.get_width() * k, crop.get_height() * k, Image.INTERPOLATE_NEAREST)
	return crop

## The cut's name over each body, for the close row.
func _names(row: Array, looks: Array) -> void:
	for i in row.size():
		var lb := Label3D.new()
		lb.text = String(Shrouds.LABELS[int(looks[i]["shroud"])])
		lb.font_size = 54
		lb.outline_size = 12
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.position = (row[i] as Node3D).position + Vector3(0, 2.15, 0)
		holder.add_child(lb)
		labels.append(lb)

func _close(row: Array) -> Image:
	var half := (row.size() - 1) * GAP * 0.5 + 1.1
	cam.fov = 26.0
	var dist := half / tan(atan(tan(deg_to_rad(cam.fov * 0.5)) * 16.0 / 9.0))
	cam.position = Vector3(0, 1.0, dist)
	cam.rotation = Vector3(-0.02, 0, 0)
	await _settle(4, false)
	_sync()
	var img := await _grab()
	for lb in labels:
		(lb as Node).queue_free()
	labels.clear()
	var top := int(cam.unproject_position(Vector3(0, 2.4, 0)).y)
	var bot := int(cam.unproject_position(Vector3(0, -0.1, 0.5)).y)
	return img.get_region(Rect2i(0, maxi(top, 0), img.get_width(), mini(bot, img.get_height()) - maxi(top, 0)))

## The row at the match camera, everything flat black on white: the shapes alone.
func _silhouette(row: Array, k := 2) -> Image:
	if black == null:
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled;\n"
		sh.code += "void fragment() { ALBEDO = vec3(0.0); }\n"
		black = ShaderMaterial.new()
		black.shader = sh
	var swap: Array = []
	for h in row:
		for mi in (h as Node).find_children("*", "MeshInstance3D", true, false):
			var g := mi as MeshInstance3D
			swap.append([g, g.material_override])
			g.material_override = black
	var ground: Array = holder.find_children("*", "MeshInstance3D", false, false)
	for g in ground:
		(g as Node3D).visible = false
	var env := (holder.find_children("*", "WorldEnvironment", false, false)[0] as WorldEnvironment).environment
	var was_mode := env.background_mode
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	var was_tone := env.tonemap_mode
	var was_glow := env.glow_enabled
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	var img := await _match_crop(row, k)
	env.background_mode = was_mode
	env.tonemap_mode = was_tone
	env.glow_enabled = was_glow
	for g in ground:
		(g as Node3D).visible = true
	for s in swap:
		(s[0] as MeshInstance3D).material_override = s[1]
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color.BLACK if c.r + c.g + c.b < 0.03 else Color.WHITE)
	return img

## A sheet per five cuts in each pose ("poses_1.png"...), or one sheet of all ten when `stem` doesn't end in "_".
func _poses(out: String, states: Array, stem: String) -> void:
	var rows: Array = []
	for start in range(0, cuts.size(), CUTS_PER_ROW):
		var some := cuts.slice(start, start + CUTS_PER_ROW)
		for st in states:
			var looks: Array = []
			for k in some:
				looks.append({"shroud": k, "gender": 1})
			var row := _row_of(looks, PI * 0.72)
			for i in row.size():
				_state(i, st)
			rows.append(await _match_crop(row, 2))
			_names(row, looks)
			rows.append(await _close(row))
			_clear()
			await tree.process_frame
		if stem.ends_with("_"):
			_stack(rows).save_png(out.path_join("%s%d.png" % [stem, start / CUTS_PER_ROW + 1]))
			rows.clear()
	if not stem.ends_with("_"):
		_stack(rows).save_png(out.path_join(stem + ".png"))

func _extras(out: String) -> void:
	var sets := [
		[{"shroud": 0, "hood": 1}, {"shroud": 0, "hood": 0}, {"shroud": 5, "hood": 1}, {"shroud": 4, "hood": 1},
			{"shroud": 9, "hood": 0}, {"shroud": 8, "hood": 1}],
		[{"shroud": 0, "trim": 0, "accent": 7}, {"shroud": 0, "trim": 1, "accent": 7},
			{"shroud": 0, "trim": 2, "accent": 7}, {"shroud": 0, "trim": 3, "accent": 7},
			{"shroud": 0, "trim": 4, "accent": 7}, {"shroud": 5, "trim": 4, "accent": 9}],
		[{"shroud": 3, "accessory": 1}, {"shroud": 3, "accessory": 2}, {"shroud": 3, "accessory": 3},
			{"shroud": 3, "accessory": 4}, {"shroud": 3, "accessory": 5}, {"shroud": 0, "accessory": 5}],
	]
	var rows: Array = []
	for looks in sets:
		var row := _row_of(looks, PI * 0.9)
		_settle_idle()
		rows.append(await _close(row))
		_clear()
		await tree.process_frame
	_stack(rows).save_png(out.path_join("extras.png"))

func _stack(rows: Array) -> Image:
	var hgt := 0
	for r in rows:
		hgt += int((r as Image).get_height() * float(OUT_W) / (r as Image).get_width()) + 6
	var sheet := Image.create(OUT_W, hgt, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1c1a24"))
	var y := 0
	for r in rows:
		var img := r as Image
		img.resize(OUT_W, int(img.get_height() * float(OUT_W) / img.get_width()), Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(0, y))
		y += img.get_height() + 6
	return sheet
