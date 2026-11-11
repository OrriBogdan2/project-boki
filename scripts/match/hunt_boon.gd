class_name HuntBoon
extends RefCounted
## Boon of the Hunt (content/rules/xp.json "boon", EARLY_CAMPS_DROP.md 6.6): the Hunters a lair
## boss's or the Watcher's kill pays get more damage and move speed for a while, so those last hits
## are the biggest in the match, stolen or not. Knocking a holder ends theirs and passes the time
## they had left to the knocker's squad that the knock pays. One boon a Hunter: a second refreshes.
## It is the KitStatus "bon" (the meta "bon_until"): each game grants it to the Hunters it owns, the
## ones XpRules.squad_paid names, and the "kst" event shows it on every game's plates.
##
## Public API:
##   HuntBoon.on_kill(m, mb, by)        `mb` died to `by`: the boon to the squad it pays, for a boss
##   HuntBoon.on_knock(m, victim, by)   `victim` went down to `by`: their boon ends or passes on
##   HuntBoon.left(h) -> float          seconds of boon left (0 without one)
##   HuntBoon.dmg_k(h), HuntBoon.speed_k(h) -> float   the damage and move-speed multipliers

const COL := Color("f2c04a")      # the boon's gold: the word, its status tile and the plate trim
const ICON := "divehawk"

static func rules() -> Dictionary:
	return XpRules.rules()["boon"]

static func on_kill(m, mb: Mob, by) -> void:
	if not (mb is Boss or String(mb.mkind) in rules()["from"]):
		return
	for h: Hunter in XpRules.squad_paid(m, by):
		KitStatus.apply(h, "bon", float(rules()["secs"]))

## Every game sees the knock, so each ends the victim's boon itself; only a rival Hunter's knock
## passes it on.
static func on_knock(m, victim: Hunter, by) -> void:
	var t := left(victim)
	if t <= 0.0:
		return
	victim.set_meta("bon_until", 0.0)
	var h = by.owner_h if by is Kin else by
	if h is Hunter and h.team != victim.team:
		for o: Hunter in XpRules.squad_paid(m, h):
			KitStatus.apply(o, "bon", t)

static func left(h: Hunter) -> float:
	if h == null or h.m == null or not h.has_meta("bon_until"):
		return 0.0
	return maxf(0.0, float(h.get_meta("bon_until")) - float(h.m.time))

static func dmg_k(h: Hunter) -> float:
	return 1.0 + float(rules()["dmg"]) if left(h) > 0.0 else 1.0

static func speed_k(h: Hunter) -> float:
	return 1.0 + float(rules()["speed"]) if left(h) > 0.0 else 1.0
