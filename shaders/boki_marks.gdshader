shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;
// A rigged Boki's coat marks (Unique.dress), drawn over its painted coat as a pass of their own: the same patterns as
// toon.gdshader, read off the rest position kept in the vertex colour so they stay on the fur, with alpha masking
// the shell and the props out.
uniform int mark_kind = 0;
uniform vec4 mark_color : source_color = vec4(0.2, 0.15, 0.1, 1.0);
uniform vec3 mark_seed = vec3(0.0);
uniform float mark_scale = 9.0;
uniform float mark_amt = 0.5;
uniform float mark_glow = 0.0;
uniform float strength = 0.62;
varying vec3 rest;
varying float fur;

float mk_h31(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
vec3 mk_h33(vec3 p) {
	return fract(sin(vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)))) * 43758.5453);
}
float mk_vn3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(mk_h31(i), mk_h31(i + vec3(1, 0, 0)), u.x), mix(mk_h31(i + vec3(0, 1, 0)), mk_h31(i + vec3(1, 1, 0)), u.x), u.y),
		mix(mix(mk_h31(i + vec3(0, 0, 1)), mk_h31(i + vec3(1, 0, 1)), u.x), mix(mk_h31(i + vec3(0, 1, 1)), mk_h31(i + vec3(1, 1, 1)), u.x), u.y), u.z);
}
float mk_spots(vec3 q, float amt) {
	vec3 i = floor(q); vec3 f = fract(q);
	float m = 0.0;
	for (int z = -1; z <= 1; z++) for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 o = mk_h33(i + g);
		float keep = step(mk_h31(i + g + 17.0), 0.35 + amt * 0.6);
		float r = mix(0.18, 0.36, o.z) * (0.7 + amt * 0.6);
		float dd = length(g + o * 0.7 + 0.15 - f);
		m = max(m, keep * (1.0 - smoothstep(r - 0.05, r, dd)));
	}
	return m;
}
float mk_pattern(vec3 q) {
	if (mark_kind == 1) { return mk_spots(q, mark_amt); }
	if (mark_kind == 2) {
		float w = mk_vn3(q * 0.45) * 3.2;
		float s = sin(q.x * 1.6 + q.z * 0.4 + w);
		return smoothstep(0.82 - mark_amt * 0.9, 0.95 - mark_amt * 0.9, s);
	}
	if (mark_kind == 3) {
		float n = mk_vn3(q) * 0.7 + mk_vn3(q * 2.3 + 5.0) * 0.3;
		return smoothstep(0.68 - mark_amt * 0.3, 0.72 - mark_amt * 0.3, n);
	}
	if (mark_kind == 4) { return mk_spots(q, mark_amt * 0.5) * 0.85; }
	return 0.0;
}


void vertex() {
	VERTEX += NORMAL * 0.002;      // just off the coat, so the two passes don't fight over the same depth
	rest = (COLOR.rgb * vec3(1.2, 1.2, 1.4) - vec3(0.6, 0.0, 0.7));
	fur = COLOR.a;
}

void fragment() {
	float mk = mk_pattern(rest * mark_scale + mark_seed) * smoothstep(0.5, 0.9, fur);
	ALBEDO = mark_color.rgb * 0.8;
	EMISSION = mark_color.rgb * mark_glow;
	ALPHA = mk * strength;
}
