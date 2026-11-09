class_name Portraits
extends RefCounted
## Hunters' faces, wherever one is shown: the HUD's portrait slot, squad frames and ally popups, the
## Hunter pick, the Hunters screen and its viewer, the practice picker, the kit card and the unlock
## reveal. A Warden's painted portrait (art/portraits/<archetype>.jpg, made by tools/portrait_art.gd)
## is its face, and its splash (<archetype>_splash.jpg) fills the bigger spots (a Warden with no
## splash shows its portrait there). A Warden with no painted art falls back to a render of its model
## (make()). Each place draws a copy cut to its own size around the framing in
## content/rules/portraits.json, corners rounded (greyed for the fallen), made once and kept. A menu's
## portrait (Pic) reads its art on a loader thread and cuts it on a worker thread (cut_soon), so a screen
## full of faces never stalls a frame. Headless there are no pixels to cut: frames draw the art's region
## straight from its texture.

const SIZE := 96              # px: the rendered fallback's square
const RULES_PATH := "res://content/rules/portraits.json"
const SMALL_PX := 64.0        # px: a frame smaller than this crops in on the face
const SMALL_ZOOM := 0.6       # the share of the portrait's height a small frame shows
const FACE_AT := Vector2(0.5, 0.42)   # where the framing point lands in a cut (fractions of the frame)
const HEAD_MID := Vector3(0, 0.18, 0)      # the head's middle above its neck pivot (Models.hunter)

## Where the painted art is looked up (--portrait-check points it elsewhere to test the fallback).
static var art_dir := "res://art/portraits/"
static var _rules := {}
static var _cuts := {}        # "path|w|h|grey" -> ImageTexture
static var _art := {}         # path -> its Texture2D, kept once read (a face drawn again never reads the disk)
static var _jobs := {}        # cut key -> [worker task id, the cut Image once done] for cut_soon

## The painted art for an archetype: its splash if asked and it has one, else its portrait; "" if none.
static func art_path(ak: String, splash := false) -> String:
	if splash and ResourceLoader.exists(art_dir + ak + "_splash.jpg"):
		return art_dir + ak + "_splash.jpg"
	var path := art_dir + ak + ".jpg"
	return path if ResourceLoader.exists(path) else ""

## Whether an archetype has a painted portrait (else its frames show the rendered model).
static func has_art(ak: String) -> bool:
	return art_path(ak) != ""

## The archetype whose face a hunter shows (the one its model wears).
static func arch_of(h: Hunter) -> String:
	var look: Dictionary = Unmasked.mask_look() if h.ctrl == "local" else h.bot_look
	return HeroKit.arch_for(h.cls, h.arch, look)

## Corner radius of a portrait drawn at this size.
static func corner(sz: Vector2) -> int:
	return int(clampf(minf(sz.x, sz.y) * 0.11, 4.0, 12.0))

## A framed face. `fallback`: the rendered model, drawn when the archetype has no painted art.
## `edge`: the frame's colour. `state`: "" alive, "down" (red pulse, drained), "dead" (grey + X),
## "out" (check). `hurt` 0..1 flashes red on a hit; `low` 0..1 (health running out) drains the colour
## and pulses a red inner edge, the same rule as the health bar. `splash`: the splash where it has one.
static func draw(c: CanvasItem, r: Rect2, ak: String, fallback: Texture2D, edge: Color, state := "", hurt := 0.0,
		low := 0.0, time := 0.0, splash := false) -> void:
	var rad := corner(r.size)
	c.draw_style_box(HudStyle.box(HudStyle.SHADE_EDGE, rad + 2, Color(edge, 0.9), 2), r.grow(2.0))
	var path := art_path(ak, splash)
	if path == "":
		if fallback:
			c.draw_texture_rect(fallback, r, false)
	else:
		_draw_art(c, r, ak, path, state == "dead")
		var drain := 0.85 if state == "down" else low * 0.5
		var grey_cut := cut(ak, path, Vector2i(r.size.round()), true) if drain > 0.0 else null
		if grey_cut:
			c.draw_texture_rect(grey_cut, r, false, Color(1, 1, 1, drain))
	c.draw_line(r.position + Vector2(rad, 1), Vector2(r.end.x - rad, r.position.y + 1), Color(1, 1, 1, 0.16), 1.0)
	_draw_state(c, r, rad, state, hurt, low, time)

