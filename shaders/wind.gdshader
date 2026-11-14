shader_type spatial;
// One streak card of a wind road. The cards live in a MultiMesh laid in the road's own frame (x along
// the road a -> b); each slides along it on TIME, wrapping, and turns about the road's axis to face
// the camera. Shaped like a dart (a thin bright head, a fat fading tail) so the flow reads at match
// zoom. INSTANCE_CUSTOM: x start phase 0..1, y speed (m/s), z length scale.
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 color : source_color = vec4(0.75, 0.95, 1.0, 0.5);
uniform float road_len = 10.0;
uniform float flow = 1.0;       // +1 = a -> b, -1 = b -> a (follows the glider on the road)
uniform float boost = 0.0;      // 0..1: the glider is riding this road
uniform float card_len = 2.6;   // m
uniform float card_w = 0.2;     // m, half-width of the tail
varying float v_fade;
void vertex() {
	float s = fract(INSTANCE_CUSTOM.x + flow * TIME * INSTANCE_CUSTOM.y * (1.0 + 0.5 * boost) / road_len);
	vec3 centre = vec3(s * road_len, 0.0, 0.0);
	vec3 to_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz - centre;
	vec3 side = cross(vec3(1.0, 0.0, 0.0), to_cam);
	side = length(side) < 0.001 ? vec3(0.0, 0.0, 1.0) : normalize(side);
	float w = card_w * (1.0 + 0.8 * boost);
	VERTEX = centre + vec3(1.0, 0.0, 0.0) * VERTEX.x * card_len * INSTANCE_CUSTOM.z + side * VERTEX.y * 2.0 * w;
	v_fade = smoothstep(0.0, 0.1, s) * (1.0 - smoothstep(0.9, 1.0, s));
}
void fragment() {
	float u = flow > 0.0 ? UV.x : 1.0 - UV.x;      // 1 = the head, the end it flies toward
	float v = abs(UV.y * 2.0 - 1.0);
	float half_w = 1.0 - 0.85 * u;
	float shape = smoothstep(half_w, half_w * 0.35, v) * (0.1 + 0.9 * pow(u, 1.5));
	shape += smoothstep(0.88, 1.0, u) * smoothstep(0.35, 0.0, v);   // the bright tip
	ALBEDO = mix(color.rgb, vec3(1.0), 0.5 * boost);
	ALPHA = clamp(color.a * (1.0 + 1.4 * boost) * v_fade * shape, 0.0, 1.0);
}
