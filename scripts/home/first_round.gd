class_name FirstRound
extends RefCounted
## The garden games' first visit (briefs/design/GARDEN.md section 5): the first press at a game's spot
## offers one skippable practice round instead of starting. Each game owns one FirstRound and asks it in
## use(); the answer, Esc and the flag live here. The flag sits in Save.d.tutorial[flag] (set when
## offered, taken or skipped, so it never comes back); a save that already holds a memory of the game
## counts as offered, so old saves load without a prompt they have outgrown.

const RESULT := "Joy and trust move with the result, and backing the winner pays gems"   # the practice card's last row

var h                                # the Home screen
var flag: String                     # Save.d.tutorial key
var kind: String                     # the memory kind the game writes ("" = no earlier saves to spare)
var title: String
var line: String                     # the one line that explains the input
var yes: String
var offer: Control = null
var on_yes: Callable

func _init(home, key: String, memory_kind: String, head: String, how: String, label := "Practice") -> void:
	h = home
	flag = key
	kind = memory_kind
	title = head
	line = how
	yes = label

## True when the press was taken: the offer is open (or was just opened); false when the game starts as usual.
func ask(on_practice: Callable) -> bool:
	if is_instance_valid(offer):
		return true
	var seen: Dictionary = Save.d["tutorial"]
	if seen.get(flag, false):
		return false
	seen[flag] = true
	if _played():
		return false
	on_yes = on_practice
	_open()
	return true

func _played() -> bool:
	if kind == "":
		return false
	for rec in Save.d.get("roster", []):
		if rec.get("memory", []).any(func(e): return String(e.get("kind", "")) == kind):
			return true
	return false

func _open() -> void:
	var c := UI.card(Color(0.06, 0.07, 0.1, 0.92), 14, 14)
	c.set_anchors_preset(Control.PRESET_CENTER_TOP)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.offset_top = 90
	var v := UI.vbox(8)
	c.add_child(v)
	v.add_child(UI.label(title, 18, UI.ACCENT_HI))
	v.add_child(UI.label(line, 14))
	var row := UI.hbox(10)
	row.add_child(UI.primary(yes, func(): answer(true)))
	row.add_child(UI.ghost("Skip", func(): answer(false)))
	v.add_child(row)
	h.root_ui.add_child(c)
	offer = c

func answer(practice: bool) -> void:
	offer.queue_free()
	offer = null
	if practice:
		on_yes.call()

## Esc while the offer is open skips it: true when it took the key.
func skip(event: InputEvent) -> bool:
	if not is_instance_valid(offer) or not event.is_action_pressed("menu"):
		return false
	answer(false)
	return true

## The practice card's extra row, in BaseRace.result_card's shape (none outside a practice round).
static func row(guide: bool, text := RESULT) -> Array:
	return [[text, 14, UI.MUTED]] if guide else []
