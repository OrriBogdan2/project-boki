shader_type spatial;
// (feelfix) Farm pond water: a gentle swell, two layers of drifting ripples, the sky's colour
// toward grazing angles, and soft highlights where the ripples crest. World-space, so tiles join.
render_mode cull_disabled, depth_draw_opaque;
uniform vec3 deep_col : source_color = vec3(0.13, 0.36, 0.55);
uniform vec3 shallow_col : source_color = vec3(0.30, 0.62, 0.72);
uniform vec3 sky_col : source_color = vec3(0.70, 0.86, 0.95);
varying vec3 wp;

#include "res://shaders/noise.gdshaderinc"

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (sin(wp.x * 2.1 + TIME * 1.6) + cos(wp.z * 1.7 + TIME * 1.3)) * 0.008;
}

void fragment() {
	vec2 p = wp.xz;
	float r1 = vnoise(p * 1.7 + vec2(TIME * 0.28, TIME * 0.19));
	float r2 = vnoise(p * 2.6 - vec2(TIME * 0.22, -TIME * 0.31));
	float rip = smoothstep(0.62, 0.8, (r1 + r2) * 0.5);
	float caust = 1.0 - smoothstep(0.0, 0.05, abs(r1 - r2));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec3 c = mix(deep_col, shallow_col, 0.25 + 0.5 * r2);
	c = mix(c, sky_col, 0.2 + 0.45 * fres);
	c += vec3(0.9, 0.97, 1.0) * (rip * 0.22 + caust * 0.12);
	ALBEDO = c;
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
	METALLIC = 0.0;
}
