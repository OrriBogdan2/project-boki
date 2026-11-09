class_name RecastCue
extends RefCounted
## The cue for an ability you press twice (DECISIONS 2026-11-08 "two-step abilities must be obvious"): while the
## local Hunter's kit has a recast open (ArchKit.recast_left / recast_slot), that slot's icon pulses, a ring
## round it shrinks with the time left, and big "<KEY> AGAIN" text sits over it, all in the ability's colour.
## The same for every Hunter. Hud._draw_arch_abilities calls draw() once, after the slots are placed.

const RING_GAP := 8.0          # px from the slot edge to the timer ring
const RING_W := 4.0            # px: the timer ring's width
const TEXT_RISE := 26.0        # px from the slot's top edge up to the AGAIN text's baseline
const TEXT_SIZE := 20
const PULSE_HZ := 9.0          # rad/s of the pulse
const TILE_RISE := 14.0        # px: the gap between the RMB slot and the floating LMB tile
const KEYS := {"k1": "signature", "x": "hunter_ult", "dash": "dash", "sec": "secondary", "primary": "fire"}

static var span := 0.0          # the longest the open recast has been (s): the ring is left / span
static var shown := ""          # the text last drawn ("" none; checks read it)

static func draw(H, p: Hunter) -> void:
	var k: ArchKit = p.ak
	var left := k.recast_left()
	shown = ""
	if left <= 0.0:
		span = 0.0
		return
	var slot := k.recast_slot()
	var r := _rect(H, slot)
	if r.size.x <= 0.0:
		return
	var c: CanvasItem = H.c
	var info := _info(k, slot)
	var col: Color = info["col"]
	var key := String(Settings.key_cap(KEYS[slot]))
	if slot == "primary":
		HudStyle.slot_frame(c, r, col, "ready")
		Icons.draw(c, String(info["icon"]), r.get_center() + Vector2(0, -2), r.size.x * 0.27, col)
		HudStyle.key_pill(c, Vector2(r.get_center().x, r.end.y), key, col)
	span = maxf(span, left) if left != INF else 1.0
	var pulse := 0.5 + 0.5 * sin(float(H.m.time) * PULSE_HZ)
	H._rounded(r.grow(2.0 + pulse * 3.0), Color(col, 0.08 + 0.12 * pulse), HudStyle.SLOT_RAD + 2, Color(col, 0.55 + 0.45 * pulse), 3)
	var ring := r.size.x * 0.5 + RING_GAP
	var frac := 1.0 if left == INF else clampf(left / maxf(span, 0.01), 0.0, 1.0)
	c.draw_arc(r.get_center(), ring, 0.0, TAU, 48, HudStyle.SHADE_EDGE, RING_W + 2.0, true)
	c.draw_arc(r.get_center(), ring, -PI / 2, -PI / 2 + TAU * frac, 48, col.lerp(Color.WHITE, 0.25 * pulse), RING_W, true)
	shown = "%s AGAIN" % key
	var tp := Vector2(r.get_center().x, r.position.y - TEXT_RISE)
	HudStyle.ctext(c, tp, shown, TEXT_SIZE, col.lerp(Color.WHITE, 0.35 + 0.3 * pulse), 6)

## The slot's screen rect, as the bar placed it (hover_spots); "primary" has no slot, so a tile floats over RMB's.
static func _rect(H, slot: String) -> Rect2:
	var id := "sec" if slot == "primary" else slot
	for hs in H.hover_spots:
		if hs[1] == id:
			var r: Rect2 = hs[0]
			return Rect2(r.position - Vector2(0, r.size.y + TILE_RISE), r.size) if slot == "primary" else r
	return Rect2()

## The icon and colour of the slot (the LMB tile has none on the bar: the kit's own attack data).
static func _info(k: ArchKit, slot: String) -> Dictionary:
	if slot == "primary":
		var ld := k.lmb_def()
		return {"icon": String(ld.get("icon", "")), "col": k.col_of(ld)}
	return k.h.slot_info(slot)
