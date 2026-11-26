shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
// A soft dark disc on the ground straight under an airborne hunter (DepthCues): it stays on the ground when
// the body is up in the air, so the gap between them shows how high the body is. Round by construction:
// nothing is drawn outside the disc, so the quad never shows as a square.
uniform float strength = 0.5;
instance uniform float fade = 1.0;   // 0..1 per disc: a hunter high above the ground fades its disc (DepthCues)

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	if (d >= 1.0) { discard; }
	ALBEDO = vec3(0.04, 0.03, 0.08);
	ALPHA = (1.0 - smoothstep(0.0, 1.0, d)) * strength * fade;
}
