extends RefCounted
## --boki-rig-shots --shots-dir=<dir> [--species=cindle] [--px=512] [--normal-k=1]: the review sheets of a rigged
## Boki, in the engine (--normal-k=0 leaves a Meshy body's normal map out, for an A/B).
## <dir>/turntable.png, faces.png, coats.png, anim_<clip>.png (a strip of each clip), match.png (match camera),
## farm.png and farm_close.png (farm camera) and frames/<clip>/NNN.png for the GIFs (tools/boki/review_gifs.sh).
## Needs a renderer.

const YAWS := 8
const SHEET_COLS := 6
const SHEET_YAWS := [PI - 0.6, PI - PI / 2.0]    # front three-quarters, side
const STRIP := 6
const FACES := ["neutral", "happy", "sad", "sleepy", "angry", "bliss"]
const COATS := [
	{"mark": "spots", "mark_col": "dark", "eye": "sky", "ears": "tufted", "tailv": "bobbed",
		"birth": ["star", "chest"]},
	{"mark": "stripes", "mark_col": "light", "eye": "amber", "ears": "folded", "tailv": "kinked", "limb": 1.09},
	{"mark": "patches", "mark_col": "glow", "eye": "rose", "ears": "splayed", "tailv": "tufted", "ear": 1.1},
	{"mark": "plain", "eye": "classic", "ears": "standard", "tailv": "standard"}]
## Far shots: [clip, at (s), face], left to right.
const ACTION := [["idle", 0.5, "neutral"], ["run", 0.1, "cheer"], ["ability", 0.5, "angry"], ["hop", 0.45, "happy"]]
const EMOTES := [["idle", 0.5, "happy"], ["idle", 0.5, "sad"], ["idle", 0.5, "sleepy"], ["idle", 0.5, "angry"]]
const CLIPS := ["idle", "walk", "run", "attack", "ability", "hop", "sleep", "eat", "pet", "chop", "mine", "carry",
	"tend"]
const GIF_FPS := 15
const MATCH_PITCH := 66.0
const MATCH_DIST := 23.0
const MATCH_FOV := 32.0
const FARM_BOKI_SCALE := 1.7        # Home's farm scale
const FARM_DIST := 33.6             # 23 m x the farm's framing (1.216) x the old arrival zoom (1.2)
const FARM_CLOSE_DIST := 22.4       # the wheel all the way in (0.8)
const ENLARGE := 4
const FUSION_PART_K := 1.3            # merge_forms "part_k" of the fallback forms
## CamRig.char_lean, which BokiRig applies in the game: the top tips away from the camera.
const LEAN := deg_to_rad(20.0)

