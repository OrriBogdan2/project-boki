shader_type spatial;
// Motley's Nightwell: a whirlpool seen from above on a radius-1 quad. A black core, light streaks winding in to
// it, and a bright rim. `clock` is seconds since it opened (the streaks run inward and the whole turns with it);
// `power` 0..1 is the empowered look: a wider, hotter rim in the accent colour. Alpha-blended so the core stays dark
// on bright grass.
render_mode unshaded, shadows_disabled, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 dark : source_color = vec4(0.02, 0.0, 0.07, 1.0);
uniform vec4 streak : source_color = vec4(0.69, 0.42, 1.0, 1.0);
uniform vec4 rim : source_color = vec4(0.78, 0.55, 1.0, 1.0);
uniform vec4 accent : source_color = vec4(1.0, 0.31, 0.85, 1.0);
uniform float arms = 5.0;
uniform float clock = 0.0;
uniform float power = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float ang = atan(p.y, p.x) - clock * 1.6;
	float wind = arms * ang + 7.0 * sqrt(r) + clock * 6.0;
	float line = pow(0.5 + 0.5 * sin(wind), 3.0) * (0.65 + 0.35 * sin(ang * 3.0 + r * 5.0 + clock * 2.0));
	float lines = line * smoothstep(0.1, 0.75, r) * (1.0 - smoothstep(0.88, 1.0, r));
	float w = mix(0.07, 0.17, power);
	float edge = smoothstep(1.0 - w, 1.0 - w * 0.25, r) * (1.0 - smoothstep(0.97, 1.0, r));
	float glow = exp(-(1.0 - r) * mix(9.0, 5.0, power)) * 0.5;
	vec3 hot = mix(rim.rgb, accent.rgb, power * 0.6) * (1.0 + 0.8 * power) * (0.9 + 0.1 * sin(clock * 6.0));
	float body = mix(0.97, 0.55, smoothstep(0.0, 0.9, r));
	vec3 col = mix(dark.rgb, streak.rgb, lines * 0.9);
	col = mix(col, hot, clamp(glow + edge, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = clamp(max(body, max(lines, edge)), 0.0, 1.0);
}
