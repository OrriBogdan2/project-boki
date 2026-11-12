extends RefCounted
## --dex-sort-check: the Field Book and the Boki Burrow share one type filter and sort (KinFilter):
## the widget has an All chip and one chip per type, picking a type lists only that type (unmet
## entries hide), every sort (number, level, trust, newest) orders what is listed, and the legendaries
## stay last under every sort and filter, in the Field Book and in the Burrow. Never touches the real save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("DEXSORT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _legend_last(list: Array) -> bool:
	var seen_legend := false
	for spk in list:
		if Data.is_rare(String(spk)):
			seen_legend = true
		elif seen_legend:
			return false
	return true

func _kin(spk: String, lvl: int, trust: float, got: float) -> Dictionary:
	var r := Save.new_kin(spk, spk)
	r["level"] = lvl
	r["trust"] = trust
	r["got_t"] = got
	return r

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var plain: Array = FieldBook.entries().filter(func(s): return not Data.is_rare(s))
	var rare: Array = FieldBook.entries().filter(Data.is_rare)
	ok(plain.size() >= 4 and not rare.is_empty(), "plain and legendary entries (%d, %d)" % [plain.size(), rare.size()])
	ok(_legend_last(FieldBook.entries()) and FieldBook.number(rare[0]) > plain.size(), "legendaries close the numbers")
	for spk in Data.KIN:
		Care.dex_mark(spk, "seen")
	# ---------------------------------------------------------------- the widget
	var picks := [0]
	var bar := KinFilter.new(func(): picks[0] += 1)
	var chips := bar.get_children().filter(func(c): return c is Button and not c is OptionButton)
	var icons := bar.find_children("*", "Control", true, false).filter(func(c): return c is DexView.TypeIcon)
	ok(chips.size() == DexView.TYPES.size() + 1, "an All chip and one chip per type (%d types)" % DexView.TYPES.size())
	ok(icons.size() == DexView.TYPES.size(), "each type chip carries its own icon")
	KinFilter.type = ""
	chips[1].pressed.emit()
	ok(KinFilter.type == DexView.TYPES.keys()[0] and picks[0] == 1, "a type chip picks its type and tells the owner")
	chips[0].pressed.emit()
	ok(KinFilter.type == "" and picks[0] == 2, "All clears the pick")
	bar.free()
	# ---------------------------------------------------------------- the Field Book
	var all_n: int = FieldBook.entries().size()
	for t in DexView.TYPES:
		KinFilter.type = t
		var want: Array = FieldBook.entries().filter(func(s): return DexView.type_of(FieldBook.face(s)) == t)
		var got: Array = DexView.listed()
		ok(got == want and _legend_last(got), "Field Book, %s only: %d entries, legendaries last" % [t, want.size()])
	KinFilter.type = DexView.type_of(plain[0])
	Save.d["dex"].erase(plain[0])
	ok(not DexView.listed().has(plain[0]), "an entry you have not met hides under a type pick")
	KinFilter.type = ""
	ok(DexView.listed().has(plain[0]) and DexView.listed().size() == all_n, "All lists every entry")
	# who you own: three plain Boki and a legendary that beats them at everything
	var a := _kin(plain[0], 9, 10.0, 100.0)
	var b := _kin(plain[1], 5, 90.0, 200.0)
	var c := _kin(plain[2], 7, 40.0, 300.0)
	var leg := _kin(rare[0], 30, 100.0, 400.0)
	Save.d["roster"] = [a, b, c, leg]
	var expect := {"number": [plain[0], plain[1], plain[2]], "level": [plain[0], plain[2], plain[1]],
		"trust": [plain[1], plain[2], plain[0]], "newest": [plain[2], plain[1], plain[0]]}
	for key in expect:
		KinFilter.sort = key
		var got: Array = DexView.listed()
		ok(got.size() == all_n and _legend_last(got), "Field Book by %s: every entry, legendaries last" % key)
		ok(got.slice(0, 3) == expect[key], "Field Book by %s: the owned Boki lead in that order" % key)
	# ---------------------------------------------------------------- the Burrow
	for key in KinBox.SORTS:
		var list := KinBox.sorted(Save.d["roster"], String(key[0]))
		ok(Data.is_rare(String(list[3]["species"])), "Burrow by %s: the legendary is last" % key[0])
	var lv := KinBox.sorted(Save.d["roster"], "level").map(func(r): return r["species"])
	var nw := KinBox.sorted(Save.d["roster"], "newest").map(func(r): return r["species"])
	ok(lv.slice(0, 3) == expect["level"], "Burrow by level: highest first")
	ok(nw.slice(0, 3) == expect["newest"], "Burrow by newest: the latest joined first")
	KinFilter.type = DexView.type_of(plain[1])
	var shown: Array = (Save.d["roster"] as Array).filter(func(r): return KinFilter.type_ok(String(r["species"])))
	ok(shown.has(b) and shown.all(func(r): return DexView.type_of(r["species"]) == KinFilter.type), "Burrow type pick")
	KinFilter.type = ""
	KinFilter.sort = "number"
	m.get_tree().quit(1 if bad > 0 else 0)
