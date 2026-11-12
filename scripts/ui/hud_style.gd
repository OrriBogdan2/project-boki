class_name HudStyle
extends RefCounted
## The in-match HUD's shared look: colour roles, fonts, sizes and the few primitives every widget
## draws with (segmented bars, plate and slot frames, key pills, outlined text). Overhead plates
## (HudPlate), the bottom-left vitals (HudVitals), the ability slots (HudSlot) and anything else on
## the match HUD use these so the whole bar reads as one family. Colours are roles, not hues: change
## a role here and every widget follows.
##
## Every draw takes the CanvasItem to draw on (the HUD's canvas, `hud.c`), so it works from any
## widget file without reaching into hud.gd.

# ------------------------------------------------------------------ colour roles
const INK := Color("f3eee2")              # main text
const MUTED := Color("a9b0bf")            # secondary text, empty things
const SHADE := Color(0.05, 0.03, 0.08, 0.86)    # frame backing behind bars and slots (void violet)
const SHADE_EDGE := Color(0.0, 0.0, 0.02, 0.95)  # segment gaps and outlines
const SELF := Color("a8f26e")             # your own health (lime)
const ALLY := Color("63c7ff")             # your squad's health (sky blue)
const FOE := Color("ff5a4a")              # rivals' health (coral red)
const LOW := Color("ffa13c")              # health shifts toward this as it runs low (yours and allies')
const DOWNED := Color("ffb36a")           # a downed hunter's bleed-out bar
const STOMPED := Color("ff3a2a")          # ... while someone is finishing them
const REVIVE := Color("8fe0a0")           # revive progress
const ARMOR := Color("9fdcff")            # armour when the hunter has no tier colour
const SHIELD := Color("eef8ff")           # shields: a pale fill past the end of health
const CHIP := Color("fff1dc")             # the chunk just lost, before it drains
const HEAL := Color("8ff0a0")             # healing numbers
const HIT := Color("fff4d6")              # your hits
const HIT_ARMOR := Color("7ac8ff")        # your hits that landed on armour
const CRIT := Color("ffd23f")             # critical hits
const CRIT_ARMOR := Color("b0e4ff")
const HURT := Color("ff6a5a")             # damage you take
const HURT_KIN := Color("ffa08a")         # damage your Boki takes
const GOLD := Color("ffd27a")             # levels, points to spend
const COOLING := Color("ff8f6b")          # a slot that isn't ready: its frame and short countdowns
const KEY_BG := Color(0.03, 0.04, 0.06, 0.95)
const FRAME := Color(0.02, 0.06, 0.1, 0.92)     # the leaning frames behind the vitals bars (near-black blue)
const XP := Color("d33efd")               # progress to your next run level
const RES := Color("ffb729")              # the class resource bar under it
const SHIELD_BAR := Color("7edaf0")       # a shield, as its own strip under health
const CD_TEXT := Color("ff3d6e")          # a slot's countdown while it cools
const RANK := Color("f4a3e6")             # a slot's rank badge

# ------------------------------------------------------------------ fonts
const BIG: Font = preload("res://fonts/LilitaOne-Regular.ttf")    # numbers, names, labels
const BODY: Font = preload("res://fonts/Rubik.ttf")               # sentences

