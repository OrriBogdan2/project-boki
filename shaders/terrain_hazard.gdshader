shader_type spatial;
// A terrain hazard area (scripts/match/terrain_hazards.gd): one flat quad over the area, cut to its
// outline by a distance field (sdf: metres inside the outline, negative outside). A bright band marks
// the edge so the area reads at a glance; the inside is the hazard's own surface by mode:
// 0 lava (glowing cracks under a dark crust, slow churn), 1 deep water (darker toward the middle,
// drifting ripples), 2 ice (glassy, white cracks), 3 static flats (dark slate, yellow veins that
// brighten with charge before a shock), 4 bramble (dark tangled ground; the thorns are props).
render_mode cull_disabled, depth_draw_opaque;
#include "res://shaders/vis.gdshaderinc"
uniform sampler2D sdf : filter_linear, repeat_disable;
uniform vec2 origin;             // world x, z of the distance field's corner
uniform vec2 size;               // metres it spans
uniform int mode = 0;
uniform vec4 col_deep : source_color;
uniform vec4 col_shallow : source_color;
uniform vec4 col_edge : source_color;
uniform float glow = 0.0;        // how much the surface lights itself
uniform float alpha = 1.0;
uniform float charge = 0.0;      // static flats: 0..1 while a shock builds up
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
// thin bright lines where a noise field crosses its middle (cracks, veins)
float veins(vec2 p, float width) { return 1.0 - smoothstep(0.0, width, abs(vnoise(p) - 0.5)); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = texture(sdf, (wpos.xz - origin) / size).r;
	if (d < 0.0) { discard; }
	float deep = smoothstep(0.2, 3.5, d);
	float edge = 1.0 - smoothstep(0.12, 0.45, d);
	vec2 p = wpos.xz;
	float t = TIME;
	vec3 c = mix(col_shallow.rgb, col_deep.rgb, deep);
	vec3 em = vec3(0.0);
	float a = alpha;
	if (mode == 0) {
		float churn = vnoise(p * 0.6 + vec2(t * 0.15, -t * 0.1));
		float crack = veins(p * 0.9 + churn * 1.5, 0.08);
		float hot = clamp(deep * 0.6 + crack + churn * 0.3, 0.0, 1.0);
		c = mix(col_shallow.rgb, col_deep.rgb, hot);
		em = col_deep.rgb * glow * hot * (0.8 + 0.2 * sin(t * 2.0 + churn * 6.0));
	} else if (mode == 1) {
		float rip = vnoise(p * 1.4 + vec2(t * 0.4, t * 0.25)) + vnoise(p * 2.3 - vec2(t * 0.3, t * 0.45));
		c += vec3(0.08, 0.12, 0.16) * smoothstep(1.1, 1.5, rip);
		a = mix(alpha * 0.85, alpha, deep);
		em = c * glow;
	} else if (mode == 2) {
		float crack = veins(p * 0.8, 0.03) + veins(p * 1.9 + 3.0, 0.025) * 0.6;
		c = mix(c, vec3(1.0), clamp(crack, 0.0, 1.0) * 0.7);
		em = c * glow;
	} else if (mode == 3) {
		float flick = 0.6 + 0.4 * step(0.5, hash(vec2(floor(t * 12.0), 3.0)));
		float v = veins(p * 0.7 + vec2(0.0, t * 0.05), 0.05) + veins(p * 1.6 - 2.0, 0.04) * 0.6;
		float k = mix(0.25, 1.0 + flick, charge);
		c = mix(c, col_edge.rgb, clamp(v, 0.0, 1.0) * k * 0.6);
		em = col_edge.rgb * glow * clamp(v, 0.0, 1.0) * k;
	} else {
		float tang = vnoise(p * 2.5) * 0.6 + vnoise(p * 6.0) * 0.4;
		c *= 0.7 + tang * 0.5;
	}
	// the edge: a bright rim so the area's outline reads from the camera
	c = mix(c, col_edge.rgb, edge * 0.85);
	em += col_edge.rgb * edge * max(glow, 0.35);
	a = mix(a, 1.0, edge);
	float fog = vis_fog(wpos);
	ALBEDO = vis_apply(c, fog);
	EMISSION = em * (1.0 - fog * 0.7);
	ALPHA = a;
	ROUGHNESS = mode == 2 || mode == 1 ? 0.15 : 0.9;
	SPECULAR = mode == 2 || mode == 1 ? 0.6 : 0.1;
}
