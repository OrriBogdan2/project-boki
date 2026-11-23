shader_type spatial;
// (feelfix) A thin band of foam where pond water meets the bank: brighter at the bank, breaking up
// and drifting. UV.y runs 0 at the bank to 1 out on the water.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
varying vec3 wp;
#include "res://shaders/noise.gdshaderinc"
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = vnoise(wp.xz * 5.0 + vec2(TIME * 0.5, -TIME * 0.35));
	float edge = 1.0 - UV.y;
	float a = smoothstep(0.0, 0.6, edge) * (0.45 + 0.55 * n) * (0.75 + 0.25 * sin(TIME * 2.2 + wp.x * 3.0 + wp.z * 2.0));
	ALBEDO = vec3(0.93, 0.97, 1.0);
	ALPHA = clamp(a, 0.0, 0.85);
}
