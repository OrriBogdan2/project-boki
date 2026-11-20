shader_type spatial;
// The silhouette of Grimble's stretched arm where it runs through rock (scripts/arch/kits/ld_fx.gd LDFx.arm): dark
// flesh with darker veins and a lit rim, drawn on top of the rock (no depth test), so the reach reads behind cover.
// UV.x runs along the arm in metres, UV.y round it.
render_mode unshaded, shadows_disabled, depth_draw_never, depth_test_disabled, blend_mix, cull_back, fog_disabled;
uniform vec4 color : source_color = vec4(0.42, 0.22, 0.62, 1.0);

void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float vein = smoothstep(0.7, 1.0, sin(UV.x * 3.1 + sin(UV.y * 12.566) * 1.6));
	ALBEDO = mix(color.rgb, color.rgb * 0.4, vein) + vec3(0.55, 0.35, 0.95) * rim * 0.6;
	ALPHA = 0.8;
}
