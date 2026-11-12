class_name KnockCredit
extends RefCounted
## Who gets credit when a hunter goes down, in one place: the knocker is whoever the blow is credited to
## (the last hit; a Boki's blow counts for its owner, a burn for whoever lit it), and an assister is any other
## rival hunter who damaged the victim inside ASSIST_WINDOW. Match.on_damage and the burn tick note each hit,
## Match.knock settles it and tells every kit (ArchKit.credited), so Salvage, the heals, the knock resets and
## the kill feed all read the same answer.

# s before the knock a hit still earns an assist [owner item 159: "the last ~4 s"; the wiki and kit data give none]
const ASSIST_WINDOW := 4.0

var hits := {}                 # victim id -> {hitter id -> [hitter, time of the last damage]}

static func of(m: Match) -> KnockCredit:
	if not m.has_meta("knock_credit"):
		m.set_meta("knock_credit", KnockCredit.new())
	return m.get_meta("knock_credit")

## `by` hurt `victim` just now (a Boki's hit is its owner's).
static func note(m: Match, by: Ent, victim: Ent) -> void:
	if by is Kin and by.owner_h:
		by = by.owner_h
	if not (victim is Hunter and by is Hunter) or by.team == victim.team or (victim as Hunter).downed:
		return
	var by_hitter: Dictionary = KnockCredit.of(m).hits.get_or_add(victim.get_instance_id(), {})
	by_hitter[by.get_instance_id()] = [by, m.time]

## Everyone but `knocker` who damaged `victim` in the window, standing and on another team (the log is spent).
static func assisters(m: Match, victim: Hunter, knocker: Ent) -> Array:
	var out := []
	for e in KnockCredit.of(m).hits.get(victim.get_instance_id(), {}).values():
		var h = e[0]
		if is_instance_valid(h) and h != knocker and not h.out and m.time - float(e[1]) <= ASSIST_WINDOW:
			out.append(h)
	KnockCredit.of(m).hits.erase(victim.get_instance_id())
	return out

## `victim` went down to `knocker` (a hunter, a mob, the Blight or nothing): tells the knocker's kit (mine) and each
## assister's (not mine). Returns the assisters.
static func settle(m: Match, victim: Hunter, knocker: Ent) -> Array:
	var assist := KnockCredit.assisters(m, victim, knocker)
	if knocker is Hunter and knocker.team != victim.team:
		KnockCredit._tell(knocker, victim, true)
	for a in assist:
		KnockCredit._tell(a, victim, false)
	return assist

static func _tell(h: Hunter, victim: Hunter, mine: bool) -> void:
	if h.ak and not h.remote and not h.downed and not h.out:
		h.ak.credited(victim, mine)
