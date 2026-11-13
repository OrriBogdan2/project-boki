class_name PlanQuiet
extends RefCounted
## The full map for a new player: matches 1 to 3 show only the map, the timer, the hot zone and the
## jump key. The legend, the Ways Out list and the squad panel wait behind one key (map_info).
## From match 4 on the whole screen shows (docs/UI_FIRST15.md section 5 item 4).

const QUIET_MATCHES := 3       # matches played before the legend and lists show by themselves

## True while the full map should stay quiet: a new player, and the key not pressed.
static func on(fm: FullMap) -> bool:
	return int(Save.d.get("matches", 0)) < QUIET_MATCHES and not fm.info

const ROWS := [["jump", "Jump off the ship"], ["map_info", "Legend and ways out"]]

## Where the key card sits: right of the map, where the legend would start (empty if it would not fit).
static func panel(fm: FullMap, sz: Vector2) -> Rect2:
	var x0 := fm.rect.end.x + 22.0
	var wv := minf(FullMap.SIDE_W, sz.x - x0 - 14.0)
	if wv < 150.0:
		return Rect2()
	return Rect2(Vector2(x0, fm.rect.position.y), Vector2(wv, 22 + ROWS.size() * 32))

## Two key rows where the legend would be: jump, and the key that brings the rest back.
static func draw(fm: FullMap, sz: Vector2) -> void:
	var r := panel(fm, sz)
	if r.size.x <= 0.0:
		return
	var rows := ROWS
	fm.hud._rounded(r, Color(0.04, 0.05, 0.08, 0.88), 12)
	var y := r.position.y + 18.0
	for row in rows:
		var cap := Settings.key_cap(String(row[0]))
		var cw: float = fm.hud.big.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0
		var kr := Rect2(Vector2(r.position.x + 14, y), Vector2(maxf(28.0, cw), 24))
		fm.hud._rounded(kr, Color(1, 1, 1, 0.12), 5, Color(1, 1, 1, 0.3), 1)
		fm.hud._ctext(kr.get_center() + Vector2(0, 5), cap, 13, FullMap.INK, fm.hud.big)
		fm.hud._text(Vector2(kr.end.x + 8, y + 17), String(row[1]), 12, FullMap.INK)
		y += 32.0
