shader_type spatial;
// The dj_fx looks alpha blended (scripts/arch/kits/dj_fx.gd, `solid`): saturated colour and dark links that
// keep their colour on bright grass, where an additive pass washes out to beige or white.
render_mode unshaded, shadows_disabled, depth_draw_never, blend_mix, cull_disabled, fog_disabled;
#include "res://shaders/dj_fx.gdshaderinc"

void fragment() {
	vec4 look = dj_look(UV);
	float bright = max(look.r, max(look.g, look.b));
	if (look.a >= 0.0) {
		ALBEDO = look.rgb;
		ALPHA = clamp(look.a, 0.0, 1.0) * color.a;
	} else {
		ALBEDO = look.rgb / max(bright, 0.001);
		ALPHA = smoothstep(0.0, 0.55, bright) * color.a;
	}
}
