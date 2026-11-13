extends Control
## Uthana review renders: N panels side by side (current in-game | raw Uthana | cleaned), each the same rig, seen
## through the game's own camera (scripts/match/cam.gd "supervive": pitch 66, 23 m back, 32 deg lens, aimed 1 m above
## the feet, the body tipped back CHAR_LEAN) on a 1440p screen, cropped to PANEL px round the hunter.
## Arg: --jobs=<json: [{out, model, face_deg, loops, libs: {lib: {name: path .glb|.res}}, panels: [{label, seq}]}]>
## A seg of seq is {clip: "lib/name" or one of the model's own clips, dur (s, default its length: past the end it
## holds), from (s into the clip), whirl: hold_from (Breaker's held swing: the loop past hold_from runs on the kit's
## spin angle)}. Frames go to out/f%04d.png at 30 fps; one METRIC line per panel (foot slide, lowest foot, lowest
## bone above the floor).
const PANEL := 480                  ## px per panel
const SCREEN_H := 1440.0            ## px: the screen height the crop is cut from
const PITCH := deg_to_rad(66.0)     ## cam.gd STYLES.supervive
const DIST := 23.0                  ## m
const FOV := 32.0                   ## deg, vertical
const RISE := 1.0                   ## m above the feet the view aims at
const CHAR_LEAN := deg_to_rad(20.0) ## cam.gd CHAR_LEAN
const CONTACT_H := 0.06             ## m above the lowest foot height that counts as planted
const FPS := 30.0
const TAP := 0.2                    ## s: content/archetypes/bulwark.json lmb.tap (the hold whirl starts here)
const FULL := 1.25                  ## s: lmb.full
const SPIN_TURNS := [2.5, 4.0]      ## turns/s from no charge to full (lmb.spin_turns)
var _panels: Array[Dictionary] = []

func _ready() -> void:
	var path := ""
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--jobs="): path = s.trim_prefix("--jobs=")
	for job: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(path)):
		await _run(job)
	get_tree().quit()

func _run(job: Dictionary) -> void:
	var out := String(job["out"])
	DirAccess.make_dir_recursive_absolute(out)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	add_child(row)
	get_window().size = Vector2i(PANEL * job["panels"].size(), PANEL)
	_panels.clear()
	var libs := _libs(job.get("libs", {}))
	var period := 0.0
	for p: Dictionary in job["panels"]:
		var side := _make_panel(row, job, libs, p)
		period = maxf(period, side["len"])
		_panels.append(side)
	await RenderingServer.frame_post_draw ## warm-up: the first frame comes out blank
	await RenderingServer.frame_post_draw
	var n := int(ceil(period * FPS)) * int(job.get("loops", 1))
	for f in n:
		var t := fmod(f / FPS, period)
		for s in _panels:
			_pose(s, minf(t, s["len"]))
		_track(f)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/f%04d.png" % [out, f])
	for s in _panels:
		var vals := [out.get_file(), s["name"], s["len"], s["slide"], s["minh"], s["minb"]]
		print("METRIC %s | %s len=%.2f planted_slide_m=%.3f foot_min_y=%.3f body_min_y=%.3f" % vals)
	row.queue_free()
	await get_tree().process_frame

func _libs(spec: Dictionary) -> Dictionary:
	var out := {}
	for lib: String in spec:
		var al := AnimationLibrary.new()
		for nm: String in spec[lib]:
			var p := String(spec[lib][nm])
			al.add_animation(nm, UthanaClean.load_motion(p) if p.ends_with(".glb") else load(p))
		out[lib] = al
	return out

