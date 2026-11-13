extends RefCounted
## --dex-check: the Field Book order and counts (docs/decisions/0002). Every legendary sits at the very
## end, sorted by tier, with a tier badge on its card; the seen/caught counts (total and per type) match
## the save. No game species is a legendary yet, so three stand-ins are added to Data.KIN for the run.

var bad := 0

func ok(what: String, cond: bool) -> void:
	printerr("DEXCHECK %-58s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	var kin_backup: Dictionary = Data.KIN.duplicate()
	var dex_backup: Dictionary = Save.d.get("dex", {}).duplicate(true)
	var first: String = Data.KIN.keys()[0]
	for spec in [["zz_ultra", "ultra"], ["zz_minor", "minor"], ["zz_boss", "boss"]]:
		Data.KIN[spec[0]] = {"name": spec[0], "type": "spore", "legendary_tier": spec[1]}
	var order := FieldBook.entries()
	ok("every species is listed once", order.size() == Data.KIN.size())
	ok("legendaries are the last entries", order.slice(order.size() - 3) == ["zz_minor", "zz_boss", "zz_ultra"])
	var rank := ["zz_minor", "zz_boss", "zz_ultra"].map(func(s): return DexView.number(s))
	ok("legendaries are sorted by tier", rank[0] < rank[1] and rank[1] < rank[2])
	ok("a normal species keeps its place", DexView.number(first) == 1)
	Save.d["dex"] = {
		first: {"seen": true, "caught": true},
		"zz_boss": {"seen": true},
		"zz_ultra": {"seen": true, "caught": true},
	}
	var tree := main_node.get_tree()
	var legend_card := DexView.tile("zz_ultra", tree, func(_s): pass)
	var plain_card := DexView.tile(first, tree, func(_s): pass)
	ok("a legendary card shows its tier badge", _has_text(legend_card, "Ultra"))
	ok("a normal card has no tier badge", not _has_text(plain_card, "Ultra"))
	var c := DexView.counts()
	ok("total counts match the save (3 seen, 2 caught)", c == Vector2i(3, 2))
	var tc := DexView.type_counts()
	var by_type := Vector2i.ZERO
	for t in tc:
		by_type += tc[t]
	ok("per-type counts add up to the totals", by_type == c)
	ok("spore row counts the stand-ins", tc["spore"].x >= 2 and tc["spore"].y >= 1)
	Data.KIN.clear()
	Data.KIN.merge(kin_backup)
	Save.d["dex"] = dex_backup
	print("DEXCHECK %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main_node.get_tree().quit(1 if bad > 0 else 0)

func _has_text(n: Node, txt: String) -> bool:
	if n is Label and (n as Label).text == txt:
		return true
	for ch in n.get_children():
		if _has_text(ch, txt):
			return true
	return false
