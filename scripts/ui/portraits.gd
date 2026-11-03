class_name Portraits
extends RefCounted
## Head-and-shoulders portraits of hunters, wherever a hunter's face is shown: the HUD's vitals block,
## squad frames, the ally popups, the hero picker and the kit card. One pipeline for any model:
## the camera is framed on the model's own head (its "Head" part, else its HeadPivot), so a tiny or a
## towering hunter is framed the same; a long lens at a 3/4 turn, the face looking off to screen right;
## key, fill and a rim in the hunter's colour; then the render (MSAA, twice the size it's kept at) is
## laid over a soft vignette in the hunter's palette and kept as an image. Nothing re-renders per frame:
## each place draws a copy cut to its own size with rounded corners (and a greyed copy for the fallen).
## An archetype can nudge its framing with "portrait": {"zoom", "lift", "yaw"} (content/archetypes).
## Headless there is no renderer: frames draw the backdrop colour only.

const RENDER := 320           # px: the square 3D render
const BAKED := 160            # px: the kept image (the render downsampled 2x)
const BACK := 48              # px: the backdrop is shaded this small, then smoothly upscaled
const FOV := 16.0             # degrees: a long lens, so the face isn't bulged by perspective
const YAW := 30.0             # degrees: the 3/4 turn
const PITCH := 6.0            # degrees: the camera a touch above the eyes
const HEAD_SHARE := 0.46      # the head's height as a share of the frame: head and shoulders
const FACE_Y := 0.43          # where the face's centre sits, from the top of the frame
const FACE_X := 0.45          # ... and from the left (room on the side it looks toward)
## Where the face's centre must land, and how tall the head may be (the --portrait-check bounds).
const FACE_BOUNDS := Rect2(0.3, 0.3, 0.3, 0.24)
const HEAD_RANGE := Vector2(0.32, 0.62)

static var _images := {}      # look key -> Image (BAKED square)
static var _stats := {}       # look key -> {"face": Vector2, "head": float, "cover": float}
static var _sized := {}       # look key -> {Vector3i(w, h, greyed): ImageTexture}
static var _pending := {}     # look key -> true while its render is in flight
static var _holder: Node = null   # the renders in flight live under this node at the root

## Whether portraits can render here (there is no renderer headless).
static func available() -> bool:
	return DisplayServer.get_name() != "headless"

## A portrait's look: what to build and the key it's kept under. `tint` is the hunter's own colour.
static func spec(cls: String, wid: String, look: Dictionary, arch: String, team_col: Color) -> Dictionary:
	var ak := HeroKit.arch_for(cls, arch, look)
	var tint := Arch.color(ak) if Arch.exists(ak) else team_col
	var key := "%s|%s|%s|%s|%d" % [ak, cls, wid, team_col.to_html(), hash(look)]
	return {"cls": cls, "wid": wid, "look": look, "arch": ak, "team": team_col, "tint": tint, "key": key}

## A hunter's portrait look, kept on the hunter until its archetype, class or weapon changes.
static func spec_of(h: Hunter) -> Dictionary:
	var s: Dictionary = h.get_meta("portrait_spec", {})
	if not s.is_empty() and s["arch"] == h.arch and s["cls"] == h.cls and s["wid"] == h.wid:
		return s
	var look: Dictionary = Save.d.get("look", {}) if h.ctrl == "local" else h.bot_look
	s = spec(h.cls, h.wid, look, h.arch, Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()])
	h.set_meta("portrait_spec", s)
	return s

## An archetype as you'd play it (your look, its signature weapon): the hero picker and kit card.
static func spec_for(ak: String) -> Dictionary:
	return spec(Arch.weight(ak), Arch.signature(ak), Save.d.get("look", {}), ak, Data.TEAM_COLORS[0])

static func is_baked(s: Dictionary) -> bool:
	return _images.has(s["key"])

## Where the face landed and how big the head is (fractions of the frame), how much of the frame
## the hunter covers and whether the face's spot is drawn on (alpha): empty until baked.
## Read by --portrait-check.
static func stats_of(s: Dictionary) -> Dictionary:
	return _stats.get(s["key"], {})

