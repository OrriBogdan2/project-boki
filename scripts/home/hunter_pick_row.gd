class_name HunterPickRow
extends RefCounted
## The expedition panel's "Hunter" pick (moved out of home.gd): one button per Hunter, the open ones
## live and the locked ones greyed with their goal on hover, and the picked one's health and dashes
## under it. No weight labels (docs/decisions/0005). Picking saves it as your expedition Hunter (its
## weight and weapon family follow) and turns the farm hunter into it.

const CHIP_FACE := 24         # px: the Warden's face on each Hunter's chip

## Adds the section to `parent` and returns the Hunter you are taking.
static func add(home: Node, parent: Control) -> String:
	var cur := Arch.of_save()
	var hd := UI.hbox(8)
	hd.add_child(UI.section("Relic"))
	hd.add_child(UI.fill())
	hd.add_child(UI.ghost("All Relics", func(): HomeClasses.open(home, cur), 0))
	parent.add_child(hd)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for a in Arch.ids():
		var id: String = a
		var role := ClassUnlock.start_role(id)
		var label := Arch.name_of(id) + ("\nStart here" if role != "" else "")
		var b := UI.choice(label, id == cur, func(): _pick(home, id), 104)
		b.disabled = not ClassUnlock.is_open(id)
		var locked := "Locked: %s\n" % ClassUnlock.requirement(id) if b.disabled else ""
		var tip := "Start here: %s\n" % role if role != "" else ""
		b.tooltip_text = tip + locked + ClassCard.kit_tip(id)
		b.set_meta("arch", id)
		Portraits.set_icon(b, id, CHIP_FACE)
		flow.add_child(b)
	parent.add_child(flow)
	var sl := UI.label(HunterViewer.stat_line(cur), UI.T_SMALL, Arch.color(cur))
	sl.autowrap_mode = TextServer.AUTOWRAP_OFF
	parent.add_child(sl)
	var cur_role := ClassUnlock.start_role(cur)
	if cur_role != "":
		parent.add_child(UI.label("Start here: " + cur_role, UI.T_SMALL, UI.GOLD))
	return cur

static func _pick(home: Node, id: String) -> void:
	if not HeroGrid.save_pick(id):
		return
	home._refresh_player_model()
	home._open_expedition()
