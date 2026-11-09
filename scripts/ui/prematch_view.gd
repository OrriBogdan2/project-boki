extends Control
## The pre-match lobby screen (rules: Prematch): pick your Hunter, meet your squad, plan with text
## chat (and a voice hook), watch the countdown. At 0 the picks lock and the match loads.

const TIMER_SIZE := 88        # px, the countdown digits
const SAFE_FRAC := 0.04       # fraction of the window height kept clear on every side (title-safe)
const DIGITS_FRAC := 0.1       # countdown digit size as a fraction of the window height
const DIGITS_MIN := 48         # px, the smallest countdown digits
const PULSE_RATE := 0.012      # radians per ms of the last-seconds throb (about 2 beats a second)
const PULSE_GROW := 0.12       # the digits swell by this much at the top of a beat
const SAFE_MIN := 24          # px, the least margin at any window size

var pm: Prematch
var voice := VoiceChat.new()
var title_label: Label
var timer_label: Label
var note_label: Label
var banner: VBoxContainer
var _pad: MarginContainer
var _last_sec := -1
var grid: GridContainer
var squad_box: HBoxContainer
var chat_log: VBoxContainer
var chat_scroll: ScrollContainer
var chat_in: LineEdit
var chat_hint: Label
var talk_btn: Button

const COLUMNS := 4          # Hunter cards per row
const CARD_MIN_W := 200.0   # px, a card's least width (portrait, name, role word)
const LOG_H := 84.0         # px, the most the chat log grows to (it scrolls past that)

## A small padlock for a shut Hunter: a body and a shackle.
class Padlock extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(22, 26)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_arc(Vector2(11, 10), 6.0, PI, TAU, 12, UI.FAINT, 2.5)
		draw_rect(Rect2(3, 10, 16, 14), UI.FAINT)

func setup(opts: Dictionary) -> void:
	pm = Prematch.new(opts)

func _ready() -> void:
	Sfx.play_music("title")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_pad = MarginContainer.new()
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pad)
	get_viewport().size_changed.connect(_fit_safe_area)
	var root := UI.vbox(10)
	_pad.add_child(root)
	banner = UI.vbox(0)
	banner.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(banner)
	var caption := UI.label("PICKS LOCK IN", 20, UI.MUTED, UI.semi)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(caption)
	timer_label = UI.label("", TIMER_SIZE, UI.INK, UI.big)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(timer_label)
	note_label = UI.label("", 22, UI.GOOD, UI.semi)
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(note_label)
	var head := UI.hbox(20)
	root.add_child(head)
	title_label = UI.title("Before the drop: pick your Hunter", 34)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	var strip := UI.hbox(14)
	root.add_child(strip)
	strip.add_child(UI.section("Squad"))
	squad_box = UI.hbox(10)
	strip.add_child(squad_box)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	grid = GridContainer.new()
	grid.columns = COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	sc.add_child(grid)
	_build_chat(root)
	_talk(false)
	_fit_safe_area()
	_fill_hunters()
	_fill_squad()
	_tick_label()
	Net.message.connect(_on_msg)
	_announce_pick()

## The chat: one "Enter to chat" line; the log shows from the first message, the input while you type.
func _build_chat(root: Control) -> void:
	chat_scroll = ScrollContainer.new()
	chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chat_scroll.visible = false
	root.add_child(chat_scroll)
	chat_log = UI.vbox(4)
	chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_scroll.add_child(chat_log)
	var row := UI.hbox(8)
	root.add_child(row)
	chat_hint = UI.para("Enter to chat")
	chat_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(chat_hint)
	chat_in = LineEdit.new()
	chat_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_in.placeholder_text = "Plan with your squad..."
	chat_in.max_length = Prematch.CHAT_MAX
	chat_in.visible = false
	chat_in.text_submitted.connect(func(_t): _send_chat())
	chat_in.focus_exited.connect(_show_chat_line.bind(false))
	chat_in.gui_input.connect(func(e): if e.is_action_pressed("ui_cancel"): chat_in.release_focus())
	row.add_child(chat_in)
	talk_btn = UI.button("", Callable())
	talk_btn.button_down.connect(func(): _talk(true))
	talk_btn.button_up.connect(func(): _talk(false))
	row.add_child(talk_btn)

