class_name UiSfx
## The one place the game's menu and event cues are named, so a sound changes in one spot.
## Files are made by tools/gen_sfx_ui.py (see docs/AUDIO.md); every cue is a 2D UI sound.

const HOVER_DB := -12.0      # dB: the tick under the cursor stays well under a click
const FOCUS_DB := -14.0      # dB: keyboard and pad moves are a touch quieter than the mouse
const TICK_FROM := 10        # s: the lobby countdown ticks once a second from here
const URGENT_FROM := 5       # s: the last few ticks are higher and doubled
const MATE_DB := -9.0        # dB: a teammate's lock-in sits well under your own
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

static func extract_success() -> void:
	Sfx.play("extract_ok", null, -3.0)

## Lobby: your Hunter chosen (not yet locked).
static func lobby_pick() -> void:
	Sfx.play("lobby_pick", null, -4.0, 0.02)

## Lobby: a pick is final. Yours is that Hunter's own sting; a teammate's is one quiet note.
static func lobby_lock(arch: String, mine: bool) -> void:
	if mine:
		var sting := "%s_lock" % arch
		Sfx.play(sting if Sfx.ensure(sting) else "lobby_pick", null, -3.0, 0.02)
	else:
		Sfx.play("lobby_mate", null, MATE_DB, 0.02)

## Lobby: one second of the countdown (sec left, TICK_FROM or less); the last URGENT_FROM are sharper.
static func lobby_tick(sec: int) -> void:
	Sfx.play("lobby_tick_urgent" if sec <= URGENT_FROM else "lobby_tick", null, -4.0, 0.02)
