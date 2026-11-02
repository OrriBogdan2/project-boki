shader_type spatial;
// Moosh Moosh and Tamsin ground discs (CareLook): a soft filled disc with a bright rim, an optional
// sweep that fills toward a trigger, and a sigil per owner. pattern: 0 plain, 1 a lantern plus (heal),
// 2 a six-spoke frost flake (slow zone), 3 a ring of burr thorns (Burrseed root).
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 rim : source_color = vec4(1.0);
uniform float fill = 1.0;        // 0..1 inner body strength
uniform float sweep = -1.0;      // 0..1 a front growing out from the centre (-1: none)
uniform float pattern = 0.0;
uniform float spin = 0.0;        // radians: the sigil turns with it
uniform float rim_w = 0.08;

float sigil(vec2 uv, float r, float a) {
	if (pattern < 0.5) { return 0.0; }
	if (pattern < 1.5) {
		// a plus: two soft bars
		vec2 q = abs(uv);
		float bar = max(step(q.x, 0.13) * step(q.y, 0.55), step(q.y, 0.13) * step(q.x, 0.55));
		return bar * 0.55;
	}
	if (pattern < 2.5) {
		// six spokes with little side ticks
		float s = abs(cos(a * 3.0));
		float spoke = smoothstep(0.96, 1.0, s) * step(r, 0.82);
		float tick = smoothstep(0.9, 1.0, abs(cos(a * 6.0))) * smoothstep(0.42, 0.46, r) * (1.0 - smoothstep(0.5, 0.54, r));
		return (spoke + tick) * 0.7;
	}
	// thorns: little triangles on an inner ring
	float th = pow(abs(cos(a * 6.0)), 6.0);
	float band = smoothstep(0.6 + 0.25 * th, 0.58 + 0.25 * th, r) * smoothstep(0.52, 0.56, r);
	return band * 0.8;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	if (r > 1.0) { discard; }
	float a = atan(uv.y, uv.x) + spin;
	vec2 ruv = vec2(cos(a), sin(a)) * r;
	float edge = smoothstep(1.0 - rim_w - 0.03, 1.0 - rim_w, r) * (1.0 - smoothstep(0.97, 1.0, r));
	float body = fill * (0.18 + 0.22 * r * r);
	float sw = 0.0;
	if (sweep >= 0.0) {
		body *= step(r, sweep) * 0.8 + 0.2;
		sw = smoothstep(sweep - 0.06, sweep, r) * (1.0 - smoothstep(sweep, sweep + 0.02, r));
	}
	float sg = sigil(ruv, r, a);
	vec3 c = color.rgb * (body + sg * 0.9) + rim.rgb * (edge + sw * 1.2);
	ALBEDO = c;
	ALPHA = clamp((body + sg + edge + sw) * color.a, 0.0, 1.0);
}
