// Cinder's and Dredge's effect looks (scripts/arch/kits/ld_fx.gd), a mode each. Every look has two parts:
// a body drawn alpha-blended (ld_fx.gdshader), so its colour and its dark rims and smoke read on bright
// grass instead of washing out to beige, and a glow drawn additively on top (ld_fx_glow.gdshader) for the
// hot cores only. life runs 0 -> 1 over an effect. Flat looks lie on a PlaneMesh (XZ, UV 0..1);
// camera-facing looks set `billboard`.
//   0 flame    a hose puff (life = its age 0..1): an orange body with a deep red band and a sooty rim,
//              a white-hot core early
//   1 orb      a radial glow: a core (color2) inside a halo (color); `strength` scales the halo's cover
//   2 comet    a streak along UV.x (0 = head), soft across UV.y, with a smoke tail (color2)
//   3 crescent a blade arc swept by `progress`: UV.x along the sweep, UV.y from the edge inward
//   7 swirl    a ring of flame streaks rotating round the centre (Cinder's shield)
//   8 links    a ring of chain links (Dredge Grounded while he reels)
//   9 flame icon  a small teardrop flame (the burn pips over a foe)
//  10 spiral   a stun spiral (Anchor Drop victims)
//  11 wave     a ring that opens over life (Cinder Shot's fizzle)
//   else     a round dot with a dark core
uniform vec4 color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform vec4 color2 : source_color = vec4(1.0, 1.0, 0.8, 1.0);
uniform float life = 0.0;
uniform float progress = 1.0;
uniform int mode = 0;
uniform float seed = 0.0;
uniform float strength = 1.0;
uniform bool billboard = false;
#include "res://shaders/noise.gdshaderinc"

// A camera-facing modelview keeping the node's scale (for `billboard` looks).
mat4 ld_billboard(mat4 model, mat4 view, mat4 inv_view) {
	float s = length(model[0].xyz);
	return view * mat4(inv_view[0] * s, inv_view[1] * s, inv_view[2] * s, model[3]);
}

vec3 fire_ramp(float t) {
	// 0 yellow, 0.35 orange, 0.65 deep red, 1 soot violet
	vec3 a = vec3(1.0, 0.78, 0.2);
	vec3 b = vec3(1.0, 0.42, 0.08);
	vec3 c = vec3(0.78, 0.12, 0.06);
	vec3 d = vec3(0.2, 0.07, 0.1);
	if (t < 0.35) return mix(a, b, t / 0.35);
	if (t < 0.65) return mix(b, c, (t - 0.35) / 0.3);
	return mix(c, d, clamp((t - 0.65) / 0.35, 0.0, 1.0));
}

