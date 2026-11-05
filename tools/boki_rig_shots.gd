extends RefCounted
## --boki-rig-shots --shots-dir=<dir> [--species=cindle] [--px=512]: the review sheets of a rigged Boki, in the engine.
## <dir>/turntable.png, faces.png, coats.png, anim_<clip>.png (a strip of each clip), match.png (match camera),
## farm.png and farm_close.png (farm camera) and frames/<clip>/NNN.png for the GIFs (tools/boki/review_gifs.sh).
## Needs a renderer.

const YAWS := 8
const STRIP := 6
const FACES := ["neutral", "happy", "sad", "sleepy", "angry", "bliss"]
const COATS := [{"mark": "spots", "mark_col": "dark", "eye": "sky"},
	{"mark": "stripes", "mark_col": "light", "eye": "amber"},
	{"mark": "patches", "mark_col": "glow", "eye": "rose"}, {"mark": "plain", "eye": "classic"}]
const CLIPS := ["idle", "walk", "run", "attack", "ability", "hop", "sleep", "eat", "pet", "chop", "mine", "carry"]
const GIF_FPS := 15
const MATCH_PITCH := 66.0
const MATCH_DIST := 23.0
const MATCH_FOV := 32.0
const FARM_BOKI_SCALE := 1.7        # Home's farm scale
const FARM_DIST := 33.6             # 23 m x the farm's framing (1.216) x HOME_ZOOM (1.2)
const FARM_CLOSE_DIST := 22.4       # the wheel all the way in (0.8)
const ENLARGE := 4

var main: Node
var out := ""
var species := "cindle"
var px := 512
var clips: Array = CLIPS

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--species="): species = a.substr(10)
		if a.begins_with("--px="): px = int(a.substr(5))
		if a.begins_with("--clips="): clips = Array(a.substr(8).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	await _turntable()
	await _faces()
	await _coats()
	await _anims()
	await _far("match.png", MATCH_DIST, 1.0)
	await _far("farm.png", FARM_DIST, FARM_BOKI_SCALE)
	await _far("farm_close.png", FARM_CLOSE_DIST, FARM_BOKI_SCALE)
	print("BOKI_RIG_SHOTS_DONE")
	main.get_tree().quit()

func _stage(px_size: Vector2i, ground := true) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = px_size
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(vp)
	var env := WorldEnvironment.new()
	vp.add_child(env)
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"),
		"stars": 0.0})
	Look.lights(vp, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	if ground:
		var g := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(80, 60)
		g.mesh = pm
		g.material_override = Models.toon(Color("4f7a3e"), false)
		vp.add_child(g)
	return vp

## A kin wearing its rigged model, whether or not Models.kin is wired to it yet.
static func rigged_kin(id: String, rec := {}) -> Node3D:
	var k := Models.kin(id, rec)
	var flex := k.get_node("Body/Flex") as Node3D
	if flex.has_node("BokiRig"):
		return k
	for ch in flex.get_children():
		flex.remove_child(ch)
		ch.free()
	var mats: Array = k.get_meta("mats")
	var extra: Array = []
	var c := {"body": mats[0], "belly": mats[1], "dark": mats[2], "glow": mats[3], "eye": mats[4]}
	BokiRig.build(id, flex, c, extra)
	return k

func _kin(vp: SubViewport) -> Array:
	var k := rigged_kin(species)
	vp.add_child(k)
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	rig.manual = true
	return [k, rig]

func _close_cam(vp: SubViewport) -> Camera3D:
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.fov = 24.0
	cam.near = 0.5
	cam.position = Vector3(0, 0.95, 4.2)
	cam.look_at(Vector3(0, 0.45, 0))
	return cam

func _grab(vp: SubViewport) -> Image:
	for k in 3:
		await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()

func _strip(n: int) -> Image:
	return Image.create(px * n, px, false, Image.FORMAT_RGBA8)

func _turntable() -> void:
	var vp := _stage(Vector2i(px, px))
	var cam := _close_cam(vp)
	cam.position = Vector3(0, 0.8, 2.9)
	cam.look_at(Vector3(0, 0.42, 0))
	var kr := _kin(vp)
	await RenderingServer.frame_post_draw
	(kr[1] as BokiRig).seek(0.5)
	var sheet := _strip(YAWS)
	for i in YAWS:
		(kr[0] as Node3D).rotation.y = PI - TAU * i / YAWS
		var img: Image = await _grab(vp)
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(i * px, 0))
		img.save_png(out.path_join("frames_turn_%d.png" % i))
	sheet.save_png(out.path_join("turntable.png"))
	vp.queue_free()

