class_name BaseHud
extends PanelContainer
## The farm's HUD card in base mode (farm_build.json "base_mode"): what changed since you left, how your
## Boki is doing (its four needs) and the one thing to do next. It sits under the top chips and shows only
## with base_mode on; the old counters, job lines and tutorial line step aside (TopChips, HomeWork, FarmGuide).

const REFRESH_S := 0.5      # seconds between redraws: needs drift slowly
const WIDTH := 250.0        # px
const BAR_W := 96.0         # px, one need's bar
const LOW := 38.0           # a need under this is a want (Care.want)

## The lines of "While you were away" from the last arrival (set once by home.gd when you arrive).
static var away: Array = []

var h
var body: VBoxContainer
var t := 0.0
var sig := ""

static func arrived(lines: Array) -> void:
	away = lines

## Builds the card on the home's UI layer, under any open menu.
static func attach(home) -> void:
	var card := BaseHud.new()
	card.h = home
	home.root_ui.add_child(card)
	if is_instance_valid(home.panel_host):
		home.root_ui.move_child(card, home.panel_host.get_index())

func _init() -> void:
	name = "BaseHud"
	add_theme_stylebox_override("panel", (UI.glass(8, 12)).get_theme_stylebox("panel"))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(16, 62)      # under the top chips
	custom_minimum_size.x = WIDTH
	body = UI.vbox(4)
	add_child(body)
	visible = false

func _process(dt: float) -> void:
	visible = FarmUnlocks.base_mode() and h.visit.is_empty()
	t += dt
	if visible and t >= REFRESH_S:
		t = 0.0
		_refresh()

func _refresh() -> void:
	var rec := Save.active_kin()
	var s := "%s|%s" % [str(away.size()), "" if rec.is_empty() else _need_sig(rec)]
	if s == sig:
		return
	sig = s
	for c in body.get_children():
		c.queue_free()
	if not away.is_empty():
		var more := "" if away.size() == 1 else " (+%d more)" % (away.size() - 1)
		body.add_child(_para("While you were away: %s%s" % [away[0], more], UI.MUTED))
	if rec.is_empty():
		return
	body.add_child(UI.label(String(rec["name"]), 14, UI.INK, UI.semi))
	for n in Care.NEEDS:
		body.add_child(_need_row(String(n), Care.need(rec, n)))
	body.add_child(_para(next_action(rec, h.POND_EDGE.x > -100.0), UI.GOLD))
	reset_size()

## The one thing to do next: the base tutorial's step while it runs, else what the Boki wants, else something to enjoy.
static func next_action(rec: Dictionary, pond: bool) -> String:
	if FarmTutorial.active():
		return FarmTutorial.hint_text(FarmTutorial.current())
	if Care.want(rec) != "":
		return KinWants.line(rec, pond)
	return "%s is happy: take a trip, or place a toy" % String(rec["name"])

func _need_sig(rec: Dictionary) -> String:
	return "%s%s%s" % [rec["uid"], Care.NEEDS.map(func(n): return int(Care.need(rec, n) / 4.0)), FarmTutorial.current()]

func _need_row(n: String, v: float) -> Control:
	var row := UI.hbox(6)
	var lbl := UI.label(String(Care.NEED_INFO[n]["name"]), 12, UI.MUTED)
	lbl.custom_minimum_size.x = 52.0
	row.add_child(lbl)
	row.add_child(UI.bar(v / 100.0, UI.BAD if v < LOW else Care.NEED_INFO[n]["col"], BAR_W, 7.0))
	return row

func _para(text: String, col: Color) -> Label:
	var l := UI.label(text, 13, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = WIDTH - 20.0
	return l
