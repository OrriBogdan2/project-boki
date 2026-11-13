shader_type spatial;
// Fx.ring: a shockwave burst flat on the ground, the shared cel ring (docs/HERO_VFX.md "The cel look"): a hard band
// with a hot lead edge that runs out to the quad's rim and breaks up as it goes, and a flash of cover inside.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
#include "res://shaders/cel.gdshaderinc"
uniform vec4 color : source_color = vec4(1.0);
uniform float life = 0.0;     // 0..1 over the burst
uniform float seed = 0.0;     // moves the band's ragged edge, so two bursts at once don't match
void fragment() {
	float go = 1.0 - pow(1.0 - min(life, 1.0), 3.0);        // races out, then slows
	vec2 ring_v = cel_ring(UV, go, life, seed);
	float d = length(UV * 2.0 - 1.0);
	float fill = hard(go * 0.9 - mix(0.2, 0.03, go) - d) * 0.25 * (1.0 - hard(life - 0.35));
	float a = (ring_v.x + fill * (1.0 - ring_v.x)) * (1.0 - smoothstep(0.75, 1.0, life)) * color.a;
	if (a <= 0.001) { discard; }
	ALBEDO = mix(color.rgb, mix(color.rgb, vec3(1.0), 0.5), ring_v.y);
	ALPHA = a;
}
