class_name GliderSfx
extends RefCounted
## One hunter's glider sounds (tools/gen_sfx_glider.py, content/sfx/glider.json): a snap as the canopy
## opens, a wind loop that pitches and swells with speed, a whoosh as the Ctrl dive starts, a crackle and a
## burn loop while it overheats, a fold as it closes. Ticked once a frame for every hunter, yours and
## everyone else's (theirs are positional and quieter, driven by the synced glide flag, velocity and the
## overheat bit), so each cue fires once on the change of state, never every frame.

const SNAP_DB := -6.0           # dB: under the skin's own open sound, which stays
const FOLD_DB := -8.0           # dB
const DIVE_DB := -4.0           # dB
const CRACKLE_DB := -5.0        # dB
const BURN_DB := -14.0          # dB, loop
const WIND_QUIET_DB := -24.0    # dB, loop at a standstill...
const WIND_LOUD_DB := -9.0      # dB, ...and at the dive's full speed
const WIND_LOW := 0.7           # pitch at a standstill...
const WIND_HIGH := 1.6          # ...and at the dive's full speed
const OTHERS_DB := -6.0         # dB under yours for another player's glider
const DIVE_VY_MIN := 18.0       # m/s of fall that counts as the plunge for another player (no dive flag is sent)

var open := false               # the glider was open last tick
var hot := false                # ...and burning
var diving := false             # ...and plunging
var net_hot := false            # another player's overheat bit (Match._net_apply)

## Called every frame by the hunter; plays the cue for whatever changed since the last call.
func tick(h: Hunter) -> void:
	var gliding := h.gliding and not h.out
	var v := h.net_vel if h.remote else h.vel
	var trim := 0.0 if h.is_local() else OTHERS_DB
	var burning := gliding and not h.dropping and (net_hot if h.remote else h.glide_fuel <= 0.001)
	var plunging := gliding and not h.dropping and (-v.y > DIVE_VY_MIN if h.remote else h.glide_dive.on)
	if gliding and not open:
		Sfx.play("glider_snap", h.pos, SNAP_DB + trim)
	elif open and not gliding:
		Sfx.play("glider_fold", h.pos, FOLD_DB + trim)
	if plunging and not diving:
		Sfx.play("glider_dive", h.pos, DIVE_DB + trim)
	if burning and not hot:
		Sfx.play("glider_crackle", h.pos, CRACKLE_DB + trim)
	open = gliding
	hot = burning
	diving = plunging
	var id := h.get_instance_id()
	if gliding:
		var k := clampf(v.length() / HunterMove.dive_vy, 0.0, 1.0)
		var vol := lerpf(WIND_QUIET_DB, WIND_LOUD_DB, k) + trim
		Sfx.loop_hold("glider_wind%d" % id, "glider_wind", h.pos, vol, lerpf(WIND_LOW, WIND_HIGH, k))
	if burning:
		Sfx.loop_hold("glider_burn%d" % id, "glider_burn", h.pos, BURN_DB + trim)
