extends Control
## The pre-match lobby screen (rules: Prematch): wait for everyone to load, then pick your Hunter on
## your turn while your squad picks theirs, plan with text chat (and a voice hook). Once the whole
## squad has picked, the picks lock and the match loads.

const TIMER_SIZE := 72        # px, the countdown digits at full size
const SAFE_FRAC := 0.04       # fraction of the window height kept clear on every side (title-safe)
const DIGITS_FRAC := 0.08     # countdown digit size as a fraction of the window height
const DIGITS_MIN := 44         # px, the smallest countdown digits
const PULSE_RATE := 0.012      # radians per ms of the last-seconds throb (about 2 beats a second)
const PULSE_GROW := 0.12       # the digits swell by this much at the top of a beat
const SAFE_MIN := 24          # px, the least margin at any window size
const TICK_FROM := 5.0        # s left on your turn when the countdown ticks each second
const PULSE_FROM := 3.0       # s left on your turn when the countdown throbs red
const COLUMNS := 4            # roster tiles per row
const TILE_FRAC := 0.085      # a roster tile's portrait as a fraction of the window height
const TILE_MIN := 60.0        # px, the smallest roster portrait
const TILE_MAX := 100.0       # px, the largest roster portrait
const NAME_FRAC := 0.07       # the hero name's size as a fraction of the window height
const NAME_MIN := 40          # px, the smallest hero name
const ABILITY_PX := 50.0      # px, one ability tile (icon and key)
const SQUAD_PX := 40.0        # px, a squadmate's portrait in the strip
const LOCK_H := 52.0          # px, the Lock in button's height
const LOG_H := 84.0           # px, the most the chat log grows to (it scrolls past that)
const PICKING_FILL := Color(0.36, 0.3, 0.14)    # the squad chip of whoever is picking: a warm gold card
const SHADE := Color(0.05, 0.035, 0.08)         # the dark the splash fades into under the roster and the text
const DIM := Color(0.55, 0.55, 0.6, 0.8)        # a roster tile you can't pick (shut or taken)

var pm: Prematch
var voice := VoiceChat.new()
var caption: Label            # over the countdown: whose turn it is
var note_label: Label         # under the countdown: the first-lobby teach (empty otherwise)
var timer_label: Label
var hero_art: TextureRect     # the shown Hunter's splash, behind everything
var hero_name: Label
var hero_role: Label
var ability_row: HBoxContainer
var lock_btn: Button
var _pad: MarginContainer
var _last_sec := -1
var _hover := ""              # the roster tile under the mouse ("" for none): the hero shows it
var grid: GridContainer
var squad_box: HBoxContainer
var chat_log: VBoxContainer
var chat_scroll: ScrollContainer
var chat_in: LineEdit
var chat_hint: Label
var talk_btn: Button
var _shown_turn := -2       # the turn the hunters and squad were last drawn for

## A small padlock for a shut Hunter: a body and a shackle.
class Padlock extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(22, 26)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_END
		size_flags_vertical = Control.SIZE_SHRINK_END

	func _draw() -> void:
		draw_arc(Vector2(11, 10), 6.0, PI, TAU, 12, UI.FAINT, 2.5)
		draw_rect(Rect2(3, 10, 16, 14), UI.FAINT)

func setup(opts: Dictionary) -> void:
	pm = Prematch.new(opts)

## The layout: the shown Hunter's splash fills the screen; the squad and the countdown on top, the
## Hunter's name, role and ability icons low on the left, the roster on the right, chat and Lock in under it.
func _ready() -> void:
	Sfx.play_music(Soundtrack.track("menu", "title"))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	hero_art = TextureRect.new()
	hero_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hero_art)
	add_child(_shade([0.0, 0.5, 0.72, 1.0], [0.0, 0.15, 0.85, 0.92], Vector2(1, 0)))
	add_child(_shade([0.0, 0.55, 1.0], [0.0, 0.0, 0.8], Vector2(0, 1)))
	_pad = MarginContainer.new()
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pad)
	get_viewport().size_changed.connect(_fit_safe_area)
	var root := UI.vbox(12)
	_pad.add_child(root)
	root.add_child(_top_bar())
	var mid := UI.hbox(24)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)
	var left := UI.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_END
	mid.add_child(left)
	_build_hero(left)
	_build_chat(left)
	var right := UI.vbox(14)
	right.alignment = BoxContainer.ALIGNMENT_END
	mid.add_child(right)
	grid = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	right.add_child(grid)
	lock_btn = UI.primary("Lock in", _lock_in)
	lock_btn.custom_minimum_size.y = LOCK_H
	right.add_child(lock_btn)
	_talk(false)
	_fit_safe_area()
	if pm.first:
		Prematch.mark_first_seen()
	pm.turn_done.connect(_on_turn_done)
	_tick_label()
	Net.message.connect(_on_msg)
	_announce_loaded()

