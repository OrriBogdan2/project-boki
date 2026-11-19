class_name ExpFold
extends RefCounted
## The folds of the expedition panel and the Relics page (docs/UI_FIRST15.md 5.5): the picked Relic, the open
## Where, the Boki and Start stay on show; every other Relic, the locked drops and "Details" (loadout, match
## settings, mode links) sit behind one button each. A fold you opened stays open while the panel rebuilds
## around a pick (a Boki arrow, a drop), and starts shut when the panel opens fresh (`reset`).

static var _opened := {}      # button text -> true while its fold is open

## True while the first drop is the only one open; the Relics page folds its locked tiles then.
static func first_visit() -> bool:
	return int(Save.d.get("extracts", 0)) < int(Data.TIERS[1]["unlock"])

## Shuts every fold (the panel opens fresh).
static func reset() -> void:
	_opened.clear()

## Shuts one fold (a pick inside it is made).
static func forget(text: String) -> void:
	_opened.erase(text)

## Hides `items` and adds a button (in `parent`) that shows or hides them ("Fewer: <text>" while open, or
## `open_text`). Returns the button.
static func add(parent: Control, items: Array, text: String, open_text := "") -> Button:
	var label := "%s (%d)" % [text, items.size()] if items.size() > 1 else text
	var b := UI.ghost(label, Callable())
	var open_label := open_text if open_text != "" else "Fewer: " + text
	var set_open := func(on: bool) -> void:
		for it in items:
			if is_instance_valid(it): (it as Control).visible = on      # (a swapped tile is gone)
		b.text = open_label if on else label
		_opened[text] = on
	b.pressed.connect(func() -> void: set_open.call(not _opened.get(text, false)))
	for it in items:
		(it as Control).visible = false
	if _opened.get(text, false): set_open.call(true)
	parent.add_child(b)
	return b