## Puts a Warden's face (`px` square, rounded) on a name chip as its icon, and tags the chip with the
## art it shows (meta "portrait_art"). No icon headless (no pixels) or for a Warden with no painted art.
static func set_icon(b: Button, ak: String, px: int) -> void:
	var path := art_path(ak)
	b.set_meta("portrait_art", path)
	if path != "":
		b.icon = cut(ak, path, Vector2i(px, px))

## The art at `path` cut to `px` around the archetype's framing, corners rounded, greyed if asked; null
## where its pixels can't be read (headless).
static func cut(ak: String, path: String, px: Vector2i, greyed := false) -> Texture2D:
	var key := _cut_key(path, px, greyed)
	if _cuts.has(key):
		return _cuts[key]
	var src := _pixels(_texture(path))
	if src == null:
		return null
	var at := Rect2i(region(ak, path, Vector2(src.get_size()), Vector2(px)))
	_cuts[key] = ImageTexture.create_from_image(_cut_pixels(src, at, px, greyed))
	return _cuts[key]

## The same cut, made off the main thread: null until it is ready (ask again next frame). The art is read
## on a loader thread and cut on a worker; headless (no pixels) it stays null.
static func cut_soon(ak: String, path: String, px: Vector2i, greyed := false) -> Texture2D:
	var key := _cut_key(path, px, greyed)
	if _cuts.has(key):
		return _cuts[key]
	if _jobs.has(key):
		var job: Array = _jobs[key]
		if not WorkerThreadPool.is_task_completed(int(job[0])):
			return null
		BackgroundWork.join(int(job[0]))
		_jobs.erase(key)
		_cuts[key] = ImageTexture.create_from_image(job[1])
		return _cuts[key]
	var src := _pixels(read_soon(path))
	if src == null:
		return null
	var at := Rect2i(region(ak, path, Vector2(src.get_size()), Vector2(px)))
	var job := [0, null]
	job[0] = BackgroundWork.add_task(func(): job[1] = _cut_pixels(src, at, px, greyed))
	_jobs[key] = job
	return null

static func _cut_key(path: String, px: Vector2i, greyed: bool) -> String:
	return "%s|%d|%d|%d" % [path, px.x, px.y, int(greyed)]

## The art's texture, read now if it isn't yet (kept for the session).
static func _texture(path: String) -> Texture2D:
	if not _art.has(path):
		_art[path] = load(path)
	return _art[path]

## The art's texture once a loader thread has read it (null while it reads; the read starts on the first ask).
static func read_soon(path: String) -> Texture2D:
	if _art.has(path):
		return _art[path]
	match ResourceLoader.load_threaded_get_status(path):
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			BackgroundWork.request(path)
			return null
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return null
	_art[path] = BackgroundWork.take(path)
	return _art[path]

## The texture's pixels, or null where they can't be read (headless, or no texture).
static func _pixels(tex: Texture2D) -> Image:
	var src: Image = tex.get_image() if tex and DisplayServer.get_name() != "headless" else null
	return null if src == null or src.is_empty() else src

## Cuts `at` out of the art, sized to `px`, greyed if asked, corners rounded. Touches only the images given,
## so it runs on a worker thread too.
static func _cut_pixels(src: Image, at: Rect2i, px: Vector2i, greyed: bool) -> Image:
	src.convert(Image.FORMAT_RGBA8)
	var img := src.get_region(at)
	img.resize(maxi(1, px.x), maxi(1, px.y), Image.INTERPOLATE_LANCZOS)
	if greyed:
		_grey_pixels(img)
	_round_corners(img, corner(Vector2(px)))
	return img

