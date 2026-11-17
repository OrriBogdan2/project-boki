shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
// A drawn face off an atlas (Meeko's companions): one cell of cols x rows, the mesh's UV running 0..1 over the cell;
// `from_cell` fades into `to_cell` by `k`, `blink` shuts the eyes by showing `blink_cell`.
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform ivec2 grid = ivec2(4, 2);
uniform int from_cell = 0;
uniform int to_cell = 0;
uniform int blink_cell = -1;
uniform float blink = 0.0;
uniform float k = 1.0;

vec4 cell(int c, vec2 uv) {
	vec2 g = vec2(grid);
	return texture(atlas, (vec2(float(c % grid.x), float(c / grid.x)) + clamp(uv, 0.0, 1.0)) / g);
}

void fragment() {
	int to_c = (blink > 0.5 && blink_cell >= 0) ? blink_cell : to_cell;
	vec4 c = mix(cell(from_cell, UV), cell(to_c, UV), k);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
