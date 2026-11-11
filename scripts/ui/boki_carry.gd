class_name BokiCarry
extends RefCounted
## The rest of what you carry, in the right-side Boki box's column (DECISIONS 2026-11-11 "carry 2 in, 1 extra out",
## Boki HUD): above the lead box, nearest first, one row each and only while it is in use:
##   second   your second Boki (Hunter.kin2): portrait, health, its carry passive's icon, and the swap key
##            (Settings.key_cap "swap_kin") with a ring that fills while the swap cools down
##   carry    the carry-out slot (Hunter.caught): the Boki you claimed, riding home. An empty outline while you
##            scan one; STOLEN when a rival took it from your deathbox (KinPair.robbed)
## The wisps you stole (BokiHud.stolen_wisps) stack above these. `shown` is what the last draw put on screen.

const ROW_W := BokiHud.STOLEN_W      # px: a row is as wide and as high as a stolen wisp's, right edge on the box's
const ROW_H := BokiHud.STOLEN_H
const ROW_GAP := 3.0       # px between rows
const ICON_PX := BokiHud.STOLEN_ICON      # px: the critter's side
const HP_W := 56.0         # px: the health bar
const HP_H := 5.0          # px
const KEY_R := 11.0        # px: the swap ring's radius round the key cap
const GROUP_ICON := {"movement": "dash", "defence": "fortify", "offence": "haymaker"}   # Icons id by passive group
const MISC_ICON := "cloak"

static var shown: Array = []

## One {"kind": "second"|"carry", "state", ...} per row in use. `state`: second "ready" | "wait" (swap cooling)
## | "down"; carry "claimed" | "empty" | "stolen".
static func rows(p: Hunter) -> Array:
	var out: Array = []
	var k2: Kin = p.kin2
	if k2 != null and not k2.dead:
		var full := maxf(0.1, float(Content.rules("kin_ai").get("swap_cooldown", 3.0)))
		out.append({"kind": "second", "kin": k2, "rec": k2.rec, "hp": clampf(k2.hp / maxf(k2.max_hp, 1.0), 0.0, 1.0),
			"cool": clampf(1.0 - p.swap_cd / full, 0.0, 1.0), "stat": _stat(k2),
			"state": "down" if k2.hp <= 0.0 else ("wait" if p.swap_cd > 0.0 else "ready")})
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

## Draws the rows above the box `r` (clear of its chip); returns the height they took, for the stolen rows above.
static func draw(H, p: Hunter, r: Rect2) -> float:
	shown.clear()
	var y := r.position.y - BokiHud.STOLEN_LIFT
	var y0 := y
	for row in rows(p):
		var box := Rect2(Vector2(r.end.x - ROW_W, y - ROW_H), Vector2(ROW_W, ROW_H))
		if String(row["kind"]) == "second":
			_second(H, p, row, box)
		else:
			_carry(H, row, box)
		shown.append({"kind": row["kind"], "state": row["state"], "rect": box, "key": Settings.key_cap("swap_kin")})
		y -= ROW_H + ROW_GAP
	return y0 - y

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
	H._rounded(box, Color(0.03, 0.03, 0.05, 0.85), 8, Color(glow, 0.7), 1)
	icon(H, k.rec, k.sp["color"], SideColor.ally(), box.position + Vector2(ROW_H * 0.5, ROW_H * 0.5))
	var bar := Rect2(box.position + Vector2(ROW_H + 4.0, ROW_H * 0.5 - HP_H * 0.5), Vector2(HP_W, HP_H))
	HudStyle.strip(H.c, bar, float(row["hp"]), HudStyle.HURT if st == "down" else HudStyle.hp_fill(SideColor.ally(), float(row["hp"]), H.m.time))
	var stat := String(row["stat"])
	if stat != "":
		var grp := String(KinParts.OWNER_STATS[stat][0])
		Icons.draw(H.c, GROUP_ICON.get(grp, MISC_ICON), Vector2(bar.end.x + 14.0, box.get_center().y), 7.0, Color(glow, 0.9))
	var at := Vector2(box.end.x - 20.0, box.get_center().y)
	var key := Settings.key_cap("swap_kin")
	if st == "down":
		HudStyle.text(H.c, at + Vector2(-14.0, 4.0), "DOWN", 11, HudStyle.HURT, 3)
		return
	if st == "wait":
		H.c.draw_arc(at, KEY_R, -PI / 2.0, -PI / 2.0 + TAU * float(row["cool"]), 24, Color(HudStyle.MUTED, 0.9), 2.0, true)
	HudStyle.key_pill(H.c, at, key, glow if st == "ready" else HudStyle.MUTED)

static func _carry(H, row: Dictionary, box: Rect2) -> void:
	var st := String(row["state"])
	var rec: Dictionary = row["rec"]
	var col := HudStyle.MUTED
	if not rec.is_empty():
		col = Data.KIN[String(rec["species"])]["color"]
	var edge: Color = HudStyle.HURT if st == "stolen" else Color(col, 0.7)
	H._rounded(box, Color(0.03, 0.03, 0.05, 0.85 if st != "empty" else 0.5), 8, edge if st != "empty" else Color(HudStyle.MUTED, 0.5), 1)
	var at := box.position + Vector2(ROW_H * 0.5, ROW_H * 0.5)
	if st == "empty":
		H.c.draw_arc(at, ICON_PX * 0.5 + 2.0, 0.0, TAU, 24, Color(HudStyle.MUTED, 0.6), 1.0, true)
		HudStyle.text(H.c, box.position + Vector2(ROW_H + 2.0, 16.0), "Carry out: free", 11, HudStyle.MUTED, 3)
		return
	icon(H, rec, col, HudStyle.HURT if st == "stolen" else SideColor.ally(), at)
	HudStyle.text(H.c, box.position + Vector2(ROW_H + 2.0, 16.0), String(rec.get("name", "Boki")), 11,
			HudStyle.MUTED if st == "stolen" else HudStyle.INK, 3)
	var tag := "STOLEN" if st == "stolen" else "RIDES HOME"
	var tw: float = HudStyle.BIG.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	HudStyle.text(H.c, Vector2(box.end.x - 6.0 - tw, box.position.y + 16.0), tag, 10, HudStyle.HURT if st == "stolen" else col, 3)
