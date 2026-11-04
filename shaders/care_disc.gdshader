shader_type spatial;
// Pip and Claire ground discs (CareLook): a soft filled disc with a bright rim, an optional
// sweep that fills toward a trigger, and a sigil per owner. pattern: 0 plain, 1 a lantern plus (heal),
// 2 a six-spoke frost flake (slow zone), 3 a ring of burr thorns (Burrseed root), 4 Claire's Rimelock rink:
// a ragged crystalline edge and a crack network whose glow (`crack`, 0..1) is the countdown; 5 the
// Hearthlight: no sigil, the body warm in the middle (color) shading out to the rim colour.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 rim : source_color = vec4(1.0);
uniform float fill = 1.0;        // 0..1 inner body strength
uniform float sweep = -1.0;      // 0..1 a front growing out from the centre (-1: none)
uniform float pattern = 0.0;
uniform float spin = 0.0;        // radians: the sigil turns with it
uniform float rim_w = 0.08;
uniform float crack = 0.0;       // pattern 4: how bright the cracks glow (0..1)

float sigil(vec2 uv, float r, float a) {
	if (pattern < 0.5 || pattern > 4.5) { return 0.0; }
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
	if (pattern > 3.5) {
		// cracks: jagged spokes that fork, and broken rings between them
		float jag = sin(r * 23.0 + a * 3.0) * 0.06 + sin(r * 41.0) * 0.03;
		float spokes = smoothstep(0.93, 1.0, abs(cos((a + jag) * 5.5)));
		float forks = smoothstep(0.95, 1.0, abs(cos((a - jag * 2.0) * 11.0))) * step(0.45, r);
		float rings = smoothstep(0.035, 0.0, abs(fract(r * 3.2 + jag) - 0.5) - 0.47) * step(0.4, abs(sin(a * 7.0 + r * 9.0)));
		return (spokes + forks * 0.7 + rings * 0.6) * (0.25 + 1.6 * crack) * step(0.12, r);
	}
	// thorns: little triangles on an inner ring
	float th = pow(abs(cos(a * 6.0)), 6.0);
	float band = smoothstep(0.6 + 0.25 * th, 0.58 + 0.25 * th, r) * smoothstep(0.52, 0.56, r);
	return band * 0.8;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float a = atan(uv.y, uv.x) + spin;
	if (pattern > 3.5 && pattern < 4.5) {
		// a ragged ice edge: the disc reads as a sheet of ice, not a clean circle
		float rag = 0.05 * abs(sin(a * 9.0)) + 0.03 * abs(sin(a * 23.0 + 1.3));
		r = r / (1.0 - rag);
	}
	if (r > 1.0) { discard; }
	vec2 ruv = vec2(cos(a), sin(a)) * r;
	float edge = smoothstep(1.0 - rim_w - 0.03, 1.0 - rim_w, r) * (1.0 - smoothstep(0.97, 1.0, r));
	float body = fill * (0.18 + 0.22 * r * r);
	float sw = 0.0;
	if (sweep >= 0.0) {
		body *= step(r, sweep) * 0.8 + 0.2;
		sw = smoothstep(sweep - 0.06, sweep, r) * (1.0 - smoothstep(sweep, sweep + 0.02, r));
	}
	float sg = sigil(ruv, r, a);
	// mixed, not added, so a saturated disc keeps its colour on bright grass
	float inner = body + sg * 0.9;
	float outer = edge + sw * 1.2;
	vec3 body_col = pattern > 4.5 ? mix(color.rgb, rim.rgb, r * r * r) : color.rgb;
	ALBEDO = (body_col * inner + rim.rgb * outer) / max(inner + outer, 0.001);
	ALPHA = clamp((body * 1.6 + sg + edge * 1.2 + sw) * color.a, 0.0, 1.0);
}
