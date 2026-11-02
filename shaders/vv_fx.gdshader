shader_type spatial;
// Vireo's and Venator's own effects (scripts/arch/kits/vv_fx.gd), one shader with a mode per look.
// `life` runs 0 -> 1 over the effect; `color` is the body, `color2` the hot core / accent.
//   0 ARC     a ribbon along UV.x (0 head, 1 tail): a jagged lightning core that re-strikes, a soft halo
//   1 PILLAR  an open column (UV.y foot 0 -> top 1): bright rim, climbing bands, narrows with life
//   2 RING    a flat quad: an expanding ring with radial spark needles (arrival bursts, shock rings)
//   3 DISC    a flat quad: a dark disc with a crackling rim (a scorch, the placed drag disc)
//   4 STAR    a camera-facing 4-point crackle (fingertip, muzzle, sky-bolt foot)
//   5 TRACER  a ribbon: a hot needle head and a tail that thins and cools (the rifle rounds)
//   6 FAN     a flat sector (UV.x across the sector, UV.y from the apex 0 to the rim 1): a blast front
//   7 SWIRL   a flat quad: spinning comma arcs (the Dazed mark)
render_mode unshaded, shadows_disabled, depth_draw_never, blend_add, cull_disabled, fog_disabled;
uniform int mode = 0;
uniform vec4 color : source_color = vec4(0.4, 0.9, 0.8, 1.0);
uniform vec4 color2 : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float life = 0.0;
uniform float seed = 0.0;
uniform float strength = 1.0;
uniform bool billboard = false;

float hash(float x) { return fract(sin(x * 127.1 + seed * 311.7) * 43758.5453); }
float vnoise(float x) {
	float i = floor(x); float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void vertex() {
	if (billboard) {
		float s = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 uv = UV;
	float k = clamp(1.0 - life, 0.0, 1.0);
	vec3 c = vec3(0.0);
	float a = 0.0;
	if (mode == 0) {
		// jagged: the core's offset across the ribbon jumps every 1/18 s, with two octaves of zigzag
		float t = floor(TIME * 18.0);
		float zig = (vnoise(uv.x * 7.0 + t * 3.1) - 0.5) * 0.55 + (vnoise(uv.x * 23.0 + t * 7.7) - 0.5) * 0.25;
		float d = abs(uv.y - 0.5 - zig * (0.3 + 0.7 * smoothstep(0.0, 0.25, uv.x)));
		float core = 1.0 - smoothstep(0.02, 0.07, d);
		float halo = (1.0 - smoothstep(0.05, 0.5, d)) * 0.45;
		float tail = 1.0 - smoothstep(0.55, 1.0, uv.x);
		c = color2.rgb * core * 1.6 + color.rgb * halo;
		a = (core + halo) * tail;
	} else if (mode == 1) {
		float rim = pow(1.0 - abs(uv.x * 2.0 - 1.0), 0.6);
		float bands = 0.65 + 0.35 * sin(uv.y * 26.0 - TIME * 14.0);
		float ends = smoothstep(0.0, 0.08, uv.y) * (1.0 - smoothstep(0.75, 1.0, uv.y));
		c = mix(color.rgb, color2.rgb, smoothstep(0.6, 1.0, rim)) * bands;
		a = ends * (0.35 + 0.65 * rim);
	} else if (mode == 2) {
		vec2 p = uv * 2.0 - 1.0;
		float r = length(p);
		float ang = atan(p.y, p.x);
		float front = 0.25 + 0.75 * sqrt(life);
		float ring = 1.0 - smoothstep(0.0, 0.06, abs(r - front));
		float needles = pow(abs(cos(ang * 6.0 + seed)), 40.0) * smoothstep(front * 0.4, front, r) * (1.0 - smoothstep(front, front + 0.18, r));
		c = color.rgb * ring + color2.rgb * needles * 1.4;
		a = (ring + needles) * k;
	} else if (mode == 3) {
		vec2 p = uv * 2.0 - 1.0;
		float r = length(p);
		float ang = atan(p.y, p.x);
		float crackle = vnoise(ang * 9.0 + floor(TIME * 14.0) * 2.3);
		float rim = 1.0 - smoothstep(0.0, 0.05 + 0.05 * crackle, abs(r - 0.92));
		float body = (1.0 - smoothstep(0.85, 0.95, r)) * 0.22;
		c = color.rgb * body + color2.rgb * rim * (0.8 + crackle);
		a = (body + rim) * k * (1.0 - smoothstep(0.98, 1.0, r));
	} else if (mode == 4) {
		vec2 p = uv * 2.0 - 1.0;
		float r = length(p);
		float ang = atan(p.y, p.x) + seed;
		float star = pow(abs(cos(ang * 2.0)), 24.0) * (1.0 - smoothstep(0.05, 1.0, r));
		float core = 1.0 - smoothstep(0.0, 0.25, r);
		float flick = 0.7 + 0.3 * hash(floor(TIME * 30.0));
		c = color.rgb * star * 1.3 * flick + color2.rgb * core;
		a = (star + core) * k;
	} else if (mode == 5) {
		float d = abs(uv.y - 0.5) * 2.0;
		float w = mix(0.9, 0.08, uv.x);
		float body = 1.0 - smoothstep(w * 0.5, w, d);
		float head = (1.0 - smoothstep(0.0, 0.12, uv.x)) * (1.0 - smoothstep(0.0, 0.8, d));
		c = mix(color2.rgb, color.rgb, smoothstep(0.0, 0.4, uv.x)) * body + color2.rgb * head;
		a = (body * (1.0 - uv.x) + head);
	} else if (mode == 6) {
		float front = 0.15 + 0.85 * sqrt(life);
		float band = 1.0 - smoothstep(0.0, 0.12, abs(uv.y - front));
		float fill = (1.0 - smoothstep(front - 0.02, front, uv.y)) * 0.35 * k;
		float spikes = pow(abs(sin(uv.x * 31.4 + seed)), 12.0) * smoothstep(front * 0.5, front, uv.y) * (1.0 - smoothstep(front, front + 0.1, uv.y));
		float edge = 1.0 - smoothstep(0.0, 0.04, min(uv.x, 1.0 - uv.x));
		c = color.rgb * (band + fill + edge * 0.5) + color2.rgb * spikes * 1.5;
		a = (band + fill + spikes + edge * 0.5 * (1.0 - smoothstep(front, front + 0.02, uv.y))) * k;
	} else {
		vec2 p = uv * 2.0 - 1.0;
		float r = length(p);
		float ang = atan(p.y, p.x) - TIME * 5.0;
		float arms = smoothstep(0.55, 1.0, sin(ang * 3.0 + r * 6.0));
		float band = smoothstep(0.35, 0.55, r) * (1.0 - smoothstep(0.8, 1.0, r));
		c = mix(color.rgb, color2.rgb, arms);
		a = arms * band;
	}
	ALBEDO = c * strength;
	ALPHA = clamp(a * color.a * strength, 0.0, 1.0);
}