# ------------------------------------------------------------------ sizes (px of the 1280x720 layout)
const LEAN_K := 0.5            # x shift per px down of every leaning frame and bar (vitals, squad rows)
const LEAN_TXT := -0.22        # x shear per px of leaning text (big numbers, state words)
const HP_PER_SEG := 25.0       # health per segment: a bigger pool shows more segments, not longer ones
const MAX_SEGS := 12           # more than this and each segment doubles (stays readable on huge pools)
const SEG_GAP := 2.0           # px between segments
const PLATE_W := 64.0          # overhead health bar width (rivals and allies; HUD_SPEC: ref 100 px of 2000)
const PLATE_W_SELF := 60.0     # your own overhead bar (ref 93 px of 2000)
const PLATE_HP_H := 8.0        # overhead health bar height
const PLATE_AR_H := 2.5        # overhead armour strip over it
const PLATE_SH_H := 2.0        # overhead shield strip under it
const PLATE_PAD := 1.5         # frame around the bars (and between them: 1 px)
const PLATE_MAX_SEGS := 7      # the plate's most segments (about 9 px each; a bigger pool shows no more)
const PLATE_TILE_W := 15.0     # a status tile at the bar's right end: width
const PLATE_TILE_H := 22.0     # ... and height (top level with the frame, hangs below it)
const PLATE_NAME_FS := 13
## Where the row of small icons under a plate starts, below the plate's anchor point (the
## loadout icons go here): the frame ends at plate_h(), then the dash pips.
const PLATE_ICON_ROW := 22.0
const SLOT_RAD := 4            # ability slot corner radius
const KEY_FS := 10             # key label size
const KEY_DROP := 14.0         # px from a slot's bottom edge down to its key label's centre

## A hunter's health colour as seen by `viewer`: you, your squad, or a rival.
static func role_col(viewer: Hunter, h: Hunter) -> Color:
	if viewer == null or h == viewer:
		return SELF
	return ALLY if h.team == viewer.team else FOE

## Health fill for a role at a fraction of max: yours and allies' warm toward LOW under half, and
## pulse under a third; rivals stay red (a low rival pulses brighter instead).
static func hp_fill(role: Color, frac: float, time: float) -> Color:
	var pulse := 0.5 + 0.5 * sin(time * 9.0)
	if role == FOE:
		return role.lerp(Color.WHITE, 0.25 * pulse) if frac < 0.3 else role
	var col := role.lerp(LOW, clampf((0.55 - frac) / 0.3, 0.0, 1.0))
	return col.lerp(Color.WHITE, 0.2 * pulse) if frac < 0.3 else col

## Health per segment for a pool this big (HP_PER_SEG, doubled until the count fits MAX_SEGS).
static func seg_step(maxv: float) -> float:
	var step := HP_PER_SEG
	while maxv / step > float(MAX_SEGS) + 0.01:
		step *= 2.0
	return step

static func seg_count(maxv: float) -> int:
	return maxi(1, int(ceil(maxv / seg_step(maxv) - 0.001)))

## A segmented bar in a handful of draws: the empty track, the chip (the part just lost), the fill,
## a top highlight, an optional shield past the end of the fill, then every gap in one multiline.
## `chip` and `shield` are fractions of max (chip <= frac draws nothing); `flash` 0..1 whitens it.
static func seg_bar(c: CanvasItem, r: Rect2, val: float, maxv: float, col: Color, chip := 0.0, shield := 0.0,
		flash := 0.0, step := -1.0) -> void:
	var f := clampf(val / maxf(1.0, maxv), 0.0, 1.0)
	c.draw_rect(r, Color(col.darkened(0.72), 0.92))
	if chip > f:
		var chip_w := r.size.x * (minf(chip, 1.0) - f)
		c.draw_rect(Rect2(r.position + Vector2(r.size.x * f, 0), Vector2(chip_w, r.size.y)), CHIP)
	if f > 0.0:
		c.draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), col)
		c.draw_rect(Rect2(r.position, Vector2(r.size.x * f, maxf(1.0, r.size.y * 0.3))), Color(1, 1, 1, 0.22))
	if shield > 0.0:
		# a shield adds on past health; what doesn't fit lies over the end of the bar
		var s := clampf(shield, 0.0, 1.0)
		var x0 := r.size.x * minf(f, 1.0 - s)
		c.draw_rect(Rect2(r.position + Vector2(x0, 0), Vector2(r.size.x * s, r.size.y)), Color(SHIELD, 0.88))
		c.draw_rect(Rect2(r.position + Vector2(x0, 0), Vector2(r.size.x * s, 1.0)), Color.WHITE)
	if flash > 0.0:
		c.draw_rect(r, Color(1, 1, 1, 0.55 * flash))
	var st := step if step > 0.0 else seg_step(maxv)
	var n := int(ceil(maxv / st - 0.001))
	if n > 1:
		var pts := PackedVector2Array()
		for i in range(1, n):
			var x := r.position.x + r.size.x * (float(i) * st / maxv)
			if x < r.end.x - 1.0:
				pts.append(Vector2(x, r.position.y))
				pts.append(Vector2(x, r.end.y))
		if pts.size() > 0:
			c.draw_multiline(pts, SHADE_EDGE, SEG_GAP)

