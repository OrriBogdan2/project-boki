// The Hero VFX surface looks (scripts/match/hero_vfx.gd), one shader, a mode per look. Premultiplied: rgb is what
// glows on top and alpha is how much of the ground it covers, so hot edges add light while char and smoke stay
// dark on bright ground. Every look burns away through noise instead of fading flat.
shader_type spatial;
render_mode blend_premul_alpha, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/noise.gdshaderinc"

const int M_SWEEP = 0;      // an arc of flame: UV.x along the swing, UV.y outer edge (0) to inner (1)
const int M_SCORCH = 1;     // the ground burning: UV across the quad
const int M_SKIRT = 2;      // a wall of flame: UV.x round it, UV.y foot (0) to top (1)
const int M_FLARE = 3;      // a ragged burst, facing the camera
const int M_RIBBON = 4;     // a mesh trail: UV.x head (0) to tail (1), UV.y across
const int M_THREAD = 5;     // a loose thread lying on the ground: UV.y from where it is tied (0) to its end (1)

uniform int mode = 0;
uniform vec4 col : source_color = vec4(1.0, 0.5, 0.1, 1.0);    // the body of the look
uniform vec4 col2 : source_color = vec4(1.0, 0.85, 0.3, 1.0);  // its hot part
uniform vec4 col3 : source_color = vec4(0.16, 0.05, 0.02, 1.0);  // char, what is left as it burns out
uniform float life = 0.0;   // 0..1 through the look
uniform float seed = 0.0;
uniform float gain = 1.0;   // the viewer's share of it (HeroVfx.view_k: allies' effects sit dimmer)
uniform int shape = 0;      // M_SCORCH: 0 disc, 1 lane, 2 cone
uniform float arc = 1.0;    // M_SCORCH cone: half angle (rad). M_SKIRT: the share of the circle it covers
uniform float aspect = 1.0; // M_SCORCH lane: length / width, so the fissures keep their size
uniform bool billboard = false;
uniform bool stitch = false;  // M_SCORCH lane: a seam of cross-stitches instead of fire

void vertex() {
	if (billboard) {
		float s = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	}
}

// the distance to the nearest cell wall: dark at the walls of a broken-plate pattern
float cracks(vec2 p) {
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(h21(ip + g), h21(ip + g + 17.3));
			float d = length(g + o - fp);
			if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
		}
	}
	return f2 - f1;
}

// Fire by heat, 0..1: char, the body colour, the hot colour, nearly white. Everything hot is drawn with high
// coverage, so it keeps its colour on bright ground instead of washing out to white.
vec3 ramp(float h) {
	h = clamp(h, 0.0, 1.0);
	if (h < 0.3) { return mix(col3.rgb, col.rgb, h / 0.3); }
	if (h < 0.72) { return mix(col.rgb, col2.rgb, (h - 0.3) / 0.42); }
	return mix(col2.rgb, vec3(1.0), (h - 0.72) / 0.28 * 0.5);
}

vec4 sweep(vec2 uv) {
	float head = min(life / 0.28, 1.0) * 1.25;
	float behind = head - uv.x;
	if (behind < 0.0) { return vec4(0.0); }
	// a thin blade of flame along the outer edge, tapered at both ends, tongues licking inward off it
	float thick = pow(sin(3.14159 * clamp(uv.x, 0.0, 1.0)), 0.8) * 0.46;
	float n = fbm3(vec2(uv.x * 9.0 - TIME * 5.0 + seed, uv.y * 4.0 + TIME * 3.0));
	float burn = smoothstep(0.2, 1.0, life);
	float body = thick - uv.y + (n - 0.42) * 0.55 - burn * 0.75;
	float a = smoothstep(0.0, 0.08, body);
	float depth = clamp(uv.y / max(thick, 0.05), 0.0, 1.0);    // 0 at the edge, 1 at the licking tips
	float lead = 1.0 - smoothstep(0.0, 0.12, behind);
	float heat = 0.9 - depth * 0.75 + (n - 0.5) * 0.5 - burn * 0.45 + lead * 0.4;
	return vec4(ramp(heat) * a, a * mix(0.95, 0.7, depth));
}

