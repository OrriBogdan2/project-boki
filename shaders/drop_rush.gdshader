shader_type canvas_item;
// The drop's rush past the screen, one full-screen pass while you fall: streaks flying out of the point
// you're falling toward, a pale pressure at the screen's edges, and the white of punching through cloud.
// k: 0..1 how fast. flash: 0..1 the cloud. focus: the vanishing point (0..1 on screen).
uniform float k = 0.0;
uniform float flash = 0.0;
uniform vec2 focus = vec2(0.5);
uniform vec4 tint : source_color = vec4(0.86, 0.94, 1.0, 1.0);
float hash(float n) {
	return fract(sin(n * 91.7) * 43758.55);
}
void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 d = (SCREEN_UV - focus) * vec2(aspect, 1.0);
	float r = length(d);
	float a = atan(d.y, d.x) / 6.2832 + 0.5;
	float streak = 0.0;
	// two rings of spokes: thin fast ones and fewer broad slow ones
	for (int i = 0; i < 2; i++) {
		float n = i == 0 ? 96.0 : 37.0;
		float cell = a * n;
		float id = floor(cell);
		float across = abs(fract(cell) - 0.5) * 2.0;
		float on = step(i == 0 ? 0.62 : 0.74, hash(id + 11.0 * float(i)));
		float speed = (i == 0 ? 2.1 : 1.1) * (0.7 + 0.8 * hash(id + 7.0));
		float run = fract(r * (i == 0 ? 1.1 : 0.7) - TIME * speed + hash(id + 3.0));
		float len = mix(0.12, 0.42, k);
		float body = smoothstep(0.0, 0.03, run) * (1.0 - smoothstep(len * 0.5, len, run));
		float w = i == 0 ? 0.55 : 0.8;
		streak += on * body * (1.0 - smoothstep(0.0, w, across)) * (i == 0 ? 0.8 : 0.2);
	}
	float edge = smoothstep(0.2 + 0.1 * (1.0 - k), 0.8, r);
	float press = smoothstep(0.42, 1.02, r) * 0.2 * k;
	float alpha = streak * edge * k * 0.75 + press + flash * (0.55 + 0.45 * r);
	COLOR = vec4(tint.rgb, clamp(alpha, 0.0, 1.0));
}
