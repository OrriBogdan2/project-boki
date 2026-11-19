extends RefCounted
## --extract-goal-check: the one-line extraction objective (ExtractGoal) and the newcomer's strip.
##   1. it points at the open seat, else the one that opens soonest; a new player only at the Uplink or the Heart ring
##   2. the words say the seat, when it opens or how far it is, and the key to hold
##   3. taken and lost seats are not offered; no line when you are out
## Plays a solo Hunter in a 4-squad match with the Heart (as --hud-groups-check does); never touches the save.

const HUD_CHECK := preload("res://tools/hud_groups_check.gd")

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("EXTRACTGOAL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func at(m: Match, sess: float) -> void:
	m.sess_t0 = sess - m.time

func run(main: Node) -> void:
	var m: Match = await HUD_CHECK.make_match(main)
	var q: Dictionary = Heart.rules()["quest"]
	at(m, 30.0)
	ok(ExtractGoal.pick(m, false) == 0, "veteran, 0:30: the Lair opens first")
	ok(ExtractGoal.pick(m, true) == 2, "new player, 0:30: only the Uplink (no boss fight, no Heart to carry)")
	at(m, float(q["lair_open_s"]) + 5.0)
	ok(ExtractGoal.pick(m, false) == 0, "veteran: the open Lair beats a locked seat")
	var lair_open := ExtractGoal.status(m, 0, WaysOutHud.seats(m)[0])
	ok(lair_open.begins_with("Sealed Lair open") and lair_open.ends_with(" m"), "open words (%s)" % lair_open)
	at(m, float(q["uplink_open_s"]) - 90.0)
	var locked := ExtractGoal.status(m, 2, WaysOutHud.seats(m)[2])
	ok(locked == "Uplink opens 1:30", "locked words: seat and clock (%s)" % locked)
	var how := ExtractGoal.how(2)
	ok(how.contains(Settings.key_cap("interact")) and how.begins_with("Hold"), "the how names the key (%s)" % how)
	ok(not ExtractGoal.how(3).contains("%F"), "no key placeholder is left in any line")
	at(m, float(q["uplink_shut_s"]) + 5.0)
	ok(ExtractGoal.pick(m, true) == 3, "new player, the Uplink lost: the Heart ring")
	at(m, float(q["uplink_open_s"]) + 5.0)
	ok(ExtractGoal.shown(m), "a seat is open: the line shows")
	m.player.out = true
	ok(not ExtractGoal.shown(m), "out of the match: no line (Ways out left is yours)")
	m.player.out = false
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	ok(true, "the real HUD drew the line")
	m.queue_free()
	print("EXTRACTGOAL DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)
