shader_type spatial;
// Dancer's and Juggernaut's own effect looks (scripts/arch/kits/dj_fx.gd), one shader, a mode each:
//   0 star     a camera-facing four-point star round a hot core (Dancer's knock, tip hits)
//   1 pillar   a rising column of light, UV.y up the side (the knock heal)
//   2 comet    a streak along UV.x (0 = head), soft across UV.y (bolt and dagger trails)
//   3 crescent a two-tone blade arc: UV.x along the sweep, UV.y from the edge (0) inward (1);
//              color is the outer edge, color2 the inner fill; progress sweeps it
//   4 puff     a camera-facing soft ring that opens and fades (a bolt fizzling at the cursor)
//   5 links    a chain: alternating bright and dark links along UV.x (stripes = links per metre * length)
//   6 bolt     a jagged lightning ribbon along UV.x (the empowered shot)
// life runs 0 -> 1 over the effect; everything is additive and unshaded.
render_mode unshaded, shadows_disabled, depth_draw_never, blend_add, cull_disabled, fog_disabled;
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

void fragment() {
	float k = 1.0 - life;
	vec3 c = vec3(0.0);
	if (mode == 0) {
		vec2 uv = UV * 2.0 - 1.0;
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
		float rise = fract(UV.y * 3.0 - TIME * 2.2 + seed);
		float streak = smoothstep(0.0, 0.2, rise) * (1.0 - smoothstep(0.2, 0.6, rise));
		float top = 1.0 - smoothstep(0.55, 1.0, UV.y);
		float grow = smoothstep(0.0, 0.18, life);
		c = (color.rgb * (0.35 + 0.65 * streak) + color2.rgb * streak * 0.4) * top * k * grow;
	} else if (mode == 2) {
		float along = UV.x;
		float across = 1.0 - abs(UV.y * 2.0 - 1.0);
		float body = (1.0 - along) * (1.0 - along) * smoothstep(0.0, 0.6, across);
		float hot = (1.0 - smoothstep(0.0, 0.25, along)) * smoothstep(0.5, 1.0, across);
		float flick = 0.75 + 0.25 * vnoise(vec2(along * 6.0 - TIME * 14.0, UV.y * 4.0 + seed));
		c = (color.rgb * body * flick + color2.rgb * hot) * k;
	} else if (mode == 3) {
		float head = progress * 1.3;
		float behind = head - UV.x;
		if (behind < 0.0) { discard; }
		float trail = 1.0 - smoothstep(0.0, 0.8, behind);
		float lead = 1.0 - smoothstep(0.0, 0.07, behind);
		float edge = 1.0 - smoothstep(0.0, 0.16, UV.y);
		float inner = (1.0 - smoothstep(0.1, 1.0, UV.y)) * (1.0 - edge);
		float flame = 0.6 + 0.4 * vnoise(vec2(UV.x * 5.0 - progress * 6.0, UV.y * 7.0 + seed));
		c = (color.rgb * edge * 1.5 + color2.rgb * inner * flame * 1.1) * trail + vec3(1.0) * lead * edge * 0.8;
		c *= 1.0 - smoothstep(0.7, 1.0, life);
	} else if (mode == 4) {
		vec2 uv = UV * 2.0 - 1.0;
		float d = length(uv);
		float r = 0.25 + 0.65 * life;
		float ring = 1.0 - smoothstep(0.0, 0.18, abs(d - r));
		float fill = (1.0 - smoothstep(0.0, r, d)) * 0.35;
		float speck = step(0.82, vnoise(uv * 9.0 + seed)) * (1.0 - smoothstep(0.0, r + 0.1, d));
		c = (color.rgb * (ring + fill) + color2.rgb * speck) * k;
	} else if (mode == 5) {
		float across = 1.0 - abs(UV.y * 2.0 - 1.0);
		float link = fract(UV.x * stripes);
		float lit = step(0.5, link);
		float bevel = smoothstep(0.0, 0.12, link) * (1.0 - smoothstep(0.38, 0.5, link)) + smoothstep(0.5, 0.62, link) * (1.0 - smoothstep(0.88, 1.0, link));
		c = mix(color2.rgb * 0.35, color.rgb, lit) * (0.5 + 0.5 * bevel) * smoothstep(0.0, 0.5, across);
		c *= k;
	} else {
		// lightning: a bright core that jitters across the ribbon, thin and hot
		float jag = vnoise(vec2(UV.x * 9.0 + seed * 3.0, floor(TIME * 24.0))) - 0.5;
		float y = UV.y - 0.5 - jag * 0.55;
		float core = 1.0 - smoothstep(0.0, 0.07, abs(y));
		float glow = 1.0 - smoothstep(0.0, 0.45, abs(y));
		float fade = 1.0 - smoothstep(0.6, 1.0, UV.x);
		c = (color2.rgb * core * 1.4 + color.rgb * glow * 0.6) * fade * k;
	}
	ALBEDO = c * color.a;
	ALPHA = 1.0;
}