## The portrait cut to `px` with rounded corners (greyed for the fallen), or null while it renders.
## The first ask starts the render; it's ready a frame or two later and kept for good.
static func texture(s: Dictionary, tree: SceneTree, px: Vector2i, greyed := false) -> Texture2D:
	var key: String = s["key"]
	var img: Image = _images.get(key)
	if img == null:
		if available() and tree != null and not _pending.has(key):
			_pending[key] = true
			_bake(s, tree)
		return null
	var per: Dictionary = _sized.get(key, {})
	var sk := Vector3i(px.x, px.y, int(greyed))
	if not per.has(sk):
		per[sk] = ImageTexture.create_from_image(_cut(img, px, _stats[key]["face"], greyed))
		_sized[key] = per
	return per[sk]

## Corner radius of a portrait drawn at this size.
static func corner(sz: Vector2) -> int:
	return int(clampf(minf(sz.x, sz.y) * 0.11, 4.0, 12.0))

## A framed portrait. `edge`: the frame's colour. `state`: "" alive, "down" (red pulse, drained),
## "dead" (grey + X), "out" (check). `hurt` 0..1 flashes red on a hit; `low` 0..1 (health running
## out) bleeds the colour and pulses a red inner edge, the same rule as the health bar.
static func draw(c: CanvasItem, r: Rect2, s: Dictionary, edge: Color, state := "", hurt := 0.0, low := 0.0,
		time := 0.0) -> void:
	var rad := corner(r.size)
	c.draw_style_box(HudStyle.box(HudStyle.SHADE_EDGE, rad + 2, Color(edge, 0.9), 2), r.grow(2.0))
	var px := Vector2i(r.size.round())
	var tex := texture(s, c.get_tree(), px, state == "dead")
	if tex == null:
		c.draw_style_box(HudStyle.box(Color.from_hsv(s["tint"].h, 0.45, 0.25), rad, Color(0, 0, 0, 0), 0), r)
		return
	c.draw_texture_rect(tex, r, false)
	var drain := 0.85 if state == "down" else low * 0.5
	if drain > 0.0:
		c.draw_texture_rect(texture(s, c.get_tree(), px, true), r, false, Color(1, 1, 1, drain))
	c.draw_line(r.position + Vector2(rad, 1), Vector2(r.end.x - rad, r.position.y + 1), Color(1, 1, 1, 0.16), 1.0)
	_draw_state(c, r, rad, state, hurt, low, time)

static func _draw_state(c: CanvasItem, r: Rect2, rad: int, state: String, hurt: float, low: float, time: float) -> void:
	var pulse := 0.5 + 0.5 * sin(time * 8.0)
	if state == "down":
		low = 0.6 + 0.4 * pulse
	if hurt > 0.02:
		var a := snappedf(clampf(hurt, 0.0, 1.0), 0.125)
		c.draw_style_box(HudStyle.box(Color(HudStyle.HURT, 0.4 * a), rad, Color(1, 0.92, 0.85, 0.8 * a), 2), r)
	if low > 0.02:
		var a := snappedf(clampf(low * (0.55 + 0.45 * pulse), 0.0, 1.0), 0.125)
		c.draw_style_box(HudStyle.box(Color(0.6, 0.02, 0.0, 0.12 * a), rad, Color(HudStyle.FOE, a), 3), r)
	if state == "dead":
		var k := r.size.x * 0.22
		var cross := [[r.position + Vector2(k, k), r.end - Vector2(k, k)],
			[Vector2(r.end.x - k, r.position.y + k), Vector2(r.position.x + k, r.end.y - k)]]
		for pair in cross:
			c.draw_line(pair[0], pair[1], Color(0, 0, 0, 0.7), 9.0, true)
			c.draw_line(pair[0], pair[1], HudStyle.FOE, 5.0, true)
	elif state == "out":
		c.draw_style_box(HudStyle.box(Color(0.05, 0.15, 0.12, 0.5), rad, Color(0, 0, 0, 0), 0), r)
		var tick := PackedVector2Array([r.position + r.size * Vector2(0.25, 0.52),
			r.position + r.size * Vector2(0.43, 0.7), r.position + r.size * Vector2(0.76, 0.3)])
		c.draw_polyline(tick, HudStyle.REVIVE, 5.0, true)

# ------------------------------------------------------------------------------------------ render

