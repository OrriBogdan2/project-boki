class_name HudSlot
extends RefCounted
## One ability or item slot on the bottom bar: the frame (HudStyle.slot_frame), the icon, and while
## it isn't ready a dimmed icon, a dark sweep over the part still cooling (clipped to the slot) and
## a big countdown in the middle; charge pips along the bottom edge, the key on a pill under it, a
## pop when a press lands, a red shake when it can't, a ring when it comes back, and ResetPop's swell
## when a reset hands it straight back. skill_slot adds
## run levels on top: locked (padlock, UNLOCK when a point can open it, LV 6 on R), rank pips over
## it, and a gold + to spend a point (RankMarks; click it or Alt + the key). Hud._ab_slot /
## Hud._skill_slot call these (the Boki slots in BokiHud go through the same two, so every slot on the bar looks alike).
## Per-slot animation state lives on Hud (slot_fx, ready_was, ready_flash, hover_spots) and the last
## countdown text shown per slot on Hud.slot_text (checks read it).

const READY_FLASH := 0.35      # s: the ring when a slot comes back
const DENY_T := 0.35           # s: the red shake when a press can't go
const POP_T := 0.3             # s: the pop when a press lands

static var shown_keys := {}    # slot id -> the key cap last drawn under it (checks read it)
static var shown_pips := {}    # slot id -> the fill (0..1) of each charge pip last drawn (checks read it)

## Moves the per-slot animation state of host `H` on by `delta` s: presses age out, "ready" rings fade.
static func decay(H, delta: float) -> void:
	for id in H.slot_fx.keys():
		H.slot_fx[id]["t"] = float(H.slot_fx[id]["t"]) + delta
		if float(H.slot_fx[id]["t"]) > ResetPop.LEN: H.slot_fx.erase(id)
	for id in H.ready_flash.keys():
		H.ready_flash[id] = float(H.ready_flash[id]) - delta
		if float(H.ready_flash[id]) <= 0.0: H.ready_flash.erase(id)

## The countdown as shown: whole seconds from 1s up, tenths under it.
static func cd_text(secs: float) -> String:
	return str(int(ceil(secs))) if secs >= 1.0 else "%.1f" % secs

static func ab_slot(H, id: String, rect: Rect2, icon: String, key: String, col: Color, cd_frac: float,
		cd_secs: float, ready: bool, charges := -1.0, max_ch := 0, label := "") -> void:
	var c: CanvasItem = H.c
	var sfx_d: Dictionary = H.slot_fx.get(id, {})
	var deny := 0.0
	var pop := 0.0
	if not sfx_d.is_empty():
		var ft := float(sfx_d["t"])
		if sfx_d["kind"] == "deny":
			deny = clampf(1.0 - ft / DENY_T, 0.0, 1.0)
			rect.position.x += sin(ft * 70.0) * 5.0 * deny
		elif sfx_d["kind"] == "reset":
			rect = ResetPop.scaled(rect, ft)
		else:
			pop = clampf(1.0 - ft / POP_T, 0.0, 1.0)
			rect = rect.grow(-rect.size.x * 0.08 * sin(pop * PI))
	var ctr := rect.get_center()
	H.hover_spots.append([rect, id])
	var was: bool = H.ready_was.get(id, true)
	if ready and not was:
		H.ready_flash[id] = READY_FLASH
	H.ready_was[id] = ready
	var cooling := cd_frac > 0.0 and cd_secs > 0.0 and not ready
	var frame_state := "cooling" if cooling else "off"
	HudStyle.slot_frame(c, rect, col, "ready" if ready else frame_state)
	var icol: Color = col if ready else Color(col.lerp(HudStyle.MUTED, 0.65), 0.45)
	Icons.draw(c, icon, ctr + Vector2(0, -2), rect.size.x * 0.27, icol)
	H.slot_text.erase(id)
	if cd_frac > 0.0:
		# a charge coming back while another is ready (dashes): a light sweep and no number, so it never reads as locked
		var shade := 0.22 if ready else 0.62
		sweep(c, rect.grow(-2.0), cd_frac, Color(0.0, 0.0, 0.02, shade))
		if ready and max_ch > 1 and cd_secs > 0.0:
			_next_charge_text(H, id, rect, cd_secs)
		if cooling:
			var t := cd_text(cd_secs)
			var fs := int(rect.size.x * (0.46 if t.length() < 3 else 0.38))
			var tcol := HudStyle.INK if cd_secs >= 1.0 else HudStyle.COOLING
			HudStyle.ctext(c, ctr + Vector2(0, fs * 0.36), t, fs, tcol, 6)
			H.slot_text[id] = t
	if max_ch > 1:
		var pw := minf(10.0, (rect.size.x - 12.0) / float(max_ch) - 2.0)
		var px := ctr.x - (pw * max_ch + 2.0 * (max_ch - 1)) * 0.5
		var fills: Array = []
		for i in max_ch:
			var pr := Rect2(Vector2(px + i * (pw + 2.0), rect.end.y - 7.0), Vector2(pw, 3.0))
			var fill := clampf(charges - float(i), 0.0, 1.0)
			c.draw_rect(pr.grow(1.0), HudStyle.SHADE_EDGE)
			c.draw_rect(pr, Color(1, 1, 1, 0.18))
			c.draw_rect(Rect2(pr.position, Vector2(pw * fill, pr.size.y)), col)
			fills.append(fill)
		shown_pips[id] = fills
	if label != "":
		HudStyle.ctext(c, Vector2(ctr.x, rect.position.y - 6), label, 11, Color(HudStyle.INK, 0.85), 3, HudStyle.BODY)
	shown_keys[id] = key
	if key != "": HudStyle.key_pill(c, Vector2(ctr.x, rect.end.y), key, col if ready else HudStyle.MUTED)
	if deny > 0.0:
		H._rounded(rect, Color(0.9, 0.15, 0.1, 0.22 * deny), HudStyle.SLOT_RAD, Color(1.0, 0.35, 0.3, deny), 3)
	if pop > 0.0:
		var pop_edge := Color(col.lerp(Color.WHITE, 0.5), pop)
		H._rounded(rect.grow((1.0 - pop) * 14.0), Color(1, 1, 1, 0.12 * pop), HudStyle.SLOT_RAD + 2, pop_edge, 3)
	var fl := float(H.ready_flash.get(id, 0.0))
	if fl > 0.0:
		var k := 1.0 - fl / READY_FLASH
		H._rounded(rect.grow(2.0 + k * 8.0), Color(0, 0, 0, 0), HudStyle.SLOT_RAD + 2, Color(col, 1.0 - k), 3)
	if sfx_d.get("kind", "") == "reset":
		ResetPop.draw(c, rect, col, float(sfx_d["t"]))

