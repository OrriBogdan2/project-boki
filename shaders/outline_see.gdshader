shader_type spatial;
// outline_smooth.gdshader for the sculpted props (Flora): the same ink line, thinned out with the prop
// over your hunter (see.gdshaderinc), so no black shell shows through the dither.
render_mode unshaded, cull_front, shadows_disabled;
uniform vec4 color : source_color = vec4(0.08, 0.065, 0.12, 1.0);
uniform float width = 0.00125;
#include "res://shaders/see.gdshaderinc"
varying vec3 wpos;
varying flat float mat_id;
void vertex() {
	float d = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	vec3 n = normalize(TANGENT);
	float s = length(MODEL_MATRIX[0].xyz);
	VERTEX += n * clamp(d * width, 0.0042, 0.034) / max(s, 0.001);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	mat_id = UV.x;
}
void fragment() {
	if (see_cut(wpos, mat_id, FRAGCOORD.xy)) { discard; }
	ALBEDO = color.rgb;
}
