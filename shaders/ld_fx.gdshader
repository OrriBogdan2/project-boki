shader_type spatial;
// The body pass of Cinder's and Dredge's effect looks (the looks are in ld_fx.gdshaderinc). Alpha-blended,
// so colour, dark rims and smoke hold on bright ground; LDFx chains ld_fx_glow.gdshader on as next_pass.
render_mode unshaded, shadows_disabled, depth_draw_never, blend_mix, cull_disabled, fog_disabled;
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
	ALBEDO = body;
	ALPHA = clamp(alpha * color.a, 0.0, 1.0);
}
