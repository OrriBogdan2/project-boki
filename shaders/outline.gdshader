shader_type spatial;
// Ink outline drawn from the inside of a slightly grown copy. It grows with distance so the line
// stays about the same thickness on screen, close up or zoomed out.
render_mode unshaded, cull_front, shadows_disabled;
uniform vec4 color : source_color = vec4(0.08, 0.065, 0.12, 1.0);
uniform float width = 0.00125;
// a Warden's 3D model (WardenGlb): the vertex colour's alpha is how far the line may grow there (x INK_ROOM m)
// before it pokes through a thin or folded part
uniform bool ink_mask = false;
// a painted model's line at the match camera: this much thinner from ~8 to 18 m away (every belt, buckle and strand
// outlined at ~1 px added up to dark speckle along the silhouette)
uniform float far_thin = 0.0;
// and gone past this share of the 8 to 18 m fade (0: never): a sub-pixel shell only shows as dark dots where the
// silhouette's triangles poke through it, so the signature rim (hero_toon far_rim_soft) carries the edge there.
// (far_cut and the glow shell go by the size on screen, as hero_toon's match_d: in match-camera metres, so a
// close-up camera far off with a narrow lens keeps the line)
uniform float far_cut = 0.0;
// A glow piece's halo at the match camera (WardenGlb, the glow slot's own shell): the shell in the piece's painted
// colour (glow_tex x glow_col x glow_k), glow_px screen pixels wide, growing in from glow_near to glow_far m away
// and none closer (close-ups keep the lens itself): a 3 cm lens or a thin crack reads as a glow, not one pixel.
uniform bool glow_shell = false;
uniform sampler2D glow_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 glow_col : source_color = vec4(1.0);
uniform float glow_k = 1.3;
uniform float glow_px = 1.4;    // (pixels of a 720 px tall view)
uniform float glow_near = 7.0;
uniform float glow_far = 14.0;
const float INK_ROOM = 0.02;
varying float far_d;
void vertex() {
	float d = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	// one pixel of a 720 px tall view at d, in metres (perspective; an orthographic camera's is constant), and the
	// distance at which the match camera's 32 degree lens sees a pixel that size (VIEWPORT_SIZE is not set here on
	// the compatibility renderer)
	float px = PROJECTION_MATRIX[3][3] > 0.5 ? 2.0 / (abs(PROJECTION_MATRIX[1][1]) * 720.0)
		: 2.0 * d / (abs(PROJECTION_MATRIX[1][1]) * 720.0);
	far_d = px * 1255.3;
	float w = clamp(d * width, 0.0042, 0.034);
	if (glow_shell) {
		w = glow_px * px * smoothstep(glow_near, glow_far, far_d);
	} else {
		if (ink_mask) { w = min(w, COLOR.a * INK_ROOM); }
		w *= 1.0 - far_thin * smoothstep(8.0, 18.0, d);
	}
	VERTEX += NORMAL * w;
}
void fragment() {
	if (glow_shell) {
		if (far_d < glow_near) { discard; }
		ALBEDO = min(texture(glow_tex, UV).rgb * glow_col.rgb * glow_k, vec3(1.0));
	} else {
		if (far_cut > 0.0 && smoothstep(8.0, 18.0, far_d) >= far_cut) { discard; }
		ALBEDO = color.rgb;
	}
}
