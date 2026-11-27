shader_type canvas_item;
// A coloured vignette at the screen edge for the local player's status (scripts/match/status_edge.gd sets col and
// k each frame). No screen read: it only blends, so it costs one cheap full-screen quad while a status runs.
uniform vec3 col = vec3(0.35, 0.6, 1.0);
uniform float k = 0.0;       // strength 0..1
uniform float pulse = 0.0;   // 0..1 slow breathing of the inner edge
void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length((SCREEN_UV - 0.5) * vec2(aspect, 1.0)) / length(vec2(aspect, 1.0) * 0.5);
	float inner = 0.55 - 0.05 * pulse;
	float body = smoothstep(inner, 1.0, r);                 // soft wash, the centre stays clear
	float rim = smoothstep(0.86, 1.0, r);                   // a brighter band hugging the edge
	float a = k * (0.5 * body * body + 0.45 * rim);
	COLOR = vec4(mix(col, vec3(1.0), 0.25 * rim), a);
}
