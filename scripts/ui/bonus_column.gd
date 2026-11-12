class_name BonusColumn
extends RefCounted
## The slim stat-bonus column on the right edge, above the gear column (the owner's 11-12 reference
## lists the Hunter's bonuses there): one leaning plate per active bonus, a number and its icon.
## Nothing is computed here: every value is Hunter.gear_stat (gear and boots, perks, the Boki's carry
## passives), so the column always agrees with the stat code. A bonus that is zero draws no row, and an
## empty column draws nothing (decision: show only what is needed). Hold Tab for what each row means.
## Measured sizes are in HUD_SPEC.md.

## Stat key (Hunter.gear_stat) -> icon. Flat stats show a plain number, the rest a percent.
const STATS := [["dmg", "burst"], ["speed", "jump"], ["cdr", "pulse"], ["glide_speed", "gust"], ["heat", "breeze"],
	["reload", "rifle"], ["dodge", "dash"], ["tonic", "tonic"], ["gems", "gem"], ["sight", "disc"],
	["armor", "fortify"], ["hp", "heart"]]
const FLAT := ["armor", "hp"]
const PITCH := 19.0         # px between row centres
const PLATE_H := 16.0       # px, the leaning plate behind a row
const FOOT_Y := 556.0       # px of the 720 layout: the lowest row's centre (clear of the gear column's upgrade line)
const ICON_X := 11.0        # px from the right edge to the icon's centre
const ICON_S := 4.0         # icon scale (the icon is 2 * this wide)
const NUM_RIGHT := 21.0     # px from the right edge to where the number ends
const NUM_FS := 11          # number font size
const PLATE_PAD := 8.0      # px of plate left of the number
const PLATE_A := 0.55       # plate opacity (the frame colour, a little lighter than the vitals' plate)
const TIP_W := 210.0        # px, the Tab tooltip
const TIP_ROW := 20.0       # px per tooltip row

## The active rows, top to bottom: [{key, text, label, icon}], text the number as drawn, label the plain words.
static func rows(p: Hunter) -> Array:
	var out: Array = []
	for s in STATS:
		var key: String = s[0]
		var v := p.gear_stat(key)
		var label := Gear.stat_label(key, v)
		if label == "":
			continue
		var n := int(round(v)) if FLAT.has(key) else int(round(v * 100.0))
		out.append({"key": key, "text": ("%+d" if FLAT.has(key) else "%+d%%") % n, "label": label, "icon": s[1]})
	return out

## Rect of the plate for row i of n at a screen size (the column grows up from its foot).
static func plate_rect(sz: Vector2, i: int, n: int, text: String) -> Rect2:
	var w := TextCache.width(HudStyle.BIG, text, NUM_FS) + NUM_RIGHT - 3.0 + PLATE_PAD
	var y := sz.y - 720.0 + FOOT_Y - float(n - 1 - i) * PITCH - PLATE_H * 0.5
	return Rect2(sz.x - 3.0 - w, y, w, PLATE_H)

static func draw(hud, sz: Vector2, p: Hunter) -> void:
	var rs := rows(p)
	for i in rs.size():
		var r := plate_rect(sz, i, rs.size(), rs[i]["text"])
		HudStyle.slant(hud.c, r.position, r.size.x, r.size.y, Color(HudStyle.FRAME, PLATE_A))
		var cy := r.get_center().y
		var col := HudStyle.INK if not String(rs[i]["text"]).begins_with("-") else HudStyle.HURT
		Icons.draw(hud.c, rs[i]["icon"], Vector2(sz.x - ICON_X, cy), ICON_S, Color(col, 0.9))
		var w := TextCache.width(HudStyle.BIG, rs[i]["text"], NUM_FS)
		HudStyle.lean_text(hud.c, Vector2(sz.x - NUM_RIGHT - w, cy + 4.0), rs[i]["text"], NUM_FS, col, 3)

## While Tab is held: a small panel left of the column naming every bonus in words.
static func draw_tip(hud, sz: Vector2, p: Hunter) -> void:
	var rs := rows(p)
	if rs.is_empty():
		return
	var h := 14.0 + float(rs.size()) * TIP_ROW
	var top := plate_rect(sz, 0, rs.size(), "")
	var box := Rect2(Vector2(sz.x - 30.0 - TIP_W, top.position.y - 7.0), Vector2(TIP_W, h))
	hud._rounded(box, Color(0.05, 0.06, 0.09, 0.92), 8, Color(HudStyle.GOLD, 0.5), 1)
	for i in rs.size():
		var y := box.position.y + 7.0 + (i + 0.5) * TIP_ROW
		Icons.draw(hud.c, rs[i]["icon"], Vector2(box.position.x + 16.0, y), ICON_S, HudStyle.INK)
		hud._text(Vector2(box.position.x + 32.0, y + 5.0), rs[i]["label"], 13, HudStyle.INK, hud.body)
