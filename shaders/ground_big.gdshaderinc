// The terrain's big painted patterns (shaders/terrain.gdshader): slow fbm of the ground's world xz only, so
// scripts/match/ground_bake.gd bakes them once per map into three RGBA textures (4 texels per metre) and the
// ground reads 1-2 texels instead of 15-21 noise hashes a pixel. k = layer * 4 + channel:
//   0 ground patches, 1 sunlit swathes, 2 painted pools, 3 hue drift (layer 0)
//   4 bloom petal drifts, 5 frost snow, 6 ember ash, 7 ember crack zones (layer 1)
//   8 storm slate, 9 gloom veins (layer 2)
float big_live(vec2 p, int k) {
	if (k == 0) return fbm3(p * 0.22);
	if (k == 1) return fbm3(p * 0.09 + 11.0);
	if (k == 2) return fbm3(p * 0.045 + 31.0);
	if (k == 3) return fbm3(p * 0.03 - 17.0);
	if (k == 4) return fbm3(p * 0.16 + 2.0);
	if (k == 5) return fbm3(p * 0.25);
	if (k == 6) return fbm3(p * 0.35 + 4.0);
	if (k == 7) return fbm3(p * 0.2 + 9.0);
	if (k == 8) return fbm3(p * 0.3 + 2.0);
	return fbm3(p * 0.15 + 3.0);
}
