shader_type spatial;
// An exit's sky beam (ExitSignal): a plain alpha column, not additive, so it still reads over a bright
// ground. Fades toward the top and is a little denser along its middle.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 color : source_color = vec4(1.0);
uniform float height = 70.0;
varying float up;
void vertex() {
	up = VERTEX.y / height + 0.5;
}
void fragment() {
	float core = 0.6 + 0.4 * clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = color.rgb;
	ALPHA = color.a * core * (1.0 - 0.6 * clamp(up, 0.0, 1.0));
}
