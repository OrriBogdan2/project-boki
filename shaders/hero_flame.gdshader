shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
// Living fire on a Hero (WardenGlb's `flame` slot): no lit surface, a tongue of fire on a strip of mesh. UV: u across
// the strip, v root to tip. Vertex colour: r = the strip's seed, g = how far it burns toward white. Cut with a hard noise
// edge, so its outline licks and no transparency sorting is needed (a cheap opaque pass, no particles). `liquid` turns it
// into the tank's bubbling fuel behind glass: u round the tank, v up it.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool no_fog = false;
uniform bool liquid = false;
uniform float speed = 1.3;         // how fast the fire climbs its strip
uniform float scale_u = 2.6;       // noise cells across a strip
uniform float scale_v = 3.4;       // and along it
uniform float lick = 0.62;         // how deep the noise bites the outline
uniform float sway = 0.018;        // m the tip wavers
uniform float gain = 1.25;         // brightness over the ramp
uniform float level = 0.72;        // liquid: the fuel's level, v
uniform vec4 c_deep : source_color = vec4(0.72, 0.07, 0.02, 1.0);
uniform vec4 c_mid : source_color = vec4(1.0, 0.33, 0.03, 1.0);
uniform vec4 c_hot : source_color = vec4(1.0, 0.68, 0.10, 1.0);
uniform vec4 c_core : source_color = vec4(1.0, 0.95, 0.62, 1.0);
#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/vis.gdshaderinc"

varying float seed;
varying float bright;

void vertex() {
	seed = COLOR.r;
	bright = COLOR.g;
	if (!liquid) {
		float v = UV.y;
		float t = TIME * 3.1 + seed * 40.0;
		VERTEX += NORMAL * sin(t + v * 7.0) * sway * v;
		VERTEX += vec3(0.0, 1.0, 0.0) * sin(t * 0.7 + v * 5.0) * sway * 0.6 * v * v;
	}
}

vec3 ramp(float h) {
	vec3 c = mix(c_deep.rgb, c_mid.rgb, smoothstep(0.0, 0.38, h));
	c = mix(c, c_hot.rgb, smoothstep(0.34, 0.66, h));
	return mix(c, c_core.rgb, smoothstep(0.66, 0.96, h));
}

float bubbles(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p) - 0.5;
	float h = h21(cell);
	vec2 at = (vec2(h, fract(h * 13.7)) - 0.5) * 0.6;
	float r = 0.1 + 0.2 * fract(h * 7.3);
	float ring = abs(length(f - at) - r);
	return step(0.45, fract(h * 3.1)) * (1.0 - smoothstep(0.02, 0.07, ring));
}

void fragment() {
	vec3 c;
	if (liquid) {
		float v = UV.y;
		float wob = 0.02 * sin(UV.x * 18.0 + TIME * 2.2) + 0.012 * sin(UV.x * 31.0 - TIME * 3.1);
		float top = level + wob;
		if (v > top) {
			// the empty glass: dark amber with the fuel's light on it
			c = mix(vec3(0.34, 0.16, 0.07), vec3(0.14, 0.09, 0.08), smoothstep(top, top + 0.2, v));
		} else {
			float n = fbm3(vec2(UV.x * 9.0, v * 5.0 - TIME * 0.35));
			float h = 0.45 + 0.42 * n - 0.32 * smoothstep(0.0, 0.25, v) * 0.0 + 0.3 * (1.0 - smoothstep(0.0, 0.5, v));
			h -= 0.12 * smoothstep(top - 0.14, top, v) * -1.0;
			float b = bubbles(vec2(UV.x * 14.0, v * 10.0 - TIME * 0.9)) + 0.7 * bubbles(vec2(UV.x * 23.0 + 3.0, v * 17.0 - TIME * 1.5));
			c = ramp(clamp(h + b * 0.55, 0.0, 1.0));
			c = mix(c, c_core.rgb, (1.0 - smoothstep(0.0, 0.012, abs(v - top))));
		}
		// the glass's highlight, a tall window down one side
		float win = smoothstep(0.03, 0.05, fract(UV.x + 0.1) - 0.1) * (1.0 - smoothstep(0.09, 0.11, fract(UV.x + 0.1) - 0.1));
		c += vec3(0.55, 0.5, 0.42) * win * 0.5;
	} else {
		vec2 p = vec2(UV.x * scale_u + seed * 17.0, UV.y * scale_v - TIME * speed + seed * 9.0);
		float n = fbm3(p);
		float n2 = vnoise(p * 2.3 + vec2(3.1, -TIME * speed * 0.7));
		float edge = 1.0 - pow(abs(UV.x - 0.5) * 2.0, 1.6);
		float fall = 1.0 - pow(UV.y, 2.2);
		float h = edge * fall + (n - 0.5) * lick + (n2 - 0.5) * lick * 0.4;
		if (h < 0.07 && UV.y > 0.03) {
			discard;
		}
		c = ramp(clamp((h - 0.07) * 1.5 + bright * 0.3, 0.0, 1.0));
	}
	c *= gain;
	float fog = no_fog ? 0.0 : vis_fog((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	c = vis_apply(c, fog);
	ALBEDO = c * (1.0 - flash) + flash_color.rgb * flash;
}
