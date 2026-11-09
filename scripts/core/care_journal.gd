class_name CareJournal
extends RefCounted
## Each Boki's journal: what happened to it, as short lines (rec["journal"], the last KEEP). The Boki card
## shows it (JournalCard), and arriving home lists what is new since the last arrival on one "While you
## were away" card, with a small gift after a long absence. Lines are plain facts and gifts: nothing in
## here says lost, starved or sick.

const KEEP := 20            # lines kept per Boki
const MERGE_S := 600.0      # seconds: feeding the same food again within this adds to the same line
const GIFT_AWAY_S := 4.0 * 3600.0      # seconds away before a Boki has saved you a snack

## One meal. `lean` is the affinity the meal built (Evo.eat), "" for none: it is named on the line.
static func fed(rec: Dictionary, food: String, lean: String) -> void:
	var lines: Array = rec.get("journal", [])
	var last: Dictionary = lines.back() if not lines.is_empty() else {}
	var now := Time.get_unix_time_from_system()
	if String(last.get("food", "")) == food and now - float(last["t"]) < MERGE_S:
		last["n"] = int(last["n"]) + 1
		last["t"] = now
		return
	_add(rec, {"t": now, "food": food, "n": 1, "lean": lean})

## Any other happening (a game with a toy, a race, a lean change): `words` is the whole line, "won the Dash".
static func note(rec: Dictionary, words: String) -> void:
	_add(rec, {"t": Time.get_unix_time_from_system(), "words": words})

## A new form or part from a level up (Evo.on_level's event): "became a Zapfang", "grew horns".
static func evolved(rec: Dictionary, ev: Dictionary) -> void:
	if ev["kind"] == "form":
		note(rec, "became a %s" % ev["to"])
	else:
		note(rec, "grew %s" % Evo.PART_NAMES.get(ev["part"], ev["part"]))

static func _add(rec: Dictionary, e: Dictionary) -> void:
	var lines: Array = rec.get("journal", [])
	lines.append(e)
	if lines.size() > KEEP:
		lines.pop_front()
	rec["journal"] = lines

## A line in words: "ate 3 × Emberberry: Fierce lean up".
static func text(e: Dictionary) -> String:
	if e.has("words"):
		return String(e["words"])
	var food := Care.food_name(String(e["food"]))
	var s := "ate %d × %s" % [int(e["n"]), food] if int(e["n"]) > 1 else "ate %s" % food
	var lean := String(e.get("lean", ""))
	if Evo.AFF.has(lean):
		s += ": %s lean up" % Evo.AFF[lean]["name"]
	return s

## The card lines for arriving home: every Boki's lines newer than the last arrival ("Pip: ate ..."),
## oldest first, then a gift after a long absence and any egg ready. Moves the mark to now.
static func arrival() -> Array:
	var now := Time.get_unix_time_from_system()
	var since := float(Save.d.get("away_seen", 0.0))
	Save.d["away_seen"] = now
	var found: Array = []
	for rec in Save.d["roster"]:
		for e in rec.get("journal", []):
			if float(e["t"]) > since:
				found.append([float(e["t"]), "%s: %s" % [rec["name"], text(e)]])
	found.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array = found.map(func(f): return f[1])
	if since > 0.0 and now - since >= GIFT_AWAY_S:
		out.append_array(_gift(now))
	for egg in Incubator.ready_eggs():
		out.append("A %s is ready to hatch" % Incubator.egg_name(egg))
	return out

## A Boki saved you a snack: one of the food its leading affinity loves, into the pantry.
static func _gift(now: float) -> Array:
	var roster: Array = Save.d["roster"].filter(func(r): return not KinBox.is_boxed(r))
	if roster.is_empty():
		return []
	var rec: Dictionary = roster[int(now) % roster.size()]
	var food := String(Evo.AFF[Evo.leading(rec)]["food"])
	Save.d["crops"][food] = int(Save.d["crops"].get(food, 0)) + 1
	_add(rec, {"t": now, "words": "saved you a snack: %s" % Care.food_name(food)})      # at the mark: not new next time
	return ["%s saved you a snack: %s" % [rec["name"], Care.food_name(food)]]
