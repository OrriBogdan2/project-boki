shader_type spatial;
// Cinder's lava carpet (Flue Flight, LDFx.lava). Alpha-blended, not additive, so the dark charred rim and the
// deep orange read as colour on bright ground instead of washing out to beige; only the hot cracks glow.
// UV.x runs along the strip, UV.y across; life 0 -> 1 over the carpet's life (the edge starts hot and cools); progress is the strip length (m).
render_mode unshaded, shadows_disabled, depth_draw_never, blend_mix, cull_disabled, fog_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.48, 0.16, 1.0);    // the molten body (Cinder's orange)
uniform vec4 color2 : source_color = vec4(0.29, 0.07, 0.22, 1.0);  // the charred rim
uniform float life = 0.0;
uniform float progress = 1.0;
uniform float seed = 0.0;
#include "res://shaders/noise.gdshaderinc"

void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float heat = 1.0 - smoothstep(0.1, 0.8, life);               // the fresh carpet is hot, then it cools
	float flow = fbm3(vec2(UV.x * progress * 1.2 - TIME * 0.35, UV.y * 2.5 + TIME * 0.2 + seed));
	float crack_n = vnoise(vec2(UV.x * progress * 3.0 + TIME * 0.8, UV.y * 6.0));
	// the body fills the whole strip (UV.y 0..1 is the damage width); a thin dark crust at the very rim gives the
	// band its shape on bright ground, and the hot line sits just inside it (a deep yellow-orange, not cream)
	float body = 1.0 - smoothstep(0.94, 1.0, across + flow * 0.04);
	float core = 1.0 - smoothstep(0.2, 0.85, across + flow * 0.25);
	float crust = smoothstep(0.86, 0.93, across + flow * 0.05);
	float edge = smoothstep(0.58, 0.8, across + flow * 0.1) * (1.0 - crust);
	float crack = smoothstep(0.55, 0.85, crack_n) * core;
	vec3 hot = vec3(1.0, 0.66, 0.12);
	vec3 col = mix(color.rgb * 0.75, color.rgb, core);
	col = mix(col, hot, edge * heat * 0.85);                      // the edge is the hot line, then it chars
	col = mix(col, color2.rgb, edge * (1.0 - heat) * 0.7);
	col += vec3(1.0, 0.8, 0.3) * crack * 0.8 * (0.4 + 0.6 * heat);
	col *= 1.0 - 0.35 * smoothstep(0.3, 1.0, life);               // the body darkens as it cools but stays orange
	col = mix(col, color2.rgb, crust * (0.65 + 0.3 * (1.0 - heat)));
	float ends = smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.92, 1.0, UV.x));
	float fade = 1.0 - smoothstep(0.75, 1.0, life);
	ALBEDO = col;
	ALPHA = body * ends * fade * 0.95;
}
