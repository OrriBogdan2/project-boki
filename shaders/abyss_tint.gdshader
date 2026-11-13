shader_type canvas_item;
// The abyss tint over the whole view (scripts/match/abyss_fx.gd sets k and pulse every frame).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float k = 0.0;       // danger 0..1 (1 = the point of no return)
uniform float pulse = 0.0;   // heartbeat 0..1
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	// [reference footage] under island level the whole view goes a saturated magenta / rose at once,
	// deepening toward crimson-magenta lower down; the picture keeps its shapes (shading, clouds)
	vec3 rose = vec3(0.98, 0.30, 0.66);
	vec3 deep = vec3(0.70, 0.05, 0.30);
	vec3 tint = mix(rose, deep, smoothstep(0.55, 1.0, k));
	// [reference] strong as soon as it's in (k ~0.55 just under the lip), redder and darker deeper
	float s = 0.9 * smoothstep(0.0, 0.6, k);
	vec3 g = mix(c, tint * (0.3 + 1.05 * l), s);
	// right at the end: darker, and the edges close in with the heartbeat
	float e = smoothstep(0.8, 1.0, k);
	g *= 1.0 - 0.3 * e;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length((SCREEN_UV - 0.5) * vec2(aspect, 1.0));
	float v = smoothstep(0.75 - pulse * 0.05, 1.05, r);
	g = mix(g, vec3(0.16, 0.0, 0.06), v * e * 0.8);
	COLOR = vec4(g, 1.0);
}
