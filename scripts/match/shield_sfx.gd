class_name ShieldSfx
extends RefCounted
## What a shield sounds like under a hit (Hunter.hurt): a dull thunk while it holds, a glassy crack when the
## hit takes the last of it. One family per material (Hunter.shield_kind, set where a kit grants the shield;
## "" is the plain ward of heals and Boki shields). Yours plays centred, anyone else's at their body.
## Sounds: tools/gen_sfx_shield.py, content/sfx/shield.json.

const WARD := "ward"
const BLOCK_DB := -4.0          # dB over the file: the thunk sits under the hit tick
const BREAK_DB := -1.0
const SOFT_HIT := 8.0           # the hit that soaks this much or less plays a touch higher and lighter
const HEAVY_HIT := 40.0         # ...and this much or more a touch lower

## The shield on `h` just soaked `soaked` damage; `h.shield` is what is left.
static func hit(h: Hunter, soaked: float) -> void:
	var m: Match = h.m
	var broke := h.shield <= 0.0
	var kind := h.shield_kind if h.shield_kind != "" else WARD
	var pitch := remap(clampf(soaked, SOFT_HIT, HEAVY_HIT), SOFT_HIT, HEAVY_HIT, 1.12, 0.9)
	var part := "break" if broke else "hit"
	var at: Variant = null if h == m.player else h.pos
	m.sfx("shield_%s_%s" % [kind, part], at, BREAK_DB if broke else BLOCK_DB, pitch)
