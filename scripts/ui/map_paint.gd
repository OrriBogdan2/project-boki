class_name MapPaint
extends SubViewport
## The painted map: baked once per map, on the GPU, from the world's tiles (shaders/map_paint.gdshader)
## into one mipmapped texture that the full map (M) and the minimap draw. Nothing re-renders the
## world for the map, and the overlays (pings, squad, spawns, exits) stay crisp vector drawing on top.
## The same map in a later match reuses the texture. Headless runs never get one (no GPU): the HUD
## keeps its plain tile texture then.

signal baked(tex: Texture2D)

static var _cache := {}          # data hash -> ImageTexture
const SHADER := preload("res://shaders/map_paint.gdshader")

var _frames := 0
var _key := 0
var result: Texture2D = null

## Starts a bake (or hands back the cached texture right away). cb(tex) runs once it's ready.
static func request(parent: Node, w: World, cb: Callable) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var data := _data(w)
	var key := hash([data[0].get_data(), data[1].get_data(), data[2].get_data(), w.w, w.h])
	if _cache.has(key):
		cb.call(_cache[key])
		return
	var mp := MapPaint.new()
	mp._key = key
	var px := 1024 if OS.has_feature("web") else 2048
	mp.size = Vector2i(px, px)
	mp.disable_3d = true
	mp.transparent_bg = false
	mp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cr := ColorRect.new()
	cr.size = Vector2(px, px)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("col_tex", ImageTexture.create_from_image(data[0]))
	mat.set_shader_parameter("info_tex", ImageTexture.create_from_image(data[1]))
	mat.set_shader_parameter("rim_tex", ImageTexture.create_from_image(data[2]))
	mat.set_shader_parameter("tiles", Vector2(w.w, w.h))
	if w.clouds.size() == 2:
		mat.set_shader_parameter("sea_deep", (w.clouds[0] as Color).darkened(0.35))
		mat.set_shader_parameter("sea_light", (w.clouds[1] as Color).lerp(Color("2a3266"), 0.35))
	cr.material = mat
	mp.add_child(cr)
	mp.baked.connect(cb)
	parent.add_child(mp)

func _process(_d: float) -> void:
	_frames += 1
	if _frames < 3:
		return
	set_process(false)
	var img := get_texture().get_image()
	if img and not img.is_empty():
		img.convert(Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		result = ImageTexture.create_from_image(img)
		_cache[_key] = result
		PerfLog.mark("map.bake")
		baked.emit(result)
	queue_free()

## Per tile: [colour + land, height/path/trees/walls, sheer/lip/tall grass/bridge].
static func _data(w: World) -> Array:
	var n := w.w * w.h
	var a := PackedByteArray(); a.resize(n * 4)
	var b := PackedByteArray(); b.resize(n * 4)
	var c := PackedByteArray(); c.resize(n * 4)
	var lip_paint := Color("dccb9c"); var sheer_paint := Color("7d7896")
	var top_lv := 1
	for i in n:
		if w.kind[i] != World.T_VOID: top_lv = maxi(top_lv, w.level[i])
	var tops: Array = []      # per island: its ground colour (the per-tile biome lookup is slow)
	for ii in w.islands.size(): tops.append(Color(w._bio_of_island(ii)["top"]))
	var top0 := Color(w.biome["top"])
	for i in n:
		var k := w.kind[i]
		if k == World.T_VOID:
			continue
		var isl: int = w.island[i]
		var col: Color = (tops[isl] if isl >= 0 and isl < tops.size() else top0).lightened(0.06 + 0.035 * mini(w.level[i], 6))
		if w.level[i] >= 8: col = col.lightened(0.18)       # a high perch: brighter
		var o := i * 4
		a[o] = int(col.r8); a[o + 1] = int(col.g8); a[o + 2] = int(col.b8); a[o + 3] = 255
		b[o] = int(clampf(float(w.level[i]) / float(top_lv), 0.0, 1.0) * 255.0)
		if w.paint.has(i) and w.paint[i] != lip_paint and w.paint[i] != sheer_paint:
			b[o + 1] = 255
		if k == World.T_BLOCK:
			if w.walls.has(i): b[o + 3] = 255
			else: b[o + 2] = 255
		if w.sheer.has(i): c[o] = 255
		elif w.lip.has(i): c[o + 1] = 255
		if w.bush.has(i): c[o + 2] = 255
		if w.bridge.has(i): c[o + 3] = 255
	return [Image.create_from_data(w.w, w.h, false, Image.FORMAT_RGBA8, a),
		Image.create_from_data(w.w, w.h, false, Image.FORMAT_RGBA8, b),
		Image.create_from_data(w.w, w.h, false, Image.FORMAT_RGBA8, c)]
