class_name NoticeQueue
extends Control
## The one notice queue of a match: every banner and toast (region names, kit status, truce and drop calls,
## level-ups, pickups, a stolen Boki) goes through it. One banner is on screen at a time, in a fixed
## band at the top, inside the safe area and clear of the reticle. The rest wait, the most important
## first (PICKUP < REGION < SQUAD < CALL < CRITICAL). A higher one cuts a lower banner short, a waiting
## one that outlives its STALE is dropped as old news, and a banner with a `short` form shows that
## when others are waiting behind it.

enum { PICKUP, REGION, SQUAD, CALL, CRITICAL }
const LIFE := [1.8, 2.6, 2.4, 3.2, 3.6]     # s on show per priority, fades included
const STALE := [1.5, 5.0, 8.0, 10.0, -1.0]   # s a waiting notice keeps before it is dropped (-1: never)
const PX := [15, 17, 17, 20, 22]            # font px per priority
const MIN_SHOW := 0.9                       # s a banner stays before a higher one may cut it short
const SHORT_LIFE := 0.7                     # of its life, a shortened banner stays
const WAIT_CAP := 8                         # notices waiting at most: past it the oldest of the lowest goes
const FADE_IN := 0.15                       # s
const FADE_OUT := 0.35                      # s
const SAFE := 0.05                          # of the screen on each side that no banner enters
const BAND_W := 0.5                         # of the screen width: the widest a banner gets
const BAND_H := 84.0                        # px: two lines at the biggest size and its padding
const ZONE_W := 0.4                         # of the screen height: the reticle zone's width
const ZONE_H := 0.3                         # of the screen height: the reticle zone's height
const ZONE_GAP := 8.0                       # px kept between the band and the reticle zone
const MAX_LINES := 2

var band := Rect2(0, 84, 640, BAND_H)       ## where the banner sits (the HUD sets it each frame)
var hold := false:                          ## true: nothing new comes in (the tutorial banner has the floor)
	set(v):
		hold = v
		_promote()
var _cur := {}
var _box: PanelContainer
var _waiting: Array[Dictionary] = []
var _fit_w := -1.0

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## The band for a screen of `sz`, its top at `top` but never into the safe margin or the reticle zone.
static func band_for(sz: Vector2, top: float) -> Rect2:
	var w := minf(sz.x * BAND_W, sz.x * (1.0 - 2.0 * SAFE))
	var y := clampf(top, sz.y * SAFE, reticle_zone(sz).position.y - ZONE_GAP - BAND_H)
	return Rect2(Vector2((sz.x - w) * 0.5, y), Vector2(w, BAND_H))

## The middle of the screen where the reticle and the fight are: no banner enters it.
static func reticle_zone(sz: Vector2) -> Rect2:
	var zs := Vector2(sz.y * ZONE_W, sz.y * ZONE_H)
	return Rect2((sz - zs) * 0.5, zs)

## Queues a notice. `short` is what shows instead when others wait behind it; `life` 0 uses the priority's.
func push(text: String, col: Color, prio := SQUAD, short := "", life := 0.0) -> void:
	if text == "":
		return
	if _cur.get("text", "") == text:
		_bump(_cur)
		_cur["t"] = minf(float(_cur["t"]), FADE_IN)       # a repeat starts its time again
		return
	for e in _waiting:
		if e["text"] == text:
			_bump(e)
			return
	_waiting.append({"text": text, "short": short, "col": col, "prio": prio, "n": 1, "t": 0.0, "wait": 0.0,
		"life": life if life > 0.0 else float(LIFE[prio])})
	if _waiting.size() > WAIT_CAP:
		_waiting.remove_at(_lowest())
	_promote()

## Removes the banner and everything waiting.
func clear() -> void:
	_drop_cur()
	_waiting.clear()

## The banner on show plus the notices waiting.
func count() -> int:
	return _waiting.size() + (0 if _cur.is_empty() else 1)

## The banner on show now, as it reads (none: empty).
func texts() -> Array[String]:
	var out: Array[String] = []
	if not _cur.is_empty():
		out.append(_label_text(_cur))
	return out

## How many notices are waiting.
func waiting() -> int:
	return _waiting.size()

