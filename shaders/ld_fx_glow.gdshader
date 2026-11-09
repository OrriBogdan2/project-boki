shader_type spatial;
// The glow pass of Cinder's and Dredge's effect looks: only the hot cores, added on top of the body pass.
render_mode unshaded, shadows_disabled, depth_draw_never, blend_add, cull_disabled, fog_disabled;
#include "res://shaders/ld_fx.gdshaderinc"

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = ld_billboard(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX);
	}
}

void fragment() {
	vec3 body;
	float alpha;
	vec3 glow;
	ld_look(UV, body, alpha, glow);
	ALBEDO = glow * color.a;
}
