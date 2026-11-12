class_name FriendlyBodies
extends RefCounted
## Your own and allied bodies (hunters, Boki) do not alter your abilities (item 56). They are pass-through
## for a body you knock, pull or carry and for your own dash, so the shove-apart in Match._separate skips those
## pairs and a wall stun comes only from real walls and terrain. Shots already skip same-team targets
## (Match._shot_targets); `shot_may_hit` is the one rule for that.

const KNOCK_WINDOW := 0.9      # s after a knock in which a body is still travelling on it

## Do `a` and `b` fight on the same side (a team, or a Boki and its owner's team, or a truce)?
static func friendly(m: Match, a: Ent, b: Ent) -> bool:
	if a == b:
		return false
	var ta := _side(a)
	var tb := _side(b)
	if ta == tb:
		return true
	return m.truce != null and m.truce.allied(ta, tb)

static func _side(e: Ent) -> int:
	if e is Kin and (e as Kin).owner_h != null:
		return (e as Kin).owner_h.team
	return e.team

## May a shot fired by `team` connect with `e`? Friendly bodies are never in its way.
static func shot_may_hit(m: Match, team: int, e: Ent) -> bool:
	var side := _side(e)
	return side != team and not (m.truce != null and m.truce.allied(team, side))

## Is `e` carrying its own momentum: a dash, a charge, a knock in flight, or a tow?
static func moving_on_purpose(m: Match, e: Ent) -> bool:
	if e is Hunter:
		var h := e as Hunter
		if h.roll_t > 0.0 or not h.charge.is_empty() or m.time - h.kb_t < KNOCK_WINDOW:
			return true
	if m.time - e.kb_time < KNOCK_WINDOW:
		return true
	return not m.displace.towing(e).is_empty()

## Who put `e` in motion: the tow's caster, or whoever last hit it while it flies; null for its own dash.
static func mover_of(m: Match, e: Ent) -> Ent:
	var rec: Dictionary = m.displace.towing(e)
	if not rec.is_empty() and rec["by"] != null:
		return rec["by"]
	if m.time - maxf(e.kb_time, (e as Hunter).kb_t if e is Hunter else -9.0) < KNOCK_WINDOW:
		return e.last_hit_by
	return null

## Should the shove-apart skip this pair? True when one is travelling and the other is on its side (its own
## dash against its Boki or ally, or a body its caster knocks or hauls against the caster's side).
static func pass_through(m: Match, a: Ent, b: Ent) -> bool:
	return _passes(m, a, b) or _passes(m, b, a)

static func _passes(m: Match, mover: Ent, other: Ent) -> bool:
	if not moving_on_purpose(m, mover):
		return false
	if friendly(m, mover, other):
		return true
	var src := mover_of(m, mover)
	if src == null or not is_instance_valid(src):
		return false
	# a hauled body slides through its hauler; a knocked one still meets the hunter who hit it (the dash that
	# knocks it, the leap that lands on it), only its caster's side is pass-through
	return friendly(m, src, other) or (src == other and not m.displace.towing(mover).is_empty())
