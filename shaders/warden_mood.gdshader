shader_type spatial;
render_mode unshaded, cull_back;
// A Hunter's face on a screen of glass (Breaker's porthole): glowing shapes drawn from 2D distances, so it holds at any
// zoom and needs no textures. The look is the owner-approved appeal3 face (v2 portrait): rounded half-moon eyes and a
// D-shaped smile in cyan with a pale-mint core, on glossy deep-teal glass. Moods: 0 calm, 1 happy, 2 angry,
// 3 determined, 4 sad; `from` fades into `to` by `k`.
uniform int from_mood = 0;
uniform int to_mood = 0;
uniform float k = 1.0;
uniform float blink = 0.0;        // 0..1: the eyes shut to a line
uniform vec3 glow = vec3(0.25, 0.95, 0.95);
uniform vec3 core = vec3(0.8, 1.0, 0.95);
uniform vec3 glass = vec3(0.12, 0.32, 0.34);
uniform float strength = 1.6;

// a half-moon: a disc of radius r at c, its underside bitten by a wider disc whose top sits dip*r under c (dip 0..1)
float moon(vec2 p, vec2 c, float r, float dip) {
	p.y = c.y + (p.y - c.y) / max(1.0 - blink, 0.06);
	float d = length(p - c) - r;
	return max(d, r * 1.2 - length(p - c + vec2(0.0, r * (dip + 1.2))));
}

// a D: flat top, round bottom (up < 0 flips it into a frown); w, h its half sizes
float dee(vec2 p, vec2 c, float w, float h, float up) {
	vec2 q = (p - c) / vec2(w, h);
	q.y *= sign(up);
	return max(length(q) - 1.0, q.y) * min(w, h);
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

float face(vec2 p, int m) {
	vec2 q = vec2(abs(p.x), p.y);   // the eyes mirror; q.x small is the inner corner
	float d = 9.0;
	if (m == 0) {          // calm: the approved face, rounded eyes and a small smile
		d = min(moon(q, vec2(0.5, 0.0), 0.26, 0.3), dee(p, vec2(0.0, -0.36), 0.15, 0.14, 1.0));
	} else if (m == 1) {   // happy: big half-moons and an open grin
		d = min(moon(q, vec2(0.5, 0.04), 0.3, 0.12), dee(p, vec2(0.0, -0.33), 0.27, 0.2, 1.0));
	} else if (m == 2) {   // angry: the half-moons cut by a brow slanting down to the middle, a frown
		float lid = q.y - 0.02 - 0.75 * (q.x - 0.32);
		d = min(max(moon(q, vec2(0.5, 0.0), 0.27, 0.3), lid), dee(p, vec2(0.0, -0.44), 0.16, 0.09, -1.0));
	} else if (m == 3) {   // determined: flattened half-moons under a level lid, a straight mouth
		d = min(max(moon(q, vec2(0.5, -0.02), 0.28, 0.4), q.y - 0.1), seg(p, vec2(-0.15, -0.38), vec2(0.15, -0.38)) - 0.045);
	} else {               // sad: half-moons drooping to the outside, a small down-turned mouth
		float lid = q.y - 0.12 + 0.6 * (q.x - 0.5);
		d = min(max(moon(q, vec2(0.48, -0.04), 0.25, 0.3), lid), dee(p, vec2(0.0, -0.46), 0.13, 0.08, -1.0));
	}
	return d;
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(2.0, -2.0);
	float d = mix(face(p, from_mood), face(p, to_mood), k);
	float line = smoothstep(0.015, -0.015, d);
	float hot = smoothstep(-0.02, -0.12, d);        // the pale core inside the shapes
	float halo = exp(-max(d, 0.0) * 9.0);
	// the glass: deep teal, darker to the rim, a soft highlight top left and a small glint
	float r = length(p);
	vec3 g = glass * mix(1.1, 0.6, smoothstep(0.3, 1.0, r));
	float sheen = smoothstep(0.32, 0.0, length((p - vec2(-0.34, 0.5)) * vec2(1.3, 2.4))) * 0.22;
	float glint = smoothstep(0.07, 0.0, length(p - vec2(-0.5, 0.56))) * 0.5;
	vec3 lit = mix(glow, core, hot * 0.5);
	ALBEDO = g + vec3(sheen + glint) * vec3(0.8, 1.0, 1.0) + glow * halo * 0.35 + lit * line * strength;
}
