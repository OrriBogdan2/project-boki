shader_type spatial;
// A thin team-colour outline for your own side (OcclusionOutline), drawn as a material overlay and only
// where something nearer the camera (a cliff, a tree, an arch) covers it. No glow: a hard, flat line.
// It reads the scene depth, so a surface of its own model never counts as cover (the gap). The
// Compatibility renderer (macOS, web) keeps depth in 0..1 with NDC z in -1..1, so it is remapped there;
// without that every pixel read as covered and uncovered Hunters wore the line too.
// Uncovered, the shell's fringe past the silhouette is a dark ground rim (rim_*) wherever the scene behind it
// lies rim_depth or more farther away: only the outer edge against the ground, never a belt or fold over the
// model itself (a full ink shell there read as speckle at the match camera). It lifts a Hunter off the pale
// Hollow Crown ground (docs/COMBAT_CLARITY.md "Hunter against the ground").
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float grow = 0.015;      // m: how far the shell stands off the model
uniform float band = 0.3;        // 0..1: how close to edge-on a surface must be to take the line
uniform float gap = 0.9;         // m: how much nearer the depth buffer must be to count as cover
uniform vec4 rim_color : source_color = vec4(0.08, 0.065, 0.12, 1.0);  // the ink colour (outline.gdshader)
uniform float rim_alpha = 1.0;
uniform float rim_depth = 0.25;  // m: how much farther the scene behind the fringe must be (the ground)
uniform float rim_px = 1.6;      // the shell at least this many pixels of a 720 px tall view wide
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
void vertex() {
	float d = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	float px = PROJECTION_MATRIX[3][3] > 0.5 ? 2.0 / (abs(PROJECTION_MATRIX[1][1]) * 720.0)
		: 2.0 * d / (abs(PROJECTION_MATRIX[1][1]) * 720.0);
	VERTEX += NORMAL * max(grow, rim_px * px);
}
void fragment() {
	float edge = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float depth = texture(depth_tex, SCREEN_UV).x;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec4 ndc = INV_PROJECTION_MATRIX * vec4(vec3(SCREEN_UV, depth) * 2.0 - 1.0, 1.0);
#else
	vec4 ndc = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
#endif
	float seen_z = -(ndc.z / ndc.w);
	float covered = step(seen_z + gap, -VERTEX.z);
	float ground = step(-VERTEX.z + rim_depth, seen_z);
	ALBEDO = mix(rim_color.rgb, color.rgb, covered);
	ALPHA = max(covered * smoothstep(1.0 - band, 1.0 - band * 0.6, edge), ground * rim_alpha);
}
