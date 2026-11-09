class_name PracticeRanks
extends RefCounted
## The Practice page of the practice areas' Esc menu: set your ability ranks for testing. Max all
## (every slot at its top rank, the ult open), Pick your max (one slot at its top rank, which unlocks
## its data bonus as the level-up rule does; the rest at rank 1) and Reset (everything at rank 1, as
## a practice area opens).

const SLOT_KEYS := {"sec": "sec", "dash": "dash", "kin": "k1", "ult": "r"}      # Hunter.SLOTS -> slot_info names

static func max_all(h: Hunter) -> void:
	for s in Hunter.SLOTS:
		h.slot_lv[s] = int(Hunter.SLOT_MAX[s])
	h.skill_pts = 0

static func pick_max(h: Hunter, slot: String) -> void:
	h.unlock_all()
	for s in Hunter.SLOTS:
		h.slot_lv[s] = int(Hunter.SLOT_MAX[s]) if s == slot else 1

static func reset(h: Hunter) -> void:
	for s in Hunter.SLOTS:
		h.slot_lv[s] = 1
	h.skill_pts = 0

static func _then(change: Callable, again: Callable) -> void:
	change.call()
	again.call()

## Fills the page body: the current ranks, then the three controls. `again` rebuilds the page.
static func fill(body: VBoxContainer, h: Hunter, again: Callable) -> void:
	UI.subtitle(body, "Practice ranks for %s" % Arch.name_of(h.arch))
	for s in Hunter.SLOTS:
		var info := h.slot_info(String(SLOT_KEYS[s]))
		body.add_child(UI.label("%s: rank %d / %d" % [info["name"], int(h.slot_lv[s]), int(Hunter.SLOT_MAX[s])], 15))
	body.add_child(UI.spacer(6))
	body.add_child(UI.button("Max all", func(): _then(max_all.bind(h), again), 388.0, "next"))
	body.add_child(UI.label("Pick your max (the rest stay at rank 1):", 14, UI.MUTED))
	for s in Hunter.SLOTS:
		var info := h.slot_info(String(SLOT_KEYS[s]))
		body.add_child(UI.button("Max %s" % info["name"], func(): _then(pick_max.bind(h, s), again), 388.0, "check"))
	body.add_child(UI.button("Reset to rank 1", func(): _then(reset.bind(h), again), 388.0, "back"))
