shader_type spatial;
// The see-through plume over a Wisp (WispLook): a flame on an upright quad that turns round its own up
// axis to face the camera, licking upward, in the viewer's relation colour (SideColor) with a paler heart.
// Every skin keeps it, so a downed Hunter's side reads the same whatever they wear. fade takes it out,
// flash > 1 brightens it (the pops).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float alpha = 0.6;
uniform float speed = 1.0;
uniform float flash = 1.0;
uniform float fade = 1.0;

void vertex() {
	vec3 up = MODEL_MATRIX[1].xyz;
	vec3 side = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side * length(MODEL_MATRIX[0].xyz), 0.0), MODEL_MATRIX[1],
		vec4(normalize(cross(side, up)), 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float v = 1.0 - UV.y;                   // 0 at the base, 1 at the tip
	float t = TIME * speed;
	float x = (UV.x - 0.5) * 2.0;
	x += (sin(v * 7.0 - t * 5.0) * 0.12 + sin(v * 13.0 - t * 8.0) * 0.05) * v;
	float w = smoothstep(0.0, 0.3, v + 0.15) * pow(1.0 - v, 0.9);      // a teardrop, widest low down
	float shape = 1.0 - smoothstep(w * 0.55, w, abs(x));
	float heart = 1.0 - smoothstep(0.0, w * 0.6, abs(x));
	float licks = 0.7 + 0.3 * sin(v * 16.0 - t * 6.0 + x * 4.0);
	vec3 c = mix(col.rgb, vec3(1.0), heart * (1.0 - v) * 0.45);
	ALBEDO = mix(c, vec3(1.0), clamp((flash - 1.0) / 3.0, 0.0, 1.0) * 0.6);
	ALPHA = shape * licks * alpha * (1.0 - v * 0.4) * clamp(fade, 0.0, 1.0);
}
