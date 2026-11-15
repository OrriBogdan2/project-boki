class_name MapKey
extends RefCounted
## The key in the corner of the full map: one icon and one word for each kind of marker the map is showing
## right now (nothing it isn't). The icons are the ones the maps draw. The minimap never calls this.
## tools/minimap_check.gd asserts that kinds() is exactly what is on the map.

const ROW_H := 20.0
const KEY_W := 78.0       # px: icon column, gap and the word
const PAD := 10.0
const WORD_PX := 13
const MARGIN := 14.0      # px from the map's corner
const ICON_X := 16.0      # px from the panel's left edge to the icon's centre

## Every kind, in the order the key lists it: [id, word].
const KINDS := [["squad", "Squad"], ["boki", "Boki"], ["exit", "Exit"], ["hot", "Hot"], ["stop", "Stop"]]

## The ids of the kinds on the map now, in KINDS order.
static func kinds(m: Match, tm: TrainMap) -> Array:
	var out: Array = []
	for k in KINDS:
		if _shown(m, String(k[0]), tm):
			out.append(String(k[0]))
	return out

static func _mate(m: Match) -> Hunter:
	for h in m.hunters:
		if m.player and h != m.player and h.team == m.player.team and not h.out and not h.extracted:
			return h
	return null

static func _shown(m: Match, id: String, tm: TrainMap) -> bool:
	match id:
		"squad": return _mate(m) != null
		"boki": return BokiHud.mapped_kin(m) != null
		"exit": return m.exits != null and not m.exits.list.is_empty()
		"hot": return m.biomes != null and not m.biomes.hot.zone.is_empty()
		_: return m.skytrain != null and not tm.halts(m.skytrain).is_empty()
	return false

## Bottom-left of the map, over the sea: a dark panel, a row per kind.
static func draw(fm: FullMap) -> void:
	var m: Match = fm.m
	var hud = fm.hud
	var c: Control = hud.c
	var ids := kinds(m, hud.train_map)
	if ids.is_empty():
		return
	var r := Rect2(Vector2.ZERO, Vector2(KEY_W + PAD, PAD + ids.size() * ROW_H))
	r.position = Vector2(fm.rect.position.x + MARGIN, fm.rect.end.y - MARGIN - r.size.y)
	hud._rounded(r, Color(0.04, 0.05, 0.08, 0.88), 8)
	for i in ids.size():
		var at := r.position + Vector2(ICON_X, PAD * 0.5 + (i + 0.5) * ROW_H)
		_glyph(fm, ids[i], at)
		hud._text(at + Vector2(14.0, 5.0), _word(ids[i]), WORD_PX, fm.INK, hud.big)

static func _word(id: String) -> String:
	for k in KINDS:
		if k[0] == id:
			return String(k[1])
	return id

static func _glyph(fm: FullMap, id: String, at: Vector2) -> void:
	var m: Match = fm.m
	var c: Control = fm.hud.c
	match id:
		"squad":
			c.draw_circle(at, 6.5, Color(0, 0, 0, 0.6))
			c.draw_circle(at, 5.0, m.mate_col(_mate(m)))
		"boki":
			var k := BokiHud.mapped_kin(m)
			c.draw_circle(at, MapDetail.ICON_R, Color(0, 0, 0, 0.6))
			Icons.draw(c, "paw", at, MapDetail.ICON_R * 0.8, Color(k.sp.get("glow", k.sp["color"])))
		"exit":
			fm.hud._draw_exit_icon(at, m.exits.list[0])
		"hot":
			c.draw_arc(at, 6.0, 0.0, TAU, 24, Color(HotZone.COL, 0.85), 2.5)
		"stop":
			TrainMap.halt_glyph(c, at)
