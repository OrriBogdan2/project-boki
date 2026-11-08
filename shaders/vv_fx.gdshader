shader_type spatial;
// Sparkle's and Vex's own effects (scripts/arch/kits/vv_fx.gd), one shader with a mode per look.
// `life` runs 0 -> 1 over the effect; `color` is the body, `color2` the hot core / accent, `color3` an
// optional edge colour (its alpha says how much). Each mode writes a BODY, alpha-blended so it keeps its
// colour and darkness on bright grass, and a GLOW added on top for the hot cores and sparks only.
//   0 ARC     a ribbon along UV.x (0 head, 1 tail): a jagged lightning core that re-strikes, a tinted halo
//   1 PILLAR  an open column (UV.y foot 0 -> top 1): bright rim, climbing bands, narrows with life
//   2 RING    a flat quad: an expanding ring with radial spark needles (arrival bursts, shock rings)
//   3 DISC    a flat quad: a dark filled disc, a jagged crackling rim and lightning veins (placed areas)
//   4 STAR    a camera-facing 4-point crackle (fingertip, muzzle, sky-bolt foot)
//   5 TRACER  a ribbon: a hot needle head and a tail that thins and cools (the rifle rounds)
//   6 FAN     a flat sector (UV.x across the sector, UV.y from the apex 0 to the rim 1): a blast front
//   7 SWIRL   a flat quad: spinning comma arcs (the Dazed mark)
//   8 BEAM    a ribbon: a hot core, a coloured body and a shimmering edge, thinning with life
render_mode unshaded, shadows_disabled, depth_draw_never, blend_premul_alpha, cull_disabled, fog_disabled;
uniform int mode = 0;
uniform vec4 color : source_color = vec4(0.4, 0.9, 0.8, 1.0);
uniform vec4 color2 : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform vec4 color3 : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float life = 0.0;
uniform float seed = 0.0;
uniform float strength = 1.0;
uniform bool billboard = false;

float hash(float x) { return fract(sin(x * 127.1 + seed * 311.7) * 43758.5453); }
float vnoise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void vertex() {
	if (billboard) {
		float s = length(MODEL_MATRIX[0].xyz);
		mat4 face = mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * face;
	}
}