## The part of the art (in its pixels, `src` its size) a frame of size `px` shows: the frame's shape,
## as big as fits, with the framing point at FACE_AT; a small frame crops in on the face.
static func region(ak: String, path: String, src: Vector2, px: Vector2) -> Rect2:
	var is_splash := path.ends_with("_splash.jpg")
	var focus := _focus(ak, is_splash) * src
	var aspect := px.x / maxf(1.0, px.y)
	var zoom := SMALL_ZOOM if minf(px.x, px.y) < SMALL_PX and not is_splash else 1.0
	var h := src.y * zoom
	var w := h * aspect
	if w > src.x:
		w = src.x
		h = w / aspect
	var x0 := clampf(focus.x - w * FACE_AT.x, 0.0, src.x - w)
	var y0 := clampf(focus.y - h * FACE_AT.y, 0.0, src.y - h)
	return Rect2(x0, y0, w, h)

static func _focus(ak: String, is_splash: bool) -> Vector2:
	if _rules.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules = parsed if typeof(parsed) == TYPE_DICTIONARY else {"face": {}, "splash": {}}
	var at: Array = (_rules["splash" if is_splash else "face"] as Dictionary).get(ak, [0.5, 0.4])
	return Vector2(float(at[0]), float(at[1]))

## The art cut to the frame where its pixels can be read, else its region straight from the texture.
static func _draw_art(c: CanvasItem, r: Rect2, ak: String, path: String, greyed: bool) -> void:
	var tex := cut(ak, path, Vector2i(r.size.round()), greyed)
	if tex:
		c.draw_texture_rect(tex, r, false)
		return
	var full := _texture(path)
	var tint := Color(0.55, 0.55, 0.6) if greyed else Color.WHITE
	c.draw_texture_rect_region(full, r, region(ak, path, full.get_size(), r.size), tint)

static func _draw_state(c: CanvasItem, r: Rect2, rad: int, state: String, hurt: float, low: float, time: float) -> void:
	var pulse := 0.5 + 0.5 * sin(time * 8.0)
	if state == "down":
		low = 0.6 + 0.4 * pulse
	if hurt > 0.02:
		var a := snappedf(clampf(hurt, 0.0, 1.0), 0.125)
		var tint := Color(Palette.col(Palette.HURT), 0.4 * a)
		c.draw_style_box(HudStyle.box(tint, rad, Color(1, 0.92, 0.85, 0.8 * a), 2), r)
	if low > 0.02:
		var a := snappedf(clampf(low * (0.55 + 0.45 * pulse), 0.0, 1.0), 0.125)
		c.draw_style_box(HudStyle.box(Color(0.6, 0.02, 0.0, 0.12 * a), rad, Color(Palette.col(Palette.FOE), a), 3), r)
	if state == "dead":
		var k := r.size.x * 0.22
		var cross := [[r.position + Vector2(k, k), r.end - Vector2(k, k)],
			[Vector2(r.end.x - k, r.position.y + k), Vector2(r.position.x + k, r.end.y - k)]]
		for pair in cross:
			c.draw_line(pair[0], pair[1], Color(0, 0, 0, 0.7), 9.0, true)
			c.draw_line(pair[0], pair[1], Palette.col(Palette.FOE), 5.0, true)
	elif state == "out":
		c.draw_style_box(HudStyle.box(Color(0.05, 0.15, 0.12, 0.5), rad, Color(0, 0, 0, 0), 0), r)
		var tick := PackedVector2Array([r.position + r.size * Vector2(0.25, 0.52),
			r.position + r.size * Vector2(0.43, 0.7), r.position + r.size * Vector2(0.76, 0.3)])
		c.draw_polyline(tick, Palette.col(Palette.GOOD), 5.0, true)

