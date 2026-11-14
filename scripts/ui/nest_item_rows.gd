class_name NestItemRows
extends RefCounted
## The Nesting Nook's nest items for the picked pair: Heirloom Threads to place, and who wears the Likeness
## Locket and the Lullaby Shell. Nothing shows if none are in the bag. The exact effect of each placed item
## is NestItems.preview_lines, listed under these rows.

## Adds the rows to dv; reopen() rebuilds the Nook panel after a change.
static func add(dv: VBoxContainer, a: Dictionary, b: Dictionary, reopen: Callable) -> void:
	if NestItems.held("gifts") + NestItems.held("species") + NestItems.held("habit") <= 0:
		return
	dv.add_child(UI.section("Nest gifts", UI.FAINT.lightened(0.2)))
	if NestItems.held("gifts") > 0:
		var title := "%s  ×%d" % [NestItems.item_of("gifts")["name"], NestItems.held("gifts")]
		var r := _row(title, "%d placed" % NestItems.threads())
		for by in [-1, 1]:
			r.add_child(UI.button("+" if by > 0 else "-", func():
				NestItems.add_threads(by)
				reopen.call(), 40))
		dv.add_child(r)
	for kind in ["species", "habit"]:
		if NestItems.held(kind) > 0:
			dv.add_child(_wear_row(kind, a, b, reopen))
	for line in NestItems.preview_lines(a, b):
		dv.add_child(UI.para(line, 12, UI.GOOD))

static func _wear_row(kind: String, a: Dictionary, b: Dictionary, reopen: Callable) -> HBoxContainer:
	var on: Dictionary = NestItems.wearer(kind, a, b)
	var title := "%s  ×%d" % [NestItems.item_of(kind)["name"], NestItems.held(kind)]
	var r := _row(title, "worn by %s" % String(on.get("name", "no one")))
	for p in [a, b]:
		r.add_child(UI.button(String(p["name"]), _wear.bind(kind, String(p["uid"]), reopen), 70))
	r.add_child(UI.ghost("None", _wear.bind(kind, "", reopen), 60))
	return r

static func _wear(kind: String, uid: String, reopen: Callable) -> void:
	NestItems.wear(kind, uid)
	reopen.call()

static func _row(title: String, state: String) -> HBoxContainer:
	var row := UI.hbox(6)
	var info := UI.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.label(title, 14))
	info.add_child(UI.label(state, 12, UI.MUTED))
	row.add_child(info)
	return row
