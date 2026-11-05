class_name MsgLane
extends Control
## The one lane for short messages on screen: toasts, pickups, level-ups, hints and the lines the
## tutorial holds back. Every screen has one (the match HUD, the farm, the town, a house; UI.toast finds
## or makes it). Messages stack down a fixed column under `top`, so two never sit on top of each other;
## a repeat of one on show or waiting merges into it ("Ember  x3"); at most MAX_SHOWN show at once
## (fewer while the host's own cards take rows, see `reserved`) and the rest wait, the most important
## first; each lives a short while. A low-priority line that waits too long is dropped as old news.

enum { LOW, NORMAL, HIGH }
const MAX_SHOWN := 3
const LIFE := [1.8, 2.4, 3.2]   # s on show for LOW, NORMAL, HIGH, fades included
const PX := [15, 17, 20]        # font px for LOW, NORMAL, HIGH
const STALE := 3.0              # s a LOW line may wait before it's dropped
const WAIT_CAP := 6             # lines waiting at most: past it the oldest of the lowest priority goes
const FADE_IN := 0.15           # s
const FADE_OUT := 0.35          # s
const GAP := 6.0                # px between two cards
const CLOSE_UP := 12.0          # 1/s: how fast the cards below slide up when one goes
const WIDE := 0.45              # of the screen width: the widest a card gets before its line wraps

var top := 100.0                ## px from the top of the screen where the column starts
var right_edge := 0.0           ## 0: the column is centred; else its right edge, in px
var reserved := 0               ## rows the host's own cards take at the top (the ally alerts)
var hold := false:              ## true: nothing new comes in (the tutorial banner has the floor)
	set(v):
		hold = v
		_promote()
var _shown: Array[Dictionary] = []
var _waiting: Array[Dictionary] = []

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## The lane on `host`, made (on top of its other children) the first time.
static func of(host: Control) -> MsgLane:
	for ch in host.get_children():
		if ch is MsgLane:
			return ch
	var lane := MsgLane.new()
	host.add_child(lane)
	return lane

## Puts a line in the lane. `life` 0 uses the priority's own; a hint passes a longer one.
func push(text: String, col: Color, prio := NORMAL, life := 0.0) -> void:
	if text == "":
		return
	for e in _shown:
		if e["text"] == text:
			_bump(e)
			e["t"] = minf(float(e["t"]), FADE_IN)      # a repeat starts its time again
			return
	for e in _waiting:
		if e["text"] == text:
			_bump(e)
			return
	var life_s := life if life > 0.0 else float(LIFE[prio])
	_waiting.append({"text": text, "col": col, "prio": prio, "life": life_s, "n": 1, "t": 0.0, "wait": 0.0})
	Sfx.play("ui_toast", null, -4.0, 0.03)
	if _waiting.size() > WAIT_CAP:
		_waiting.remove_at(_lowest())
	if get_parent() is Control:
		get_parent().move_child(self, -1)      # over the panels opened since
	_promote()

## Removes every line, on show or waiting.
func clear() -> void:
	for e in _shown:
		(e["box"] as Control).queue_free()
	_shown.clear()
	_waiting.clear()

## Lines on show plus lines waiting.
func count() -> int:
	return _shown.size() + _waiting.size()

## The lines on show now, top to bottom, as they read ("Ember  x3").
func texts() -> Array[String]:
	var out: Array[String] = []
	for e in _shown:
		out.append(_label_text(e))
	return out

## How many lines are waiting for a free row.
func waiting() -> int:
	return _waiting.size()

## The cards on show, top to bottom, in screen px.
func rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for e in _shown:
		out.append((e["box"] as Control).get_rect())
	return out

## Where the column ends now (its top when nothing shows).
func bottom() -> float:
	return top if _shown.is_empty() else (_shown.back()["box"] as Control).get_rect().end.y

## Fades a world label (a lair's name board, a farm marker) while any of `rects` covers it on screen.
static func yield_label(lbl: Label3D, cam: Camera3D, rects: Array[Rect2], delta: float) -> void:
	var want := 0.0
	if not rects.is_empty() and lbl.is_visible_in_tree() and not cam.is_position_behind(lbl.global_position):
		var mine := label_rect(lbl, cam)
		for r in rects:
			if r.intersects(mine):
				want = 1.0
	if lbl.transparency == want:
		return
	lbl.transparency = move_toward(lbl.transparency, want, delta * 6.0)
	lbl.modulate.a = 1.0 - lbl.transparency            # (the outline ignores transparency on some renderers)
	lbl.outline_modulate.a = 1.0 - lbl.transparency

