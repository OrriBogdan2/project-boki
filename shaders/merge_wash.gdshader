shader_type spatial;
// The colour a merged form washes over the whole model (an overlay on every mesh): a flat tint plus a bright rim,
// so the silhouette reads in the form's colour from the top-down camera, hat included. One shared material.
render_mode unshaded, depth_draw_never, shadows_disabled, blend_add;
uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 1.0;
void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float pulse = 0.9 + 0.1 * sin(TIME * 5.0);
	ALBEDO = color.rgb;
	ALPHA = clamp((0.34 + rim * 0.8) * strength * color.a * pulse, 0.0, 1.0);
}
