class_name KinPace
## Companion Boki out of a fight think at 10 Hz. Near you, a calm Boki re-plans the way to its spot beside its
## Hunter every THINK_S and walks every step; far from you (Bot.FAR_M) its whole sim runs every FAR_EVERY steps
## with the skipped time added in, as Bot.tick does for far bots. A Boki with a foe, or whose Hunter was just
## hit or is fighting, runs every step. Off-line only: a client would see its Boki step at 10 Hz.

const THINK_S := 0.1           # s between a calm Boki's walk plans (10 Hz)
const FAR_EVERY := 6           # sim steps per update for a calm Boki far from you (10 Hz at 60 steps a second)
const HURT_S := 3.0            # s after its Hunter is hit that a Boki counts as in a fight (KinFollow.in_combat)

## The time for this step's sim (with what it skipped), or 0.0 on a step a far, calm Boki skips.
static func step(k: Kin, dt: float) -> float:
	var acc := k.pace_dt + dt
	var off_beat := (int(k.m.time / Match.DT) + k.get_instance_id()) % FAR_EVERY != 0
	if off_beat and acc < dt * FAR_EVERY and _calm_far(k):
		k.pace_dt = acc
		return 0.0
	k.pace_dt = 0.0
	return acc

## The time a calm Boki's walk plan covers when one is due (since its last, at most THINK_S), else 0.0: it keeps
## its last plan in between.
static func plan_dt(k: Kin, dt: float) -> float:
	var since: float = k.m.time - k.plan_t
	if since < THINK_S and not k.m.net_on:
		return 0.0
	k.plan_t = k.m.time
	return clampf(since, dt, THINK_S)

static func _calm_far(k: Kin) -> bool:
	var o := k.owner_h
	var me: Hunter = k.m.player
	if k.m.net_on or o == null or me == null or o == me or me.out or k.target != null:
		return false
	if not (k.state == "active" or k.state == "shoulder") or k.m.time - o.hurt_at < HURT_S:
		return false
	return o.ai.get("tgt") == null and o.flat_dist(me) > Bot.FAR_M
