class_name UiSfx
extends RefCounted
## The one place the game's menu and event cues are named, so a sound changes in one spot.
## Files are made by tools/gen_sfx_ui.py (see docs/AUDIO.md); every cue is a 2D UI sound.
## Sounds for the controls Ui.button does not cover (sliders, toggles, dropdowns) are hooked once on the tree
## (Game): any HSlider, CheckButton or OptionButton added anywhere gets them for free.

const HOVER_DB := -12.0      # dB: the tick under the cursor stays well under a click
const FOCUS_DB := -14.0      # dB: keyboard and pad moves are a touch quieter than the mouse
const TICK_FROM := 10        # s: the lobby countdown ticks once a second from here
const URGENT_FROM := 5       # s: the last few ticks are higher and doubled
const MATE_DB := -9.0        # dB: a teammate's lock-in sits well under your own
const SLIDER_GAP_MS := 55      # a drag over many steps ticks at most this often
const META := "ui_sfx"         # marks a control already wired
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

static func hook(tree: SceneTree) -> void:
	tree.node_added.connect(attach)

static func attach(n: Node) -> void:
	if n.has_meta(META): return
	if n is Slider:
		n.set_meta(META, true)
		n.value_changed.connect(func(_v): _tick(n))
	elif n is CheckButton or n is CheckBox:
		n.set_meta(META, true)
		n.toggled.connect(func(on): Sfx.play("click", null, -6.0, 0.03, 1.15 if on else 0.85))
	elif n is OptionButton:
		n.set_meta(META, true)
		n.item_selected.connect(func(_i): Sfx.play("ui_tab"))

static func _tick(s: Slider) -> void:
	if not s.is_inside_tree(): return
	var now := Time.get_ticks_msec()
	if now - int(s.get_meta("tick_at", -1000)) < SLIDER_GAP_MS: return
	s.set_meta("tick_at", now)
	var span := maxf(s.max_value - s.min_value, 0.0001)
	var pitch := 0.9 + 0.3 * (s.value - s.min_value) / span
	Sfx.play("hover", null, -8.0, 0.0, pitch)
