shader_type canvas_item;
render_mode blend_disabled;
// The painted full map (M) and minimap, baked once per map from the tile data (see map_paint.gd):
// smooth island outlines with an ink line, cliff rims (pale where you can grab, slate where it's
// sheer), soft hill shading by terrace height, worn paths, tree and rock clumps, ruin walls, and the
// cloud sea below with each island's shadow. UV 0..1 spans the whole map.

uniform sampler2D col_tex : filter_linear, repeat_disable;    // rgb ground colour, a land
uniform sampler2D info_tex : filter_linear, repeat_disable;   // r height, g path, b trees/rocks, a walls
uniform sampler2D rim_tex : filter_linear, repeat_disable;    // r sheer rim, g grabbable rim, b tall grass, a bridge
uniform vec2 tiles = vec2(216.0, 216.0);
uniform vec3 sea_deep : source_color = vec3(0.04, 0.05, 0.12);
uniform vec3 sea_light : source_color = vec3(0.17, 0.2, 0.38);
uniform vec3 ink : source_color = vec3(0.07, 0.06, 0.12);
uniform vec3 path_col : source_color = vec3(0.9, 0.81, 0.6);
uniform vec3 wall_col : source_color = vec3(0.9, 0.87, 0.8);
uniform vec3 sheer_col : source_color = vec3(0.32, 0.29, 0.44);
uniform vec3 lip_col : source_color = vec3(0.95, 0.88, 0.7);
uniform vec3 bridge_col : source_color = vec3(0.72, 0.55, 0.36);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm3(vec2 p) {
	float s = 0.0; float a = 0.5;
	for (int i = 0; i < 3; i++) { s += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return s / 0.875;
}
float fbm(vec2 p) {
	float s = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { s += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return s;
}

// t in tiles. A 3x3 tent of bilinear taps: tile corners round off into smooth coasts.
vec4 soft(sampler2D tx, vec2 t, float r) {
	vec4 s = vec4(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			float wg = (x == 0 && y == 0) ? 4.0 : ((x == 0 || y == 0) ? 2.0 : 1.0);
			s += wg * texture(tx, (t + vec2(float(x), float(y)) * r) / tiles);
		}
	}
	return s / 16.0;
}

void fragment() {
	vec2 t = UV * tiles;
	// a little painterly wobble on every edge
	vec2 wob = vec2(fbm3(t * 0.3), fbm3(t * 0.3 + 17.3)) - 0.5;
	vec2 tw = t + wob * 0.7;
	float px = tiles.x * fwidth(UV.x);                      // tiles per output pixel
	float aa = max(px * 0.75, 0.02);

	// ---- the sea of cloud below, with each island's shadow and a pale haze hugging the coasts
	float cl = fbm(t * 0.06 + vec2(3.1, 7.7));
	float cl2 = fbm(t * 0.17 - vec2(5.2, 1.3));
	vec3 sea = mix(sea_deep, sea_light, smoothstep(0.25, 0.85, cl * 0.75 + cl2 * 0.35));
	float shadow = soft(col_tex, tw - vec2(1.1, 1.6), 1.2).a;
	sea *= 1.0 - 0.55 * smoothstep(0.15, 0.7, shadow);
	float haze = soft(col_tex, tw, 2.6).a;
	sea = mix(sea, sea_light * 1.25, 0.22 * smoothstep(0.02, 0.4, haze) * (1.0 - smoothstep(0.4, 0.6, haze)));
	vec2 vc = UV - 0.5;
	sea *= 1.0 - 0.55 * dot(vc, vc);

	// ---- land
	float mask = soft(col_tex, tw, 0.55).a;
	float land = smoothstep(0.5 - aa, 0.5 + aa, mask);
	vec4 cs = soft(col_tex, tw, 0.45);
	vec3 base = cs.rgb / max(cs.a, 0.05);
	vec4 info = soft(info_tex, tw, 0.5);
	// hill shading by terrace height, lit from the upper left like the 3D sun
	float e = 0.9;
	float hx = soft(info_tex, tw + vec2(e, 0.0), 0.5).r - soft(info_tex, tw - vec2(e, 0.0), 0.5).r;
	float hz = soft(info_tex, tw + vec2(0.0, e), 0.5).r - soft(info_tex, tw - vec2(0.0, e), 0.5).r;
	vec3 n = normalize(vec3(-hx * 9.0, 1.0, -hz * 9.0));
	float lit = dot(n, normalize(vec3(-0.55, 0.75, -0.45)));
	float slope = length(vec2(hx, hz));
	vec3 col = base * (0.86 + 0.32 * lit);
	// terrace edges read as soft painted cliffs
	col = mix(col, col * 0.62, smoothstep(0.035, 0.11, slope) * 0.75);
	col *= 0.97 + 0.08 * (fbm(t * 0.9) - 0.5);
	// worn paths
	float path = smoothstep(0.3, 0.62, info.g + (fbm(t * 1.4) - 0.5) * 0.25);
	col = mix(col, path_col * (0.9 + 0.12 * lit), path * 0.85);
	// tall grass to hide in: darker, streaky
	vec4 rim = soft(rim_tex, tw, 0.5);
	float tg = smoothstep(0.3, 0.6, rim.b);
	col = mix(col, col * vec3(0.7, 0.82, 0.68), tg * (0.6 + 0.4 * sin(t.x * 5.0 + t.y * 3.0 + fbm(t * 2.0) * 4.0)));
	// clumps of trees and rocks: soft round blobs with a shadow below-right
	float fo = info.b + (fbm(t * 2.3) - 0.5) * 0.35;
	float blob = smoothstep(0.32, 0.5, fo);
	float bsh = smoothstep(0.3, 0.55, soft(info_tex, t - vec2(0.35, 0.45), 0.5).b);
	col *= 1.0 - 0.3 * bsh * (1.0 - blob);
	vec3 leaf = base * vec3(0.62, 0.72, 0.58);
	col = mix(col, leaf * (0.82 + 0.35 * smoothstep(0.4, 0.8, fo)), blob);
	// bridges
	col = mix(col, bridge_col, smoothstep(0.35, 0.6, rim.a));
	// ruin walls: crisp pale stone with a dark edge
	float wv = texture(info_tex, t / tiles).a;
	float wl = smoothstep(0.42 - aa * 0.4, 0.58 + aa * 0.4, wv);
	float we = smoothstep(0.22, 0.4, wv);
	col = mix(col, ink, we * (1.0 - wl) * 0.8);
	col = mix(col, wall_col, wl);
	// the rim of the cliff just inside the coast: pale where you can grab it, slate where it's sheer
	float band = smoothstep(0.5, 0.5 + aa, mask) * (1.0 - smoothstep(0.62, 0.72, mask));
	vec3 rim_c = mix(col * 0.7, lip_col, smoothstep(0.15, 0.4, rim.g));
	rim_c = mix(rim_c, sheer_col, smoothstep(0.15, 0.4, rim.r));
	col = mix(col, rim_c, band * 0.9);

	vec3 outc = mix(sea, col, land);
	// an ink line round every coast
	float line = 1.0 - smoothstep(0.0, aa * 1.6 + 0.03, abs(mask - 0.5));
	outc = mix(outc, ink, line * 0.85);
	// paper grain
	outc *= 0.975 + 0.05 * hash(floor(UV * 2048.0));
	COLOR = vec4(outc, 1.0);
}
