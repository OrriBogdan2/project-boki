shader_type spatial;
// ReceiverCue's body shell: a heal is a soft band of light climbing the body (band 0 -> 1), a shield a
// thin bright rim (band < 0). Mixed, not added, so the tint still reads over bright ground, where an
// additive glow saturates to nothing.
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 1.0;
uniform float band = -1.0;       // heal: the band's height up the body, 0..1; below 0: a shield's rim
uniform float body_h = 1.8;      // the capsule's height (local), to place the band
varying float y01;
void vertex() {
	y01 = VERTEX.y / body_h + 0.5;
}
void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
	float a;
	if (band >= 0.0) {
		float b = exp(-pow((y01 - band) / 0.13, 2.0));
		a = b * (0.4 + 0.6 * rim) + 0.3 * rim;
	} else {
		a = pow(rim, 2.5) * 1.3 + 0.06;
	}
	ALBEDO = color.rgb;
	ALPHA = clamp(a * strength, 0.0, 0.9);
}