func _show_chat_line(typing: bool) -> void:
	chat_in.visible = typing
	chat_hint.visible = not typing
	if typing:
		chat_in.grab_focus()

func _exit_tree() -> void:
	if Net.message.is_connected(_on_msg):
		Net.message.disconnect(_on_msg)

func _process(delta: float) -> void:
	var was := pm.locked
	var go := pm.tick(delta)
	_tick_label()
	if pm.locked and not was:
		title_label.text = "Picks are locked. Loading in..."
		note_label.text = "Time's up: %s locked in" % HunterViewer.display_name(pm.pick)
		_fill_hunters()
		chat_in.release_focus()
	if go:
		set_process(false)
		Game.goto("match", pm.launch_opts())

func _tick_label() -> void:
	var s := int(ceil(pm.left))
	timer_label.text = "%d:%02d" % [s / 60, s % 60]
	if s != _last_sec:
		_last_sec = s
		if pm.left > 0.0 and pm.left <= Prematch.TICK_FROM:
			Sfx.play("click", null, 0.0, 0.0, 1.5 if pm.left <= Prematch.PULSE_FROM else 1.0)
	_pulse(pm.left)

## Digits warm to red below TICK_FROM and throb red below PULSE_FROM.
func _pulse(left: float) -> void:
	var beat := 0.0
	if left <= Prematch.PULSE_FROM:
		beat = 0.5 + 0.5 * sin(Time.get_ticks_msec() * PULSE_RATE)
	var red := 0.0
	if left <= Prematch.TICK_FROM:
		red = 0.5 + 0.5 * beat if left <= Prematch.PULSE_FROM else 0.5
	timer_label.add_theme_color_override("font_color", UI.INK.lerp(UI.BAD, red))
	timer_label.pivot_offset = timer_label.size * 0.5
	timer_label.scale = Vector2.ONE * (1.0 + PULSE_GROW * beat)

## Keeps the whole screen inside a title-safe margin, so the countdown shows at every window size;
## smaller windows get smaller digits. The declutter layout has no side column, so the Hunter grid
## keeps COLUMNS at every size (4 x CARD_MIN_W fits the 1240 logical px UI).
func _fit_safe_area() -> void:
	var win := get_viewport_rect().size
	var m := maxi(SAFE_MIN, int(win.y * SAFE_FRAC))
	for side in ["left", "right", "top", "bottom"]:
		_pad.add_theme_constant_override("margin_" + side, m)
	timer_label.add_theme_font_size_override("font_size", clampi(int(win.y * DIGITS_FRAC), DIGITS_MIN, TIMER_SIZE))

func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or e.echo or chat_in.has_focus() or pm.locked:
		return
	if e.pressed and e.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_show_chat_line(true)
		get_viewport().set_input_as_handled()
	elif e.physical_keycode == KEY_V and talk_btn.visible:
		_talk(e.pressed)

## Push-to-talk: the button (hold) or V. The transport is VoiceChat's; none ships yet.
func _talk(on: bool) -> void:
	voice.set_talking(on)
	talk_btn.text = "Speaking..." if on else "Hold to talk (V)"

# ------------------------------------------------------------------ hunters and squad
func _fill_hunters() -> void:
	for c in grid.get_children():
		c.queue_free()
	for ak in Arch.ids():
		grid.add_child(_tile(String(ak)))

