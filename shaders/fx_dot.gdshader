shader_type spatial;
// Particle bursts (hits, dust, pickups, explosions): a camera-facing soft dot with a crisp bright
// core, coloured by the particle (COLOR, faded by the burst's ramp). Dusty, pale colours stay soft
// puffs; bright colours get a white-hot centre.
// Soft where it meets the ground: Forward+ and Mobile fade by the depth behind the dot; gl_compatibility (no
// depth read) and the Low presets (FxDot adds DOT_HEIGHT_FADE: no depth copy) fade by height above the ground
// under the burst (instance uniform ground_y, set by Fx).
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY || defined(DOT_HEIGHT_FADE)
#define HEIGHT_FADE
#endif
render_mode unshaded, shadows_disabled, depth_draw_never, blend_mix, cull_disabled, fog_disabled;
uniform float core = 0.55;
uniform float soft_m : hint_range(0.01, 1.0) = 0.15;      // m over which a dot fades out into the ground
#ifdef HEIGHT_FADE
instance uniform float ground_y = -1000.0;                // m, the ground under the burst (none: no fade)
#else
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
#endif
#include "res://shaders/cel.gdshaderinc"
const vec2 LIGHT_UV = vec2(-0.45, -0.89);     // the key light in the dot's UV: up and to the left, as on the cast
const float SHADE = 0.62;                     // the shaded tone's share of the lit one
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv);
	if (d > 1.0) { discard; }
	float sat = max(max(COLOR.r, COLOR.g), COLOR.b) - min(min(COLOR.r, COLOR.g), COLOR.b);
	float hot = smoothstep(0.15, 0.45, sat);
	float body = cel_cover(1.0 - smoothstep(0.35, 1.0, d), UV * 0.5);
	float c = hard(0.3 - d);
	// cel: dust and smoke in two flat tones (lit and shaded), hot sparks a flat white core
	float tone = mix(mix(SHADE, 1.0, hard(dot(uv, LIGHT_UV) + 0.2)), 1.0, hot);
	ALBEDO = mix(COLOR.rgb * tone, vec3(1.0), c * core * hot) * (1.0 + hot * 0.6);
#ifdef HEIGHT_FADE
	float gap = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y - ground_y;
#else
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(depth_tex, SCREEN_UV).r, 1.0);
	float gap = VERTEX.z - behind.z / behind.w;
#endif
	ALPHA = clamp(body * (0.75 + hot * 0.25) + c * 0.3, 0.0, 1.0) * COLOR.a * smoothstep(0.0, soft_m, gap);
}
