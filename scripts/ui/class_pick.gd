class_name ClassPick
extends RefCounted
## The Mask pick (docs/decisions/0005): the first Mask of a new save, before the egg pick (the starters, Vex),
## or with `second` the second Mask after the first expedition (second_picks: Kael, Pip, Cinder; offer() puts it
## over the farm). Name chips over the Hunter viewer (HunterViewer); a chip click picks it and swaps the model
## in the same viewer (set_hunter), so nothing rebuilds or resets. `picked` is the chosen ids, changed in
## place; the button calls `done(picked)`.

const STAGE := Vector2(300, 300)
const CHIP_FACE := 40         # px: the Hunter's face on each Mask's chip
const HINT := "Put on the Mask you wear first: you become mostly its Hunter, with a little of you showing through."
const HINT_SECOND := "Choose your second Mask. The other two open through their own challenges."

static func row(picked: Array, done: Callable, second := false) -> Control:
	var ids: Array = ClassUnlock.second_picks() if second else ClassUnlock.starters()
	var back := UI.card(Color(0.06, 0.04, 0.11, 0.94), 14, 12)
	back.set_meta("starter_pick", true)
	var v := UI.vbox(6)
	back.add_child(v)
	var head := UI.title("Choose your second Mask" if second else "Choose your first Mask", 26, UI.ACCENT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var hint := UI.para(HINT_SECOND if second else HINT, UI.T_SMALL, UI.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var chips := HFlowContainer.new()
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	v.add_child(chips)
	var viewer := HunterViewer.make(String(ids[0]), STAGE, true)
	back.set_meta("viewer", viewer)
	v.add_child(viewer)
	var go := UI.primary("", func(): done.call(picked), 300)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.set_meta("go", go)
	var refresh := func():
		for c in chips.get_children():
			(c as Button).theme_type_variation = "Chosen" if picked.has(String(c.get_meta("arch"))) else ""
		go.disabled = picked.size() != ClassUnlock.picks_needed()
		go.text = "Pick a Mask" if go.disabled else "Take %s" % Arch.name_of(String(picked[0]))
	for a in ids:
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

## The second Mask on offer over the farm (after the first expedition), once nothing else covers it: the pick,
## then the new Mask's reveal. Returns whether it is waiting.
static func offer(home: Node) -> bool:
	if not ClassUnlock.second_pending():
		return false
	if home.panel_open != "" or home.building_now or not Save.d["tutorial"].get("home", false):
		home.get_tree().create_timer(1.0).timeout.connect(func():
			if is_instance_valid(home) and home.is_inside_tree(): offer(home))
		return true
	var layer := CanvasLayer.new()
	layer.layer = 60
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.06, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var picked: Array = []
	var on_pick := func(ids: Array):
		if not ClassUnlock.choose_second(String(ids[0])):
			return
		Save.save_game()
		layer.queue_free()
		ClassReveal.maybe_show(home)
	layer.set_meta("second_pick", true)
	center.add_child(row(picked, on_pick, true))
	home.add_child(layer)
	return true
