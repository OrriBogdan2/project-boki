shader_type spatial;
// The marks Boki leave in pond water (scripts/home/boki_wake.gd): one flat quad per mark, every mark in one
// MultiMesh. INSTANCE_CUSTOM.r picks the mark (0 a ripple ring round the body, 1 a V wake opening behind it),
// .g offsets the ring's waves in time (0..1, so Boki don't ripple in step), .b is how strongly it shows (0..1).
// Each wave is a bank-foam white crest with a darker trough just outside it, so it reads on the pale pond
// water, broken up and drifting like the pond's own foam (pond_foam.gdshader). water_mask (one texel per 1 m
// water tile) keeps the marks off the banks: a ring on dry ground would read as a gameplay ring.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;
uniform float period = 0.6;      // s between ripple waves (wade.json ripple_secs); each wave lives two periods
uniform sampler2D water_mask : hint_default_white, filter_linear, repeat_disable;
uniform vec2 mask_origin = vec2(0.0);    // m: the mask's corner on the ground (x, z)
uniform vec2 mask_span = vec2(1.0);      // m: its size
const float RING_IN = 0.45;      // where a wave starts, as a share of the ring's radius (about the body's edge)
const float RING_W = 0.06;       // a crest's half width, as a share of the ring's radius
const float ARM_W = 0.1;         // a V arm's crest half width at the bow, as a share of the wake's half width
const vec3 FOAM = vec3(0.93, 0.97, 1.0);
const vec3 TROUGH = vec3(0.13, 0.36, 0.55);      // the pond's deep colour (pond_water.gdshader deep_col)
varying vec4 mark;
varying vec2 lp;                 // the quad's own x and z, -0.5..0.5 (the wake's +z runs back from the bow)
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float band(float x, float w) { return 1.0 - smoothstep(0.0, w, abs(x)); }
void vertex() {
	mark = INSTANCE_CUSTOM;
	lp = VERTEX.xz;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float crest = 0.0;
	float trough = 0.0;
	if (mark.r < 0.5) {
		// two waves at a time, each spreading out from the body and fading as it goes
		float d = length(lp) * 2.0;
		for (int i = 0; i < 2; i++) {
			float t = fract(TIME / (period * 2.0) + mark.g + float(i) * 0.5);
			float off = d - mix(RING_IN, 1.0, t);
			float life = (1.0 - t * t) * smoothstep(0.0, 0.12, t);
			crest += band(off, RING_W) * life;
			trough += band(off - RING_W * 1.8, RING_W * 1.3) * life;
		}
	} else {
		// two arms from the bow out to the quad's back corners, with swells running back along them
		float along = lp.y + 0.5;
		float w = ARM_W + along * 0.1;
		float off = abs(lp.x) * 2.0 - along;
		float life = (0.7 + 0.3 * sin(along * 18.0 - TIME * 7.0)) * sqrt(1.0 - along) * smoothstep(0.0, 0.1, along);
		crest = band(off, w) * life;
		trough = band(off - w * 1.8, w * 1.3) * life;
	}
	float wet = smoothstep(0.3, 0.7, texture(water_mask, (wp.xz - mask_origin) / mask_span).r);
	float n = 0.7 + 0.3 * vnoise(wp.xz * 5.0 + vec2(TIME * 0.5, -TIME * 0.35));
	crest = clamp(crest, 0.0, 1.0);
	ALBEDO = mix(TROUGH, FOAM, crest / max(crest + trough, 0.001));
	ALPHA = clamp(max(crest, trough * 0.4) * n * mark.b * wet, 0.0, 0.9);
}
