class_name KnockCallout
extends Control
## The big moment when YOU knock or eliminate a rival (hero-ref/HUD.md 5): "KNOCKED <name>" or
## "ELIMINATED <name>" above the crosshair for about a second. Quick knocks stack as lines, the
## oldest going first. Transient only, nothing stays on screen. The sound is Juice's own
## knock_confirm / kill; this adds none. One lives on the HUD (`of`), made on the first call.

const LIFE := 1.0           # s a line is on screen, fades included
const POP := 0.12           # s a new line takes to settle from POP_SCALE to 1
const POP_SCALE := 1.3
const FADE_OUT := 0.25      # s
const MAX_LINES := 3        # knocks on screen at once; a fourth pushes the oldest off
const TOP := 0.3            # of the screen height: where the first line sits (under the message lane)
const WORD_PX := 0.045      # of the screen height: the KNOCKED / ELIMINATED word
const NAME_PX := 0.032      # of the screen height: the name
const GAP := 0.012          # of the screen height: between two lines
const NAME_MAX := 16        # characters of a name that are shown
const KNOCK_COL := Color("ff5fb0")      # knocked: the pink-magenta accent of HUD.md
const OUTLINE := Color(0.03, 0.02, 0.05, 0.95)

var lines: Array[Dictionary] = []       # {"word", "name", "col", "t"}: what is on screen now
var _font: Font = preload("res://fonts/LilitaOne-Regular.ttf")

## "knock" or "out" of `victim`, for the HUD of `m` (nothing if the match has none). `confirm`
## also plays the confirm sound (knock_confirm / kill): the online client's events, where Juice doesn't run.
static func say(m: Match, kind: String, victim: Hunter, confirm := false) -> void:
	if m == null or victim == null:
		return
	if confirm:
		m.sfx("knock_confirm" if kind == "knock" else "kill", null, -6.0 if kind == "knock" else -3.0)
	if m.hud == null:
		return
	var host: Node = m.hud
	var callout: KnockCallout = null
	for ch in host.get_children():
		if ch is KnockCallout:
			callout = ch
	if callout == null:
		callout = KnockCallout.new()
		host.add_child(callout)
	callout.push("KNOCKED" if kind == "knock" else "ELIMINATED", victim.pname.left(NAME_MAX),
		KNOCK_COL if kind == "knock" else HudStyle.FOE)

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func push(word: String, victim_name: String, col: Color) -> void:
	lines.append({"word": word, "name": victim_name, "col": col, "t": 0.0})
	if lines.size() > MAX_LINES:
		lines.pop_front()
	queue_redraw()

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if lines.is_empty():
		return
	for e in lines:
		e["t"] = float(e["t"]) + delta
	lines = lines.filter(func(e): return float(e["t"]) < LIFE)
	queue_redraw()

func _draw() -> void:
	var step := size.y * (WORD_PX + GAP)
	for i in lines.size():
		var e: Dictionary = lines[i]
		var t := float(e["t"])
		var fade := clampf((LIFE - t) / FADE_OUT, 0.0, 1.0)
		var pop := lerpf(POP_SCALE, 1.0, clampf(t / POP, 0.0, 1.0))
		_draw_line(e, Vector2(size.x * 0.5, size.y * TOP + step * i), pop, fade)

## One line centred on `mid`: the word in its colour, the name after it in ink.
func _draw_line(e: Dictionary, mid: Vector2, pop: float, fade: float) -> void:
	var word_px := int(size.y * WORD_PX)
	var name_px := int(size.y * NAME_PX)
	var gap := float(word_px) * 0.4
	var word_w := _font.get_string_size(e["word"], HORIZONTAL_ALIGNMENT_LEFT, -1, word_px).x
	var name_w := _font.get_string_size(e["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, name_px).x
	var x0 := -(word_w + gap + name_w) * 0.5
	draw_set_transform(mid, 0.0, Vector2(pop, pop))
	var col: Color = e["col"]
	_text(e["word"], Vector2(x0, 0), word_px, Color(col, fade))
	_text(e["name"], Vector2(x0 + word_w + gap, 0), name_px, Color(HudStyle.INK, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _text(s: String, at: Vector2, px: int, col: Color) -> void:
	draw_string_outline(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, px / 4, Color(OUTLINE, col.a))
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
