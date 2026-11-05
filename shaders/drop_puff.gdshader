shader_type spatial;
// One of the clouds you fall past: a camera-facing puff of soft noise, sunlit on top and blue underneath.
// It thins out as the camera nears it, so falling through one rushes by instead of whiting out the view.
// INSTANCE_CUSTOM: x a seed, y its opacity.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 lit : source_color = vec4(1.0, 0.99, 0.96, 1.0);
uniform vec4 shade : source_color = vec4(0.62, 0.7, 0.86, 1.0);
uniform float near_fade = 60.0;      // m from the camera: fully gone inside this...
uniform float near_full = 130.0;     // ...and full from here
#include "res://shaders/noise.gdshaderinc"
varying float seed;
varying float opacity;
void vertex() {
	seed = INSTANCE_CUSTOM.x;
	opacity = INSTANCE_CUSTOM.y;
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s * 0.62, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
float puff_fbm(vec2 p) {
	return 0.533 * vnoise(p) + 0.267 * vnoise(p * 2.07 + 5.2) + 0.2 * vnoise(p * 4.3 + 1.3);
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	vec2 p = q * 1.5 + vec2(seed * 37.0, seed * 91.0) + vec2(TIME * 0.02, 0.0);
	float n = puff_fbm(p);
	float n2 = puff_fbm(p + vec2(0.0, 0.16));       // toward the sun, up the quad
	float round_edge = 1.0 - smoothstep(0.2, 1.0, length(q));
	float dens = smoothstep(0.32, 0.72, n * 0.75 + round_edge * 0.55) * smoothstep(0.0, 0.3, round_edge);
	float litk = clamp((n - n2) * 2.6 + 0.62 - q.y * 0.32, 0.0, 1.0);
	ALBEDO = mix(shade.rgb, lit.rgb, litk);
	float cam_d = length(VERTEX);
	ALPHA = dens * opacity * smoothstep(near_fade, near_full, cam_d);
}
