// One Hero VFX GPU particle, a camera-facing quad (the motion: hero_vfx_motes.gdshader; its velocity, size and age
// arrive in the instance transform). Embers are hot streaks along their velocity that cool to col3; smoke is a soft
// noisy puff that grows and thins. Premultiplied like shaders/hero_vfx.gdshader.
shader_type spatial;
render_mode blend_premul_alpha, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec4 col : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform vec4 col2 : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform vec4 col3 : source_color = vec4(0.16, 0.05, 0.02, 1.0);
uniform int look = 0;        // 0 ember, 1 smoke, 2 chunk (a dark tumbling shard of ground)
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
	if (look == 0) {
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
		float ang = pick * 6.28 + (look == 1 ? age * 0.7 : age * 9.0);
		float ca = cos(ang);
		float sa = sin(ang);
		vec2 off = vec2(q.x * ca - q.y * sa, q.x * sa + q.y * ca) * grow;
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
	} else {
		float rock = step(abs(p.x) + abs(p.y) * (0.7 + pick * 0.6), 0.85);
		a = rock * (1.0 - smoothstep(0.8, 1.0, age));
		float lit = 0.5 + 0.5 * p.y;
		ALBEDO = mix(col3.rgb, col.rgb, lit * (1.0 - age)) * a * gain;
		ALPHA = a * gain;
	}
}