func _make_panel(row: HBoxContainer, job: Dictionary, libs: Dictionary, p: Dictionary) -> Dictionary:
	var box := SubViewportContainer.new()
	box.custom_minimum_size = Vector2(PANEL, PANEL)
	row.add_child(box)
	var vp := SubViewport.new()
	vp.size = Vector2i(PANEL, PANEL)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.17, 0.2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 25, 0)
	sun.shadow_enabled = true
	vp.add_child(sun)
	vp.add_child(_ground())
	var m: Node3D = load(String(job["model"])).instantiate()
	m.basis = Basis(Vector3.RIGHT, -CHAR_LEAN) * Basis(Vector3.UP, deg_to_rad(float(job.get("face_deg", -127.0))))
	vp.add_child(m)
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	for lib: String in libs:
		ap.add_animation_library(lib, libs[lib])
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	var seq: Array = p["seq"]
	var total := 0.0
	for seg: Dictionary in seq:
		var a := ap.get_animation(String(seg["clip"]))
		seg["at"] = total
		seg["d"] = float(seg.get("dur", a.length - float(seg.get("from", 0.0))))
		total += float(seg["d"])
	var cam := Camera3D.new()
	cam.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(FOV * 0.5)) * PANEL / SCREEN_H))
	vp.add_child(cam)
	var l := Label.new()
	l.text = String(p["label"])
	l.position = Vector2(8, 6)
	l.add_theme_font_size_override("font_size", 15)
	box.add_child(l)
	return {"m": m, "ap": ap, "sk": sk, "cam": cam, "seq": seq, "len": total, "name": l.text, "feet": _feet(sk),
		"prev": {}, "slide": 0.0, "minh": 99.0, "minb": 99.0}

## Seeks the panel's sequence to t (s): the segment playing then, held on its last frame past its end.
func _pose(s: Dictionary, t: float) -> void:
	var seg: Dictionary = s["seq"][0]
	for g: Dictionary in s["seq"]:
		if t >= float(g["at"]): seg = g
	var ap: AnimationPlayer = s["ap"]
	var clip := String(seg["clip"])
	var a := ap.get_animation(clip)
	var lt := t - float(seg["at"])
	var tt := float(seg.get("from", 0.0)) + lt
	if seg.has("whirl"):
		tt = _whirl_t(lt, float(seg["whirl"]), a.length)
	if ap.assigned_animation != clip:
		ap.play(clip)
		ap.pause()
	ap.seek(minf(tt, a.length - 0.001), true)

## The held swing's clip time lt s after the whirl starts (lmb_t = TAP + lt): bjorn_fx.gd hold() sets the loop's phase
## from the kit's spin (starting in front of him, a quarter turn on from the clip's 0), warden_clips.gd seeks it.
func _whirl_t(lt: float, hold_from: float, length: float) -> float:
	var spin := 0.0
	var t := 0.0
	while t < lt:
		var k := clampf(t / (FULL - TAP), 0.0, 1.0)      # bulwark_kit.gd smash_k()
		spin += TAU * lerpf(SPIN_TURNS[0], SPIN_TURNS[1], k) / 60.0
		t += 1.0 / 60.0
	var phase := fposmod((spin + PI * 0.5) / TAU, 1.0)
	return hold_from + phase * (length - hold_from - 0.001)

func _feet(sk: Skeleton3D) -> Array[int]:
	var out: Array[int] = []
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if n.begins_with("foot.") or n.begins_with("x_foot."): out.append(i)
	return out

func _ground() -> MeshInstance3D:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	g.mesh = pm
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.fill(Color(0.32, 0.33, 0.36))
	img.set_pixel(0, 0, Color(0.42, 0.43, 0.47))
	img.set_pixel(1, 1, Color(0.42, 0.43, 0.47))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(40, 40, 1) ## 0.5 m checks
	g.material_override = mat
	return g

## The game camera follows the root over the floor; the foot and floor metrics are read in the unleaned frame.
func _track(f: int) -> void:
	for s in _panels:
		var sk: Skeleton3D = s["sk"]
		var m: Node3D = s["m"]
		var upright := Transform3D(Basis(Vector3.UP, m.basis.get_euler().y), m.position) * sk.transform
		var r := sk.global_transform * sk.get_bone_global_pose(0).origin
		var aim := Vector3(r.x, RISE, r.z)
		var cam: Camera3D = s["cam"]
		cam.position = aim + Vector3(0, sin(PITCH), cos(PITCH)) * DIST
		cam.look_at(aim)
		for i in sk.get_bone_count():
			if i > 0: s["minb"] = minf(s["minb"], (upright * sk.get_bone_global_pose(i).origin).y)
		for b in s["feet"]:
			var p := upright * sk.get_bone_global_pose(b).origin
			s["minh"] = minf(s["minh"], p.y)
			if s["prev"].has(b) and p.y < s["minh"] + CONTACT_H and f > 2:
				var d: Vector3 = p - s["prev"][b]
				s["slide"] += Vector2(d.x, d.z).length()
			s["prev"][b] = p
