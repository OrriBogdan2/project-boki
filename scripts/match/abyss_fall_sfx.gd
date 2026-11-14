class_name AbyssFallSfx
extends RefCounted
## One hunter's abyss fall sounds (tools/gen_sfx_abyss_fall.py, content/sfx/abyss_fall.json).
## Yours, unpositioned: an abyss_wind loop from the moment you drop under an island's lip over the abyss,
## its pitch and level climbing through the slow band (HunterMove.abyss_slow_from..abyss_slow_to, where
## the fall eases to its abyss cap) so you hear how deep you are; abyss_warn once when the point of no
## return (Hunter.abyss_kill_y) is WARN_S of falling away; abyss_lift once when anything carries you back
## up (the glider, cool or overheated, an updraft, a ledge float). Everyone else's: one positional
## abyss_cry as they drop under the lip, at normal hearing range. Ticked once a frame per hunter next to
## GliderSfx; each cue fires once on the change of state.

const WIND_KEY := "abyss_wind"
const WIND_QUIET_DB := -20.0    # dB, loop, at the top of the slow band...
const WIND_LOUD_DB := -5.0      # ...and at its bottom
const WIND_LOW := 0.75          # pitch at the top of the slow band...
const WIND_HIGH := 1.45         # ...and at its bottom
const WARN_S := 0.6             # s of falling left above the point of no return when the warning plays
const WARN_DB := -3.0           # dB
const LIFT_VY := 2.0            # m/s climbing under the lip that counts as being lifted out
const LIFT_DB := -4.0           # dB
const CRY_DB := -4.0            # dB, positional

var falling := false            # under the lip and dropping: the wind is on
var warned := false             # this drop's warning has played
var lifted := false             # the lift cue has played since you last fell
var cried := false              # another hunter's cry has played for this drop

## The wind's level (dB, x) and pitch (y) `depth` metres under the lip: quiet and low at the slow band's
## top, loud and high at its bottom (the band HunterMove.fall_cap eases the fall through).
static func wind_mix(depth: float) -> Vector2:
	var span := HunterMove.abyss_slow_to - HunterMove.abyss_slow_from
	var k := clampf((depth - HunterMove.abyss_slow_from) / span, 0.0, 1.0)
	return Vector2(lerpf(WIND_QUIET_DB, WIND_LOUD_DB, k), lerpf(WIND_LOW, WIND_HIGH, k))

func tick(h: Hunter) -> void:
	if not h.is_local():
		_other(h)
		return
	falling = h.below_lip and h.vel.y < 0.0
	if not h.below_lip:
		warned = false
		lifted = false
		return
	if h.vel.y > LIFT_VY and not lifted:
		lifted = true
		warned = false
		Sfx.play("abyss_lift", null, LIFT_DB, 0.03)
	if not falling:
		return
	lifted = false
	var wind := wind_mix(h.lip_y - h.pos.y)
	Sfx.loop_hold(WIND_KEY, WIND_KEY, null, wind.x, wind.y)
	if not warned and h.pos.y - h.abyss_kill_y() < -h.vel.y * WARN_S:
		warned = true
		Sfx.play("abyss_warn", null, WARN_DB, 0.0)

## Another hunter (a remote player or a bot): one cry as it drops under the lip, re-armed once it's back
## out of the abyss (climbed out, or back in play after falling out).
func _other(h: Hunter) -> void:
	if h.below_lip and not cried:
		cried = true
		Sfx.play("abyss_cry", h.pos, CRY_DB)
	elif not h.below_lip:
		cried = false
