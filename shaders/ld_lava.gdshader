shader_type spatial;
// Cinder's lava carpet (Flue Flight, LDFx.lava). Alpha-blended, not additive, so the dark charred rim and the
// deep orange read as colour on bright ground instead of washing out to beige; only the hot cracks glow.
// UV.x runs along the strip, UV.y across; life 0 -> 1 over the carpet's 4s; progress is the strip length (m).
render_mode unshaded, shadows_disabled, depth_draw_never, blend_mix, cull_disabled, fog_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.48, 0.16, 1.0);    // the molten body (Cinder's orange)
uniform vec4 color2 : source_color = vec4(0.29, 0.07, 0.22, 1.0);  // the charred rim
uniform float life = 0.0;
uniform float progress = 1.0;
uniform float seed = 0.0;
#include "res://shaders/noise.gdshaderinc"

void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float flow = fbm3(vec2(UV.x * progress * 1.2 - TIME * 0.35, UV.y * 2.5 + TIME * 0.2 + seed));
	float crack_n = vnoise(vec2(UV.x * progress * 3.0 + TIME * 0.8, UV.y * 6.0));
	float body = 1.0 - smoothstep(0.55, 0.95, across + flow * 0.2);
	float core = 1.0 - smoothstep(0.1, 0.6, across + flow * 0.25);
	float crack = smoothstep(0.55, 0.85, crack_n) * core;
	vec3 molten = mix(color.rgb * 0.8, color.rgb, core);
	vec3 col = mix(color2.rgb, molten, smoothstep(0.35, 0.8, 1.0 - across + flow * 0.15));
	col += vec3(1.0, 0.85, 0.35) * crack * 0.9;
	float ends = smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.92, 1.0, UV.x));
	float fade = 1.0 - smoothstep(0.75, 1.0, life);
	ALBEDO = col;
	ALPHA = body * ends * fade * 0.92;
}
