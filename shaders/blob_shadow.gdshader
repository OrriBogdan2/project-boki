shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
// A soft dark disc on the ground straight under a hunter (DepthCues): it stays on the ground when
// the body is airborne or at a ledge, so the gap between them shows how high the body is.
uniform float strength = 0.5;
instance uniform float fade = 1.0;   // 0..1 per disc: a hunter high above the ground fades its disc (DepthCues)

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.04, 0.03, 0.08);
	ALPHA = (1.0 - smoothstep(0.25, 1.0, d)) * strength * fade;
}
