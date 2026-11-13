class_name BotSquad
extends RefCounted
## Squad play for bots, the way three players on voice would do it: stay within reach of each
## other, go to a squadmate's fight and shoot what they shoot, don't start a fight alone against
## more, and leave as a squad. Without this each bot ran its own errands: squadmates looted a chest
## 7 m from a mate's fight, and drifted islands apart (docs/BOTS_HUMAN_1111.md has the numbers).
## Bot._choose asks `foes` and `outnumbered` when it picks a target, and `assist_goal` and
## `regroup_goal` when it picks where to walk. The tier still matters: skill sets how far off a bot
## notices a squadmate's fight and how bad the odds must be before it holds back.

const FAR_M := 28.0            # metres from the nearest squadmate where a bot with nothing pressing heads back
const NEAR_M := 10.0           # ...and how close it comes before it goes back to its own errands
const BASE_M := 55.0           # metres: further off than this, base to the squadmate instead of walking
const GUARD_M := 6.0           # metres from a busy lead where a squadmate with nothing to do waits
const CALM_S := 4.0            # seconds since the last hit before a bot stands still to base
const ASSIST_BASE := 18.0      # metres from which the least skilled bot notices a squadmate's fight
const ASSIST_SKILL := 22.0     # ...more per point of skill (an expert: about 38 m)
const ASSIST_REACH := 12.0     # metres: the least reach onto a rival who is fighting a squadmate
const FOCUS := 8.0             # target score added for the rival the squad has called (see HELD)
const HELD := 6.0              # target score added for the rival a bot is already shooting...
const HELD_FRESH := 14.0       # ...and for the first HOLD_S after it picked them: a player sticks with a
                               # pick for a few seconds (with HELD alone bots flipped 7 times a fight minute)
const HOLD_S := 2.5            # seconds a fresh pick counts as HELD_FRESH
const FIGHT_FRESH_S := 3.0     # seconds a landed hit keeps two hunters "in a fight"
const HELP_HP := 0.35          # health share under which a bot leaves the helping to others
const CROWD_M := 12.0          # metres round a rival that count as its side of a fight
const SIDE_M := 14.0           # metres round us that count as ours
const CLOSE_M := 6.0           # a rival this close is fought whatever the odds
const ODDS_SKILL := 0.45       # skill from which one extra rival is enough to hold back (below: two)

## Off for a match started with "bot_plain": bots as they were without squad play or retreats
## (the bot-human check measures both ways from one build). Off in the duel room too: one against
## one with nowhere to go, a bot there fights it out (and --bot-kit-use counts what it presses).
static func on(m) -> bool:
	return not (m.opts.get("bot_plain", false) or m.opts.get("duel", false))

static func up(o: Hunter) -> bool:
	return not (o.out or o.downed or o.extracted or o.riding or o.dropping)

## The nearest squadmate on their feet within `within` metres, or null.
static func nearest(m, h: Hunter, within := 1e9) -> Hunter:
	var best: Hunter = null
	var bd: float = within
	for o in m.hunters:
		if o == h or o.team != h.team or not up(o):
			continue
		var d := h.flat_dist(o)
		if d < bd:
			bd = d
			best = o
	return best

## The hunter behind a hit (a kin's hit counts as its owner's).
static func hunter_of(e) -> Hunter:
	if e == null or not is_instance_valid(e):
		return null
	if e is Hunter:
		return e
	return (e as Kin).owner_h if e is Kin else null

## The rival this hunter is fighting right now, or null: a bot's own target, else whoever hit it
## (or it hit) in the last few seconds, so a player squadmate's fights count too.
static func foe_of(m, mate: Hunter) -> Hunter:
	var t = mate.ai.get("tgt")
	if t != null and is_instance_valid(t) and t is Hunter and t.team != mate.team and t.targetable():
		return t
	var by := hunter_of(mate.last_hit_by)
	if by and by.team != mate.team and by.targetable() and m.time - mate.hurt_at < FIGHT_FRESH_S:
		return by
	for o in m.hunters:
		if o.team != mate.team and o.targetable() and m.time - o.hurt_at < FIGHT_FRESH_S \
				and hunter_of(o.last_hit_by) == mate:
			return o
	return null

## The rivals this bot's squadmates are fighting within earshot (further for a skilled bot).
static func foes(m, h: Hunter, a: Dictionary) -> Array:
	var out: Array = []
	if not on(m):
		return out
	var hear := ASSIST_BASE + ASSIST_SKILL * float(a.get("skill", 0.5))
	for o in m.hunters:
		if o == h or o.team != h.team or not up(o) or h.flat_dist(o) > hear:
			continue
		var f := foe_of(m, o)
		if f and not out.has(f):
			out.append(f)
	return out

## The one rival of `fighting` the squad shoots together: the one a player squadmate is on, else
## the one the first of its bots in a fight is on. Null for that first bot itself, which keeps its
## own pick, so two bots never swap targets back and forth.
static func called(m, h: Hunter, fighting: Array) -> Hunter:
	var pick: Hunter = null
	var before_me := true
	for o in m.hunters:
		if o == h:
			before_me = false
			continue
		if o.team != h.team or not up(o):
			continue
		var player: bool = o.ctrl != "bot"
		if not player and (pick != null or not before_me):
			continue
		var f := foe_of(m, o)
		if f and fighting.has(f):
			pick = f
			if player:
				break
	return pick

