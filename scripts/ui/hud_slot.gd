class_name HudSlot
extends RefCounted
## One ability or item slot on the bottom bar: the frame (HudStyle.slot_frame), the icon, and while
## it isn't ready a dimmed icon, a dark sweep over the part still cooling (clipped to the slot) and
## a big countdown in the middle; charge pips along the bottom edge, the key on a pill under it, a
## pop when a press lands, one red pulse of the frame when it can't (PressDeny), a ring when it comes
## back, and ResetPop's swell when a reset hands it straight back. skill_slot adds
## run levels on top: locked (padlock, UNLOCK when a point can open it, LV 6 on R), rank pips over
## it, and a gold + to spend a point (RankMarks; click it or Alt + the key). Hud._ab_slot /
## Hud._skill_slot call these (the Boki slots in BokiHud go through the same two, so every slot on the bar looks alike).
## Per-slot animation state lives on Hud (slot_fx, ready_was, ready_flash, hover_spots) and the last
## countdown text shown per slot on Hud.slot_text (checks read it).

const READY_FLASH := 0.35      # s: the ring when a slot comes back
const DENY_T := 0.15           # s: the frame's one red pulse when a press can't go
const POP_T := 0.3             # s: the pop when a press lands
const DISC_K := 0.26           # a charge disc's width / the slot's (the source: ~5 px on a ~19 px slot, DASH_UI.md)
const DISC_GAP := 1.0          # px between two charge discs

static var shown_keys := {}    # slot id -> the key cap last drawn under it (checks read it)
static var shown_pips := {}    # slot id -> the fill (0..1) of each charge pip last drawn (checks read it)

## Moves the per-slot animation state of host `hud` on by `delta` s: presses age out, "ready" rings fade.
static func decay(hud, delta: float) -> void:
	for id in hud.slot_fx.keys():
		hud.slot_fx[id]["t"] = float(hud.slot_fx[id]["t"]) + delta
		if float(hud.slot_fx[id]["t"]) > ResetPop.LEN: hud.slot_fx.erase(id)
	for id in hud.ready_flash.keys():
		hud.ready_flash[id] = float(hud.ready_flash[id]) - delta
		if float(hud.ready_flash[id]) <= 0.0: hud.ready_flash.erase(id)

## The countdown as shown: whole seconds from 1s up, tenths under it.
static func cd_text(secs: float) -> String:
	return str(int(ceil(secs))) if secs >= 1.0 else "%.1f" % secs

static func ab_slot(hud, id: String, rect: Rect2, icon: String, key: String, col: Color, cd_frac: float,
		cd_secs: float, ready: bool, charges := -1.0, max_ch := 0, label := "") -> void:
	var c: CanvasItem = hud.c
	var sfx_d: Dictionary = hud.slot_fx.get(id, {})
	var pop := 0.0
	if not sfx_d.is_empty():
		var ft := float(sfx_d["t"])
		if sfx_d["kind"] == "reset":
			rect = ResetPop.scaled(rect, ft)
		elif sfx_d["kind"] == "cast":
			pop = clampf(1.0 - ft / POP_T, 0.0, 1.0)
			rect = rect.grow(-rect.size.x * 0.08 * sin(pop * PI))
	var ctr := rect.get_center()
	hud.hover_spots.append([rect, id])
	var was: bool = hud.ready_was.get(id, true)
	if ready and not was:
		hud.ready_flash[id] = READY_FLASH
	hud.ready_was[id] = ready
	var cooling := cd_frac > 0.0 and cd_secs > 0.0 and not ready
	var frame_state := "cooling" if cooling else "off"
	HudStyle.slot_frame(c, rect, col, "ready" if ready else frame_state)
	var icol: Color = col if ready else Color(col.lerp(HudStyle.MUTED, 0.65), 0.45)
	Icons.draw(c, icon, ctr + Vector2(0, -2), rect.size.x * 0.27, icol)
	hud.slot_text.erase(id)
	if cd_frac > 0.0:
		# a charge coming back while another is ready: a light sweep, so it never reads as locked
		var shade := 0.22 if ready else 0.62
		sweep(c, rect.grow(-2.0), cd_frac, Color(0.0, 0.0, 0.02, shade))
		# the next charge's countdown shows big in the middle while another is ready, as the source shows it
		if cooling or (ready and max_ch > 1 and cd_secs > 0.0):
			var t := cd_text(cd_secs)
			var fs := int(rect.size.x * (0.46 if t.length() < 3 else 0.38))
			var tcol := HudStyle.INK if cd_secs >= 1.0 else HudStyle.COOLING
			HudStyle.ctext(c, ctr + Vector2(0, fs * 0.36), t, fs, tcol, 6)
			hud.slot_text[id] = t
	if max_ch > 1:
		shown_pips[id] = charge_discs(c, rect, charges, max_ch, col)
	if label != "":
		HudStyle.ctext(c, Vector2(ctr.x, rect.position.y - 6), label, 11, Color(HudStyle.INK, 0.85), 3, HudStyle.BODY)
	shown_keys[id] = key
	if key != "": HudStyle.key_pill(c, Vector2(ctr.x, rect.end.y), key, col if ready else HudStyle.MUTED)
	deny_pulse(hud, id, rect)
	if pop > 0.0:
		var pop_edge := Color(col.lerp(Color.WHITE, 0.5), pop)
		hud._rounded(rect.grow((1.0 - pop) * 14.0), Color(1, 1, 1, 0.12 * pop), HudStyle.SLOT_RAD + 2, pop_edge, 3)
	var fl := float(hud.ready_flash.get(id, 0.0))
	if fl > 0.0:
		var k := 1.0 - fl / READY_FLASH
		hud._rounded(rect.grow(2.0 + k * 8.0), Color(0, 0, 0, 0), HudStyle.SLOT_RAD + 2, Color(col, 1.0 - k), 3)
	if sfx_d.get("kind", "") == "reset":
		ResetPop.draw(c, rect, col, float(sfx_d["t"]))

