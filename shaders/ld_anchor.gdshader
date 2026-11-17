shader_type spatial;
// Dredge's giant anchor (LDFx anchor_drop and the air dive): a solid dark iron body that holds its shape on
// bright grass, a thin seafoam fresnel rim so the silhouette reads, and a faint top light. Opaque; `fade`
// takes it away with a screen-door dither so it never turns see-through and pale.
render_mode unshaded, shadows_disabled, cull_back, fog_disabled;
uniform vec4 color : source_color = vec4(0.23, 0.25, 0.28, 1.0);    // the iron
uniform vec4 color2 : source_color = vec4(0.36, 1.0, 0.85, 1.0);    // the rim glow
uniform float fade = 1.0;

void fragment() {
	float dither = fract(dot(floor(FRAGCOORD.xy), vec2(0.5, 0.25)) + 0.125);
	if (fade < 0.999 && dither > fade) {
		discard;
	}
	float rim = smoothstep(0.55, 0.85, 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0));
	vec3 world_n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float top = clamp(world_n.y, 0.0, 1.0);
	ALBEDO = mix(color.rgb * (0.7 + 0.5 * top), color2.rgb, rim);
}
