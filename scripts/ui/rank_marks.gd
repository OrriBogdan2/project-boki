class_name RankMarks
extends RefCounted
## The run-level marks on a ranked ability slot (HudSlot.skill_slot): the rank as a numeral badge on
## the slot's top edge, and
## while a skill point can go in, a pulsing gold frame and a big gold "+" in the corner that you can
## click (RankClick) or spend with Alt + the ability's key. The "ALT+key" hint shows over every
## rankable slot for a few seconds when a new point arrives, and on hover after that.

const BADGE_H := 10.0          # px: the rank badge on the slot's top edge
const NUMERALS := ["", "I", "II", "III", "IV", "V", "VI"]
const PLUS_R := 11.0           # px: the "+" badge's radius before its pulse
const PLUS_HIT := 16.0         # px: half the clickable square round the "+"
const HINT_SECS := 5.0         # s: the ALT+key hint shows on every rankable slot after a new point
const HINT_RAISED := ["dash"]  # slots whose hint sits a row higher: the row's slots are closer than "ALT+SHIFT" is wide
const HINT_ROW := 19.0         # px: that extra height

static var plus_spots := {}    # slot -> [Rect2 the "+" covers, HudPanels.draws when drawn] (RankClick reads it)
static var faces := {}         # slot -> [Rect2 the slot's face, HudPanels.draws when drawn] (tutorial pointers read it)
static var _pts_was := 0
static var _hint_until := 0.0

## The rank `lv` as a numeral on a badge over `r`'s top edge, pink, gold once the slot is maxed.
## Also notes a newly earned point, which starts the ALT+key hint.
static func pips(H, r: Rect2, slot: String, lv: int, _col: Color) -> void:
	var c: CanvasItem = H.c
	var pts: int = H.m.player.skill_pts
	if pts > _pts_was:
		_hint_until = float(H.m.time) + HINT_SECS
	_pts_was = pts
	var maxed := lv >= int(Hunter.SLOT_MAX.get(slot, 3))
	var txt: String = NUMERALS[clampi(lv, 0, NUMERALS.size() - 1)]
	var w := maxf(14.0, HudStyle.BIG.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 8.0)
	var br := Rect2(Vector2(r.get_center().x - w * 0.5, r.position.y - BADGE_H * 0.6), Vector2(w, BADGE_H))
	c.draw_style_box(HudStyle.box(HudStyle.GOLD if maxed else HudStyle.RANK, 5, HudStyle.SHADE_EDGE, 1), br)
	HudStyle.ctext(c, Vector2(br.get_center().x, br.end.y - 2.0), txt, 9, Color.WHITE, 2)

## The spend-a-point marks on a slot that can rank now: the pulsing frame, the "+" (recorded in
## plus_spots for clicks) and the ALT+key hint while it's fresh or hovered.
static func plus(H, r: Rect2, id: String, slot: String, key: String) -> void:
	var c: CanvasItem = H.c
	var t: float = H.m.time
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	var glow := Color(1.0, 0.82, 0.48, 0.35 + 0.5 * pulse)
	H._rounded(r.grow(2.0 + pulse * 3.0), Color(0, 0, 0, 0), HudStyle.SLOT_RAD + 3, glow, 3)
	if H.hover_id == id or t < _hint_until:
		_hint(H, hint_pill(r, slot, key), "ALT+" + key)
	var cp := Vector2(r.end.x - 3.0, r.position.y + 3.0)
	var rad := PLUS_R + pulse * 1.5
	c.draw_circle(cp, rad + 1.5, HudStyle.SHADE_EDGE)
	c.draw_circle(cp, rad, HudStyle.GOLD)
	HudStyle.ctext(c, cp + Vector2(0, 6.0), "+", 18, Color(0.1, 0.07, 0.02), 0)
	mark(slot, Rect2(cp - Vector2(PLUS_HIT, PLUS_HIT), Vector2(PLUS_HIT, PLUS_HIT) * 2.0))

## Make `at` the clickable spot that spends a point on `slot` this frame (a locked slot's whole face).
static func mark(slot: String, at: Rect2) -> void:
	plus_spots[slot] = [at, HudPanels.draws]

## The "+" rect for `slot` if HudPanels' latest redraw drew it, else an empty Rect2 (the panels redraw
## REDRAW_HZ times a second, so a "+" lives until the next redraw leaves it out).
static func spot(slot: String) -> Rect2:
	var s: Array = plus_spots.get(slot, [])
	if s.is_empty() or int(s[1]) != HudPanels.draws:
		return Rect2()
	return s[0]

## Note where `slot`'s face is this pass, wherever the HUD lays the ability row out.
static func note_face(slot: String, r: Rect2) -> void:
	faces[slot] = [r, HudPanels.draws]

## `slot`'s face as the HUD last drew it, or an empty Rect2 if it wasn't drawn this pass or the one before
## (a tutorial pointer draws before the panels' pass of the same frame, so it reads the previous pass).
static func face(slot: String) -> Rect2:
	var s: Array = faces.get(slot, [])
	if s.is_empty() or int(s[1]) < HudPanels.draws - 1:
		return Rect2()
	return s[0]

## Where the ALT+key hint sits over the slot at `r`: centred on it, a row higher for HINT_RAISED slots.
static func hint_pill(r: Rect2, slot: String, key: String) -> Rect2:
	var w := HudStyle.BIG.get_string_size("ALT+" + key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12.0
	var lift := HINT_ROW if slot in HINT_RAISED else 0.0
	return Rect2(Vector2(r.get_center().x - w * 0.5, r.position.y - 27.0 - lift), Vector2(w, 17.0))

## The ALT+key hint on a dark pill, so it reads over the bars and labels above the slot.
static func _hint(H, pill: Rect2, text: String) -> void:
	H._rounded(pill, HudStyle.KEY_BG, 6, Color(HudStyle.GOLD, 0.8), 1)
	HudStyle.ctext(H.c, Vector2(pill.get_center().x, pill.end.y - 4.0), text, 12, HudStyle.GOLD, 0)
