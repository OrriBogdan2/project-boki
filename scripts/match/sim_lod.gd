class_name SimLod
## Far, calm bots run at a third of the sim rate (decision 0021).
##
## The 2x Hollow Crown holds 40 hunters, most of them roaming or fighting far from the one human
## playing offline. A bot more than FAR_M from the local player, on the ground, with nothing urgent
## on, not fighting anything within FAR_M of the player and not just hit by the player, thinks AND
## simulates every EVERY steps with the skipped time added in; its Boki does the same. Bot-vs-bot
## fights far off count (a third of a 40-bot match is that at any time): both sides step together,
## so it's a 20 Hz fight, not a lopsided one, and the visuals already redraw far things every 4th
## frame (Match._render_now). Bots are staggered by slot so each step carries a third of them.
## Anything that breaks the rule (the player walking up or shooting it, leaving the ground, a revive)
## puts it back on every step at once, with the time it has banked.
##
## Offline only: a server has no local player, and on a client bots are remote (puppets).

const FAR_M := 45.0       # m from the local player (flat) before a bot may slow down
const EVERY := 3          # sim steps per bot step when far and calm (60 Hz -> 20 Hz)
const HIT_CALM_S := 1.5   # s after the player (or their Boki) hit it before it counts as far again
const TRAIN_CALM_S := 1.5 # s after standing on a train car (the car carries it; keep physics exact)
## Bot goals kept at the full rate: boarding or riding moving things and scripted lair moments, where
## a 50 ms step could miss a platform or a lever. Walking to a box, a Boki or a downed mate is not one
## of them (Bot.URGENT_GOALS is about not flip-flopping goals; its timers get the banked time).
const FULL_RATE_GOALS := ["board", "lift", "yard", "hum", "beacon", "lair_fight", "lair_escape", "lair_lever",
	"lair_updraft"]

const THINK_FAR_M := 90.0  # m from the local player (flat): two camera views off, nobody sees it decide
const THINK_FAR_K := 2.0   # how much longer such a bot waits between picking goals and targets

static var _n := 0             # sim steps planned (staggers the bots' slots)

## Once per sim step, before the bots think: sets each bot's step time for this step (0 = skip).
static func plan(m: Match, dt: float) -> void:
	_n += 1
	var me := m.player
	var on := me != null and not me.out and not me.extracted
	for i in m.hunters.size():
		var h: Hunter = m.hunters[i]
		if h.ctrl != "bot" or h.remote:
			continue
		var a := h.ai
		var acc := float(a.get("lod_dt", 0.0)) + dt
		if on and _calm(m, h, me) and (_n + i) % EVERY != 0:
			a["lod_dt"] = acc
			a["lod_step"] = 0.0
		else:
			a["lod_dt"] = 0.0
			a["lod_step"] = acc

## How much longer than usual a bot waits before it chooses again (Bot.think): THINK_FAR_K when it
## is more than THINK_FAR_M from the local player and calm (same rule as the 20 Hz step), else 1. A
## far bot still steers, aims and fires every step it takes; it only re-picks its goal less often.
static func think_k(m: Match, h: Hunter) -> float:
	var me := m.player
	if me == null or me.out or me.extracted or h.remote or h.flat_dist(me) <= THINK_FAR_M:
		return 1.0
	return THINK_FAR_K if _calm(m, h, me) else 1.0

## The time this hunter steps by this sim step (dt for anyone not on the plan).
static func step_dt(h: Hunter, dt: float) -> float:
	return float(h.ai.get("lod_step", dt)) if h.ctrl == "bot" and not h.remote else dt

## A kin out with its hunter (on its shoulder or active), not after anything near the player and
## itself far, steps with its hunter; any other kin every step.
static func kin_dt(k: Kin, dt: float) -> float:
	var o := k.owner_h
	var me: Hunter = (k.m as Match).player if o else null
	if o == null or me == null or k.remote or not (k.state == "shoulder" or k.state == "active"):
		return dt
	if (k.target != null and k.target.flat_dist(me) <= FAR_M) or k.flat_dist(me) <= FAR_M:
		return dt
	return step_dt(o, dt)

static func _calm(m: Match, h: Hunter, me: Hunter) -> bool:
	if h.out or h.extracted or h.riding or h.downed or not h.grounded or h.gliding:
		return false
	if not h.grap.is_empty() or not h.pad.is_empty() or h.roll_t > 0.0 or not h.merge_st.is_empty():
		return false
	if m.time - h.hurt_at < HIT_CALM_S and _mine(h.last_hit_by, me):
		return false
	if m.skytrain and m.time - float(m.skytrain.ride_t.get(h, -9.0)) < TRAIN_CALM_S:
		return false
	var a := h.ai
	if String(a.get("goal_kind", "")) in FULL_RATE_GOALS:
		return false
	var t = a.get("tgt")
	if is_instance_valid(t) and t is Ent and (t as Ent).flat_dist(me) <= FAR_M:
		return false
	return h.flat_dist(me) > FAR_M

## The player or their Boki.
static func _mine(by: Variant, me: Hunter) -> bool:
	return is_instance_valid(by) and (by == me or (by is Kin and (by as Kin).owner_h == me))
