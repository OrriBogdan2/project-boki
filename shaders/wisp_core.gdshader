shader_type spatial;
// The Hunter Wisp's one material (WispLook): a round outline in the team colour with a white core. The
// outer part of the silhouette (rim, a fraction of the radius) is the team colour, the middle facing the
// camera is white, and nothing flickers: a steady glow is the Hunter rule (round = Hunter, critter = Boki).
// Mixed, not added, so it keeps its colour on bright ground. flash > 1 whitens it (the pops), fade takes
// it out.
render_mode unshaded, shadows_disabled, blend_mix, depth_draw_never, fog_disabled;
uniform vec4 rim_col : source_color = vec4(1.0);
uniform vec4 core_col : source_color = vec4(1.0);
uniform float rim = 0.3;
uniform float glow = 1.3;
uniform float flash = 1.0;
uniform float fade = 1.0;
void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float inner = 1.0 - rim;
	float edge = sqrt(1.0 - inner * inner);      // the facing value at the rim's inner border
	float core = smoothstep(edge - 0.08, edge + 0.08, facing);
	vec3 col = mix(rim_col.rgb * glow, core_col.rgb, core);
	col = mix(col, vec3(1.0), clamp((flash - 1.0) / 3.0, 0.0, 1.0) * 0.8);
	ALBEDO = col;
	ALPHA = clamp(fade, 0.0, 1.0) * 0.92;
}
