class_name UiSfx
## The one place the game's menu and event cues are named, so a sound changes in one spot.
## Files are made by tools/gen_sfx_ui.py (see docs/AUDIO.md); every cue is a 2D UI sound.

const HOVER_DB := -12.0      # dB: the tick under the cursor stays well under a click
const FOCUS_DB := -14.0      # dB: keyboard and pad moves are a touch quieter than the mouse
const BACK_WORDS := {"Back": true, "Close": true, "Cancel": true, "✕": true, "Leave it  (Esc)": true}

static func hover(keyboard := false) -> void:
	Sfx.play("hover", null, FOCUS_DB if keyboard else HOVER_DB, 0.05)

## Something was refused (a full box, no room, a failed trade).
static func error(vol_db := -8.0) -> void:
	Sfx.play("ui_deny", null, vol_db)

## A button press: snd names its cue (the main button confirms, a tab ticks); a "go back" label falls.
static func press(label: String, snd := "") -> void:
	if snd == "":
		snd = "ui_back" if BACK_WORDS.has(label) else "click"
	Sfx.play(snd)

static func captured() -> void:
	Sfx.play("ui_capture", null, -4.0, 0.02)

static func extract_start() -> void:
	Sfx.play("ui_extract_start", null, -4.0, 0.02)

static func extract_success() -> void:
	Sfx.play("extract_ok", null, -3.0)

static func extract_fail() -> void:
	Sfx.play("ui_extract_fail", null, -4.0, 0.02)
