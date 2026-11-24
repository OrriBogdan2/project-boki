class_name TutorialHints
extends RefCounted
## The tutorial's quiet steps (DECISIONS 2026-11-08: about 8 steps, the rest one-line first-time hints).
## A quiet step still runs (its stop, camp, marker and Boki lead are the course) but it has no strip, no
## check, no sting and no pause: its one line goes to the message lane, once per save, and an ability pick
## is made for you. Which steps: content/rules/tutorial.json "quiet"; their lines: "hint" (else the step's own).
## Save key: Save.d.tutorial "tuth_<step>".


## Whether a step is a one-line hint rather than a banner step.
static func quiet(sid: String) -> bool:
	return sid in Content.rules("tutorial")["quiet"]


## The steps the player gets a banner for, out of the ones this kit runs (Tutorial.applies).
static func banner_steps(tu: Tutorial) -> Array:
	var out := []
	for s in Tutorial.steps():
		var sid := String(s[0])
		if tu.applies(sid) and not quiet(sid):
			out.append(sid)
	return out


## The step's hint line, before the tokens are filled ("" when it says what the step says).
static func line(sid: String) -> String:
	return String(Content.rules("tutorial")["hint"].get(sid, ""))


## Says the step's line in the message lane: once per save, or again when `again` (the player is stuck on it).
static func say(tu: Tutorial, again := false) -> void:
	if tu.m.hud == null or tu.text == "":
		return
	var key := "tuth_" + tu.id()
	var seen: Dictionary = Save.d["tutorial"]
	if seen.get(key, false) and not again:
		return
	seen[key] = true
	tu.m.hud.tip(tu.text)


## A quiet pick step takes its point for you (the pick key still works the same later).
static func auto_pick(tu: Tutorial, sid: String) -> void:
	var slot := TutorialCamps.pick_slot(sid)
	if slot != "" and quiet(sid):
		tu.m.player.level_slot(slot)


## A hint step on the course keeps the short pause after it (a pick too: the next leg starts a beat later, as it did
## when the key was pressed). Only the pure-reading steps (points, ranks) pass at once.
static func settles(sid: String) -> bool:
	return sid not in ["points", "ranks"]
