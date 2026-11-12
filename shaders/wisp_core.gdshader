shader_type spatial;
// The Wisp's body (WispLook): a chubby round soul with a tiny face on its +Z side, shaded from a light
// overhead, with a thin outline in the viewer's relation colour (SideColor) so the body reads by side too.
// style picks the skin's surface: 0 plain, 1 glitch (hue bands sliding, rows skipping sideways), 2 ember
// (cracks glowing glow_col under a dark crust). Opaque: fade takes it out in a dither, flash > 1 whitens it
// (the pops).
render_mode unshaded, shadows_disabled, fog_disabled;
uniform vec4 rim_col : source_color = vec4(1.0);
uniform vec4 body_col : source_color = vec4(1.0);
uniform vec4 shade_col : source_color = vec4(0.7);
uniform vec4 face_col : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 glow_col : source_color = vec4(1.0);
uniform int style = 0;
uniform float rim = 0.18;
uniform float flash = 1.0;
uniform float fade = 1.0;
varying vec3 dir;      // from the body's centre, in its own space (+Z is the face)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void vertex() {
	dir = normalize(VERTEX);
	if (style == 1) {
		// glitch: now and then a row of the body skips sideways for a few frames
		float row = floor(VERTEX.y * 16.0);
		float tick = floor(TIME * 9.0);
		VERTEX.x += step(0.86, hash(vec2(row, tick))) * 0.035 * sign(hash(vec2(tick, row)) - 0.5);
	}
}

// Two dot eyes and a small smile, a few centimetres across on a 0.3 m body, turned FACE_TILT radians up
// the front so the game camera, looking steeply down, sees them.
const float FACE_TILT = 0.5;
float face(vec3 d) {
	d = vec3(d.x, d.y * cos(FACE_TILT) - d.z * sin(FACE_TILT), d.y * sin(FACE_TILT) + d.z * cos(FACE_TILT));
	float eyes = max(step(0.989, dot(d, normalize(vec3(-0.27, 0.16, 0.95)))),
		step(0.989, dot(d, normalize(vec3(0.27, 0.16, 0.95)))));
	float smile = step(abs(d.y - (-0.08 + 2.2 * d.x * d.x)), 0.014) * step(abs(d.x), 0.1) * step(0.0, d.z);
	return max(eyes, smile);
}

void fragment() {
	vec3 up = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	float lit = smoothstep(-0.3, 0.8, dot(NORMAL, up));
	vec3 col = mix(shade_col.rgb, body_col.rgb, lit);
	if (style == 1) {
		vec3 bands = hue(floor(fract(dir.y * 1.5 + TIME * 0.5) * 6.0) / 6.0);
		col = mix(col, bands, 0.55 * lit + 0.25);
	} else if (style == 2) {
		float n = sin(dir.x * 13.0 + sin(dir.y * 9.0)) * sin(dir.y * 11.0 + dir.z * 7.0) * sin(dir.z * 12.0 + dir.x * 5.0);
		float crack = 1.0 - smoothstep(0.0, 0.07, abs(n));
		col = mix(col, glow_col.rgb * 1.5, crack * (0.75 + 0.25 * sin(TIME * 3.0)));
	}
	col = mix(col, face_col.rgb, face(dir));
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	col = mix(rim_col.rgb, col, smoothstep(rim, rim + 0.08, facing));
	col = mix(col, vec3(1.0), clamp((flash - 1.0) / 3.0, 0.0, 1.0) * 0.8);
	if (hash(floor(FRAGCOORD.xy / 2.0)) > fade) {
		discard;
	}
	ALBEDO = col;
}