## The target score the rival a bot is already shooting gets (Bot._choose; tgt_t is when it was picked).
static func held(m, a: Dictionary) -> float:
	if on(m) and m.time - float(a.get("tgt_t", -9.0)) < HOLD_S:
		return HELD_FRESH
	return HELD

## How many more rivals than squad (this bot included) stand within SIDE_M of this bot.
static func odds(m, h: Hunter) -> int:
	var k := -1
	for x in m.hunters:
		if x == h or not up(x) or x.flat_dist(h) > SIDE_M:
			continue
		k += -1 if x.team == h.team else 1
	return k

## Where to run to help: the nearest rival a squadmate is fighting (Bot._choose targets it once it
## is in reach and in sight), or INF. A badly hurt bot stays out of it. The bot keeps to the rival
## it set off for while that fight lasts: with two fights either side it turned round every think.
## In reach of that rival and still no shot (it is up a ledge or behind a rock): go to the squadmate
## instead, who has one. Walking at a spot it could not reach, a bot turned on the spot under it.
static func assist_goal(m, h: Hunter, a: Dictionary, fighting: Array) -> Vector3:
	if fighting.is_empty() or h.hp < h.max_hp * HELP_HP:
		a.erase("assist")
		return Vector3.INF
	var best = a.get("assist")
	if not (is_instance_valid(best) and fighting.has(best)):
		best = fighting[0]
		for f in fighting:
			if h.flat_dist(f) < h.flat_dist(best):
				best = f
		a["assist"] = best
	var mate := nearest(m, h)
	if h.flat_dist(best) < ASSIST_REACH and mate:
		return mate.pos
	return best.pos

## Would starting on rival `o` be a fight against more than we have here? Counted the way a player
## reads it: hunters on their feet round the rival against those round us.
static func outnumbered(m, h: Hunter, a: Dictionary, o: Hunter, d: float) -> bool:
	if d < CLOSE_M or not on(m):
		return false
	var theirs := 0
	var ours := 0
	for x in m.hunters:
		if not up(x):
			continue
		if x.team == o.team and x.flat_dist(o) < CROWD_M:
			theirs += 1
		elif x.team == h.team and x.flat_dist(h) < SIDE_M:
			ours += 1
	return theirs - ours >= (1 if float(a.get("skill", 0.5)) >= ODDS_SKILL else 2)

## Who the squad keeps to: a player on the squad if there is one (the nearest), else the first of
## its bots on their feet. Null when that is `h` itself or nobody is up.
static func lead(m, h: Hunter) -> Hunter:
	var first: Hunter = null
	var human: Hunter = null
	for o in m.hunters:
		if o.team != h.team or not up(o):
			continue
		if first == null:
			first = o
		if o.ctrl != "bot" and o != h and (human == null or h.flat_dist(o) < h.flat_dist(human)):
			human = o
	if human:
		return human
	return null if first == h else first

## Where a bot with nothing to do roams: where its lead is roaming to, else to the lead, or INF for
## the lead itself, which picks its own way. Next to a lead that is busy (looting, holding a spot, a
## player standing) it waits on one spot: walking onto the lead, it was pushed back off every step
## and turned on the spot for half a minute.
static func roam_to(m, h: Hunter, a: Dictionary) -> Vector3:
	var ld := lead(m, h)
	if ld == null or not on(m):
		a.erase("guard")
		return Vector3.INF
	if ld.ctrl == "bot" and String(ld.ai.get("goal_kind", "")) == "roam":
		a.erase("guard")
		return ld.ai["goal"]
	if h.flat_dist(ld) > GUARD_M:
		a.erase("guard")
		return ld.pos
	if not a.has("guard"):
		a["guard"] = h.pos
	return a["guard"]

## Drifted off from the squad with nothing pressing: the squadmate to head back to (and base to
## them when they are islands away and it is calm), or INF. Holds until the bot is close again.
static func regroup_goal(m, h: Hunter, a: Dictionary) -> Vector3:
	var ld := lead(m, h)
	var mate: Hunter = ld if ld and ld.ctrl != "bot" else nearest(m, h)
	if mate == null or not on(m):
		a.erase("regroup")
		return Vector3.INF
	var d := h.flat_dist(mate)
	if d < NEAR_M or (d < FAR_M and not a.has("regroup")):
		a.erase("regroup")
		return Vector3.INF
	a["regroup"] = true
	if d > BASE_M and h.base_t <= 0.0 and h.base_cd <= 0.0 and h.grounded and m.time - h.hurt_at > CALM_S:
		h.start_base(mate)
	return mate.pos

## One bot decides, the squad's bots go along (leaving for the exit, crashing a rival's uplink).
static func agree(m, h: Hunter, key: String, value: bool) -> void:
	h.ai[key] = value
	if not on(m):
		return
	for o in m.hunters:
		if o.team == h.team and o.ctrl != "local":
			o.ai[key] = value
