shader_type spatial;
// Hit sparks and muzzle embers: a streak stretched along the particle's travel (the emitter aligns
// each particle's Y axis to its velocity), turned to face the camera, white-hot at the head and
// fading to its colour at the tail. Additive, so a spray of them blooms a little on the glow pass.
render_mode unshaded, shadows_disabled, depth_draw_never, blend_add, cull_disabled, fog_disabled;
uniform float length_k = 5.0;     // streak length in particle widths
uniform float heat = 1.6;         // brightness (above 1 feeds the glow)
void vertex() {
	vec3 p = MODEL_MATRIX[3].xyz;
	vec3 ay = MODEL_MATRIX[1].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 dir = normalize(ay + vec3(0.0, 1e-5, 0.0));
	vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - p);
	vec3 side = normalize(cross(dir, to_cam) + vec3(1e-5, 0.0, 0.0));
	vec3 w = p + side * VERTEX.x * s + dir * (VERTEX.y - 0.5) * s * length_k;
	MODELVIEW_MATRIX = VIEW_MATRIX;
	VERTEX = w;
}
void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float along = 1.0 - UV.y;           // 1 at the head
	float body = (1.0 - across * across) * smoothstep(0.0, 0.85, along);
	float core = (1.0 - smoothstep(0.0, 0.35, across)) * smoothstep(0.55, 1.0, along);
	vec3 c = mix(COLOR.rgb, vec3(1.0), core * 0.8);
	ALBEDO = c * body * COLOR.a * heat;
	ALPHA = 1.0;
}
