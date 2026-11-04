// A glow halo on a Warden model's lens or eye (WardenGlb halos, content/rules/warden_look.json): a camera-facing
// disc of a constant size on screen, so a lens a pixel wide at the match camera still reads, faded out up close
// (where the lens itself reads) and when the lens turns away from the camera.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 color : source_color = vec4(0.35, 1.0, 0.45, 1.0);
uniform float strength = 1.2;
uniform float px = 3.0;          // the halo's radius on screen (pixels)
uniform float near_d = 7.0;      // no halo this close to the camera (m) ...
uniform float far_d = 14.0;      // ... full from here
uniform float lift = 0.0;        // m more toward the camera (a lens behind a fringe of hair)
varying float fade;
void vertex() {
	vec3 c = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = length(c);
	float r = d * px * 2.0 / (VIEWPORT_SIZE.y * PROJECTION_MATRIX[1][1]);
	// the lens's forward (the anchor's -Z) against the way to the camera
	vec3 fwd = normalize((MODELVIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
	float facing = smoothstep(-0.15, 0.35, dot(fwd, -c / max(d, 1e-4)));
	fade = smoothstep(near_d, far_d, d) * facing;
	// pulled toward the camera by its radius, so the face it sits on never clips it
	vec3 centre = c - c / max(d, 1e-4) * (r + lift);
	vec2 corner = (UV - 0.5) * 2.0;
	POSITION = PROJECTION_MATRIX * vec4(centre + vec3(corner * r, 0.0), 1.0);
}
void fragment() {
	float q = length((UV - 0.5) * 2.0);
	float glow = pow(max(1.0 - q, 0.0), 2.0) + smoothstep(0.38, 0.0, q) * 0.8;
	ALBEDO = color.rgb * strength;
	ALPHA = clamp(glow * fade, 0.0, 1.0);
}
