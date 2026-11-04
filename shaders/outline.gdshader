shader_type spatial;
// Ink outline drawn from the inside of a slightly grown copy. It grows with distance so the line
// stays about the same thickness on screen, close up or zoomed out.
render_mode unshaded, cull_front, shadows_disabled;
uniform vec4 color : source_color = vec4(0.08, 0.065, 0.12, 1.0);
uniform float width = 0.00125;
// a painted model's line at the match camera: this much thinner from ~8 to 18 m away (every belt, buckle and strand
// outlined at ~1 px added up to dark speckle along the silhouette)
uniform float far_thin = 0.0;
void vertex() {
	float d = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	VERTEX += NORMAL * clamp(d * width, 0.0042, 0.034) * (1.0 - far_thin * smoothstep(8.0, 18.0, d));
}
void fragment() { ALBEDO = color.rgb; }
