class_name BotSquad
extends RefCounted
## How a bot plays with its squad, the way a trio of people does (docs/BOTS_HUMAN_1111.md): with
## nothing to fight it keeps near the squad's lead instead of roaming the map alone, it heads out when
## the lead does, and in a fight it piles onto the rival a squadmate is fighting or being shot by.
## Bot.think and Bot._choose call these; how strongly a bot does it follows its difficulty.

const REGROUP_R := 22.0          # m from the lead past which a calm bot walks back to it
const REGROUP_DONE := 8.0        # m: back with the lead (the gap keeps it from pacing on the edge)
const ASSIST_R := 24.0           # m: a squadmate's rival this close is worth joining (times aggro)
const FOCUS := 8.0               # target score (metres of distance) for a squadmate's rival, at full skill
const HIT_RECENT := 4.0          # s: a squadmate hit this recently is still being shot at
const SIDE := 2.5                # m: where a follower stands beside where its lead is going

## The one the rest keep to: the person in the squad, else its drop leader, else the first one up.
static func lead(m: Match, h: Hunter) -> Hunter:
	var first: Hunter = null
	var drop: Hunter = null
	for o in m.hunters:
		if o.team != h.team or o.out or o.extracted or o.downed or o.riding or o.dropping:
			continue
		if o.ctrl == "local" or o.ctrl == "remote":
			return o
		if first == null:
			first = o
		if m.skydrop and m.skydrop.is_lead(o):
			drop = o
	return drop if drop else first

## Where a calm bot that has drifted from its lead should walk (INF when it is close enough, or is
## the lead). The lead itself goes where its own goals take it.
static func regroup(m: Match, h: Hunter, cur_kind: String) -> Vector3:
	var l := lead(m, h)
	if l == null or l == h:
		return Vector3.INF
	var r := REGROUP_DONE if cur_kind == "regroup" else REGROUP_R
	return l.pos if h.flat_dist(l) > r else Vector3.INF

## A follower heads home when its (bot) lead has decided to: squads leave together.
static func lead_leaving(m: Match, h: Hunter) -> bool:
	var l := lead(m, h)
	return l != null and l != h and l.ctrl == "bot" and bool(l.ai.get("leave", false))

## How much more a rival is worth shooting because the squad is on it: a squadmate is targeting it,
## or it has just hit a squadmate. 0 when neither.
static func focus(m: Match, h: Hunter, o: Hunter) -> float:
	for f in m.hunters:
		if f == h or f.team != h.team or f.out or f.downed:
			continue
		if f.ai.get("tgt") == o or (f.last_hit_by == o and m.time - f.hurt_at < HIT_RECENT):
			return FOCUS * float(h.ai["skill"])
	return 0.0

## With nothing of its own to do, a follower goes where its lead is going (or, for a person, to them),
## to its own spot beside it rather than onto it. INF when it is the lead or has none.
static func tag_along(m: Match, h: Hunter) -> Vector3:
	var l := lead(m, h)
	if l == null or l == h:
		return Vector3.INF
	var g: Vector3 = l.ai.get("goal", Vector3.INF) if l.ctrl == "bot" else Vector3.INF
	if g == Vector3.INF or l.flat_dist(g) > REGROUP_R * 2.0:
		g = l.pos
	var ang := float(hash(h.nid) % 6) / 6.0 * TAU
	var q := g + Vector3(cos(ang), 0, sin(ang)) * SIDE
	return g if m.world.is_void(q.x, q.z) or m.world.is_block(q.x, q.z) else q
