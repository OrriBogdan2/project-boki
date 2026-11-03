shader_type spatial;
// Sable's and Juggernaut's own effect looks (scripts/arch/kits/dj_fx.gd), one shader, a mode each:
//   0 star     a camera-facing four-point star round a hot core (Sable's knock, tip hits)
//   1 pillar   a rising column of light, UV.y up the side (the knock heal)
//   2 comet    a streak along UV.x (0 = head), soft across UV.y (bolt and dagger trails)
//   3 crescent a two-tone blade arc: UV.x along the sweep, UV.y from the edge (0) inward (1);
//              color is the outer edge, color2 the inner fill; progress sweeps it
//   4 puff     a camera-facing soft ring that opens and fades (a bolt fizzling at the cursor)
//   5 links    a chain: alternating bright and dark links along UV.x (stripes = links per metre * length)
//   6 bolt     a jagged lightning ribbon along UV.x (the empowered shot)
// life runs 0 -> 1 over the effect. This one is additive: glows, cores and sparks. Colour and darkness
// that must hold up on bright ground use dj_fx_mix.gdshader (the same looks, alpha blended).
render_mode unshaded, shadows_disabled, depth_draw_never, blend_add, cull_disabled, fog_disabled;
#include "res://shaders/dj_fx.gdshaderinc"

void fragment() {
	ALBEDO = dj_look(UV).rgb * color.a;
	ALPHA = 1.0;
}
