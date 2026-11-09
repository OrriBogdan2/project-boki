shader_type spatial;
// A loot rarity pillar: a column of light, strongest at its foot and fading to nothing at the top, soft at
// the rim. Brightness comes from the height, not the viewing angle, so it reads from the high match camera.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float height = 3.0;      // m, the mesh's full height (it is centred on its middle)
varying float up;
void vertex() {
	up = clamp(VERTEX.y / height + 0.5, 0.0, 1.0);
}
void fragment() {
	float rim = mix(0.55, 1.0, abs(dot(NORMAL, VIEW)));
	ALBEDO = color.rgb;
	ALPHA = clamp(color.a * 1.8 * pow(1.0 - up, 1.3) * rim, 0.0, 1.0);
}
