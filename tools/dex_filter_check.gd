extends RefCounted
## --dex-filter-check: the Field Book filters on a fixture save. Each filter (type, status, thrives in)
## returns the right species, a two-type species matches either of its types, legendaries stay last in
## every filtered view, the "n of N" count is right, and the save is untouched.

const _ALL := ["a1", "a2", "a3", "a4", "a5", "l_min", "l_boss", "l_ult"]

var bad := 0

func ok(what: String, cond: bool) -> void:
	printerr("DEXFILTER %-58s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	var kin_backup: Dictionary = Data.KIN.duplicate()
	var save_backup: Dictionary = Save.d.duplicate(true)
	var zones_backup = Content._cache.get("rules/garden_zones")
	Data.KIN.clear()
	# a legendary sits among the normals in Data.KIN on purpose: the view must still put it last
	for spec in [
			["a1", "spore", "", ""], ["l_ult", "spore", "", "ultra"],
			["a2", "titan", "", ""], ["a3", "spore", "titan", ""],
			["a4", "venom", "", ""], ["l_min", "titan", "", "minor"],
			["a5", "swarm", "", ""], ["l_boss", "venom", "", "boss"]]:
		Data.KIN[spec[0]] = {"name": spec[0], "type": spec[1], "type2": spec[2]}
		if spec[3] != "":
			Data.KIN[spec[0]]["legendary_tier"] = spec[3]
	Content._cache["rules/garden_zones"] = {"zones": {
		"z1": {"name": "One", "types": ["spore"]},
		"z2": {"name": "Two", "types": ["venom", "swarm"]}}}
	Save.d["dex"] = {
		"a1": {"seen": true}, "a2": {"caught": true}, "a3": {"caught": true},
		"l_ult": {"seen": true}, "l_boss": {"caught": true}}
	Save.d["roster"] = [{"species": "a2"}, {"species": "l_min", "boxed": true}]
	var before := Save.d.hash()
	DexFilter.reset()
	ok("no filter: all, legendaries last", DexFilter.species() == _ALL)
	DexFilter.types = ["spore"]
	ok("type spore: its own and the two-type one", DexFilter.species() == ["a1", "a3", "l_ult"])
	DexFilter.types = ["titan"]
	ok("type titan: the second type counts too", DexFilter.species() == ["a2", "a3", "l_min"])
	DexFilter.types = ["spore", "venom"]
	ok("two types: either matches, legends by tier", DexFilter.species() == ["a1", "a3", "a4", "l_boss", "l_ult"])
	DexFilter.reset()
	DexFilter.status = "seen"
	ok("seen: seen or caught", DexFilter.species() == ["a1", "a2", "a3", "l_boss", "l_ult"])
	DexFilter.status = "caught"
	ok("caught", DexFilter.species() == ["a2", "a3", "l_boss"])
	DexFilter.status = "owned"
	ok("owned now: the roster, the Burrow included", DexFilter.species() == ["a2", "l_min"])
	DexFilter.reset()
	DexFilter.zone = "z1"
	ok("thrives in z1: species of its types", DexFilter.species() == ["a1", "a3", "l_ult"])
	DexFilter.zone = "z2"
	ok("thrives in z2", DexFilter.species() == ["a4", "a5", "l_boss"])
	DexFilter.types = ["titan"]
	DexFilter.zone = ""
	DexFilter.status = "caught"
	ok("filters combine (titan and caught)", DexFilter.species() == ["a2", "a3"])
	DexFilter.status = "owned"
	DexFilter.types = ["spore"]
	ok("a filter nobody passes is empty", DexFilter.species().is_empty())
	DexFilter.reset()
	var browser := DexFilter.Browser.new(main_node.get_tree(), func(_s): pass)
	ok("the count reads 'n of N' for everything", _has_text(browser, "8 of 8"))
	DexFilter.types = ["venom"]
	browser.refresh()
	await main_node.get_tree().process_frame
	ok("the count follows the filter ('2 of 8')", _has_text(browser, "2 of 8"))
	DexFilter.reset()
	ok("filters never touch the save", Save.d.hash() == before)
	browser.free()
	Data.KIN.clear()
	Data.KIN.merge(kin_backup)
	Save.d = save_backup
	if zones_backup == null:
		Content._cache.erase("rules/garden_zones")
	else:
		Content._cache["rules/garden_zones"] = zones_backup
	print("DEXFILTER %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main_node.get_tree().quit(1 if bad > 0 else 0)

func _has_text(n: Node, txt: String) -> bool:
	if n is Label and (n as Label).text == txt:
		return true
	for ch in n.get_children():
		if not ch.is_queued_for_deletion() and _has_text(ch, txt):
			return true
	return false
