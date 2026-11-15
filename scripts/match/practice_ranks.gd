class_name PracticeRanks
extends RefCounted
## The Practice page of the Training Grounds' Esc menu: set your own ability ranks to test them.
## Max all (every ability at its top rank), Pick your max (one ability at its top rank, which unlocks
## its data bonus as the level-up rule does; the rest at rank 1) and Reset (everything at rank 1, as
## the Training Grounds open). Only the player changes: bots keep spending by their kit's order.

const HUD_SLOT := {"sec": "sec", "dash": "dash", "kin": "k1", "ult": "r"}      # Hunter.SLOTS -> slot_info names
const WIDE := 388.0      # px, button width (the Esc menu's)

static func max_all(h: Hunter) -> void:
	for s in Hunter.SLOTS:
		h.slot_lv[s] = int(Hunter.SLOT_MAX[s])
	h.skill_pts = 0

static func pick_max(h: Hunter, slot: String) -> void:
	reset(h)
	h.slot_lv[slot] = int(Hunter.SLOT_MAX[slot])

static func reset(h: Hunter) -> void:
	for s in Hunter.SLOTS:
		h.slot_lv[s] = 1
	h.skill_pts = 0

## Fills the page body: Max all, one Pick your max button per ability with its rank, Reset. `again` redraws it.
static func fill(body: VBoxContainer, h: Hunter, again: Callable) -> void:
	UI.subtitle(body, "Set your ranks to try them")
	body.add_child(UI.button("Max all", _then.bind(max_all.bind(h), again), WIDE, "next"))
	body.add_child(UI.label("Pick your max:", 14, UI.MUTED))
	for s in Hunter.SLOTS:
		var txt := "Max %s (rank %d / %d)" % [_name(h, s), int(h.slot_lv[s]), int(Hunter.SLOT_MAX[s])]
		var b := UI.button(txt, _then.bind(pick_max.bind(h, s), again), WIDE, "check")
		var ranks := Arch.next_ranks(h.arch, s, 1)
		if not ranks.is_empty():
			b.tooltip_text = String(ranks[-1][1])      # what the top rank unlocks (the kit's data bonus)
		body.add_child(b)
	body.add_child(UI.button("Reset to rank 1", _then.bind(reset.bind(h), again), WIDE, "back"))

static func _then(change: Callable, again: Callable) -> void:
	change.call()
	again.call()

static func _name(h: Hunter, slot: String) -> String:
	return String(h.slot_info(String(HUD_SLOT[slot]))["name"])
