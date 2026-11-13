// Sight: everyone on your team lights up a small circle around them and a wide wedge in front of them
// (where they aim) out to their range. Walls and high ground cast sight shadows. Everything outside
// what your team can see is darkened and turned a cool grey-blue, so the lit space reads at a glance;
// your own wedge's two sides carry a thin soft cyan line on the ground. Set from Match; the numbers
// are measured from the owner's reference in docs/specs/VISION_LOOK.md.
global uniform float vis_on;
global uniform vec3 vis_focus;
global uniform vec2 vis_dir;
global uniform vec2 vis_size;
global uniform sampler2D vis_blocks : filter_linear;
global uniform float vis_range;
global uniform float vis_allies;
global uniform vec4 vis_ally0;     // xy = position (x, z), zw = aim direction
global uniform vec4 vis_ally1;
global uniform vec4 vis_ally2;
global uniform float vis_ally_range;   // how far teammates see (the raid condition shortens it)
global uniform float vis_dark;         // how dark it is outside sight (RaidLook.VIS_DARK; darker at night)

const float VIS_COS = 0.087;           // cos of half the wedge: 170 degrees wide (Match.VIEW_COS, the same rule)
const float VIS_NEAR = 2.0;           // m: the circle all round you that is always lit (Match.NEAR_SENSE)
const float VIS_SOFT = 0.35;           // m: the lit side fades in over this much past the wedge's side
const float VIS_LINE_W = 0.035;        // m: the edge line core fades out by this far each side (~3 px solid at 1080p)
const float VIS_GLOW_W = 0.25;         // m: the glow falling off into the lit side (1/e at ~7 px at 1080p)
const vec3 VIS_LINE = vec3(0.32, 0.86, 1.0);   // the edge line's cyan

// Metres from the wedge's nearer side, along the ground: negative inside the wedge, positive outside.
float vis_side(vec2 d, float dist, vec2 dir) {
	float a = acos(clamp(dot(d / max(dist, 0.001), dir), -1.0, 1.0)) - acos(VIS_COS);
	return dist * sin(clamp(a, -1.5707, 1.5707));
}

// How lit a point is by one viewer: 1 inside the circle or the unblocked cone, 0 outside.
float vis_one(vec2 eye, vec2 dir, float range, vec2 wp, int max_steps) {
	vec2 d = wp - eye;
	float dist = length(d);
	float near_v = 1.0 - smoothstep(VIS_NEAR, VIS_NEAR + 0.6, dist);
	if (near_v >= 1.0) { return 1.0; }
	float cone = (1.0 - smoothstep(-VIS_SOFT, 0.0, vis_side(d, dist, dir))) * (1.0 - smoothstep(range - 2.5, range + 0.5, dist));
	if (cone > 0.001) {
		// sight shadows: march toward the point through a smoothed map of what blocks sight
		float steps = clamp(floor(dist / 0.4), 1.0, float(max_steps));
		float occ = 0.0;
		for (int i = 1; i < 64; i++) {
			if (i >= max_steps) { break; }
			float t = float(i) / steps;
			if (t >= 1.0 || dist * (1.0 - t) < 0.7) { break; }
			vec2 q = eye + d * t;
			float v = textureLod(vis_blocks, q / vis_size, 0.0).r;
			occ = max(occ, smoothstep(0.32, 0.72, v));
			if (occ > 0.99) { break; }
		}
		cone *= 1.0 - occ;
	}
	return max(near_v, cone);
}

float vis_fog(vec3 wp) {
	if (vis_on < 0.5) { return 0.0; }
	float lit = vis_one(vis_focus.xz, vis_dir, vis_range, wp.xz, 60);
	if (lit < 0.999 && vis_allies > 0.5) { lit = max(lit, vis_one(vis_ally0.xy, vis_ally0.zw, vis_ally_range, wp.xz, 28)); }
	if (lit < 0.999 && vis_allies > 1.5) { lit = max(lit, vis_one(vis_ally1.xy, vis_ally1.zw, vis_ally_range, wp.xz, 28)); }
	if (lit < 0.999 && vis_allies > 2.5) { lit = max(lit, vis_one(vis_ally2.xy, vis_ally2.zw, vis_ally_range, wp.xz, 28)); }
	return 1.0 - lit;
}

// Outside sight: darker and a cool blue (75% toward a blue with little red, then x vis_dark), but the
// ground, walls and grass still read. Tuned on GPU shots (docs/specs/VISION_LOOK.md): a greyer blue
// turns purple on warm ground, a deeper one goes near black. Inside: a touch brighter, so the lit space pops. What's hidden
// stays hidden either way: rival hunters and Boki out of sight aren't drawn at all
// (Match._update_vision), this only shades the world.
vec3 vis_apply(vec3 c, float fog) {
	if (vis_on < 0.5) { return c; }
	vec3 blue = vec3(dot(c, vec3(0.3, 0.59, 0.11))) * vec3(0.2, 0.75, 1.3) + vec3(0.0, 0.01, 0.04);
	vec3 dark = mix(c, blue, 0.75) * vis_dark;
	return mix(c * 1.05, dark, fog);
}

// The glow of your own wedge's two sides on the ground (added to EMISSION): from your near circle out
// to your range, a thin cyan core with a soft fall-off into the lit side.
vec3 vis_edge(vec3 wp) {
	if (vis_on < 0.5) { return vec3(0.0); }
	vec2 d = wp.xz - vis_focus.xz;
	float dist = length(d);
	float s = vis_side(d, dist, vis_dir);
	float line_k = 1.0 - smoothstep(VIS_LINE_W * 0.5, VIS_LINE_W, abs(s));
	float glow_k = s < 0.0 ? exp(s / VIS_GLOW_W * 3.0) * 0.45 : 0.0;
	float span = smoothstep(VIS_NEAR, VIS_NEAR + 0.6, dist) * (1.0 - smoothstep(vis_range - 3.0, vis_range, dist));
	return VIS_LINE * max(line_k, glow_k) * span;
}
