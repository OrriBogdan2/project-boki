class_name KnockBanner
extends Control
## The banner top-centre when a knock matters to you: ALLY KNOCKED (a teammate went down) or KNOCK (your
## squad knocked a rival). The knocked hunter's round portrait in a thick ring over an ink slash, an X on
## top, the word in bold italic and their name on a dark pill. The slash and pill are see-through
## (back_alpha); the banner sits on whole pixels and its words are drawn at their real size, never scaled.
## It pops in, holds, then fades and rises away (show_s in all). A new knock replaces it at once;
## another of the same kind within combo_s counts up ("x2") instead. Each kind has its sound: a low
## warning for a teammate, a hit sting for a rival.
## Match.knock (through Juice.knock) and a knock from the network call knocked(). A full-screen Control
## over the HUD's canvas (so the whole banner, portrait included, fades with `modulate`).
## Numbers: content/rules/knock_banner.json.

const RULES_PATH := "res://content/rules/knock_banner.json"
const ALLY_WORD := "ALLY KNOCKED"
const FOE_WORD := "KNOCK"
const ALLY_RING := Color("3fc8ff")       # a teammate's ring and slash (cyan)
const ALLY_EDGE := Color("1d4fd0")       # the outline of the white ALLY KNOCKED
const ALLY_X := Color("ff4f92")          # the pink X over a teammate's portrait
const FOE_RING := Color("ff3a6a")        # a rival's ring, slash and word (hot pink-red)
const INK_EDGE := Color(0.02, 0.02, 0.05, 0.85)   # the dark line around ring, X and word
const PILL := Color(0.04, 0.05, 0.08)   # the name pill (its alpha is back_alpha)
const FACE_R := 36.0                     # px: the portrait's half size (the ring's outside is 96 px across)
const RING_W := 13.0                     # px: wide enough to cover the portrait's rounded corners
const X_R := 9.0                         # px: half the X over the portrait
const WORD_PX := 34
const NAME_PX := 14
const COUNT_PX := 20
const BLADE_STEPS := 16                  # points down each side of a slash blade (smooth at 1080p)

static var _rules := {}

var kind := ""        # "" nothing on show, "ally" or "foe"
var who: Hunter = null
var count := 1        # knocks of this kind in a quick run (x2 ...)
var t := 0.0          # s since this banner opened
var _top := -1.0      # px: where the banner sits, fixed when it opens (-1: not placed yet)
var _hud: Node        # the match HUD (hud.gd): its message lane and its rendered portraits
# the ink slash behind the portrait, px from its centre: a bright blade low left to high right on a dark one
var _slash := _blade(Vector2(-100, 34), Vector2(104, -44), -8.0, 30.0)
var _slash_dark := _blade(Vector2(-78, 50), Vector2(88, -16), -6.0, 22.0)

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func _ready() -> void:
	_hud = get_parent()

## Ages the banner; it closes after show_s.
func _process(delta: float) -> void:
	t += delta
	var r := rules()
	if t >= float(r["show_s"]) or not is_instance_valid(who):
		kind = ""
		who = null
		set_process(false)
	modulate.a = _fade() * clampf(t / (float(r["pop_s"]) * 0.5), 0.0, 1.0)
	queue_redraw()

## Draws the banner on show, under any toasts that were up when it opened (but never lower than max_top_frac).
func _draw() -> void:
	if kind == "":
		return
	var r := rules()
	if _top < 0.0:
		var under_toasts := maxf(size.y * float(r["top_frac"]), _hud.msgs.bottom() + 8.0)
		_top = minf(under_toasts, size.y * float(r["max_top_frac"]))
	var centre := Vector2(size.x * 0.5, _top + FACE_R + RING_W - float(r["rise_px"]) * (1.0 - _fade())).round()
	var s := _scale(r)
	draw_set_transform(centre, 0.0, Vector2.ONE * s)
	_draw_face(float(r["back_alpha"]))
	draw_set_transform(Vector2.ZERO)
	_draw_words(centre, s, float(r["back_alpha"]))

## The banner numbers (content/rules/knock_banner.json), read once.
static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _rules

## Hunter `h` was knocked by `credit`: a banner (and its sound) if they are `viewer`'s teammate, or a
## rival `viewer`'s squad knocked. Nothing for the viewer's own knock (the killcam line says it).
func knocked(viewer: Hunter, h: Hunter, credit: Ent) -> void:
	if viewer == null or h == viewer:
		return
	var now := ""
	if h.team == viewer.team:
		now = "ally"
	elif credit is Hunter and (credit as Hunter).team == viewer.team:
		now = "foe"
	if now == "":
		return
	var quick := kind == now and t < float(rules()["combo_s"])
	count = count + 1 if quick else 1
	kind = now
	who = h
	t = 0.0
	_top = -1.0
	set_process(true)
	queue_redraw()
	if now == "ally":
		Sfx.play("warn", null, -4.0, 0.0, 0.8)
	else:
		Sfx.play("knock_confirm", null, -6.0)

## The word on show ("" when no banner is up).
func word() -> String:
	if kind == "":
		return ""
	return ALLY_WORD if kind == "ally" else FOE_WORD

## The ring colour of the banner on show.
func ring_color() -> Color:
	return ALLY_RING if kind == "ally" else FOE_RING

