shader_type spatial;
// Tarek's stone: dark basalt with glowing molten cracks. The cracks are the thin valleys of a value
// noise in object space, so every rock and boulder cracks in its own place and nothing tiles.
// heat 0..1 drives how wide and bright the cracks run (a launched or punched rock runs hot).
render_mode cull_back, specular_disabled;
#include "res://shaders/noise.gdshaderinc"
uniform vec4 stone : source_color = vec4(0.2, 0.15, 0.13, 1.0);
uniform vec4 stone_hi : source_color = vec4(0.42, 0.31, 0.24, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.45, 0.12, 1.0);
uniform float heat : hint_range(0.0, 1.0) = 0.35;
uniform float scale = 3.2;
uniform float seed = 0.0;
// a warm light on the edges (Tarek's raised rocks; 0 elsewhere)
uniform vec4 rim_col : source_color = vec4(1.0, 0.72, 0.42, 1.0);
uniform float rim = 0.0;
// sunlit upward faces (the same rocks; 0 elsewhere)
uniform vec4 cap_col : source_color = vec4(0.92, 0.8, 0.6, 1.0);
uniform float cap = 0.0;
varying vec3 opos;
varying float up;
void vertex() {
	opos = VERTEX;
	up = NORMAL.y;
}
void fragment() {
	vec2 q = opos.xz * scale + opos.y * vec2(1.7, -1.3) * scale + vec2(seed * 7.1, seed * 3.3);
	float n = fbm3(q);
	float crack = 1.0 - smoothstep(0.0, 0.035 + heat * 0.05, abs(n - 0.5));
	float base = clamp(opos.y * 0.7 + 0.35, 0.0, 1.0);
	vec3 rock = mix(stone.rgb, stone_hi.rgb, fbm3(q * 0.5 + 3.0) * 0.8);
	// the cracks glow brighter toward the base, where the heat comes up from the ground
	float hot = crack * mix(1.0, 0.45, base) * (0.45 + heat);
	rock = mix(rock, cap_col.rgb, cap * smoothstep(0.4, 0.75, up));
	ALBEDO = rock * (1.0 - crack * 0.6);
	ROUGHNESS = 0.9;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = glow.rgb * hot * (1.2 + heat * 2.2) + rim_col.rgb * rim * edge;
}
