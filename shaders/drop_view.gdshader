shader_type canvas_item;
// The local player's way down (DropView): wind streaks at the screen edges that grow with the fall
// speed, and a moment of pale haze crossing the cloud sheet. One full-screen pass, drawn only while
// either of them shows.
uniform float streak = 0.0;      // 0..1 with fall speed
uniform float haze = 0.0;        // 0..1 inside the cloud
uniform vec4 tint : source_color = vec4(0.92, 0.95, 1.0, 1.0);
const float LANES = 56.0;        // streak lanes round the screen
float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }
void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;                        // 0 at the centre, 1 at the middle of an edge
	float lane = (atan(c.y, c.x) / 6.28318 + 0.5) * LANES;
	float seed = hash(floor(lane));
	// a short dash running outward along its lane, thin across it; about half the lanes are empty
	float along = fract(r * (1.2 + seed) - TIME * (1.6 + seed * 1.4) + seed * 7.0);
	float dash = smoothstep(0.0, 0.08, along) * (1.0 - smoothstep(0.08, 0.5, along));
	float thin = 1.0 - smoothstep(0.05, 0.3, abs(fract(lane) - 0.5) * 2.0);
	float s = dash * thin * step(0.45, seed) * smoothstep(0.6, 1.25, r) * streak * 0.5;
	COLOR = vec4(tint.rgb, max(s, haze));
}
