class_name ClassPick
extends RefCounted
## The Hunter pick of a new save (docs/decisions/0005), before the egg pick: 1 of the starters
## (content/rules/class_unlock.json "starters") as name chips over the Hunter viewer (HunterViewer). A chip
## click picks it and swaps the model in the same viewer (set_hunter), so nothing rebuilds or resets.
## `picked` is the chosen ids, changed in place; the button calls `done(picked)`.

const STAGE := Vector2(300, 300)
const CHIP_FACE := 40         # px: the Warden's face on each starter's chip
const HINT := "Pick the mask you wear first: you become mostly its Warden, with a little of you showing through. " \
		+ "The other two open after your first expedition."

static func row(picked: Array, done: Callable) -> Control:
	var back := UI.card(Color(0.06, 0.04, 0.11, 0.94), 14, 12)
	back.set_meta("starter_pick", true)
	var v := UI.vbox(6)
	back.add_child(v)
	var head := UI.title("Choose your first mask", 26, UI.ACCENT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var hint := UI.para(HINT, UI.T_SMALL, UI.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var chips := HFlowContainer.new()
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	v.add_child(chips)
	var viewer := HunterViewer.make(String(ClassUnlock.starters()[0]), STAGE, true)
	back.set_meta("viewer", viewer)
	v.add_child(viewer)
	var go := UI.primary("", func(): done.call(picked), 300)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.set_meta("go", go)
	var refresh := func():
		for c in chips.get_children():
			(c as Button).theme_type_variation = "Chosen" if picked.has(String(c.get_meta("arch"))) else ""
		go.disabled = picked.size() != ClassUnlock.picks_needed()
		go.text = "Pick one of the three" if go.disabled else "Take %s" % Arch.name_of(String(picked[0]))
	for a in ClassUnlock.starters():
		var id: String = a
		var b := UI.choice(Arch.name_of(id), false, func():
			toggle(picked, id)
			refresh.call()
			viewer.set_hunter(id), 132)
		b.add_theme_color_override("font_color", Arch.color(id))
		Portraits.set_icon(b, id, CHIP_FACE)
		b.set_meta("arch", id)
		b.set_meta("starter_chip", id)
		chips.add_child(b)
	v.add_child(go)
	refresh.call()
	return back

## A click on a chip: in or out of the pick. With the pick full, the oldest choice makes room.
static func toggle(picked: Array, id: String) -> void:
	if picked.has(id):
		picked.erase(id)
		return
	picked.append(id)
	while picked.size() > ClassUnlock.picks_needed():
		picked.pop_front()
