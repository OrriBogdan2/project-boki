shader_type spatial;
// The drop's two beats, one shader over one pooled mesh (DropBlasts).
// kind 0: the glider's snap, a camera-facing crack of air: a hard ring and short canopy-line rays.
// kind 1: the landing, flat on the ground: a torn ring of dust racing out and a bright first flash.
// INSTANCE_CUSTOM: x age 0..1, y kind, z a seed. COLOR: the owner's colour.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/noise.gdshaderinc"
varying float age;
varying float kind;
varying float seed;
void vertex() {
	age = INSTANCE_CUSTOM.x;
	kind = INSTANCE_CUSTOM.y;
	seed = INSTANCE_CUSTOM.z;
	float s = length(MODEL_MATRIX[0].xyz);
	if (kind < 0.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	} else {
		VERTEX = vec3(VERTEX.x, 0.0, -VERTEX.y);
	}
}
float ease_out(float x, float p) {
	return 1.0 - pow(1.0 - x, p);
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	vec3 col;
	float alpha;
	if (kind < 0.5) {
		float front = ease_out(age, 3.0) * 0.86;
		float band = 1.0 - smoothstep(0.0, 0.025 + 0.07 * age, abs(r - front));
		float spokes = pow(abs(cos(a * 4.0 + seed * 6.0)), 40.0);
		float ray = spokes * smoothstep(front * 0.8, front * 0.96, r) * (1.0 - smoothstep(front + 0.02, front + 0.14, r));
		col = mix(vec3(1.0), COLOR.rgb, 0.35 + 0.5 * age);
		alpha = (band * 0.85 + ray) * (1.0 - age) * (1.0 - age);
	} else {
		float front = ease_out(age, 3.4) * 0.8;
		float n = vnoise(vec2(a * 3.2 + seed * 19.0, age * 2.0)) + 0.5 * vnoise(vec2(a * 8.1 + seed * 7.0, r * 5.0));
		float torn = front + (n - 0.75) * 0.17 * (0.3 + age);
		float width = 0.1 + 0.3 * age;
		float dust = smoothstep(torn - width, torn, r) * (1.0 - smoothstep(torn, torn + 0.05, r));
		dust *= smoothstep(0.25, 0.75, n + 0.45 * (1.0 - age));
		float hot = (1.0 - smoothstep(0.0, 0.03, abs(r - ease_out(age, 5.0) * 0.46))) * (1.0 - smoothstep(0.0, 0.3, age));
		col = mix(vec3(0.86, 0.79, 0.66), COLOR.rgb, hot);
		alpha = (dust * 0.8 * (1.0 - age * age) + hot) * (1.0 - smoothstep(0.92, 1.0, r));
	}
	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
