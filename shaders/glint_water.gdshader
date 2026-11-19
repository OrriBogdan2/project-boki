// Glint Fishing looks (scripts/home/glint_fx.gd, content/rules/glint_fishing_vfx.json), one shader, a look each.
// Premultiplied like the Hero surface looks, drawn in the shared cel pass: flat hard-edged bands, no soft glow.
shader_type spatial;
render_mode blend_premul_alpha, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/cel.gdshaderinc"

const int L_RIPPLE = 0;     // the bobber landing: one small ring easing out over the water
const int L_TIGHT = 1;      // waiting: rings round the bobber; `close` 0..1 draws them in
const int L_SPLASH = 2;     // the bite: a fast thin ring with a crown of teeth
const int L_GLINT = 3;      // a catch: a four-point star facing the camera

uniform int look = 0;
uniform vec4 col : source_color = vec4(0.75, 0.96, 1.0, 1.0);
uniform vec4 col2 : source_color = vec4(1.0);
uniform float life = 0.0;   // 0..1 through the look
uniform float close = 0.0;  // L_TIGHT: 0 rings wide at rest .. 1 closed on the bobber
uniform float rest = 0.95;  // L_TIGHT: the outer ring's radius at rest (share of the quad)
uniform float core = 0.3;   // L_TIGHT: the outer ring's radius once closed
uniform int rings = 3;
uniform float seed = 0.0;

void vertex() {
	if (look == L_GLINT) {
		float s = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	}
}

vec4 ripple(vec2 uv) {
	float go = 1.0 - pow(1.0 - life, 2.0);
	vec2 ring_v = cel_ring(uv, go, life, seed);
	float a = ring_v.x * (1.0 - hard(life - 0.7));
	return vec4(mix(col.rgb, col2.rgb, ring_v.y) * a, a);
}

vec4 tight(vec2 uv) {
	float d = length(uv * 2.0 - 1.0);
	float outer = mix(rest, core, close);
	float a = 0.0;
	for (int i = 0; i < rings; i++) {
		float r = outer * (1.0 - float(i) * 0.22);
		a = max(a, hard(min(r - d, d - r + 0.045)));
	}
	a *= mix(0.45, 1.0, close);
	return vec4(mix(col.rgb, col2.rgb, close) * a, a);
}

vec4 splash(vec2 uv) {
	vec2 p = uv * 2.0 - 1.0;
	float d = length(p);
	float r = 1.0 - pow(1.0 - life, 3.0);
	float teeth = pow(0.5 + 0.5 * cos(atan(p.y, p.x) * 8.0 + seed), 3.0);   // points, not waves
	float reach = r * 0.85 + teeth * 0.2 * sin(life * 3.1416);
	float band = hard(min(reach - d, d - reach + mix(0.16, 0.05, life)));
	float a = band * (1.0 - hard(life - 0.65));
	return vec4(mix(col.rgb, col2.rgb, hard(d - reach + 0.04)) * a, a);
}

vec4 glint(vec2 uv) {
	vec2 p = (uv * 2.0 - 1.0) / mix(0.5, 1.0, sin(min(life * 2.0, 1.0) * 1.5708));
	float star = sqrt(abs(p.x)) + sqrt(abs(p.y));       // < 1 inside a four-point star
	float a = hard(0.95 - star) * (1.0 - hard(life - 0.7));
	float hot = hard(0.5 - star);
	return vec4(mix(col.rgb, col2.rgb, hot) * a, a);
}

void fragment() {
	vec4 v;
	if (look == L_RIPPLE) { v = ripple(UV); }
	else if (look == L_TIGHT) { v = tight(UV); }
	else if (look == L_SPLASH) { v = splash(UV); }
	else { v = glint(UV); }
	if (v.a <= 0.002) { discard; }
	ALBEDO = v.rgb;
	ALPHA = v.a;
}
