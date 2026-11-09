shader_type spatial;
// The soft light round a Wisp (WispLook): added, strongest toward the middle and gone at the edge, so it
// reads as a glow, never a disc. Same uniforms as wisp_core so HunterWisp can flash and fade both.
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, fog_disabled;
uniform vec4 core_col : source_color = vec4(1.0);
uniform vec4 rim_col : source_color = vec4(1.0);
uniform float glow = 0.85;
uniform float alpha = 0.12;
uniform float flash = 1.0;
uniform float fade = 1.0;
uniform float flicker = 0.25;
uniform float flicker_hz = 9.0;
uniform float phase = 0.0;
void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float flick = 1.0 + flicker * 0.3 * sin(TIME * flicker_hz * 0.5 + phase);
	ALBEDO = core_col.rgb * glow;
	ALPHA = clamp(pow(facing, 2.5) * alpha * flash * flick * fade, 0.0, 1.0);
}
