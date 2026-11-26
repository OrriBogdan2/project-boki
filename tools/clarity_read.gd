extends RefCounted
## Rival read for --clarity-shots (docs/COMBAT_CLARITY.md "Rivals read at Hunter size"). Per Hunter on a fight frame:
## its body's screen pixels (the bodies drawn alone, as ClarityContrast does), the pixels of its nameplate (the frame
## with the plate layer hidden, inside the plate's recorded box), its ownership ring's screen footprint and band, and
## for a rival how much of its own colour survives the side edge: the share of body pixels within PALETTE_TOL of the
## same body drawn with side_rim off. Numbers only; the pictures are the fight frames.

const SOLO_LAYER := 1 << 19  # render layer 20, as in clarity_shots
const PLATE_DIFF := 0.1  # most-changed channel above which a pixel belongs to the plate
const PALETTE_TOL := 0.12  # RGB distance (0-1) under which a body pixel counts as keeping its own colour
const DIFF := 0.02  # most-changed channel above which a pixel of `solo` is a body's (bodies sit on near-black)


## One row per shown Hunter: {rival, body, plate, ring_w, ring_h, ring_band, body_w, kept}. `kept` is -1 for a
## Hunter that is not a rival. Draws the frame four ways (as played, no plates, bodies alone with and without the edge);
## with `pics` (a path prefix) the bodies-alone pictures are saved as <pics>_on.png and <pics>_off.png.
static func frame(fm: Match, pics := "") -> Array:
	var rows: Array = []
	var vp := fm.get_viewport()
	var k := Vector2(vp.size) / vp.get_visible_rect().size  # canvas units -> picture pixels
	var zones := {}  # Hunter -> its box in image pixels
	for h: Hunter in fm.hunters:
		var z := HunterZone.rect_of(fm, h)
		if z.has_area():
			zones[h] = Rect2i(Rect2(z.position * k, z.size * k))
	if zones.is_empty():
		return rows
	await RenderingServer.frame_post_draw
	var played := fm.get_viewport().get_texture().get_image()
	var layer: Node2D = fm.hud.plates._layer
	layer.visible = false
	await RenderingServer.frame_post_draw
	var bare := fm.get_viewport().get_texture().get_image()
	layer.visible = true
	var cam := fm.get_viewport().get_camera_3d()
	var mask := cam.cull_mask
	var bodies := {}  # MeshInstance3D -> layers
	for h: Hunter in zones:
		for mi: MeshInstance3D in h.find_children("*", "MeshInstance3D", true, false):
			if (
				not mi.name.ends_with("_ink")
				and mi.name != "TeamRing"
				and mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			):
				bodies[mi] = mi.layers
				mi.layers = SOLO_LAYER
	cam.cull_mask = SOLO_LAYER
	await RenderingServer.frame_post_draw
	var solo_on := fm.get_viewport().get_texture().get_image()
	var edges := {}  # Hunter -> its side_rim
	for h: Hunter in zones:
		edges[h] = SideRings.edge_of(h)
		for mt in h.mats:
			mt.set_shader_parameter("side_rim", Color(0, 0, 0, 0))
	await RenderingServer.frame_post_draw
	var solo_off := fm.get_viewport().get_texture().get_image()
	for h: Hunter in zones:
		for mt in h.mats:
			mt.set_shader_parameter("side_rim", edges[h])
	cam.cull_mask = 0
	await RenderingServer.frame_post_draw
	var empty := fm.get_viewport().get_texture().get_image()
	cam.cull_mask = mask
	for mi: MeshInstance3D in bodies:
		mi.layers = bodies[mi]
	if pics != "":
		solo_on.save_png(pics + "_on.png")
		solo_off.save_png(pics + "_off.png")
	var plates: Array = []
	for p: Rect2 in SafeArea.seen.get("plate", []):
		plates.append(Rect2(p.position * k, p.size * k))
	for h: Hunter in zones:
		var r: Rect2i = zones[h]
		var rival: bool = h.team != fm.player.team
		var body := _body(solo_on, solo_off, empty, r, rival)
		(
			rows
			. append(
				{
					"rival": rival,
					"box": r,
					"body": body[0],
					"kept": body[1],
					"body_w": body[2],
					"plate": _plate(played, bare, plates, r),
					"ring": _ring(cam, h, k),
				}
			)
		)
	return rows