## The banner on show, in screen px (none: empty).
func rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not _cur.is_empty():
		out.append(_box.get_rect())
	return out

## Where the banner ends now (the band's top when nothing shows).
func bottom() -> float:
	return band.position.y if _cur.is_empty() else _box.get_rect().end.y

func _process(delta: float) -> void:
	if _cur.is_empty() and _waiting.is_empty():
		return
	for i in range(_waiting.size() - 1, -1, -1):
		var w: Dictionary = _waiting[i]
		w["wait"] = float(w["wait"]) + delta
		var stale: float = STALE[int(w["prio"])]
		if stale >= 0.0 and float(w["wait"]) > stale:
			_waiting.remove_at(i)
	if not _cur.is_empty():
		_cur["t"] = float(_cur["t"]) + delta
		_cut_short()
		if float(_cur["t"]) >= float(_cur["life"]):
			_drop_cur()
	_promote()
	if not _cur.is_empty():
		_place()

## Puts the best waiting notice on show when none is.
func _promote() -> void:
	if _cur.is_empty() and not hold and not _waiting.is_empty():
		_show(_waiting.pop_at(_best()))

## A higher notice waiting cuts the banner on show short, once it has had its MIN_SHOW.
func _cut_short() -> void:
	if _waiting.is_empty() or float(_cur["t"]) < MIN_SHOW:
		return
	if int(_waiting[_best()]["prio"]) > int(_cur["prio"]):
		_cur["life"] = minf(float(_cur["life"]), float(_cur["t"]) + FADE_OUT)

func _show(e: Dictionary) -> void:
	if e["short"] != "" and not _waiting.is_empty():
		e["text"] = e["short"]
		e["life"] = float(e["life"]) * SHORT_LIFE
	_cur = e
	_box = _card(e)
	add_child(_box)
	_fit_w = -1.0
	Sfx.play("ui_toast", null, -4.0, 0.03)
	_place()

func _drop_cur() -> void:
	if _box:
		_box.queue_free()
	_box = null
	_cur = {}

## The banner centred in the band, fading in and out.
func _place() -> void:
	if _fit_w != band.size.x:
		_fit_w = band.size.x
		_fit(_box.get_child(0) as Label, PX[int(_cur["prio"])])
		_box.reset_size()
	_box.position = band.position + Vector2((band.size.x - _box.size.x) * 0.5, 0.0)
	var t := float(_cur["t"])
	_box.modulate.a = clampf(t / FADE_IN, 0.0, 1.0) * clampf((float(_cur["life"]) - t) / FADE_OUT, 0.0, 1.0)

## One banner: the menu's glass with a line in the notice's colour, at most MAX_LINES tall.
func _card(e: Dictionary) -> PanelContainer:
	var c := UI.glass(8, UI.R_CARD)
	var f := c.get_theme_stylebox("panel") as UiFrame
	f.edge = Color(e["col"], 0.35)
	f.padded(12, 3)
	var l := UI.label(_label_text(e), PX[int(e["prio"])], e["col"], UI.big)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.08, 0.6))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = MAX_LINES
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.add_child(l)
	c.modulate.a = 0.0
	return c

func _bump(e: Dictionary) -> void:
	e["n"] = int(e["n"]) + 1
	if e == _cur:
		(_box.get_child(0) as Label).text = _label_text(e)
		_fit_w = -1.0

## The label as wide as its line, up to the band (past that it wraps).
func _fit(l: Label, px: int) -> void:
	var natural := UI.big.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	l.custom_minimum_size.x = minf(natural + 2.0, band.size.x - 28.0)

func _label_text(e: Dictionary) -> String:
	return String(e["text"]) if int(e["n"]) < 2 else "%s  x%d" % [e["text"], e["n"]]

## The waiting notice to show next: the most important, the oldest within a priority.
func _best() -> int:
	var best := 0
	for i in _waiting.size():
		if int(_waiting[i]["prio"]) > int(_waiting[best]["prio"]):
			best = i
	return best

## The waiting notice to drop when too many wait: the oldest of the lowest priority.
func _lowest() -> int:
	var out := 0
	for i in _waiting.size():
		if int(_waiting[i]["prio"]) < int(_waiting[out]["prio"]):
			out = i
	return out
