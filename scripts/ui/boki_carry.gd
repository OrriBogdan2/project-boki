class_name BokiCarry
extends RefCounted
## The rest of what you carry, beside the right-side Boki box (DECISIONS 2026-11-11 "carry 2 in, 1 extra out", Boki
## HUD): a column left of the gloves, up from the boxes' bottom (nothing fits under the box, and above it sits the
## belt), nearest first, one row each and only while it is in use:
##   second   your second Boki (Hunter.kin2): portrait, health, its carry passive's icon, and the swap key
##            (Settings.key_cap "swap_kin") with a ring that fills while the swap cools down
##   carry    the carry-out slot (Hunter.caught): the Boki you claimed, riding home. An empty outline while you
##            scan one; STOLEN when a rival took it from your deathbox (KinPair.robbed)
## The wisps you stole (BokiHud.stolen_wisps) stack above these. `shown` is what the last draw put on screen.

const ROW_W := BokiHud.STOLEN_W      # px: a row is as wide and as high as a stolen wisp's
const ROW_H := BokiHud.STOLEN_H
const ROW_GAP := 3.0       # px between rows
const ICON_PX := BokiHud.STOLEN_ICON      # px: the critter's side
const HP_W := 56.0         # px: the health bar
const HP_H := 5.0          # px
const KEY_R := 11.0        # px: the swap ring's radius round the key cap
const GROUP_ICON := {"movement": "dash", "defence": "fortify", "offence": "haymaker"}   # Icons id by passive group
const MISC_ICON := "cloak"

static var shown: Array = []

## One {"kind": "second"|"carry", "state", ...} per row in use. `state`: second "ready" | "wait" (swap cooling);
## carry "claimed" | "empty" | "stolen".
static func rows(p: Hunter) -> Array:
	var out: Array = []
	var k2: Kin = p.kin2
	if k2 != null and not k2.dead:
		var full := maxf(0.1, float(Content.rules("kin_ai").get("swap_cooldown", 3.0)))
		var state := "ready"
		if p.swap_cd > 0.0:
			state = "wait"
		out.append({"kind": "second", "kin": k2, "rec": k2.rec, "hp": clampf(k2.hp / maxf(k2.max_hp, 1.0), 0.0, 1.0),
			"cool": clampf(1.0 - p.swap_cd / full, 0.0, 1.0), "stat": _stat(k2), "state": state})
	for rec in p.caught:
		out.append({"kind": "carry", "rec": rec, "state": "claimed"})
	if p.caught.is_empty():
		var lost: Dictionary = p.get_meta(KinPair.ROBBED, {})
		if not lost.is_empty():
			out.append({"kind": "carry", "rec": lost, "state": "stolen"})
		elif Capture.state(p) != {}:
			out.append({"kind": "carry", "rec": {}, "state": "empty"})
	return out

## The stat a Boki's carry passive gives (its first), "" when none.
static func _stat(k: Kin) -> String:
	if k.ks == null or k.ks.carry_passives.is_empty():
		return ""
	return String(k.ks.carry_passives[0]["stat"])

## Draws the rows up from `bottom`, right edge at `right`; returns the height they took, for the stolen rows above.
static func draw(H, p: Hunter, right: float, bottom: float) -> float:
	shown.clear()
	var y := bottom
	for row in rows(p):
		var box := Rect2(Vector2(right - ROW_W, y - ROW_H), Vector2(ROW_W, ROW_H))
		if String(row["kind"]) == "second":
			_second(H, p, row, box)
		else:
			_carry(H, row, box)
		shown.append({"kind": row["kind"], "state": row["state"], "rect": box, "key": Settings.key_cap("swap_kin")})
		y -= ROW_H + ROW_GAP
	return bottom - y

## The critter's portrait (or its colours when the render is not there) with a ring, centred on `at`.
static func icon(H, rec: Dictionary, col: Color, ring: Color, at: Vector2) -> void:
	var tex := KinPortrait.tex(rec, H.get_tree())
	if tex != null:
		H.c.draw_texture_rect(tex, Rect2(at - Vector2.ONE * ICON_PX * 0.5, Vector2.ONE * ICON_PX), false)
	else:
		H.c.draw_circle(at, ICON_PX * 0.5, Color(col, 0.6))
		H.c.draw_circle(at, ICON_PX * 0.5 - 2.0, col)
	H.c.draw_arc(at, ICON_PX * 0.5 + 2.0, 0.0, TAU, 24, ring, 2.0, true)

