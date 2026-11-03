// The looks of shaders/dj_fx.gdshader (additive glow) and dj_fx_mix.gdshader (alpha blended colour), one
// function shared by both: dj_look(uv) gives the colour and, for the links, how much of it is solid.
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform vec4 color2 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float life = 0.0;
uniform float progress = 1.0;
uniform int mode = 0;
uniform float stripes = 8.0;
uniform float seed = 0.0;
uniform bool billboard = false;
#include "res://shaders/noise.gdshaderinc"

void vertex() {
	if (billboard) {
		float s = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	}
}

// rgb: the look; a: its coverage where a mode has a solid body (the chain's links), else -1 (from brightness)
vec4 dj_look(vec2 uv0) {
	float k = 1.0 - life;
	vec3 c = vec3(0.0);
	float cov = -1.0;
	if (mode == 0) {
		vec2 uv = uv0 * 2.0 - 1.0;
		float d = length(uv);
		float a = atan(uv.y, uv.x) + seed;
		// four long points, four short ones between them, a hot core and a soft halo
		float p4 = pow(abs(cos(a * 2.0)), 40.0) * (1.0 - smoothstep(0.0, 1.0, d / (0.35 + 0.65 * smoothstep(0.0, 0.25, life))));
		float p8 = pow(abs(cos(a * 2.0 + 0.785)), 60.0) * (1.0 - smoothstep(0.0, 0.5, d)) * 0.5;
		float core = 1.0 - smoothstep(0.0, 0.18, d);
		float halo = (1.0 - smoothstep(0.1, 0.9, d)) * 0.3;
		c = color.rgb * (p4 * 1.6 + p8 + halo) + color2.rgb * core;
		c *= k;
	} else if (mode == 1) {
		// a column: bright edges seen side on, streaks rising, a soft top
		float rise = fract(uv0.y * 3.0 - TIME * 2.2 + seed);
		float streak = smoothstep(0.0, 0.2, rise) * (1.0 - smoothstep(0.2, 0.6, rise));
		float top = 1.0 - smoothstep(0.55, 1.0, uv0.y);
		float grow = smoothstep(0.0, 0.18, life);
		c = (color.rgb * (0.35 + 0.65 * streak) + color2.rgb * streak * 0.4) * top * k * grow;
	} else if (mode == 2) {
		float along = uv0.x;
		float across = 1.0 - abs(uv0.y * 2.0 - 1.0);
		float body = (1.0 - along) * (1.0 - along) * smoothstep(0.0, 0.6, across);
		float hot = (1.0 - smoothstep(0.0, 0.25, along)) * smoothstep(0.5, 1.0, across);
		float flick = 0.75 + 0.25 * vnoise(vec2(along * 6.0 - TIME * 14.0, uv0.y * 4.0 + seed));
		c = (color.rgb * body * flick + color2.rgb * hot) * k;
	} else if (mode == 3) {
		float head = progress * 1.3;
		float behind = head - uv0.x;
		if (behind < 0.0) { discard; }
		// the swept part stays solid (at least 60%) so the whole arc reads, brightest at the leading edge
		float trail = mix(0.6, 1.0, 1.0 - smoothstep(0.0, 0.6, behind));
		float lead = 1.0 - smoothstep(0.0, 0.07, behind);
		float edge = 1.0 - smoothstep(0.0, 0.3, uv0.y);
		float inner = (1.0 - smoothstep(0.1, 1.0, uv0.y)) * (1.0 - edge);
		float flame = 0.6 + 0.4 * vnoise(vec2(uv0.x * 5.0 - progress * 6.0, uv0.y * 7.0 + seed));
		c = (color.rgb * edge * 1.5 + color2.rgb * inner * flame * 1.1) * trail + mix(color.rgb, vec3(1.0), 0.45) * lead * edge * 0.8;
		c *= 1.0 - smoothstep(0.7, 1.0, life);
	} else if (mode == 4) {
		vec2 uv = uv0 * 2.0 - 1.0;
		float d = length(uv);
		float r = 0.25 + 0.65 * life;
		float ring = 1.0 - smoothstep(0.0, 0.18, abs(d - r));
		float fill = (1.0 - smoothstep(0.0, r, d)) * 0.35;
		float speck = step(0.82, vnoise(uv * 9.0 + seed)) * (1.0 - smoothstep(0.0, r + 0.1, d));
		c = (color.rgb * (ring + fill) + color2.rgb * speck) * k;
	} else if (mode == 5) {
		float across = 1.0 - abs(uv0.y * 2.0 - 1.0);
		float link = fract(uv0.x * stripes);
		float lit = step(0.5, link);
		float bevel = smoothstep(0.0, 0.12, link) * (1.0 - smoothstep(0.38, 0.5, link)) + smoothstep(0.5, 0.62, link) * (1.0 - smoothstep(0.88, 1.0, link));
		c = mix(color2.rgb, color.rgb, lit) * (0.6 + 0.4 * bevel);
		cov = smoothstep(0.0, 0.35, across) * k;
	} else {
		// lightning: a bright core that jitters across the ribbon, thin and hot
		float jag = vnoise(vec2(uv0.x * 9.0 + seed * 3.0, floor(TIME * 24.0))) - 0.5;
		float y = uv0.y - 0.5 - jag * 0.55;
		float core = 1.0 - smoothstep(0.0, 0.07, abs(y));
		float glow = 1.0 - smoothstep(0.0, 0.45, abs(y));
		float fade = 1.0 - smoothstep(0.6, 1.0, uv0.x);
		c = (color2.rgb * core * 1.4 + color.rgb * glow * 0.6) * fade * k;
	}
	return vec4(c, cov);
}
