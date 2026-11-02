shader_type spatial;
// Moosh Moosh's lantern light (CareLook): an additive soft column or comet body that fades along
// its length (UV.y) and at its sides, with a slow shimmer. For the light columns, rising rays, the
// root beam, the comet tails and the swirl.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
uniform vec4 color : source_color = vec4(1.0);
uniform float alpha = 1.0;
uniform float fade_end = 1.0;     // 1: fades toward UV.y = 1; 0: even
void fragment() {
	float side = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = mix(1.0, 1.0 - UV.y, fade_end);
	float sh = 0.85 + 0.15 * sin(UV.y * 24.0 - TIME * 8.0);
	float a = pow(side, 1.5) * along * sh;
	ALBEDO = mix(color.rgb, vec3(1.0), pow(side, 6.0) * 0.6);
	ALPHA = clamp(a * color.a * alpha, 0.0, 1.0);
}
