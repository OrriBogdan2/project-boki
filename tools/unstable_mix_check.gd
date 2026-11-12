extends RefCounted
## --unstable-mix-check: the Nook's unstable mix (UnstableMix, content/rules/unstable_mix.json). 20 clashing
## couples (element or temper) and 20 calm ones are bred headlessly: the clashing babies hatch low on joy
## with the "needs extra care" tag, the calm ones are untouched, and the tag clears after a day of care.
## Never a loss: nothing dies or goes missing. Never touches the real save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("MIX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _kin(sp: String, temper: float, bravery := 0.5) -> Dictionary:
	var k := Save.new_kin(sp, sp)
	k["traits"]["temper"] = temper
	k["traits"]["bravery"] = bravery
	return k

## One species of each theme, so a couple can be picked by element.
func _by_theme() -> Dictionary:
	var out := {}
	for sp in Data.KIN:
		var t := String(Data.KIN[sp].get("theme", ""))
		if not out.has(t): out[t] = sp
	return out

func _preview_text(a: Dictionary, b: Dictionary) -> String:
	var dv := VBoxContainer.new()
	NookRules.preview(dv, a, b)
	var all := ""
	for l in dv.get_children(): all += (l as Label).text + "\n"
	dv.free()
	return all

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var rules := Content.rules("unstable_mix")
	var types: Dictionary = rules["types"]
	ok(types.size() == 18, "the element table lists the 18 types (%d)" % types.size())
	var table_ok := true
	for c in rules["clashes"]:
		if not types.has(c[0]) or not types.has(c[1]) or c[0] == c[1]: table_ok = false
	ok(table_ok, "every clash names two different types from the table")
	var themes := _by_theme()
	var known := true
	for t in themes: known = known and (types.has(t) or t == "none")
	ok(known, "every species' type is in the table")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var clash_pairs: Array = []
	for c in rules["clashes"]:
		if themes.has(c[0]) and themes.has(c[1]): clash_pairs.append(c)
	ok(clash_pairs.size() >= 4, "%d clashes have species in the game today" % clash_pairs.size())
	# ---- 20 clashing couples: element clashes (even calm tempers) and temper clashes (same species)
	var low := 0
	var tagged := 0
	var told := 0
	var alive := 0
	for i in 20:
		var a: Dictionary
		var b: Dictionary
		if i % 2 == 0:
			var c: Array = clash_pairs[(i / 2) % clash_pairs.size()]
			a = _kin(themes[c[i % 4 / 2]], 0.5)
			b = _kin(themes[c[1 - i % 4 / 2]], 0.5)
		else:
			var sp: String = themes.values()[i % themes.size()]
			var hot: bool = i % 4 == 1          # hot-headed against mellow, otherwise bold against timid
			a = _kin(sp, 0.9, 0.5) if hot else _kin(sp, 0.5, 0.1)
			b = _kin(sp, 0.2, 0.5) if hot else _kin(sp, 0.5, 0.9)
		var baby := Care.breed(a, b, rng)
		if float(baby["needs"]["joy"]) == float(rules["hatch_joy"]): low += 1
		if float(baby.get("extra_care", 0.0)) == float(rules["care_s"]): tagged += 1
		var shown := _preview_text(a, b).contains("Unstable mix: ") and Care.condition_name(baby) == "Needs extra care"
		if shown: told += 1
		if not baby.has("starve") and float(baby["needs"]["food"]) > 0.0 and not baby.get("dead", false): alive += 1
	ok(low == 20, "20 of 20 clashing babies hatch low on joy (%d)" % low)
	ok(tagged == 20, "20 of 20 clashing babies carry the extra-care tag (%d)" % tagged)
	ok(told == 20, "20 of 20 clashing pairs get the Nook line and the card tag (%d)" % told)
	ok(alive == 20, "no clashing baby starts hungry, sick or lost (%d)" % alive)
	# ---- 20 calm couples: no clashing element, tempers close
	var calm := 0
	var untouched := 0
	var quiet := 0
	var names: Array = themes.keys()
	for i in 20:
		var t1: String = names[i % names.size()]
		var t2: String = names[(i * 3 + 1) % names.size()] if i % 2 == 0 else t1
		var a := _kin(themes[t1], 0.4 + 0.01 * i)
		var b := _kin(themes[t2], 0.5 - 0.01 * i * 0.5)
		if UnstableMix.unstable(a, b): continue     # the table says these two clash: not a calm couple
		calm += 1
		var baby := Care.breed(a, b, rng)
		if float(baby["needs"]["joy"]) != float(rules["hatch_joy"]) and not baby.has("extra_care"): untouched += 1
		if not _preview_text(a, b).contains("Unstable"): quiet += 1
	ok(calm == 20, "20 calm couples were found (%d)" % calm)
	ok(untouched == calm, "calm babies hatch with normal joy and no tag (%d of %d)" % [untouched, calm])
	ok(quiet == calm, "calm pairs get no unstable note (%d of %d)" % [quiet, calm])
	# ---- the day of care
	var kid := Care.breed(_kin(themes["ember"], 0.5), _kin(themes["frost"], 0.5), rng)
	for n in Care.NEEDS: kid["needs"][n] = 90.0
	UnstableMix.tick(kid, float(rules["care_s"]) - 60.0)
	ok(kid.has("extra_care"), "just under a day of care: still tagged")
	UnstableMix.tick(kid, 120.0)
	var cleared: bool = not kid.has("extra_care") and Care.condition_name(kid) != "Needs extra care"
	ok(cleared, "after a day of care the tag is gone")
	var worn := Care.breed(_kin(themes["ember"], 0.5), _kin(themes["frost"], 0.5), rng)
	for n in Care.NEEDS: worn["needs"][n] = 10.0
	UnstableMix.tick(worn, 3.0 * float(rules["care_s"]))
	ok(worn.has("extra_care"), "days of neglect do not count as care")
	var live := Care.breed(_kin(themes["ember"], 0.5), _kin(themes["frost"], 0.5), rng)
	var owed := float(live["extra_care"])
	Care.tick(live, 60.0)
	ok(float(live["extra_care"]) < owed, "Care.tick at home pays the day down")
	print("MIX done, %d failed" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
