class_name ExpFold
extends RefCounted
## The first visit to the expedition panel and the Relics page (docs/UI_FIRST15.md 5.5): while only the first
## Where is open, show the picked Relic, that Where and Start, and fold the rest behind one button
## (every Relic, every drop, the match settings and the mode links stay one click away).

## True while the first drop is the only one open; the folds are shown folded then.
static func first_visit() -> bool:
	return int(Save.d.get("extracts", 0)) < int(Data.TIERS[1]["unlock"])

## Hides `items` and adds a button (in `parent`) that shows or hides them. Returns the button.
static func add(parent: Control, items: Array, text: String) -> Button:
	var label := "%s (%d)" % [text, items.size()] if items.size() > 1 else text
	var b := UI.ghost(label, Callable())
	var open := [false]
	b.pressed.connect(func() -> void:
		open[0] = not open[0]
		for it in items:
			if is_instance_valid(it): (it as Control).visible = open[0]      # (a swapped tile is gone)
		b.text = ("Fewer: " + text) if open[0] else label)
	for it in items:
		(it as Control).visible = false
	parent.add_child(b)
	return b
