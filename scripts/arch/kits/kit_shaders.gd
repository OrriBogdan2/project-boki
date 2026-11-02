class_name KitShaders
extends RefCounted
## Our own effect shaders for the Pin and Bjorn kits (pooled meshes in PinFx / BjornFx drive them through
## uniforms). Every one is unshaded and additive or alpha-blended, casts no shadow and never writes depth,
## so stacked effects can't z-fight the ground. Built once and cached.

static var _cache := {}

static func mat(kind: String, col := Color.WHITE) -> ShaderMaterial:
	if not _cache.has(kind):
		var s := Shader.new()
		s.code = _code(kind)
		_cache[kind] = s
	var m := ShaderMaterial.new()
	m.shader = _cache[kind]
	m.set_shader_parameter("color", col)
	return m

const _BILLBOARD := """
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
"""

static func _code(kind: String) -> String:
	match kind:
		# a four-point star with a soft core and an optional ring (the stage flash, the perfect star, the glint)
		"star":
			return """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float power = 1.0;     // overall strength 0..
uniform float ring = 0.0;      // ring strength
uniform float ring_r = 0.62;   // ring radius (uv units)
uniform float rot = 0.0;       // radians (0.785 = an X)
uniform float thin = 28.0;     // ray sharpness
void vertex() {""" + _BILLBOARD + """}
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float c = cos(rot), s = sin(rot);
	uv = vec2(c * uv.x - s * uv.y, s * uv.x + c * uv.y);
	float r = length(uv);
	float rays = exp(-abs(uv.y) * thin) * max(0.0, 1.0 - abs(uv.x)) + exp(-abs(uv.x) * thin) * max(0.0, 1.0 - abs(uv.y));
	float core = exp(-r * 7.0);
	float rg = ring * exp(-pow((r - ring_r) * 18.0, 2.0));
	float a = clamp((rays + core * 1.4 + rg) * power, 0.0, 1.5) * (1.0 - smoothstep(0.85, 1.0, r));
	ALBEDO = mix(color.rgb, vec3(1.0), core * 0.6) * a;
	ALPHA = clamp(a, 0.0, 1.0) * color.a;
}
"""
		# a streak or ribbon: bright along its centre line (uv.y = 0.5), fading to its tail (uv.x = 0)
		"streak":
			return """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float power = 1.0;
uniform float tail = 1.0;      // 1 = fades to nothing at uv.x = 0
void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float a = pow(across, 1.6) * mix(1.0, UV.x, tail) * power;
	ALBEDO = mix(color.rgb, vec3(1.0), pow(across, 6.0) * 0.7) * a;
	ALPHA = clamp(a, 0.0, 1.0) * color.a;
}
"""
		# a standing translucent panel: bright rim and base, a rising shimmer (Pin's Rain of Arrows)
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
		# a licking flame on a billboard (Pin's anti-heal burn: blue)
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
		# a flaming crescent ribbon (Bjorn's slam): uv.x along the arc, uv.y from the inner to the outer edge;
		# a white-yellow core, orange then red edges, burning away from its tail as life runs down
		"crescent":
			return """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.55, 0.15, 1.0);
uniform float life = 1.0;      // 1 -> 0
uniform float power = 2.4;
void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float along = sin(clamp(UV.x, 0.0, 1.0) * 3.14159);
	float lick = 0.8 + 0.2 * sin(UV.x * 40.0 + TIME * 30.0 + UV.y * 9.0);
	float a = pow(across, 1.2) * along * lick * clamp(life * 1.5, 0.0, 1.0) * power;
	vec3 hot = mix(vec3(0.9, 0.12, 0.05), color.rgb, clamp((across - 0.1) / 0.45, 0.0, 1.0));
	hot = mix(hot, vec3(1.0, 0.96, 0.7), clamp((across - 0.65) / 0.3, 0.0, 1.0));
	ALBEDO = hot * a * 1.6;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""
		# a light pillar: brightest on its rim (seen side-on), rising chevron bands (Bjorn's beacon, Purify's column)
		"beam":
			return """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float power = 1.0;
uniform float speed = 1.4;
uniform float bands = 6.0;
varying float rim;
void vertex() {
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	rim = 1.0 - abs(n.z);
}
void fragment() {
	float up = UV.y;   // 0 at the top, 1 at the foot
	float ch = fract(up * bands + TIME * speed + abs(UV.x - 0.5) * 1.2);
	float chev = smoothstep(0.0, 0.08, ch) * (1.0 - smoothstep(0.12, 0.24, ch));
	float fade = smoothstep(0.0, 0.5, up);
	float a = (0.18 + rim * 0.75 + chev * 0.55) * fade * power;
	ALBEDO = mix(color.rgb, vec3(1.0), chev * 0.4 + rim * 0.2) * a;
	ALPHA = clamp(a, 0.0, 1.0) * color.a;
}
"""
		# a swirling ring band flat on the ground (Bjorn's 360 Smash, Purify's rings): uv.x round, uv.y across
		"swirl":
			return """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 color2 : source_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform float life = 1.0;
uniform float power = 1.0;
uniform float spin = 3.0;
void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float sw = fract(UV.x * 6.0 - UV.y * 0.6 + TIME * spin);
	float streak = smoothstep(0.0, 0.5, sw) * (1.0 - smoothstep(0.5, 1.0, sw));
	float a = pow(across, 1.4) * (0.35 + 0.65 * streak) * life * power;
	ALBEDO = mix(color.rgb, color2.rgb, streak * across) * a * 1.4;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""
		# Bjorn's aegis: a curved gold slab with vertical ribs, a bright rim, a hammer sigil at its heart,
		# a shimmer that sweeps across it, a flash when it blocks and cracks as it weakens
		"aegis":
			return """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float power = 1.0;
uniform float hit = 0.0;       // 1 on a block, fades
uniform float hurt = 0.0;      // 0 whole .. 1 nearly broken
uniform float armed = 0.0;     // a Shield Slam is armed: it burns hotter
void fragment() {
	vec2 uv = UV;
	float rim = max((1.0 - smoothstep(0.0, 0.06, uv.y)), smoothstep(0.9, 1.0, uv.y)) + max((1.0 - smoothstep(0.0, 0.035, uv.x)), smoothstep(0.965, 1.0, uv.x));
	float ribs = smoothstep(0.88, 1.0, abs(sin(uv.x * 3.14159 * 9.0))) * 0.35;
	vec2 c = vec2((uv.x - 0.5) * 2.6, (uv.y - 0.45) * 1.0);
	float head = step(abs(c.x), 0.32) * step(abs(c.y + 0.16), 0.09);
	float haft = step(abs(c.x), 0.06) * step(-0.16, c.y) * step(c.y, 0.3);
	float sigil = max(head, haft);
	float sweep = exp(-pow((uv.x - fract(TIME * 0.45)) * 9.0, 2.0)) * 0.35;
	float crack = hurt * smoothstep(0.93, 1.0, abs(sin(uv.x * 23.0 + sin(uv.y * 17.0) * 2.0))) * 1.2;
	float a = (0.14 + ribs + rim * 0.9 + sigil * 0.55 + sweep + crack + hit * 0.8 + armed * 0.25) * power;
	vec3 col = mix(color.rgb, vec3(1.0, 0.98, 0.85), rim * 0.4 + hit * 0.5 + sigil * 0.25);
	col = mix(col, vec3(1.0, 0.45, 0.15), armed * 0.35 + crack * 0.4);
	ALBEDO = col * a;
	ALPHA = clamp(a, 0.0, 1.0) * color.a;
}
"""
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
