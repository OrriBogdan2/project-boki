class_name StatusEdge
extends CanvasLayer
## The local player's status as a screen-edge tint (HUD makes one, under its widgets): stunned or knocked is blue,
## untouchable (a long invulnerable window: a revive, a landing, an ultimate) is yellow, Grounded is half-strength
## yellow, cloaked is a dark blue. The centre stays clear. One shader, no screen read, hidden when nothing applies.

const SHADER: Shader = preload("res://shaders/status_edge.gdshader")
const STUN := Color(0.30, 0.55, 1.0)  # stunned, knocked up
const INVULN := Color(1.0, 0.85, 0.2)  # untouchable
const GROUNDED := Color(1.0, 0.85, 0.2)  # same yellow at half strength
const CLOAK := Color(0.05, 0.10, 0.35)  # invisible
const INV_MIN := 0.5  # s of invulnerability before it tints (dash and hit frames are shorter and stay clean)
const STRENGTH := {"stun": 0.9, "invuln": 0.75, "grounded": 0.45, "cloak": 0.7}
const FADE_RATE := 12.0  # 1/s: how fast the tint follows the status
const PULSE_RATE := 0.7  # Hz: the inner edge's breathing while untouchable

var rect: ColorRect
var mat: ShaderMaterial
var k := 0.0
var _phase := 0.0


func _init() -> void:
	layer = 3  # under the abyss tint (4) and the HUD
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	rect.material = mat
	rect.visible = false
	add_child(rect)


## What `p` shows now: the tint colour and its target strength (0 for none), the first of stun, invulnerable,
## Grounded, cloaked.
static func want(p: Hunter) -> Array:
	if p == null or p.out:
		return [STUN, 0.0]
	if p.stun_t > 0.0 or p.knock_t > 0.0:
		return [STUN, STRENGTH["stun"]]
	if p.inv_t >= INV_MIN:
		return [INVULN, STRENGTH["invuln"]]
	if KitStatus.grounded(p):
		return [GROUNDED, STRENGTH["grounded"]]
	if p.cloak_t > 0.0:
		return [CLOAK, STRENGTH["cloak"]]
	return [STUN, 0.0]


## One frame for `p` (the local player; null hides it): eases toward what it shows.
func tick(p: Hunter, dt: float) -> void:
	var w := want(p)
	k = lerpf(k, float(w[1]), 1.0 - exp(-FADE_RATE * dt))
	rect.visible = k > 0.01
	if not rect.visible:
		return
	_phase = fmod(_phase + dt * PULSE_RATE, 1.0)
	mat.set_shader_parameter("col", Vector3(w[0].r, w[0].g, w[0].b))
	mat.set_shader_parameter("k", k)
	mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(_phase * TAU) if p.inv_t >= INV_MIN else 0.0)
