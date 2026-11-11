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
##   HuntBoon.cue_gain(h, secs)         a Hunter shows the boon: the rising cue and the tick 5 s before it ends
## The sounds (content/sfx/boon.json) are for the local player's squad only: a rival's boon is silent.

const COL := Color("f2c04a")      # the boon's gold: the word, its status tile and the plate trim
const ICON := "divehawk"
const TICK_LEFT := 5.0            # s: the "ending soon" tick sounds this long before the boon runs out
const TICK_DB := -6.0             # dB: the tick is a quiet reminder
const LOST_DB := -3.0             # dB: the steal sting stays softer than the gain cue

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
		if _heard(m, victim):
			m.sfx("boon_lost", null, LOST_DB)
		for o: Hunter in XpRules.squad_paid(m, h):
			KitStatus.apply(o, "bon", t)

static func _heard(m, h: Hunter) -> bool:
	return m.player != null and h.team == m.player.team

## `h` got the boon for `secs` (any game shows it): the local squad hears the rising cue, and a tick
## 5 s before it ends. A refresh moves the end, so a tick that fires early finds more than TICK_LEFT left.
static func cue_gain(h: Hunter, secs: float) -> void:
	if not _heard(h.m, h):
		return
	h.m.sfx("boon_gain", h.pos)
	if secs > TICK_LEFT:
		h.m.later(secs - TICK_LEFT, func():
			if is_instance_valid(h) and left(h) > 0.0 and left(h) <= TICK_LEFT + 0.1:
				h.m.sfx("boon_tick", h.pos, TICK_DB))

static func left(h: Hunter) -> float:
	if h == null or h.m == null or not h.has_meta("bon_until"):
		return 0.0
	return maxf(0.0, float(h.get_meta("bon_until")) - float(h.m.time))

static func dmg_k(h: Hunter) -> float:
	return 1.0 + float(rules()["dmg"]) if left(h) > 0.0 else 1.0

static func speed_k(h: Hunter) -> float:
	return 1.0 + float(rules()["speed"]) if left(h) > 0.0 else 1.0