## A full-screen fade from clear to SHADE along `dir` (x: toward the roster, y: toward the bottom).
func _shade(offs: Array, alphas: Array, dir: Vector2) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(alphas.map(func(a): return Color(SHADE, a)))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = dir
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return tr

## Your squad on the left, the turn caption and countdown in the middle.
func _top_bar() -> Control:
	var bar := UI.hbox(12)
	squad_box = UI.hbox(8)
	squad_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(squad_box)
	var banner := UI.vbox(0)
	bar.add_child(banner)
	caption = _outlined(UI.label("", 16, UI.MUTED, UI.caps))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(caption)
	timer_label = _outlined(UI.label("", TIMER_SIZE, UI.INK, UI.big))
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(timer_label)
	note_label = _outlined(UI.label("", 18, UI.GOOD, UI.semi))
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(note_label)
	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(right)
	return bar

## The shown Hunter's name, its role (or why you can't pick it) and its ability icons.
func _build_hero(parent: Control) -> void:
	hero_name = _outlined(UI.label("", 64, UI.INK, UI.big))
	parent.add_child(hero_name)
	hero_role = _outlined(UI.label("", 20, UI.MUTED, UI.semi))
	parent.add_child(hero_role)
	ability_row = UI.hbox(6)
	parent.add_child(ability_row)
	parent.add_child(UI.spacer(10))

## Text drawn over the splash gets a dark rim so it reads on any art.
func _outlined(l: Label) -> Label:
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	return l

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
	var go := pm.tick(delta)
	_tick_label()
	if go:
		set_process(false)
		Game.goto("match", pm.launch_opts())

## The countdown and the caption over it; redraws the roster, squad and hero when the turn moves on.
func _tick_label() -> void:
	if pm.turn != _shown_turn:
		_shown_turn = pm.turn
		_refresh()
		if pm.locked:
			chat_in.release_focus()
	var m := pm.picker()
	var s := int(ceil(maxf(pm.turn_left, 0.0)))
	timer_label.text = "" if m.is_empty() else "0:%02d" % s
	if pm.turn < 0:
		var lc := pm.loaded_count()
		caption.text = "WAITING FOR PLAYERS  %d/%d" % [lc.x, lc.y]
	elif pm.locked:
		caption.text = "PICKS LOCKED"
	elif pm.my_turn():
		caption.text = "YOUR TURN"
	else:
		caption.text = "%s IS PICKING" % String(m["name"]).to_upper()
	note_label.text = pm.teach_line()
	var mine := pm.my_turn() and not pm.locked
	if s != _last_sec:
		_last_sec = s
		if mine and pm.turn_left > 0.0 and pm.turn_left <= TICK_FROM:
			Sfx.play("click", null, 0.0, 0.0, 1.5 if pm.turn_left <= PULSE_FROM else 1.0)
	_pulse(pm.turn_left if mine else Prematch.TURN)

## Digits warm to red below TICK_FROM and throb red below PULSE_FROM (your own turn only).
func _pulse(left: float) -> void:
	var beat := 0.0
	if left <= PULSE_FROM:
		beat = 0.5 + 0.5 * sin(Time.get_ticks_msec() * PULSE_RATE)
	var red := 0.0
	if left <= TICK_FROM:
		red = 0.5 + 0.5 * beat if left <= PULSE_FROM else 0.5
	timer_label.add_theme_color_override("font_color", UI.INK.lerp(UI.BAD, red))
	timer_label.pivot_offset = timer_label.size * 0.5
	timer_label.scale = Vector2.ONE * (1.0 + PULSE_GROW * beat)

