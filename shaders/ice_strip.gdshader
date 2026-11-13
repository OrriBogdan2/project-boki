shader_type spatial;
// Claire's skate trail (IceStrip): every plate of the trail is one instance of one MultiMesh. A flat cel-lit plate
// of pale ice with a ragged edge, a faint frost band along its rim, one lighter facet step, and a melt: it keeps
// full strength for the first third of its life, then fades in ragged cel steps. Per instance custom data:
// x = born (s of match time), y = life (s), z = a seed that moves the noise so plates don't repeat.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
#include "res://shaders/cel.gdshaderinc"
uniform vec4 color : source_color = vec4(0.75, 0.97, 0.94, 0.7);
uniform vec4 edge : source_color = vec4(0.91, 1.0, 1.0, 1.0);
uniform float now = 0.0;          // match time, set once a step
varying vec3 plate;
void vertex() {
	plate = INSTANCE_CUSTOM.xyz;
	float k = clamp((now - plate.x) / plate.y, 0.0, 1.0);
	VERTEX.xz *= mix(0.6, 1.0, clamp(k * 15.0, 0.0, 1.0));    // frozen in under the blade at once
}
void fragment() {
	float k = clamp((now - plate.x) / plate.y, 0.0, 1.0);
	float fade = 1.0 - smoothstep(0.3, 1.0, k);
	vec2 p = abs(UV * 2.0 - 1.0);
	float d = pow(pow(p.x, 4.0) + pow(p.y, 4.0), 0.25);
	vec3 n = texture(vfx_noise, UV * vec2(1.5, 1.0) + plate.z).rgb;
	float inside = hard(1.0 - d + (n.g - 0.5) * 0.14);
	float frost = hard(d - 0.74 + (n.g - 0.5) * 0.1);
	float facet = hard(n.b - 0.55);
	vec3 c = mix(color.rgb, edge.rgb, max(frost * 0.7, facet * 0.25));
	ALBEDO = c;
	float a = cel_cover(fade * (color.a + frost * 0.25), UV * 0.5 + plate.z);
	ALPHA = inside * a;
}
