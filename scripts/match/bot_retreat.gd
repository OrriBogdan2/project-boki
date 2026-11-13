class_name BotRetreat
extends RefCounted
## A bot that is losing a fight backs out of it the way a player does: it breaks off toward a
## squadmate (or just away), keeps shooting on the way, dashes clear when it can, and drinks once
## nobody is hitting it. Without this a bot stood and traded down to nothing with tonics still on
## its belt (docs/BOTS_HUMAN_1111.md has the numbers).
## Bot.think calls `move` in a fight and `goal` when it picks where to walk; BotBelt asks
## `can_drink` before a tonic with a rival close.
## The tier still decides how good a bot is at it: an Easy bot notices it is in trouble about half
## the time and late (32% health, 52% when outnumbered, or under 1.1 s from down at the rate the hits
## come in), an Expert every time and early (44%, 64%, 2.4 s).

const LOW_BASE := 0.26         # health share where the least skilled bot starts to think of leaving
const LOW_SKILL := 0.2         # ...more of it per point of skill (an expert leaves at about 44%)
const ODDS_ADD := 0.2          # ...and more again with more rivals than squad around: under focus fire
                               # the last third of a health bar lasts about a second
const OK_GAIN := 0.25          # health share above that mark where a bot counts itself fit again
const SEE_BASE := 0.8          # seconds to down at the current damage rate where the least skilled bot
const SEE_SKILL := 1.6         # ...sees the fight is lost (more per point of skill: an expert 2.4 s). A
                               # player leaves on focus fire coming in, not once the bar is a sliver
const RATE_S := 0.6            # seconds the damage rate is smoothed over
const OUT_MIN_S := 2.0         # seconds a bot that left on the damage rate stays out before it re-thinks
const NOTICE_BASE := 0.3       # chance a bot with no ability sense notices it should leave...
const NOTICE_ABIL := 0.7       # ...and how much the tier's "abil" adds (expert: always)
const WINNING := 0.6           # the rival's health under this share of ours: finish it instead
const MATE_M := 45.0           # metres: a squadmate this close is worth running to
const GIVE_UP_S := 9.0         # seconds a bot runs before it turns and fights (nobody runs forever)
const QUIET_S := 1.1           # seconds since the last hit before a drink is worth starting (a hit spills it)
const DRINK_M := 8.0           # metres from the rival (or out of its sight) before drinking
const DANGER_M := 20.0         # metres: a rival in sight this close keeps a hurt bot walking away
const STEP_M := 3.5            # metres of safe ground the way out needs ahead
const WALL_M := 2.0            # metres ahead that must not be a rock or a wall
const DASH_M := 5.0            # metres of safe ground a dash out needs
const FLEE_M := 10.0           # metres ahead the walk-away spot is placed
const TURNS := [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]      # radians tried either side of straight away

## The health share under which this bot thinks about leaving a fight (higher when outnumbered).
static func low_mark(m, h: Hunter, a: Dictionary) -> float:
	var mark := LOW_BASE + LOW_SKILL * float(a.get("skill", 0.5))
	return mark + (ODDS_ADD if BotSquad.odds(m, h) > 0 else 0.0)

## Hurt enough to leave, and the kind of bot that notices? Rolled once each time it gets low; the
## answer holds until it is fit again or has run for GIVE_UP_S.
static func wants_out(m, h: Hunter, a: Dictionary) -> bool:
	var frac: float = h.hp / h.max_hp
	var low := low_mark(m, h, a)
	var doomed := down_in(m, h, a) < SEE_BASE + SEE_SKILL * float(a.get("skill", 0.5))
	var settled: bool = m.time - float(a.get("rt_t0", -99.0)) > OUT_MIN_S
	if (frac >= low + OK_GAIN and not doomed and settled) or not BotSquad.on(m):
		a.erase("rt_wise")
		a.erase("rt_t0")
		return false
	if not a.has("rt_wise"):
		if frac >= low and not doomed:
			return false
		var abil := float((a.get("diff", {}) as Dictionary).get("abil", 0.7))
		a["rt_wise"] = randf() < NOTICE_BASE + NOTICE_ABIL * abil
		a["rt_t0"] = m.time
	if a["rt_wise"] and m.time - float(a["rt_t0"]) > GIVE_UP_S:
		a["rt_wise"] = false
	return a["rt_wise"]

