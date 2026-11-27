extends "res://tools/gameplay_media.gd"
## --hunter-gpu-shots --heroes=<arch ids> --shots-dir=<dir> [--size=WxH]: each Hunter alone in a real match (Dusk Isles,
## seed 5), under the match camera, as <dir>/<hero>_<shot>.png: match (idle, the default zoom), zoom (idle,
## closer), run (moving, closer) and eye (idle, facing a camera at chest height, 3/4 front). Needs a renderer
## (jobq --needs gpu). --face: idle hunters aim at the camera;
## --raid=day (RaidLook) shoots in the overcast day instead of the clear evening.

const SIZE := Vector2i(1600, 900)  # px of each shot (--size=WxH)
const SETTLE := 1.5  # s of idle before a shot
const RUN_SECS := 1.2  # s of run before the run shot
const ZOOM_CLOSE := 0.5  # camera zoom of the closer shots
const FACE_CAM := Vector3(0, 0.9, 3.0)  # --face: idle hunter aims toward the camera
const EYE_DIR := Vector3(0.45, 0.12, 1.0)  # the eye shot: camera direction from the hunter's middle (3/4 front)
const EYE_FOV := 30.0  # deg
const EYE_FILL := 0.8  # of the frame height the hunter fills
var face := false
var size := SIZE
var variants: Array = []  # --set=<name>:<param>=<v>,... shader overrides; shots <hero>_<name>_<shot>


func run(main_node: Node) -> void:
	main = main_node
	var heroes := ["gunslinger", "thief", "ashwick", "juggernaut", "rimewright"]
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--heroes="):
			heroes = Array(String(a).substr(9).split(","))
		if String(a) == "--face":
			face = true
		if String(a).begins_with("--set="):
			_add_variant(String(a).substr(6))
		if String(a).begins_with("--size="):
			var wh := String(a).get_slice("=", 1)
			size = Vector2i(int(wh.get_slice("x", 0)), int(wh.get_slice("x", 1)))
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	if variants.is_empty():
		variants.append(["", {}])
	main.get_window().size = size
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Settings.v["tips"] = false
	for hero in heroes:
		for v in variants:
			if m:
				m.queue_free()
			await _start(hero, "cindle")
			m.player.ctrl = "idle"
			m.player.teleport(_ground(m.player.pos))
			_apply(v[1])
			var tag: String = hero if v[0] == "" else "%s_%s" % [hero, v[0]]
			await _take(SETTLE, 1.0, Vector2.ZERO, "%s_match.png" % tag)
			await _take(SETTLE, ZOOM_CLOSE, Vector2.ZERO, "%s_zoom.png" % tag)
			await _take(RUN_SECS, ZOOM_CLOSE, Vector2(1, 0.4).normalized(), "%s_run.png" % tag)
			await _take(SETTLE, 1.0, Vector2.ZERO, "%s_eye.png" % tag, true)
		print("HUNTERGPU %s done" % hero)
	print("HUNTERGPU all in %s" % dir)
	main.get_tree().quit(0)


func _add_variant(spec: String) -> void:
	var d := {}
	for kv in spec.get_slice(":", 1).split(",", false):
		var val := kv.get_slice("=", 1)
		if val.contains("/"):  # x/y/z: a Vector3 (own_ambient), x/y/z/w: a Color
			var f := val.split_floats("/")
			d[kv.get_slice("=", 0)] = Vector3(f[0], f[1], f[2]) if f.size() == 3 else Color(f[0], f[1], f[2], f[3])
		else:
			d[kv.get_slice("=", 0)] = float(val)
	variants.append([spec.get_slice(":", 0), d])


## The overrides on every toon material of the player's model.
func _apply(over: Dictionary) -> void:
	for mt in m.player.model.get_meta("mats", []) as Array:
		if not mt is ShaderMaterial:
			continue
		var surf = (mt as ShaderMaterial).get_shader_parameter("surface")  # (null on a flame/void/card surface)
		if not over.has("skin_only") or (surf != null and int(surf) == 4):
			for k in over:
				if k == "skin_only":
					continue
				if k == "rawtex":  # debug: the albedo atlas straight to the screen (unshaded)
					var sh := Shader.new()
					sh.code = (
						"shader_type spatial; render_mode unshaded; "
						+ "uniform sampler2D albedo_tex : source_color, filter_linear_mipmap; "
						+ "void fragment() { ALBEDO = texture(albedo_tex, UV).rgb; }"
					)
					(mt as ShaderMaterial).shader = sh
				elif k == "nomips":  # the albedo atlas sampled without its mip chain (texel-true, shimmers)
					var tex = (mt as ShaderMaterial).get_shader_parameter("albedo_tex")
					if tex is Texture2D:
						var img := (tex as Texture2D).get_image()
						img.clear_mipmaps()
						(mt as ShaderMaterial).set_shader_parameter("albedo_tex", ImageTexture.create_from_image(img))
				else:
					(mt as ShaderMaterial).set_shader_parameter(k, over[k])


## Steps `secs` of the match as Match runs a frame (the player holds `move`), then saves the shot.
## `eye`: the hunter faces the camera, which then moves to chest height in front of it (EYE_DIR).
func _take(secs: float, zoom_v: float, move: Vector2, file: String, eye := false) -> void:
	var p := m.player
	_zoom(zoom_v)
	m.cam.snap(p.pos)
	var t := 0.0
	while t < secs:
		_purge()
		p.inp["move"] = move
		if (face or eye) and move == Vector2.ZERO:
			p.inp["aim"] = p.pos + (EYE_DIR * Vector3(1, 0, 1) * 3.0 if eye else FACE_CAM)
		for _i in 2:
			m.step(STEP)
		m.cam.follow(p.pos, FRAME, false)
		for h in m.hunters:
			h.render(FRAME, 1.0)
		await main.get_tree().process_frame
		t += FRAME
	if eye:
		_eye_cam(p.model)
		await main.get_tree().process_frame
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file))


## The match camera at chest height, framing the model's meshes (their world box) EYE_FILL of the frame high.
func _eye_cam(model: Node3D) -> void:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if not (mi as MeshInstance3D).is_visible_in_tree():
			continue
		var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var c := box.get_center()
	var dist := box.size.y * 0.5 / EYE_FILL / tan(deg_to_rad(EYE_FOV * 0.5))
	m.cam.fov = EYE_FOV
	m.cam.global_position = c + EYE_DIR.normalized() * dist
	m.cam.look_at(c)
	print("HUNTERGPU eye box %s dist %.2f" % [box.size, dist])