static func _second(H, p: Hunter, row: Dictionary, box: Rect2) -> void:
	var k: Kin = row["kin"]
	var glow: Color = k.sp.get("glow", k.sp["color"])
	var st := String(row["state"])
	var hp := float(row["hp"])
	H._rounded(box, Color(0.03, 0.03, 0.05, 0.85), 8, Color(glow, 0.7), 1)
	icon(H, k.rec, k.sp["color"], SideColor.ally(), box.position + Vector2(ROW_H * 0.5, ROW_H * 0.5))
	var bar := Rect2(box.position + Vector2(ROW_H + 4.0, ROW_H * 0.5 - HP_H * 0.5), Vector2(HP_W, HP_H))
	var hp_col := HudStyle.hp_fill(SideColor.ally(), hp, H.m.time)
	HudStyle.strip(H.c, bar, hp, hp_col)
	var stat := String(row["stat"])
	if stat != "":
		var group := String(KinParts.OWNER_STATS[stat][0])
		var icon_at := Vector2(bar.end.x + 14.0, box.get_center().y)
		Icons.draw(H.c, GROUP_ICON.get(group, MISC_ICON), icon_at, 7.0, Color(glow, 0.9))
	var at := Vector2(box.end.x - 20.0, box.get_center().y)
	if st == "wait":
		var sweep := -PI / 2.0 + TAU * float(row["cool"])
		H.c.draw_arc(at, KEY_R, -PI / 2.0, sweep, 24, Color(HudStyle.MUTED, 0.9), 2.0, true)
	var key_col := glow
	if st != "ready":
		key_col = HudStyle.MUTED
	HudStyle.key_pill(H.c, at, Settings.key_cap("swap_kin"), key_col)

static func _carry(H, row: Dictionary, box: Rect2) -> void:
	var st := String(row["state"])
	var rec: Dictionary = row["rec"]
	var at := box.position + Vector2(ROW_H * 0.5, ROW_H * 0.5)
	var text_at := box.position + Vector2(ROW_H + 2.0, 16.0)
	var back := Color(0.03, 0.03, 0.05, 0.85)
	if st == "empty":
		H._rounded(box, Color(back, 0.5), 8, Color(HudStyle.MUTED, 0.5), 1)
		H.c.draw_arc(at, ICON_PX * 0.5 + 2.0, 0.0, TAU, 24, Color(HudStyle.MUTED, 0.6), 1.0, true)
		HudStyle.text(H.c, text_at, "Carry out: free", 11, HudStyle.MUTED, 3)
		return
	var col: Color = Data.KIN[String(rec["species"])]["color"]
	var tone := SideColor.ally()
	var name_col: Color = HudStyle.INK
	var tag := "RIDES HOME"
	var tag_col := col
	if st == "stolen":
		tone = HudStyle.HURT
		name_col = HudStyle.MUTED
		tag = "STOLEN"
		tag_col = HudStyle.HURT
	H._rounded(box, back, 8, Color(tone if st == "stolen" else col, 0.7), 1)
	icon(H, rec, col, tone, at)
	HudStyle.text(H.c, text_at, String(rec.get("name", "Boki")), 11, name_col, 3)
	var tw: float = HudStyle.BIG.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	HudStyle.text(H.c, Vector2(box.end.x - 6.0 - tw, box.position.y + 16.0), tag, 10, tag_col, 3)

## `s` drawn at most `room` px wide: font 11 shrinking to 9, then cut with an ellipsis. Returns [text, size].
static func fit(s: String, room: float) -> Array:
	for fs in [11, 10, 9]:
		if TextCache.width(HudStyle.BIG, s, fs) <= room:
			return [s, fs]
	var t := s
	while t.length() > 1 and TextCache.width(HudStyle.BIG, t + "…", 9) > room:
		t = t.left(t.length() - 1)
	return [t.strip_edges() + "…", 9]
