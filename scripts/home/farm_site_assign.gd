class_name FarmSiteAssign
extends RefCounted
## The site panel (docs/decisions/0004-farm-building.md): what a construction site still needs and an
## Assign list of Boki with their building skill. A Boki picked here goes to that site and builds only
## there until it stands or you send it somewhere else (FarmSites.assign).

const LIST_MAX := 6      # Boki shown in the Assign list, best builders first

static func open(h, e: Dictionary) -> void:
	var u := int(e["u"])
	var nm := String(HomeLayout.CATALOG[String(e["id"])]["name"])
	var v: VBoxContainer = h._new_panel("%s site" % nm, 560)
	var need := FarmSites.need_text(e)
	var sub := "%d of %d swings" % [int(e["site"]["got"]), int(e["site"]["need"])]
	UI.subtitle(v, sub if need == "" else sub + "  ·  " + need)
	var crew := FarmSites.crew(u)
	var slots := int(FarmSites.rules()["crew_slots"])
	var rule := "An assigned Boki builds only here and keeps a place for itself until the %s stands or you move it."
	v.add_child(UI.para(rule % nm.to_lower(), UI.T_SMALL, UI.MUTED))
	v.add_child(UI.section("Assigned  %d / %d" % [crew.size(), slots]))
	if crew.is_empty():
		v.add_child(UI.label("Nobody yet: any free Boki may still lend a hand.", UI.T_BODY, UI.MUTED))
	for r in crew:
		var rr: Dictionary = r
		var row := _row(rr, "")
		row.add_child(UI.button("Unassign", func(): _send(h, rr, -1, e), 120))
		v.add_child(row)
	if crew.size() < slots:
		var cands := _free(crew)
		v.add_child(UI.section("Assign a Boki"))
		if cands.is_empty():
			v.add_child(UI.label("No other Boki of yours can work right now.", UI.T_BODY, UI.MUTED))
		for r in cands.slice(0, LIST_MAX):
			var rr: Dictionary = r
			var row := _row(rr, _where(h, rr))
			row.add_child(UI.primary("Assign", func(): _send(h, rr, u, e), 120))
			v.add_child(row)
	UI.footer_primary(v, "Done", func(): h._close_panel(), 100)

## Boki that can work and are not already here, free ones first, then by building skill.
static func _free(crew: Array) -> Array:
	var out: Array = []
	for r in Save.d["roster"]:
		if not crew.has(r) and Work.can_work(r): out.append(r)
	out.sort_custom(func(a, b):
		if _posted(a) != _posted(b):
			return _posted(b)
		return _skill(a) > _skill(b))
	return out

static func _posted(rec: Dictionary) -> bool:
	return Work.assigned(rec) >= 0 or FarmSites.site_of(rec) >= 0

static func _skill(rec: Dictionary) -> int:
	return FarmSites.level(rec, {"el": "craft", "kind": "build"})

## What a Boki that is not free is doing now ("" for a free one).
static func _where(h, rec: Dictionary) -> String:
	var site := FarmSites.entry(FarmSites.site_of(rec))
	if not site.is_empty():
		return "  (at the %s site)" % String(HomeLayout.CATALOG[String(site["id"])]["name"]).to_lower()
	for st in HomeLayout.stations(h._d()):
		if int(st["e"]["u"]) == Work.assigned(rec):
			return "  (at the %s)" % String(HomeLayout.CATALOG[st["id"]]["name"]).to_lower()
	return ""

static func _row(rec: Dictionary, note: String) -> HBoxContainer:
	var row := UI.hbox(10)
	var col: Color = Data.KIN.get(String(rec["species"]), {}).get("color", UI.INK)
	var l := UI.label("%s  ·  Building %d%s" % [rec["name"], _skill(rec), note], UI.T_BODY, col)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row

## Sends a Boki to the site (u) or frees it (-1): it drops what it was doing and picks again.
static func _send(h, rec: Dictionary, u: int, e: Dictionary) -> void:
	FarmSites.assign(rec, u)
	h.hw.reassign(rec)
	Save.save_game()
	open(h, e)
