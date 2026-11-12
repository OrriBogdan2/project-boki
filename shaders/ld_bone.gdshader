shader_type spatial;
// Grimble's bone hook (scripts/arch/kits/ld_fx.gd, the "hook" prop): lit bone with a coin-gold rim. Drawn on top of
// walls and rocks too (no depth test), so the hook always reads.
render_mode unshaded, shadows_disabled, depth_draw_never, depth_test_disabled, blend_mix, cull_back, fog_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.78, 0.2, 1.0);     // the rim
uniform vec4 color2 : source_color = vec4(0.86, 0.8, 0.7, 1.0);    // the bone

void fragment() {
	float lit = 0.5 + 0.5 * clamp(dot(normalize(NORMAL), normalize(vec3(-0.35, 0.65, 0.65))), -1.0, 1.0);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	ALBEDO = color2.rgb * lit + color.rgb * rim * 0.5;
	ALPHA = 1.0;
}