var main: Node
var out := ""
var species := "cindle"
var px := 512
var clips: Array = CLIPS
var sheet_frames := 0    # --sheet-frames=N: an animated sheet (see _sheet)
var dex_dir := ""    # --dex-dir=<dir> with --sheet: also dex_sheet_N.png from <dir>/<id>.glb, same height

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--species="): species = a.substr(10)
		if a.begins_with("--px="): px = int(a.substr(5))
		if a.begins_with("--dex-dir="): dex_dir = a.substr(10)
		if a.begins_with("--sheet-frames="): sheet_frames = int(a.substr(15))
		if a.begins_with("--normal-k="): BokiRig.normal_k = float(a.substr(11))
		if a.begins_with("--clips="): clips = Array(a.substr(8).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sheet="):    # one picture a view of every species listed, named, in a grid
			await _sheet(a.substr(8).split(","))
			print("BOKI_RIG_SHOTS_DONE")
			main.get_tree().quit()
			return
	await _turntable()
	await _faces()
	await _coats()
	await _grown()
	await _anims()
	await _fusion()
	await _far("match.png", MATCH_DIST, 1.0, ACTION, PI * 0.8)
	await _far("farm.png", FARM_DIST, FARM_BOKI_SCALE, ACTION, PI * 0.8)
	await _far("farm_faces.png", FARM_DIST, FARM_BOKI_SCALE, EMOTES, PI)
	await _far("farm_close.png", FARM_CLOSE_DIST, FARM_BOKI_SCALE, EMOTES, PI)
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
	if not Data.KIN.has(id):
		return _bare_kin(id)
	var k := Models.kin(id, rec)
	var flex := k.get_node("Body/Flex") as Node3D
	if flex.has_node("BokiRig"):
		return k
	var d := Unique.of(rec)
	for ch in flex.get_children():
		flex.remove_child(ch)
		ch.free()
	var mats: Array = k.get_meta("mats")
	var extra: Array = []
	var c := {"body": mats[0], "belly": mats[1], "dark": mats[2], "glow": mats[3], "eye": mats[4]}
	BokiRig.build(id, flex, c, extra)
	if not d.is_empty():
		BokiDna.wear(flex.get_node("BokiRig").skeleton(), flex, d, k.get_meta("mats"), rec)
	return k

## A species with a body in art/kin but no game data yet: its rig on a bare Body/Flex, neutral colours.
static func _bare_kin(id: String) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var flex := Node3D.new()
	flex.name = "Flex"
	body.add_child(flex)
	var neutral := Models.toon(Color.WHITE)
	var eye := Models.toon(Color.WHITE, false)
	BokiRig.build(id, flex, {"body": neutral, "belly": neutral, "dark": neutral, "glow": neutral, "eye": eye}, [])
	return root


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
	cam.position = Vector3(0, 0.8, 3.3)
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

## The contact sheet: <dir>/sheet_<view>.png, a cell a species (its name on it), SHEET_COLS to a row, from the front
## three-quarters and the side, standing (idle), as the game builds it. With --sheet-frames=N it is instead
## <dir>/sheet_<clip>_<k>.png: one sheet per --clips clip and frame k of N through the clip (an animated review).
func _sheet(ids: PackedStringArray) -> void:
	if sheet_frames > 0:
		for c in clips:
			for k in sheet_frames:
				await _sheet_png(ids, SHEET_YAWS[0], c, float(k) / sheet_frames, "sheet_%s_%d.png" % [c, k])
		return
	for view in SHEET_YAWS.size():
		await _sheet_png(ids, SHEET_YAWS[view], "idle", -1.0, "sheet_%d.png" % view)


## One sheet picture: every species in `clip` at `phase` (0..1 of its length; -1 = the idle pose at 0.5 s).
func _sheet_png(ids: PackedStringArray, yaw: float, clip: String, phase: float, file: String) -> void:
	var rows := (ids.size() + SHEET_COLS - 1) / SHEET_COLS
	var sheet := Image.create(px * SHEET_COLS, px * rows, false, Image.FORMAT_RGBA8)
	var dex_sheet := Image.create(px * SHEET_COLS, px * rows, false, Image.FORMAT_RGBA8)
	for n in ids.size():
		species = ids[n]
		var vp := _stage(Vector2i(px, px))
		var cam := _close_cam(vp)
		cam.position = Vector3(0, 0.8, 3.3)
		cam.look_at(Vector3(0, 0.42, 0))
		var tag := Label.new()
		tag.text = species
		tag.add_theme_font_size_override("font_size", px / 16)
		vp.add_child(tag)
		var kr := _kin(vp)
		await RenderingServer.frame_post_draw
		var rig := kr[1] as BokiRig
		rig.set_clip(clip, 0.0)
		rig.seek(0.5 if phase < 0.0 else phase * rig.player.get_animation(clip).length)
		(kr[0] as Node3D).rotation.y = yaw
		var img: Image = await _grab(vp)
		img.convert(Image.FORMAT_RGBA8)
		var at := Vector2i(n % SHEET_COLS * px, n / SHEET_COLS * px)
		sheet.blit_rect(img, Rect2i(0, 0, px, px), at)
		if dex_dir != "":
			var dex := _dex_model(species, _height(rig))
			if dex != null:
				(kr[0] as Node3D).visible = false
				vp.add_child(dex)
				dex.rotation.y = yaw - PI    # glTF models face +z, the game's face -z
				var dex_img: Image = await _grab(vp)
				dex_img.convert(Image.FORMAT_RGBA8)
				dex_sheet.blit_rect(dex_img, Rect2i(0, 0, px, px), at)
		vp.queue_free()
	sheet.save_png(out.path_join(file))
	if dex_dir != "":
		dex_sheet.save_png(out.path_join("dex_" + file))


## A model's box in its root's space (the model need not be in the tree).
static func _box(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var up: Node3D = mi
		while up != root:
			xf = up.transform * xf
			up = up.get_parent() as Node3D
		var b := xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _height(rig: BokiRig) -> float:
	return _box(rig.skeleton().get_parent() as Node3D).size.y


## The dex model <dex_dir>/<id>.glb (a plain, undraco'd glb), stood on the ground and scaled to `height` m.
func _dex_model(id: String, height: float) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(dex_dir.path_join(id + ".glb"), state) != OK:
		return null
	var holder := Node3D.new()
	var model := doc.generate_scene(state)
	holder.add_child(model)
	for n in model.find_children("*", "MeshInstance3D", true, false):
		for i in (n as MeshInstance3D).get_surface_override_material_count():
			var mat := (n as MeshInstance3D).mesh.surface_get_material(i) as BaseMaterial3D
			if mat != null:
				mat.metallic = 0.0    # a Meshy glb is fully metallic: black without a sky to reflect
	var box := _box(model)
	model.scale = Vector3.ONE * height / box.size.y
	model.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z) * model.scale.y
	return holder

func _faces() -> void:
	var vp := _stage(Vector2i(px, px), false)
	var cam := _close_cam(vp)
	cam.fov = 13.0
	var head: Vector3 = BokiRig.FRAME[species]["head"]
	cam.position = Vector3(0.0, head.y + 0.16, 3.3)
	cam.look_at(Vector3(0, head.y + 0.01, -0.1))
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

## The Fusion on a Hunter, close (front, 3/4, back) and at the match camera.
func _fusion() -> void:
	var key := BokiFusion.key_of(species)
	var form := {"id": key, "kit": key == "tidal_shell", "type": key, "glow": Data.KIN[species]["glow"]}
	if not BokiFusion.has(form):
		return
	var vp := _stage(Vector2i(px, px))
	var cam := _close_cam(vp)
	cam.fov = 26.0
	cam.position = Vector3(0, 1.5, 5.6)
	cam.look_at(Vector3(0, 1.0, 0))
	var h := Models.hunter(Arch.weight("gunslinger"), Data.TEAM_COLORS[0], Arch.signature("gunslinger"), "",
		PlayerLook.neutral(), "gunslinger")
	var box := Node3D.new()
	box.scale = Vector3.ONE * FUSION_PART_K
	h.get_node("Rig/Torso").add_child(box)
	BokiFusion.build(box, form, Vector3.ZERO)
	vp.add_child(h)
	var sheet := _strip(4)
	for i in 3:
		h.rotation.y = [0.0, -PI * 0.28, PI][i]
		var img: Image = await _grab(vp)
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(i * px, 0))
	var p := deg_to_rad(MATCH_PITCH)
	cam.fov = MATCH_FOV
	cam.position = Vector3(0, sin(p), cos(p)) * MATCH_DIST
	cam.rotation = Vector3(-p, 0, 0)
	h.rotation.y = -PI * 0.2
	var far: Image = await _grab(vp)
	var mid := Vector2i(cam.unproject_position(Vector3(0, 0.9, 0)))
	var crop := far.get_region(Rect2i(mid - Vector2i(64, 64), Vector2i(128, 128)))
	crop.resize(px, px, Image.INTERPOLATE_NEAREST)
	crop.convert(Image.FORMAT_RGBA8)
	sheet.blit_rect(crop, Rect2i(0, 0, px, px), Vector2i(3 * px, 0))
	sheet.save_png(out.path_join("fusion.png"))
	vp.queue_free()

