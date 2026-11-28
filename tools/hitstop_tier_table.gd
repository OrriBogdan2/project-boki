extends RefCounted
## --impact-weight-check section 11: the hit-stop tier table (docs/MOVEMENT_FEEL.d/1128-hitstop-tiers.md), one row
## per Hunter and LMB / RMB / E / R (the ult, the "x" slot) hit. Each row's measured cells are rebuilt from the
## presses at the dummy (section 4) and the rules, so a doc cell that no longer matches fails (the row to paste is
## printed as a TIERROW line). The source rule: a slot the source makes heavy (an ult's hit or a slam) lands heavy.

const DOC := "res://docs/MOVEMENT_FEEL.d/1128-hitstop-tiers.md"
const SLOTS := {"lmb": "LMB", "rmb": "RMB", "e": "E", "x": "R"}
const SOURCES := ["light", "medium", "heavy", "none"]
const FPS := 60.0
const DEFAULT_SLIDER := 0.3  # the Screen shake slider's default (Settings), for the kick's amplitude
const AMP_PER_POWER := 0.25  # world units at power 1, full slider (1123-shake-table.md)
## Columns: 0 Hunter, 1 slot, 2 ability, 3 source, 4 rules, 5 measured, 6 stop, 7 attacker, 8 flash, 9 kick,
## 10 own camera, 11 note. 4-10 are rebuilt; 0-3 and 11 are written by hand.
const BUILT := [4, 5, 6, 7, 8, 9, 10]


## feel: hero -> slot -> the dummy's peaks (impact_weight_check.feel); ok: the check's assert.
static func check(feel: Dictionary, ok: Callable) -> void:
	var doc := _doc_rows()
	var n := 0
	for hero in Arch.ORDER:
		for slot in SLOTS:
			var got := row(hero, slot, feel.get(hero, {}).get(slot, {}))
			var key := "%s %s" % [hero, SLOTS[slot]]
			print("TIERROW %s | %s" % [key, " | ".join(got)])
			var have: Array = doc.get(key, [])
			if have.size() < 12:
				ok.call(false, "tier table: %s has a row in %s" % [key, DOC])
				continue
			n += 1
			var diff := []
			for i in BUILT:
				if String(have[i]) != String(got[i - 4]):
					diff.append("col %d '%s' (measured '%s')" % [i + 1, have[i], got[i - 4]])
			ok.call(diff.is_empty(), "tier table %s: the doc matches the measured row %s" % [key, diff])
			var src := String(have[3]).get_slice(" ", 0)
			ok.call(SOURCES.has(src), "tier table %s: source '%s' is one of %s" % [key, src, SOURCES])
			if src == "heavy":
				var w := _lightest(hero, slot, feel.get(hero, {}).get(slot, {}))
				ok.call(w == "heavy", "tier table %s: a sourced heavy lands heavy (lightest hit '%s')" % [key, w])
	ok.call(n == Arch.ORDER.size() * SLOTS.size(), "tier table: %d of %d rows" % [n, Arch.ORDER.size() * SLOTS.size()])


## The rebuilt cells 4-10 of one row: rules tier, tiers seen on the dummy, stop, attacker hold, flash, kick, own cam.
static func row(hero: String, slot: String, pk: Dictionary) -> Array:
	var rules := ImpactWeight.of_ability(hero, slot)
	var tiers := _seen(pk)
	var landed := not pk.is_empty() and not (pk["tags"] as Array).is_empty()
	var measured := "+".join(tiers)
	if not landed:
		measured = "no hit on the dummy"
	elif tiers.is_empty():
		measured = "T0, no stop"
	var stops := tiers
	if not landed:
		stops = [rules] if rules != "" else []
	var stop := " / ".join(stops.map(func(w): return _ms_frames(ImpactWeight.hold_s(w))))
	if not landed and stop != "":
		stop = "rules " + stop
	var held := float(pk.get("freeze", 0.0))
	var attacker := _ms_frames(held) if held > 0.0 else "-"
	var heaviest := String(stops[-1]) if stops else ""
	var power := ImpactWeight.shake(heaviest)
	var kick := "0" if power <= 0.0 else "%.1f (%.3f m at 30%%)" % [power, power * AMP_PER_POWER * DEFAULT_SLIDER]
	return [
		rules if rules != "" else "-",
		measured,
		stop if stop != "" else "0",
		attacker if landed else "n/a",
		_flash(float(pk.get("flash", 0.0))) if landed else "n/a",
		kick,
		"%.3f" % float(pk.get("shake", 0.0)) if landed else "n/a",
	]


static func _seen(pk: Dictionary) -> Array:
	var got: Dictionary = pk.get("tiers", {})
	return ImpactWeight.TIERS.filter(func(w): return got.has(w))


## The slot's lightest weighted hit on the dummy, or its rules tier when the dummy took none.
static func _lightest(hero: String, slot: String, pk: Dictionary) -> String:
	var tiers := _seen(pk)
	if not pk.is_empty() and not (pk["tags"] as Array).is_empty():
		return String(tiers[0]) if tiers else ""
	return ImpactWeight.of_ability(hero, slot)


static func _ms_frames(s: float) -> String:
	return "%d ms (%.1f f)" % [roundi(s * 1000.0), s * FPS]


## A flash peak is read after a step, up to one step under what was set: the set value it came from.
static func _flash(peak: float) -> String:
	if peak <= 0.0:
		return "0"
	for s in [ImpactWeight.flash_s("light"), ComboMark.FLASH_BODY]:
		if peak <= s + 0.0001:
			return "%d ms" % roundi(s * 1000.0)
	return "%d ms" % roundi(peak * 1000.0)


## The doc's table rows: "<hero> <slot label>" -> its trimmed cells (the hero id is in the first cell's brackets).
static func _doc_rows() -> Dictionary:
	var out := {}
	var rx := RegEx.create_from_string("\\((\\w+)\\)")
	for line in FileAccess.get_file_as_string(DOC).split("\n"):
		if not line.begins_with("| "):
			continue
		var cells := Array(line.trim_prefix("|").trim_suffix("|").split("|")).map(func(c): return c.strip_edges())
		var id := rx.search(String(cells[0]))
		if id != null and cells.size() >= 12:
			out["%s %s" % [id.get_string(1), cells[1]]] = cells
	return out
