shader_type spatial;
// Dredge's Grapnel rope (scripts/arch/kits/ld_fx.gd LDFx.rope): braided strands drawn on top of walls and
// rocks too (no depth test), so the hook always reads. UV.x runs along the rope in metres, UV.y across a strand;
// the vertex colour darkens alternate strands so the braid reads.
render_mode unshaded, shadows_disabled, depth_draw_never, depth_test_disabled, blend_mix, cull_disabled, fog_disabled;
uniform vec4 color : source_color = vec4(0.94, 0.82, 0.44, 1.0);
uniform vec4 color2 : source_color = vec4(1.0, 0.96, 0.8, 1.0);
uniform float twist = 6.0;

void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float lay = fract(UV.x * twist + UV.y * 0.8);
	float fibre = smoothstep(0.0, 0.2, lay) * (1.0 - smoothstep(0.55, 0.9, lay));
	float shade = 1.0 - across * across * 0.7;
	vec3 c = mix(color.rgb * 0.55, color.rgb, fibre) * shade + color2.rgb * (1.0 - smoothstep(0.0, 0.25, across)) * 0.35;
	ALBEDO = c * COLOR.rgb;
	ALPHA = (1.0 - smoothstep(0.8, 1.0, across)) * color.a;
}
