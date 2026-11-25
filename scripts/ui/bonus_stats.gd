class_name BonusStats
extends RefCounted
## Right edge, under the BuffStack (drawn with it, so it follows it exactly): a small column of what your gear,
## perks and Boki add right now, one row each, a small icon and the value: bonus damage, bonus health, move speed
## and cooldown haste. It reads the same numbers the fight does (Hunter.gear_stat, Hunter.kin_hp_added), so
## nothing here is kept. A row at zero stays in its place, dimmed, so the column never jumps. Staged with
## HudReveal "bonus_stats".

const ROW_H := 15.0  # units (1280x720 layout), one row
const PAD := 5.0  # units inside the backing
const COL_W := 62.0  # units
const GAP := 8.0  # units under the BuffStack
const PX := 11  # px, the values
const ICON_R := 5.0
const DIM := 0.4  # alpha of a zero row
const ROWS := [
	["claw", "dmg", "pct", Color("ff9a8a")],
	["heart", "hp", "flat", Color("8ff0a0")],
	["dash", "speed", "pct", Color("9fdcff")],
	["clock", "cdr", "pct", Color("ffd27a")],
]


## [{icon, text, col, on}] for each row, from the hunter's current numbers.
static func rows(p: Hunter) -> Array:
	var out: Array = []
	for r: Array in ROWS:
		var v := p.gear_stat(String(r[1]))
		if String(r[1]) == "hp":
			v += p.kin_hp_added
		var text := "+%d" % int(round(v)) if String(r[2]) == "flat" else "+%d%%" % int(round(v * 100.0))
		out.append({"icon": r[0], "text": text, "col": r[3], "on": v > 0.0005})
	return out


## The column's rect: right-aligned at the margin, under the buff icons (`below`, the y they end at), kept off the
## gear row above the weapon card.
static func rect(sz: Vector2, below: float) -> Rect2:
	var h := ROW_H * ROWS.size() + PAD * 2.0
	var y := minf(below + GAP, GearPanel.cell_rect(sz, 0).position.y - GAP - h)
	return Rect2(Vector2(SafeArea.frame(sz).end.x - HudStyle.hud_pad(sz).x - COL_W, y), Vector2(COL_W, h))


static func draw(hud, sz: Vector2, p: Hunter) -> void:
	var r := rect(sz, hud.buffs.bottom())
	SafeArea.note_as("bonus_stats", r)
	hud.c.draw_style_box(HudStyle.box(Color(0.04, 0.05, 0.08, 0.6), 8, Color(0, 0, 0, 0), 0), r)
	var rs := rows(p)
	for i in rs.size():
		var row: Dictionary = rs[i]
		var a := 1.0 if row["on"] else DIM
		var y := r.position.y + PAD + ROW_H * float(i)
		Icons.draw(
			hud.c, String(row["icon"]), Vector2(r.position.x + PAD + 7.0, y + ROW_H * 0.5), ICON_R, Color(row["col"], a)
		)
		var w := TextCache.width(HudStyle.BIG, String(row["text"]), PX)
		HudStyle.text(hud.c, Vector2(r.end.x - PAD - w, y + 11.0), String(row["text"]), PX, Color(HudStyle.INK, a), 3)