## Builds the stage, waits for its one render, then keeps the image over the backdrop.
static func _bake(s: Dictionary, tree: SceneTree) -> void:
	var vp := _stage(s)
	if not is_instance_valid(_holder):
		_holder = Node.new()
		_holder.name = "HunterPortraits"
		tree.root.add_child.call_deferred(_holder)     # (the root may be busy setting up its children)
	_holder.add_child(vp)
	var img: Image = null
	for i in 4:
		await RenderingServer.frame_post_draw
		if not is_instance_valid(vp):
			_pending.erase(s["key"])
			return
		img = vp.get_texture().get_image()
		if img != null and not img.is_empty():
			break
	var cam := vp.get_camera_3d()
	var face: Vector3 = vp.get_meta("face")
	var top: Vector3 = vp.get_meta("head_top")
	var face_uv := cam.unproject_position(face) / float(RENDER)
	var head := (cam.unproject_position(face) - cam.unproject_position(top)).length() * 2.0 / float(RENDER)
	vp.queue_free()
	_pending.erase(s["key"])
	if img == null or img.is_empty():
		return
	img.convert(Image.FORMAT_RGBA8)
	var cover := _coverage(img)
	var solid := img.get_pixelv(Vector2i((face_uv * RENDER).clamp(Vector2.ZERO, Vector2.ONE * (RENDER - 1)))).a
	var out := _backdrop(s["tint"], face_uv)
	out.blend_rect(img, Rect2i(0, 0, RENDER, RENDER), Vector2i.ZERO)
	out.resize(BAKED, BAKED, Image.INTERPOLATE_LANCZOS)
	_stats[s["key"]] = {"face": face_uv, "head": head, "cover": cover, "solid": solid}
	_images[s["key"]] = out

## The viewport: the model with its weapon and ring hidden, the lights, the camera on its face.
static func _stage(s: Dictionary) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(RENDER, RENDER)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var mdl := Models.hunter(s["cls"], s["team"], s["wid"], "", s["look"], s["arch"])
	for path in ["TeamRing", "Rig/Torso/Aim/Gun"]:
		var n := mdl.get_node_or_null(path) as Node3D
		if n:
			n.visible = false
	for mat in mdl.get_meta("mats", []):
		(mat as ShaderMaterial).set_shader_parameter("no_fog", true)     # (the match's sight fog greys it otherwise)
	vp.add_child(mdl)
	var head := _head_box(mdl)
	var cam := _camera(head, Arch.def(s["arch"]).get("portrait", {}) if Arch.exists(s["arch"]) else {})
	vp.add_child(cam)
	cam.current = true
	_light(vp, cam.transform.basis, s["tint"])
	vp.set_meta("face", head.get_center())
	vp.set_meta("head_top", head.get_center() + Vector3(0, head.size.y * 0.5, 0))
	return vp

## The head's box in the model's space (its scale included): the "Head" part if the model has one,
## else everything on the HeadPivot, else the top of the whole model.
static func _head_box(mdl: Node3D) -> AABB:
	var head := mdl.find_child("Head", true, false) as MeshInstance3D
	if head:
		return _to_model(head, mdl) * head.get_aabb()
	var box := AABB()
	var pivot := mdl.find_child("HeadPivot", true, false)
	for n in (pivot.find_children("*", "MeshInstance3D", true, false) if pivot else []):
		var mi := n as MeshInstance3D
		var b := _to_model(mi, mdl) * mi.get_aabb()
		box = b if box.size == Vector3.ZERO else box.merge(b)
	if box.size == Vector3.ZERO:
		var s := mdl.scale.y
		box = AABB(Vector3(-0.15, 1.1, -0.15) * s, Vector3(0.3, 0.3, 0.3) * s)
	return box

