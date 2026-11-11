// See-through props: where a tree's canopy or a ruin pillar stands between the camera and your own
// hunter (or your Boki), only the pixels right over them dither to half, in a small soft circle, so
// you can always find yourself without the forest vanishing. Pixels behind you, beside you or
// outside the circle stay solid, and bark (UV.x material 1, trunks and boughs) never thins.
// see_on marks the materials that may thin (Flora.SEE). Set every frame by SeeThrough.update
// (scripts/match/see_through.gd); see_a.w / see_b.w are 0 when off.
global uniform vec3 see_cam;
global uniform vec4 see_a;   // xyz: your hunter's feet; w: 1 when on
global uniform vec4 see_b;   // xyz: your Boki's feet; w: 1 when it's out
uniform bool see_on = false;

const float SEE_MAX = 0.5;        // share of pixels dropped at the circle's heart: half, never gone
const float SEE_A_Y = 0.85;       // m above the hunter's feet the circle is centred on (mid-body)
const float SEE_A_R = 0.9;        // m: the circle's radius at the hunter's distance (head to feet from above)
const float SEE_B_Y = 0.35;       // m: the same for a Boki
const float SEE_B_R = 0.6;
const float SEE_EDGE = 0.4;       // m the circle's edge softens over
const float SEE_FRONT = 0.35;     // m a pixel must be nearer the camera than the target to thin
const float SEE_BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

// 0..1: how much the pixel at world point p covers the point t from the camera, inside a circle of
// radius r around t (measured at t's distance, so it is a fixed size on screen).
float see_cover(vec3 p, vec3 t, float r) {
	vec3 ray = t - see_cam;
	float len = max(length(ray), 0.001);
	vec3 dir = ray / len;
	vec3 v = p - see_cam;
	float along = dot(v, dir);
	float off = length(v - dir * along) * len / max(along, 0.05);
	float front = smoothstep(SEE_FRONT, SEE_FRONT + 0.5, len - along);
	return (1.0 - smoothstep(r - SEE_EDGE, r, off)) * front;
}

// Fragment side: true for the pixels to drop, in a 4x4 ordered dither (no sorting, keeps depth):
// `if (see_cut(wpos, mat_id, FRAGCOORD.xy)) { discard; }`.
bool see_cut(vec3 p, float mat_id, vec2 frag) {
	if (!see_on || int(mat_id + 0.5) == 1 || (see_a.w < 0.5 && see_b.w < 0.5)) { return false; }
	float f = 0.0;
	if (see_a.w > 0.5) { f = see_cover(p, see_a.xyz + vec3(0.0, SEE_A_Y, 0.0), SEE_A_R); }
	if (see_b.w > 0.5) { f = max(f, see_cover(p, see_b.xyz + vec3(0.0, SEE_B_Y, 0.0), SEE_B_R)); }
	if (f <= 0.01) { return false; }
	ivec2 q = ivec2(frag) & ivec2(3);
	return (SEE_BAYER[q.y * 4 + q.x] + 0.5) / 16.0 < f * SEE_MAX;
}
