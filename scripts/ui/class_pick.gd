class_name ClassPick
extends RefCounted
## The starter pick on a new save: three classes (content/rules/class_unlock.json "starters"), one of
## each weight, shown as cards. `on` is the highlighted one; clicking a card calls `cb(id)`. The rest
## of the classes open through play, which the line under the cards says.

static func row(on: String, cb: Callable) -> Control:
	var v := UI.vbox(8)
	v.set_meta("starter_pick", true)
	var hint := UI.para("Pick the class you start with. The others open as you play: goals, and an account level that grows with every expedition. You can try any class in the Arena at any time.", UI.T_SMALL, Color(1, 0.95, 0.88, 0.92))
	hint.custom_minimum_size.x = 820
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var cards := UI.hbox(12); cards.alignment = BoxContainer.ALIGNMENT_CENTER
	for a in ClassUnlock.starters():
		var id: String = a
		var c := ClassCard.make(id, id == on, func(): cb.call(id), "Picked" if id == on else "")
		cards.add_child(c)
	v.add_child(cards)
	return v
