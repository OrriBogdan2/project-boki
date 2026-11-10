shader_type spatial;
// The Wisp's glowing body (WispLook): a coloured ball, brighter toward its middle with a pale rim, that
// flickers. Mixed, not added, so it keeps its colour on bright ground. flash > 1 whitens it (the pops),
// fade takes it out.
render_mode unshaded, shadows_disabled, blend_mix, depth_draw_never, fog_disabled;
uniform vec4 core_col : source_color = vec4(1.0);
uniform vec4 rim_col : source_color = vec4(1.0);
uniform float glow = 0.85;
uniform float flash = 1.0;
uniform float fade = 1.0;
uniform float flicker = 0.25;
uniform float flicker_hz = 9.0;
uniform float phase = 0.0;
void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float wave = 0.5 * sin(TIME * flicker_hz + phase) + 0.5 * sin(TIME * flicker_hz * 2.3 + phase * 1.7);
	float flick = 1.0 + flicker * 0.25 * wave;
	vec3 heart = mix(core_col.rgb, vec3(1.0), glow * 0.6);
	vec3 col = mix(core_col.rgb * 0.85, heart, smoothstep(0.35, 1.0, facing));
	col = mix(col, rim_col.rgb, pow(1.0 - facing, 3.0) * 0.6);
	col = mix(col * flick, vec3(1.0), clamp((flash - 1.0) / 3.0, 0.0, 1.0) * 0.8);
	ALBEDO = col;
	ALPHA = clamp(fade, 0.0, 1.0);
}
