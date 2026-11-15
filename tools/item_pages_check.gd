extends RefCounted
## --item-pages-check: the Field Book's pages for shaping items (ItemPages, GardenItems.owned/uses).
## Unowned items are a silhouette with no text and no page; owning one reveals its tile and page;
## applying it logs which Boki took it and what changed; a family gets a star once all its items have
## been owned; the page opens from the inventory's Field Book tab. Never touches the real save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("ITEMPAGES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var host := VBoxContainer.new()
	main.add_child(host)
	var open_log: Array = []
	_hidden(host, open_log)
	_revealed(host, open_log)
	_taken()
	_stars(host)
	_in_inventory()
	host.queue_free()
	print("ITEMPAGES DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _texts(n: Node) -> Array:
	var out: Array = []
	for l in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out

func _tiles(host: Node) -> Array:
	for ch in host.get_children():
		host.remove_child(ch)
		ch.free()
	ItemPages.grid(host as VBoxContainer, func(_id): pass)
	return host.find_children("*", "GridContainer", true, false)[0].get_children()

func _hidden(host: Node, _log: Array) -> void:
	var tiles := _tiles(host)
	var silent := true
	for t in tiles:
		silent = silent and _texts(t).is_empty() and (t as Control).tooltip_text == ""
	ok(tiles.size() == GardenItems.ids().size() and silent, "unowned: a silhouette tile each, no text or tooltip")

func _revealed(host: Node, _log: Array) -> void:
	Save.add_item("thumpnut", 1)
	var tiles := _tiles(host)
	ok(_texts(tiles[0]) == ["Thumpnut"], "owning Thumpnut reveals its name on its tile")
	ok(_texts(tiles[1]).is_empty(), "the next item stays a silhouette")
	var page := VBoxContainer.new()
	host.add_child(page)
	ItemPages.detail(page, "thumpnut")
	var words := " ".join(_texts(page))
	var shown := ["Thumpnut", "Power", "Stump Shove prize", "Not used yet"].all(func(w): return words.contains(w))
	ok(shown, "its page shows name, what it nudges, where it comes from and that nobody took it yet")
	page.free()

func _taken() -> void:
	var rec := Save.new_kin("cindle", "Pip")
	var pv := GardenItems.preview(rec, "thumpnut")
	GardenItems.apply(rec, "thumpnut")
	var u: Array = GardenItems.uses("thumpnut")
	var logged: bool = u.size() == 1 and u[0]["boki"] == "Pip" and u[0]["text"] == pv["text"]
	ok(logged, "applying it logs the Boki and the exact change")
	var page := VBoxContainer.new()
	ItemPages.detail(page, "thumpnut")
	ok(" ".join(_texts(page)).contains("Pip: " + String(pv["text"])), "the page lists who took it and what changed")
	page.free()
	Save.d["items"]["thumpnut"] = 0
	ok(GardenItems.owned("thumpnut"), "an item used up still has its page")
	for i in 9:
		GardenItems.apply(rec, "thumpnut")
	var keep := int(GardenItems.rules()["log_keep"])
	ok(GardenItems.uses("thumpnut").size() == keep, "the log keeps only the newest few")

func _stars(host: Node) -> void:
	var fam := "stat"
	var ids: Array = GardenItems.family_ids(fam)
	for id in ids.slice(0, ids.size() - 1):
		Save.add_item(id, 1)
	ok(not GardenItems.family_done(fam), "one item short: no star")
	var page := VBoxContainer.new()
	host.add_child(page)
	ItemPages.detail(page, "thumpnut")
	ok(not _texts(page).has("★"), "page without the star")
	page.free()
	Save.add_item(ids.back(), 1)
	var only_stat: bool = GardenItems.family_done(fam) and not GardenItems.family_done("path")
	ok(only_stat, "the last item completes only its own family")
	page = VBoxContainer.new()
	host.add_child(page)
	ItemPages.detail(page, "thumpnut")
	ok(_texts(page).has("★"), "completed family: the page has the star")
	page.free()

func _in_inventory() -> void:
	Overlay.inv_tab = "Field Book"
	Overlay.open_inventory()
	var tile_names := " ".join(_texts(Overlay.root))
	var listed := tile_names.to_lower().contains("shaping items") and tile_names.contains("Thumpnut")
	ok(listed, "the Field Book tab lists the shaping items")
	Overlay.open_dex("thumpnut")
	ok(" ".join(_texts(Overlay.root)).contains("Nudges"), "an item's page opens as a Field Book sub-page")
	Overlay.close()
