// A Hero's cloth scarf end (scripts/match/hero_scarf.gd): one lit, two-sided band. UV.x runs from the knot (0) to
// the tip (1), UV.y across. Frost-white at the knot, the Hero's colour coming in toward the tip as the cloth thins
// and fades out; a cut point, soft edges, two long folds and a cold rim where it turns from the light.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_schlick_ggx, shadows_disabled;

uniform vec4 root_col : source_color = vec4(0.94, 0.98, 1.0, 1.0);  // the cloth at the knot
uniform vec4 tip_col : source_color = vec4(0.37, 0.84, 0.77, 1.0);  // the Hero's colour it fades out in
uniform float fade_from = 0.6;     // share of the length where the cloth starts to thin out
uniform float point_len = 0.14;    // share of the length the cut point takes
uniform float folds = 1.5;         // long folds across the band
uniform float seed = 0.0;          // (a fold's phase: two tails don't fold alike)
uniform float gain = 1.0;          // the viewer's share of it (HeroVfx.view_k: an ally's sits dimmer)

void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	// the cut point: the band narrows to a tip over its last point_len, its sides curving in
	float to_tip = clamp((1.0 - UV.x) / point_len, 0.0, 1.0);
	float cut = smoothstep(0.0, 0.08, pow(to_tip, 0.6) - across);
	float edge = 1.0 - smoothstep(0.88, 1.0, across);
	float thin = 1.0 - smoothstep(fade_from, 1.0, UV.x) * 0.55;
	float tint = smoothstep(0.15, 1.0, UV.x);
	float fold = sin(UV.y * 6.2832 * folds + UV.x * 3.0 + seed);
	vec3 c = mix(root_col.rgb, tip_col.rgb, tint) * (0.9 + fold * 0.08);
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = c * gain;
	ALPHA = clamp(cut * mix(0.7, 0.96, edge) * thin, 0.0, 1.0) * gain;
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
	EMISSION = (mix(root_col.rgb, tip_col.rgb, 0.5) * rim * 0.35 + tip_col.rgb * tint * 0.1) * gain;
	BACKLIGHT = vec3(0.35) * c;
}
