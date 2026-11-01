extends CanvasLayer
## (movefeel) The abyss closing in, for the local player only. SUPERVIVE tints the screen as you sink
## below island level and darkens it the deeper you go [footage, SUPERVIVE_FEEL.md]; ours escalates
## hard so it's unmistakable before it's too late: the colour drains, the picture darkens and goes
## crimson, and a vignette closes in from the edges, beating with a heartbeat. The HUD adds the
## heartbeat/rumble sounds and a pulsing warning near the point of no return (see Hud).
## Sits just under the HUD layer, so the HUD stays readable. (No class_name: load it by path, so a
## fresh checkout needs no class-cache rescan.)

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float k = 0.0;       // danger 0..1 (1 = the point of no return)
uniform float pulse = 0.0;   // heartbeat 0..1
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	// drain the colour
	vec3 g = mix(c, vec3(l), clamp(k * 1.25, 0.0, 0.92));
	// deep crimson monochrome taking over past the halfway mark
	vec3 red = vec3(l * 1.2 + 0.06, l * 0.16, l * 0.14);
	float rk = smoothstep(0.3, 1.0, k);
	g = mix(g, red, rk * (0.7 + 0.3 * pulse));
	// darker the deeper
	g *= 1.0 - 0.5 * k;
	// the vignette closes in, and breathes with the heartbeat
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 d = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
	float r = length(d);
	float edge = mix(0.95, 0.2, k) - pulse * 0.05 * k;
	float v = smoothstep(edge, edge + 0.32, r);
	g = mix(g, vec3(0.1, 0.0, 0.01) * (0.6 + 0.4 * pulse), v * clamp(k * 1.5, 0.0, 0.97));
	COLOR = vec4(g, 1.0);
}
"""

var rect: ColorRect
var mat: ShaderMaterial
var k := 0.0

func _init() -> void:
	layer = 4
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	rect.visible = false
	add_child(rect)

## Sets the effect's strength (0..1) and the heartbeat phase (0..1) for this frame.
func show_danger(danger: float, beat: float) -> void:
	k = danger
	rect.visible = danger > 0.004
	if rect.visible:
		mat.set_shader_parameter("k", danger)
		mat.set_shader_parameter("pulse", beat)

## How deep into the abyss p is, 0 (at the balloon line, 0.5m under the lowest lip around) to 1 (the point
## of no return, Hunter.abyss_kill_y), eased so it builds early and is near full well before the end.
## An overheated glider (no lift left) reads worse.
static func danger(p: Hunter) -> float:
	if p == null or p.out or p.grounded or not p.over_void():
		return 0.0
	# the lip it's measured from: the lowest island ground around (or where you left), as the kill line is
	var top: float = p.m.world.abyss_floor(p.pos.x, p.pos.z, p.last_gy) + World.ABYSS_DEPTH - 0.5
	var kill := p.abyss_kill_y()
	var span := maxf(1.0, top - kill)
	var depth := top - p.pos.y
	if depth <= 0.0:
		return 0.0
	var x := clampf(depth / span, 0.0, 1.0)
	x = 1.0 - pow(1.0 - x, 1.6)      # rises fast at first: it's obvious early
	if p.glide_fuel <= 0.001:
		x = minf(1.0, x * 1.25 + 0.1)
	return x