## The source's charge counter: a row of round discs centred on the slot's top edge, one per charge. A ready
## charge is a disc in the slot's colour, a spent one dark with a light ring, and the recharging one fills its
## ring clockwise. Returns each disc's fill (0..1) for the checks.
static func charge_discs(c: CanvasItem, r: Rect2, charges: float, cap: int, col: Color) -> Array:
	var d := minf(r.size.x * DISC_K, (r.size.x - 4.0) / float(cap) - DISC_GAP)
	var x0 := r.get_center().x - (d * cap + DISC_GAP * (cap - 1)) * 0.5 + d * 0.5
	var fills: Array = []
	for i in cap:
		var at := Vector2(x0 + i * (d + DISC_GAP), r.position.y)
		var fill := clampf(charges - float(i), 0.0, 1.0)
		c.draw_circle(at, d * 0.5 + 1.0, HudStyle.SHADE_EDGE)
		c.draw_circle(at, d * 0.5, col if fill >= 1.0 else Color(0.06, 0.06, 0.1))
		if fill < 1.0:
			c.draw_arc(at, d * 0.5 - 0.75, 0.0, TAU, 20, Color(1, 1, 1, 0.55), 1.5, true)
			if fill > 0.0:
				c.draw_arc(at, d * 0.5 - 1.5, -PI / 2, -PI / 2 + TAU * fill, 20, col, 3.0, true)
		fills.append(fill)
	return fills

## A locked slot: the dimmed icon under a padlock and the key cap; "UNLOCK" in gold when a point can open it
## (`can`), else `tag` (when it opens, "" for none) on a pill over the slot. `id` names it in shown_keys.
static func locked(hud, id: String, r: Rect2, icon: String, col: Color, key: String, can: bool, tag: String) -> void:
	var c: CanvasItem = hud.c
	var pulse := 0.5 + 0.5 * sin(float(hud.m.time) * 5.0)
	HudStyle.slot_frame(c, r, HudStyle.GOLD, "ready" if can else "off")
	if can:
		var glow := Color(1.0, 0.82, 0.48, 0.25 + 0.4 * pulse)
		hud._rounded(r.grow(2.0 + pulse * 2.0), Color(0, 0, 0, 0), HudStyle.SLOT_RAD + 2, glow, 2)
	var icol := Color(col.lerp(HudStyle.MUTED, 0.5), 0.45 if can else 0.22)
	Icons.draw(c, icon, r.get_center() + Vector2(0, -2), r.size.x * 0.25, icol)
	var lcol := HudStyle.GOLD if can else Color(HudStyle.MUTED, 0.85)
	padlock(hud, r.get_center() + Vector2(0, 4), lcol)
	if can:
		# (at a bigger Text size the word grows down into the slot, not up into the resource bar's name)
		var base := r.position.y - 7.0 + (UI.fs(10) - 10)
		HudStyle.ctext(c, Vector2(r.get_center().x, base), "UNLOCK", 10, HudStyle.GOLD, 3)
	elif tag != "":
		var tw := TextCache.width(HudStyle.BIG, tag, 10) + 12.0
		var tr := Rect2(Vector2(r.get_center().x - tw * 0.5, r.position.y - 14), Vector2(tw, 14))
		hud._rounded(tr, HudStyle.KEY_BG, 5, Color(HudStyle.MUTED, 0.7), 1)
		HudStyle.ctext(c, Vector2(r.get_center().x, tr.end.y - 3), tag, 10, Color(HudStyle.INK, 0.9), 0)
	shown_keys[id] = key
	HudStyle.key_pill(c, Vector2(r.get_center().x, r.end.y), key, lcol if can else Color(HudStyle.MUTED, 0.6))

## The padlock every locked slot shows, its body centred on `at`.
static func padlock(hud, at: Vector2, col: Color) -> void:
	hud.c.draw_arc(at + Vector2(0, -6), 5.0, PI, TAU, 12, col, 2.0, true)
	hud._rounded(Rect2(at + Vector2(-7, -6), Vector2(14, 11)), col, 3)

