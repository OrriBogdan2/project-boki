class_name BotZone
extends RefCounted
## Bots and the closing zone (ShrinkZone, docs/decisions/0060-shrinking-zone.md). A bot keeps to the
## circle that counts: the one closing now, or the next one once the time before its edge reaches the
## bot is under the bot's travel time inside (BotRoute.eta: legs, pads, glides, ringed lanes) times
## SLACK plus the lead (content/rules/shrink_zone.json bot_lead_s). Until then it loots and fights as
## usual, but only for goals inside that circle; once it has to go it drops the fight and heads for
## the spot inside it can reach soonest. Bot calls goal() and drop_fight(); nothing here goes over Net.

const SLACK := 1.4          # bots walk round rocks and wait at pads: a little slower than the plan
const IN_M := 6.0           # m inside the circle a goal or a spot must be (at most a third of r)
const SPOT_R := 0.5         # spots tried at this share of the radius from the centre ...
const SPOT_DIRS := 6        # ... in this many directions round it, plus the one toward the bot
const ETA_EVERY := 1.5      # s between travel-time re-checks for one bot

## The goal Bot should head for instead of `want`: `want` while it is inside the circle that counts
## (and so is the bot), else a spot inside that circle. Sets h.ai["zone_go"] while the bot must move.
static func goal(m: Match, h: Hunter, want: Vector3) -> Vector3:
	var z: ShrinkZone = m.zone
	h.ai["zone_go"] = false
	if z == null:
		return want
	var j := keep(m, h)
	if j == 0:
		return want
	var c := z.cs[j]
	var inner := z.rs[j] - minf(IN_M, z.rs[j] / 3.0)
	var here := Vector2(h.pos.x, h.pos.z)
	if here.distance_to(c) < inner and (want == Vector3.INF or Vector2(want.x, want.z).distance_to(c) < inner):
		return want
	h.ai["zone_go"] = here.distance_to(c) >= inner
	var spot := _spot(m, h, j)
	return want if spot == Vector3.INF else spot

## A fight Bot should drop: the bot is outside the edge, or it has to go and the foe is outside the
## circle it is heading for.
static func drop_fight(m: Match, h: Hunter, foe) -> bool:
	var z: ShrinkZone = m.zone
	if z == null or foe == null:
		return false
	if z.k > 0 and z.outside(h.pos):
		return true
	if not h.ai.get("zone_go", false):
		return false
	var j := keep(m, h)
	return Vector2(foe.pos.x, foe.pos.z).distance_to(z.cs[j]) > z.rs[j]

## The circle the bot has to keep to now (0: none, the first circle covers the map).
static func keep(m: Match, h: Hunter) -> int:
	var z: ShrinkZone = m.zone
	var j := z.k
	var nx := j + 1
	if nx > z.last():
		return j
	var p := Vector2(h.pos.x, h.pos.z)
	if p.distance_to(z.cs[nx]) < z.rs[nx]:
		return j      # already inside the next one
	var left := _passes(z, nx, p) - m.time
	return nx if left < _eta(m, h, nx) * SLACK + float(ShrinkZone.rules()["bot_lead_s"]) else j

## Seconds from the bot to its spot inside circle j, re-checked every ETA_EVERY s.
static func _eta(m: Match, h: Hunter, j: int) -> float:
	var e: Dictionary = h.ai.get("zone_eta", {})
	if int(e.get("j", -1)) != j or m.time - float(e.get("t", -99.0)) > ETA_EVERY:
		var spot := _spot(m, h, j)
		var s := BotRoute.eta(m.world, h.pos, spot) if spot != Vector3.INF else INF
		e = {"j": j, "t": m.time, "s": minf(s, 999.0)}
		h.ai["zone_eta"] = e
	return float(e["s"])

## When close j's moving edge passes p (its start when p is already outside where it starts from).
static func _passes(z: ShrinkZone, j: int, p: Vector2) -> float:
	var steps := 12
	for i in steps + 1:
		var f := float(i) / steps
		if p.distance_to(z.cs[j - 1].lerp(z.cs[j], f)) > lerpf(z.rs[j - 1], z.rs[j], f):
			return lerpf(z.t0[j], z.t1[j], f)
	return z.t1[j]

## The spot inside circle j the bot can reach soonest, chosen once per circle (again if Bot gave up
## on it: no way there).
static func _spot(m: Match, h: Hunter, j: int) -> Vector3:
	var z: ShrinkZone = m.zone
	var at: Vector3 = h.ai.get("zone_at", Vector3.INF)
	var gave_up := float(h.ai.get("banned", {}).get(at, -1.0)) > m.time
	if int(h.ai.get("zone_j", -1)) == j and at != Vector3.INF and not gave_up:
		return at
	var c := z.cs[j]
	var r := z.rs[j]
	var inner := r - minf(IN_M, r / 3.0)
	var here := Vector2(h.pos.x, h.pos.z)
	var tries := [c + (here - c).limit_length(r * SPOT_R)]
	var turn := randf() * TAU
	for i in SPOT_DIRS:
		tries.append(c + Vector2.from_angle(turn + TAU * i / SPOT_DIRS) * r * SPOT_R)
	tries.append(c)
	var best := Vector3.INF
	var best_s := INF
	for q in tries:
		var p := m.world.free_spot_near(Vector3(q.x, 0, q.y), [], 1.0, 0.45, minf(16.0, r * 0.4))
		if p == Vector3.INF or (gave_up and p.distance_to(at) < 2.0) or Vector2(p.x, p.z).distance_to(c) > inner:
			continue
		var s := BotRoute.eta(m.world, h.pos, p)
		if s < best_s:
			best = p
			best_s = s
	h.ai["zone_j"] = j
	h.ai["zone_at"] = best
	return best
