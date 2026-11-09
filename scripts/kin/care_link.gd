class_name CareLink
extends RefCounted
## How a Boki's raising shows and counts as a run partner. line(): its trained stats, element and
## trust in one line (expedition panel, Boki box). mult(): a small capped scale on the carry passive
## and the merge form's passive numbers (Hunter._refresh_kin_stats). Numbers: content/rules/boki_summon.json.

static func max_bonus() -> float:
	return clampf(float(Content.rules("boki_summon").get("max_bonus", 0.0)), 0.0, 0.10)

## 1.0 for an untrained Boki, up to 1.0 + max_bonus when every trained stat is at its level cap.
static func mult(rec: Dictionary) -> float:
	if rec.is_empty():
		return 1.0
	Care.ensure(rec)
	var sum := 0.0
	for s in Care.STATS:
		sum += float(rec["stats"].get(s, 0))
	return 1.0 + max_bonus() * clampf(sum / (float(Care.STATS.size()) * float(Care.stat_cap(rec))), 0.0, 1.0)

## "Power 12 · Guard 8 · Speed 3 · Focus 5  |  Venom  |  Trust 72", and the match effect when there is one.
static func line(rec: Dictionary) -> String:
	if rec.is_empty():
		return ""
	Care.ensure(rec)
	var st: Dictionary = rec["stats"]
	var bits: Array = []
	for s in Care.STATS:
		bits.append("%s %d" % [Care.STATS[s]["name"], int(st.get(s, 0))])
	var el := String(Data.KIN[rec["species"]]["type"]).capitalize()
	var t := "%s  |  %s  |  Trust %d" % [" · ".join(bits), el, int(rec.get("trust", 0))]
	var b := mult(rec) - 1.0
	return t + ("  |  partner +%.1f%%" % (b * 100.0) if b > 0.0 else "")
