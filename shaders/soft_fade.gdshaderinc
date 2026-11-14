// Soft edges where a camera-facing effect (fx_dot bursts and dust, LDFx's upright looks) meets the ground, so a
// dot or flame tongue fades out instead of cutting a hard line into it. One path, picked by renderer:
// Forward+/Mobile fade by the scene depth behind the fragment (a soft particle); Compatibility has no depth
// texture to spare, so it fades by the fragment's height over the match's tile ground (fx_ground, set by
// FxGround; off outside a match, where nothing fades).
const float SOFT_REACH = 0.25;   // m: from touching the ground (hidden) to fully shown

#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
global uniform sampler2D fx_ground : filter_nearest;   // tile heights: R = (level + 1) / 32, as terrain's height_tex
global uniform vec3 fx_ground_size;                     // xy: the map in tiles (1 m each); z: 1 when on
const float SOFT_LEVEL = 0.8;                           // m per tile level (TerrainMesh.LEVEL)
#else
uniform sampler2D soft_depth : hint_depth_texture, filter_nearest;
#endif

// 0..1: how much of this fragment shows (call from fragment() with SCREEN_UV, VERTEX and the two matrices).
float soft_fade(vec2 screen_uv, vec3 view_pos, mat4 inv_proj, mat4 inv_view) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	if (fx_ground_size.z < 0.5) {
		return 1.0;
	}
	vec3 p = (inv_view * vec4(view_pos, 1.0)).xyz;
	float ground = (texture(fx_ground, p.xz / fx_ground_size.xy).r * 32.0 - 1.0) * SOFT_LEVEL;
	return smoothstep(0.0, SOFT_REACH, p.y - ground);
#else
	float depth = texture(soft_depth, screen_uv).r;
	vec4 scene = inv_proj * vec4(screen_uv * 2.0 - 1.0, depth, 1.0);
	return smoothstep(0.0, SOFT_REACH, view_pos.z - scene.z / scene.w);
#endif
}