// A seam along a lane: a torn slit with a thread running through it and cross-stitches over it, drawn in as it goes.
vec4 seam(vec2 uv) {
	float along = uv.y * aspect * 1.5;
	float x = abs(uv.x - 0.5) * 2.0;
	float cell = fract(along) - 0.5;
	float cross_a = abs(x * 0.42 - abs(cell));
	float arm = (1.0 - smoothstep(0.0, 0.07, cross_a)) * (1.0 - smoothstep(0.62, 0.8, x));
	float slit = (1.0 - smoothstep(0.0, 0.12, x)) * 0.8;
	float front = smoothstep(0.0, 0.3, life) * 1.25;
	float lit = 1.0 - smoothstep(front - 0.1, front, uv.y);
	float n = fbm3(uv * vec2(3.0, 9.0) + seed);
	float gone = smoothstep(life * 1.3 - 0.3, life * 1.3, n + 0.15);
	float ends = smoothstep(0.0, 0.03, uv.y) * (1.0 - smoothstep(0.97, 1.0, uv.y));
	float a = max(arm, slit) * lit * gone * ends;
	vec3 c = mix(col3.rgb, col.rgb, arm);
	c = mix(c, col2.rgb, (1.0 - smoothstep(0.0, 0.02, cross_a)) * (1.0 - smoothstep(0.1, 0.4, life)));
	return vec4(c * a, a);
}

vec4 thread(vec2 uv) {
	float wander = sin(uv.y * 8.0 + seed) * 0.17 + sin(uv.y * 3.1 + seed * 1.7) * 0.13;
	float sway = sin(TIME * 2.2 + seed + uv.y * 5.0) * 0.03 * uv.y;
	float d = abs(uv.x - 0.5 - (wander + sway) * smoothstep(0.0, 0.5, uv.y));
	float line = 1.0 - smoothstep(0.03, 0.075, d);
	float fade = 1.0 - smoothstep(0.7, 1.0, life);
	float end = 1.0 - smoothstep(0.82 * (1.0 - life * 0.6), 1.0 * (1.0 - life * 0.6), uv.y);
	float a = line * fade * end;
	return vec4(mix(col.rgb, col2.rgb, line * 0.2) * a, a);
}

vec4 scorch(vec2 uv) {
	if (stitch) { return seam(uv); }
	vec2 p = uv * 2.0 - 1.0;
	float d = length(p);
	float mask = 1.0;
	float along = 0.0;
	vec2 q;
	if (shape == 1) {
		// a lane: straight sides, frayed ends; it catches from its start, UV.y along it
		along = uv.y;
		d = max(abs(p.x), pow(abs(p.y), 6.0));
		q = vec2(uv.x * 1.3, uv.y * 1.1 * aspect);
	} else {
		// fissures running outward: polar, stretched along the radius
		float ang = atan(p.x, p.y);
		q = vec2(ang * 1.9, d * 1.5 - seed);
		if (shape == 2) {
			mask = 1.0 - smoothstep(arc * 0.85, arc, abs(ang));
		}
	}
	float n = fbm3(p * 2.6 + seed);
	float front = smoothstep(0.0, 0.22, life) * 1.5;           // burns outward fast
	float reach = (1.0 - smoothstep(0.55, 1.0, d + (n - 0.5) * 0.5)) * (1.0 - smoothstep(0.86, 0.98, length(p * vec2(1.0, shape == 1 ? 0.0 : 1.0))));
	float lit = shape == 1 ? 1.0 - smoothstep(front - 0.2, front - 0.02, along + (n - 0.5) * 0.25) : 1.0 - smoothstep(front - 0.25, front, d);
	float fade = 1.0 - smoothstep(0.5, 1.0, life);
	float dissolve = smoothstep(life * 1.25 - 0.28, life * 1.25, n + 0.2);
	// only some walls of the broken plates are open: a few running fissures, not a net
	float open = smoothstep(0.42, 0.62, fbm3(p * 1.7 - seed));
	float width = 0.035 + 0.06 * open;
	float cr = (1.0 - smoothstep(0.0, width, cracks(q + (vec2(n) - 0.5) * 0.5 + vec2(seed, 0.0)))) * open;
	float cool = 1.0 - smoothstep(0.15, 0.8, life);
	float a_char = reach * lit * (0.06 + 0.14 * smoothstep(0.35, 0.7, n)) * dissolve * mask;
	float a_crack = cr * reach * lit * mask * (0.35 + 0.65 * fade) * dissolve;
	float flash = (1.0 - smoothstep(0.0, 0.24, life)) * reach * lit * mask * smoothstep(0.3, 0.62, n + (1.0 - d) * 0.25);
	vec3 c = ramp(0.2 + 0.5 * cool) * a_crack + ramp(0.3 + n * 0.35) * flash * (1.0 - a_crack) + col3.rgb * a_char;
	return vec4(c, clamp(a_char + a_crack + flash, 0.0, 1.0));
}

