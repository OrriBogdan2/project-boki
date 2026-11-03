class_name ClassPick
extends RefCounted
## The Hunter pick in the new-game flow (docs/decisions/0005): the first Hunter is already yours and you
## pick 1 of the starters (content/rules/class_unlock.json "starters"). A row of the starters as name
## chips, each toggling it in or out of your pick, and the Hunter viewer (HunterViewer) for the one you
## last clicked: its model playing each ability in turn, its keys and the plain-words card. `on` is the
## one in the viewer, `picked` the chosen one; a click on a chip calls `cb(id)`. The panel is dark so it
## reads over the bright set behind it.

const STAGE := Vector2(300, 300)
const CHIP_FACE := 40         # px: the Warden's face on each starter's chip
const HINT := "%s is yours already. Pick one more to start with. The other two open with an easy challenge, " \
		+ "and the rest of the Hunters with their own."

static func row(on: String, picked: Array, cb: Callable) -> Control:
	var back := UI.card(Color(0.06, 0.04, 0.11, 0.94), 14, 12)
	back.set_meta("starter_pick", true)
	var v := UI.vbox(6)
	back.add_child(v)
	var head := UI.title("Choose your second Hunter", 26, UI.ACCENT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var hint := UI.para(HINT % Arch.name_of(ClassUnlock.first_hunter()), UI.T_SMALL, UI.MUTED)
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
		Portraits.set_icon(b, id, CHIP_FACE)
		b.set_meta("arch", id)
		b.set_meta("starter_chip", id)
		chips.add_child(b)
	v.add_child(chips)
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