## Keeps the whole screen inside a title-safe margin, so the countdown shows at every window size;
## the digits, the hero name and the roster tiles scale with the window height.
func _fit_safe_area() -> void:
	var win := get_viewport_rect().size
	var m := maxi(SAFE_MIN, int(win.y * SAFE_FRAC))
	for side in ["left", "right", "top", "bottom"]:
		_pad.add_theme_constant_override("margin_" + side, m)
	timer_label.add_theme_font_size_override("font_size", clampi(int(win.y * DIGITS_FRAC), DIGITS_MIN, TIMER_SIZE))
	hero_name.add_theme_font_size_override("font_size", maxi(NAME_MIN, int(win.y * NAME_FRAC)))
	_fill_hunters()

func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or e.echo or chat_in.has_focus() or pm.locked:
		return
	if e.pressed and e.is_action("confirm"):
		_show_chat_line(true)
		get_viewport().set_input_as_handled()
	elif e.is_action("push_to_talk") and talk_btn.visible:
		_talk(e.pressed)

## Push-to-talk: the button (hold) or the push_to_talk key. The transport is VoiceChat's; none ships yet.
func _talk(on: bool) -> void:
	voice.set_talking(on)
	talk_btn.text = "Speaking..." if on else "Hold to talk (%s)" % Settings.key_cap("push_to_talk")

# ------------------------------------------------------------------ hero, roster and squad
func _refresh() -> void:
	_fill_hunters()
	_fill_squad()
	_show_hero()

## The Hunter the big view shows: the roster tile under the mouse, else your pick, else your saved one.
func shown_hunter() -> String:
	if _hover != "":
		return _hover
	return pm.pick if pm.pick != "" else Arch.of_save()

## The splash, name, one status line (role word, or why you can't pick it) and the ability icons.
func _show_hero() -> void:
	var ak := shown_hunter()
	var path := Portraits.art_path(ak, true)
	hero_art.texture = load(path) if path != "" else null
	hero_name.text = HeroTitle.base_name(ak) if HeroTitle.base_name(ak) != "" else Arch.name_of(ak)
	hero_name.add_theme_color_override("font_color", Arch.color(ak))
	var role := String(Arch.def(ak)["card"]["role_word"])
	var mate := pm.taken_by(ak) if ak != pm.pick else ""
	if not ClassUnlock.is_open(ak):
		role = "Locked: " + ClassUnlock.requirement(ak)
	elif mate != "":
		role += "  ·  taken by " + mate
	hero_role.text = role
	for c in ability_row.get_children():
		c.free()
	for slot in KitCard.slots_of(ak):
		ability_row.add_child(_ability(ak, slot))
	_fit_lock()

## One ability: its icon and key on a small tile; its name and what it does on hover.
func _ability(ak: String, slot: String) -> Control:
	var info := KitCard.slot_text(ak, slot)
	var tile := PanelContainer.new()
	var face := UI.frame(Color(UI.NIGHT, 0.8), UI.R_CTRL, Color(info["col"], 0.5), 1, 4, 3)
	tile.add_theme_stylebox_override("panel", face)
	tile.custom_minimum_size = Vector2(ABILITY_PX, ABILITY_PX)
	tile.tooltip_text = "%s (%s)\n%s" % [info["name"], KitCard.LABEL[slot], info["line"]]
	var v := UI.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	tile.add_child(v)
	var dot := UI.IconDot.new(String(info["icon"]), info["col"], 26.0)
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(dot)
	var key := KitCard.key_cap(slot)
	var kl := UI.label(key if key != "" else "Passive", 10, UI.MUTED, UI.semi)
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(kl)
	return tile

## Lock in: live on your turn once you have a pick; says so once your pick is in.
func _fit_lock() -> void:
	var mine := pm.my_turn() and not pm.locked
	lock_btn.disabled = not mine or pm.pick == ""
	var done := pm.pick != "" and not mine
	lock_btn.text = "Locked in" if done else "Lock in"

func _lock_in() -> void:
	pm.lock_in()

func _fill_hunters() -> void:
	for c in grid.get_children():
		c.queue_free()
	var px := clampf(get_viewport_rect().size.y * TILE_FRAC, TILE_MIN, TILE_MAX)
	for ak in Arch.ids():
		grid.add_child(_tile(String(ak), px))

