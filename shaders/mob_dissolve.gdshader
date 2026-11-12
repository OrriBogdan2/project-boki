shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;
// A dying monster: one tinted silhouette whose body eats away on a noise field (low to high, so it
// goes from the feet up) with a hot rim where it is being eaten. `k` runs 0 (whole) to 1 (gone).
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform float k : hint_range(0.0, 1.0) = 0.0;
uniform float height = 1.5;     // m, the model's height (the eaten line climbs this far)
uniform vec3 origin;            // where it fell, so the pattern stays put if the body drifts
varying vec3 lpos;
#include "res://shaders/noise.gdshaderinc"

void vertex() {
	lpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - origin;
}

void fragment() {
	float n = fbm3(lpos.xz * 3.1 + lpos.y * 2.3);
	float climb = clamp(lpos.y / height, 0.0, 1.0);
	float gone = k * 1.5 - (0.5 * climb + n * 0.5);
	if (gone > 0.0) discard;
	float rim = smoothstep(-0.16, 0.0, gone);
	ALBEDO = tint.rgb * (1.0 - rim);
	EMISSION = edge.rgb * rim * 2.2;
}
