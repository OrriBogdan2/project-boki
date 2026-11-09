// A Hero's cloth scarf end (scripts/match/hero_scarf.gd): one lit, two-sided band. UV.x runs from the knot (0) to
// the tip (1), UV.y across. Frost-white at the knot, the Hero's colour coming in toward the tip as the cloth thins
// and fades out; a cut point, soft edges, a faint knit and a few frost glints that catch the light.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_schlick_ggx, shadows_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec4 root_col : source_color = vec4(0.94, 0.98, 1.0, 1.0);  // the cloth at the knot
uniform vec4 tip_col : source_color = vec4(0.37, 0.84, 0.77, 1.0);  // the Hero's colour it fades out in
uniform float fade_from = 0.55;    // share of the length where the cloth starts to thin out
uniform float point_len = 0.14;    // share of the length the cut point takes
uniform float seed = 0.0;
uniform float gain = 1.0;          // the viewer's share of it (HeroVfx.view_k: an ally's sits dimmer)

void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	// the cut point: the band narrows to a tip over its last point_len, its sides curving in
	float to_tip = clamp((1.0 - UV.x) / point_len, 0.0, 1.0);
	float cut = smoothstep(0.0, 0.06, pow(to_tip, 0.6) - across);
	float edge = 1.0 - smoothstep(0.82, 1.0, across);
	float thin = 1.0 - smoothstep(fade_from, 1.0, UV.x) * 0.8;
	float a = cut * mix(0.55, 1.0, edge) * thin * mix(0.95, 0.75, UV.x);
	float tint = smoothstep(0.1, 0.95, UV.x);
	float knit = sin(UV.x * 220.0 + sin(UV.y * 6.0) * 2.0) * 0.5 + 0.5;
	vec3 c = mix(root_col.rgb, tip_col.rgb, tint) * (0.93 + knit * 0.07);
	// a fold shade down the middle, so the band reads as cloth and not a flat card
	c *= 1.0 - (1.0 - across) * 0.08;
	float glint = step(0.985, h21(floor(vec2(UV.x * 90.0, UV.y * 9.0)) + seed));
	ALBEDO = c * gain;
	ALPHA = clamp(a, 0.0, 1.0) * gain;
	ROUGHNESS = 0.7;
	SPECULAR = 0.35;
	EMISSION = (vec3(0.9, 0.97, 1.0) * glint * 0.6 + tip_col.rgb * tint * 0.12) * gain;
	BACKLIGHT = vec3(0.3) * root_col.rgb;
}
