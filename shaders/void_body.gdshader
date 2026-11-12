shader_type spatial;
// The Empty's bare body: a window into the void. A deep fill with drifting stars fixed to the screen, so the whole
// silhouette reads as one cut-out of night sky, and a soft lit edge in the outline colour (the ink line itself is the
// next pass, outline.gdshader). Smooth and featureless: no shading detail, nothing anatomical.
render_mode unshaded, shadows_disabled, cull_back, depth_draw_opaque, blend_mix;

uniform vec4 deep : source_color = vec4(0.03, 0.02, 0.07, 1.0);     // the void's fill (the creator's body tint)
uniform vec4 edge : source_color = vec4(0.55, 0.85, 1.0, 1.0);      // the lit rim, in the outline colour
uniform float stars = 1.0;              // star density
uniform float rim = 0.6;                // how bright the lit edge is
uniform float scale = 9.0;              // star cells across the screen's height

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// One layer of stars on a grid of cells: a soft dot in some cells, twinkling slowly.
float star_layer(vec2 p, float cells, float seed) {
	vec2 g = p * cells;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id + seed);
	if (h > 0.22 * stars) {
		return 0.0;
	}
	vec2 off = vec2(hash(id + seed + 3.1), hash(id + seed + 7.7)) - 0.5;
	float d = length(f - off * 0.6);
	float tw = 0.65 + 0.35 * sin(TIME * (0.6 + h * 2.0) + h * 40.0);
	return smoothstep(0.09, 0.0, d) * tw;
}

void fragment() {
	vec2 view = VIEWPORT_SIZE;
	vec2 p = SCREEN_UV * vec2(view.x / view.y, 1.0) * scale;
	p += vec2(TIME * 0.006, TIME * 0.003);
	float s = star_layer(p, 1.0, 1.0) + star_layer(p, 1.7, 5.0) * 0.7 + star_layer(p, 2.9, 9.0) * 0.45;
	float nebula = 0.5 + 0.5 * sin(p.x * 0.7 + sin(p.y * 0.9 + TIME * 0.05) * 1.6);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec3 col = deep.rgb + edge.rgb * (0.05 * nebula);
	col += mix(vec3(1.0), edge.rgb, 0.3) * s;
	col = mix(col, edge.rgb, fres * rim);
	ALBEDO = col;
}
