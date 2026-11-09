shader_type spatial;
render_mode unshaded, cull_back;
// A Hunter's face on a screen of glass (Breaker's porthole): glowing shapes drawn from 2D distances, so it holds at any
// zoom and needs no textures. Moods: 0 calm dots, 1 happy, 2 angry, 3 determined, 4 sad; `from` fades into `to` by `k`.
uniform int from_mood = 0;
uniform int to_mood = 0;
uniform float k = 1.0;
uniform float blink = 0.0;        // 0..1: the eyes shut to a line
uniform vec3 glow = vec3(0.45, 1.0, 0.95);
uniform vec3 glass = vec3(0.07, 0.2, 0.22);
uniform float strength = 1.8;

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

float arc(vec2 p, vec2 c, float r, float a0, float a1) {
	vec2 q = p - c;
	float a = atan(q.x, q.y);
	float d = abs(length(q) - r);
	if (a < a0 || a > a1) {
		vec2 e0 = c + r * vec2(sin(a0), cos(a0));
		vec2 e1 = c + r * vec2(sin(a1), cos(a1));
		d = min(length(p - e0), length(p - e1));
	}
	return d;
}

float face(vec2 p, int m) {
	vec2 q = vec2(abs(p.x), p.y);
	float d = 9.0;
	if (m == 0) {
		d = length((q - vec2(0.3, 0.02)) * vec2(1.0, 1.0 / max(1.0 - blink, 0.08))) - 0.2;
	} else if (m == 1) {
		float sm = length((p - vec2(0.0, -0.3)) * vec2(1.0, 1.7)) - 0.34;
		d = min(arc(q, vec2(0.38, -0.02), 0.2, -1.3, 1.3) - 0.055, max(sm, p.y + 0.2));
	} else if (m == 2) {
		float tri = max(seg(q, vec2(0.14, 0.02), vec2(0.6, 0.3)) - 0.075, q.y - 0.62 * (q.x - 0.14) - 0.06);
		d = min(tri, arc(p, vec2(0.0, -0.62), 0.3, -0.75, 0.75) - 0.04);
	} else if (m == 3) {
		d = seg(q, vec2(0.16, 0.05), vec2(0.62, 0.05)) - 0.05;
	} else {
		d = seg(q, vec2(0.14, 0.2), vec2(0.58, 0.02)) - 0.06;
		d = min(d, length((q - vec2(0.4, 0.0)) * vec2(1.0, 1.6)) - 0.12);
		d = min(d, arc(p, vec2(0.0, -0.62), 0.3, -0.75, 0.75) - 0.04);
	}
	return d;
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(2.0, -2.0);
	float d = mix(face(p, from_mood), face(p, to_mood), k);
	float line = smoothstep(0.02, -0.02, d);
	float halo = exp(-max(d, 0.0) * 7.0) * 0.6;
	// the glass: dark, a soft highlight top left
	float sheen = smoothstep(0.34, 0.0, length((p - vec2(-0.32, 0.5)) * vec2(1.0, 2.2))) * 0.18;
	ALBEDO = glass + vec3(sheen) + glow * (line * strength + halo * 0.6);
}
