shader_type spatial;
// The marks Boki leave in pond water (scripts/home/boki_wake.gd): one flat quad per mark, every mark in one
// MultiMesh. INSTANCE_CUSTOM.r picks the mark (0 a ripple ring round the body, 1 a V wake opening behind it),
// .g offsets the ring's waves in time (0..1, so Boki don't ripple in step), .b is how strongly it shows (0..1).
// Bank-foam white, broken up and drifting like the pond's own foam (pond_foam.gdshader).
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, fog_disabled;
uniform float period = 0.6;      // s between ripple waves (wade.json ripple_secs); each wave lives two periods
const float RING_IN = 0.45;      // where a wave starts, as a share of the ring's radius (about the body's edge)
const float RING_W = 0.07;       // a wave's half width, as a share of the ring's radius
const float ARM_W = 0.07;        // a V arm's half width at the bow, as a share of the wake's half width
varying vec4 mark;
varying vec2 lp;                 // the quad's own x and z, -0.5..0.5 (the wake's +z runs back from the bow)
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void vertex() {
	mark = INSTANCE_CUSTOM;
	lp = VERTEX.xz;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float a = 0.0;
	if (mark.r < 0.5) {
		// two waves at a time, each spreading out from the body and thinning away
		float d = length(lp) * 2.0;
		for (int i = 0; i < 2; i++) {
			float t = fract(TIME / (period * 2.0) + mark.g + float(i) * 0.5);
			float r = mix(RING_IN, 1.0, t);
			a += (1.0 - smoothstep(0.0, RING_W, abs(d - r))) * (1.0 - t) * smoothstep(0.0, 0.15, t);
		}
	} else {
		// two arms from the bow out to the quad's back corners, with swells running back along them
		float along = lp.y + 0.5;
		float side = abs(lp.x) * 2.0;
		float arm = 1.0 - smoothstep(0.0, ARM_W + along * 0.1, abs(side - along));
		float swell = 0.65 + 0.35 * sin(along * 18.0 - TIME * 7.0);
		a = arm * swell * (1.0 - along) * smoothstep(0.0, 0.12, along);
	}
	float n = vnoise(wp.xz * 5.0 + vec2(TIME * 0.5, -TIME * 0.35));
	ALBEDO = vec3(0.93, 0.97, 1.0);
	ALPHA = clamp(a * (0.55 + 0.45 * n) * mark.b, 0.0, 0.85);
}
