shader_type spatial;
// The last hunter up: a rim of side colour hugging the body with bands climbing it, deep then bright,
// so it reads on snow as well as on dark ground (mixed, not added). Drawn from the inside, so the
// hunter stays visible through it.
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 color : source_color = vec4(1.0);
uniform float climb_hz = 0.7;   // bands climbing per second
void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 0.9);
	float band = 0.5 + 0.5 * sin((UV.y * 3.0 - TIME * climb_hz) * 6.2831853);
	float ends = smoothstep(0.0, 0.2, UV.y) * smoothstep(1.0, 0.8, UV.y);
	ALBEDO = mix(color.rgb * 0.55, mix(color.rgb, vec3(1.0), 0.35), band);
	ALPHA = clamp(0.12 + rim * (0.75 + 0.35 * band), 0.0, 1.0) * mix(0.4, 1.0, ends) * color.a;
}
