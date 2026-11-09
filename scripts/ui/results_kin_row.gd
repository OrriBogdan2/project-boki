class_name ResultsKinRow
extends RefCounted
## The one Boki row on the results card: its portrait and, in one plain line, what it did this run
## (times sent out, damage, healing, saves, bond gained). Counters come from the match stats
## (HunterFeats: kin_damage, kin_healing, kin_saves) and the lead Boki's run (throws).

const PORTRAIT_PX := 40.0
const BOND_SHOWN := 0.5          # bond points; a smaller change reads as "no change"

static func _times(n: int) -> String:
	return "once" if n == 1 else "%d times" % n

## "Sent out 3 times, hit for 120 damage, healed you for 40, got you back up once, bond up 4."
static func line(r: Dictionary, s: Dictionary) -> String:
	var stats: Dictionary = r.get("stats", {})
	var runs: Array = r.get("kin_runs", [])
	var sent := int((runs[0] as Dictionary).get("stats", {}).get("throws", 0)) if not runs.is_empty() else 0
	var parts: Array[String] = []
	if sent > 0:
		parts.append("sent out " + _times(sent))
	if int(stats.get("kin_damage", 0)) > 0:
		parts.append("hit for %d damage" % int(stats["kin_damage"]))
	if int(stats.get("kin_healing", 0)) > 0:
		parts.append("healed you for %d" % int(stats["kin_healing"]))
	if int(stats.get("kin_saves", 0)) > 0:
		parts.append("got you back up " + _times(int(stats["kin_saves"])))
	var bond := float(s.get("trust_delta", 0.0))
	if absf(bond) >= BOND_SHOWN:
		parts.append("bond %s %d" % ["up" if bond > 0.0 else "down", int(round(absf(bond)))])
	if parts.is_empty():
		return "Stayed close and out of the fight."
	var text := ", ".join(parts)
	return text.substr(0, 1).to_upper() + text.substr(1) + "."

## The row: portrait, then the line (wraps if the card is narrow).
static func row(s: Dictionary, tree: SceneTree) -> Control:
	var hb := UI.hbox(10)
	hb.set_meta("kin_row", true)
	hb.add_child(KinPortrait.view(s["kin"], tree, PORTRAIT_PX))
	var l := UI.label(String(s["kin_line"]), 14, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(l)
	return hb
