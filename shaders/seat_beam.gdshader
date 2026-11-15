shader_type spatial;
// A way-out seat's column (scripts/match/seat_beacon.gd): a unit-height cylinder scaled up to its height, bright
// at the foot and fading out at the top. Mix-blended, so the same shader draws a clear beam, a squad-coloured
// one and the dark smother of a seat the Blight has taken. No particles: the only motion is a slow shimmer.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 color : source_color = vec4(1.0);
uniform float shimmer = 0.15;
varying float up;       // 0 at the foot, 1 at the top
void vertex() {
	up = clamp(VERTEX.y + 0.5, 0.0, 1.0);
}
void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a * pow(1.0 - up, 0.7) * (1.0 - shimmer * (0.5 + 0.5 * sin(TIME * 2.4 + up * 6.0)));
}
