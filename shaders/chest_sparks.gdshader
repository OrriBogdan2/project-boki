shader_type spatial;
// The few sparks that drift up off a chest's lid (PropSculpt.chest). Every instance of the multimesh
// is one spark: its place on the lid, its phase and its fade all come from its INSTANCE_ID, so it
// needs no particle system (a CPUParticles3D draws from the match's seeded global random stream).
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 glow : source_color = vec4(1.0, 0.85, 0.5, 0.85);
uniform vec3 extents = vec3(0.5, 0.05, 0.3);     // the box the sparks start in (m)
uniform float rise = 0.8;                         // how far one climbs in its life (m)
uniform float life = 1.6;                         // seconds
uniform float spark_size = 0.03;                  // radius (m)
varying float fade;
float hsh(float n) { return fract(sin(n * 91.345 + 7.13) * 47453.5453); }
void vertex() {
	float id = float(INSTANCE_ID);
	float ph = fract(TIME / life + hsh(id));
	vec3 off = vec3((hsh(id + 1.0) * 2.0 - 1.0) * extents.x, (hsh(id + 2.0) * 2.0 - 1.0) * extents.y, (hsh(id + 3.0) * 2.0 - 1.0) * extents.z);
	off.x += (hsh(id + 4.0) - 0.5) * 0.2 * ph;
	VERTEX = VERTEX * spark_size * (0.7 + hsh(id + 5.0) * 0.6) + off + vec3(0.0, ph * rise * (0.6 + hsh(id + 6.0) * 0.4), 0.0);
	fade = sin(ph * 3.14159);
}
void fragment() {
	ALBEDO = glow.rgb;
	ALPHA = glow.a * fade;
}
