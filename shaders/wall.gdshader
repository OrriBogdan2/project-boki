shader_type spatial;
render_mode depth_prepass_alpha;
// Toon stone for walls. Whatever part of a wall stands between the camera and the player
// dithers away, so you can always see yourself behind cover.
uniform float rim_amount = 0.12;
uniform float shade = 0.42;
uniform vec3 focus = vec3(0.0, -999.0, 0.0);
uniform float radius = 0.13;
#include "res://shaders/vis.gdshaderinc"
#include "res://shaders/noise.gdshaderinc"
varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = COLOR.rgb;
	float kind = COLOR.a;     // 1 stone, 0.5 cover (moss, snow, ash), 0 mortar
	float up = clamp(wn.y, 0.0, 1.0);
	if (kind > 0.75) {
		// hand-cut stone: broad value shifts along a run, chisel brushwork across each face, a
		// lighter wash on faces turned to the sky and a little grime settling in toward the foot
		float big = fbm3(wp.xz * 0.28 + wp.yy * 0.2);
		float n1 = vnoise(vec2(dot(wp.xz, vec2(0.7, 0.7)) * 3.2, wp.y * 6.5));
		float n2 = vnoise(wp.xz * 10.0 + wp.yy * 8.0);
		c *= 0.86 + big * 0.24;
		c *= 0.92 + n1 * 0.14;
		c *= 0.95 + n2 * 0.08;
		c = mix(c, c * vec3(1.08, 1.05, 1.0) + 0.03, up * 0.6);
	} else if (kind > 0.25) {
		// cover: soft clumps, brighter where it faces up, darker where it hangs down a face
		float cl = fbm3(wp.xz * 7.0 + wp.yy * 3.0);
		c *= 0.86 + cl * 0.22;
		c *= mix(0.8, 1.06, up);
	} else {
		c *= 0.85 + vnoise(wp.xz * 5.0 + wp.yy * 5.0) * 0.12;
	}
	float cut = 0.0;
	vec4 fv = VIEW_MATRIX * vec4(focus, 1.0);
	if (fv.z < 0.0 && VERTEX.z > fv.z + 0.4) {
		vec2 a = VERTEX.xy / -VERTEX.z;
		vec2 b = fv.xy / -fv.z;
		float fade = 1.0 - smoothstep(radius * 0.55, radius, length(a - b));
		cut = fade;
	}
	c = vis_apply(c, vis_fog((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz));
	ALBEDO = c;
	ALPHA = 1.0 - cut * 0.78;     // see through the part of a wall that hides you, smoothly
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(1.0, 0.96, 0.88) * rim * rim_amount * 0.35;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	if (!LIGHT_IS_DIRECTIONAL) {
		// lamps and glows: plain falloff. (The cel shade floor below is only for the sun; on a lamp
		// it lit whole screen clusters at once, which showed up as blocky squares at night.)
		float pl = smoothstep(-0.1, 0.4, dot(NORMAL, LIGHT)) * ATTENUATION;
		DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * pl;
	} else {
		float ndl = dot(NORMAL, LIGHT);
		float lit = smoothstep(0.0, 0.06, ndl) * ATTENUATION;
		float band = smoothstep(0.35, 0.65, lit);
		vec3 tone = mix(vec3(shade) * vec3(0.7, 0.66, 0.92), vec3(1.05, 1.0, 0.93), band);
		DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * tone;
	}
}