## A billboarded Label3D's box on screen, in px, from its text and font (centred on its position).
static func label_rect(lbl: Label3D, cam: Camera3D) -> Rect2:
	var f: Font = lbl.font if lbl.font else ThemeDB.fallback_font
	var wrap_px := lbl.width if lbl.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0
	var px := f.get_multiline_string_size(lbl.text, HORIZONTAL_ALIGNMENT_CENTER, wrap_px, lbl.font_size)
	var half := px * lbl.pixel_size * lbl.global_basis.get_scale().x * 0.5
	var b := cam.global_basis
	var o := lbl.global_position
	var a := cam.unproject_position(o - b.x * half.x + b.y * half.y)
	var c := cam.unproject_position(o + b.x * half.x - b.y * half.y)
	return Rect2(a, c - a).abs()

func _process(delta: float) -> void:
	if _shown.is_empty() and _waiting.is_empty():
		return
	for i in range(_shown.size() - 1, -1, -1):
		var e: Dictionary = _shown[i]
		e["t"] = float(e["t"]) + delta
		if float(e["t"]) >= float(e["life"]):
			(e["box"] as Control).queue_free()
			_shown.remove_at(i)
	for i in range(_waiting.size() - 1, -1, -1):
		var w: Dictionary = _waiting[i]
		w["wait"] = float(w["wait"]) + delta
		if int(w["prio"]) == LOW and float(w["wait"]) > STALE:
			_waiting.remove_at(i)
	_promote()
	_layout(delta)

## Moves waiting lines onto free rows, the most important first (oldest first within a priority).
func _promote() -> void:
	while not hold and not _waiting.is_empty() and _shown.size() < maxi(1, MAX_SHOWN - reserved):
		var best := 0
		for i in _waiting.size():
			if int(_waiting[i]["prio"]) > int(_waiting[best]["prio"]):
				best = i
		var e: Dictionary = _waiting.pop_at(best)
		e["box"] = _card(e)
		add_child(e["box"])
		_shown.append(e)
		_layout(0.0)

## Stacks the cards down the column. A card slides up into a freed row, never past the one above.
func _layout(delta: float) -> void:
	var want := top
	var above := -INF
	var k := 1.0 - exp(-CLOSE_UP * delta)
	for e in _shown:
		var box: Control = e["box"]
		box.reset_size()
		var x := (size.x - box.size.x) * 0.5 if right_edge <= 0.0 else right_edge - box.size.x
		var y := want if not e.has("placed") else lerpf(box.position.y, want, k)
		e["placed"] = true
		y = maxf(y, above + GAP)
		box.position = Vector2(x, y)
		above = y + box.size.y
		want += box.size.y + GAP
		var t := float(e["t"])
		box.modulate.a = clampf(t / FADE_IN, 0.0, 1.0) * clampf((float(e["life"]) - t) / FADE_OUT, 0.0, 1.0)

## One card: the menu's glass with a line in the message's colour.
func _card(e: Dictionary) -> PanelContainer:
	var px: int = PX[int(e["prio"])]
	var c := UI.glass(8, UI.R_CARD)
	var f := c.get_theme_stylebox("panel") as UiFrame
	f.edge = Color(e["col"], 0.35)
	f.padded(12, 3)
	var l := UI.label(_label_text(e), px, e["col"], UI.big)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.08, 0.6))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART      # a long line wraps at a sane width, never word by word
	_fit(l, px)
	c.add_child(l)
	c.modulate.a = 0.0
	return c

func _bump(e: Dictionary) -> void:
	e["n"] = int(e["n"]) + 1
	if e.has("box"):
		var l := (e["box"] as Control).get_child(0) as Label
		l.text = _label_text(e)
		_fit(l, PX[int(e["prio"])])

## The label as wide as its line, up to WIDE of the screen (past that it wraps).
func _fit(l: Label, px: int) -> void:
	var natural := UI.big.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var widest := get_viewport_rect().size.x * WIDE if is_inside_tree() else 600.0
	l.custom_minimum_size.x = minf(natural + 2.0, widest)

func _label_text(e: Dictionary) -> String:
	return String(e["text"]) if int(e["n"]) < 2 else "%s  x%d" % [e["text"], e["n"]]

## The waiting line to drop when too many wait: the oldest of the lowest priority.
func _lowest() -> int:
	var out := 0
	for i in _waiting.size():
		if int(_waiting[i]["prio"]) < int(_waiting[out]["prio"]):
			out = i
	return out
