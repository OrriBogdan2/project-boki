class_name TutorialStrip
extends RefCounted
## The one objective banner of every tutorial (match steps, the first-match guide, the farm steps): a slim
## one-line strip at the top-centre, inside the title-safe margin, never taller than HEIGHT_FRAC of the
## screen. It glows softly and pulses for PULSE_T when the objective changes, then calms to a steady rim.
## The match HUD draws it on its canvas (TutorialHud); the farm adds a StripView Control (FarmGuide).
## Both call paint() with the same numbers, so the two look the same.

const MINT := Color("8fe3c8")
const GOLD := Color("f2c84a")
const PANEL := Color(0.03, 0.04, 0.07, 0.94)
const HEIGHT_FRAC := 0.06       # of the screen height: the tallest the strip gets
const WIDTH_FRAC := 0.42        # of the screen width: the widest it gets (the message lane starts at 0.72)
const SAFE_FRAC := 0.04         # the title-safe margin (PrematchView.SAFE_FRAC), of the height
const SAFE_MIN := 24.0          # px, the least margin at any size
const PULSE_T := 1.6            # s the glow and the pulse take to calm after the objective changes
const PULSE_HZ := 2.5           # beats a second while it pulses
const POP_T := 0.25             # s the strip takes to drop in on a new objective
const GLOW_PX := 10.0           # how far the soft glow reaches past the rim at its brightest

const REST_GLOW := 0.45         # the glow a settled "steady" line (the match HUD) keeps, so it never goes quiet
const BREATHE := 0.08           # how far the steady glow breathes up and down
const BREATHE_HZ := 0.5         # breaths a second
const KEY_FACE := Color(0.93, 0.95, 0.98)
const KEY_INK := Color(0.06, 0.08, 0.12)

static var _runs_of := ""       # the line and key cap _runs was split for
static var _runs_cache: Array = []

const GAP := 8.0                # px kept under whatever already sits at the top-centre (`below`)

## Where the strip sits for a screen size: under the safe margin, and under `below` (the bottom of the
## Ways Out strip in a real match, WaysOutHud.bottom) when that is lower, so it never covers the zone clocks.
static func rect(sz: Vector2, below := 0.0) -> Rect2:
	var w := sz.x * WIDTH_FRAC
	var top := maxf(maxf(SAFE_MIN, sz.y * SAFE_FRAC), below + GAP if below > 0.0 else 0.0)
	return Rect2(Vector2((sz.x - w) * 0.5, top), Vector2(w, sz.y * HEIGHT_FRAC))

## 1 the moment the objective changes, easing to 0 over PULSE_T.
static func glow(age: float) -> float:
	return 1.0 - clampf(age / PULSE_T, 0.0, 1.0)

## How lit the rim is (0..1). A "steady" line (the match HUD, which redraws every frame) starts at full glow,
## settles over PULSE_T to a slow breathing REST_GLOW and flares to `flare` (a stall's pulse); any other line
## only pulses for PULSE_T after a new objective and is calm after.
static func lit_at(age: float, steady := false, flare := 0.0) -> float:
	var g := glow(age)
	if not steady:
		return g * (0.55 + 0.45 * (0.5 + 0.5 * sin(age * TAU * PULSE_HZ))) if g > 0.0 else 0.0
	var rest := REST_GLOW + BREATHE * sin(Time.get_ticks_msec() / 1000.0 * TAU * BREATHE_HZ)
	return maxf(maxf(g, rest), flare)

## The strip's rect this frame: dropping in from above for POP_T, then still.
static func shown(sz: Vector2, age: float, below := 0.0) -> Rect2:
	var r := rect(sz, below)
	var k := clampf(age / POP_T, 0.0, 1.0)
	r.position.y -= pow(1.0 - k, 3.0) * (r.end.y + 4.0)
	return r