func _faces() -> void:
	var vp := _stage(Vector2i(px, px), false)
	var cam := _close_cam(vp)
	cam.fov = 13.0
	cam.position = Vector3(0.0, 0.62, 3.3)
	cam.look_at(Vector3(0, 0.46, -0.1))
	var kr := _kin(vp)
	(kr[0] as Node3D).rotation.y = PI
	await RenderingServer.frame_post_draw
	var sheet := _strip(FACES.size())
	var rig := kr[1] as BokiRig
	for i in FACES.size():
		rig.set_face(String(FACES[i]))
		rig.seek(0.5)
		var img: Image = await _grab(vp)
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(i * px, 0))
	sheet.save_png(out.path_join("faces.png"))
	vp.queue_free()

## Each Boki its own: coat marks, eye colours, the shimmer palette.
func _coats() -> void:
	var vp := _stage(Vector2i(px, px))
	var cam := _close_cam(vp)
	cam.position = Vector3(0, 0.8, 2.9)
	cam.look_at(Vector3(0, 0.42, 0))
	var sheet := _strip(COATS.size())
	for i in COATS.size():
		var rec := Save.new_kin(species, "Coat")
		rec["dna"] = Unique.roll(1000 + i)
		rec["dna"].merge(COATS[i], true)
		rec["shimmer"] = i == COATS.size() - 1
		rec["level"] = 8
		var k := rigged_kin(species, rec)
		vp.add_child(k)
		k.rotation.y = PI * 0.8
		var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
		rig.manual = true
		await RenderingServer.frame_post_draw
		rig.seek(0.5)
		var img: Image = await _grab(vp)
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(i * px, 0))
		k.queue_free()
	sheet.save_png(out.path_join("coats.png"))
	vp.queue_free()

func _face_for(rig: BokiRig, clip_id: String, k: float) -> String:
	var cf: Variant = BokiRig.CLIP_FACE.get(clip_id, "neutral")
	if cf is Array:
		var best := "neutral"
		for beat in cf:
			if float(beat[0]) <= k:
				best = String(beat[1])
		return best
	return String(cf)

func _anims() -> void:
	var vp := _stage(Vector2i(px, px))
	_close_cam(vp)
	var kr := _kin(vp)
	var rig := kr[1] as BokiRig
	(kr[0] as Node3D).rotation.y = PI * 0.72
	await RenderingServer.frame_post_draw
	for c in clips:
		await _clip(vp, rig, String(c))
	vp.queue_free()

func _clip(vp: SubViewport, rig: BokiRig, c: String) -> void:
	rig.set_clip(c, 0.0)
	var clip_s := rig.player.get_animation(c).length
	var frames := maxi(int(clip_s * GIF_FPS), STRIP)
	var dir := out.path_join("frames").path_join(c)
	DirAccess.make_dir_recursive_absolute(dir)
	var sheet := _strip(STRIP)
	var every := float(frames) / STRIP
	var next := 0.0
	var tile := 0
	for f in frames:
		var k := float(f) / frames
		rig.set_face(_face_for(rig, c, k))
		rig.seek(k * clip_s)
		var img: Image = await _grab(vp)
		img.convert(Image.FORMAT_RGBA8)
		img.save_png(dir.path_join("%03d.png" % f))
		if f >= next and tile < STRIP:
			sheet.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(tile * px, 0))
			tile += 1
			next += every
	sheet.save_png(out.path_join("anim_%s.png" % c))

func _far(file: String, dist: float, boki_scale: float) -> void:
	var vp := _stage(Vector2i(1920, 1080))
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.fov = MATCH_FOV
	var p := deg_to_rad(MATCH_PITCH)
	cam.position = Vector3(0, sin(p), cos(p)) * dist
	cam.rotation = Vector3(-p, 0, 0)
	var picks := [["idle", 0.5, "neutral"], ["run", 0.1, "cheer"], ["ability", 0.5, "angry"], ["hop", 0.45, "happy"]]
	for i in picks.size():
		var kr := _kin(vp)
		var k := kr[0] as Node3D
		k.scale = Vector3.ONE * boki_scale
		k.position = Vector3((i - 1.5) * 1.5 * boki_scale, 0, 0)
		k.rotation.y = PI * 0.8
		var rig := kr[1] as BokiRig
		await RenderingServer.frame_post_draw
		rig.set_clip(String(picks[i][0]), 0.0)
		rig.set_face(String(picks[i][2]))
		rig.seek(float(picks[i][1]))
	var img: Image = await _grab(vp)
	var mid := Vector2i(cam.unproject_position(Vector3(0, 0.3, 0)))
	var half := Vector2i(190, 70) * int(boki_scale + 0.5)
	var crop := img.get_region(Rect2i(mid - half, half * 2))
	crop.resize(crop.get_width() * ENLARGE, crop.get_height() * ENLARGE, Image.INTERPOLATE_NEAREST)
	crop.save_png(out.path_join(file))
	vp.queue_free()
