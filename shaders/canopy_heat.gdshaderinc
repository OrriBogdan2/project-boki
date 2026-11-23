// A glider canopy's heat (GliderHeat): canopy_heat 0 cool .. 1 overheated warms the cloth toward ember, and
// canopy_burn 1 flickers it. Shared by toon.gdshader and hero_toon.gdshader (Hunters' canopies use the second).
// Include after noise.gdshaderinc (vnoise).
uniform float canopy_heat : hint_range(0.0, 1.0) = 0.0;
uniform float canopy_burn : hint_range(0.0, 1.0) = 0.0;

// The flicker's noise at a canopy point: 0 when the canopy is cool, so cool cloth pays nothing.
float canopy_ember(vec2 p) {
	if (canopy_heat <= 0.0 && canopy_burn <= 0.0) { return 0.0; }
	return 0.5 + 0.5 * vnoise(p * 9.0 + vec2(TIME * 17.0, -TIME * 11.0));
}

vec3 canopy_tint(vec3 c, float ember) {
	vec3 hot = vec3(0.95, 0.3, 0.1) * (0.5 + dot(c, vec3(0.5)));
	return mix(c, hot, canopy_heat * 0.75) * (1.0 - canopy_burn * 0.5 * (1.0 - ember));
}

vec3 canopy_glow(float ember) {
	return vec3(1.0, 0.4, 0.1) * (canopy_heat * canopy_heat * 0.4 + canopy_burn * ember * 0.8);
}
