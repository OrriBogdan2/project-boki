class_name PracticeMap
extends RefCounted
## The practice tools on the full map (M) in the Training Grounds, the Arena and the Test Zone: the dummies and
## the sparring bot as red rings, the stations as small diamonds (one per perch), and a legend card with a row
## for each kind that is really there. Called by FullMap (the map and its legend).

const RING_R := 6.0  # px: a dummy's or the bot's ring
const STATION_R := 5.0  # px: half a station diamond
const ROW_H := 24.0  # px: one legend row
const HEAD_H := 44.0  # px: the card's title


## Every ring on the map: the dummies and the bot.
static func _targets(m: Match) -> Array:
	var out: Array = m.arena.dummies.map(func(d: Dictionary) -> Hunter: return d["h"])
	if m.arena.bot != null:
		out.append(m.arena.bot)
	return out


static func _stations(m: Match) -> Array:
	return m.arena.grounds.stations if m.arena.grounds != null else []


## The legend rows that exist: [kind, text].
static func rows(m: Match) -> Array:
	var out: Array = []
	if m.arena == null:
		return out
	if not m.arena.dummies.is_empty():
		out.append(["dummy", "Practice dummy"])
	if m.arena.bot != null:
		out.append(["dummy", "Sparring bot"])
	if not _stations(m).is_empty():
		out.append(["station", "Station: gear and tools"])
	return out


static func full_map(fm: FullMap) -> void:
	var m: Match = fm.m
	if m.arena == null:
		return
	var c: Control = fm.hud.c
	var seen := {}
	for st in _stations(m):
		var mid: Vector3 = st["c"]
		var pv: Vector2 = fm.to_screen(mid)
		if not seen.has(mid) and fm.rect.grow(-4.0).has_point(pv):
			seen[mid] = true      # (a perch's pedestals ring its middle: one diamond for the perch)
			_diamond(c, pv, Grounds.color_of(st["kind"], st["id"]))
	for h in _targets(m):
		var pv: Vector2 = fm.to_screen(h.pos)
		if not h.out and fm.rect.grow(-4.0).has_point(pv):
			c.draw_arc(pv, RING_R, 0.0, TAU, 16, SideColor.foe(), 2.0)


## The legend card at `at` (width `w`); returns its box.
static func card(fm: FullMap, at: Vector2, w: float) -> Rect2:
	var c: Control = fm.hud.c
	var list := rows(fm.m)
	var r := Rect2(at, Vector2(w, HEAD_H + list.size() * ROW_H + 8.0))
	fm.hud._rounded(r, Color(0.04, 0.05, 0.08, 0.88), 12)
	fm.hud._text(r.position + Vector2(14, 26), "PRACTICE", 16, FullMap.GOLD, fm.hud.big)
	var y := r.position.y + HEAD_H + 8.0
	for row in list:
		var pv := Vector2(r.position.x + 26, y)
		if row[0] == "station":
			_diamond(c, pv, FullMap.GOLD)
		else:
			c.draw_arc(pv, RING_R, 0.0, TAU, 16, SideColor.foe(), 2.0)
		fm.hud._text(Vector2(r.position.x + 48, y + 5), String(row[1]), 12, FullMap.INK)
		y += ROW_H
	return r


static func _diamond(c: Control, pv: Vector2, col: Color) -> void:
	var up := Vector2(0, STATION_R)
	var side := Vector2(STATION_R, 0)
	var pts := PackedVector2Array([pv - up, pv + side, pv + up, pv - side])
	c.draw_colored_polygon(pts, Color(col, 0.9))
	c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.7), 1.0)
