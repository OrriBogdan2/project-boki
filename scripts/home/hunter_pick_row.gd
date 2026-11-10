class_name HunterPickRow
extends RefCounted
## The expedition panel's "Hunter" pick (moved out of home.gd): the shared HunterPicker cards (name and
## role word, stats and the unlock goal on hover). No weight labels (docs/decisions/0005). Picking saves it
## as your expedition Hunter (its weight and weapon family follow) and turns the farm hunter into it.

const COLUMNS := 3            # cards per row in the panel's left column
const CARD_W := 120.0         # px, a card's least width
const PORTRAIT_PX := 40.0     # px, the Warden's face on each card

## Adds the section to `parent` and returns the Hunter you are taking.
static func add(home: Node, parent: Control) -> String:
	var cur := Arch.of_save()
	var hd := UI.hbox(8)
	hd.add_child(UI.section("Relic"))
	hd.add_child(UI.fill())
	hd.add_child(UI.ghost("All Relics", func(): HomeClasses.open(home, cur), 0))
	parent.add_child(hd)
	parent.add_child(HunterPicker.grid(cur, func(id): _pick(home, id), COLUMNS, CARD_W, PORTRAIT_PX))
	return cur

static func _pick(home: Node, id: String) -> void:
	if not HeroGrid.save_pick(id):
		return
	home._refresh_player_model()
	home._open_expedition()
