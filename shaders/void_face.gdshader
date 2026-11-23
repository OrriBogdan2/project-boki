shader_type spatial;
// The Empty's head (Unmasked): void all the way round, a dim starfield seen with real parallax and a lit edge
// so it reads against any ground. A socket shaped for a Mask floats on the face: inside it the stars are deep
// and bright with a glowing rim, and faint ghost outlines of the missing features float in the dark; outside it
// the glow spills softly onto the void. Shell of the head, centred on 0, front -Z.
render_mode unshaded, shadows_disabled, cull_back, depth_draw_opaque, blend_mix;

uniform int shape = 0;                 // 0 oval, 1 mask, 2 torn, 3 crescent
uniform int ghost = 1;                 // 0 none, 1 eyes, 2 full face, 3 stitched
uniform vec2 extent = vec2(0.85, 0.9); // rad round the head: the shape's half size
uniform float lift = 0.08;             // rad: the face sits this far below the head's middle
uniform vec4 glow : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform vec4 deep : source_color = vec4(0.02, 0.015, 0.05, 1.0);
uniform float depth = 0.35;            // how far back the stars sit (parallax)
uniform float stars = 1.0;             // star density
uniform float halo = 0.16;             // shape units the glow spills onto the void round the socket

varying vec3 obj_pos;
varying vec3 obj_eye;
varying vec3 obj_normal;

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
	obj_eye = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ellipse(vec2 p, vec2 r) {
	return (length(p / r) - 1.0) * min(r.x, r.y);
}

float sdf_shape(vec2 p) {
	if (shape == 1) {
		// a mask: broad at the brow with a notch, narrowing to a soft point at the chin
		vec2 q = p;
		q.x *= 1.0 + 0.32 * smoothstep(0.1, -0.9, q.y);
		float d = ellipse(q - vec2(0.0, 0.02), vec2(0.82, 0.92));
		d = max(d, -(ellipse(p - vec2(0.0, 1.02), vec2(0.16, 0.2))));
		return d;
	}
	if (shape == 2) {
		// torn: an oval whose edge is ragged, as if the face were ripped away
		float a = atan(p.y, p.x);
		float rag = 0.06 * sin(a * 7.0 + 1.3) + 0.045 * sin(a * 13.0 - 0.4) + 0.03 * sin(a * 23.0 + 2.0);
		return ellipse(p, vec2(0.78, 0.9)) - rag;
	}
	if (shape == 3) {
		// a crescent: the hollow eats the face from one side, the rest is left blank
		float outer = ellipse(p, vec2(0.8, 0.94));
		float bite = ellipse(p - vec2(0.48, 0.12), vec2(0.62, 0.78));
		return max(outer, -bite);
	}
	return ellipse(p, vec2(0.78, 0.92));
}

// A soft glowing line from a to b (distance in shape units).
float seg(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return exp(-pow(length(pa - ba * h) / w, 2.0));
}

float ring(vec2 p, vec2 c, vec2 r, float w) {
	return exp(-pow(abs(length((p - c) / r) - 1.0) * min(r.x, r.y) / w, 2.0));
}

