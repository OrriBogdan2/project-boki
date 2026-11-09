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
const SHADE := Color(0.03, 0.03, 0.05, 0.86)    # frame backing behind bars and slots
const SHADE_EDGE := Color(0.0, 0.0, 0.02, 0.95)  # segment gaps and outlines
const DOWNED := Color("ffb36a")           # a downed hunter's bleed-out bar
const STOMPED := Color("ff3a2a")          # ... while someone is finishing them
const ARMOR := Color("9fdcff")            # armour when the hunter has no tier colour
const SHIELD := Color("eef8ff")           # shields: a pale fill past the end of health
const CHIP := Color("fff1dc")             # the chunk just lost, before it drains
const HIT := Color("fff4d6")              # your hits
const HIT_ARMOR := Color("7ac8ff")        # your hits that landed on armour
const CRIT := Color("ffd23f")             # critical hits
const CRIT_ARMOR := Color("b0e4ff")
const HURT_KIN := Color("ffa08a")         # damage your Boki takes
const GOLD := Color("ffd27a")             # levels, points to spend
const COOLING := Color("ff8f6b")          # a slot that isn't ready: its frame and short countdowns
const KEY_BG := Color(0.04, 0.04, 0.06, 0.95)

# ------------------------------------------------------------------ fonts
const BIG: Font = preload("res://fonts/LilitaOne-Regular.ttf")    # numbers, names, labels
const BODY: Font = preload("res://fonts/Rubik.ttf")               # sentences

# ------------------------------------------------------------------ sizes (px at 1080p; the HUD is unscaled)
const HP_PER_SEG := 25.0       # health per segment: a bigger pool shows more segments, not longer ones
const MAX_SEGS := 12           # more than this and each segment doubles (stays readable on huge pools)
const SEG_GAP := 2.0           # px between segments
const PLATE_W := 100.0         # overhead health bar width (rivals and allies)
const PLATE_W_SELF := 108.0    # your own overhead bar
const PLATE_HP_H := 9.0        # overhead health bar height
const PLATE_AR_H := 3.0        # overhead armour strip under it
const PLATE_PAD := 2.0         # frame around the bars
const PLATE_NAME_FS := 13
## Where the row of small icons under a plate starts, below the plate's anchor point (the
## loadout icons go here): the bars end at +PLATE_HP_H + PLATE_AR_H + pads, then the dash pips.
const PLATE_ICON_ROW := 22.0
const SLOT_RAD := 9            # ability slot corner radius
const KEY_FS := 12             # key label size

## A hunter's health colour as seen by `viewer`: you, your squad, or a rival.
static func role_col(viewer: Hunter, h: Hunter) -> Color:
	if viewer == null or h == viewer:
		return Palette.col(Palette.YOU)
	return Palette.col(Palette.ALLY if h.team == viewer.team else Palette.FOE)

## Health fill for a role at a fraction of max: yours and allies' warm toward LOW under half, and
## pulse under a third; rivals stay red (a low rival pulses brighter instead).
static func hp_fill(role: Color, frac: float, time: float) -> Color:
	var pulse := 0.5 + 0.5 * sin(time * 9.0)
	if role == Palette.col(Palette.FOE):
		return role.lerp(Color.WHITE, 0.25 * pulse) if frac < 0.3 else role
	var col := role.lerp(Palette.col(Palette.LOW), clampf((0.55 - frac) / 0.3, 0.0, 1.0))
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

## The dark frame a plate's bars sit in: a soft-cornered backing with a hairline edge in the role
## colour (white while `flash` is up).
static func plate_frame(c: CanvasItem, r: Rect2, edge: Color, flash := 0.0) -> void:
	var sb := box(SHADE, 3, edge.lerp(Color.WHITE, snappedf(flash, 0.25)), 1)     # in steps: few cached boxes
	c.draw_style_box(sb, r)

## An ability or item slot's frame. `state`: "ready" (edge in the slot colour, a faint top gloss),
## "cooling" (a dim coral edge), "off" (barely there: locked, empty, or can't be used now).
static func slot_frame(c: CanvasItem, r: Rect2, col: Color, state := "ready") -> void:
	var edge := Color(1, 1, 1, 0.12)
	if state == "ready":
		edge = col
	elif state == "cooling":
		edge = Color(COOLING, 0.55)
	c.draw_style_box(box(Color(0.05, 0.06, 0.09, 0.92), SLOT_RAD, edge, 2), r)
	if state == "ready":
		var gloss := Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, r.size.y * 0.42))
		c.draw_style_box(box(Color(col, 0.10), SLOT_RAD - 3, Color(0, 0, 0, 0), 0), gloss)

## The key label under a slot: a dark pill, the key in the slot colour (muted when not ready).
static func key_pill(c: CanvasItem, center: Vector2, key: String, col: Color) -> void:
	var kw := BIG.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_FS).x
	var kr := Rect2(center - Vector2(kw * 0.5 + 6, 9), Vector2(kw + 12, 18))
	c.draw_style_box(box(KEY_BG, 9, Color(col, 0.8), 1), kr)
	c.draw_string(BIG, Vector2(kr.position.x + 6, kr.position.y + 14), key, HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_FS, col)

## A small count badge (charges, stack sizes) centred on `at`.
static func count_badge(c: CanvasItem, at: Vector2, n: int, col: Color) -> void:
	var s := str(n)
	var w := maxf(16.0, BIG.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8.0)
	c.draw_style_box(box(KEY_BG, 8, Color(col, 0.9), 1), Rect2(at - Vector2(w * 0.5, 8), Vector2(w, 16)))
	ctext(c, at + Vector2(0, 4.5), s, 11, col)

## Outlined text, left-aligned at `p` (baseline). `ol` is the outline width in px.
static func text(c: CanvasItem, p: Vector2, s: String, font_size: int, col: Color, ol := 4, font: Font = BIG) -> void:
	TextCache.draw(c, font, p, s, font_size, col, ol, Color(0, 0, 0, 0.6 * col.a))

## Outlined text centred on x at baseline `p.y`.
static func ctext(c: CanvasItem, p: Vector2, s: String, font_size: int, col: Color, ol := 4, font: Font = BIG) -> void:
	var w := TextCache.width(font, s, font_size)
	text(c, Vector2(p.x - w * 0.5, p.y), s, font_size, col, ol, font)

## Floating damage number colour: by who was hit and how (Match picks, Fx draws).
static func dmg_col(crit: bool, armor_hit: bool, on_you: bool, on_your_kin: bool) -> Color:
	if on_you: return Palette.col(Palette.HURT)
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
