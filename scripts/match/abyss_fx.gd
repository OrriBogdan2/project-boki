extends CanvasLayer
## (movefeel) The abyss, for the local player only. As in the owner's reference footage, the moment
## you're falling below island level the whole view goes a saturated magenta/rose, deepening toward
## crimson-magenta the lower you go; only right at the point of no return does it darken and close
## in at the edges with a heartbeat. It lets go as the glider lifts you back up (see danger). The HUD adds the heartbeat sounds
## and a pulsing warning near the end (see Hud); the home uses it too (Home._abyss_tint).
## Sits just under the HUD layer, so the HUD stays readable. (No class_name: load it by path, so a
## fresh checkout needs no class-cache rescan.)

const SHADER: Shader = preload("res://shaders/abyss_tint.gdshader")

var rect: ColorRect
var mat: ShaderMaterial
var k := 0.0


func _init() -> void:
	layer = 4
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	rect.material = mat
	rect.visible = false
	add_child(rect)


## Sets the effect's strength (0..1) and the heartbeat phase (0..1) for this frame.
func show_danger(amount: float, beat: float) -> void:
	k = amount
	rect.visible = amount > 0.004
	if rect.visible:
		mat.set_shader_parameter("k", amount)
		mat.set_shader_parameter("pulse", beat)


## How deep into the abyss p is, as the tint's strength: 0 above the start depth (see danger_depth), rising
## smoothly to 1 at the point of no return (Hunter.abyss_kill_y). An overheated glider (no lift left) reads worse.
## Off while the glider lifts you back up.
static func danger(p: Hunter) -> float:
	if p == null or p.out or p.grounded or not p.over_void():
		return 0.0
	if p.vel.y > RISE_OFF:
		return 0.0  # lifting back up (glider lift, a jump, an updraft): the tint lets go
	# the lip it's measured from: the lowest island ground around (or where you left), as the kill line is
	var top: float = p.m.world.abyss_floor(p.pos.x, p.pos.z, p.last_gy) + World.ABYSS_DEPTH - 0.5
	return danger_depth(top - p.pos.y, top - p.abyss_kill_y(), p.glide_fuel <= 0.001)


## The same from a depth under the balloon line and the span down to the point of no return: 0 until
## start_depth (content/rules/abyss_danger.json: a small dip shows nothing), then a smooth ramp to 1 at the
## point of no return. An overheated glider (no_heat) reads a quarter worse, never before the start.
static func danger_depth(depth: float, span: float, no_heat := false) -> float:
	var rules := Content.rules("abyss_danger")
	var start := float(rules["start_depth"])
	if depth <= start:
		return 0.0
	var x := clampf((depth - start) / maxf(1.0, span - start), 0.0, 1.0)
	x = pow(x, float(rules["curve"]))
	return minf(1.0, x * 1.25) if no_heat else x


const RISE_OFF := 1.0  # rising faster than this (m/s): no tint
