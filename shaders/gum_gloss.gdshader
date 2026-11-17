shader_type spatial;
// A bubble's gloss over its toon pass (WardenGlb: Sparkle's gum, a material tagged "gum"): drawn additively on top,
// a pale fresnel rim and one soft highlight toward the upper left, so the opaque pink ball reads as a thin,
// glossy, see-through skin of gum. No depth write, so it never hides what's behind it.
render_mode blend_add, unshaded, depth_draw_never, cull_back;
uniform vec4 rim_color : source_color = vec4(1.0, 0.82, 0.93, 1.0);
uniform float rim = 0.75;
uniform float spot = 0.9;

void fragment() {
	float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fr = pow(1.0 - nv, 2.5);
	vec3 h = normalize(VIEW + normalize(vec3(-0.5, 0.7, 0.4)));
	float sp = smoothstep(0.93, 0.985, dot(NORMAL, h));
	ALBEDO = rim_color.rgb * fr * rim + vec3(1.0) * sp * spot;
}
