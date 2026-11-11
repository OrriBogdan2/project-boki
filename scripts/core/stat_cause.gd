class_name StatCause
## Why a trained stat moved: each gain from play (Care.STATS) writes one journal line on the Boki,
## "+2 Speed from the race", and the Boki card shows the latest one under each stat bar (StatBudgetView).
## Lines are CareJournal lines (rec["journal"]) that also carry the stat; an older record without the key
## just has none yet. Every source of a stat gain goes through gain().

## Where a gain came from, as the end of the line.
const CAUSES := {"drill": "yard training", "toy": "a toy", "race": "the race"}

## Trains `stat` by up to n points (Care.add_stat: capped by level) and notes why. Returns the points gained.
static func gain(rec: Dictionary, stat: String, n: int, cause: String) -> int:
	var gained := Care.add_stat(rec, stat, n)
	if gained > 0:
		CareJournal.note(rec, "+%d %s from %s" % [gained, Care.STATS[stat]["name"], CAUSES[cause]])
		(rec["journal"] as Array).back()["stat"] = stat
	return gained

## The latest line for a stat with its age, "+2 Speed from the race, 5 min ago", or "" if it never gained.
static func last(rec: Dictionary, stat: String, now := Time.get_unix_time_from_system()) -> String:
	var lines: Array = rec.get("journal", [])
	for i in range(lines.size() - 1, -1, -1):
		if String(lines[i].get("stat", "")) == stat:
			return "%s, %s" % [lines[i]["words"], _ago(now - float(lines[i]["t"]))]
	return ""

static func _ago(secs: float) -> String:
	if secs < 60.0: return "just now"
	if secs < 3600.0: return "%d min ago" % int(secs / 60.0)
	if secs < 86400.0: return "%d h ago" % int(secs / 3600.0)
	return "%d days ago" % int(secs / 86400.0)