## The mean of each number over the rows (rivals only for `kept`), as one printable line.
static func summary(rows: Array) -> String:
	var n := 0.0
	var s := {"body": 0.0, "plate": 0.0, "ring_band": 0.0, "ring_w": 0.0, "body_w": 0.0}
	var kept := 0.0
	var rivals := 0.0
	for r: Dictionary in rows:
		n += 1.0
		s["body"] += r["body"]
		s["plate"] += r["plate"]
		s["body_w"] += r["body_w"]
		s["ring_band"] += r["ring"].z
		s["ring_w"] += r["ring"].x
		if r["rival"] and r["kept"] >= 0.0:
			rivals += 1.0
			kept += r["kept"]
	if n == 0.0:
		return "no Hunters"
	return (
		(
			"body %.0f px, plate %.0f px (x%.1f), ring band %.0f px, ring %.0f px wide vs body %.0f px wide (x%.1f),"
			% [
				s["body"] / n,
				s["plate"] / n,
				s["plate"] / maxf(s["body"], 1.0),
				s["ring_band"] / n,
				s["ring_w"] / n,
				s["body_w"] / n,
				s["ring_w"] / maxf(s["body_w"], 1.0)
			]
		)
		+ " rival colours kept %.1f%% (%d rivals)" % [100.0 * kept / maxf(rivals, 1.0), int(rivals)]
	)


## [body pixels, share kept (-1 for a non-rival), body width] inside `r`.
static func _body(on: Image, off: Image, empty: Image, r: Rect2i, rival: bool) -> Array:
	var box := r.intersection(Rect2i(Vector2i.ZERO, on.get_size()))
	var n := 0
	var kept := 0
	var x0 := 1 << 20
	var x1 := -1
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var c := on.get_pixel(x, y)
			if _gap(c, empty.get_pixel(x, y)) <= DIFF:
				continue
			n += 1
			x0 = mini(x0, x)
			x1 = maxi(x1, x)
			if rival and _gap(c, off.get_pixel(x, y)) <= PALETTE_TOL:
				kept += 1
	return [n, float(kept) / n if rival and n > 0 else -1.0, maxi(x1 - x0 + 1, 0)]


## Pixels of the plate layer inside the plate boxes that touch `r`'s column (the plate hangs over the head).
static func _plate(played: Image, bare: Image, plates: Array, r: Rect2i) -> int:
	var n := 0
	for p: Rect2 in plates:
		if absf(p.get_center().x - (r.position.x + r.size.x * 0.5)) > r.size.x * 0.5 or p.get_center().y > r.end.y:
			continue
		var box := Rect2i(p).intersection(Rect2i(Vector2i.ZERO, played.get_size()))
		for y in range(box.position.y, box.end.y):
			for x in range(box.position.x, box.end.x):
				if _gap(played.get_pixel(x, y), bare.get_pixel(x, y)) > PLATE_DIFF:
					n += 1
	return n


## The ownership ring on screen: Vector3(width, height of its footprint, band pixels).
static func _ring(cam: Camera3D, h: Hunter, k: Vector2) -> Vector3:
	var ring := h.model.get_node_or_null("TeamRing") as MeshInstance3D
	if ring == null or not ring.is_visible_in_tree():
		return Vector3.ZERO
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for c in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]:
		var p := cam.unproject_position(ring.global_transform * (c * 0.5 * (ring.mesh as PlaneMesh).size.x)) * k
		lo = lo.min(p)
		hi = hi.max(p)
	var size := hi - lo
	var t: float = (ring.material_override as ShaderMaterial).get_shader_parameter("thickness")
	return Vector3(size.x, size.y, PI * 0.25 * size.x * size.y * (1.0 - pow(1.0 - t, 2.0)))


static func _gap(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))
