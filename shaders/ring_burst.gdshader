shader_type spatial;
// A burst's ground ring (Fx.ring) in the cel look: a hard band with a hot lead edge racing out to the quad's reach,
// a flash of dust inside, breaking up as it spends. Premultiplied like the Hero looks (hero_vfx.gdshader M_RING).
render_mode blend_premul_alpha, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/cel.gdshaderinc"

uniform vec4 color : source_color = vec4(1.0);    // the body; its alpha is the fade
uniform float go = 0.0;       // 0..1 how far the band has raced out
uniform float spent = 0.0;    // 0..1 through the burst: the band breaks up
uniform float seed = 0.0;     // turns the noise round, so two rings don't break the same way

void fragment() {
	vec2 ring_v = cel_ring(UV, go, spent, seed);
	float d = length(UV * 2.0 - 1.0);
	float fill = hard(go * 0.9 - mix(0.2, 0.03, go) - d) * 0.25 * (1.0 - hard(spent - 0.35));
	float a = (ring_v.x + fill * (1.0 - ring_v.x)) * color.a;
	vec3 hot = mix(color.rgb, vec3(1.0), 0.5);
	vec3 c = mix(color.rgb, hot, ring_v.y);
	ALBEDO = c * a;
	ALPHA = a;
}
