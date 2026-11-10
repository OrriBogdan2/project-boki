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

## Who a blow counts for: the Hunter a Boki rides with (the thief while it is stolen), else the hitter itself.
static func credited(by: Ent) -> Ent:
	return by.owner_h if by is Kin and by.owner_h else by

## The Boki that landed a blow (null for anything else), and its net id for the "knock" / "out" events.
static func boki_of(by: Ent) -> Kin:
	return by as Kin if by is Kin and by.owner_h else null

static func boki_nid(by: Ent) -> String:
	var k := KnockCredit.boki_of(by)
	return k.nid if k else ""

## "Vex's Cindle" when a Boki did it, else the Hunter's title.
static func name_of(hunter: Hunter, via: Ent) -> String:
	var k := KnockCredit.boki_of(via)
	return "%s's %s" % [hunter.pname, k.rec.get("name", "Boki")] if k else hunter.pname

## `by` hurt `victim` just now (a Boki's hit is its owner's).
static func note(m: Match, by: Ent, victim: Ent) -> void:
	by = KnockCredit.credited(by)
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

## The feed line and CombatBus.takedown for a knock or a kill, on every game (the remote ones from the net event).
## `hunter` is who is credited, `via` what landed the blow (a Boki, or null), `why` is how a kill happened.
static func announce(m: Match, kind: String, victim: Hunter, hunter: Ent, via: Ent, assists: Array, why := "") -> void:
	var credited_foe: bool = hunter is Hunter and hunter != victim and hunter.team != victim.team
	var who := KnockCredit.name_of(hunter, via) if credited_foe else ""
	var vic := victim.pname
	if kind == "knock":
		m.add_feed(("%s knocked %s" % [who, vic]) if credited_foe else "%s went down" % vic)
	else:
		var took := credited_foe and why not in ["abyss", "train"]
		m.add_feed(("%s took out %s" % [who, vic]) if took else Match.out_text(vic, why))
	CombatBus.takedown.emit(kind, victim, hunter if credited_foe else null, KnockCredit.boki_of(via), assists)