## A plain (unsegmented) strip with its empty track: armour under health, XP, resources.
static func strip(c: CanvasItem, r: Rect2, frac: float, col: Color, back_a := 0.85) -> void:
	c.draw_rect(r, Color(col.darkened(0.75), back_a))
	if frac > 0.0:
		c.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)

## Height of a plate's leaning frame: armour strip, health, shield strip, 1 px between, a pad round.
static func plate_h() -> float:
	return PLATE_AR_H + PLATE_HP_H + PLATE_SH_H + 2.0 + PLATE_PAD * 2.0

## The dark leaning frame a plate's bars sit in: a hairline in the role colour (white while `flash`
## is up) round a dark backing. `at` is its top-left; `w` the bar width.
static func plate_frame(c: CanvasItem, at: Vector2, w: float, edge: Color, flash := 0.0) -> void:
	var w_all := w + PLATE_PAD * 2.0
	var h := plate_h()
	slant(c, at, w_all, h, edge.lerp(Color.WHITE, snappedf(flash, 0.25)))
	slant(c, at + Vector2(1.0 - LEAN_K, 1.0), w_all - 2.0, h - 2.0, SHADE)

## An ability or item slot's frame. `state`: "ready" (filled in the slot colour under a dark edge,
## a light top gloss), "cooling" (dark, a pink-red edge), "off" (dark, barely edged: locked, empty, or
## can't be used now).
static func slot_frame(c: CanvasItem, r: Rect2, col: Color, state := "ready") -> void:
	var bg := Color(0.04, 0.05, 0.08, 0.92)
	var edge := Color(0.75, 0.8, 1.0, 0.16)
	if state == "ready":
		bg = Color(col.darkened(0.5), 0.95)
		edge = Color(0.1, 0.13, 0.17, 0.95)
	elif state == "cooling":
		edge = Color(CD_TEXT.darkened(0.25), 0.9)
	c.draw_style_box(box(bg, SLOT_RAD, edge, 2), r)
	if state == "ready":
		var gloss := Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, r.size.y * 0.42))
		c.draw_style_box(box(Color(1, 1, 1, 0.12), SLOT_RAD - 1, Color(0, 0, 0, 0), 0), gloss)

## The key label under a slot: a dark rounded tab centred on `center`, the key in `col`.
static func key_pill(c: CanvasItem, center: Vector2, key: String, col: Color) -> void:
	var kw := BIG.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_FS).x
	var kr := Rect2(center - Vector2(maxf(kw * 0.5 + 4, 7), 6.5), Vector2(maxf(kw + 8, 14), 13))
	c.draw_style_box(box(KEY_BG, 3, Color(0, 0, 0, 0), 0), kr)
	var at := Vector2(center.x - kw * 0.5, kr.position.y + 10.5)
	c.draw_string(BIG, at, key, HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_FS, col)

## A parallelogram `w` wide and `h` tall whose top-left is `at`, its bottom LEAN_K * h further left.
static func slant(c: CanvasItem, at: Vector2, w: float, h: float, col: Color) -> void:
	if w <= 0.0:
		return
	c.draw_colored_polygon(slant_pts(at, w, h), col)

## The corners of that parallelogram, clockwise from the top-left.
static func slant_pts(at: Vector2, w: float, h: float) -> PackedVector2Array:
	var d := LEAN_K * h
	return PackedVector2Array([at, at + Vector2(w, 0), at + Vector2(w - d, h), at + Vector2(-d, h)])

