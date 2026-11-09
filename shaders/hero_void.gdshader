shader_type spatial;
render_mode unshaded, cull_back, blend_mix;
// The Void seen through a hero (WardenGlb's `void` slot, RIG_CONTRACT "Materials"): a window onto a
// starfield, not a lit surface. The painted colour (the atlas, or the part's own small texture) is the
// deep base; over it two layers of stars drift at different speeds in screen space, so the stars stay put
// while the body moves through them, as through a tear in the coat. `soft` fades the piece out toward its
// UV v = 1 (a wisp's tip) and at its silhouette, for a body that dissolves into smoke; without it the piece
// is opaque (the Void through a coat's tears).
uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_tex = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool no_fog = false;
uniform vec4 deep : source_color = vec4(0.05, 0.03, 0.14, 1.0);   // the Void's own dark, mixed under the paint
uniform float paint_k = 0.55;      // how much of the painted colour shows over the deep
uniform vec4 star_color : source_color = vec4(0.95, 0.88, 1.0, 1.0);
uniform float stars = 1.0;         // star brightness
uniform float star_scale = 46.0;   // star cells across the screen's height
uniform vec2 drift = vec2(0.012, -0.02);   // the star layers' scroll, screen heights a second
uniform bool soft = false;
uniform float fade_from = 0.72;    // soft: opaque up to this v, gone by v = 1
uniform float edge_soft = 0.6;     // soft: how much the silhouette thins out
#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/vis.gdshaderinc"

float star_layer(vec2 p, float density) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float h = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	vec2 at = vec2(fract(h * 17.13), fract(h * 31.71)) * 0.7 + 0.15;
	float d = length(f - at);
	float on = step(1.0 - density, h);
	float tw = 0.65 + 0.35 * sin(TIME * (1.5 + h * 3.0) + h * 40.0);
	return on * tw * (smoothstep(0.09, 0.0, d) + 0.25 * smoothstep(0.3, 0.0, d));
}

void fragment() {
	vec3 base = albedo.rgb;
	if (use_tex) {
		base *= texture(albedo_tex, UV).rgb;
	}
	vec3 c = mix(deep.rgb, base, paint_k);
	vec2 sp = SCREEN_UV * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
	float s1 = star_layer(sp * star_scale + TIME * drift * star_scale, 0.18);
	float s2 = star_layer(sp * star_scale * 0.55 + vec2(13.7, 4.1) + TIME * drift * star_scale * 0.45, 0.12);
	float neb = vnoise(sp * 5.0 + TIME * drift * 3.0);
	c += base * neb * 0.25;
	c += star_color.rgb * (s1 + s2 * 0.7) * stars;
	float fog = no_fog ? 0.0 : vis_fog((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	c = vis_apply(c, fog);
	ALBEDO = c * (1.0 - flash) + flash_color.rgb * flash;
	float a = 1.0;
	if (soft) {
		float nv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		a = 1.0 - smoothstep(fade_from, 1.0, UV.y);
		a *= mix(1.0, smoothstep(0.0, 0.55, nv), edge_soft);
		a *= 0.75 + 0.25 * vnoise(vec2(UV.x * 6.0, UV.y * 4.0 - TIME * 0.6));
	}
	ALPHA = clamp(a, 0.0, 1.0);
}
