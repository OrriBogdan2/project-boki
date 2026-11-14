shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_lambert, specular_schlick_ggx;
// A hero body turned to ice (Rimelock, IceBody): the hero's own materials are swapped for this one, so the
// body itself is ice, not a shell round it. Translucent and refractive (the ground shows through, bent by
// the surface), a fresnel rim, a cold glow deep in the thick parts, a web of frost cracks and a drifting
// sparkle. `freeze` sweeps a bright frost front from the feet (foot_y) up past the head (head_y): below it
// ice, above it her own colour and atlas; thawing runs the front back down.
uniform vec4 albedo : source_color = vec4(1.0);          // her own colour, kept above the frost front
uniform bool use_tex = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_vertex_color = false;
uniform vec4 ice : source_color = vec4(0.62, 0.88, 0.97, 1.0);    // the ice's own tint
uniform vec4 glow : source_color = vec4(0.30, 0.70, 1.0, 1.0);    // the inner glow
uniform vec4 rim : source_color = vec4(0.93, 0.99, 1.0, 1.0);     // the fresnel rim, the cracks, the front
uniform float freeze : hint_range(0.0, 1.0) = 1.0;   // how far the frost front has climbed: 0 flesh, 1 all ice
uniform float foot_y = 0.0;      // world y of the feet
uniform float head_y = 2.4;      // world y above the head
uniform float see = 0.55;        // how much of the bent world shows through the ice
uniform float refract = 0.035;   // screen-space bend of what shows through
uniform float crack = 0.7;       // strength of the frost crack web
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 cell(vec2 c) {
	return vec2(hash2(c), hash2(c + 19.19));
}

// Voronoi edges (F2 - F1): thin bright lines where the cells meet, the frost's crack web
float cracks(vec2 p) {
	vec2 g = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 r = o + cell(g + o) - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return 1.0 - smoothstep(0.0, 0.08, sqrt(d2) - sqrt(d1));
}

void fragment() {
	vec3 skin = albedo.rgb;
	if (use_tex) {
		skin *= texture(albedo_tex, UV).rgb;
	}
	if (use_vertex_color) {
		skin *= COLOR.rgb;
	}
	float line = mix(foot_y - 0.25, head_y + 0.25, freeze);
	float above = world_pos.y - line;
	float icy = 1.0 - smoothstep(0.0, 0.06, above);
	float moving = step(0.001, freeze) * (1.0 - step(0.999, freeze));
	float front = exp(-abs(above) * 14.0) * moving;
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - facing, 2.4);
	// the crack web over the body's world position, one coarse and one fine
	vec2 cp = world_pos.xy * 3.2 + world_pos.z * 1.7;
	float web = cracks(cp) * crack;
	float fine = cracks(cp * 2.3 + 7.0) * crack * 0.35;
	// what the ice lets through, bent by the surface (view-space normal xy is the screen's)
	vec2 bend = NORMAL.xy * refract * (0.4 + 0.6 * facing);
	vec3 through = texture(screen_tex, SCREEN_UV + bend).rgb;
	vec3 body = mix(ice.rgb, through * ice.rgb * 1.15, see * facing);
	// a few facets catch the light, drifting with time
	vec2 facet = floor(world_pos.xz * 38.0 + world_pos.y * 23.0);
	float spark = step(0.975, hash2(facet + floor(TIME * 2.0)));
	ALBEDO = mix(skin, body, icy);
	vec3 shine = glow.rgb * (0.12 + 0.35 * facing * facing)
			+ rim.rgb * (fres * 0.9 + web * 0.55 + fine + spark * 0.8);
	EMISSION = shine * icy + rim.rgb * front * 2.5;
	ROUGHNESS = mix(0.75, 0.08, icy);
	SPECULAR = mix(0.3, 0.7, icy);
	ALPHA = 1.0;
}
