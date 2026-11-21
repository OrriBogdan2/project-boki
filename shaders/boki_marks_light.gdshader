shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, diffuse_lambert, specular_disabled;
// Pale and glowing coat marks on a rigged Boki's painted coat: a lit share of the coat's own paint added on top, so
// the marks are its own colour lighter (a glowing one shines in it, a touch of the species' glow), never a flat colour.
#include "res://shaders/boki_marks.gdshaderinc"
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float light_gain = 0.8;     // how much of the coat's own colour a full mark adds
uniform vec4 mark_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float mark_glow = 0.0;

void fragment() {
	float mk = mk_mask();
	vec3 tx = texture(albedo_tex, UV).rgb;
	ALBEDO = tx * light_gain * mk;
	ROUGHNESS = 1.0;
	EMISSION = mix(tx, mark_color.rgb, 0.25) * mark_glow * 0.6 * mk;
}
