shader_type spatial;
// A Warden .glb's alpha cards (WardenGlb "card" slot): see-through wings painted into a small RGBA atlas
// (tools/meshy/warden_props.py). Both sides drawn, lit softly (the painted colour carries its own shading),
// a pearly sheen where the card turns edge-on, and the hit flash like every other hero surface.
render_mode blend_mix, cull_disabled, depth_draw_never, diffuse_lambert, specular_disabled, shadows_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_tex = true;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_k = 1.0;        // the whole card's opacity, x the atlas alpha
uniform float glow = 0.12;          // a little self light, so the cards read in shadow
uniform float sheen = 0.35;         // the pearly edge-on shimmer
uniform vec4 sheen_color : source_color = vec4(0.85, 0.9, 1.0, 1.0);
uniform float irid = 0.0;           // thin-film colour play that shifts with the view (moth and fairy wings)
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// At the match camera (8 to 18 m, as hero_toon's far_*): the pearly edge sheen and the thin-film colour go
// (far_sheen of them left: per pixel they flickered white), a card turned edge-on fades out (far_edge: a wing seen
// side-on is a sub-pixel pale streak, the speckle fringe) and one seen face-on keeps its coverage (far_alpha x
// the atlas alpha, whose coarse mips average it away), no dither and no cutout
uniform float far_sheen = 0.0;
uniform float far_edge = 1.0;
uniform float far_alpha = 1.35;

void fragment() {
	vec4 t = use_tex ? texture(albedo_tex, UV) : vec4(1.0);
	vec3 c = t.rgb * albedo.rgb;
	// (by the size on screen, in match-camera metres, as hero_toon's match_d)
	float far_k = smoothstep(8.0, 18.0, PROJECTION_MATRIX[3][3] > 0.5 ? 6.97 / abs(PROJECTION_MATRIX[1][1])
		: length(VERTEX) * 3.487 / abs(PROJECTION_MATRIX[1][1]));
	float face_on = abs(dot(NORMAL, VIEW));
	float edge = 1.0 - face_on;
	vec3 sh = mix(sheen_color.rgb, vec3(1.0, 0.8, 0.95), 0.5 + 0.5 * sin(UV.y * 9.0 + UV.x * 5.0));
	c += sh * sheen * edge * edge * mix(1.0, far_sheen, far_k);
	// a soft rainbow that slides across the card as it turns: cyan, pink, gold, mint
	float ph = dot(NORMAL, VIEW) * 3.0 + UV.y * 4.0 + UV.x * 2.0;
	vec3 film = 0.5 + 0.5 * cos(6.2832 * (vec3(0.0, 0.33, 0.67) + ph));
	c = mix(c, c * (0.55 + 0.9 * film), irid * mix(1.0, far_sheen, far_k));
	ALBEDO = mix(c, flash_color.rgb, flash);
	EMISSION = c * glow + flash_color.rgb * flash * 0.9;
	float far_a = mix(1.0, far_alpha * mix(1.0, smoothstep(0.12, 0.45, face_on), far_edge), far_k);
	ALPHA = clamp(t.a * albedo.a * alpha_k * far_a, 0.0, 1.0);
}
