class_name BotWays
extends RefCounted
## Bots in Limited Ways Out (briefs/specs/LIMITED_WAY_OUTS.md section 7; knobs: content/rules/heart.json
## "bots"). Each squad has a plan by the match seed: raider (the Sealed Lair), runner (the Heartspark,
## carried to the Heart Gate), holder (the Uplink) or stayer (loots, then the final). When its seat is
## taken or shut a squad falls through to the next open one, then to the final. Every bot keeps inside
## the tide ring. Fairness: a bot squad starts a seat no sooner than seat_delay_s after it opens, and bot
## squads take at most min(early_seats_cap_max, bot squads / early_seats_cap_per_bot_squads) of the three
## early seats. A squad with a human in it (the player's, also on --autoplay) has no delay and no cap.

const PLANS := ["raider", "runner", "holder", "stayer"]
## The early seats each plan tries, its own first, in the order they open; every plan ends on the final.
const ORDER := {"raider": ["lair", "spark", "uplink"], "runner": ["spark", "uplink"], "holder": ["uplink"],
	"stayer": []}
const RUN_LEAD := 45.0      # s: a runner heads for the Heart this long before runner_at_s ("at the Heart by 5:15")
const FINAL_LEAD := 20.0    # s: squads with no other seat head for the Heart ring this long before it opens
const RING_LOOK := 20.0     # s: a goal must still be inside the tide ring this far ahead
const RING_KEEP := 4.0      # m (design map): and this far inside it
const RING_EDGE := 2.0      # m: a bot this close to the ring's edge (or past it) drops everything and walks in
const WAIT_R := 5.0         # m from the Heart a runner waits for the spark
const ESCORT_R := 3.0       # m from the Gate the carrier's squadmates stand (the Gate takes them within gate_take_r)
const GROUND_STEPS := [1.0, 0.85, 0.7, 0.5, 0.3]

## The Ways Out mode with both kinds of seat in this match.
static func on(m: Match) -> bool:
	return m.heart != null and m.heart.site != Vector3.INF and m.exits != null and m.exits.seats != null

static func knob(k: String) -> float:
	return float((Heart.rules()["bots"] as Dictionary)[k])

