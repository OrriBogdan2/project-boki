shader_type spatial;
// Albert's raised aegis (AegisWall): his figurehead hatch shield (art-refs/albert_hero_1114 turnaround) grown into a
// curved wall: dark hull planks with a carved panel in the middle, an iron frame, strap and rivets, and the sea's
// cyan light glowing in the gaps between the planks (as on his body). Four surfaces of one mesh (`kind`): 0 the
// planked face, 1 the boards' darker back a hand inside it, 2 the iron rim along the top, 3 the soft ground contact. UV.x runs once along the arc, UV.y 0 at
// the foot / near edge to 1 at the top / far edge. Both faces are drawn alike, so the wall reads from either side.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 albedo : source_color = vec4(0.48, 0.31, 0.2, 1.0);      // the planks (bulwark.json wood)
uniform vec4 rim_color : source_color = vec4(0.44, 0.42, 0.39, 1.0);  // the iron frame (bulwark.json band)
uniform vec4 sea : source_color = vec4(0.12, 0.88, 0.8, 1.0);         // the light between the planks (model_glow core)
uniform float kind = 0.0;
uniform float glow = 0.3;          // 0.3 at rest, up to ~1.6 on a block
uniform float plank_m = 0.36;      // a plank's width (m)
uniform float arc_m = 4.8;         // the wall's length in metres (keeps the planks one width)
uniform float height_m = 1.7;      // the wall's height in metres (keeps the iron one width)

float hash(float n) {
	return fract(sin(n * 91.345) * 47453.21);
}

void fragment() {
	vec2 uv = vec2(UV.x, kind < 1.5 ? 1.0 - UV.y : UV.y);     // (KitMeshes.wall has v 0 at the top)
	float ends = smoothstep(0.0, 0.03, uv.x) * smoothstep(1.0, 0.97, uv.x);
	float flash = clamp(glow - 0.3, 0.0, 1.3);
	vec3 col = albedo.rgb;
	float a = 0.0;
	if (kind < 0.5) {
		vec2 m = vec2(uv.x * arc_m, uv.y * height_m);       // metres along the arc and up
		float cx = (uv.x - 0.5) * arc_m;
		// the planks: each its own shade, a grain running up it, a dark gap between them with the sea light in it
		float pid = floor(m.x / plank_m);
		float px = fract(m.x / plank_m);
		float grain = 0.5 + 0.5 * sin(m.y * 7.0 + sin(m.y * 2.3 + pid * 4.1) * 2.5 + px * 3.0);
		col = albedo.rgb * (0.82 + 0.3 * hash(pid)) * (0.88 + 0.16 * grain);
		col *= mix(0.72, 1.08, smoothstep(0.0, 0.9, uv.y));   // darker at the foot, lit at the top
		float gap = 1.0 - smoothstep(0.02, 0.05, min(px, 1.0 - px));
		// the carved figurehead panel in the middle: lighter raised wood, a dark cut round its edge
		float panel = length(vec2(cx / 0.42, (uv.y - 0.52) / 0.36));
		float carved = 1.0 - smoothstep(0.92, 1.0, panel);
		float cut = smoothstep(0.86, 0.96, panel) * (1.0 - smoothstep(1.0, 1.1, panel));
		col = mix(col, albedo.rgb * vec3(1.35, 1.25, 1.12) * (0.9 + 0.1 * grain), carved);
		col = mix(col, albedo.rgb * 0.35, cut * 0.8);
		gap *= 1.0 - carved;
		col = mix(col, mix(albedo.rgb * 0.3, sea.rgb, 0.18), gap);
		// the iron: a frame round the edge, a strap across the middle (broken by the panel) and rivets on them
		float edge = min(min(m.x, arc_m - m.x), min(m.y, height_m - m.y));
		float frame = 1.0 - smoothstep(0.1, 0.13, edge);
		float strap = (1.0 - smoothstep(0.05, 0.07, abs(m.y - height_m * 0.3))) * step(0.98, panel);
		float iron = max(frame, strap);
		vec2 rv = vec2(fract(m.x / 0.3) - 0.5, 0.0) * 0.3;
		float on_line = min(abs(m.y - height_m * 0.3), min(abs(m.y - 0.055), abs(m.y - height_m + 0.055)));
		float rivet = (1.0 - smoothstep(0.022, 0.034, length(vec2(rv.x, on_line)))) * step(0.98, panel);
		col = mix(col, rim_color.rgb * (0.85 + 0.25 * smoothstep(0.0, 1.0, uv.y)), iron);
		col = mix(col, rim_color.rgb * 1.6, rivet);
		a = mix(0.72, 0.56, uv.y) + iron * 0.2;
		a *= smoothstep(0.0, 0.03, uv.y);
		col += sea.rgb * gap * flash * 0.8;
	} else if (kind < 1.5) {
		// the boards' back: plain dark planks, mostly clear so the face reads over it, the gaps faintly lit
		float px = fract(uv.x * arc_m / plank_m);
		float gap = 1.0 - smoothstep(0.03, 0.07, min(px, 1.0 - px));
		col = mix(albedo.rgb * 0.5, sea.rgb * 0.6, gap * 0.5);
		a = (0.22 + 0.2 * smoothstep(0.5, 1.0, uv.y)) * (1.0 - smoothstep(0.96, 1.0, uv.y));
	} else if (kind < 2.5) {
		// the iron rim on top: a dark bar with a lit edge
		float c = 1.0 - abs(uv.y - 0.5) * 2.0;
		col = mix(rim_color.rgb * 0.7, rim_color.rgb * 1.5, smoothstep(0.4, 1.0, c));
		a = 0.9 * smoothstep(0.0, 0.25, c);
	} else {
		// the ground contact: a soft dark-wood shadow at the foot, a thin sea glow on its line, gone at the ends
		float foot = exp(-pow((uv.y - 0.33) * 3.6, 2.0));
		col = mix(albedo.rgb * 0.45, sea.rgb, foot * foot * 0.35);
		a = 0.75 * foot;
	}
	a *= ends;
	col = mix(col, vec3(1.0), flash * 0.25) * (1.0 + flash * 0.2);
	ALBEDO = col;
	ALPHA = clamp(a * (1.0 + flash * 0.3), 0.0, 1.0);
}