## One card: portrait, name, role word. Stats and the unlock quest are the tooltip. A shut Hunter is dim
## with a padlock.
func _tile(ak: String) -> PanelContainer:
	var open := ClassUnlock.is_open(ak)
	var card := UI.tile_card(ak == pm.pick, func(): _choose(ak), 10, Arch.color(ak))
	card.custom_minimum_size = Vector2(CARD_MIN_W, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UI.hbox(10)
	card.add_child(row)
	row.add_child(ClassCard.portrait(ak))
	var col := UI.vbox(2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	col.add_child(UI.label(HeroTitle.base_name(ak), 20, Arch.color(ak) if open else UI.FAINT, UI.big))
	var role := String(Arch.def(ak)["card"]["role_word"])
	if ak == pm.pick and pm.locked:
		col.add_child(UI.label(role + "  ·  locked in", 13, UI.GOOD))
	else:
		col.add_child(UI.label(role, 13, UI.MUTED))
	card.tooltip_text = HunterViewer.stat_line(ak) + "\n" + ClassCard.kit_tip(ak)
	if not open:
		row.add_child(Padlock.new())
		card.modulate = Color(0.55, 0.55, 0.6, 0.8)
		card.tooltip_text = "Locked: %s\n%s" % [ClassUnlock.requirement(ak), card.tooltip_text]
	card.set_meta("arch", ak)
	return card

func _choose(ak: String) -> void:
	if pm.choose(ak):
		_fill_hunters()
		_fill_squad()
		_announce_pick()

func _fill_squad() -> void:
	for c in squad_box.get_children():
		c.queue_free()
	var mates := Prematch.squad_of(pm.opts, pm.pick, pm.peer_picks)
	for m in mates:
		var ak: String = m["arch"]
		var chip := UI.card(UI.CARD, 8, 6)
		var h := UI.hbox(8)
		chip.add_child(h)
		h.add_child(ClassCard.portrait(ak, 36.0) if Arch.exists(ak) else UI.label("?", 20))
		var you: bool = m["you"]
		var shown := String(m["name"]) + ("  (you)" if you else "")
		var tint := UI.ACCENT_HI if you else UI.INK
		h.add_child(UI.label(shown, UI.T_BODY, tint, UI.semi))
		h.add_child(UI.label(Arch.label(ak) if Arch.exists(ak) else "Choosing...", UI.T_SMALL, UI.MUTED))
		squad_box.add_child(chip)
	if mates.size() == 1 and int(pm.opts.get("squad", 1)) <= 1:
		squad_box.add_child(UI.para("A solo drop: nobody to plan with, but everyone else is out there."))
	talk_btn.visible = voice.available() and mates.any(func(m): return not m["you"] and m.get("peer", "") != "")

# ------------------------------------------------------------------ chat and picks
func _add_chat(who: String, text: String, col: Color) -> void:
	var l := UI.para("%s: %s" % [who, text], UI.T_BODY, col)
	chat_log.add_child(l)
	chat_scroll.visible = true
	await get_tree().process_frame
	chat_scroll.custom_minimum_size.y = minf(chat_log.get_combined_minimum_size().y, LOG_H)
	chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)

func _send_chat() -> void:
	var text := Prematch.clean_chat(chat_in.text)
	chat_in.clear()
	chat_in.release_focus()
	if text == "":
		return
	var me := String(Save.d.get("name", "Hunter"))
	_add_chat(me, text, UI.ACCENT_HI)
	if Net.mode != "":
		Net.lobby_emit("chat", {"name": me, "t": text})

func _announce_pick() -> void:
	if Net.mode != "":
		Net.lobby_emit("pick", {"arch": pm.pick})

## A teammate's chat line or pick (the lobby channel reaches everyone online: other squads' are dropped).
func _on_msg(topic: String, data, from: String) -> void:
	if typeof(data) != TYPE_DICTIONARY or not _teammate(from):
		return
	if topic == "chat":
		_add_chat(String(data.get("name", "Hunter")), Prematch.clean_chat(String(data.get("t", ""))), UI.INK)
	elif topic == "pick" and Arch.exists(String(data.get("arch", ""))):
		pm.peer_picks[from] = String(data["arch"])
		_fill_squad()

func _teammate(peer: String) -> bool:
	return Prematch.squad_of(pm.opts, pm.pick).any(func(m): return not m["you"] and m.get("peer", "") == peer)
