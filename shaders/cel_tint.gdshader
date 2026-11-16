shader_type spatial;
// A flat alpha-blended tint in two cel tones (KitLooks.shade_mat): the colour as given on the side facing screen
// up-left, a darker flat step on the far side, one hard edge between. Unshaded and mixed rather than additive, so a
// dark tint stays dark on bright ground. Discs and rings facing the camera keep their one colour.
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix;
#include "res://shaders/cel.gdshaderinc"
uniform vec4 color : source_color = vec4(1.0);
const vec3 TINT_FROM = vec3(-0.45, 0.7, 0.55);      // view space: from the screen's up-left, toward the camera
const float TINT_EDGE = 0.1;                   // dot with TINT_FROM below which a face is in the shaded tone
const float TINT_SHADE = 0.68;                 // the shaded tone's share of the colour
void fragment() {
	float lit = hard(dot(normalize(NORMAL), normalize(TINT_FROM)) - TINT_EDGE);
	ALBEDO = color.rgb * mix(TINT_SHADE, 1.0, lit);
	ALPHA = color.a;
}
