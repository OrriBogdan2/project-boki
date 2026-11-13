class_name PanelInput
extends RefCounted
## Which panels own the keyboard and mouse in a match, so a press made while one is open never fires,
## dashes, jumps or casts underneath it (checked by --panel-input-check). A panel closing needs no
## handling here: these are read from the panels' own open state, so the first press after it closes
## reaches the Hunter on the same frame.

## The map, the backpack or the swap window is open (the Esc menu is `Match.paused`).
static func panel_up(hud: Node) -> bool:
	return hud != null and (hud.map_open() or hud.pack_open() or hud.swap_open())

## A fresh press of `action` this frame that the match may act on.
static func pressed(m: Match, action: String) -> bool:
	return Input.is_action_just_pressed(action) and not m.paused and not panel_up(m.hud)
