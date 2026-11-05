class_name TipsLog
extends RefCounted
## The Tips log (pause menu): every first-time expedition tip this save has seen, newest first, in
## the words and keys you play with now (MatchTips.text). A tip shows once out on an expedition; this
## is where to read it again.

## Fills an overlay page with the log.
static func fill(v: VBoxContainer) -> void:
	var ids: Array = MatchTips.seen().filter(func(id): return MatchTips.lines().has(id))
	if ids.is_empty():
		var none := "No tips yet. A tip shows the first time something new happens on an expedition, then waits here."
		v.add_child(UI.para(none, UI.T_BODY))
		return
	UI.subtitle(v, "Shown once on an expedition, kept here")
	ids.reverse()
	for id in ids:
		var c := UI.card(UI.CARD, 12)
		var line := UI.para(MatchTips.text(String(id)), UI.T_BODY, UI.INK)
		c.add_child(line)
		v.add_child(c)
