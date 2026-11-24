shader_type spatial;
// Bright projectile core with a soft edge.
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never;
uniform vec4 color : source_color = vec4(1.0);
instance uniform float near_a : hint_range(0.0, 1.0) = 1.0;  // FxHunterCap: the glow's share of alpha near a Hunter
void fragment() {
	float f = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	ALBEDO = mix(color.rgb, vec3(1.0), f * 0.7);
	ALPHA = clamp(f * 1.4, 0.0, 1.0) * color.a * near_a;
}
