shader_type spatial;
// Grimble's bone-hook arm (scripts/arch/kits/ld_fx.gd LDFx.arm and the "hook" prop): bruised purple flesh with dark
// veins and a ridge of pale bone knuckles along the top, going bone-white towards the hook. Drawn on top of walls and
// rocks too (no depth test), so the hook always reads. On the arm UV.x runs along it in metres, UV.y round it, and
// the vertex alpha is how far into the bone end a point is (a mesh with no vertex colour, the hook's pieces, is all bone).
render_mode unshaded, shadows_disabled, depth_draw_never, depth_test_disabled, blend_mix, cull_back, fog_disabled;
uniform vec4 color : source_color = vec4(0.42, 0.22, 0.62, 1.0);
uniform vec4 color2 : source_color = vec4(0.86, 0.8, 0.7, 1.0);

void fragment() {
	float lit = 0.5 + 0.5 * clamp(dot(normalize(NORMAL), normalize(vec3(-0.35, 0.65, 0.65))), -1.0, 1.0);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float vein = smoothstep(0.7, 1.0, sin(UV.x * 3.1 + sin(UV.y * 12.566) * 1.6));
	vec3 flesh = mix(color.rgb, color.rgb * 0.3, vein * 0.8) * (0.7 + 0.5 * sin(UV.x * 7.0) * 0.5 + 0.25);
	float ridge = (1.0 - smoothstep(0.04, 0.09, abs(UV.y - 0.25))) * step(0.3, fract(UV.x * 1.7));
	float b = max(COLOR.a, ridge);
	vec3 c = mix(flesh, color2.rgb, b) * lit + color.rgb * rim * 0.5;
	ALBEDO = c;
	ALPHA = 1.0;
}