## The squad's plan, by the match seed (every game picks the same one).
static func plan(m: Match, team: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(m.seed_val) * 7919 + team * 104729 + 31
	var share: Dictionary = Heart.rules()["bots"]["plans"]
	var x := rng.randf()
	for p in PLANS:
		x -= float(share[p])
		if x < 0.0:
			return p
	return PLANS[-1]

## No human plays in this squad (the local player counts as one, on --autoplay too).
static func bot_squad(m: Match, team: int) -> bool:
	for o in m.hunters:
		if o.team == team and (o == m.player or o.ctrl != "bot"):
			return false
	return true

## How many of the three early seats bot squads may take this match.
static func cap(m: Match) -> int:
	var teams := {}
	for o in m.hunters:
		teams[o.team] = true
	var bots := teams.keys().filter(func(t): return bot_squad(m, t)).size()
	return mini(int(knob("early_seats_cap_max")), bots / int(knob("early_seats_cap_per_bot_squads")))

## The squad on (or out by) each early seat, -1 for none: [lair, spark, uplink].
static func early_teams(m: Match) -> Array:
	var sq: QuestSeats = m.exits.seats
	var on_seat := func(s: QuestSeat) -> int:
		return s.team if s and s.state in [QuestSeat.S.IN_USE, QuestSeat.S.TAKEN] else -1
	var spark: int = m.heart.early_team
	if spark < 0 and m.heart.carrier:
		spark = m.heart.carrier.team
	return [on_seat.call(sq.lair), spark, on_seat.call(sq.uplink)]

## When a bot squad may start a seat: seat_delay_s after it opens (the spark: after it is charged).
static func start_t(seat: String) -> float:
	match seat:
		"lair": return QuestSeats.q("lair_open_s") + knob("seat_delay_s")
		"spark": return Heart.r("wake_s") + Heart.r("charge_s") + knob("seat_delay_s")
		"uplink": return QuestSeats.q("uplink_open_s") + knob("seat_delay_s")
	return 0.0

## This squad may start that early seat now: past the delay and under the cap (bot squads only).
static func may_start(m: Match, team: int, seat: String) -> bool:
	return not _delayed(m, team, seat) and not _capped(m, team)

static func _delayed(m: Match, team: int, seat: String) -> bool:
	return on(m) and bot_squad(m, team) and m.sess_time() < start_t(seat)

## Bot squads already hold or took as many early seats as bots may (this squad's own count too: one of
## it left behind after its squad took a seat does not start a second).
static func _capped(m: Match, team: int) -> bool:
	if not on(m) or not bot_squad(m, team):
		return false
	var taken := early_teams(m).filter(func(t): return t >= 0 and bot_squad(m, t)).size()
	return taken >= cap(m)

## [goal, kind] for the squad's seat now, or [] (nothing to do yet: loot). Sealed in a lair, or riding
## its updraft out, Lairs.bot_goal leads.
static func goal(m: Match, h: Hunter) -> Array:
	if m.lairs:
		var riding := m.lairs.list.any(func(L): return (L.get("flown", []) as Array).has(h))
		if riding or not m.lairs.sealed_lair(h).is_empty():
			return []
	var order: Array = ORDER[plan(m, h.team)]
	for seat in order + ["final"]:
		var g: Variant = _seat_goal(m, h, seat, not order.is_empty() and seat == order[0])
		if g is Array:
			return g
		if g == "wait":
			return []
	return []

## One seat: [goal, kind], "wait" (not yet: loot meanwhile) or "gone" (taken, shut, capped: the next).
static func _seat_goal(m: Match, h: Hunter, seat: String, own: bool) -> Variant:
	var t := m.sess_time()
	match seat:
		"lair": return _lair(m, h, t)
		"spark": return _spark(m, h, t, own)
		"uplink": return _uplink(m, h, t, own)
	if m.heart.state == Heart.S.DONE:
		return "gone"
	if m.heart.state == Heart.S.FINAL or t >= Heart.r("final_s") - FINAL_LEAD:
		return [_around(m, m.heart.site, h, Heart.r("final_r") * 0.5), "ring"]
	return "wait"

static func _lair(m: Match, h: Hunter, t: float) -> Variant:
	var s: QuestSeat = m.exits.seats.lair
	if s == null or s.state in [QuestSeat.S.TAKEN, QuestSeat.S.SHUT, QuestSeat.S.IN_USE]:
		return "gone"
	if s.state == QuestSeat.S.LOCKED or t < knob("raider_at_s") or _delayed(m, h.team, "lair"):
		return "wait"
	if _capped(m, h.team):
		return "gone"
	var g: Array = m.lairs.bot_lair(s.ref, h)
	return g if not g.is_empty() else "gone"

static func _spark(m: Match, h: Hunter, t: float, own: bool) -> Variant:
	var hr: Heart = m.heart
	if hr.early_team >= 0 or not inside(m, hr.gate):
		return "gone"      # (taken, or the end phase is closing over the Gate: no carrying the spark out into it)
	var c: Hunter = hr.carrier
	if c and c.team == h.team:
		return [hr.gate, "gate"] if c == h else [_around(m, hr.gate, h, ESCORT_R), "seat"]
	if c:
		return [c.pos, "chase"] if own else "gone"
	if t < knob("runner_at_s") - RUN_LEAD:
		return "wait"
	if _capped(m, h.team):
		return "gone"
	var no_rival := not _rival_near(m, h, hr.spark_pos, knob("runner_rival_r"))
	if hr.spark_live() and not _delayed(m, h.team, "spark") and no_rival:
		return [hr.spark_pos, "spark"]
	return [_around(m, hr.site, h, WAIT_R), "seat"]      # charging, the delay, or a rival on it: wait by the Heart

static func _uplink(m: Match, h: Hunter, t: float, own: bool) -> Variant:
	var s: QuestSeat = m.exits.seats.uplink
	if s == null:
		return "gone"
	if not m.exits.active_for(h.team).is_empty():
		var g: Array = m.exits.bot_goal(h, true)      # ours charging (hold the yard) or its lift open
		if not g.is_empty():
			return g
	if s.state in [QuestSeat.S.TAKEN, QuestSeat.S.SHUT]:
		return "gone"
	if s.state == QuestSeat.S.IN_USE:
		return [m.exits.yard_spot(s.ref, h), "yard"] if own else "gone"      # a rival's: stand in it, it stalls
	if s.state == QuestSeat.S.LOCKED or t < knob("holder_at_s") or _delayed(m, h.team, "uplink"):
		return "wait"
	if _capped(m, h.team):
		return "gone"
	return [s.ref["pos"], "uplink"] if m.exits.startable(s.ref) else "wait"

static func _rival_near(m: Match, h: Hunter, p: Vector3, r: float) -> bool:
	for o in m.hunters:
		if o.team != h.team and not o.out and not o.extracted and not o.downed and o.flat_dist(p) < r:
			return true
	return false

## Each bot its own spot r metres round a point (on ground), so a squad spreads out.
static func _around(m: Match, c: Vector3, h: Hunter, r: float) -> Vector3:
	var a := float(hash(h.nid) % 12) / 12.0 * TAU
	var p := c + Vector3(cos(a), 0.0, sin(a)) * r
	if m.world.is_void(p.x, p.z) or m.world.is_block(p.x, p.z):
		return c
	return Vector3(p.x, m.world.ground_at(p.x, p.z), p.z)

# ------------------------------------------------------------------ the tide ring
## How far from the Heart a goal may lie: the ring RING_LOOK seconds on, less RING_KEEP (INF: no ring yet).
static func safe_r(m: Match) -> float:
	if m.heart == null or m.heart.site == Vector3.INF or m.sess_time() + RING_LOOK < Heart.r("tide_start_s"):
		return INF
	var k: float = m.heart.ways_scale
	return Heart.ring_at(m.sess_time() + RING_LOOK, k) - RING_KEEP * k

static func inside(m: Match, p: Vector3) -> bool:
	var c: Vector3 = m.heart.site if m.heart else Vector3.ZERO
	return Vector2(p.x - c.x, p.z - c.z).length() <= safe_r(m)

## The goal itself when it is inside the ring, else the nearest ground on the way from it to the Heart.
static func keep_inside(m: Match, p: Vector3) -> Vector3:
	if p == Vector3.INF or inside(m, p):
		return p
	var c: Vector3 = m.heart.site
	var d := Vector2(p.x - c.x, p.z - c.z).normalized() * safe_r(m)
	for f: float in GROUND_STEPS:
		var q := c + Vector3(d.x, 0.0, d.y) * f
		if not m.world.is_void(q.x, q.z) and not m.world.is_block(q.x, q.z):
			return Vector3(q.x, m.world.ground_at(q.x, q.z), q.z)
	return c

## How far from the Heart a tile path from p may lead: the tide ring, or p's own distance when it stands
## farther out (INF: no ring). A path round a cliff to a ramp never runs out into the Blight.
static func path_r(m: Match, p: Vector3) -> float:
	var tr := Heart.tide_r(m)
	if tr <= 0.0 or not on(m):
		return INF
	return maxf(tr, Vector2(p.x - m.heart.site.x, p.z - m.heart.site.z).length())

## Near the ring's edge (in the end phase farther in: heart.json bots end_edge_m) or out in the tide: the
## spot to walk back in to (INF: fine where it is). Not while sealed in a lair (its walls hold the bot in;
## Lairs.bot_goal leads).
static func ring_back(m: Match, h: Hunter) -> Vector3:
	var tr := Heart.tide_r(m)
	if tr <= 0.0 or (m.lairs and not m.lairs.sealed_lair(h).is_empty()):
		return Vector3.INF
	var edge := maxf(RING_EDGE, knob("end_edge_m")) if Heart.end_phase(m) else RING_EDGE
	if h.flat_dist(m.heart.site) < tr - edge * m.heart.ways_scale:
		return Vector3.INF
	return keep_inside(m, h.pos)