static func _to_model(n: Node3D, mdl: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent() as Node3D
	while p != null:
		xf = p.transform * xf
		if p == mdl:
			break
		p = p.get_parent() as Node3D
	return xf

## A long lens on the face from a 3/4 turn, a little above, sized so the head fills HEAD_SHARE.
static func _camera(head: AABB, tweak: Dictionary) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = FOV
	var frame_h := head.size.y / (HEAD_SHARE * float(tweak.get("zoom", 1.0)))
	var yaw := deg_to_rad(float(tweak.get("yaw", YAW)))
	var pitch := deg_to_rad(PITCH)
	var toward := Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
	var right := (-toward).cross(Vector3.UP).normalized()
	var face := head.get_center()
	var eye_y := FACE_Y - float(tweak.get("lift", 0.0))
	var aim := face - Vector3.UP * (0.5 - eye_y) * frame_h + right * (0.5 - FACE_X) * frame_h
	var dist := frame_h * 0.5 / tan(deg_to_rad(FOV) * 0.5)
	cam.transform = Transform3D(Basis(), aim + toward * dist).looking_at(aim, Vector3.UP)
	return cam

## Key, fill and rim, set from the camera: a warm key high on the side the face turns to, a cool
## soft fill from the other side, a rim from behind in the hunter's colour; a soft ambient so no
## face falls into black.
static func _light(vp: SubViewport, cam: Basis, tint: Color) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9aa3c4").lerp(tint, 0.25)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var back := cam.z
	var lights := [
		[cam.x * 0.6 + Vector3.UP * 0.7 + back * 0.8, Color("fff0da"), 1.2],
		[-cam.x * 0.9 + Vector3.UP * 0.15 + back * 0.6, Color("c4d2ff"), 0.45],
		[-back * 0.9 + Vector3.UP * 0.4 - cam.x * 0.35, tint.lerp(Color.WHITE, 0.25), 2.2],
	]
	for l in lights:
		var dl := DirectionalLight3D.new()
		var from: Vector3 = (l[0] as Vector3).normalized()
		var up := Vector3.UP if absf(from.y) < 0.95 else Vector3.FORWARD
		dl.transform = Transform3D(Basis.looking_at(-from, up), Vector3.ZERO)
		dl.light_color = l[1]
		dl.light_energy = l[2]
		vp.add_child(dl)

# ------------------------------------------------------------------------------------------ images

## The backdrop: a glow in the hunter's colour behind the head falling off to a deep shade of it,
## darker toward the bottom and the corners.
static func _backdrop(tint: Color, face: Vector2) -> Image:
	var img := Image.create(BACK, BACK, false, Image.FORMAT_RGBA8)
	var deep := Color.from_hsv(tint.h, clampf(tint.s * 0.75, 0.15, 0.6), 0.11)
	var glow := Color.from_hsv(tint.h, clampf(tint.s * 0.55, 0.12, 0.5), 0.48)
	var centre := face + Vector2(0.08, -0.04)
	for y in BACK:
		for x in BACK:
			var uv := Vector2(x + 0.5, y + 0.5) / float(BACK)
			var col := glow.lerp(deep, smoothstep(0.0, 0.8, uv.distance_to(centre)))
			col = col.darkened(0.3 * smoothstep(0.55, 1.0, uv.y))
			col = col.darkened(0.5 * clampf((uv - Vector2(0.5, 0.5)).length_squared() * 2.4 - 0.25, 0.0, 1.0))
			img.set_pixel(x, y, col)
	img.resize(RENDER, RENDER, Image.INTERPOLATE_CUBIC)
	return img

## The share of the render the hunter covers (sampled every 4th pixel).
static func _coverage(img: Image) -> float:
	var hit := 0
	var all := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			all += 1
			if img.get_pixel(x, y).a > 0.5:
				hit += 1
	return float(hit) / float(maxi(1, all))

## The kept image cut to `px`'s shape around the face, scaled to it, corners rounded; greyed if asked.
static func _cut(src: Image, px: Vector2i, face: Vector2, greyed: bool) -> Image:
	var aspect := float(px.x) / float(maxi(1, px.y))
	var w := float(BAKED) * minf(1.0, aspect)
	var h := float(BAKED) * minf(1.0, 1.0 / aspect)
	var x0 := clampf(face.x * BAKED - w * FACE_X, 0.0, BAKED - w)
	var y0 := clampf(face.y * BAKED - h * FACE_Y, 0.0, BAKED - h)
	var img := src.get_region(Rect2i(int(x0), int(y0), int(w), int(h)))
	img.resize(maxi(1, px.x), maxi(1, px.y), Image.INTERPOLATE_LANCZOS)
	if greyed:
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				var l := (c.r * 0.3 + c.g * 0.55 + c.b * 0.15) * 0.62
				img.set_pixel(x, y, Color(l, l, l * 1.05, c.a))
	_round_corners(img, corner(Vector2(px)))
	return img

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

## A portrait as a menu control (hero picker, kit card): redraws once its render is in.
class Pic extends Control:
	var look: Dictionary
	var edge: Color

	func _init(s: Dictionary, px: Vector2, edge_col: Color) -> void:
		look = s
		edge = edge_col
		custom_minimum_size = px
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(Portraits.available())

	func _process(_dt: float) -> void:
		if Portraits.is_baked(look):
			queue_redraw()
			set_process(false)

	func _draw() -> void:
		Portraits.draw(self, Rect2(Vector2.ZERO, size), look, edge)
