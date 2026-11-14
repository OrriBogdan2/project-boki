class_name UltGlow
extends RefCounted
## A Hunter whose ultimate is ready glows in their own colour, for everyone to see; on the cast the glow
## flashes bright and fades (the cast cue itself is unchanged). One shader value, hero_toon's ult_glow,
## set on the body's materials only when it changes. The ready state rides the "st" flags (Match._flags
## bit READY_BIT) so other players see it; the flash is the glow dropping when the ult goes on cooldown.

const READY_BIT := 1 << 28      # in the hunter snapshot flags (bits 25-27 are StatusLooks, 15-24 taken)
const READY_LEVEL := 0.4       # glow while ready, 0..1 (1 is the cast flash)
const RISE_PER_S := 1.0        # glow fades in over ~0.4 s
const FADE_PER_S := 3.5        # the flash fades out over ~0.3 s

## Is the Hunter's ultimate ready (unlocked, off cooldown)? Local and bot Hunters read their kit; others, the net.
static func kit_ready(h: Hunter) -> bool:
	return h.ak != null and HeroUlt.ready(h.ak)

## Once per rendered frame: eases the glow toward its target, flashing when a ready ult goes off.
static func tick(h: Hunter, dt: float) -> void:
	if not h.remote:
		h.ult_ready = kit_ready(h)
	var was: bool = h.get_meta("ult_was", false)
	h.set_meta("ult_was", h.ult_ready)
	var alive := not h.downed and not h.out
	var target := READY_LEVEL if h.ult_ready and alive and not KinMerge.active(h) else 0.0
	if was and not h.ult_ready and alive:
		h.ult_glow = 1.0                  # the cast: flash
	else:
		h.ult_glow = move_toward(h.ult_glow, target, (FADE_PER_S if h.ult_glow > target else RISE_PER_S) * dt)
	_apply(h)

## Sets the glow on the body's materials when it differs from what the first one holds (a rebuilt model gets it too).
static func _apply(h: Hunter) -> void:
	if h.mats.is_empty():
		return
	var first: ShaderMaterial = h.mats[0]
	var shown = first.get_shader_parameter("ult_glow")
	if is_equal_approx(h.ult_glow, 0.0 if shown == null else float(shown)):
		return
	var col := Arch.color(h.arch) if h.arch != "" else h.accent()
	for mt: ShaderMaterial in h.mats:
		mt.set_shader_parameter("ult_color", col)
		mt.set_shader_parameter("ult_glow", h.ult_glow)