## A leaning segmented bar (the vitals' armour and health): track, chip, fill, a lit top edge, then a
## leaning gap every `step` of `maxv`. `chip` is a fraction of max (<= the fill draws nothing).
static func slant_bar(c: CanvasItem, at: Vector2, w: float, h: float, val: float, maxv: float, col: Color,
		step: float, chip := 0.0) -> void:
	var f := clampf(val / maxf(1.0, maxv), 0.0, 1.0)
	slant(c, at, w, h, Color(col.darkened(0.78), 0.9))
	if chip > f:
		slant(c, at, w * minf(chip, 1.0), h, CHIP)
	slant(c, at, w * f, h, col)
	slant(c, at, w * f, maxf(1.0, h * 0.2), Color(1, 1, 1, 0.3))
	if step <= 0.0 or maxv <= step:
		return
	var pts := PackedVector2Array()
	var i := 1
	while i * step < maxv - step * 0.5:
		var x := at.x + w * (i * step / maxv)
		pts.append(Vector2(x, at.y))
		pts.append(Vector2(x - LEAN_K * h, at.y + h))
		i += 1
	c.draw_multiline(pts, SHADE_EDGE, SEG_GAP)

## A texture cut to a disc of radius `r` round `ctr` (round portraits).
static var _disc := PackedVector2Array()
static func round_tex(c: CanvasItem, ctr: Vector2, r: float, tex: Texture2D, tint := Color.WHITE) -> void:
	if _disc.is_empty():
		for i in 40:
			_disc.append(Vector2.from_angle(TAU * i / 40.0))
	var pts := PackedVector2Array()
	var uv := PackedVector2Array()
	for v in _disc:
		pts.append(ctr + v * r)
		uv.append(Vector2(0.5, 0.5) + v * 0.5)
	c.draw_colored_polygon(pts, tint, uv, tex)

## Outlined text leaning like the frames (LEAN_TXT), left-aligned at `p` (baseline).
static func lean_text(c: CanvasItem, p: Vector2, s: String, font_size: int, col: Color, ol := 4) -> void:
	c.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(LEAN_TXT, 1), p))
	text(c, Vector2.ZERO, s, font_size, col, ol)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

## Outlined text, left-aligned at `p` (baseline). `ol` is the outline width in px.
static func text(c: CanvasItem, p: Vector2, s: String, font_size: int, col: Color, ol := 4, font: Font = BIG) -> void:
	TextCache.draw(c, font, p, s, font_size, col, ol, Color(0, 0, 0, 0.6 * col.a))

## Outlined text centred on x at baseline `p.y`.
static func ctext(c: CanvasItem, p: Vector2, s: String, font_size: int, col: Color, ol := 4, font: Font = BIG) -> void:
	var w := TextCache.width(font, s, font_size)
	text(c, Vector2(p.x - w * 0.5, p.y), s, font_size, col, ol, font)

## Floating damage number colour: by who was hit and how (Match picks, Fx draws).
static func dmg_col(crit: bool, armor_hit: bool, on_you: bool, on_your_kin: bool) -> Color:
	if on_you: return HURT
	if on_your_kin: return HURT_KIN
	if crit: return CRIT_ARMOR if armor_hit else CRIT
	return HIT_ARMOR if armor_hit else HIT

# style boxes are made once per look and reused (dozens of frames are drawn every frame)
static var _boxes := {}
## A cached rounded style box (bg, corner radius, border colour and width): for widgets drawing their own shapes.
static func box(bg: Color, rad: int, border: Color, bw: int) -> StyleBoxFlat:
	var key := [bg, rad, border, bw]
	var sb: StyleBoxFlat = _boxes.get(key)
	if sb == null:
		if _boxes.size() > 256: _boxes.clear()
		sb = StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(rad)
		if bw > 0:
			sb.border_color = border
			sb.set_border_width_all(bw)
		sb.anti_aliasing = true
		_boxes[key] = sb
	return sb
