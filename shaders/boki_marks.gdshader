shader_type spatial;
render_mode blend_mul, depth_draw_never, cull_back, unshaded;
// Dark coat marks on a rigged Boki's painted coat: the coat's own paint, deeper (a multiply), so a marked Vespyx stays
// the pink fox of its art. A flat mark colour laid over the atlas read as another Boki (owner 11-19, "the old model").
#include "res://shaders/boki_marks.gdshaderinc"
uniform float dark_tone = 0.55;     // the coat's value under a full mark

void fragment() {
	ALBEDO = mix(vec3(1.0), vec3(dark_tone), mk_mask());
}
