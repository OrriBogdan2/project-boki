shader_type spatial;
// Pip's and Claire's light (CareLook): a soft column or comet body that fades along its length
// (UV.y) and at its sides with a slow shimmer, or (orb = 1) a ball that fades toward its silhouette.
// Mixed, not added: on bright grass an additive light washes to beige, a mixed one keeps its hue.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 color : source_color = vec4(1.0);
uniform float alpha = 1.0;
uniform float fade_end = 1.0;     // 1: fades toward UV.y = 1; 0: even
uniform float orb = 0.0;          // 1: a ball (fresnel fade) instead of a strip
void fragment() {
	float side = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = mix(1.0, 1.0 - UV.y, fade_end);
	float sh = 0.85 + 0.15 * sin(UV.y * 24.0 - TIME * 8.0);
	float a = pow(side, 1.5) * along * sh;
	float core = pow(side, 6.0);
	if (orb > 0.5) {
		float f = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
		a = clamp(f * 1.4, 0.0, 1.0);
		core = f * f;
	}
	ALBEDO = mix(color.rgb, vec3(1.0), core * 0.25);
	ALPHA = clamp(a * color.a * alpha, 0.0, 1.0);
}
