extends Control
## The pre-match lobby screen (rules: Prematch): wait for everyone to load, then pick your Hunter on
## your turn while your squad picks theirs, plan with text chat (and a voice hook). Once the whole
## squad has picked, the picks lock and the match loads.

var pm: Prematch
var voice := VoiceChat.new()
var timer_label: Label
var hint: Label
var grid: GridContainer
var squad_box: VBoxContainer
var chat_log: VBoxContainer
var chat_scroll: ScrollContainer
var chat_in: LineEdit
var talk_btn: Button
const PICKING_FILL := Color(0.36, 0.3, 0.14)    # the squad row of whoever is picking: a warm gold card
var _shown_turn := -2       # the turn the hunters and squad were last drawn for

func setup(opts: Dictionary) -> void:
	pm = Prematch.new(opts)

func _ready() -> void:
	Sfx.play_music("title")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 36)
	add_child(pad)
	var root := UI.vbox(14)
	pad.add_child(root)
	var head := UI.hbox(20)
	root.add_child(head)
	var titles := UI.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(UI.section("Before the drop", UI.GOLD))
	titles.add_child(UI.title("Pick your Hunter", 34))
	hint = UI.para("")
	titles.add_child(hint)
	timer_label = UI.label("", 56, UI.INK, UI.big)
	head.add_child(timer_label)
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
	pm.turn_done.connect(_on_turn_done)
	_tick_label()
	Net.message.connect(_on_msg)
	_announce_loaded()

func _exit_tree() -> void:
	if Net.message.is_connected(_on_msg):
		Net.message.disconnect(_on_msg)

func _process(delta: float) -> void:
	var go := pm.tick(delta)
	_tick_label()
	if go:
		set_process(false)
		Game.goto("match", pm.launch_opts())

## The countdown and the line under the title; redraws the hunters and squad when the turn moves on.
func _tick_label() -> void:
	if pm.turn != _shown_turn:
		_shown_turn = pm.turn
		_fill_hunters()
		_fill_squad()
		if pm.locked:
			chat_in.release_focus()
	var m := pm.picker()
	timer_label.text = "" if m.is_empty() else "0:%02d" % int(ceil(maxf(pm.turn_left, 0.0)))
	timer_label.add_theme_color_override("font_color", UI.BAD if pm.my_turn() and pm.turn_left <= 3.0 else UI.INK)
	if pm.turn < 0:
		var lc := pm.loaded_count()
		hint.text = "Waiting for players to load (%d/%d)" % [lc.x, lc.y]
	elif pm.locked:
		hint.text = "Picks are locked. Loading in..."
	elif pm.my_turn():
		hint.text = "Your turn: pick a Hunter. No two on a squad can be the same one."
	else:
		hint.text = "%s is picking. Your squad picks in turn, %d seconds each." % [m["name"], int(Prematch.TURN)]

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
	var mate := pm.taken_by(ak) if ak != pm.pick else ""
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
		col.add_child(UI.label("Your pick" if pm.my_turn() else "Locked in", 12, UI.GOOD, UI.semi))
	elif mate != "":
		col.add_child(UI.label("Taken by " + mate, 12, UI.FAINT, UI.semi))
		card.modulate = Color(0.55, 0.55, 0.6, 0.8)
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
		_announce_pick(false)

## Your squad in pick order; whoever is picking is outlined.
func _fill_squad() -> void:
	for c in squad_box.get_children():
		c.queue_free()
	var now := pm.picker()
	for m in pm.squad:
		var ak: String = m["arch"]
		var row := UI.card(PICKING_FILL if m == now else UI.CARD, 8, 10)
		var h := UI.hbox(10)
		row.add_child(h)
		h.add_child(ClassCard.portrait(ak, 48.0) if Arch.exists(ak) else UI.label("?", 24))
		var you: bool = m["you"]
		var shown := "%s%s" % [m["name"], "  (you)" if you else ""]
		var nm := UI.label(shown, UI.T_BODY, UI.ACCENT_HI if you else UI.INK, UI.semi)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		var state := "Picking..." if m == now else "Waiting to pick"
		h.add_child(UI.label(Arch.label(ak) if Arch.exists(ak) else state, 14, UI.GOLD if m == now else UI.MUTED))
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

## Your pick to the squad: live while you choose, `final` when your turn ends.
func _announce_pick(final: bool) -> void:
	if Net.mode != "":
		Net.lobby_emit("pick", {"arch": pm.pick, "final": final})

func _announce_loaded() -> void:
	if Net.mode != "":
		Net.lobby_emit("loaded", {})

func _on_turn_done(i: int) -> void:
	if pm.squad[i]["you"]:
		_announce_pick(true)

## Someone loaded (every squad: picking waits for the whole lobby), or a teammate's chat line or pick
## (the lobby channel reaches everyone online: other squads' chat and picks are dropped).
func _on_msg(topic: String, data, from: String) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	if topic == "loaded":
		if pm.mark_loaded(from):
			_announce_loaded()
		return
	if not _teammate(from):
		return
	if topic == "chat":
		_add_chat(String(data.get("name", "Hunter")), Prematch.clean_chat(String(data.get("t", ""))), UI.INK)
	elif topic == "pick" and pm.remote_pick(from, String(data.get("arch", "")), bool(data.get("final", false))):
		_fill_hunters()
		_fill_squad()

func _teammate(peer: String) -> bool:
	return pm.squad.any(func(m): return not m["you"] and m["peer"] == peer)
