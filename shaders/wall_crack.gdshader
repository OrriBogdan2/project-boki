shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// A crack stamped on a wall (scripts/match/wall_impact.gd): R of the texture is the crack, G a thin halo.
// The crack is stone, the halo the attacker's colour; `fade` runs 1 -> 0 over the decal's life.
uniform sampler2D crack : filter_linear;
uniform vec3 stone = vec3(0.16, 0.15, 0.14);
uniform vec3 rim = vec3(1.0);
uniform float fade = 1.0;

void fragment() {
	vec2 t = texture(crack, UV).rg;
	ALBEDO = mix(rim, stone, step(0.4, t.r));
	ALPHA = max(t.r, t.g * 0.75) * fade;
}
