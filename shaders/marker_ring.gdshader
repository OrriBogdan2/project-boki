shader_type spatial;
// A cel ring on the ground for team markers (docs/HERO_VFX.md "The cel look"): a hard one-pixel band, ragged by the
// shared noise, with a lighter lead edge on its outer rim. Same `color` and `thickness` as ring.gdshader, so SideRings
// repaints it by colour alone (you / squad / others, and the colour-blind variants of those colours).
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix, fog_disabled;

#include "res://shaders/cel.gdshaderinc"

const float RAG = 0.02;          // how far the noise moves the band's edges (share of the radius)
const float LEAD = 0.35;         // share of the band, from the outer rim in, drawn lighter
const float LEAD_LIGHT = 0.45;   // how far towards white the lead edge goes

uniform vec4 color : source_color = vec4(1.0);
uniform float thickness = 0.16;  // band width (share of the radius)

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p) + (texture(vfx_noise, vec2(atan(p.y, p.x) / 6.2832 * 2.0, 0.6)).g - 0.5) * RAG * 2.0;
	float band = hard(min(1.0 - d, d - (1.0 - thickness)));
	if (band <= 0.001) { discard; }
	float lead = hard(d - (1.0 - thickness * LEAD));
	ALBEDO = mix(color.rgb, vec3(1.0), lead * LEAD_LIGHT);
	ALPHA = band * color.a;
}
