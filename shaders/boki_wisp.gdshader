shader_type spatial;
// A Boki wisp's body (BokiWispLook): the one material every Boki wisp shares. Unlit and opaque; each part's
// colour (body, belly, tips) comes in the vertex colours, the middle lifts toward white like a soul-light
// and the edge turns to the Boki's glow colour (per wisp, an instance uniform), so the critter reads as an
// outline of light.
render_mode unshaded, shadows_disabled, fog_disabled;
instance uniform vec4 rim_col : source_color = vec4(1.0);
instance uniform float flash = 0.0;  // 0..1: the whole body lifts to the rim colour (BokiWispPop's type-coloured light)
instance uniform float dim = 1.0;   // under 1 while its summon rests (KinSummon)
uniform float glow = 0.15;   // how far the middle lifts toward white
uniform float rim = 0.9;     // how strongly the edge turns to the glow colour
void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// vertex colours are 8-bit sRGB (finer steps in the darks than linear): to linear here. The Compatibility
	// renderer (the web build) draws ALBEDO as it is, in sRGB, so there they stay as they are (a linear dark
	// body came out near black).
	vec3 base = mix(pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), COLOR.rgb / 12.92, step(COLOR.rgb, vec3(0.04045)));
	base = OUTPUT_IS_SRGB ? COLOR.rgb : base;
	vec3 col = mix(base, vec3(1.0), glow * facing * facing);
	ALBEDO = mix(col, rim_col.rgb * 1.3, pow(1.0 - facing, 1.2) * rim) * dim;
	ALBEDO = mix(ALBEDO, rim_col.rgb * 1.3, flash);
}
