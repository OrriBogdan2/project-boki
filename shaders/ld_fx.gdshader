shader_type spatial;
// Linwick's and Dredge's own effect looks (scripts/arch/kits/ld_fx.gd), one shader, a mode each.
// life runs 0 -> 1 over an effect; everything is additive and unshaded. Flat looks lie on a PlaneMesh
// (XZ, UV 0..1); camera-facing looks set `billboard`.
//   0 flame    a hose puff (life = its age 0..1, seed): white-hot core early, then
//              yellow, orange, and a sooty violet fringe as it dies
//   1 orb      a radial glow: a hot core (color2) inside a halo (color) - the Cinder Shot, the pilot flame
//   2 comet    a streak along UV.x (0 = head), soft across UV.y, with a smoke tail (color2)
//   3 crescent a blade arc swept by `progress`: UV.x along the sweep, UV.y from the edge inward
//   4 sunburst a spiky radial burst that throws its spikes out over life (the Furnace Cloak, the barge)
//   5 lava     a molten strip: UV.x along, UV.y across; churning yellow-orange core, dark violet edges
//   6 scorch   a cracked, glowing scorch disc that cools from orange to soot
//   7 swirl    a ring of flame streaks rotating round the centre (Linwick's shield)
//   8 links    a ring of chain links (Dredge Grounded while he reels)
//   9 flame icon  a small teardrop flame (the burn pips over a foe)
//  10 spiral   a stun spiral (Anchor Drop victims)
//  11 wave     a thin ring that opens over life (the Anchor's landing ring, Fire Bolt's fizzle)
//  12 dot      a soft round dot (a slug hanging at its stop line)
render_mode unshaded, shadows_disabled, depth_draw_never, blend_add, cull_disabled, fog_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform vec4 color2 : source_color = vec4(1.0, 1.0, 0.8, 1.0);
uniform float life = 0.0;
uniform float progress = 1.0;
uniform int mode = 0;
uniform float seed = 0.0;
uniform float strength = 1.0;
uniform bool billboard = false;
#include "res://shaders/noise.gdshaderinc"

void vertex() {
	if (billboard) {
		float s = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	}
}

vec3 fire_ramp(float t) {
	// 0 white-hot, 0.25 yellow, 0.55 orange, 0.85 deep red-violet
	vec3 a = vec3(1.0, 0.97, 0.85);
	vec3 b = vec3(1.0, 0.82, 0.25);
	vec3 c = vec3(1.0, 0.42, 0.1);
	vec3 d = vec3(0.45, 0.08, 0.22);
	if (t < 0.25) return mix(a, b, t / 0.25);
	if (t < 0.55) return mix(b, c, (t - 0.25) / 0.3);
	return mix(c, d, clamp((t - 0.55) / 0.3, 0.0, 1.0));
}

