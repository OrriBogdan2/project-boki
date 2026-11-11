// The cel look every Hero effect shares (docs/HERO_VFX.md "The cel look"): heat and cover in CEL_BANDS flat steps
// with one-pixel hard edges, ragged by one baked noise texture (art/vfx/noise.png: r billows, g fbm, b cell walls;
// the vfx_noise shader global in project.godot, baked by tools/gen_vfx_noise.py).
global uniform sampler2D vfx_noise : filter_linear_mipmap, repeat_enable;

const float CEL_BANDS = 4.0;     // flat steps: char, body, hot, white-hot
const float CEL_RAG = 0.14;      // share of a step the noise moves an edge by, so steps read hand-cut, not ruled

// 0 below zero, 1 above, with a one-pixel anti-aliased step between: a cel edge at any size on screen
float hard(float x) {
	return clamp(x / max(fwidth(x), 1e-4) + 0.5, 0.0, 1.0);
}

// h snapped to CEL_BANDS flat steps, the step edges anti-aliased
float cel(float h) {
	float s = h * CEL_BANDS;
	return (floor(s) + hard(fract(s) - 0.5)) / CEL_BANDS;
}

// A soft cover or glow (0..1) drawn as flat steps with ragged hard edges; faint haze below half a step is gone.
// uv picks the noise (a look's own UV, offset by its seed, so stacked looks don't share edges).
float cel_cover(float a, vec2 uv) {
	float rag = (texture(vfx_noise, uv).g - 0.5) * CEL_RAG * 2.0 / CEL_BANDS;
	return cel(clamp(a + rag, 0.0, 1.0));
}

// An additive glow colour snapped to flat steps of its own brightness (its hue kept).
vec3 cel_glow(vec3 c, vec2 uv) {
	float v = max(max(c.r, c.g), c.b);
	return v > 1e-4 ? c * (cel_cover(min(v, 1.0), uv) / min(v, 1.0)) : c;
}

// A shockwave ring over a flat quad (uv 0..1) at `go` 0..1 of its run: a hard band with a hot lead edge, broken up
// by the noise's cell walls as `spent` runs 0..1. x: the band, y: its lead edge.
vec2 cel_ring(vec2 uv, float go, float spent, float ring_seed) {
	vec2 p = uv * 2.0 - 1.0;
	float d = length(p);
	float round_u = atan(p.y, p.x) / 6.2832 * 2.0 + ring_seed;     // two whole turns of the tiling noise: no seam
	float r = go * 0.9 + (texture(vfx_noise, vec2(round_u, 0.2)).g - 0.5) * 0.08;
	float w = mix(0.2, 0.03, go);
	float band = hard(min(r - d, d - r + w));
	float gaps = hard(texture(vfx_noise, vec2(round_u * 1.5, go * 0.25)).b - spent * 1.2 + 0.35);
	return vec2(band * gaps, band * hard(d - r + w * 0.4));
}
