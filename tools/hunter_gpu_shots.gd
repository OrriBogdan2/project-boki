extends "res://tools/gameplay_media.gd"
## --hunter-gpu-shots --heroes=<arch ids> --shots-dir=<dir>: each Hunter alone in a real match (Dusk Isles, seed 5),
## under the match camera, as <dir>/<hero>_<shot>.png: match (idle, the camera's default zoom), zoom (idle, closer)
## and run (moving, closer). Needs a renderer (jobq --needs gpu). --face: idle hunters aim at the camera;
## --raid=day (RaidLook) shoots in the overcast day instead of the clear evening.

const SIZE := Vector2i(1600, 900)   # px of each shot
const SETTLE := 1.5                 # s of idle before a shot
const RUN_SECS := 1.2               # s of run before the run shot
const ZOOM_CLOSE := 0.5             # camera zoom of the closer shots
const FACE_CAM := Vector3(0, 0.9, 3.0)   # --face: idle hunter aims toward the camera
var face := false
var variants: Array = []    # --set=<name>:<param>=<v>,... shader overrides; shots <hero>_<name>_<shot>

func run(main_node: Node) -> void:
	main = main_node
	var heroes := ["gunslinger", "thief", "ashwick", "juggernaut", "rimewright"]
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--heroes="): heroes = Array(String(a).substr(9).split(","))
		if String(a) == "--face": face = true
		if String(a).begins_with("--set="): _add_variant(String(a).substr(6))
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	if variants.is_empty():
		variants.append(["", {}])
	main.get_window().size = SIZE
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
		print("HUNTERGPU %s done" % hero)
	print("HUNTERGPU all in %s" % dir)
	main.get_tree().quit(0)

func _add_variant(spec: String) -> void:
	var d := {}
	for kv in spec.get_slice(":", 1).split(",", false):
		var val := kv.get_slice("=", 1)
		if val.contains("/"):      # x/y/z: a Vector3 (own_ambient), x/y/z/w: a Color
			var f := val.split_floats("/")
			d[kv.get_slice("=", 0)] = Vector3(f[0], f[1], f[2]) if f.size() == 3 else Color(f[0], f[1], f[2], f[3])
		else:
			d[kv.get_slice("=", 0)] = float(val)
	variants.append([spec.get_slice(":", 0), d])

## The overrides on every toon material of the player's model.
func _apply(over: Dictionary) -> void:
	for mt in (m.player.model.get_meta("mats", []) as Array):
		if not mt is ShaderMaterial:
			continue
		var surf = (mt as ShaderMaterial).get_shader_parameter("surface")     # (null on a flame/void/card surface)
		if not over.has("skin_only") or (surf != null and int(surf) == 4):
			for k in over:
				if k == "skin_only":
					continue
				if k == "rawtex":      # debug: the albedo atlas straight to the screen (unshaded)
					var sh := Shader.new()
					sh.code = "shader_type spatial; render_mode unshaded; " \
						+ "uniform sampler2D albedo_tex : source_color, filter_linear_mipmap; " \
						+ "void fragment() { ALBEDO = texture(albedo_tex, UV).rgb; }"
					(mt as ShaderMaterial).shader = sh
				elif k == "nomips":      # the albedo atlas sampled without its mip chain (texel-true, shimmers)
					var tex = (mt as ShaderMaterial).get_shader_parameter("albedo_tex")
					if tex is Texture2D:
						var img := (tex as Texture2D).get_image()
						img.clear_mipmaps()
						(mt as ShaderMaterial).set_shader_parameter("albedo_tex", ImageTexture.create_from_image(img))
				else:
					(mt as ShaderMaterial).set_shader_parameter(k, over[k])

## Steps `secs` of the match as Match runs a frame (the player holds `move`), then saves the shot.
func _take(secs: float, zoom_v: float, move: Vector2, file: String) -> void:
	var P := m.player
	_zoom(zoom_v)
	m.cam.snap(P.pos)
	var t := 0.0
	while t < secs:
		_purge()
		P.inp["move"] = move
		if face and move == Vector2.ZERO:
			P.inp["aim"] = P.pos + FACE_CAM
		for _i in 2:
			m.step(STEP)
		m.cam.follow(P.pos, FRAME, false)
		for h in m.hunters:
			h.render(FRAME, 1.0)
		await main.get_tree().process_frame
		t += FRAME
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file))
