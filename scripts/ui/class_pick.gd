class_name ClassPick
extends RefCounted
## The starting pick at character creation (docs/decisions/0005): you pick 1 Hunter. A row of every
## starter (content/rules/class_unlock.json "starters") as name chips, and the Hunter viewer
## (HunterViewer) for the highlighted one: its model playing each ability in turn, its keys and the
## plain-words card. `on` is the highlighted one; a click on a chip calls `cb(id)`. The line on top
## says the next two come early. The panel is dark so it reads over the bright set behind it.

const STAGE := Vector2(300, 300)
const HINT := "Pick 1 Hunter to start. Your next two unlocks come early, any Hunter you like; " \
		+ "try them all in the Arena."

static func row(on: String, cb: Callable) -> Control:
	var back := UI.card(Color(0.06, 0.04, 0.11, 0.94), 14, 12)
	back.set_meta("starter_pick", true)
	var v := UI.vbox(6)
	back.add_child(v)
	var head := UI.title("Choose your Hunter", 26, UI.ACCENT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var hint := UI.para(HINT, UI.T_SMALL, UI.MUTED)
	hint.custom_minimum_size.x = 780
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var chips := HFlowContainer.new()
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	for a in ClassUnlock.starters():
		var id: String = a
		var b := UI.choice(Arch.name_of(id), id == on, func(): cb.call(id), 116)
		b.add_theme_color_override("font_color", Arch.color(id))
		b.set_meta("arch", id)
		b.set_meta("starter_chip", id)
		chips.add_child(b)
	v.add_child(chips)
	var viewer := HunterViewer.make(on, STAGE)
	back.set_meta("viewer", viewer)
	v.add_child(viewer)
	return back