void fragment() {
	vec2 uv = UV;
	float k = clamp(1.0 - life, 0.0, 1.0);
	vec3 body = color.rgb;
	float body_a = 0.0;
	vec3 glow = vec3(0.0);
	if (mode == 0) {
		// jagged: the core's offset across the ribbon jumps every 1/18 s, with two octaves of zigzag
		float t = floor(TIME * 18.0);
		float zig = (vnoise(uv.x * 7.0 + t * 3.1) - 0.5) * 0.55 + (vnoise(uv.x * 23.0 + t * 7.7) - 0.5) * 0.25;
		float d = abs(uv.y - 0.5 - zig * (0.3 + 0.7 * smoothstep(0.0, 0.25, uv.x)));
		float core = 1.0 - smoothstep(0.03, 0.09, d);
		float halo = 1.0 - smoothstep(0.06, 0.4, d);
		float tail = 1.0 - smoothstep(0.55, 1.0, uv.x);
		body_a = halo * 0.8 * tail;
		glow = color2.rgb * core * 1.4 * tail;
	} else if (mode == 1) {
		float rim = pow(1.0 - abs(uv.x * 2.0 - 1.0), 0.6);
		float bands = 0.65 + 0.35 * sin(uv.y * 26.0 - TIME * 14.0);
		float ends = smoothstep(0.0, 0.08, uv.y) * (1.0 - smoothstep(0.75, 1.0, uv.y));
		body_a = ends * (0.25 + 0.4 * rim) * bands;
		glow = color2.rgb * smoothstep(0.7, 1.0, rim) * ends * bands * 0.8;
	} else if (mode == 2) {
		vec2 p = uv * 2.0 - 1.0;
		float r = length(p);
		float ang = atan(p.y, p.x);
		float front = 0.25 + 0.75 * sqrt(life);
		float ring = 1.0 - smoothstep(0.0, 0.08, abs(r - front));
		float needles = pow(abs(cos(ang * 6.0 + seed)), 40.0) * smoothstep(front * 0.4, front, r);
		needles *= 1.0 - smoothstep(front, front + 0.18, r);
		body_a = ring * 0.9 * k;
		glow = color2.rgb * (needles * 1.4 + ring * 0.35) * k;
	} else if (mode == 3) {
		// a placed area: a dark fill, veins of lightning inside, and a jagged rim that crawls
		vec2 p = uv * 2.0 - 1.0;
		float r = length(p);
		float ang = atan(p.y, p.x);
		float tick = floor(TIME * 14.0);
		float crackle = vnoise(ang * 11.0 + tick * 2.3);
		float edge_r = 0.9 + (crackle - 0.5) * 0.08;
		float rim = 1.0 - smoothstep(0.0, 0.035 + 0.04 * crackle, abs(r - edge_r));
		float inside = 1.0 - smoothstep(edge_r - 0.02, edge_r, r);
		float spoke = fract((ang + vnoise(r * 6.0 + tick) * 0.5) * 6.0 / 6.2832);
		float veins = (1.0 - smoothstep(0.0, 0.05, abs(spoke - 0.5))) * inside * smoothstep(0.15, 0.6, r);
		veins *= step(0.45, vnoise(ang * 3.0 + tick * 0.7));
		body = mix(color.rgb, color3.rgb, rim * color3.a);
		body_a = max(inside * 0.7, rim) * k;
		glow = color2.rgb * (rim * (0.3 + 0.5 * crackle) + veins * 0.7) * k;
	} else if (mode == 4) {
		vec2 p = uv * 2.0 - 1.0;
		float r = length(p);
		float ang = atan(p.y, p.x) + seed;
		float star = pow(abs(cos(ang * 2.0)), 24.0) * (1.0 - smoothstep(0.05, 1.0, r));
		float core = 1.0 - smoothstep(0.0, 0.25, r);
		float flick = 0.7 + 0.3 * hash(floor(TIME * 30.0));
		body_a = clamp(star * 1.6 * flick, 0.0, 1.0) * k;
		glow = color2.rgb * core * k;
	} else if (mode == 5) {
		float d = abs(uv.y - 0.5) * 2.0;
		float w = mix(0.9, 0.08, uv.x);
		float shaft = 1.0 - smoothstep(w * 0.5, w, d);
		float head = (1.0 - smoothstep(0.0, 0.12, uv.x)) * (1.0 - smoothstep(0.0, 0.8, d));
		body_a = shaft * (1.0 - uv.x) * k;
		glow = color2.rgb * head * k;
	} else if (mode == 8) {
		// a hot core, a coloured body, and a shimmering edge band in color3
		float d = abs(uv.y - 0.5) * 2.0;
		float w = mix(1.0, 0.25, life);
		float shaft = 1.0 - smoothstep(w * 0.45, w, d);
		float core = 1.0 - smoothstep(0.0, 0.2 * w, d);
		float shimmer = 0.6 + 0.4 * sin(uv.x * 90.0 - TIME * 50.0);
		float edge = (1.0 - smoothstep(0.0, 0.12 * w, abs(d - w * 0.62))) * shimmer;
		body = mix(color.rgb, color3.rgb, edge * color3.a);
		body_a = clamp(shaft * 0.85 + edge * color3.a, 0.0, 1.0) * k;
		glow = color2.rgb * core * 1.4 * k;
	} else {
		vec2 p = uv * 2.0 - 1.0;
		float r = length(p);
		float ang = atan(p.y, p.x) - TIME * 5.0;
		float arms = smoothstep(0.55, 1.0, sin(ang * 3.0 + r * 6.0));
		float band = smoothstep(0.35, 0.55, r) * (1.0 - smoothstep(0.8, 1.0, r));
		body_a = arms * band;
		glow = color2.rgb * arms * band * 0.4;
	}
	// premultiplied: the body covers what is under it, the glow adds on top
	float a = clamp(body_a * color.a * strength, 0.0, 1.0);
	ALBEDO = body * a + glow * color.a * strength;
	ALPHA = a;
}