## Seconds until this bot is down if the hits keep coming as they have this last moment (INF when
## nothing is landing). Health and armor together, the damage rate smoothed over RATE_S.
static func down_in(m, h: Hunter, a: Dictionary) -> float:
	var left: float = h.hp + h.armor
	var gap: float = m.time - float(a.get("rt_at", m.time))
	var rate := float(a.get("rt_rate", 0.0))
	if gap > 0.0:
		var lost := maxf(float(a.get("rt_left", left)) - left, 0.0)
		rate = lerpf(rate, lost / gap, minf(gap / RATE_S, 1.0))
	a["rt_left"] = left
	a["rt_at"] = m.time
	a["rt_rate"] = rate
	return left / rate if rate > 0.5 else INF

## In a fight with `foe`: is the bot backing out of it right now? (Not when the rival is nearly
## done, and not with nothing to drink and nobody to run to: then it is better to trade.)
static func active(m, h: Hunter, a: Dictionary, foe: Ent) -> bool:
	if not (foe is Hunter) or (foe as Hunter).downed or not wants_out(m, h, a):
		return false
	if foe.hp < h.hp * WINNING:
		return false
	return has_heal(h) or BotSquad.nearest(m, h, MATE_M) != null

static func has_heal(h: Hunter) -> bool:
	return UtilityBelt.count(h, "tonic") > 0 or UtilityBelt.count(h, "medkit") > 0

## The fight move: `mv` as the bot meant it, or the way out when it is leaving. Sets up a dash
## clear when one is ready (never mid-drink: a roll spills the tonic).
static func move(m, h: Hunter, a: Dictionary, foe: Ent, mv: Vector2, inp: Dictionary) -> Vector2:
	if not active(m, h, a, foe):
		return mv
	var to := h.dir_to(foe)
	var out := way_out(m, h, to)
	if out == Vector2.ZERO:
		return mv      # cornered: fight
	if h.drink_t <= 0.0 and float(a["dash_cd"]) <= 0.0 and m.bot_brain._safe(m, h, out, DASH_M):
		a["dash_cd"] = randf_range(1.2, 3.0) / (0.5 + float(a["skill"]))
		a["dash_dir"] = out
		inp["dash"] = true
	return out + Vector2(-to.y, to.x) * float(a["strafe"]) * 0.3

## A direction that leads away from the rival (leaning to the nearest squadmate who is not on the
## rival's side of us) over safe ground, or ZERO if every way is a drop or a wall.
static func way_out(m, h: Hunter, to: Vector2) -> Vector2:
	var away := -to
	var mate: Hunter = BotSquad.nearest(m, h, MATE_M)
	if mate:
		var tm := h.dir_to(mate)
		if tm.dot(to) < 0.3:
			away = (away + tm * 0.8).normalized()
	for turn in TURNS:
		var dir: Vector2 = away.rotated(turn)
		var wall: bool = m.world.is_block(h.pos.x + dir.x * WALL_M, h.pos.z + dir.y * WALL_M)
		if not wall and m.bot_brain._safe(m, h, dir, STEP_M):
			return dir
	return Vector2.ZERO

## May a bot with a rival close start a tonic? Only once it has not been hit for a moment and the
## rival is a way off or cannot see it: the drink takes a second and a hit spills it.
static func can_drink(m, h: Hunter, foe: Ent) -> bool:
	if m.time - h.hurt_at < QUIET_S:
		return false
	if not (foe is Hunter):
		return true
	return h.flat_dist(foe) > DRINK_M or not m.world.los(h.pos, foe.pos, h.pos.y + 0.95)

## With no target: a hurt bot that wants out keeps walking away while a rival it can see is close
## (it drinks on the way, BotBelt). The spot to walk to, or INF.
static func goal(m, h: Hunter, a: Dictionary) -> Vector3:
	if not a.get("rt_wise", false) or not wants_out(m, h, a):
		return Vector3.INF
	var foe: Hunter = null
	var best := DANGER_M
	for o in m.hunters:
		if o.team == h.team or not o.targetable() or not m.can_see(h.team, o):
			continue
		var d := h.flat_dist(o)
		if d < best:
			best = d
			foe = o
	if foe == null:
		return Vector3.INF
	var out := way_out(m, h, h.dir_to(foe))
	if out == Vector2.ZERO:
		return Vector3.INF
	var p := h.pos + Vector3(out.x, 0, out.y) * FLEE_M
	if m.world.is_void(p.x, p.z) or m.world.is_block(p.x, p.z):
		p = h.pos + Vector3(out.x, 0, out.y) * STEP_M
	return Vector3(p.x, m.world.ground_at(p.x, p.z), p.z)
