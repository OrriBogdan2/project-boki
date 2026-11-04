shader_type spatial;
// Ink outline drawn from the inside of a slightly grown copy. It grows with distance so the line
// stays about the same thickness on screen, close up or zoomed out.
render_mode unshaded, cull_front, shadows_disabled;
uniform vec4 color : source_color = vec4(0.08, 0.065, 0.12, 1.0);
uniform float width = 0.00125;
// a Warden's 3D model (WardenGlb): the vertex colour's alpha is how far the line may grow there (x INK_ROOM m)
// before it pokes through a thin or folded part
uniform bool ink_mask = false;
const float INK_ROOM = 0.02;
void vertex() {
	float d = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	float w = clamp(d * width, 0.0042, 0.034);
	if (ink_mask) { w = min(w, COLOR.a * INK_ROOM); }
	VERTEX += NORMAL * w;
}
void fragment() { ALBEDO = color.rgb; }
