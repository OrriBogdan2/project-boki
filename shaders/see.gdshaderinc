// See-through props: a tree, pillar or boulder standing between the camera and your own hunter (or
// your Boki) thins out to a light stipple, so you never lose yourself behind a canopy, as in most
// top-down games. Each instance is tested as one sphere (its canopy or bulk): see_y is the sphere's
// centre height and see_r its radius, in the mesh's own metres (0 radius: this material never thins).
// Set every frame by SeeThrough.update (scripts/match/see_through.gd); see_a.w / see_b.w are 0 when off.
global uniform vec3 see_cam;
global uniform vec4 see_a;   // xyz: your hunter's feet; w: 1 when on
global uniform vec4 see_b;   // xyz: your Boki's feet; w: 1 when it's out
uniform float see_y = 0.0;
uniform float see_r = 0.0;

// How much a sphere (centre c, radius r) hides the point t from the camera: 1 when the line of
// sight runs through it and its near side is in front of t, easing to 0 at its edge.
float see_hides(vec3 c, float r, vec3 t) {
	vec3 ray = t - see_cam;
	float len = max(length(ray), 0.001);
	vec3 dir = ray / len;
	float along = dot(c - see_cam, dir);
	float off = length((c - see_cam) - dir * along);
	float front = along - r;            // where the sphere starts along the line of sight
	return (1.0 - smoothstep(r * 0.85, r + 0.75, off)) * smoothstep(0.0, 0.6, len - front - 0.35);
}

// 0..1 for this instance (call from vertex(): the same for every vertex of one prop).
float see_fade(mat4 model) {
	if (see_r <= 0.0 || (see_a.w < 0.5 && see_b.w < 0.5)) { return 0.0; }
	float s = length(model[0].xyz);
	float sy = length(model[1].xyz);
	vec3 c = model[3].xyz + vec3(0.0, see_y * sy, 0.0);
	float r = see_r * s;
	float f = 0.0;
	if (see_a.w > 0.5) {
		f = max(see_hides(c, r, see_a.xyz + vec3(0.0, 0.45, 0.0)), see_hides(c, r, see_a.xyz + vec3(0.0, 1.55, 0.0)));
	}
	if (see_b.w > 0.5) {
		f = max(f, see_hides(c, r, see_b.xyz + vec3(0.0, 0.45, 0.0)));
	}
	return f;
}

// Fragment side: true for the share of pixels to drop, in a fine, stable stipple (no sorting, keeps
// depth): `if (see_cut(k, FRAGCOORD.xy)) { discard; }`.
bool see_cut(float fade, vec2 frag) {
	if (fade <= 0.01) { return false; }
	float n = fract(52.9829189 * fract(dot(floor(frag), vec2(0.06711056, 0.00583715))));
	return n < fade * 0.88;
}
