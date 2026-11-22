shader_type spatial;
// The Blight's wall (BlightWall): a tall band of crimson light on the tide ring. UV.y runs 0 at the
// foot of the mesh to 1 at its top, UV.x once round the ring. It has to say where safety is and which
// way the ring moves without filling the screen: a thin, bright line where the ground ends (the edge),
// a body that leans in over the safe side and thins out with distance, and (rich) light that falls down
// the face toward the foot. `rich` 0 is the cheap look (no streaks, no pulse): the low preset.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;
uniform vec4 color : source_color = vec4(0.22, 0.02, 0.2, 1.0);       // the body: dark plum, against a red sky and the pale sea alike
uniform vec4 hot : source_color = vec4(1.0, 0.45, 0.58, 1.0);        // the glowing foot line
uniform float rich = 0.0;
uniform float ground = 0.33;      // where the island ground sits on UV.y
uniform float height_m = 90.0;    // the mesh's height in metres (UV.y 0..1)
uniform float ring_m = 400.0;     // the ring's length in metres: keeps the bands one size as it shrinks
uniform float lean = 0.15;        // metres the wall leans in per metre of height: it closes over the safe side
uniform float body_a = 0.3;      // the body's opacity near the camera
uniform float far_k = 0.4;        // the body's share of that far away (the slab never fills the sky)
uniform float outside_k = 0.4;   // the body's share seen from outside the ring (you already know you are out)
varying float h;
varying float inside;
void vertex() {
	h = UV.y;
	float radius = ring_m / TAU;
	VERTEX.xz *= 1.0 - lean * max(h - ground, 0.0) * height_m / radius;
	vec3 cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	inside = step(length(cam.xz), 1.0);
}
void fragment() {
	float d = length(VERTEX);
	float up = clamp((h - ground) / (1.0 - ground), 0.0, 1.0);
	float up_m = max(h - ground, 0.0) * height_m;
	float dist_k = mix(1.0, far_k, smoothstep(35.0, 150.0, d));
	float body = (1.0 - smoothstep(0.0, 0.5, up)) * smoothstep(0.0, ground, h);
	body *= body_a * dist_k * mix(outside_k, 1.0, inside);
	float edge = h - ground;
	float line = exp(-pow(edge * 90.0, 2.0));       // the crisp edge, about a metre wide
	float halo = exp(-pow(edge * 22.0, 2.0));       // the glow round it
	float pulse = 1.0;
	if (rich > 0.5) {
		float u = UV.x * ring_m;
		float column = 0.5 + 0.5 * sin(u * 0.7 + 3.0 * sin(u * 0.13));
		float fall = pow(0.5 + 0.5 * sin(up_m * 0.22 + TIME * 1.6 + u * 0.05), 3.0);   // crests run down to the foot
		body *= 0.7 + 0.8 * column * fall;
		pulse = 0.85 + 0.15 * sin(TIME * 3.0);
	}
	float a = body + 0.2 * halo + 0.6 * line * pulse;
	a *= smoothstep(3.0, 14.0, d);                  // fades out as the camera goes through it
	ALBEDO = mix(color.rgb, hot.rgb, clamp(halo * 0.3 + line, 0.0, 1.0));
	ALPHA = clamp(a, 0.0, 0.85);
}
