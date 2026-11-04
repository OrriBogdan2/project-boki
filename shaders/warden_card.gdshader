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
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 t = use_tex ? texture(albedo_tex, UV) : vec4(1.0);
	vec3 c = t.rgb * albedo.rgb;
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	vec3 sh = mix(sheen_color.rgb, vec3(1.0, 0.8, 0.95), 0.5 + 0.5 * sin(UV.y * 9.0 + UV.x * 5.0));
	c += sh * sheen * edge * edge;
	ALBEDO = mix(c, flash_color.rgb, flash);
	EMISSION = c * glow + flash_color.rgb * flash * 0.9;
	ALPHA = clamp(t.a * albedo.a * alpha_k, 0.0, 1.0);
}