## The four ways of growing up: Evo's tint and size with every part of that path, at level 2.
func _grown() -> void:
	var vp := _stage(Vector2i(px, px))
	var cam := _close_cam(vp)
	cam.position = Vector3(0, 0.95, 3.5)
	cam.look_at(Vector3(0, 0.5, 0))
	var sheet := _strip(Evo.AFF.size())
	var i := 0
	for aff in Evo.AFF:
		var rec := Save.new_kin(species, "Grown")
		rec["level"] = 12
		rec["forms"] = [aff, aff]
		rec["muts"] = []
		for part in Evo.AFF[aff]["parts"]:
			rec["muts"].append({"id": part, "lv": 2, "aff": aff})
		var k := rigged_kin(species, rec)
		vp.add_child(k)
		k.rotation.y = PI * 0.78
		var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
		rig.manual = true
		await RenderingServer.frame_post_draw
		rig.seek(0.5)
		var img: Image = await _grab(vp)
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(i * px, 0))
		k.queue_free()
		i += 1
	sheet.save_png(out.path_join("grown.png"))
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
	_hold_load(rig, c == "carry")
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

## Home's carried item, as the real farm gives it.
func _hold_load(rig: BokiRig, on: bool) -> void:
	var old := rig.root.get_node_or_null("Held")
	if old:
		old.free()
	if on:
		var it := WorkModels.held("chop", "")
		rig.root.add_child(it)
		it.position = BokiRig.FRAME[species]["carry"]

func _far(file: String, dist: float, boki_scale: float, picks: Array, yaw: float) -> void:
	var vp := _stage(Vector2i(1920, 1080))
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.fov = MATCH_FOV
	var p := deg_to_rad(MATCH_PITCH)
	cam.position = Vector3(0, sin(p), cos(p)) * dist
	cam.rotation = Vector3(-p, 0, 0)
	for i in picks.size():
		var kr := _kin(vp)
		var k := kr[0] as Node3D
		k.scale = Vector3.ONE * boki_scale
		k.position = Vector3((i - 1.5) * 1.5 * boki_scale, 0, 0)
		k.basis = Basis(Vector3.RIGHT, -LEAN) * Basis(Vector3.UP, yaw) * Basis.from_scale(k.scale)
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
