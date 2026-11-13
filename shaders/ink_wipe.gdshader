shader_type canvas_item;
// A ragged ink wipe instead of a plain fade: the rect's colour alpha is how far the ink has
// spread (0 = clear, 1 = covered), sweeping down from the top in torn, brushy edges.
#include "res://shaders/noise.gdshaderinc"
void fragment() {
	float prog = COLOR.a;
	float n = vnoise(UV * vec2(9.0, 5.0)) * 0.55 + vnoise(UV * vec2(23.0, 13.0)) * 0.25;
	float edge = n * 0.6 + UV.y * 0.4;
	float a = smoothstep(edge - 0.06, edge, prog * 1.2 - 0.1);
	COLOR = vec4(0.02, 0.015, 0.035, a);
}
