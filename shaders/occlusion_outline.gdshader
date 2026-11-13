shader_type spatial;
// A thin team-colour outline for your own side (OcclusionOutline), drawn as a material overlay and only
// where something nearer the camera (a cliff, a tree, an arch) covers it. No glow: a hard, flat line.
// It reads the scene depth, so a surface of its own model never counts as cover (the gap). The
// Compatibility renderer (macOS, web) keeps depth in 0..1 with NDC z in -1..1, so it is remapped there;
// without that every pixel read as covered and uncovered Hunters wore the line too.
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float grow = 0.015;      // m: how far the shell stands off the model
uniform float band = 0.3;        // 0..1: how close to edge-on a surface must be to take the line
uniform float gap = 0.9;         // m: how much nearer the depth buffer must be to count as cover
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
void vertex() {
	VERTEX += NORMAL * grow;
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
	ALBEDO = color.rgb;
	ALPHA = covered * smoothstep(1.0 - band, 1.0 - band * 0.6, edge);
}
