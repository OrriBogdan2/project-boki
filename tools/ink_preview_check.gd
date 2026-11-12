extends RefCounted
## --ink-preview-check: an Ink's card in the Feed menu says what it will do to this Boki before it is used
## (Evo.ink_preview, GardenItemRows.add_inks; content/rules/evolve.json, DECISIONS 2026-11-08). Three cases:
## a line with that Ink branch and art shows the form's picture and name and can be used (it evolves, the
## Ink is spent, the change is queued for the home to play); a line without that branch says "no effect";
## a branch whose form has no model yet says it waits for its art. Neither of those two can be used.
## Never touches the real save.

const BASE := "cindle"

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("INKPREVIEW %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var lines: Dictionary = Evo.rules()["lines"]
	var art := ""                 # a species with a model, the stand-in form for the "form" case
	for id in Data.KIN:
		if Evo.has_art(String(id)) and not lines.has(String(id)):
			art = String(id)
			break
	ok(art != "", "a species with art to stand in as an Ink form (%s)" % art)
	var real: Array = lines["ermink"]["into"]
	ok(real.any(func(o): return o.get("item", "") == "ink_ember" and not Evo.has_art(String(o["id"]))),
			"evolve.json: Ermink's Ember Ink form has no model yet (the art gate case is real data)")
	var plain := Evo.ink_preview(_boki("cindle"), "ink_ember")
	ok(plain["state"] == "none", "none: Ember Ink on Cindle (its real line has no Ink branch) does nothing")
	var keep: Variant = lines.get(BASE)          # BASE's line for this run only: Tide Ink takes it to `art`
	lines[BASE] = {"into": [{"id": art, "item": "ink_tide"}]}
	_preview(art)
	_card(main, art)
	if keep == null:
		lines.erase(BASE)
	else:
		lines[BASE] = keep
	print("INKPREVIEW DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _boki(species: String) -> Dictionary:
	var rec := Save.new_kin("cindle", "T-" + species)      # Ermink has no kin data yet: only its line is read
	rec["species"] = species
	return rec

func _preview(art: String) -> void:
	var nm := String(Data.KIN[art]["name"])
	var form := Evo.ink_preview(_boki(BASE), "ink_tide")
	ok(form["state"] == "form" and form["to"] == art and form["name"] == nm and String(form["text"]).contains(nm),
			"form: Tide Ink on its line names %s (%s)" % [nm, form["text"]])
	var none := Evo.ink_preview(_boki(BASE), "ink_frost")
	ok(none["state"] == "none" and String(none["text"]).to_lower().contains("no effect on this boki"),
			"none: Frost Ink on a line without that branch says no effect (%s)" % none["text"])
	var waits := Evo.ink_preview(_boki("ermink"), "ink_ember")
	ok(waits["state"] == "waits" and waits["to"] == "flarmink" and String(waits["text"]).contains("waits for its art")
			and String(waits["text"]).contains(String(waits["name"])),
			"waits: Ember Ink on Ermink names Flarmink and waits for its art (%s)" % waits["text"])

func _rows(host: VBoxContainer) -> Dictionary:
	var out := {}
	for row in host.get_children():
		var labels: Array = row.find_children("*", "Label", true, false)
		var title := (labels[0] as Label).text
		out[title.get_slice("  ", 0)] = {"row": row, "desc": (labels[1] as Label).text,
				"btn": row.find_children("*", "Button", true, false)[0], "pic": row.get_child(0)}
	return out

func _card(main: Node, art: String) -> void:
	for ink in ["ink_tide", "ink_frost"]:
		Goods.give("good:" + ink)
	var host := VBoxContainer.new()
	main.add_child(host)
	var rec := _boki(BASE)
	var played: Array = []
	var any := GardenItemRows.add_inks(host, rec, [func(): played.append("close"), func(): played.append("play")])
	var rows := _rows(host)
	ok(any and rows.size() == 2, "the card lists the two Inks held, no others (%d rows)" % rows.size())
	var tide: Dictionary = rows.get("Tide Ink", {})
	var frost: Dictionary = rows.get("Frost Ink", {})
	ok(not tide.is_empty() and String(tide["desc"]).contains(String(Data.KIN[art]["name"])),
			"Tide Ink row names the form (%s)" % tide.get("desc", ""))
	ok(not tide.is_empty() and (tide["pic"] is TextureRect or tide["pic"] is KinPortrait.Disc),
			"Tide Ink row shows the form's portrait")
	ok(not tide.is_empty() and not (tide["btn"] as Button).disabled, "Tide Ink can be used")
	ok(not frost.is_empty() and String(frost["desc"]).to_lower().contains("no effect"),
			"Frost Ink row says no effect (%s)" % frost.get("desc", ""))
	ok(not frost.is_empty() and (frost["btn"] as Button).disabled, "Frost Ink can't be used on it")
	if not tide.is_empty():
		(tide["btn"] as Button).pressed.emit()
	var pend: Array = rec.get("pending_evo", [])
	ok(rec["species"] == art and pend.size() == 1 and pend[0]["item"] == "ink_tide",
			"using Tide Ink evolves it to %s and queues the change" % art)
	ok(Goods.have("good:ink_tide") == 0 and Goods.have("good:ink_frost") == 1, "the Tide Ink is spent, Frost kept")
	ok(played == ["close", "play"], "the home closes the menu, then plays the change (%s)" % [played])
	for ch in host.get_children():
		host.remove_child(ch)
		ch.free()
	var wait_rec := _boki("ermink")
	Goods.give("good:ink_ember")
	GardenItemRows.add_inks(host, wait_rec, [])
	var ember: Dictionary = _rows(host).get("Ember Ink", {})
	var waits := not ember.is_empty() and String(ember["desc"]).contains("waits for its art")
	ok(waits and (ember["btn"] as Button).disabled,
			"Ember Ink on Ermink: waits for its art, can't be used (%s)" % ember.get("desc", ""))
	host.queue_free()
