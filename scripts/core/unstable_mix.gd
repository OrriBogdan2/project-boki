class_name UnstableMix
## An unstable mix (briefs/design/GARDEN.md section 6): a Nook pair whose elements clash or whose tempers
## oppose. The baby hatches low on joy with a "needs extra care" tag that clears after a day of care.
## It is a story, never a loss. Tuning and the 18-type table: content/rules/unstable_mix.json.

static func _rules() -> Dictionary:
	return Content.rules("unstable_mix")

static func _theme(rec: Dictionary) -> String:
	return String(Data.KIN.get(rec["species"], {}).get("theme", ""))

## Why this pair is unstable, in plain words ("" when it is calm).
static func why(a: Dictionary, b: Dictionary) -> String:
	var ta := _theme(a)
	var tb := _theme(b)
	for c in _rules()["clashes"]:
		if (c[0] == ta and c[1] == tb) or (c[0] == tb and c[1] == ta):
			return "%s and %s clash" % [DexView.type_name(ta), DexView.type_name(tb)]
	var gap: float = _rules()["trait_gap"]
	var words: Dictionary = _rules()["traits"]
	for t in words:
		var xa := float(a["traits"].get(t, 0.5))
		var xb := float(b["traits"].get(t, 0.5))
		if absf(xa - xb) < gap: continue
		var hi: int = 0 if xa > xb else 1     # which word goes with the higher value
		return "one is %s and the other %s" % [words[t][hi], words[t][1 - hi]]
	return ""

static func unstable(a: Dictionary, b: Dictionary) -> bool:
	return why(a, b) != ""

## The Nook preview line for a pair ("" when calm).
static func preview_line(a: Dictionary, b: Dictionary) -> String:
	var w := why(a, b)
	return "" if w == "" else "Unstable mix: %s. The baby hatches low on joy and needs extra care for a day." % w

## Hatch: low joy and the tag, with the care still owed in rec["extra_care"] (seconds).
static func mark(baby: Dictionary) -> void:
	baby["needs"]["joy"] = float(_rules()["hatch_joy"])
	baby["extra_care"] = float(_rules()["care_s"])

## Time passing at home: only time spent in fine condition counts. At zero the tag is gone.
static func tick(rec: Dictionary, secs: float) -> void:
	if not rec.has("extra_care") or Care.condition(rec) < float(_rules()["fine_condition"]): return
	rec["extra_care"] = float(rec["extra_care"]) - secs
	if float(rec["extra_care"]) <= 0.0: rec.erase("extra_care")
