class_name StolenHome
extends RefCounted
## A Boki that a rival took as a wisp and that went home when the match ended (DECISIONS 2026-11-09, Stealing).
## It is never lost, so this is only the feeling of it: the match gives it one event (back), the results fold it
## into the Boki's memory and its journal line (the "While you were away" card shows the journal), and in the
## garden its friends come to greet it through the base life's React state. No reward, no penalty.

## uids of Boki that came home from a thief since the garden last looked (Game.apply_result adds, arrive takes).
static var pending: Array = []

## he / she for the memory and card lines, never "it".
static func pronoun(rec: Dictionary) -> String:
	return "she" if Unique.sex(rec) == "f" else "he"

## The one line, in the Boki's own memory and on the card: "was stolen by Rook, but she came home".
static func line(rec: Dictionary, thief: String) -> String:
	return "was stolen by %s, but %s came home when the match ended" % [thief, pronoun(rec)]

## Match side, from KinSteal.go_home: a wisp that was held by a thief goes home to its local owner. Once.
static func back(k: Kin) -> void:
	var thief := String(k.get_meta("thief", ""))
	k.remove_meta("thief")
	if thief != "" and not k.remote and k.home_h == k.m.player:
		k.note("stolen_home", line(k.rec, thief))

## Results side, from Game._kin_after: the journal line for the card, and the greeting waits for the garden.
static func came_back(rec: Dictionary, words: String) -> void:
	CareJournal.note(rec, words)
	pending.append(String(rec["uid"]))

## The garden: each returned Boki that is out gets its friends over (BaseLife.arrived); the rest are forgotten.
static func arrive(h) -> void:
	for uid in pending:
		for k in h.kins:
			if String(k["rec"]["uid"]) == uid and h.life:
				h.life.arrived(k, true)
	pending.clear()
