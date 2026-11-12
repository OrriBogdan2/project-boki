class_name ChannelBar
extends RefCounted
## "Meeko is protecting you": while an ally's Hearth Call channels on you, a slim bar with her portrait sits
## under your vitals and drains over the channel's length; it is gone the frame the channel ends or breaks.
## The caster's game reads its kit; every other game gets the target and the seconds left from the hunter
## snapshot (HunterNet), so the ally sees it online too. Check: --hudref-check (and the online row of
## --displace-net-check).

const BAR_H := 8.0             # px: the bar
const ICON := 16.0             # px: Meeko's portrait chip
const COL := Color("ffd27a")   # the tether's gold
const META := "chan"           # remote caster: [target nid, match time the channel ends]

## nid -> {"left": s, "frac": 0..1} of the bar the last draw put up (a check reads it)
static var shown := {}

## The caster's channel as [target nid, seconds left]; ["", 0] when none runs.
static func read(h: Hunter) -> Array:
	var k := h.ak as TenderKit
	if k != null and not k.hearth_call.is_empty():
		var who: Hunter = k.hearth_call["who"]
		return [who.nid if is_instance_valid(who) else "", float(k.hearth_call["left"])]
	var rem: Array = h.get_meta(META, ["", 0.0])
	return [rem[0], float(rem[1]) - h.m.time]

## A remote caster's snapshot field: the target and the seconds left (0.05 s steps).
static func store(h: Hunter, to: String, left: float) -> void:
	h.set_meta(META, [to, h.m.time + left])

## The ally's view: the hunter channelling on `p` and the seconds left, or null.
static func caster_on(m: Match, p: Hunter) -> Hunter:
	for h in m.hunters:
		if h != p and h.ak is TenderKit and not h.out and not h.downed:
			var ch := read(h)
			if ch[0] == p.nid and float(ch[1]) > 0.0:
				return h
	return null

static func draw(H, sz: Vector2, p: Hunter) -> void:
	shown.clear()
	var from := caster_on(H.m, p)
	if from == null:
		return
	var left := float(read(from)[1])
	var total := float((from.ak as TenderKit).x_def()["time"])
	var frac := clampf(left / total, 0.0, 1.0)
	shown[from.nid] = {"left": left, "frac": frac}
	var o: Vector2 = H._hud_origin(sz)
	var y: float = o.y + H.HUD_PORTRAIT.y + 3.0
	H._draw_portrait(Rect2(Vector2(o.x, y - 4.0), Vector2(ICON, ICON)), from, "", COL)
	var bar := Rect2(Vector2(o.x + ICON + 8.0, y), Vector2(HudVitals.BAR_W + H.HUD_PORTRAIT.x - ICON - 8.0, BAR_H))
	H._rounded(bar.grow(2.0), HudStyle.SHADE, 4)
	H.c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, BAR_H)), COL)
	HudStyle.text(H.c, bar.end + Vector2(8.0, 1.0), "%.1f" % left, 11, HudStyle.INK)
