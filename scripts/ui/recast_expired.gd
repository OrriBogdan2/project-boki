class_name RecastExpired
extends RefCounted
## "EXPIRED" over a slot's icon while its recast window's flash runs (RecastBuffer.expired, content/rules/tuning.json).

const RED := Color("ff6a5e")
const FADE_S := 0.2      # s: the flash fades out over its last stretch

## Called by HudSlot.ab_slot for each slot; draws nothing unless the local hunter's `id` ("k1", "x") just expired.
static func draw(H, id: String, rect: Rect2) -> void:
	var p: Hunter = H.m.player
	if p == null or p.ak == null:
		return
	var left := float(p.ak.rb.expired.get(id, 0.0))
	if left <= 0.0:
		return
	var a := clampf(left / FADE_S, 0.0, 1.0)
	H._rounded(rect, Color(0.0, 0.0, 0.0, 0.5 * a), HudStyle.SLOT_RAD, Color(RED, a), 2)
	HudStyle.ctext(H.c, rect.get_center(), "EXPIRED", int(rect.size.x * 0.2), Color(RED, a), 4)
