shader_type spatial;
// Dredge's giant anchor (LDFx anchor_drop and the air dive): a solid dark iron body that holds its shape on
// bright grass, a seafoam fresnel rim so the silhouette reads, and a faint top light. `fade` takes it away.
render_mode unshaded, shadows_disabled, blend_mix, depth_draw_always, cull_back, fog_disabled;
uniform vec4 color : source_color = vec4(0.23, 0.25, 0.28, 1.0);    // the iron
uniform vec4 color2 : source_color = vec4(0.36, 1.0, 0.85, 1.0);    // the rim glow
uniform float fade = 1.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec3 world_n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float top = clamp(world_n.y, 0.0, 1.0);
	ALBEDO = mix(color.rgb * (0.75 + 0.5 * top), color2.rgb, clamp(rim * 1.4, 0.0, 1.0));
	ALPHA = fade;
}
