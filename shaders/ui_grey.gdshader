shader_type canvas_item;
// A locked Hunter's portrait: almost no colour and dimmer (HunterPickRow).
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(luma), 0.92) * 0.6, c.a);
}