void fragment() {
	float k = 1.0 - life;
	vec3 c = vec3(0.0);
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv);
	if (mode == 0) {
		float age = life;
		float sd = seed * 3.1;
		float n = fbm3(uv * 2.2 + vec2(sd, -TIME * 3.0 - sd));
		float edge = 0.62 + 0.3 * n;
		float body = 1.0 - smoothstep(edge * 0.35, edge, d);
		float core = (1.0 - smoothstep(0.0, 0.45, d)) * (1.0 - smoothstep(0.1, 0.5, age));
		c = fire_ramp(0.15 + age * 0.85 + n * 0.15) * body * (1.0 - smoothstep(0.6, 1.0, age)) * 0.42 + vec3(1.0, 0.9, 0.6) * core * 0.25;
	} else if (mode == 1) {
		float core = 1.0 - smoothstep(0.0, 0.32, d);
		float halo = (1.0 - smoothstep(0.2, 1.0, d));
		float fl = 0.8 + 0.2 * vnoise(vec2(atan(uv.y, uv.x) * 3.0 + seed, TIME * 9.0));
		c = color.rgb * halo * halo * fl * 0.9 + color2.rgb * core * 1.3;
		c *= k;
	} else if (mode == 2) {
		float along = UV.x;
		float across = 1.0 - abs(UV.y * 2.0 - 1.0);
		float body = (1.0 - along) * smoothstep(0.0, 0.7, across);
		float flick = 0.7 + 0.3 * vnoise(vec2(along * 7.0 - TIME * 16.0, UV.y * 5.0 + seed));
		float smoke = smoothstep(0.3, 1.0, along) * (1.0 - along) * smoothstep(0.0, 0.9, across) * vnoise(vec2(along * 4.0 - TIME * 5.0, UV.y * 3.0));
		c = color.rgb * body * body * flick * 1.2 + color2.rgb * smoke * 0.8;
		c *= k;
	} else if (mode == 3) {
		float head = progress * 1.3;
		float behind = head - UV.x;
		if (behind < 0.0) { discard; }
		float trail = 1.0 - smoothstep(0.0, 0.8, behind);
		float edge = 1.0 - smoothstep(0.0, 0.18, UV.y);
		float inner = (1.0 - smoothstep(0.1, 1.0, UV.y)) * (1.0 - edge);
		float n = 0.6 + 0.4 * vnoise(vec2(UV.x * 6.0 - progress * 7.0, UV.y * 8.0 + seed));
		c = (color.rgb * edge * 1.6 + color2.rgb * inner * n) * trail;
		c *= 1.0 - smoothstep(0.6, 1.0, life);
	} else if (mode == 4) {
		float a = atan(uv.y, uv.x) + seed;
		float spikes = pow(abs(sin(a * 7.0)), 6.0) * 0.7 + pow(abs(sin(a * 11.0 + 1.3)), 10.0) * 0.5;
		float reach = 0.35 + 0.65 * smoothstep(0.0, 0.35, life);
		float ray = spikes * (1.0 - smoothstep(0.0, reach, d)) * smoothstep(0.05, 0.2, d);
		float disc = (1.0 - smoothstep(0.0, reach * 0.55, d));
		c = (color.rgb * (ray * 1.4 + disc * 0.7) + color2.rgb * disc * disc * 0.9) * (1.0 - smoothstep(0.45, 1.0, life));
	} else if (mode == 5) {
		float across = abs(UV.y * 2.0 - 1.0);
		float n = fbm3(vec2(UV.x * progress * 1.2 - TIME * 0.35, UV.y * 2.5 + TIME * 0.2 + seed));
		float n2 = vnoise(vec2(UV.x * progress * 3.0 + TIME * 0.8, UV.y * 6.0));
		float core = (1.0 - smoothstep(0.15, 0.7, across + n * 0.25));
		float rim = smoothstep(0.55, 0.85, across + n * 0.2) * (1.0 - smoothstep(0.85, 1.0, across));
		vec3 molten = mix(vec3(1.0, 0.45, 0.08), vec3(1.0, 0.85, 0.3), smoothstep(0.45, 0.8, n2));
		float ends = smoothstep(0.0, 0.04, UV.x) * (1.0 - smoothstep(0.96, 1.0, UV.x));
		c = (molten * core * (0.7 + 0.3 * n2) + vec3(0.3, 0.06, 0.32) * rim) * ends;
		c *= 1.0 - smoothstep(0.75, 1.0, life);
	} else if (mode == 6) {
		float n = vnoise(uv * 5.0 + seed);
		float crack = 1.0 - smoothstep(0.0, 0.08, abs(fract(atan(uv.y, uv.x) * 1.4 + n * 0.6) - 0.5) * (0.4 + d));
		float disc = 1.0 - smoothstep(0.55, 1.0, d + n * 0.2);
		vec3 hot = mix(color.rgb, color2.rgb, smoothstep(0.0, 0.7, life));
		c = (hot * crack * disc * 1.2 + color.rgb * disc * 0.18) * (1.0 - smoothstep(0.6, 1.0, life));
	} else if (mode == 7) {
		float a = atan(uv.y, uv.x);
		float ring = 1.0 - smoothstep(0.0, 0.16, abs(d - 0.8));
		float streak = pow(fract(a / 6.2832 * 5.0 + TIME * 1.6 + seed), 3.0);
		float n = vnoise(vec2(a * 4.0 - TIME * 6.0, d * 6.0));
		c = (color.rgb * ring * (0.4 + 1.1 * streak) + color2.rgb * ring * streak * n) * strength;
	} else if (mode == 8) {
		float a = atan(uv.y, uv.x) / 6.2832 + 0.5;
		float ring = 1.0 - smoothstep(0.0, 0.1, abs(d - 0.82));
		float link = fract(a * 14.0 + seed);
		float lit = smoothstep(0.08, 0.2, link) * (1.0 - smoothstep(0.42, 0.55, link));
		c = (color.rgb * lit + color2.rgb * (1.0 - lit) * 0.35) * ring * strength;
	} else if (mode == 9) {
		vec2 p = vec2(uv.x, uv.y + 0.25);
		float w = 0.55 * (1.0 - smoothstep(-0.9, 0.9, -p.y)) + 0.05;
		float wob = sin(p.y * 6.0 + TIME * 14.0 + seed) * 0.08;
		float body = 1.0 - smoothstep(w * 0.6, w, abs(p.x + wob * (0.5 - p.y)));
		body *= smoothstep(-0.95, -0.6, -p.y) * (1.0 - smoothstep(0.55, 0.75, p.y));
		float core = body * (1.0 - smoothstep(0.0, 0.35, length(p - vec2(0.0, 0.25))));
		c = (color.rgb * body + color2.rgb * core) * strength;
	} else if (mode == 10) {
		float a = atan(uv.y, uv.x);
		float sp = fract((a / 6.2832) * 2.0 - d * 2.2 + TIME * 2.5);
		float arm = (1.0 - smoothstep(0.0, 0.12, abs(sp - 0.5))) * (1.0 - smoothstep(0.7, 1.0, d)) * smoothstep(0.08, 0.2, d);
		c = (color.rgb * arm + color2.rgb * arm * (1.0 - d)) * strength;
	} else if (mode == 11) {
		float r = 0.2 + 0.78 * smoothstep(0.0, 0.6, life);
		float ring = 1.0 - smoothstep(0.0, 0.06 + 0.06 * k, abs(d - r));
		float fill = (1.0 - smoothstep(0.0, r, d)) * 0.15 * k;
		c = (color.rgb * ring * 1.3 + color2.rgb * fill) * k;
	} else {
		float dot_ = 1.0 - smoothstep(0.0, 1.0, d);
		c = (color.rgb * dot_ * dot_ + color2.rgb * (1.0 - smoothstep(0.0, 0.3, d))) * k;
	}
	ALBEDO = c * color.a;
	ALPHA = 1.0;
}
