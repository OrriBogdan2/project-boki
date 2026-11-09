class_name CareJournal
extends RefCounted
## Each Boki's journal: what happened to it, as short lines (rec["journal"], the last KEEP). The Boki card
## shows it, and arriving home lists what is new since the last arrival on one "While you were away" card
## (HomeAway). Lines are plain facts and gifts: nothing in here says lost, starved or sick.

const KEEP := 20            # lines kept per Boki
const MERGE_S := 600.0      # seconds: feeding the same food again within this adds to the same line

## One meal. `lean_before` is rec["lean"] from before the meal: any element that grew is named on the line.
static func fed(rec: Dictionary, food: String, lean_before: Dictionary) -> void:
	var lean: Dictionary = rec.get("lean", {})
	var up: Array = []
	for el in lean:
		if float(lean[el]) > float(lean_before.get(el, 0.0)):
			up.append(String(el).capitalize())
	var now := Time.get_unix_time_from_system()
	var lines: Array = rec.get("journal", [])
	var last: Dictionary = lines.back() if not lines.is_empty() else {}
	if String(last.get("food", "")) == food and now - float(last["t"]) < MERGE_S:
		last["n"] = int(last["n"]) + 1
		last["t"] = now
		for el in up:
			if not (last["up"] as Array).has(el): last["up"].append(el)
		return
	lines.append({"t": now, "food": food, "n": 1, "up": up})
	if lines.size() > KEEP: lines.pop_front()
	rec["journal"] = lines

## A line in words: "ate 3 Boki kibble: Fire lean up".
static func text(e: Dictionary) -> String:
	var s := "ate %s" % Care.food_name(String(e["food"]))
	if int(e["n"]) > 1: s = "ate %d × %s" % [int(e["n"]), Care.food_name(String(e["food"]))]
	if not (e["up"] as Array).is_empty(): s += ": %s lean up" % " and ".join(e["up"])
	return s

## The card lines for arriving home: every Boki's lines newer than the last arrival ("Pip: ate ..."),
## oldest first. Moves the mark to now, so the next arrival starts from here.
static func arrival() -> Array:
	var since := float(Save.d.get("away_seen", 0.0))
	Save.d["away_seen"] = Time.get_unix_time_from_system()
	var found: Array = []
	for rec in Save.d["roster"]:
		for e in rec.get("journal", []):
			if float(e["t"]) > since:
				found.append([float(e["t"]), "%s: %s" % [rec["name"], text(e)]])
	found.sort_custom(func(a, b): return a[0] < b[0])
	return found.map(func(f): return f[1])

## The Boki card's journal: its lines, newest first.
static func card(rec: Dictionary, into: Control) -> void:
	into.add_child(UI.section("Journal", UI.FAINT.lightened(0.2)))
	var lines: Array = rec.get("journal", [])
	if lines.is_empty():
		into.add_child(UI.para("Nothing yet: feed it and play with it.", 12, UI.FAINT))
	for i in range(lines.size() - 1, -1, -1):
		into.add_child(UI.para(HomeNotices.bullet(text(lines[i])), 12, UI.MUTED))
