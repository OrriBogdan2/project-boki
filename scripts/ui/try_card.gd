class_name TryCard
extends RefCounted
## The small "What to try today" card on the title screen. Its text is content/rules/try_today.json.
## Dismissing it remembers the card's id in Settings, so it comes back only when the id changes.

const RULES_PATH := "res://content/rules/try_today.json"

static func rules() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	return parsed if parsed is Dictionary else {}

## True when there is a card to show that this player has not dismissed.
static func due() -> bool:
	var r := rules()
	var seen := String(Settings.v.get("try_dismissed", ""))
	return not (r.get("lines", []) as Array).is_empty() and seen != String(r.get("id", ""))

## Builds the card (the caller places it) or returns null when none is due.
static func build() -> Control:
	if not due():
		return null
	var r := rules()
	var card := UI.glass(10, UI.R_CARD)
	card.name = "TryCard"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.custom_minimum_size = Vector2(300, 0)
	var v := UI.vbox(6)
	card.add_child(v)
	v.add_child(UI.label(String(r.get("title", "")), UI.T_HEAD, UI.INK, UI.big))
	for line in r["lines"]:
		v.add_child(UI.para(String(line), UI.T_SMALL))
	var gone := UI.ghost("Got it", func(): dismiss(card))
	gone.focus_mode = Control.FOCUS_NONE
	v.add_child(gone)
	return card

static func dismiss(card: Control) -> void:
	Settings.set_v("try_dismissed", String(rules().get("id", "")))
	card.queue_free()
