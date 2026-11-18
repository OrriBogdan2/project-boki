// Sight: everyone on your team lights up a small circle around them and a wide wedge in front of them
// (where they aim) out to their range; a rival who gave herself away lights a soft circle of her own. Walls and high ground cast sight shadows. Everything outside
// what your team can see is greyed out like fog (desaturated, dimmer, a light veil; no tint), so the lit space
// reads at a glance; the cone's sides are a soft fade, not a line. Set from Match; the numbers
// are measured from the owner's reference in docs/specs/VISION_LOOK.md.
global uniform float vis_on;
global uniform vec3 vis_focus;
global uniform vec2 vis_dir;
global uniform vec2 vis_size;
global uniform sampler2D vis_blocks : filter_linear;
global uniform float vis_range;
global uniform vec2 vis_scout;     // the held far look (ScoutLook): x extra share of range inside the cone, y its half-angle's cosine
global uniform float vis_allies;
global uniform vec4 vis_ally0;     // xy = position (x, z), zw = aim direction
global uniform vec4 vis_ally1;
global uniform vec4 vis_ally2;
global uniform float vis_ally_range;   // how far teammates see (the raid condition shortens it)
global uniform float vis_dark;         // how dark it is outside sight (RaidLook.VIS_DARK; darker at night)
global uniform float vis_reveals;      // rivals who gave themselves away (RevealLight, up to three)
global uniform vec3 vis_reveal0;       // xy = position (x, z), z = strength (fades out as the reveal ends)
global uniform vec3 vis_reveal1;
global uniform vec3 vis_reveal2;

const float VIS_COS = 0.5;             // cos of half the cone: 120 degrees wide (Match.VIEW_COS, the same rule)
const float VIS_NEAR = 2.0;           // m: the circle all round you that is always lit (Match.NEAR_SENSE)
const float VIS_REVEAL_R = 2.0;        // m: lit round a revealed rival, soft to +0.6 (~10% of the screen across, as measured)
const float VIS_SOFT = 1.6;            // m: the lit cone fades out over this much inside its sides (a soft edge, no line)

// Metres from the wedge's nearer side, along the ground: negative inside the wedge, positive outside.
float vis_side(vec2 d, float dist, vec2 dir) {
	float a = acos(clamp(dot(d / max(dist, 0.001), dir), -1.0, 1.0)) - acos(VIS_COS);
	return dist * sin(clamp(a, -1.5707, 1.5707));
}

// How lit a point is by one viewer: 1 inside the circle or the unblocked cone, 0 outside. `scout` reaches
// that share further inside the far look's narrow cone (0 for teammates).
float vis_one(vec2 eye, vec2 dir, float range, float scout, vec2 wp, int max_steps) {
	vec2 d = wp - eye;
	float dist = length(d);
	float near_v = 1.0 - smoothstep(VIS_NEAR, VIS_NEAR + 0.6, dist);
	if (near_v >= 1.0) { return 1.0; }
	float c = dot(d / max(dist, 0.001), dir);
	float reach = range * (1.0 + scout * smoothstep(vis_scout.y - 0.006, vis_scout.y + 0.006, c));
	float cone = (1.0 - smoothstep(-VIS_SOFT, 0.0, vis_side(d, dist, dir))) * (1.0 - smoothstep(reach - 2.5, reach + 0.5, dist));
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

// A revealed rival's own soft circle (RevealLight): no sight shadows, it is her light, not your view.
float vis_reveal(vec3 r, vec2 wp) {
	return r.z * (1.0 - smoothstep(VIS_REVEAL_R, VIS_REVEAL_R + 0.6, distance(wp, r.xy)));
}

float vis_fog(vec3 wp) {
	if (vis_on < 0.5) { return 0.0; }
	float lit = vis_one(vis_focus.xz, vis_dir, vis_range, vis_scout.x, wp.xz, 60);
	if (lit < 0.999 && vis_allies > 0.5) { lit = max(lit, vis_one(vis_ally0.xy, vis_ally0.zw, vis_ally_range, 0.0, wp.xz, 28)); }
	if (lit < 0.999 && vis_allies > 1.5) { lit = max(lit, vis_one(vis_ally1.xy, vis_ally1.zw, vis_ally_range, 0.0, wp.xz, 28)); }
	if (lit < 0.999 && vis_allies > 2.5) { lit = max(lit, vis_one(vis_ally2.xy, vis_ally2.zw, vis_ally_range, 0.0, wp.xz, 28)); }
	if (lit < 0.999 && vis_reveals > 0.5) { lit = max(lit, vis_reveal(vis_reveal0, wp.xz)); }
	if (lit < 0.999 && vis_reveals > 1.5) { lit = max(lit, vis_reveal(vis_reveal1, wp.xz)); }
	if (lit < 0.999 && vis_reveals > 2.5) { lit = max(lit, vis_reveal(vis_reveal2, wp.xz)); }
	return 1.0 - lit;
}

// Outside sight: grey fog. The ground is pulled to its own luma (no hue, so no blue), a light neutral veil lifts
// the darks, VIS_COOL takes out the cast the lighting and grade add, then it is dimmed by vis_dark; the terrain,
// walls and grass still read. Inside: a touch brighter, so the lit space pops. What's hidden stays hidden either
// way: rival hunters and Boki out of sight aren't drawn at all (Match._update_vision), this only shades the world.
const float VIS_GREY = 1.0;            // share of the colour pulled to grey outside sight (all of it: every ground ends up one grey)
const float VIS_VEIL = 0.14;           // share of a mid-grey fog laid over it
const vec3 VIS_COOL = vec3(0.7, 1.0, 0.95);   // cancels the sun's warmth and the grade's saturation: grey shows as grey (GPU, clear)
vec3 vis_apply(vec3 c, float fog) {
	if (vis_on < 0.5) { return c; }
	vec3 grey = vec3(dot(c, vec3(0.3, 0.59, 0.11)));
	vec3 dark = mix(mix(c, grey, VIS_GREY), vec3(0.5), VIS_VEIL) * VIS_COOL * vis_dark;
	return mix(c * 1.05, dark, fog);
}
