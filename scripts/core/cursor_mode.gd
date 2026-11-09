class_name CursorMode
extends RefCounted
## The one place the OS cursor's mode is set. In a live fight (a match or the Training Area, unpaused)
## the game's own reticle is the cursor, so the OS one is hidden and, with Settings "cursor_confine",
## kept inside the window so a click never lands on the desktop. Every menu, the pause menu, the farm
## and the lobby show the normal cursor.

## The mode last asked for (headless runs have no real cursor to read back).
static var current := Input.MOUSE_MODE_VISIBLE

## Back to a live fight: the reticle is the cursor.
static func aim() -> void:
	_apply(Input.MOUSE_MODE_CONFINED_HIDDEN if bool(Settings.get_v("cursor_confine")) else Input.MOUSE_MODE_HIDDEN)

## Any menu or screen with buttons to click.
static func menu() -> void:
	_apply(Input.MOUSE_MODE_VISIBLE)

static func _apply(mode: Input.MouseMode) -> void:
	current = mode
	Input.mouse_mode = mode
