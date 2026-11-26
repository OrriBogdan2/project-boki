class_name GroundBake
extends SubViewport
## The terrain's big painted patterns (patches, sunlit swathes, pools, hue drift and each biome's drifts and
## zones: shaders/ground_big.gdshaderinc), baked once per map on the GPU into three mipmapped RGBA textures
## that the ground reads instead of ~7 fbm a pixel (about 85 sin hashes). They hang on world xz only, so the
## bake is the live noise sampled at 4 texels per metre (3 on the web) and the same map size reuses it.
## Until the bake lands (3 frames) and in headless runs the shader keeps its live noise (use_bake off).
## --ground-live keeps it off (bench and before/after shots).

static var _cache := {}          # Vector2i(w, h) -> [Texture2D x3], the last map size baked
const SHADER := preload("res://shaders/ground_bake.gdshader")

var _frames := 0
var _key := Vector2i.ZERO
var _mat: ShaderMaterial
var _n := 0

## Bakes for (or hands the cached textures right away to) this terrain material.
static func request(parent: Node, mat: ShaderMaterial, map_size: Vector2) -> void:
	if DisplayServer.get_name() == "headless" or "--ground-live" in OS.get_cmdline_user_args():
		return
	var key := Vector2i(map_size)
	if _cache.has(key):
		_apply(mat, _cache[key])
		return
	var per := 3 if OS.has_feature("web") else 4
	var gb := GroundBake.new()
	gb._key = key
	gb._mat = mat
	gb._n = mini(maxi(key.x, key.y) * per, 2048)
	gb.size = Vector2i(gb._n * 3, gb._n)
	gb.disable_3d = true
	gb.transparent_bg = true
	gb.render_target_update_mode = SubViewport.UPDATE_ONCE
	for layer in 3:
		var cr := ColorRect.new()
		cr.position = Vector2(layer * gb._n, 0)
		cr.size = Vector2(gb._n, gb._n)
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("map_size", map_size)
		m.set_shader_parameter("layer", layer)
		cr.material = m
		gb.add_child(cr)
	parent.add_child(gb)

static func _apply(mat: ShaderMaterial, texs: Array) -> void:
	for i in 3:
		mat.set_shader_parameter("bake%d" % i, texs[i])
	mat.set_shader_parameter("use_bake", true)

func _process(_d: float) -> void:
	_frames += 1
	if _frames < 3:
		return
	set_process(false)
	var img := get_texture().get_image()
	if img and not img.is_empty():
		img.convert(Image.FORMAT_RGBA8)
		var texs := []
		for i in 3:
			var part := img.get_region(Rect2i(i * _n, 0, _n, _n))
			part.generate_mipmaps()
			texs.append(ImageTexture.create_from_image(part))
		_cache.clear()
		_cache[_key] = texs
		if is_instance_valid(_mat):
			_apply(_mat, texs)
		PerfLog.mark("ground.bake")
	queue_free()