## 1 while the banner holds, down to 0 over its last fade_s.
func _fade() -> float:
	var r := rules()
	return clampf((float(r["show_s"]) - t) / float(r["fade_s"]), 0.0, 1.0)

## The pop: from pop_scale down to just under 1 in pop_s, then back up to 1 over settle_s.
func _scale(r: Dictionary) -> float:
	var pop := float(r["pop_s"])
	var low := 1.0 - float(r["punch"])
	if t < pop:
		return lerpf(float(r["pop_scale"]), low, ease(t / pop, 0.4))
	return lerpf(low, 1.0, clampf((t - pop) / float(r["settle_s"]), 0.0, 1.0))

## A slash blade from `a` to `b`, bowed `bow` px sideways at its middle, `w` px thick at its widest (near
## the tail), sharp at both ends.
static func _blade(a: Vector2, b: Vector2, bow: float, w: float) -> PackedVector2Array:
	var side := (b - a).orthogonal().normalized()
	var top := PackedVector2Array([a])
	var low := PackedVector2Array()
	for i in range(1, BLADE_STEPS):
		var f := float(i) / BLADE_STEPS
		var mid := a.lerp(b, f) + side * bow * 4.0 * f * (1.0 - f)
		var half := side * w * 0.5 * sin(PI * pow(f, 0.6))
		top.append(mid + half)
		low.append(mid - half)
	top.append(b)
	low.reverse()
	return top + low

## A filled shape with a smooth (anti-aliased) rim: polygons alone draw jagged edges.
func _smooth_polygon(pts: PackedVector2Array, col: Color) -> void:
	draw_colored_polygon(pts, col)
	var rim := pts.duplicate()
	rim.append(pts[0])
	draw_polyline(rim, col, 1.0, true)

## The see-through slash, the portrait in its ring and the X over it, around (0, 0).
func _draw_face(back_alpha: float) -> void:
	var ring := ring_color()
	_smooth_polygon(_slash_dark, Color(ring.darkened(0.55), back_alpha))
	_smooth_polygon(_slash, Color(ring, back_alpha))
	var ak := Portraits.arch_of(who)
	var fallback: Texture2D = null if Portraits.has_art(ak) else _hud.portrait(who)
	var face := Rect2(Vector2(-FACE_R, -FACE_R), Vector2(FACE_R, FACE_R) * 2.0)
	Portraits.draw(self, face, ak, fallback, ring)
	draw_arc(Vector2.ZERO, FACE_R + RING_W * 0.5, 0.0, TAU, 96, ring, RING_W + 1.0, true)
	draw_arc(Vector2.ZERO, FACE_R + RING_W + 1.0, 0.0, TAU, 96, INK_EDGE, 3.0, true)
	var x_col := ALLY_X if kind == "ally" else Color.WHITE
	var at := Vector2(0.0, -FACE_R - RING_W * 0.5)
	for d in [Vector2(1, 1), Vector2(1, -1)]:
		draw_line(at - d * X_R, at + d * X_R, INK_EDGE, 8.0, true)
	for d in [Vector2(1, 1), Vector2(1, -1)]:
		draw_line(at - d * X_R, at + d * X_R, x_col, 4.5, true)

## The bold italic word (with the run count) and the see-through name pill under the portrait at `c`,
## scaled by the pop `s`: drawn at their real font size on whole pixels (a scaled glyph blurs).
func _draw_words(c: Vector2, s: float, back_alpha: float) -> void:
	var font := HudStyle.big_italic()
	var w := word()
	var px := roundi(WORD_PX * s)
	var y := roundf(c.y + (FACE_R + RING_W + WORD_PX + 2.0) * s)
	var at := Vector2(roundf(c.x - TextCache.width(font, w, px) * 0.5), y)
	var fill := Color.WHITE if kind == "ally" else FOE_RING
	var edge := ALLY_EDGE if kind == "ally" else Color.WHITE
	TextCache.draw(self, font, at, w, px, fill, roundi(10 * s), INK_EDGE)
	TextCache.draw(self, font, at, w, px, fill, roundi(5 * s), edge)
	if count > 1:
		var n_at := Vector2(roundf(2.0 * c.x - at.x + 6.0 * s), roundf(y - px * 0.45))
		TextCache.draw(self, font, n_at, "x%d" % count, roundi(COUNT_PX * s), HudStyle.GOLD, roundi(5 * s), INK_EDGE)
	var nm := who.pname.substr(0, 16)
	var name_px := roundi(NAME_PX * s)
	var nw := TextCache.width(HudStyle.BIG, nm, name_px)
	var pill := Rect2((Vector2(c.x - nw * 0.5, y) + Vector2(-12.0, 9.0) * s).round(),
		(Vector2(nw, 0.0) + Vector2(24.0, 22.0) * s).round())
	draw_style_box(HudStyle.box(Color(PILL, back_alpha), 11, Color(1, 1, 1, 0.12), 1), pill)
	var name_at := Vector2(roundf(c.x - nw * 0.5), pill.end.y - roundf(6.0 * s))
	TextCache.draw(self, HudStyle.BIG, name_at, nm, name_px, HudStyle.INK, 3, INK_EDGE)
