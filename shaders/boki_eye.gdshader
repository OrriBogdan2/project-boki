shader_type spatial;
render_mode cull_back;
// A rigged Boki's eye (BokiRig): a dome with the iris drawn on it. The iris takes each Boki's own colour and slides with
// `look`; the catch-lights stay put, so the eye stays bright whichever way it looks.
uniform vec4 iris : source_color = vec4(0.62, 0.89, 0.23, 1.0);
uniform vec2 look = vec2(0.0);
uniform float size = 0.82;
uniform float pupil = 0.40;
uniform float night_glow = 0.1;

void fragment() {
	vec2 p = vec2(UV.x - 0.5, 0.5 - UV.y) * 2.0;
	vec2 q = (p - look) * vec2(1.0, 0.96);
	float r = length(q) / size;
	float aa = fwidth(r) + 0.01;
	float grad = clamp(0.5 - q.y * 0.62, 0.0, 1.0);
	vec3 c = mix(iris.rgb * 0.42, iris.rgb * 1.3 + vec3(0.05), grad);
	c = mix(c, vec3(0.05, 0.08, 0.05), smoothstep(pupil + aa, pupil - aa, r));
	c = mix(c, iris.rgb * 0.16, smoothstep(0.88, 0.97, r));
	c = mix(c, vec3(1.0), smoothstep(1.0 - aa, 1.0 + aa, r));
	float big = smoothstep(0.24, 0.215, length(p - vec2(0.22, 0.30)));
	float small = smoothstep(0.1, 0.08, length(p - vec2(-0.26, -0.24)));
	c = mix(c, vec3(1.0), max(big, small));
	ALBEDO = c;
	EMISSION = c * night_glow + vec3(1.0) * max(big, small) * 0.35;
	ROUGHNESS = 0.3;
	SPECULAR = 0.3;
}
