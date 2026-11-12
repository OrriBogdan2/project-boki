shader_type spatial;
// The Blight's wall (BlightWall): a tall band of crimson light on the tide ring. UV.y runs 0 at the
// foot of the mesh to 1 at its top, UV.x once round the ring. `rich` 0 is the cheap look (a flat
// gradient, nothing else): the low preset; 1 adds drifting bands.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;
uniform vec4 color : source_color = vec4(0.22, 0.02, 0.2, 1.0);       // the body: dark plum, against a red sky and the pale sea alike
uniform vec4 hot : source_color = vec4(1.0, 0.3, 0.5, 1.0);          // the glowing foot
uniform float rich = 0.0;
uniform float ground = 0.33;      // where the island ground sits on UV.y
uniform float ring_m = 400.0;     // the ring's length in metres: keeps the bands one size as it shrinks
varying float h;
void vertex() {
	h = UV.y;
}
void fragment() {
	float up = clamp((h - ground) / (1.0 - ground), 0.0, 1.0);
	float body = (1.0 - smoothstep(0.3, 1.0, up)) * smoothstep(0.0, ground, h);
	float foot = exp(-pow((h - ground) * 16.0, 2.0));
	float a = 0.6 * body + 0.5 * foot;
	if (rich > 0.5) {
		float u = UV.x * ring_m;
		a *= 0.7 + 0.3 * sin(u * 0.35 + TIME * 0.7 + h * 9.0) * sin(u * 0.11 - TIME * 0.45);
	}
	a *= smoothstep(3.0, 14.0, length(VERTEX));     // fades out as the camera goes through it
	ALBEDO = mix(color.rgb, hot.rgb, foot);
	ALPHA = clamp(a, 0.0, 0.75);
}
