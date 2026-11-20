shader_type spatial;
// Albert's raised aegis (AegisWall): a translucent gold wall, drawn as four surfaces of one mesh (`kind`): 0 the
// outer sheet, 1 a brighter inner sheet a hand inside it (the layering), 2 the lit rim on top, 3 the soft ground
// contact. UV.x runs once along the arc, UV.y 0 at the foot / near edge to 1 at the top / far edge. Both faces are
// drawn alike, so the wall reads from either side.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 albedo : source_color = vec4(0.96, 0.89, 0.66, 1.0);     // the body gold (bulwark.json slab)
uniform vec4 rim_color : source_color = vec4(1.0, 0.94, 0.69, 1.0);   // his ivory (Arch.color)
uniform float kind = 0.0;
uniform float glow = 0.3;          // 0.3 at rest, up to ~1.6 on a block, pulsing when armed
uniform float plates = 7.0;        // seams along the arc
uniform float arc_m = 4.8;         // the wall's length in metres (keeps the seams one width)

void fragment() {
	vec2 uv = vec2(UV.x, kind < 1.5 ? 1.0 - UV.y : UV.y);     // (KitMeshes.wall has v 0 at the top)
	float ends = smoothstep(0.0, 0.05, uv.x) * smoothstep(1.0, 0.95, uv.x);
	float flash = clamp(glow - 0.3, 0.0, 1.3);
	vec3 col = albedo.rgb;
	float a = 0.0;
	if (kind < 0.5) {
		// the outer sheet: a pale body, deeper gold low down, seams between the plates, a hammer cross in the middle
		float seam = 1.0 - smoothstep(0.0, 0.022, abs(fract(uv.x * plates) - 0.5) - 0.48 + 0.022);
		float band = 1.0 - smoothstep(0.0, 0.02, abs(uv.y - 0.5) - 0.012);
		float cx = abs(uv.x - 0.5) * arc_m;
		float dy = (uv.y - 0.5) * 1.7;
		float cross_m = max(step(cx, 0.06) * step(abs(dy), 0.3), step(abs(dy - 0.12), 0.05) * step(cx, 0.22));
		col = mix(albedo.rgb * vec3(0.97, 0.82, 0.4), albedo.rgb * vec3(1.0, 0.97, 0.85), smoothstep(0.0, 0.85, uv.y));
		col = mix(col, albedo.rgb * vec3(0.78, 0.6, 0.22), max(seam, band) * 0.85);
		col = mix(col, rim_color.rgb, cross_m * 0.9);
		a = mix(0.7, 0.42, uv.y) + max(seam, band) * 0.2 + cross_m * 0.3;
		a *= smoothstep(0.0, 0.04, uv.y);
	} else if (kind < 1.5) {
		// the inner sheet: shorter and brighter at its top edge, clear low down, so two layers show through each other
		col = mix(albedo.rgb * vec3(1.0, 0.9, 0.6), rim_color.rgb, uv.y);
		a = (0.15 + 0.55 * smoothstep(0.45, 1.0, uv.y)) * (1.0 - smoothstep(0.96, 1.0, uv.y));
	} else if (kind < 2.5) {
		// the rim on top: a lit ivory bar with a hot centre line
		float c = 1.0 - abs(uv.y - 0.5) * 2.0;
		col = mix(rim_color.rgb, vec3(1.0), smoothstep(0.35, 1.0, c) * 0.6);
		a = 0.9 * smoothstep(0.0, 0.25, c);
	} else {
		// the ground contact: brightest at the foot, a soft falloff both ways, gone at the ends
		float foot = exp(-pow((uv.y - 0.33) * 3.6, 2.0));
		col = mix(albedo.rgb * vec3(1.0, 0.86, 0.5), rim_color.rgb, foot * 0.5);
		a = 0.9 * foot;
	}
	a *= ends;
	col = mix(col, vec3(1.0), flash * 0.35) * (1.0 + flash * 0.25);
	ALBEDO = col;
	ALPHA = clamp(a * (1.0 + flash * 0.4), 0.0, 1.0);
}
