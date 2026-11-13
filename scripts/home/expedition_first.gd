class_name ExpeditionFirst
extends RefCounted
## The expedition panel on the first visits (docs/UI_FIRST15.md shot 30): your Relic, the one open Where
## choice and Start. Locked Relics, the Boki and loadout rows, Match, Conditions and the mode links are
## folded behind "More" until the player has finished a real expedition (the tutorial course doesn't
## count); returning players get the full panel.

static var _folded: Array[Control] = []
static var _on := false
static var _opened_more := false     # "More" pressed this session: the panel is re-opened after a pick, keep it open

## Call when the panel starts building. True on the first visits.
static func begin() -> bool:
	_folded.clear()
	var tutorial_match := 1 if Save.d.get("tutorial", {}).get("match", false) else 0     # the course counts as a match
	var played := int(Save.d.get("matches", 0)) - tutorial_match
	_on = played <= 0 and not _opened_more
	return _on

## Marks `c` as part of "More" (hidden on the first visits) and returns it.
static func fold(c: Control) -> Control:
	if _on:
		c.visible = false
		_folded.append(c)
	return c

## A box in `parent` for things that belong behind "More".
static func group(parent: Control) -> VBoxContainer:
	var box := UI.vbox(10)
	parent.add_child(fold(box))
	return box

## The "More" button: shows everything folded, then goes away.
static func more_button(parent: Control) -> void:
	if not _on:
		return
	var b := UI.ghost("More", Callable())
	b.pressed.connect(func():
		_opened_more = true
		for c in _folded:
			c.visible = true
		b.queue_free())
	parent.add_child(b)

## Visible blocks in the panel: the section headings plus the Start button.
static func visible_blocks(root: Node) -> int:
	var n := 1
	for l in root.find_children("*", "Label", true, false):
		if l.has_meta("pg_head") and (l as Label).is_visible_in_tree():
			n += 1
	return n
