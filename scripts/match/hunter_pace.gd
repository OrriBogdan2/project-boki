class_name HunterPace
## A bot Hunter far from you and out of a fight runs its sim every FAR_EVERY steps with the skipped time added in,
## as KinPace does for Boki and Bot.tick for far bots' decisions (decision 0048). In a fight, hurt, dashing, off
## the ground or within FAR_M of you, it runs every step. Off-line only: a client would see Hunters step at 30 Hz.

const FAR_M := 60.0            # m from the local player: past the camera's view at every zoom
const FAR_EVERY := 2           # sim steps per update when calm and that far (30 Hz at 60 steps a second)
const HURT_S := 3.0            # s after a hit that a Hunter counts as in a fight

## The time for this step's sim (with what it skipped), or 0.0 on a step a far, calm Hunter skips.
static func step(h: Hunter, dt: float) -> float:
	var acc := h.pace_dt + dt
	var off_beat := (int(h.m.time / Match.DT) + h.get_instance_id()) % FAR_EVERY != 0
	if off_beat and acc < dt * FAR_EVERY and _calm_far(h):
		h.pace_dt = acc
		h.prev = h.pos          # (held still between updates, not drawn sliding back toward the last one)
		return 0.0
	h.pace_dt = 0.0
	return acc

static func _calm_far(h: Hunter) -> bool:
	var me: Hunter = h.m.player
	if h.m.net_on or h.ctrl != "bot" or h.remote or me == null or me.out or h == me:
		return false
	if h.out or h.extracted or h.downed or h.riding or h.dropping or not h.grounded or h.roll_t > 0.0:
		return false
	if h.ai.get("tgt") != null or h.m.time - h.hurt_at < HURT_S:
		return false
	return h.flat_dist(me) > FAR_M