## Over an ab_slot drawn not ready: off cooldown but it can't be cast now (stunned, downed, merged).
## A dark veil and the padlock, so it never reads as ready or as cooling.
static func lock_over(hud, r: Rect2) -> void:
	hud._rounded(r.grow(-2.0), Color(0.0, 0.0, 0.02, 0.5), HudStyle.SLOT_RAD - 1)
	padlock(hud, r.get_center() + Vector2(0, 4), Color(HudStyle.INK, 0.9))

## Over an ab_slot drawn ready: the ultimate's lit frame (a bright rim and a soft halo in the slot colour,
## steady), and while `shine` runs 1 -> 0 after it comes back a white edge, a brightened icon and a band of
## light crossing the slot left to right.
static func lit(hud, r: Rect2, col: Color, icon: String, shine: float) -> void:
	var c: CanvasItem = hud.c
	hud._rounded(r.grow(5.0), Color(0, 0, 0, 0), HudStyle.SLOT_RAD + 5, Color(col, 0.3), 3)
	hud._rounded(r.grow(2.0), Color(0, 0, 0, 0), HudStyle.SLOT_RAD + 2, Color(col.lightened(0.25), 0.95), 2)
	if shine <= 0.0:
		return
	hud._rounded(r.grow(2.0), Color(0, 0, 0, 0), HudStyle.SLOT_RAD + 2, Color(1, 1, 1, shine), 3)
	Icons.draw(c, icon, r.get_center() + Vector2(0, -2), r.size.x * 0.27, Color(1, 1, 1, 0.7 * shine))
	var w := r.size.x * 0.3
	var bx := lerpf(r.position.x - w * 2.0, r.end.x + w, 1.0 - shine)
	var band := PackedVector2Array([Vector2(bx + w, r.position.y), Vector2(bx + w * 2.0, r.position.y),
			Vector2(bx + w, r.end.y), Vector2(bx, r.end.y)])
	var inner := r.grow(-3.0)      # (inside the frame's rounded corners)
	var clip := PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end,
			Vector2(inner.position.x, inner.end.y)])
	for part in Geometry2D.intersect_polygons(band, clip):
		c.draw_colored_polygon(part, Color(1, 1, 1, 0.4 * shine))

## A refused press on slot `id` (PressDeny): its frame swells red and back once over DENY_T.
static func deny_pulse(hud, id: String, r: Rect2) -> void:
	var fx: Dictionary = hud.slot_fx.get(id, {})
	if fx.get("kind", "") != "deny" or float(fx["t"]) >= DENY_T:
		return
	var k := sin(PI * float(fx["t"]) / DENY_T)
	hud._rounded(r.grow(3.0 * k), Color(0.9, 0.15, 0.1, 0.22 * k), HudStyle.SLOT_RAD, Color(1.0, 0.35, 0.3, k), 3)

## The part of a slot still cooling: a slice from 12 o'clock, clockwise, cut to the slot's square so
## it never spills past the frame.
static func sweep(c: CanvasItem, r: Rect2, frac: float, col: Color) -> void:
	if frac <= 0.005:
		return
	frac = minf(frac, 0.995)      # (a full turn closes on itself: the polygon would not triangulate)
	var ctr := r.get_center()
	var half := r.size * 0.5
	var pts := PackedVector2Array([ctr])
	var n := 32
	var a0 := -PI / 2.0 + TAU * (1.0 - frac)
	for i in n + 1:
		var a := a0 + TAU * frac * float(i) / n
		var d := Vector2(cos(a), sin(a))
		pts.append(ctr + d * minf(half.x / maxf(absf(d.x), 0.0001), half.y / maxf(absf(d.y), 0.0001)))
	c.draw_colored_polygon(pts, col)

## A slot with run levels: locked (padlock; UNLOCK in gold when a point can open it; R says when it
## opens), else the ability slot with RankMarks' tier pips and, while a point can go in, its gold +.
static func skill_slot(hud, slot: String, id: String, r: Rect2, icon: String, key: String, col: Color, cdf: float,
		cds: float, ready: bool, ch := -1.0, mx := 0) -> void:
	var p: Hunter = hud.m.player
	var lv := int(p.slot_lv.get(slot, 1))
	var can := p.can_level(slot)
	RankMarks.note_face(slot, r)
	if lv <= 0:
		hud.hover_spots.append([r, id])
		# R: a tag over the slot saying when it opens, so it never reads as just on cooldown
		locked(hud, id, r, icon, col, key, can, hud.r_lock_text(p) if slot == "ult" else "")
		deny_pulse(hud, id, r)
		if can:
			RankMarks.beam(hud, r, slot)
			RankMarks.mark(slot, r)
		return
	ab_slot(hud, id, r, icon, key, col, cdf, cds, ready, ch, mx)
	RankMarks.pips(hud, r, slot, lv, col)
	if can:
		RankMarks.plus(hud, r, id, slot, key)
