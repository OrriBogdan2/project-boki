extends RefCounted
## --boki-rig-shots --shots-dir=<dir> [--species=cindle] [--px=512]: the review sheets of a rigged Boki, in the engine.
## <dir>/turntable.png, faces.png, anim_<clip>.png (a strip of each clip), match.png (match camera), farm.png (farm
## camera) and frames/<clip>/NNN.png for the GIFs (tools/boki/review_gifs.sh). Needs a renderer.

const YAWS := 8
const STRIP := 6
const FACES := ["neutral", "happy", "sad", "sleepy", "angry", "bliss"]
const CLIPS := ["idle", "walk", "run", "attack", "ability", "hop", "sleep", "eat", "pet", "chop", "mine", "carry"]
const GIF_FPS := 15
const MATCH_PITCH := 66.0
const MATCH_DIST := 23.0
const MATCH_FOV := 32.0
const FARM_BOKI_SCALE := 1.7        # Home's farm scale
const FARM_PITCH := 55.0
const FARM_DIST := 29.0
const FARM_FOV := 28.0
const ENLARGE := 4

var main: Node
var out := ""
var species := "cindle"
var px := 512

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--species="): species = a.substr(10)
		if a.begins_with("--px="): px = int(a.substr(5))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	await _turntable()
	await _faces()
	await _anims()
	await _far("match.png", MATCH_PITCH, MATCH_DIST, MATCH_FOV, 1.0)
	await _far("farm.png", FARM_PITCH, FARM_DIST, FARM_FOV, FARM_BOKI_SCALE)
	print("BOKI_RIG_SHOTS_DONE")
	main.get_tree().quit()

func _stage(size: Vector2i, ground := true) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(vp)
	var env := WorldEnvironment.new()
	vp.add_child(env)
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"), "stars": 0.0})
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
	BokiRig.build(id, flex, {"body": mats[0], "belly": mats[1], "dark": mats[2], "glow": mats[3], "eye": mats[4]}, extra)
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
	cam.position = Vector3(0, 0.95, 3.3)
	cam.look_at(Vector3(0, 0.42, 0))
	return cam

func _grab(vp: SubViewport) -> Image:
	for k in 3:
		await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()

func _strip(n: int) -> Image:
	return Image.create(px * n, px, false, Image.FORMAT_RGBA8)

func _turntable() -> void:
	var vp := _stage(Vector2i(px, px))
	_close_cam(vp)
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
	for c in CLIPS:
		await _clip(vp, rig, String(c))
	vp.queue_free()

func _clip(vp: SubViewport, rig: BokiRig, c: String) -> void:
	rig.set_clip(c, 0.0)
	var length := rig.player.get_animation(c).length
	var frames := maxi(int(length * GIF_FPS), STRIP)
	var dir := out.path_join("frames").path_join(c)
	DirAccess.make_dir_recursive_absolute(dir)
	var sheet := _strip(STRIP)
	var every := float(frames) / STRIP
	var next := 0.0
	var tile := 0
	for f in frames:
		var k := float(f) / frames
		rig.set_face(_face_for(rig, c, k))
		rig.seek(k * length)
		var img: Image = await _grab(vp)
		img.convert(Image.FORMAT_RGBA8)
		img.save_png(dir.path_join("%03d.png" % f))
		if f >= next and tile < STRIP:
			sheet.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(tile * px, 0))
			tile += 1
			next += every
	sheet.save_png(out.path_join("anim_%s.png" % c))

func _far(file: String, pitch: float, dist: float, fov: float, boki_scale: float) -> void:
	var vp := _stage(Vector2i(1280, 720))
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.fov = fov
	var p := deg_to_rad(pitch)
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
	var half := Vector2i(160, 60) * int(boki_scale + 0.5)
	var crop := img.get_region(Rect2i(mid - half, half * 2))
	crop.resize(crop.get_width() * ENLARGE, crop.get_height() * ENLARGE, Image.INTERPOLATE_NEAREST)
	crop.save_png(out.path_join(file))
	vp.queue_free()
