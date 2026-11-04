class_name KitShaders
extends RefCounted
## Our own effect shaders for the Hem and Breaker kits (pooled meshes in PinFx / BjornFx drive them through
## uniforms). Every one is unshaded, casts no shadow and never writes depth, so stacked effects can't
## z-fight the ground. Built once and cached.
##
## Additive light alone turns beige or white on bright grass, so a "layered" material draws the colour
## first as an alpha-blended body (the MIX_PASS variant of the same shader) and the additive glow on top
## of it as its next pass, at a lower strength. KitShaders.param sets a uniform on both passes.

## How strong the additive glow pass is over a layered material's coloured body.
const LAYER_GLOW := 0.45

## The shared ending of every layerable shader: `col` and `a` are set; the body pass shows the colour
## itself (alpha-blended, `body` scales its opacity), the glow pass adds it scaled by `glow`.
const _TAIL := """
#ifdef MIX_PASS
	ALBEDO = col;
	ALPHA = clamp(a * body, 0.0, 1.0) * color.a;
#else
	ALBEDO = col * a * glow;
	ALPHA = clamp(a, 0.0, 1.0) * color.a;
#endif
}
"""
const _LAYER_UNIFORMS := """
uniform float glow = 1.0;
uniform float body = 1.0;
"""

const _BILLBOARD := """
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]
	);
"""

static var _cache := {}

## A material for one effect shader: additive glow only, or with `layered` a coloured alpha-blended body
## with the glow as its next pass.
static func mat(kind: String, col := Color.WHITE, layered := false) -> ShaderMaterial:
	var glow_mat := _one(kind, col, false)
	if not layered:
		return glow_mat
	glow_mat.set_shader_parameter("glow", LAYER_GLOW)
	var body_mat := _one(kind, col, true)
	body_mat.next_pass = glow_mat
	return body_mat

## Sets a shader uniform on a pooled effect's material and on its glow pass, if it has one.
static func param(mi: GeometryInstance3D, uniform_name: StringName, value: Variant) -> void:
	var pass_mat := mi.material_override as ShaderMaterial
	while pass_mat:
		pass_mat.set_shader_parameter(uniform_name, value)
		pass_mat = pass_mat.next_pass as ShaderMaterial

static func _one(kind: String, col: Color, body_pass: bool) -> ShaderMaterial:
	var key := kind + ("|mix" if body_pass else "")
	if not _cache.has(key):
		var code := _code(kind)
		if body_pass:
			code = code.replace("shader_type spatial;", "shader_type spatial;\n#define MIX_PASS")
			code = code.replace("blend_add", "blend_mix")
		var sh := Shader.new()
		sh.code = code
		_cache[key] = sh
	var m := ShaderMaterial.new()
	m.shader = _cache[key]
	m.set_shader_parameter("color", col)
	return m