## A charge is ready and the next one recharges: its countdown small at the top, the slot not dimmed like a locked one.
static func _next_charge_text(H, id: String, r: Rect2, secs: float) -> void:
	var t := cd_text(secs)
	HudStyle.ctext(H.c, r.position + Vector2(r.size.x * 0.5, 17.0), t, DashSlot.TOP_CD_FS, Color(HudStyle.INK, 0.9), 4)
	H.slot_text[id] = t

## A locked slot: the dimmed icon under a padlock and the key cap; "UNLOCK" in gold when a point can open it
## (`can`), else `tag` (when it opens, "" for none) on a pill over the slot. `id` names it in shown_keys.
static func locked(H, id: String, r: Rect2, icon: String, col: Color, key: String, can: bool, tag: String) -> void:
	var c: CanvasItem = H.c
	var pulse := 0.5 + 0.5 * sin(float(H.m.time) * 5.0)
	HudStyle.slot_frame(c, r, HudStyle.GOLD, "ready" if can else "off")
	if can:
		var glow := Color(1.0, 0.82, 0.48, 0.25 + 0.4 * pulse)
		H._rounded(r.grow(2.0 + pulse * 2.0), Color(0, 0, 0, 0), HudStyle.SLOT_RAD + 2, glow, 2)
	var icol := Color(col.lerp(HudStyle.MUTED, 0.5), 0.45 if can else 0.22)
	Icons.draw(c, icon, r.get_center() + Vector2(0, -2), r.size.x * 0.25, icol)
	var lc := r.get_center() + Vector2(0, 4)
	var lcol := HudStyle.GOLD if can else Color(HudStyle.MUTED, 0.85)
	c.draw_arc(lc + Vector2(0, -6), 5.0, PI, TAU, 12, lcol, 2.0, true)
	H._rounded(Rect2(lc + Vector2(-7, -6), Vector2(14, 11)), lcol, 3)
	if can:
		HudStyle.ctext(c, Vector2(r.get_center().x, r.position.y - 7), "UNLOCK", 10, HudStyle.GOLD, 3)
	elif tag != "":
		var tw := HudStyle.BIG.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12.0
		var tr := Rect2(Vector2(r.get_center().x - tw * 0.5, r.position.y - 17), Vector2(tw, 14))
		H._rounded(tr, HudStyle.KEY_BG, 5, Color(HudStyle.MUTED, 0.7), 1)
		HudStyle.ctext(c, Vector2(r.get_center().x, tr.end.y - 3), tag, 10, Color(HudStyle.INK, 0.9), 0)
	shown_keys[id] = key
	HudStyle.key_pill(c, Vector2(r.get_center().x, r.end.y), key, lcol if can else Color(HudStyle.MUTED, 0.6))

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
static func skill_slot(H, slot: String, id: String, r: Rect2, icon: String, key: String, col: Color, cdf: float,
		cds: float, ready: bool, ch := -1.0, mx := 0) -> void:
	var p: Hunter = H.m.player
	var lv := int(p.slot_lv.get(slot, 1))
	var can := p.can_level(slot)
	if lv <= 0:
		H.hover_spots.append([r, id])
		var sfx_d: Dictionary = H.slot_fx.get(id, {})
		if not sfx_d.is_empty() and sfx_d["kind"] == "deny":
			r.position.x += sin(float(sfx_d["t"]) * 70.0) * 5.0 * clampf(1.0 - float(sfx_d["t"]) / DENY_T, 0.0, 1.0)
		# R: a tag over the slot saying when it opens, so it never reads as just on cooldown
		locked(H, id, r, icon, col, key, can, H.r_lock_text(p) if slot == "ult" else "")
		if can:
			RankMarks.mark(slot, r)
		return
	ab_slot(H, id, r, icon, key, col, cdf, cds, ready, ch, mx)
	RankMarks.pips(H, r, slot, lv, col)
	if can:
		RankMarks.plus(H, r, id, slot, key)