## One roster tile: the portrait only. Hovering shows the Hunter big; stats and the unlock quest are the
## tooltip. A shut Hunter is dim with a padlock, a squadmate's is dim.
func _tile(ak: String, px: float) -> PanelContainer:
	var open := ClassUnlock.is_open(ak)
	var card := UI.tile_card(ak == pm.pick, func(): _choose(ak), 4, Arch.color(ak))
	card.add_child(ClassCard.portrait(ak, px))
	card.tooltip_text = "%s  ·  %s\n%s\n%s\n%s" % [HeroTitle.base_name(ak), Arch.def(ak)["card"]["role_word"],
		HunterViewer.stat_line(ak), "\n".join(ClassCard.howto_lines(ak)), ClassCard.kit_tip(ak)]
	if not open:
		card.add_child(Padlock.new())
		card.tooltip_text = "Locked: %s\n%s" % [ClassUnlock.requirement(ak), card.tooltip_text]
	if not open or (pm.taken_by(ak) != "" and ak != pm.pick):
		card.modulate = DIM
	card.mouse_entered.connect(_hover_on.bind(ak))
	card.mouse_exited.connect(_hover_on.bind(""))
	card.set_meta("arch", ak)
	return card

## A squadmate who hasn't picked yet: a dim square where their portrait goes.
func _empty_face() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.frame(UI.WELL, UI.R_SMALL, UI.LINE))
	p.custom_minimum_size = Vector2(SQUAD_PX, SQUAD_PX)
	return p

func _hover_on(ak: String) -> void:
	_hover = ak
	_show_hero()

func _choose(ak: String) -> void:
	if pm.choose(ak):
		_refresh()
		_announce_pick(false)

## Your squad in pick order: portrait, name, and their Hunter (or that they are picking).
func _fill_squad() -> void:
	for c in squad_box.get_children():
		c.queue_free()
	var now := pm.picker()
	for m in pm.squad:
		var ak: String = m["arch"]
		var chip := UI.card(PICKING_FILL if m == now else Color(UI.CARD, 0.85), 8, 6)
		chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var h := UI.hbox(8)
		chip.add_child(h)
		h.add_child(ClassCard.portrait(ak, SQUAD_PX) if Arch.exists(ak) else _empty_face())
		var v := UI.vbox(0)
		h.add_child(v)
		var you: bool = m["you"]
		v.add_child(UI.label(String(m["name"]), UI.T_BODY, UI.ACCENT_HI if you else UI.INK, UI.semi))
		var state := "Picking..." if m == now else "Waiting"
		var shown := Arch.label(ak) if Arch.exists(ak) else state
		v.add_child(UI.label(shown, UI.T_SMALL, UI.GOLD if m == now else UI.MUTED))
		if not you and not bool(m["bot"]):
			h.add_child(_mute_button(String(m["name"])))
		squad_box.add_child(chip)
	talk_btn.visible = voice.available() and pm.squad.any(func(m): return not m["you"] and m.get("peer", "") != "")

# ------------------------------------------------------------------ chat and picks
## The squad row's Mute button: silences that teammate's chat and voice for you, this session.
func _mute_button(who: String) -> Button:
	var b := UI.button("", Callable())
	var refresh := func() -> void: b.text = "Muted" if MuteList.has(who) else "Mute"
	refresh.call()
	b.pressed.connect(func():
		MuteList.toggle(who)
		refresh.call()
		for l in chat_log.get_children():
			if l.get_meta("who", "") == who:
				l.visible = not MuteList.has(who))
	return b

func _add_chat(who: String, text: String, col: Color) -> void:
	var l := UI.para("%s: %s" % [who, text], UI.T_BODY, col)
	l.set_meta("who", who)
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
		var who := String(data.get("name", "Hunter"))
		if not MuteList.has(who):
			_add_chat(who, Prematch.clean_chat(String(data.get("t", ""))), UI.INK)
	elif topic == "pick" and pm.remote_pick(from, String(data.get("arch", "")), bool(data.get("final", false))):
		_refresh()

func _teammate(peer: String) -> bool:
	return pm.squad.any(func(m): return not m["you"] and m["peer"] == peer)
