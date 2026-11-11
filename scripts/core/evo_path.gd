class_name EvoPath
## The path meter of a branching final (briefs/design/GARDEN_MODERN.md section 3, docs/decisions/0022).
## Each final of a line is one end; pips come from five sources (stat lead, element lean, worn path tokens,
## care, Cup Ribbons), all tuned in content/rules/evo_paths.json. The end with more pips is the form; a tie
## goes to the stat lead, and with that tied too the Boki waits. Ink lines have no pips, only a preview.

const SOURCES := ["stat", "lean", "tokens", "care", "ribbons"]
const ART := "res://art/kin/%s/%s.glb"

static func rules() -> Dictionary:
	return Content.rules("evo_paths")

## The branching line of this Boki's species ({} when its line does not branch by pips).
static func line(rec: Dictionary) -> Dictionary:
	return rules()["lines"].get(String(rec.get("species", "")), {})

## Per end of the line, the pip sources that count: [[{source, count}, ...], [...]] ([] for no line).
static func pips(rec: Dictionary) -> Array:
	var ln := line(rec)
	if ln.is_empty():
		return []
	var ends: Array = ln["ends"]
	var lead := _stat_lead(rec, ends)
	var out := []
	for i in ends.size():
		var e: Dictionary = ends[i]
		var counts := {"stat": int(rules()["pips"]["stat_lead"]) if lead == i else 0, "lean": _lean(rec, e),
				"tokens": _tokens(rec, e), "care": _care(rec, e), "ribbons": _ribbons(rec, e)}
		var list := []
		for s in SOURCES:
			if int(counts[s]) > 0:
				list.append({"source": s, "count": int(counts[s])})
		out.append(list)
	return out

static func total(list: Array) -> int:
	var n := 0
	for p in list:
		n += int(p["count"])
	return n

## The end index this Boki is growing toward: more pips, then the stat lead; -1 when undecided (or no line).
static func winner(rec: Dictionary) -> int:
	var p := pips(rec)
	if p.is_empty():
		return -1
	var a := total(p[0])
	var b := total(p[1])
	if a != b:
		return 0 if a > b else 1
	return _stat_lead(rec, line(rec)["ends"])

## Its final is due: a branching line, at or past the line's level, not evolved yet.
static func due(rec: Dictionary) -> bool:
	var ln := line(rec)
	return not ln.is_empty() and int(rec.get("level", 1)) >= int(ln["level"]) and String(rec.get("final", "")) == ""

static func has_art(form: String) -> bool:
	return ResourceLoader.exists(ART % [form, form])

## Why "Evolve now" can't happen now ("" when it can): "stay", "undecided" or "art".
static func blocked(rec: Dictionary) -> String:
	if rec.get("stay", false):
		return "stay"
	var w := winner(rec)
	if w < 0:
		return "undecided"
	return "" if has_art(String(line(rec)["ends"][w]["form"])) else "art"

## Evolve now: the Boki takes the winning final. False (nothing changes) when it is not due or blocked.
static func evolve(rec: Dictionary) -> bool:
	if not due(rec) or blocked(rec) != "":
		return false
	rec["final"] = String(line(rec)["ends"][winner(rec)]["form"])
	return true

## The player has met this form (Field Book), so its card shows its shape and name, not a black '?'.
static func known(form: String) -> bool:
	var e := Care.dex_entry(form)
	return bool(e.get("seen", false)) or bool(e.get("caught", false))

## Ink lines: for each Ink in the bag, the form it would make ([{ink, form, name}]); [] for other species.
static func ink_previews(rec: Dictionary) -> Array:
	var ln: Dictionary = rules()["inks"].get(String(rec.get("species", "")), {})
	var out := []
	for ink in ln.get("forms", {}):
		if int(Save.d.get("items", {}).get(ink, 0)) > 0:
			var nm := String(ln["forms"][ink])
			out.append({"ink": ink, "form": nm.to_lower(), "name": nm})
	return out

static func _stat_lead(rec: Dictionary, ends: Array) -> int:
	var st: Dictionary = rec.get("stats", {})
	var a := int(st.get(String(ends[0]["stat"]), 0))
	var b := int(st.get(String(ends[1]["stat"]), 0))
	if a == b:
		return -1
	return 0 if a > b else 1

static func _lean(rec: Dictionary, e: Dictionary) -> int:
	var f := float(rec.get("lean", {}).get(String(e["type"]), 0.0)) / Evo.LEAN_FULL
	if f >= 1.0:
		return int(rules()["pips"]["lean_full"])
	return int(rules()["pips"]["lean_half"]) if f >= float(rules()["lean_half_at"]) else 0

static func _tokens(rec: Dictionary, e: Dictionary) -> int:
	var n := 0
	for t in rec.get("path", []):
		if GardenItems.aff_of(t) == String(e["path"]):
			n += 1
	return mini(n, int(rules()["pips"]["tokens_max"]))

static func _care(rec: Dictionary, e: Dictionary) -> int:
	var n := 0
	for t in e["traits"]:
		if float(rec.get("traits", {}).get(t, 0.5)) >= float(rules()["trait_at"]):
			n = int(rules()["pips"]["care_trait"])
	var top := ""
	var most := 0
	var use: Dictionary = rec.get("toy_use", {})
	for toy in use:
		if int(use[toy]) > most:
			most = int(use[toy])
			top = toy
	if top != "" and String(HomeToys.rules()["toys"].get(top, {}).get("stat", "")) == String(e["stat"]):
		n += int(rules()["pips"]["care_toy"])
	return n

static func _ribbons(rec: Dictionary, e: Dictionary) -> int:
	var n := 0
	for sport in e["sports"]:
		n += int(rec.get("ribbons", {}).get(sport, {}).get("n", 0))
	return mini(n, int(rules()["pips"]["ribbons_max"]))
