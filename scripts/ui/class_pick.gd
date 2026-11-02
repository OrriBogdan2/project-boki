class_name ClassPick
extends RefCounted
## The starter pick on a new save: three classes (content/rules/class_unlock.json "starters"), one of
## each weight, shown as cards. `on` is the highlighted one; clicking a card calls `cb(id)`. The rest
## of the classes open through play, which the line above the cards says. The cards sit on a dark
## panel so they read over the bright set behind them.

static func row(on: String, cb: Callable) -> Control:
	var back := UI.card(Color(0.06, 0.04, 0.11, 0.93), 14, 14)
	back.set_meta("starter_pick", true)
	var v := UI.vbox(10); back.add_child(v)
	var hint := UI.para("Pick the class you start with. The others open as you play: a goal for each, and an account level that grows with every expedition. You can try any class in the Arena at any time.", UI.T_SMALL, UI.MUTED)
	hint.custom_minimum_size.x = 800
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var cards := UI.hbox(12); cards.alignment = BoxContainer.ALIGNMENT_CENTER
	for a in ClassUnlock.starters():
		var id: String = a
		cards.add_child(ClassCard.make(id, id == on, func(): cb.call(id), "Picked" if id == on else "", true))
	v.add_child(cards)
	return back
