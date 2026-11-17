shader_type spatial;
render_mode unshaded, cull_back;
// A Hunter's face on a screen of glass (Breaker's porthole): glowing shapes drawn from 2D distances, so it holds at any
// zoom and needs no textures. The look is his live v95 master's (Meshy i1, owner promotion 11-12): two pale-cyan eyes,
// rounded below and cut by a lid that slants down to the middle, no mouth, on near-black glass with a soft highlight top
// left. Moods: 0 calm (the master's own scowl), 1 happy, 2 angry, 3 determined, 4 sad; `from` fades into `to` by `k`.
uniform int from_mood = 0;
uniform int to_mood = 0;
uniform float k = 1.0;
uniform float blink = 0.0;        // 0..1: the eyes shut to a line
uniform vec3 glow = vec3(0.42, 0.9, 1.0);
uniform vec3 core = vec3(0.85, 1.0, 1.0);
uniform vec3 glass = vec3(0.045, 0.05, 0.058);
uniform float strength = 1.6;
// past the glass's edge (r > 1: the screen's triangles that reach onto the porthole ring): the ring's copper, so the
// glass reads round whatever the low mesh's triangle edges do
uniform vec3 rim_col : source_color = vec3(0.45, 0.26, 0.21);

// a half-moon: a disc of radius r at c, its underside bitten by a wider disc whose top sits dip*r under c (dip 0..1)
float moon(vec2 p, vec2 c, float r, float dip) {
	p.y = c.y + (p.y - c.y) / max(1.0 - blink, 0.06);
	float d = length(p - c) - r;
	return max(d, r * 1.2 - length(p - c + vec2(0.0, r * (dip + 1.2))));
}

// an eye: an ellipse (half sizes w, h) at c, shut toward a line by blink
float eye(vec2 p, vec2 c, float w, float h) {
	vec2 q = (p - c) / vec2(w, h * max(1.0 - blink, 0.06));
	return (length(q) - 1.0) * min(w, h);
}

// a lid: the eye is cut above a line through (x0, y0) of slope `fall` (> 0 falls toward the middle)
float lid(vec2 q, float x0, float y0, float fall) {
	return q.y - y0 - fall * (q.x - x0);
}

float face(vec2 p, int m) {
	vec2 q = vec2(abs(p.x), p.y);   // the eyes mirror; q.x small is the inner corner
	float d = 9.0;
	if (m == 0) {          // calm: the master's eyes, a lid falling gently to the middle
		d = max(eye(q, vec2(0.43, -0.02), 0.31, 0.22), lid(q, 0.7, 0.15, 0.42));
	} else if (m == 1) {   // happy: the eyes lift into round half-moons, no lid
		d = moon(q, vec2(0.43, 0.02), 0.27, 0.25);
	} else if (m == 2) {   // angry: a steeper lid, the eyes narrower
		d = max(eye(q, vec2(0.43, -0.04), 0.31, 0.2), lid(q, 0.7, 0.13, 0.8));
	} else if (m == 3) {   // determined: a level lid
		d = max(eye(q, vec2(0.43, -0.02), 0.31, 0.22), lid(q, 0.0, 0.07, 0.0));
	} else {               // sad: the lid falls to the outside
		d = max(eye(q, vec2(0.43, -0.05), 0.29, 0.2), lid(q, 0.3, 0.1, -0.45));
	}
	return d;
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(2.0, -2.0);
	float d = mix(face(p, from_mood), face(p, to_mood), k);
	float line = smoothstep(0.015, -0.015, d);
	float hot = smoothstep(-0.02, -0.12, d);        // the pale core inside the shapes
	float halo = exp(-max(d, 0.0) * 9.0);
	// the glass: near-black, darker to the rim, a soft highlight top left and a small glint
	float r = length(p);
	vec3 g = glass * mix(1.1, 0.6, smoothstep(0.3, 1.0, r));
	float sheen = smoothstep(0.3, 0.0, length((p - vec2(-0.3, 0.6)) * vec2(1.2, 2.6))) * 0.3;
	float glint = smoothstep(0.06, 0.0, length(p - vec2(-0.48, 0.62))) * 0.35;
	vec3 lit = mix(glow, core, hot * 0.5);
	vec3 col = g + vec3(sheen + glint) * vec3(0.8, 1.0, 1.0) + glow * halo * 0.35 + lit * line * strength;
	float bezel = smoothstep(0.9, 0.97, r) * (1.0 - smoothstep(0.97, 1.0, r));   // a dark seat round the glass
	ALBEDO = mix(col * (1.0 - 0.7 * bezel), rim_col, smoothstep(0.985, 1.01, r));
}
