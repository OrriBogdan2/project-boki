extends Control
## The pre-match lobby screen (rules: Prematch): pick your Hunter, meet your squad, plan with text
## chat (and a voice hook), watch the countdown. At 0 the picks lock and the match loads.

const TIMER_SIZE := 88        # px, the countdown digits
const SAFE_FRAC := 0.04       # fraction of the window height kept clear on every side (title-safe)
const PULSE_RATE := 0.012      # radians per ms of the last-seconds throb (about 2 beats a second)
const PULSE_GROW := 0.12       # the digits swell by this much at the top of a beat
const SAFE_MIN := 24          # px, the least margin at any window size

var pm: Prematch
var voice := VoiceChat.new()
var timer_label: Label
var note_label: Label
var banner: VBoxContainer
var _pad: MarginContainer
var _last_sec := -1
var hint: Label
var grid: GridContainer
var squad_box: VBoxContainer
var chat_log: VBoxContainer
var chat_scroll: ScrollContainer
var chat_in: LineEdit
var talk_btn: Button

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
	resized.connect(_fit_safe_area)
	_fit_safe_area()
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
	var titles := UI.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(UI.section("Before the drop", UI.GOLD))
	titles.add_child(UI.title("Pick your Hunter", 34))
	hint = UI.para("Your squad can see your pick. Picks lock when the timer ends.")
	titles.add_child(hint)
	var cols := UI.hbox(24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(sc)
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	sc.add_child(grid)
	var side_col := UI.vbox(12)
	side_col.custom_minimum_size = Vector2(380, 0)
	cols.add_child(side_col)
	side_col.add_child(UI.section("Your squad"))
	squad_box = UI.vbox(6)
	side_col.add_child(squad_box)
	side_col.add_child(UI.section("Squad chat"))
	chat_scroll = ScrollContainer.new()
	chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_col.add_child(chat_scroll)
	chat_log = UI.vbox(4)
	chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_scroll.add_child(chat_log)
	var row := UI.hbox(8)
	side_col.add_child(row)
	chat_in = LineEdit.new()
	chat_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_in.placeholder_text = "Plan with your squad..."
	chat_in.max_length = Prematch.CHAT_MAX
	chat_in.text_submitted.connect(func(_t): _send_chat())
	row.add_child(chat_in)
	row.add_child(UI.button("Say", _send_chat))
	talk_btn = UI.button("", Callable())
	talk_btn.button_down.connect(func(): _talk(true))
	talk_btn.button_up.connect(func(): _talk(false))
	side_col.add_child(talk_btn)
	_talk(false)
	_fill_hunters()
	_fill_squad()
	_tick_label()
	Net.message.connect(_on_msg)
	_announce_pick()

func _exit_tree() -> void:
	if Net.message.is_connected(_on_msg):
		Net.message.disconnect(_on_msg)

func _process(delta: float) -> void:
	var was := pm.locked
	var go := pm.tick(delta)
	_tick_label()
	if pm.locked and not was:
		hint.text = "Picks are locked. Loading in..."
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

## Keeps the whole screen inside a title-safe margin, so the countdown shows at every window size.
func _fit_safe_area() -> void:
	var m := maxi(SAFE_MIN, int(size.y * SAFE_FRAC))
	for side in ["left", "right", "top", "bottom"]:
		_pad.add_theme_constant_override("margin_" + side, m)

func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.physical_keycode == KEY_V and not e.echo and not chat_in.has_focus():
		_talk(e.pressed)

## Push-to-talk: the button (hold) or V. The transport is VoiceChat's; none ships yet.
func _talk(on: bool) -> void:
	voice.set_talking(on)
	var label := "Speaking..." if on else "Hold to talk (V)"
	if not voice.available():
		label += "  -  voice isn't connected yet"
	talk_btn.text = label

# ------------------------------------------------------------------ hunters and squad
func _fill_hunters() -> void:
	for c in grid.get_children():
		c.queue_free()
	for ak in Arch.ids():
		grid.add_child(_tile(String(ak)))

func _tile(ak: String) -> PanelContainer:
	var open := ClassUnlock.is_open(ak)
	var card := UI.tile_card(ak == pm.pick, func(): _choose(ak), 10, Arch.color(ak))
	card.custom_minimum_size = Vector2(HeroGrid.CARD_W, 0)
	var row := UI.hbox(10)
	card.add_child(row)
	row.add_child(ClassCard.portrait(ak))
	var col := UI.vbox(2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(UI.label(HunterViewer.display_name(ak), 18, Arch.color(ak) if open else UI.FAINT, UI.big))
	col.add_child(UI.label(HunterViewer.stat_line(ak), 12, UI.MUTED))
	if ak == pm.pick:
		col.add_child(UI.label("Locked in" if pm.locked else "Your pick", 12, UI.GOOD, UI.semi))
	elif not open:
		col.add_child(UI.label("Locked: " + ClassUnlock.requirement(ak), 12, UI.FAINT, UI.semi))
		card.modulate = Color(0.55, 0.55, 0.6, 0.8)
	card.tooltip_text = ClassCard.kit_tip(ak)
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
	for m in Prematch.squad_of(pm.opts, pm.pick, pm.peer_picks):
		var ak: String = m["arch"]
		var row := UI.card(UI.CARD, 8, 10)
		var h := UI.hbox(10)
		row.add_child(h)
		h.add_child(ClassCard.portrait(ak, 48.0) if Arch.exists(ak) else UI.label("?", 24))
		var you: bool = m["you"]
		var shown := "%s%s" % [m["name"], "  (you)" if you else ""]
		var nm := UI.label(shown, UI.T_BODY, UI.ACCENT_HI if you else UI.INK, UI.semi)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(UI.label(Arch.label(ak) if Arch.exists(ak) else "Choosing...", 14, UI.MUTED))
		squad_box.add_child(row)
	if squad_box.get_child_count() == 1 and int(pm.opts.get("squad", 1)) <= 1:
		squad_box.add_child(UI.para("A solo drop: nobody to plan with, but everyone else is out there."))

# ------------------------------------------------------------------ chat and picks
func _add_chat(who: String, text: String, col: Color) -> void:
	var l := UI.para("%s: %s" % [who, text], UI.T_BODY, col)
	chat_log.add_child(l)
	await get_tree().process_frame
	chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)

func _send_chat() -> void:
	var text := Prematch.clean_chat(chat_in.text)
	chat_in.clear()
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
