// One Hero VFX GPU particle, a camera-facing quad (the motion: hero_vfx_motes.gdshader; its velocity, size and age
// arrive in the instance transform). Embers are hot streaks along their velocity that cool to col3; smoke is a soft
// noisy puff that grows and thins. Premultiplied like shaders/hero_vfx.gdshader.
shader_type spatial;
render_mode blend_premul_alpha, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec4 col : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform vec4 col2 : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform vec4 col3 : source_color = vec4(0.16, 0.05, 0.02, 1.0);
// 0 ember, 1 smoke, 2 chunk (a dark tumbling shard of ground), 3 shard (a crisp crystal), 4 card (a tumbling card
// that burns from its edges), 5 coin (a spinning metal glint), 6 star (a twinkling four-point star), 7 drop (water),
// 8 petal (a leaf-shaped petal that flutters as it falls)
uniform int look = 0;
uniform float stretch = 0.05;  // s of velocity an ember's streak spans
uniform float gain = 1.0;

varying float age;
varying float pick;

void vertex() {
	vec3 vel = MODEL_MATRIX[0].xyz;
	float sz = MODEL_MATRIX[1].x;
	age = clamp(MODEL_MATRIX[1].y, 0.0, 1.0);
	pick = MODEL_MATRIX[2].x;
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec2 q = VERTEX.xy * 2.0;
	vec3 world;
	if (look == 0 || look == 7) {
		vec3 vs = (VIEW_MATRIX * vec4(vel, 0.0)).xyz;
		vec2 v2 = vs.xy;
		float len = length(v2);
		vec2 way = len > 0.01 ? v2 / len : vec2(0.0, 1.0);
		vec2 side = vec2(-way.y, way.x);
		float w = sz * 0.6 * (1.0 - age * 0.6);
		vec2 off = side * q.x * w + way * q.y * (w + len * stretch);
		world = center + right * off.x + up * off.y;
	} else {
		float grow = look == 1 ? sz * (0.6 + age * 1.6) : sz * (1.0 - age * 0.3);
		float turn = look == 1 ? age * 0.7 : age * 9.0;
		if (look == 6) { turn = age * 1.5; }
		float ang = pick * 6.28 + turn;
		float ca = cos(ang);
		float sa = sin(ang);
		vec2 qq = q;
		if (look == 4 || look == 5) { qq.x *= cos(age * 14.0 + pick * 9.0); }   // flipping over as it tumbles
		if (look == 8) { qq.x *= 0.35 + 0.65 * abs(cos(age * 7.0 + pick * 9.0)); }   // a slow flutter
		if (look == 4) { qq.y *= 1.4; }
		vec2 off = vec2(qq.x * ca - qq.y * sa, qq.x * sa + qq.y * ca) * grow;
		world = center + right * off.x + up * off.y;
	}
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	vec3 c;
	float a;
	if (look == 0) {
		float dot_shape = 1.0 - smoothstep(0.3, 1.0, d);
		vec3 hot = mix(col2.rgb, col.rgb, smoothstep(0.1, 0.55, age));
		c = mix(hot, col3.rgb, smoothstep(0.55, 1.0, age));
		a = dot_shape * (1.0 - smoothstep(0.7, 1.0, age));
		ALBEDO = c * a * gain;
		ALPHA = a * 0.9 * gain;
	} else if (look == 1) {
		float n = fbm3(p * 1.6 + pick * 31.0 + vec2(0.0, age * 1.4));
		float puff = (1.0 - smoothstep(0.35, 1.0, d + (n - 0.5) * 0.9));
		a = puff * smoothstep(0.0, 0.12, age) * (1.0 - smoothstep(0.35, 1.0, age)) * 0.38;
		ALBEDO = mix(col.rgb, col3.rgb, smoothstep(0.0, 0.35, age)) * a * gain;
		ALPHA = a * gain;
	} else if (look == 3) {
		// a crystal: a sharp diamond with a bright facet edge
		float dia = abs(p.x) * (1.3 + pick * 0.6) + abs(p.y) * 0.8;
		float body = 1.0 - smoothstep(0.78, 0.84, dia);
		float facet = smoothstep(0.55, 0.8, dia) * body + step(0.0, p.x) * 0.25 * body;
		a = body * (1.0 - smoothstep(0.75, 1.0, age));
		ALBEDO = mix(col.rgb, col2.rgb, facet) * a * gain;
		ALPHA = a * 0.95 * gain;
	} else if (look == 4) {
		// a card: a pale face with a coloured mark, burning in from its edges to char
		float edge = max(abs(p.x), abs(p.y));
		float burn = age * 1.3 + (fbm3(p * 3.0 + pick * 17.0) - 0.5) * 0.4;
		float left = 1.0 - smoothstep(0.88 - burn * 0.9, 0.95 - burn * 0.9, edge);
		float rim = left * smoothstep(0.7 - burn * 0.9, 0.9 - burn * 0.9, edge);
		float mark = 1.0 - smoothstep(0.18, 0.24, length(p * vec2(1.0, 0.8)));
		vec3 face = mix(vec3(0.95, 0.92, 0.85), col.rgb, mark);
		c = mix(face, col2.rgb, rim);
		a = left;
		ALBEDO = c * a * gain;
		ALPHA = a * gain;
	} else if (look == 5) {
		// a coin or a nail head: metal with a glint that sweeps over it as it spins
		float disc = 1.0 - smoothstep(0.8, 0.9, d);
		float glint = pow(max(0.0, sin(age * 18.0 + pick * 9.0 + p.x * 3.0)), 8.0);
		a = disc * (1.0 - smoothstep(0.8, 1.0, age));
		ALBEDO = mix(col.rgb * (0.6 + 0.4 * (0.5 + 0.5 * p.y)), vec3(1.0), glint) * a * gain;
		ALPHA = a * gain;
	} else if (look == 6) {
		// a star: four thin rays and a core that twinkle
		float rays = max(1.0 - smoothstep(0.0, 0.12, abs(p.x)) , 1.0 - smoothstep(0.0, 0.12, abs(p.y)));
		rays *= 1.0 - smoothstep(0.3, 1.0, d);
		float core = 1.0 - smoothstep(0.0, 0.35, d);
		float tw = 0.65 + 0.35 * sin(age * 25.0 + pick * 40.0);
		a = clamp(rays + core, 0.0, 1.0) * tw * (1.0 - smoothstep(0.6, 1.0, age));
		ALBEDO = mix(col.rgb, col2.rgb, core) * a * gain;
		ALPHA = a * 0.85 * gain;
	} else if (look == 7) {
		// a drop of water: a clear streak with a bright rim, gone as it lands
		float drop = 1.0 - smoothstep(0.35, 1.0, d);
		a = drop * (1.0 - smoothstep(0.6, 1.0, age)) * 0.75;
		ALBEDO = mix(col.rgb, col2.rgb, smoothstep(0.4, 0.9, d)) * a * gain;
		ALPHA = a * gain;
	} else if (look == 8) {
		// a petal: an almond with a pale midrib, its base the body colour, its tip the hot colour
		float half_w = 0.55 * (1.0 - p.y * p.y);
		float body = 1.0 - smoothstep(half_w - 0.08, half_w, abs(p.x));
		float rib = (1.0 - smoothstep(0.0, 0.06, abs(p.x))) * 0.5;
		a = body * (1.0 - smoothstep(0.7, 1.0, age));
		ALBEDO = mix(mix(col.rgb, col2.rgb, 0.5 + 0.5 * p.y), col2.rgb, rib) * a * gain;
		ALPHA = a * 0.95 * gain;
	} else {
		float rock = step(abs(p.x) + abs(p.y) * (0.7 + pick * 0.6), 0.85);
		a = rock * (1.0 - smoothstep(0.8, 1.0, age));
		float lit = 0.5 + 0.5 * p.y;
		ALBEDO = mix(col3.rgb, col.rgb, lit * (1.0 - age)) * a * gain;
		ALPHA = a * gain;
	}
}
