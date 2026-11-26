shader_type canvas_item;
render_mode blend_disabled;
// Bakes one layer of the terrain's big patterns (shaders/ground_big.gdshaderinc) over the whole map; UV 0..1
// spans it, so each texel holds the live value at its centre (see scripts/match/ground_bake.gd).
#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/ground_big.gdshaderinc"
uniform vec2 map_size = vec2(64.0, 64.0);
uniform int layer = 0;

void fragment() {
	vec2 p = UV * map_size;
	int k = layer * 4;
	COLOR = vec4(big_live(p, k), big_live(p, k + 1), layer < 2 ? big_live(p, k + 2) : 0.0, layer < 2 ? big_live(p, k + 3) : 1.0);
}
