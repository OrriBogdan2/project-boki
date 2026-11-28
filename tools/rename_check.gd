extends RefCounted
## --rename-check: renaming a Boki you own from its kin card's About tab (KinNames.rename, AboutView.name_row,
## NameStep with a start name). The Name row has a Rename button; it opens the naming line filled with the
## name it has, Keep renames it (the save, its event log, the row and the card's callback), and a blank,
## unchanged, rude or too long name is refused. A Boki that is not yours shows its name with no button.

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("RENAME %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var rec := Save.new_kin("cindle", "Pip")
	Save.d["roster"].append(rec)
	# the rule itself
	var rude := String(KinNames.rules()["rude"][0])
	var long := "B".repeat(int(KinNames.rules()["max_len"]) + 1)
	var tries := {
		"blank": "", "spaces": "   ", "unchanged": "Pip", "unchanged, padded": "  Pip ", "rude": rude, "too long": long
	}
	for why in tries:
		ok(not KinNames.rename(rec, tries[why]) and rec["name"] == "Pip", "refused: %s" % why)
	var stranger := Save.new_kin("cindle", "Wisp")  # (not in the roster: a visitor or a parent long gone)
	ok(not KinNames.can_rename(stranger) and not KinNames.rename(stranger, "Mine"), "a Boki not yours keeps its name")
	ok(KinNames.rename(rec, "  Bramble ") and rec["name"] == "Bramble", "a kept name is set, trimmed: %s" % rec["name"])
	var evs := (Save.d["log"] as Array).filter(func(e): return e["ev"] == "renamed" and e["uid"] == rec["uid"])
	ok(evs.size() == 1 and evs[0]["from"] == "Pip" and evs[0]["name"] == "Bramble", "the event log has it: %s" % [evs])
	# the card: the Name row and its Rename button
	var box := VBoxContainer.new()
	main.add_child(box)
	var got := []
	AboutView.history(rec, box, func(nm): got.append(nm))
	var row: Control = box.get_child(0)
	var btn := _button(row)
	ok(_text(row).contains("Bramble") and btn != null, "the About tab's first row is its name, with Rename")
	btn.pressed.emit()
	await main.get_tree().process_frame
	var step := _step(box)
	ok(step != null and not row.visible, "Rename opens the naming line in place of the row")
	ok(step != null and step.box.text == "Bramble", "the line opens with the name it has, not a new suggestion")
	if step != null:
		step.box.text = "Thistle"
		step.keep()
	await main.get_tree().process_frame
	ok(rec["name"] == "Thistle" and Save.kin(rec["uid"])["name"] == "Thistle", "Keep renames it in the save")
	ok(row.visible and _text(row).contains("Thistle") and _step(box) == null, "the row is back with the new name")
	ok(got == ["Thistle"], "the card hears the new name (its title): %s" % [got])
	# Keep with the same name closes the line and changes nothing
	btn.pressed.emit()
	step = _step(box)
	var logs := _renames()
	if step != null:
		step.keep()
	await main.get_tree().process_frame
	ok(rec["name"] == "Thistle" and _renames() == logs and row.visible, "an unchanged name just closes")
	# leaving the card mid-rename keeps the old name
	btn.pressed.emit()
	step = _step(box)
	if step != null:
		step.box.text = "Nope"
	box.queue_free()
	await main.get_tree().process_frame
	ok(rec["name"] == "Thistle" and got.size() == 1, "closing the card mid-rename keeps the old name")
	# a Boki that is not yours: the name, no button
	var box2 := VBoxContainer.new()
	main.add_child(box2)
	AboutView.history(stranger, box2)
	ok(_text(box2.get_child(0)).contains("Wisp") and _button(box2.get_child(0)) == null, "not yours: no Rename")
	box2.queue_free()
	print("RENAME DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _renames() -> int:
	return (Save.d["log"] as Array).filter(func(e): return e["ev"] == "renamed").size()


func _button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button:
			return c
	return null


func _step(n: Node) -> NameStep:
	for c in n.get_children():
		if c is NameStep and not c.is_queued_for_deletion():
			return c
	return null


func _text(n: Node) -> String:
	var t := ""
	for c in n.get_children():
		if c is Label:
			t += (c as Label).text + " "
	return t
