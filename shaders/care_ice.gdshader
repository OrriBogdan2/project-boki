shader_type spatial;
// Claire's ice (CareLook): faceted, see-through crystal with a bright cold rim, a pale core and a
// slow glint that sweeps across the screen-space facets. Used by the shards, the spear, the Rink
// Wall, Shatter spikes and the frost shell. glow lifts it toward white (a fresh or hit crystal).
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, blend_mix;
uniform vec4 color : source_color = vec4(0.62, 0.95, 0.92, 0.7);
uniform vec4 edge : source_color = vec4(0.9, 1.0, 1.0, 1.0);
uniform float glow = 0.0;
uniform float alpha = 1.0;
void fragment() {
	float f = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float rimk = pow(f, 2.2);
	float glint = smoothstep(0.92, 1.0, sin((FRAGCOORD.x + FRAGCOORD.y) * 0.02 - TIME * 3.0) * 0.5 + 0.5);
	vec3 c = mix(color.rgb, edge.rgb, clamp(rimk * 1.3 + glint * 0.5 + glow, 0.0, 1.0));
	ALBEDO = c;
	ALPHA = clamp((color.a * 0.65 + rimk * 0.5 + glint * 0.2 + glow * 0.3) * alpha, 0.0, 1.0);
}