## Draws the strip on any CanvasItem. `line` has: text, key_cap, count ("1/3" or ""), dist ("12m" or "") and
## dir (a Vector2 for the arrow, ZERO for none). `age` is the seconds since the objective changed;
## `alpha` fades the whole strip.
static func paint(ci: CanvasItem, font: Font, r: Rect2, line: Dictionary, age: float, alpha := 1.0) -> void:
	var lit := lit_at(age, bool(line.get("steady", false)), float(line.get("flare", 0.0)))
	# soft glow: a few wide rims fading outward, only while it is lit
	for i in 3:
		var grow := GLOW_PX * lit * float(3 - i) / 3.0
		if grow > 0.5:
			var halo := _box(Color(MINT, 0.07 * lit * alpha), r.size.y * 0.5 + grow, Color(0, 0, 0, 0), 0)
			ci.draw_style_box(halo, r.grow(grow))
	var rim := Color(MINT, (0.5 + 0.5 * lit) * alpha)
	ci.draw_style_box(_box(Color(PANEL, PANEL.a * alpha), r.size.y * 0.5, rim, int(2.0 + 1.5 * lit)), r)
	var mid := r.get_center().y
	var px := int(r.size.y * 0.5)
	var left := r.position.x + r.size.y * 0.5
	var right := r.end.x - r.size.y * 0.5
	var count := String(line.get("count", ""))
	var dist := String(line.get("dist", ""))
	var tail := (dist + "  " + count).strip_edges()
	if tail != "":
		var tw := font.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		_text(ci, font, Vector2(right - tw, mid + px * 0.36), tail, px, Color(MINT, alpha))
		right -= tw + 10.0
	var dir: Vector2 = line.get("dir", Vector2.ZERO)
	if dir != Vector2.ZERO:
		right = _arrow(ci, Vector2(right, mid), r.size.y, dir, alpha) - 8.0
	var runs := _runs(String(line.get("text", "")), String(line.get("key_cap", "")), line.get("keys", []))
	var tpx := px
	while tpx > 12 and _runs_w(font, runs, tpx) > right - left:
		tpx -= 1
	var x := left
	for run in runs:
		var w := String(run[0])
		if run[1]:
			var cw := _cap_w(font, w, tpx)
			var ch := minf(r.size.y * 0.7, tpx * 1.3)
			var cap := Rect2(Vector2(x, mid - ch * 0.5), Vector2(cw, ch))
			ci.draw_style_box(_box(Color(KEY_FACE, alpha), 8, Color(0, 0, 0, 0), 0), cap)
			var kw := font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x
			_text(ci, font, Vector2(x + (cw - kw) * 0.5, mid + tpx * 0.36), w, tpx, Color(KEY_INK, alpha), false)
			x += cw + tpx * 0.3
		else:
			_text(ci, font, Vector2(x, mid + tpx * 0.36), w, tpx, Color(GOLD, alpha))
			x += font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x + tpx * 0.3

## The line as runs of [text, is_key]: a word that is one of `keys` (or the step's key cap) is a key-cap run of
## its own; the step's key cap leads the line when the line doesn't name it. Split again only when the line changes.
static func _runs(text: String, cap: String, keys: Array) -> Array:
	var id := text + "|" + cap + "|" + ",".join(keys)
	if _runs_of == id:
		return _runs_cache
	_runs_of = id
	var named := cap == ""
	var all: Array = keys.duplicate()
	if cap != "":
		all.append(cap)
	_runs_cache = []
	var words := ""
	for w in text.split(" "):
		var core := w.rstrip(",.:;!?")
		if core != "" and core in all:
			named = named or core == cap
			if words != "":
				_runs_cache.append([words, false])
			_runs_cache.append([core, true])
			words = w.substr(core.length())
		else:
			words += (" " if words != "" else "") + w
	if words.strip_edges() != "":
		_runs_cache.append([words, false])
	if not named:
		_runs_cache.push_front([cap, true])
	return _runs_cache

static func _cap_w(font: Font, key: String, px: int) -> float:
	return maxf(px * 1.4, font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + px * 0.6)

static func _runs_w(font: Font, runs: Array, px: int) -> float:
	var w := 0.0
	for run in runs:
		var rw := font.get_string_size(run[0], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		w += (_cap_w(font, run[0], px) if run[1] else rw) + px * 0.3
	return w - px * 0.3

## The way-to-go arrow ending at `end` (right edge, row middle); returns the x where it starts.
static func _arrow(ci: CanvasItem, end: Vector2, row: float, dir: Vector2, alpha: float) -> float:
	var s := row * 0.2
	var at := Vector2(end.x - s * 1.4, end.y)
	var perp := Vector2(-dir.y, dir.x)
	ci.draw_circle(at, s * 1.25, Color(MINT, 0.18 * alpha))
	ci.draw_colored_polygon(PackedVector2Array([at + dir * s, at - dir * s * 0.6 + perp * s * 0.75,
		at - dir * s * 0.6 - perp * s * 0.75]), Color(MINT, alpha))
	return at.x - s * 1.25

static func _box(col: Color, rad: float, border: Color, bw: int) -> StyleBoxFlat:
	return HudStyle.box(col, int(rad), border, bw)

static func _text(ci: CanvasItem, font: Font, p: Vector2, s: String, px: int, col: Color, outline := true) -> void:
	if outline:
		ci.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 4, Color(0, 0, 0, 0.55 * col.a))
	ci.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