// The look of `mode` at uv01: body colour and cover (alpha-blended) and glow (added on top).
void ld_look(vec2 uv01, out vec3 body, out float alpha, out vec3 glow) {
	float k = 1.0 - life;
	vec2 uv = uv01 * 2.0 - 1.0;
	float d = length(uv);
	body = color.rgb;
	alpha = 0.0;
	glow = vec3(0.0);
	if (mode == 0) {
		float n = fbm3(uv * 2.2 + vec2(seed * 3.1, -TIME * 3.0 - seed * 3.1));
		float edge = 0.66 + 0.3 * n;
		float cover = 1.0 - smoothstep(edge * 0.55, edge, d);
		float band = smoothstep(edge * 0.3, edge * 0.85, d);
		float fade = 1.0 - smoothstep(0.65, 1.0, life);
		body = fire_ramp(0.05 + life * 0.75 + band * 0.3 + n * 0.12);
		alpha = cover * fade * 0.85;
		float core = (1.0 - smoothstep(0.0, 0.42, d)) * (1.0 - smoothstep(0.08, 0.45, life));
		glow = vec3(1.0, 0.82, 0.45) * core * 0.6;
	} else if (mode == 1) {
		float core = 1.0 - smoothstep(0.0, 0.34, d);
		float halo = 1.0 - smoothstep(0.25, 1.0, d);
		float flick = 0.85 + 0.15 * vnoise(vec2(atan(uv.y, uv.x) * 3.0 + seed, TIME * 9.0));
		body = mix(color.rgb, color2.rgb, core);
		alpha = clamp(halo * flick * strength + core, 0.0, 1.0) * k;
		glow = color2.rgb * core * 0.6 * k;
	} else if (mode == 2) {
		float along = uv01.x;
		float across = 1.0 - abs(uv01.y * 2.0 - 1.0);
		float head = (1.0 - along) * smoothstep(0.0, 0.7, across);
		float flick = 0.75 + 0.25 * vnoise(vec2(along * 7.0 - TIME * 16.0, uv01.y * 5.0 + seed));
		float smoke_n = vnoise(vec2(along * 4.0 - TIME * 5.0, uv01.y * 3.0));
		float smoke = smoothstep(0.2, 0.9, along) * (1.0 - along) * smoothstep(0.0, 0.9, across) * smoke_n;
		float smoke_w = smoke * 2.0 / (head * head * flick + smoke * 2.0 + 0.001);
		body = mix(color.rgb, color2.rgb, smoke_w);
		alpha = clamp(head * head * flick * 1.4 + smoke * 2.4 * color2.a, 0.0, 1.0) * k;
		glow = color.rgb * pow(head, 3.0) * 0.35 * k;
	} else if (mode == 3) {
		float behind = progress * 1.3 - uv01.x;
		float trail = behind < 0.0 ? 0.0 : 1.0 - smoothstep(0.0, 0.8, behind);
		float edge = 1.0 - smoothstep(0.0, 0.22, uv01.y);
		float inner = (1.0 - smoothstep(0.15, 1.0, uv01.y)) * (1.0 - edge);
		float n = 0.6 + 0.4 * vnoise(vec2(uv01.x * 6.0 - progress * 7.0, uv01.y * 8.0 + seed));
		float fade = 1.0 - smoothstep(0.6, 1.0, life);
		body = mix(color2.rgb, color.rgb, edge);
		alpha = clamp(edge + inner * n * 0.85, 0.0, 1.0) * trail * fade;
		glow = color.rgb * edge * 0.35 * trail * fade;
	} else if (mode == 7) {
		float a = atan(uv.y, uv.x);
		float ring = 1.0 - smoothstep(0.0, 0.17, abs(d - 0.8));
		float streak = pow(fract(a / 6.2832 * 5.0 + TIME * 1.6 + seed), 3.0);
		float n = vnoise(vec2(a * 4.0 - TIME * 6.0, d * 6.0));
		body = mix(color.rgb * 0.6, color2.rgb, streak * n);
		alpha = ring * (0.45 + 0.55 * streak) * strength;
		glow = color2.rgb * ring * streak * n * 0.35 * strength;
	} else if (mode == 8) {
		float a = atan(uv.y, uv.x) / 6.2832 + 0.5;
		float ring = 1.0 - smoothstep(0.0, 0.1, abs(d - 0.82));
		float link = fract(a * 14.0 + seed);
		float lit = smoothstep(0.08, 0.2, link) * (1.0 - smoothstep(0.42, 0.55, link));
		body = mix(color2.rgb, color.rgb, lit);
		alpha = ring * (0.5 + 0.5 * lit) * strength;
		glow = color.rgb * ring * lit * 0.2 * strength;
	} else if (mode == 9) {
		vec2 p = vec2(uv.x, uv.y + 0.25);
		float w = 0.55 * (1.0 - smoothstep(-0.9, 0.9, -p.y)) + 0.05;
		float wob = sin(p.y * 6.0 + TIME * 14.0 + seed) * 0.08;
		float shape = 1.0 - smoothstep(w * 0.6, w, abs(p.x + wob * (0.5 - p.y)));
		shape *= smoothstep(-0.95, -0.6, -p.y) * (1.0 - smoothstep(0.55, 0.75, p.y));
		float core = shape * (1.0 - smoothstep(0.0, 0.35, length(p - vec2(0.0, 0.25))));
		body = mix(color.rgb, color2.rgb, core);
		alpha = shape * strength;
		glow = color2.rgb * core * 0.5 * strength;
	} else if (mode == 10) {
		float a = atan(uv.y, uv.x);
		float sp = fract((a / 6.2832) * 2.0 - d * 2.2 + TIME * 2.5);
		float arm = (1.0 - smoothstep(0.0, 0.14, abs(sp - 0.5))) * (1.0 - smoothstep(0.7, 1.0, d)) * smoothstep(0.08, 0.2, d);
		body = mix(color2.rgb, color.rgb, smoothstep(0.2, 0.8, d));
		alpha = arm * strength;
		glow = color.rgb * arm * 0.25 * strength;
	} else if (mode == 11) {
		float r = 0.2 + 0.78 * smoothstep(0.0, 0.6, life);
		float ring = 1.0 - smoothstep(0.0, 0.07 + 0.06 * k, abs(d - r));
		float fill = (1.0 - smoothstep(0.0, r, d)) * 0.25 * k * color2.a;
		body = mix(color2.rgb, color.rgb, ring);
		alpha = clamp(ring + fill, 0.0, 1.0) * k;
		glow = color.rgb * ring * 0.3 * k;
	} else if (mode == 13) {
		// a thin ribbon of smoke climbing from the quad's foot, wavering and breaking into streaks
		float h = 1.0 - uv01.y;
		float sway = 0.26 * h * sin(h * 4.5 + TIME * 1.4 + seed * 2.0) + 0.12 * h * h * sin(seed * 5.0);
		float w = 0.05 + 0.15 * h;
		float x = uv.x - sway;
		float n = fbm3(vec2(x * 2.5, h * 3.5 - TIME * 1.1) + seed);
		float ribbon = 1.0 - smoothstep(w * 0.45, w, abs(x));
		float streak = smoothstep(0.32, 0.62, n + 0.2);
		float ends = smoothstep(0.0, 0.1, h) * (1.0 - smoothstep(0.5, 0.95, h));
		body = mix(color2.rgb, color.rgb, smoothstep(0.0, 0.6, h));
		alpha = ribbon * streak * ends * color.a * smoothstep(0.0, 0.15, life) * (1.0 - smoothstep(0.55, 1.0, life));
	} else {
		float cover = 1.0 - smoothstep(0.7, 1.0, d);
		float core = 1.0 - smoothstep(0.15, 0.5, d);
		body = mix(color.rgb, color2.rgb, core);
		alpha = cover * k;
		glow = color.rgb * (1.0 - smoothstep(0.5, 1.0, d)) * 0.25 * k;
	}
}