static func _code(kind: String) -> String:
	match kind:
		# a four-point star with a soft core and an optional ring (impact stars, Breaker's glint and flare); it
		# draws over everything, since an impact star sits inside the body it hit
		"star":
			return """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
// overall strength 0..
uniform float power = 1.0;
// ring strength
uniform float ring = 0.0;
// ring radius (uv units)
uniform float ring_r = 0.62;
// radians (0.785 = an X)
uniform float rot = 0.0;
// ray sharpness
uniform float thin = 28.0;
// how far the core whitens (0 keeps it the star's own colour)
uniform float white = 1.0;
""" + _LAYER_UNIFORMS + """
void vertex() {""" + _BILLBOARD + """}
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float c = cos(rot), s = sin(rot);
	uv = vec2(c * uv.x - s * uv.y, s * uv.x + c * uv.y);
	float r = length(uv);
	float rays = exp(-abs(uv.y) * thin) * max(0.0, 1.0 - abs(uv.x))
		+ exp(-abs(uv.x) * thin) * max(0.0, 1.0 - abs(uv.y));
	float core = exp(-r * 7.0);
	float rg = ring * exp(-pow((r - ring_r) * 18.0, 2.0));
	float a = clamp((rays + core * 1.4 + rg) * power, 0.0, 1.5) * (1.0 - smoothstep(0.85, 1.0, r));
	vec3 col = mix(color.rgb, vec3(1.0), core * 0.6 * white);
""" + _TAIL
		# Hem's fletch burst (her stage and perfect-release flashes, the glint at her bow): leaf-shaped
		# feathers radiating from a small core, each with a bright quill down its middle, an optional ring
		"rosette":
			return """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float power = 1.0;
// how many feathers
uniform float leaves = 6.0;
// radians the burst is turned by
uniform float rot = 0.0;
uniform float ring = 0.0;
uniform float ring_r = 0.86;
""" + _LAYER_UNIFORMS + """
void vertex() {""" + _BILLBOARD + """}
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float seg = 6.28318 / leaves;
	float ang = atan(uv.y, uv.x) + rot;
	float off = abs(mod(ang + seg * 0.5, seg) - seg * 0.5);
	// a feather: widest a third of the way out, pointed at both ends
	float u = clamp((r - 0.12) / 0.8, 0.0, 1.0);
	float half_w = seg * 0.42 * pow(sin(3.14159 * pow(u, 0.7)), 0.8);
	float leaf = (1.0 - smoothstep(half_w * 0.7, half_w, off)) * step(0.12, r) * (1.0 - step(0.92, r));
	float quill = leaf * exp(-off * r * 55.0);
	float core = exp(-r * 10.0);
	float rg = ring * exp(-pow((r - ring_r) * 16.0, 2.0));
	float a = (leaf * 0.85 + quill * 0.5 + core + rg) * power * (1.0 - smoothstep(0.92, 1.0, r));
	vec3 col = mix(color.rgb, vec3(1.0, 0.97, 0.8), quill * 0.3 + core * 0.3);
""" + _TAIL
		# a streak or ribbon: bright along its centre line (uv.y = 0.5), fading to its tail (uv.x = 0)
		"streak":
			return """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float power = 1.0;
// 1 = fades to nothing at uv.x = 0
uniform float tail = 1.0;
""" + _LAYER_UNIFORMS + """
void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float a = pow(across, 1.6) * mix(1.0, UV.x, tail) * power;
	vec3 col = mix(color.rgb, vec3(1.0), pow(across, 6.0) * 0.7);
""" + _TAIL
		# a standing translucent panel: bright rim and base, a rising shimmer (Hem's Rain of Arrows)
		"panel":
			return """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float power = 1.0;
void fragment() {
	float edge = max((1.0 - smoothstep(0.0, 0.08, UV.x)), smoothstep(0.92, 1.0, UV.x));
	float top = (1.0 - smoothstep(0.0, 0.1, UV.y));
	float base = smoothstep(0.75, 1.0, UV.y);
	float sh = 0.5 + 0.5 * sin((UV.y * 9.0 + TIME * 3.0) + UV.x * 2.0);
	float a = (0.16 + 0.12 * sh * (1.0 - UV.y * 0.5) + edge * 0.8 + top * 0.5 + base * 0.7) * power;
	ALBEDO = mix(color.rgb, vec3(1.0), edge * 0.4 + top * 0.3) * a;
	ALPHA = clamp(a, 0.0, 1.0) * color.a;
}
"""
		# a licking flame on a billboard (Hem's anti-heal burn: blue)
		"flame":
			return """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float power = 1.0;
uniform float seed = 0.0;
void vertex() {""" + _BILLBOARD + """}
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME * 5.0 + seed;
	float wob = sin(uv.y * 6.0 + t) * 0.12 + sin(uv.y * 11.0 - t * 1.3) * 0.06;
	float w = mix(0.75, 0.05, clamp((1.0 - uv.y) * 0.5, 0.0, 1.0));
	float body = (1.0 - smoothstep(w * 0.2, w, abs(uv.x + wob * (1.0 - uv.y) * 0.5)));
	float h = smoothstep(-1.0, -0.2, -uv.y * 0.9 + 0.1 * sin(t + uv.x * 5.0));
	float a = body * (1.0 - smoothstep(0.6, 1.0, uv.y)) * smoothstep(-1.0, -0.4, uv.y) * power;
	ALBEDO = mix(color.rgb, vec3(1.0), body * h * 0.35) * a;
	ALPHA = clamp(a, 0.0, 1.0) * color.a;
}
"""
		# a flaming crescent ribbon (Breaker's slam): uv.x along the arc, uv.y from the inner to the outer edge;
		# a white-yellow core, orange then red edges, burning away from its tail as life runs down
		"crescent":
			return """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.55, 0.15, 1.0);
// 1 -> 0
uniform float life = 1.0;
uniform float power = 2.4;
""" + _LAYER_UNIFORMS + """
void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float along = pow(sin(clamp(UV.x, 0.0, 1.0) * 3.14159), 0.5);
	float lick = 0.75 + 0.25 * sin(UV.x * 40.0 + TIME * 30.0 + UV.y * 9.0);
	// it burns away from its tail (uv.x = 0) as life runs out
	float burn = smoothstep(0.0, 0.25, life * 1.3 - (1.0 - UV.x) * 0.3);
	float a = pow(across, 0.8) * along * lick * burn * power;
	vec3 col = mix(vec3(0.85, 0.1, 0.04), color.rgb, clamp((across - 0.1) / 0.4, 0.0, 1.0));
	col = mix(col, vec3(1.0, 0.95, 0.62), clamp((across - 0.62) / 0.3, 0.0, 1.0));
""" + _TAIL
		# a light pillar: brightest on its rim (seen side-on), rising chevron bands (Breaker's beacon, Purify's column)
		"beam":
			return """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float power = 1.0;
uniform float speed = 1.4;
uniform float bands = 6.0;
""" + _LAYER_UNIFORMS + """
varying float rim;
void vertex() {
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	rim = 1.0 - abs(n.z);
}
void fragment() {
	// 0 at the top, 1 at the foot
	float up = UV.y;
	float ch = fract(up * bands + TIME * speed + abs(UV.x - 0.5) * 1.2);
	float chev = smoothstep(0.0, 0.08, ch) * (1.0 - smoothstep(0.12, 0.24, ch));
	float fade = smoothstep(0.0, 0.5, up);
	float a = (0.18 + rim * 0.75 + chev * 0.55) * fade * power;
	vec3 col = mix(color.rgb, vec3(1.0), chev * 0.4 + rim * 0.2);
""" + _TAIL
		# a swirling ring band flat on the ground (Breaker's 360 Smash, Purify's rings): uv.x round, uv.y across
		"swirl":
			return """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 color2 : source_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform float life = 1.0;
uniform float power = 1.0;
uniform float spin = 3.0;
// how far the streaks lean round (a spiral)
uniform float twist = 0.6;
""" + _LAYER_UNIFORMS + """
void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float sw = fract(UV.x * 6.0 - UV.y * twist + TIME * spin);
	float streak = smoothstep(0.0, 0.5, sw) * (1.0 - smoothstep(0.5, 1.0, sw));
	float a = pow(across, 1.1) * (0.35 + 0.65 * streak) * life * power;
	vec3 col = mix(color.rgb, color2.rgb, streak * across);
""" + _TAIL
		# Breaker's aegis: a solid pale-gold slab with horizontal ribs, a bright rim, his hammer sigil glowing on
		# its face, a shimmer sweeping across, the whole slab flashing on a block and cracking as it weakens
		"aegis":
			return """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float power = 1.0;
// 1 on a block, fades
uniform float hit = 0.0;
// 0 whole .. 1 nearly broken
uniform float hurt = 0.0;
// a Shield Slam is armed: it burns hotter
uniform float armed = 0.0;
""" + _LAYER_UNIFORMS + """
void fragment() {
	vec2 uv = UV;
	float rim = max(1.0 - smoothstep(0.0, 0.07, uv.y), smoothstep(0.93, 1.0, uv.y));
	rim = max(rim, max(1.0 - smoothstep(0.0, 0.03, uv.x), smoothstep(0.97, 1.0, uv.x)));
	float ribs = smoothstep(0.8, 1.0, abs(sin(uv.y * 3.14159 * 5.0))) * 0.22;
	vec2 c = vec2((uv.x - 0.5) * 2.6, uv.y - 0.45);
	float head = step(abs(c.x), 0.34) * step(abs(c.y + 0.17), 0.1);
	float haft = step(abs(c.x), 0.07) * step(-0.17, c.y) * step(c.y, 0.32);
	float sigil = max(head, haft);
	float sweep = exp(-pow((uv.x - fract(TIME * 0.45)) * 9.0, 2.0)) * 0.2;
	float crack = hurt * smoothstep(0.93, 1.0, abs(sin(uv.x * 23.0 + sin(uv.y * 17.0) * 2.0)));
	float a = (0.68 + ribs + rim * 0.5 + sigil * 0.45 + sweep + crack * 0.4 + hit * 0.45 + armed * 0.1) * power;
	vec3 col = mix(color.rgb, vec3(0.72, 0.48, 0.1), ribs * 2.5);
	col = mix(col, vec3(1.0, 0.97, 0.82), rim * 0.6 + hit * 0.6 + sweep);
	col = mix(col, vec3(1.0, 0.55, 0.08), sigil * 0.9);
	col = mix(col, vec3(1.0, 0.42, 0.12), armed * 0.3 + crack * 0.6);
""" + _TAIL
		# the screen tint while Spirit Walk carries you through something: a dark blue wash, darker at the edges
		"tint":
			return """shader_type canvas_item;
uniform vec4 color : source_color = vec4(0.04, 0.08, 0.3, 1.0);
uniform float power = 0.0;
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float v = smoothstep(0.3, 1.5, length(uv));
	COLOR = vec4(color.rgb, clamp(power * (0.42 + v * 0.45), 0.0, 0.9));
}
"""
	return ""
