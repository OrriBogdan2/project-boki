class_name RankMarks
extends RefCounted
## The run-level marks on a ranked ability slot (HudSlot.skill_slot): tier pips over the slot, and
## while a skill point can go in, a pulsing gold frame and a big gold "+" in the corner that you can
## click (RankClick) or spend with Alt + the ability's key. The "ALT+key" hint shows over every
## rankable slot for a few seconds when a new point arrives, and on hover after that.

const PIP_W := 12.0            # px: one tier pip
const PIP_H := 5.0
const PIP_GAP := 3.0
const PLUS_R := 11.0           # px: the "+" badge's radius before its pulse
const PLUS_HIT := 16.0         # px: half the clickable square round the "+"
const HINT_SECS := 5.0         # s: the ALT+key hint shows on every rankable slot after a new point

static var plus_spots := {}    # slot -> [Rect2 the "+" covers, frame drawn] (RankClick reads it)
static var _pts_was := 0
static var _hint_until := 0.0

## Tier pips over `r`: one per rank the slot can reach, lit up to `lv`; gold once the slot is maxed.
## Also notes a newly earned point, which starts the ALT+key hint.
static func pips(H, r: Rect2, slot: String, lv: int, col: Color) -> void:
	var c: CanvasItem = H.c
	var pts: int = H.m.player.skill_pts
	if pts > _pts_was:
		_hint_until = float(H.m.time) + HINT_SECS
	_pts_was = pts
	var tiers := int(Hunter.SLOT_MAX.get(slot, 3))
	var maxed := lv >= tiers
	var x0 := r.get_center().x - (tiers * PIP_W + (tiers - 1) * PIP_GAP) * 0.5
	for i in tiers:
		var pr := Rect2(Vector2(x0 + i * (PIP_W + PIP_GAP), r.position.y - PIP_H - 4.0), Vector2(PIP_W, PIP_H))
		var lit := HudStyle.GOLD if maxed else col
		c.draw_rect(pr.grow(1.0), HudStyle.SHADE_EDGE)
		c.draw_rect(pr, Color(lit, 0.95) if i < lv else Color(1, 1, 1, 0.16))

## The spend-a-point marks on a slot that can rank now: the pulsing frame, the "+" (recorded in
## plus_spots for clicks) and the ALT+key hint while it's fresh or hovered.
static func plus(H, r: Rect2, id: String, slot: String, key: String) -> void:
	var c: CanvasItem = H.c
	var t: float = H.m.time
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	var glow := Color(1.0, 0.82, 0.48, 0.35 + 0.5 * pulse)
	H._rounded(r.grow(2.0 + pulse * 3.0), Color(0, 0, 0, 0), HudStyle.SLOT_RAD + 3, glow, 3)
	if H.hover_id == id or t < _hint_until:
		HudStyle.ctext(c, Vector2(r.get_center().x, r.position.y - 16), "ALT+" + key, 12, HudStyle.GOLD)
	var cp := Vector2(r.end.x - 3.0, r.position.y + 3.0)
	var rad := PLUS_R + pulse * 1.5
	c.draw_circle(cp, rad + 1.5, HudStyle.SHADE_EDGE)
	c.draw_circle(cp, rad, HudStyle.GOLD)
	HudStyle.ctext(c, cp + Vector2(0, 6.0), "+", 18, Color(0.1, 0.07, 0.02), 0)
	mark(slot, Rect2(cp - Vector2(PLUS_HIT, PLUS_HIT), Vector2(PLUS_HIT, PLUS_HIT) * 2.0))

## Make `at` the clickable spot that spends a point on `slot` this frame (a locked slot's whole face).
static func mark(slot: String, at: Rect2) -> void:
	plus_spots[slot] = [at, Engine.get_process_frames()]

## The "+" rect for `slot` if it was drawn this frame or the last, else an empty Rect2.
static func spot(slot: String) -> Rect2:
	var s: Array = plus_spots.get(slot, [])
	if s.is_empty() or Engine.get_process_frames() - int(s[1]) > 1:
		return Rect2()
	return s[0]
