// The look locker's backdrop wall (LookSet): dark at the floor, a band of your glow at chest height, fading out
// above it so the sky shows over the wall. Graded by height, so it needs no UVs.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

uniform vec4 low_col : source_color = vec4(0.04, 0.03, 0.09, 1.0);
uniform vec4 band_col : source_color = vec4(0.2, 0.4, 0.5, 1.0);
uniform float wall_h = 4.5;      // m: the wall's height (its mesh is centred on its middle)
uniform float band_at = 0.36;    // 0..1 up the wall: the band's brightest line
uniform float fade_to = 0.8;     // 0..1 up the wall: fully clear from here

varying float up;

void vertex() {
	up = VERTEX.y / wall_h + 0.5;
}

void fragment() {
	ALBEDO = mix(low_col.rgb, band_col.rgb, smoothstep(0.0, band_at, up));
	ALPHA = 1.0 - smoothstep(band_at, fade_to, up);
}
