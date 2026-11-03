class_name ClassPick
extends RefCounted
## The pick at character creation (docs/decisions/0005): you pick 2 of the 4 starting Hunters
## (content/rules/class_unlock.json "starters" and "starter_picks"). A row of the starters as name
## chips, each toggling it in or out of your pick, and the Hunter viewer (HunterViewer) for the one you
## last clicked: its model playing each ability in turn, its keys and the plain-words card. `on` is the
## one in the viewer, `picked` the chosen ones; a click on a chip calls `cb(id)`. The panel is dark so it
## reads over the bright set behind it.

const STAGE := Vector2(300, 300)
const HINT := "Pick %d Hunters to start with. Every other Hunter opens with its own challenge; " \
		+ "try them all in the Arena."

static func row(on: String, picked: Array, cb: Callable) -> Control:
	var back := UI.card(Color(0.06, 0.04, 0.11, 0.94), 14, 12)
	back.set_meta("starter_pick", true)
	var v := UI.vbox(6)
	back.add_child(v)
	var head := UI.title("Choose your Hunters", 26, UI.ACCENT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var hint := UI.para(HINT % ClassUnlock.picks_needed(), UI.T_SMALL, UI.MUTED)
	hint.custom_minimum_size.x = 780
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var chips := HFlowContainer.new()
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	for a in ClassUnlock.starters():
		var id: String = a
		var b := UI.choice(Arch.name_of(id), picked.has(id), func(): cb.call(id), 132)
		b.add_theme_color_override("font_color", Arch.color(id))
		b.set_meta("arch", id)
		b.set_meta("starter_chip", id)
		chips.add_child(b)
	v.add_child(chips)
	var full := picked.size() == ClassUnlock.picks_needed()
	var count := UI.label("%d / %d picked" % [picked.size(), ClassUnlock.picks_needed()], 13,
			UI.GOOD if full else UI.MUTED, UI.semi)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(count)
	var viewer := HunterViewer.make(on, STAGE)
	back.set_meta("viewer", viewer)
	v.add_child(viewer)
	return back

## A click on a chip: in or out of the pick. With the pick full, the oldest choice makes room.
static func toggle(picked: Array, id: String) -> Array:
	var out := picked.duplicate()
	if out.has(id):
		out.erase(id)
		return out
	out.append(id)
	while out.size() > ClassUnlock.picks_needed():
		out.pop_front()
	return out
