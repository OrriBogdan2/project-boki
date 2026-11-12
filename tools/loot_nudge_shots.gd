extends RefCounted
## --loot-nudge-shots --shots-dir=<dir>: <dir>/card.png, a Boki's card journal before and after it eats a
## Thumpnut carried home from an expedition (the feed row's preview, then the journal line it leaves).
## Needs a renderer.

const SIZE := Vector2i(1100, 520)

func run(main: Node) -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	Save.no_write = true
	Save.d = Save.fresh()
	Save.add_item("thumpnut", 1)
	var rec := Save.new_kin("cindle", "Ember")
	rec["level"] = 3
	rec["stats"]["power"] = 4
	CareJournal.note(rec, "won the Dash")
	main.get_window().size = SIZE
	main.get_viewport().size = SIZE
	var layer := CanvasLayer.new()
	layer.layer = 100
	main.add_child(layer)
	var back := ColorRect.new()
	back.color = Color("2a2540")
	back.size = Vector2(SIZE)
	layer.add_child(back)
	var row := UI.hbox(24)
	row.position = Vector2(30, 30)
	layer.add_child(row)
	var preview := String(GardenItems.preview(rec, "thumpnut")["text"])
	row.add_child(_card(rec, "Before: Thumpnut ×1 in the bag", "Feed: " + preview))
	GardenItems.use(rec, "thumpnut")
	row.add_child(_card(rec, "After: eaten at home", "Thumpnut ×0 in the bag"))
	for i in 6:
		await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(out.path_join("card.png"))
	print("LOOT_NUDGE_SHOTS_DONE")
	main.get_tree().quit()

func _card(rec: Dictionary, head: String, line: String) -> PanelContainer:
	var c := UI.card()
	var v := UI.vbox(6)
	v.custom_minimum_size = Vector2(480, 0)
	c.add_child(v)
	v.add_child(UI.label("%s  ·  Power %d" % [rec["name"], int(rec["stats"]["power"])], 22, UI.INK))
	v.add_child(UI.section(head))
	v.add_child(UI.para(line, 13, UI.MUTED))
	JournalCard.add(rec, v)
	return c
