shader_type canvas_item;
// The abyss tint over the whole view (scripts/match/abyss_fx.gd sets k and pulse every frame).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float k = 0.0;       // danger 0..1 (1 = the point of no return)
uniform float pulse = 0.0;   // heartbeat 0..1
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	// Graded (owner 11-17): k is 0 until the start depth and builds to 1 at the point of no return.
	// First the edges redden (a vignette, the centre stays readable), then the whole view drains toward
	// red; the full wash only comes near the end.
	vec3 rose = vec3(0.95, 0.22, 0.30);
	vec3 deep = vec3(0.70, 0.03, 0.12);
	vec3 tint = mix(rose, deep, smoothstep(0.3, 1.0, k));
	float s = 0.85 * smoothstep(0.25, 1.0, k) * k;
	vec3 g = mix(c, tint * (0.3 + 1.05 * l), s);
	float e = smoothstep(0.6, 1.0, k);
	g *= 1.0 - 0.3 * e;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length((SCREEN_UV - 0.5) * vec2(aspect, 1.0));
	float v = smoothstep(0.85 - 0.35 * k - pulse * 0.05 * k, 1.05, r);
	g = mix(g, vec3(0.40, 0.0, 0.05), v * (0.15 + 0.65 * k) * smoothstep(0.0, 0.15, k));
	COLOR = vec4(g, 1.0);
}
