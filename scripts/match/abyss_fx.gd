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


## How deep into the abyss p is, as the tint's strength: 0 (at or above the balloon line, 0.5m under
## the lowest lip around) to 1 (the point of no return, Hunter.abyss_kill_y). An overheated glider
## (no lift left) reads worse.
## [reference footage, feelfix] D1 (0.33s frames): the tint is there in the first frame after you
## drop below the lip (strong by ~2-3m down, with the balloon marker), stays while you fall, is gone
## as soon as the glider is lifting you back up (fading over one frame) even while you're still out
## over the void, and comes straight back when you fall again. BH (0.75s frames): faint for a frame
## as it starts, then strong; the deepest dip goes crimson with dark edges. So: a quick onset near
## the lip, deepening with depth to full right before the point of no return, and off while rising.
static func danger(p: Hunter) -> float:
	if p == null or p.out or p.grounded or not p.over_void():
		return 0.0
	if p.vel.y > RISE_OFF:
		return 0.0  # lifting back up (glider lift, a jump, an updraft): the tint lets go
	# the lip it's measured from: the lowest island ground around (or where you left), as the kill line is
	var top: float = p.m.world.abyss_floor(p.pos.x, p.pos.z, p.last_gy) + World.ABYSS_DEPTH - 0.5
	return danger_depth(top - p.pos.y, top - p.abyss_kill_y(), p.glide_fuel <= 0.001)


## The same from a depth under the balloon line and the span down to the point of no return.
static func danger_depth(depth: float, span: float, no_heat := false) -> float:
	if depth <= 0.0:
		return 0.0
	var x := clampf(depth / maxf(1.0, span), 0.0, 1.0)
	# a quick onset just under the lip (to ONSET_K over the first ONSET of the drop), then deepening
	# steadily to full right before the point of no return
	var a := ONSET_K * smoothstep(0.0, ONSET, x)
	var b := (1.0 - ONSET_K) * pow(clampf((x - ONSET) / (FULL_AT - ONSET), 0.0, 1.0), 1.2)
	x = clampf(a + b, 0.0, 1.0)
	if no_heat and x > 0.0:
		x = minf(1.0, x * 1.25 + 0.08)
	return x


const ONSET := 0.12  # share of the drop (balloon line to point of no return) the tint takes to come in
const ONSET_K := 0.55  # ...and how strong it is by then (unmistakable, still rose rather than crimson)
const FULL_AT := 0.95  # full strength (crimson, dark edges) from here to the point of no return
const RISE_OFF := 1.0  # rising faster than this (m/s): no tint
