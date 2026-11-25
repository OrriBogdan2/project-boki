class_name ClockRow
extends RefCounted
## Under the minimap: ONE compact row, the way the reference reads, with a thin progress line under it for how far
## through the match you are. Left to right: the sky (a dot in its colour, its short name and, in haze, how far you
## see), the tide's phase (a clock icon and its short words), the ring's next close, then the time left and your run
## level on the right. What does not fit the row is dropped from the right of the chips, the phase last. The squad
## frames hang right under it (Hud.mm_bottom).

const W := 262.0  # units (1280x720 layout), the row's width: the squad frames and the objective card share its edge
const H := 22.0  # units, the row
const GAP := 8.0  # units under the minimap
const LINE_GAP := 3.0  # units between the row and its progress line
const LINE_H := 2.0
const CHIP_PX := 10  # px, the chips' words
const TIME_PX := 15  # px, the time left
const LV_PX := 11  # px
const PAD := 8.0  # units inside the row's ends
const CHIP_GAP := 8.0
const LOW_S := 30.0  # s left: the clock and the phase turn red
const PROG_COL := Color("b9a6ff")
const ALERT_H := 16.0  # units, the "outside the ring" pill under the line


## Draws the row and its line, and sets hud.mm_bottom to what hangs under them.
static func draw(hud, mm: Rect2) -> void:
	var m: Match = hud.m
	var left := m.length - m.time
	var low := left < LOW_S
	var r := Rect2(Vector2(mm.position.x, mm.end.y + GAP), Vector2(W, H))
	hud._rounded(r, Color(0.04, 0.05, 0.08, 0.86), 8)
	var c: CanvasItem = hud.c
	var base := r.position.y + 15.0
	var lv_x := r.end.x - PAD
	if m.player:
		var lt := "LV %d" % m.player.lvl
		lv_x -= TextCache.width(HudStyle.BIG, lt, LV_PX)
		HudStyle.text(c, Vector2(lv_x, base), lt, LV_PX, HudStyle.GOLD, 3)
	var time_txt: String = hud._fmt(left)
	var time_x := lv_x - 8.0 - TextCache.width(HudStyle.BIG, time_txt, TIME_PX)
	HudStyle.text(c, Vector2(time_x, base + 1.0), time_txt, TIME_PX, HudStyle.HURT if low else HudStyle.INK, 4)
	var x := r.position.x + PAD
	for chip: Array in _chips(hud, low):
		var w := float(chip[3]) + TextCache.width(HudStyle.BIG, String(chip[0]), CHIP_PX)
		if x + w > time_x - CHIP_GAP:
			break
		if String(chip[2]) == "":
			c.draw_circle(Vector2(x + 4.0, r.get_center().y), 3.5, chip[1])
		else:
			Icons.draw(c, String(chip[2]), Vector2(x + 5.0, r.get_center().y), 5.0, chip[1])
		HudStyle.text(c, Vector2(x + float(chip[3]), base), String(chip[0]), CHIP_PX, chip[1], 3)
		x += w + CHIP_GAP
	var line := Rect2(Vector2(r.position.x + 4.0, r.end.y + LINE_GAP), Vector2(r.size.x - 8.0, LINE_H))
	var prog := clampf(m.time / maxf(1.0, m.length), 0.0, 1.0)
	c.draw_rect(line, Color(1, 1, 1, 0.14))
	c.draw_rect(Rect2(line.position, Vector2(line.size.x * prog, LINE_H)), HudStyle.HURT if low else PROG_COL)
	SafeArea.note(line)
	hud.mm_bottom = line.end.y
	if m.zone and m.zone.outside_text() != "":
		var ar := Rect2(Vector2(r.position.x, line.end.y + 4.0), Vector2(W, ALERT_H))
		hud._rounded(ar, Color(0.25, 0.06, 0.05, 0.85), 6)
		var a := 0.6 + 0.4 * sin(m.time * 8.0)
		HudStyle.text(c, ar.position + Vector2(8.0, 12.0), m.zone.outside_text(), CHIP_PX, Color(HudStyle.HURT, a), 3)
		hud.mm_bottom = ar.end.y
	if m.rolling:
		SessionRow.draw(hud, Rect2(Vector2(r.position.x, hud.mm_bottom + 4.0), Vector2(W, 42.0)))


## The chips in the order they are kept: [words, colour, icon ("" = a dot), x offset of the words].
static func _chips(hud, low: bool) -> Array:
	var m: Match = hud.m
	var out: Array = []
	var phase := "ISLANDS FALLING" if low else HeartHud.zone_line(m).to_upper().replace(" IN ", " ")  # (the tide)
	if phase != "":
		out.append([phase, HudStyle.HURT if low else SideColor.tone("tide_next"), "clock", 14.0])
	if HudReveal.on(m, "weather"):
		var col: Color = RaidLook.COLORS.get(m.raid, HudStyle.INK)
		var sky := String(RaidLook.NAMES.get(m.raid, m.raid)).get_slice(" ", 0).to_upper()
		if m.sight_k < 0.99:
			sky += " %d%%" % int(round(m.sight_k * 100.0))
		out.push_front([sky, col, "", 11.0])
	if m.zone and HudReveal.on(m, "weather"):
		out.append([m.zone.row_text(hud), ShrinkZone.COL, "", 11.0])
	return out
