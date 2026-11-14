class_name TutorialResume
extends RefCounted
## Quitting the combat tutorial part-way: Save.d.tutorial.tut_beat is the id of the last finished beat,
## and Continue on the title opens the tutorial again at the beat after it (Tutorial restores the
## state that beat needs). Finishing or skipping it (Match._finish) sets tutorial.match, which ends all this.
## docs/decisions/0101-tutorial-resume.md.

## Beats whose state lives in the world's outpost resume at the start of that run.
const OUTPOST_RUN := ["uplink", "defend", "extract"]
const OUTPOST_START := "goexit"


static func opts() -> Dictionary:
	return {"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0}


## Hatched but the tutorial was never finished or skipped (and the farm was never reached).
static func pending() -> bool:
	if "--skip-tutorial" in OS.get_cmdline_user_args() or Save.d["roster"].is_empty():
		return false
	var t: Dictionary = Save.d["tutorial"]
	var over: bool = t.get("match", false) or t.get("home", false) or t.get("day1_done", false)
	return bool(t.get("hatched", false)) and not over


static func last_beat() -> String:
	return String(Save.d["tutorial"].get("tut_beat", ""))


## A beat was finished: remember it. (Extracting, the last beat, ends the match and sets tutorial.match.)
static func remember(beat: String) -> void:
	Save.d["tutorial"]["tut_beat"] = beat
	Save.save_game()


## The step index to carry on at after a finished beat (0 when none, or the beat is unknown).
static func step_after(beat: String) -> int:
	var list := Tutorial.steps()
	for i in list.size():
		if String(list[i][0]) == beat:
			if i + 1 < list.size() and OUTPOST_RUN.has(String(list[i + 1][0])):
				return _index(OUTPOST_START)
			return i + 1
	return 0


static func _index(beat: String) -> int:
	var list := Tutorial.steps()
	for i in list.size():
		if String(list[i][0]) == beat:
			return i
	return 0


## v11 -> v12: a save that got past the tutorial (played, or reached the farm) has finished it.
static func migrate(data: Dictionary) -> void:
	var t: Dictionary = data.get("tutorial", {})
	if t.is_empty() or bool(t.get("match", false)):
		return
	var ft = t.get("ft")
	var farmed: bool = typeof(ft) == TYPE_DICTIONARY and not (ft.get("did", {}) as Dictionary).is_empty()
	var played: bool = int(data.get("matches", 0)) > 0 or int(data.get("extracts", 0)) > 0
	if played or farmed or t.get("home", false) or t.get("day1_done", false):
		t["match"] = true
