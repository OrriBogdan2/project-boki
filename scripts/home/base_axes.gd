class_name BaseAxes
extends RefCounted
## Raising leans a Boki (docs/decisions/0177-raising-leans.md). Care moves three axes, each -1..1 in
## rec["raised"]: bold (shy..bold), busy (lazy..busy), gentle (rough..gentle). BaseLife.choose scales the odds of
## its nap, play, chase and cling picks by mult(). Tuning: content/rules/base_axes.json.

const AXES := ["bold", "busy", "gentle"]


## Every Boki carries a lean (a new one starts at none).
static func ensure(rec: Dictionary) -> void:
	if not rec.has("raised"):
		rec["raised"] = {"bold": 0.0, "busy": 0.0, "gentle": 0.0}


## Save migration (v22 -> v23): every Boki in an older save gets its lean.
static func migrate(data: Dictionary) -> void:
	for rec in data.get("roster", []):
		if typeof(rec) == TYPE_DICTIONARY and not rec.is_empty():
			ensure(rec)


## A first care of the day of `kind` (Care.care_day): steps the axes it leans, and notes crossing a band.
static func care(rec: Dictionary, kind: String) -> void:
	var tune := Content.rules("base_axes")
	ensure(rec)
	var raised: Dictionary = rec["raised"]
	for axis in tune["steps"].get(kind, {}) as Dictionary:
		var was := float(raised[axis])
		raised[axis] = clampf(was + float(tune["steps"][kind][axis]), -float(tune["cap"]), float(tune["cap"]))
		_band_line(rec, axis, was, float(raised[axis]), tune)


## The odds scale of `activity` (a key of the rules' weights) for this Boki: 1 with no lean.
static func mult(rec: Dictionary, activity: String) -> float:
	var tune := Content.rules("base_axes")
	var raised: Dictionary = rec.get("raised", {})
	var scale := 1.0
	for axis in tune["weights"][activity] as Dictionary:
		scale += float(tune["weights"][activity][axis]) * float(raised.get(axis, 0.0))
	return clampf(scale, float(tune["mult"][0]), float(tune["mult"][1]))


static func _band_line(rec: Dictionary, axis: String, from: float, to: float, tune: Dictionary) -> void:
	var band := float(tune["band"])
	if absf(from) >= band or absf(to) < band:
		return
	var words := "is getting " + String(tune["words"][axis][0 if to > 0.0 else 1])
	if not (rec.get("journal", []) as Array).any(func(line): return line.get("words", "") == words):
		CareJournal.note(rec, words)  # a lean that wobbles across the band says it once
