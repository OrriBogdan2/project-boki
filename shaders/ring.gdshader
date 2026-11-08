shader_type spatial;
// A flat ring on the ground: team markers, shockwaves, revive progress.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 color : source_color = vec4(1.0);
uniform float thickness = 0.12;
uniform float fill = 0.0;
uniform float arc = 1.0;
uniform float wash = 0.0;   // a faint fill rising toward the band, a shockwave's body (0..1)
uniform float halo = 0.0;   // a soft glow either side of the band and a hot core in it (0..1)
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float ang = (atan(uv.x, -uv.y) / 6.2831853) + 0.5;
	float ring = smoothstep(1.0 - thickness - 0.04, 1.0 - thickness, r) * (1.0 - smoothstep(0.96, 1.0, r));
	if (ang > arc) { ring = 0.0; }
	float band = 1.0 - thickness * 0.5 - 0.02;
	float soft = halo * (1.0 - smoothstep(0.0, thickness + 0.2, abs(r - band)));
	float inner = wash * smoothstep(0.15, 1.0, r) * step(r, band);
	if (ang > arc) { soft = 0.0; inner = 0.0; }
	float a = max(max(ring, step(r, 1.0) * fill), max(soft * 0.5, inner * 0.3));
	if (a <= 0.001) { discard; }
	ALBEDO = mix(color.rgb, vec3(1.0), ring * halo * 0.4);
	ALPHA = a * color.a;
}
