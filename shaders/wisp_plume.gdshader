shader_type spatial;
// The see-through plume round a Wisp (WispLook): a flame on a quad that faces the camera, rising up the
// screen from the body's bottom edge. The quad sits a little toward the camera (so its base never sinks
// into the ground) with a soft hole where the body is, so the body sits in the flame and is never tinted.
// It licks upward in the viewer's relation colour (SideColor) with a paler heart and a thin dark rim that
// keeps it readable on any ground. Every skin keeps it, so a downed Hunter's side reads the same whatever
// they wear. fade takes it out, flash > 1 brightens it (the pops).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float alpha = 0.6;
uniform float speed = 1.0;
uniform float rise = 0.5;       // m up the screen from the body's middle to the quad's middle
uniform float lift = 0.3;       // m toward the camera
uniform float hole = 0.3;       // m: the body's radius, cut out of the flame
uniform float flash = 1.0;
uniform float fade = 1.0;
varying vec2 local;             // on the quad, in metres from its middle

void vertex() {
	local = VERTEX.xy;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 toward = INV_VIEW_MATRIX[2].xyz;
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 mid = MODEL_MATRIX[3].xyz + up * rise * sy + toward * lift;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * length(MODEL_MATRIX[0].xyz), 0.0), vec4(up * sy, 0.0),
		vec4(toward, 0.0), vec4(mid, 1.0));
}

void fragment() {
	float v = 1.0 - UV.y;                   // 0 at the base, 1 at the tip
	float t = TIME * speed;
	float x = (UV.x - 0.5) * 2.0;
	x += (sin(v * 7.0 - t * 5.0) * 0.1 + sin(v * 13.0 - t * 8.0) * 0.04) * v;
	float w = smoothstep(0.0, 0.25, v + 0.1) * pow(1.0 - v, 0.6);      // a full teardrop, widest low down
	float shape = 1.0 - smoothstep(w * 0.72, w * 0.82, abs(x));
	float edge = (1.0 - smoothstep(w * 0.82, w, abs(x))) * (1.0 - shape);    // a dark rim: reads on any ground
	float heart = 1.0 - smoothstep(0.0, w * 0.5, abs(x));
	float licks = 0.8 + 0.2 * sin(v * 16.0 - t * 6.0 + x * 4.0);
	vec3 c = mix(col.rgb, vec3(1.0), heart * (1.0 - v) * 0.2);
	c = mix(c, col.rgb * 0.25, edge);
	ALBEDO = mix(c, vec3(1.0), clamp((flash - 1.0) / 3.0, 0.0, 1.0) * 0.6);
	float body = 1.0 - smoothstep(hole * 0.85, hole, length(local - vec2(0.0, -rise)));
	ALPHA = (shape * licks + edge * 0.5) * alpha * (1.0 - v * 0.3) * (1.0 - body) * clamp(fade, 0.0, 1.0);
}
