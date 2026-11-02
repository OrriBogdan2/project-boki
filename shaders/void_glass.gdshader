shader_type spatial;
// Ostra's void crystal and orbs: a dark core that turns to a hot violet rim toward the silhouette,
// with a slow inner swirl. Additive, so a cluster of shards reads as one bright bundle.
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, cull_disabled;
#include "res://shaders/noise.gdshaderinc"
uniform vec4 core : source_color = vec4(0.12, 0.03, 0.22, 1.0);
uniform vec4 rim : source_color = vec4(0.85, 0.45, 1.0, 1.0);
uniform float power = 2.2;
uniform float swirl = 1.0;
uniform float alpha = 1.0;
void fragment() {
	float f = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float s = vnoise(UV * 6.0 + vec2(TIME * 0.7 * swirl, -TIME * 0.4 * swirl));
	vec3 c = mix(core.rgb, rim.rgb, pow(f, power)) + rim.rgb * s * 0.18;
	ALBEDO = c;
	ALPHA = clamp(pow(f, power * 0.6) * 1.2 + 0.18 + s * 0.12, 0.0, 1.0) * alpha;
}
