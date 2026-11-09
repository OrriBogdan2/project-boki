extends Control
## Play online: pick a mode, queue at the nearest matchmaker, see where you are in the line, and
## go straight into the match when it's made (OnlineSession does the work; this shows it).

const MODES := [["arena", "Arena", "Four against four.", "burst"],
	["trio", "Expedition", "Squads of three on the islands, with their Boki.", "portal"]]

var opts := {}
var session: OnlineSession
var status: Label
var line: Label
var detail: Label
var cancel_btn: Button
var mode_btns := {}

func setup(o: Dictionary) -> void:
	opts = o

func _ready() -> void:
	Sfx.play_music("title")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var pb := UI.scroll_panel("Play online", 600, _back, "Back")
	var panel: PanelContainer = pb[0]
	var v: VBoxContainer = pb[1]
	center.add_child(panel)
	UI.pop_in(panel)
	status = panel.get_meta("sub")
	UI.subtitle(v, "Matches run on Project Boki's servers; empty seats are filled with bots.")
	v.add_child(UI.section("What to play"))
	for md in MODES:
		var key := String(md[0])
		var row := UI.card(UI.CARD, 10, 12)
		var h := UI.hbox(12)
		row.add_child(h)
		var txt := UI.vbox(1)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_child(UI.label(String(md[1]), UI.T_BODY, UI.INK, UI.semi))
		txt.add_child(UI.label(String(md[2]), 13, UI.MUTED))
		h.add_child(txt)
		var b := UI.button("Queue", func(): session.queue_for(key), 120, String(md[3]))
		mode_btns[key] = b
		h.add_child(b)
		v.add_child(row)
	v.add_child(UI.spacer(2))
	v.add_child(UI.section("Your place in line"))
	line = UI.para("Pick a mode to queue.", UI.T_BODY, UI.INK)
	v.add_child(line)
	detail = UI.para("", UI.T_SMALL, UI.MUTED)
	v.add_child(detail)
	cancel_btn = UI.button("Leave the queue", func(): session.cancel(), 180, "close")
	UI.footer(v).add_child(cancel_btn)
	session = OnlineSession.get_session()
	session.changed.connect(_refresh)
	_refresh()
	if opts.has("mode"):
		session.queue_for(String(opts["mode"]))

func _exit_tree() -> void:
	if session and session.changed.is_connected(_refresh):
		session.changed.disconnect(_refresh)

## Esc goes back, like the X; leaving the screen leaves the queue.
func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("menu") and not Overlay.is_open():
		get_viewport().set_input_as_handled()
		_back()

func _back() -> void:
	session.cancel()
	Game.goto("home" if not Save.d["roster"].is_empty() else "title")

func _refresh() -> void:
	if not is_instance_valid(line):
		return
	var st := session.state
	var busy := st in ["region", "queue", "connect", "wait"]
	for k in mode_btns:
		mode_btns[k].disabled = busy
		mode_btns[k].theme_type_variation = "Chosen" if busy and k == session.mode else ""
	cancel_btn.visible = busy
	var where := ""
	if not session.region.is_empty():
		where = "%s server, %d ms" % [String(session.region.get("id", "")).to_upper(), int(session.region.get("ms", 0))]
	status.text = where if where != "" else "Build %s" % Net.VERSION
	match st:
		"queue":
			var what: String = OnlineSession.MODE_NAMES.get(session.mode, session.mode)
			line.text = "%s: you're number %d in line" % [what, maxi(session.place, 1)]
			line.add_theme_color_override("font_color", UI.INK)
			detail.text = "Looking for hunters..."
			if session.eta_s > 0:
				detail.text = "About %d seconds. Empty seats go to bots when the wait runs out." % session.eta_s
		"error":
			line.text = session.message
			line.add_theme_color_override("font_color", UI.BAD)
			detail.text = "Game version %s." % Net.VERSION
		"idle":
			line.text = "Pick a mode to queue."
			line.add_theme_color_override("font_color", UI.INK)
			detail.text = ""
		_:
			line.text = session.message
			line.add_theme_color_override("font_color", UI.INK)
			detail.text = ""