float ghosts(vec2 p) {
	if (ghost == 0) {
		return 0.0;
	}
	float g = 0.0;
	for (int i = 0; i < 2; i++) {
		float sx = i == 0 ? -1.0 : 1.0;
		vec2 eye = vec2(0.33 * sx, 0.14);
		// almond eye outlines
		g += ring(p, eye, vec2(0.2, 0.09), 0.018);
		if (ghost >= 2) {
			g += 0.8 * seg(p, eye + vec2(-0.2 * sx, 0.2), eye + vec2(0.18 * sx, 0.24), 0.016);
		}
	}
	if (ghost >= 2) {
		g += 0.7 * seg(p, vec2(0.0, 0.08), vec2(0.03, -0.24), 0.016);
		g += 0.7 * seg(p, vec2(-0.07, -0.26), vec2(0.07, -0.26), 0.016);
		g += 0.7 * seg(p, vec2(-0.2, -0.46), vec2(0.2, -0.46), 0.016);
	}
	if (ghost == 3) {
		// stitched: dashed seams where the features were sewn shut
		for (int i = 0; i < 2; i++) {
			float sx = i == 0 ? -1.0 : 1.0;
			float d = seg(p, vec2(0.33 * sx - 0.2, 0.14), vec2(0.33 * sx + 0.2, 0.14), 0.016);
			g += d * step(0.5, fract(p.x * 9.0));
			for (int k = -2; k <= 2; k++) {
				vec2 c = vec2(0.33 * sx + float(k) * 0.08, 0.14);
				g += 0.8 * seg(p, c + vec2(0.0, -0.05), c + vec2(0.0, 0.05), 0.012);
			}
		}
		g += seg(p, vec2(-0.22, -0.36), vec2(0.22, -0.36), 0.016) * step(0.5, fract(p.x * 9.0));
	}
	return g;
}

// One layer of stars at this parallax depth.
float star_layer(vec2 p, float cell, float seed) {
	vec2 c = floor(p * cell);
	vec2 f = fract(p * cell) - 0.5;
	float h = hash(c + seed);
	if (h > 0.35 * stars) {
		return 0.0;
	}
	vec2 off = vec2(hash(c + seed + 3.1), hash(c + seed + 7.7)) - 0.5;
	float r = length(f - off * 0.6);
	float tw = 0.6 + 0.4 * sin(TIME * (1.0 + h * 5.0) + h * 40.0);
	return smoothstep(0.12, 0.0, r) * tw;
}

vec2 face_uv(vec3 v) {
	vec3 n = normalize(v);
	return vec2(atan(n.x, -n.z), asin(clamp(n.y, -1.0, 1.0)) + lift) / extent;
}

void fragment() {
	vec2 p = face_uv(obj_pos);
	float d = sdf_shape(p);
	// looking into the hole: the eye ray, in the face's own frame, carries the far layers sideways
	vec3 to_eye = normalize(obj_eye - obj_pos);
	vec2 par = to_eye.xy / max(-to_eye.z, 0.25);
	par = clamp(par, vec2(-2.0), vec2(2.0)) / extent.x;      // (seen from behind the parallax would run wild)
	float s = star_layer(p + par * depth * 0.6, 7.0, 1.0) * 0.9;
	s += star_layer(p + par * depth * 1.2, 11.0, 5.0) * 0.6;
	s += star_layer(p + par * depth * 2.0, 17.0, 9.0) * 0.4;
	vec3 stars_col = mix(vec3(1.0), glow.rgb, 0.35) * s;
	vec3 col;
	if (d > 0.0) {
		float edge = pow(1.0 - clamp(dot(normalize(obj_normal), normalize(obj_eye - obj_pos)), 0.0, 1.0), 3.0);
		float k = clamp(1.0 - d / halo, 0.0, 1.0);
		col = deep.rgb + stars_col * 0.7 + glow.rgb * edge * 0.55;
		col = mix(col, glow.rgb * 1.4, k * k * 0.55);
	} else {
		float inner = clamp(-d / 0.32, 0.0, 1.0);
		col = mix(glow.rgb * 0.35, deep.rgb, smoothstep(0.0, 1.0, inner));
		// a faint nebula far back
		vec2 pn = p + par * depth * 1.6;
		float neb = 0.5 + 0.5 * sin(pn.x * 3.1 + sin(pn.y * 2.3 + TIME * 0.15) * 1.7);
		col += glow.rgb * 0.08 * neb * inner;
		col += stars_col * inner;
		// ghost features hang a little way back
		col += glow.rgb * 0.55 * ghosts(p + par * depth * 0.3);
	}
	// the bright lip of the socket
	float rim = exp(-pow(d / 0.03, 2.0));
	col = mix(col, glow.rgb * 1.8 + vec3(0.2), rim * 0.85);
	ALBEDO = col;
}