static func _grey_pixels(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := (c.r * 0.3 + c.g * 0.55 + c.b * 0.15) * 0.62
			img.set_pixel(x, y, Color(l, l, l * 1.05, c.a))

static func _round_corners(img: Image, rad: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in rad:
		for x in rad:
			var a := clampf(float(rad) - Vector2(rad - x - 0.5, rad - y - 0.5).length() + 0.5, 0.0, 1.0)
			if a >= 1.0:
				continue
			for p in [Vector2i(x, y), Vector2i(w - 1 - x, y), Vector2i(x, h - 1 - y), Vector2i(w - 1 - x, h - 1 - y)]:
				var c := img.get_pixelv(p)
				c.a *= a
				img.set_pixelv(p, c)

# ------------------------------------------------------------------------------------------ fallback
## A rendered portrait of this look, for a Warden with no painted art: a viewport to add to the tree;
## its texture fills in next frame. `body`: the whole hunter with its weapon, standing (the reveal),
## instead of head and shoulders; `px`: the viewport's size.
static func make(cls: String, team_col: Color, wid: String, look: Dictionary, arch := "", body := false,
		px := SIZE) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a93b8")
	e.ambient_light_energy = 0.9
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-28, 155, 0)
	key.light_color = Color("fff1dc")
	key.light_energy = 1.15
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, -25, 0)
	rim.light_color = team_col.lerp(Color.WHITE, 0.4)
	rim.light_energy = 0.6
	vp.add_child(rim)
	var mdl := Models.hunter(cls, team_col, wid, "", look, arch)
	var ring := mdl.get_node_or_null("TeamRing")
	if ring:
		(ring as Node3D).visible = false
	vp.add_child(mdl)
	# no weapon in the way of the face
	var gun := mdl.get_node_or_null("Rig/Torso/Aim/Gun")
	if gun and not body:
		(gun as Node3D).visible = false
	# the face looks down -Z; frame the head from a little off to one side
	var s := mdl.scale.y
	var head := head_at(mdl)
	var cam := Camera3D.new()
	cam.fov = 26.0
	vp.add_child(cam)
	if body:
		var eye := Vector3(-1.5, 1.5, -4.6) * s
		cam.transform = Transform3D(Basis(), eye).looking_at(Vector3(0, 0.95 * s, 0), Vector3.UP)
	else:
		var eye := head + Vector3(-0.45, 0.1, -1.55) * s
		cam.transform = Transform3D(Basis(), eye).looking_at(head + Vector3(0, -0.13 * s, 0), Vector3.UP)
	cam.current = true
	return vp

## The middle of the hunter's head, from the model's feet (scaled with it): each Warden carries its head
## at its own height.
static func head_at(mdl: Node3D) -> Vector3:
	var pv := mdl.get_node("Rig/Torso/HeadPivot") as Node3D
	var torso := pv.get_parent() as Node3D
	var rig := torso.get_parent() as Node3D
	return mdl.transform.basis * (rig.transform * torso.transform * pv.transform * HEAD_MID)

## A desaturated, darkened copy of a rendered portrait (null until the portrait has been drawn).
static func grey(tex: Texture2D) -> ImageTexture:
	if tex == null or DisplayServer.get_name() == "headless":
		return null       # (headless checks: the dummy renderer has no pixels and errors "Parameter t is null")
	var img := tex.get_image()
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGBA8)
	if not img.get_used_rect().has_area():
		return null
	_grey_pixels(img)
	return ImageTexture.create_from_image(img)

## A painted portrait as a menu control (the Hunter pick, the Hunters screen, the kit card): the
## archetype's face in a frame of its colour. Carries the art it shows as meta "portrait_art".
class Pic extends Control:
	var arch := ""
	var edge := Color.WHITE
	var splash := false

	func _init(ak: String, px: Vector2, edge_col: Color, use_splash := false) -> void:
		arch = ak
		edge = edge_col
		splash = use_splash
		custom_minimum_size = px
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_meta("portrait_art", Portraits.art_path(ak, use_splash))

	## Until its cut is ready (Portraits.cut_soon) only the frame shows.
	func _process(_dt: float) -> void:
		if size.x < 1.0:
			return
		var path := Portraits.art_path(arch, splash)
		var cut_ready := Portraits.cut_soon(arch, path, Vector2i(size.round())) != null
		if cut_ready or (DisplayServer.get_name() == "headless" and Portraits.read_soon(path) != null):
			set_process(false)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if is_processing():
			var box := HudStyle.box(HudStyle.SHADE_EDGE, Portraits.corner(r.size) + 2, Color(edge, 0.9), 2)
			draw_style_box(box, r.grow(2.0))
			return
		Portraits.draw(self, r, arch, null, edge, "", 0.0, 0.0, 0.0, splash)