vec4 skirt(vec2 uv) {
	if (uv.x > arc) { return vec4(0.0); }
	float n = fbm3(vec2(uv.x * 22.0 + seed, uv.y * 2.5 - TIME * 3.2));
	float tall = 1.0 - smoothstep(0.1, 1.0, life);             // the wall sinks as it spends
	float tongue = n * 1.35 + tall * 0.75 - uv.y * 1.5 - smoothstep(0.45, 1.0, life) * 0.7;
	float a = smoothstep(0.0, 0.14, tongue);
	float heat = tongue * 1.1 + 0.15 - uv.y * 0.25;
	return vec4(ramp(heat) * a * 0.8, a * 0.8);
}

vec4 flare(vec2 uv) {
	vec2 p = uv * 2.0 - 1.0;
	float d = length(p);
	float ang = atan(p.y, p.x);
	// a ragged edge: uneven tongues, nothing regular
	float rag = fbm3(vec2(ang * 2.4 + seed, seed * 0.7)) * 0.75 + 0.35;
	float open = smoothstep(0.0, 0.2, life);
	float reach = rag * mix(0.35, 1.0, open) * (1.0 - life * 0.5);
	float body = 1.0 - smoothstep(reach * 0.45, reach, d);
	float core = 1.0 - smoothstep(0.0, reach * 0.55, d);
	float fade = 1.0 - smoothstep(0.35, 1.0, life);
	float holes = smoothstep(life - 0.1, life + 0.25, fbm3(p * 3.5 + seed) + 0.25);
	float a = clamp(body * holes * fade, 0.0, 1.0);
	return vec4(ramp(0.3 + core * 0.75) * a, a * 0.9);
}

vec4 ribbon(vec2 uv) {
	float across = 1.0 - abs(uv.y * 2.0 - 1.0);
	float n = fbm3(vec2(uv.x * 5.0 - TIME * 5.0 + seed, uv.y * 3.0));
	float body = across * 1.4 + (n - 0.5) * 0.9 - uv.x * 0.9;
	float a = smoothstep(0.08, 0.3, body);
	float heat = across * across * (1.0 - uv.x) * 0.95 + (n - 0.5) * 0.3;
	return vec4(ramp(heat) * a, a * mix(0.95, 0.35, uv.x));
}

void fragment() {
	vec4 v;
	if (mode == M_SWEEP) { v = sweep(UV); }
	else if (mode == M_SCORCH) { v = scorch(UV); }
	else if (mode == M_SKIRT) { v = skirt(UV); }
	else if (mode == M_FLARE) { v = flare(UV); }
	else if (mode == M_RIBBON) { v = ribbon(UV); }
	else { v = thread(UV); }
	ALBEDO = v.rgb * gain;
	ALPHA = v.a * gain;
}
