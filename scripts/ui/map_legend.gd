class_name MapLegend
extends RefCounted
## The key to the full map (M): a compact corner panel with one icon and one plain word per kind of
## icon the maps draw in THIS match (nothing the match doesn't have). The glyphs are the ones the
## maps draw (FullMap, Hud, ReviveHud, BokiHud call the same functions); the few that were only
## inline there live here (place_glyph). Teammates and your Boki wisp take the HUD's colours.
## tools/map_legend_check.gd fails when a map glyph function has no kind here.

const ROW_H := 18.0
const COL_W := 84.0           # px: glyph, gap and the word
const PAD := 9.0
const MAX_ROWS := 9
const WORD_PX := 12
const PANEL := Color(0.04, 0.05, 0.08, 0.84)
const AMBER := Color("ffb64a")
const PLACE_COLS := {"perch": Color("9af0ff"), "rail": Color("ffcf7a"), "choke": Color("ffb36a")}
# the colours of features that have their own map glyphs (Heart, hot zone, shops: READY branches)
const HEART_COL := Color("ff5d78")
const GATE_COL := Color("ff9aa8")
const TIDE_COL := Color(0.75, 0.2, 0.35, 0.8)
const HOT_COL := Color("ff6a3d")
const ARROW := [Vector2(0, -8), Vector2(5.5, 4), Vector2(0, 1.5), Vector2(-5.5, 4)]    # you, ships: points up
const PIN := [Vector2(0, 6), Vector2(-4, -2), Vector2(4, -2)]
const HEART := [Vector2(0, 7), Vector2(-6.5, -0.5), Vector2(-3.5, -5.5),
	Vector2(0, -2.5), Vector2(3.5, -5.5), Vector2(6.5, -0.5)]

## Every kind of icon the maps can draw: [id, word]. The spawn categories (boss, vault, rare_kin, cache,
## and any a map registers) are matched by id; kinds only some matches have are tested in has().
const KINDS := [
	["you", "You"], ["squad", "Squad"], ["wisp", "Wisp"], ["rival", "Rival"], ["ally", "Ally"],
	["lead", "Lead"], ["ping", "Ping"], ["noise", "Noise"], ["goal", "Goal"],
	["boss", "Boss"], ["lair", "Lair"], ["egg", "Egg"], ["vault", "Vault"], ["rare_kin", "Rare"], ["cache", "Cache"],
	["dock", "Skiff"], ["outpost", "Uplink"], ["hatch", "Hatch"],
	["shrine", "Shrine"], ["beacon", "Beacon"], ["box", "Box"],
	["perch", "Perch"], ["rail", "Stop"], ["choke", "Choke"], ["train", "Train"],
	["ship", "Ship"], ["wave", "Wave"], ["bounty", "Bounty"],
	["heart", "Heart"], ["gate", "Gate"], ["spark", "Spark"], ["blight", "Blight"], ["hot", "Hot"], ["shop", "Shop"]]

## The ids in KINDS present in this match, in order, plus any spawn category the map registers.
static func present(m: Match) -> Array:
	var out: Array = []
	for k in KINDS:
		if has(m, String(k[0])):
			out.append(String(k[0]))
	if m.spawn_plan:
		for cat in m.spawn_plan.shown_cats():
			if not out.has(cat):
				out.append(cat)
	return out

static func word(m: Match, id: String) -> String:
	for k in KINDS:
		if k[0] == id:
			return String(k[1])
	return String(m.spawn_plan.cats.get(id, {}).get("name", id)).get_slice(" ", 0)

static func has(m: Match, id: String) -> bool:
	var p: Hunter = m.player
	match id:
		"you", "ping", "noise", "rival":
			return p != null
		"squad":
			return p != null and m.hunters.any(func(h): return h != p and h.team == p.team)
		"wisp":
			return p != null and p.kin != null
		"ally":
			return m.truce != null
		"lead":
			return m.skydrop != null
		"goal":
			return m.tut != null
		"boss", "vault", "rare_kin", "cache":
			return m.spawn_plan != null and m.spawn_plan.shown_cats().has(id)
		"lair", "egg":
			return m.lairs != null and not m.lairs.list.is_empty()
		"dock", "outpost", "hatch":
			return m.exits != null and m.exits.list.any(func(x): return x["kind"] == id)
		"shrine":
			return not m.shrines.is_empty()
		"beacon":
			return not m.beacons.is_empty()
		"box":
			return p != null
		"perch", "rail", "choke":
			return m.world.labels.any(func(lb): return lb["kind"] == id)
		"train":
			return m.skytrain != null
		"ship":
			return not m.ship.is_empty()
		"wave", "bounty":
			return m.rolling != null
		"heart", "gate", "spark", "blight":
			var ht = m.get("heart")          # (the Heart, a READY branch: absent here)
			return ht != null and ht.site != Vector3.INF
		"hot":
			return m.get("hot") != null
		"shop":
			return m.has_meta("shops") and not (m.get_meta("shops")["list"] as Array).is_empty()
	return false

# ------------------------------------------------------------------ the glyphs that were inline
## A place on a map: a perch (up-arrow), a rail stop (square) or a chokepoint (bowtie), on a dark backing.
## k scales it (the minimap draws at 1.0).
static func place_glyph(c: CanvasItem, kind: String, pv: Vector2, k := 1.0) -> void:
	var col: Color = PLACE_COLS[kind]
	var dark := Color(0, 0, 0, 0.6)
	match kind:
		"perch":
			c.draw_colored_polygon(_at(pv, k, [Vector2(0, -9), Vector2(7, 4), Vector2(-7, 4)]), dark)
			c.draw_colored_polygon(_at(pv, k, [Vector2(0, -7), Vector2(5, 2.5), Vector2(-5, 2.5)]), col)
		"rail":
			c.draw_rect(Rect2(pv - Vector2(4, 4) * k, Vector2(8, 8) * k), dark)
			c.draw_rect(Rect2(pv - Vector2(3, 3) * k, Vector2(6, 6) * k), col)
		"choke":
			for sx in [-1.0, 1.0]:
				c.draw_colored_polygon(_at(pv, k, [Vector2(sx * 6.0, -4.5), Vector2.ZERO, Vector2(sx * 6.0, 4.5)]), col)

static func _at(pv: Vector2, k: float, offsets: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in offsets:
		out.append(pv + (q as Vector2) * k)
	return out

# ------------------------------------------------------------------ the panel
## Where the key goes for n entries: the map's bottom-left corner, in columns of MAX_ROWS.
static func panel(fm: FullMap, n: int) -> Rect2:
	var rows := mini(n, MAX_ROWS)
	var cols := ceili(float(n) / float(maxi(rows, 1)))
	var box := Vector2(cols * COL_W + PAD * 2.0 - 8.0, rows * ROW_H + PAD * 2.0 - 4.0)
	return Rect2(Vector2(fm.rect.position.x + 10.0, fm.rect.end.y - 10.0 - box.y), box)

## The key: one glyph and word per id, only what this match has.
static func draw(fm: FullMap, ids: Array) -> void:
	if ids.is_empty():
		return
	var rows := mini(ids.size(), MAX_ROWS)
	var r := panel(fm, ids.size())
	fm.hud._rounded(r, PANEL, 8, Color(0.85, 0.8, 1.0, 0.25), 1)
	for i in ids.size():
		var at := r.position + Vector2(PAD, PAD + 1.0) + Vector2(floorf(i / float(rows)) * COL_W, (i % rows) * ROW_H)
		glyph(fm, String(ids[i]), at + Vector2(7.0, ROW_H * 0.5 - 1.0))
		fm.hud._text(at + Vector2(22.0, ROW_H * 0.5 + 3.0), word(fm.m, String(ids[i])), WORD_PX, FullMap.INK)

## One kind's glyph at pv, the same drawing the maps use.
static func glyph(fm: FullMap, id: String, pv: Vector2) -> void:
	var c: Control = fm.hud.c
	var m: Match = fm.m
	match id:
		"you":
			c.draw_colored_polygon(_at(pv, 1.0, ARROW), FullMap.INK)
		"squad":
			var mate: Hunter = m.player
			for h in m.hunters:
				if h != m.player and h.team == m.player.team:
					mate = h
					break
			_dot(c, pv, m.mate_col(mate))
		"wisp":
			var kin_col: Color = BokiHud.wisp_col(m.player.kin) if m.player.kin else BokiHud.DOWN_COL
			BokiHud.wisp_glyph(c, pv, kin_col, 5.0, m.time)
		"rival":
			_dot(c, pv, FullMap.BAD)
		"ally":
			_dot(c, pv, Color("f4f1e6"))
		"lead":
			fm.crown(c, pv, FullMap.GOLD)
		"ping":
			var col := m.mate_col(m.player)
			c.draw_colored_polygon(_at(pv, 1.0, PIN), col)
			c.draw_circle(pv + Vector2(0, -3), 4.5, col)
		"noise":
			c.draw_arc(pv, 6.0, 0, TAU, 20, Color("ff9a5a"), 2.0, true)
			c.draw_circle(pv, 2.0, Color("ff9a5a"))
		"goal":
			c.draw_arc(pv, 5.5, 0, TAU, 16, Color("8fe3c8"), 2.5, true)
		"lair":
			fm.hud._lair_icon(pv, {"state": "sealed", "boss": ""}, 0.85)
		"egg":
			c.draw_set_transform(pv, 0.0, Vector2(0.8, 1.05))
			c.draw_circle(Vector2.ZERO, 6.5, Color(0, 0, 0, 0.75))
			c.draw_circle(Vector2.ZERO, 5.0, Color("ffd36a"))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"dock", "outpost", "hatch":
			fm._exit_glyph(c, id, pv, Exits.color_of({"kind": id, "state": "idle", "prog": 0.0}))
		"shrine":
			fm.shrine_glyph(c, pv, 5.5)
		"beacon":
			ReviveHud.beacon_glyph(c, pv, 4.5, {}, 0.0)
		"box":
			ReviveHud.box_glyph(c, pv, 5.0, m.mate_col(m.player), true)
		"perch", "rail", "choke":
			place_glyph(c, id, pv, 1.0)
		"train":
			c.draw_line(pv + Vector2(-9, 0), pv + Vector2(-1, 0), Color(1.0, 0.72, 0.35, 0.8), 2.0, true)
			c.draw_circle(pv + Vector2(5, 0), 3.5, Color("ff5a3a"))
		"ship":
			c.draw_colored_polygon(_at(pv, 1.0, ARROW), FullMap.GOLD)
		"wave":
			c.draw_colored_polygon(_at(pv, 1.0, ARROW), AMBER)
		"bounty":
			fm.hud.bounty_marker(c, pv, 0.85)
		"heart":
			c.draw_arc(pv, 9.0, 0, TAU, 24, Color(HEART_COL, 0.55), 2.0, true)
			c.draw_colored_polygon(_at(pv, 1.0, HEART), Color("b8203f"))
		"gate":
			c.draw_rect(Rect2(pv + Vector2(-6, -6), Vector2(2.7, 12)), GATE_COL)
			c.draw_rect(Rect2(pv + Vector2(3.3, -6), Vector2(2.7, 12)), GATE_COL)
			c.draw_line(pv + Vector2(-6, -6), pv + Vector2(6, -6), GATE_COL, 2.0)
		"spark":
			c.draw_arc(pv, 7.0, 0, TAU, 24, Color(HEART_COL, 0.6), 1.5, true)
			c.draw_circle(pv, 4.5, HEART_COL)
			c.draw_circle(pv, 2.0, Color("ffe6ea"))
		"blight":
			c.draw_arc(pv, 7.0, 0, TAU, 24, TIDE_COL, 2.5, true)
		"hot":
			c.draw_circle(pv, 8.0, Color(HOT_COL, 0.2))
			c.draw_arc(pv, 8.0, 0, TAU, 24, Color(HOT_COL, 0.9), 2.5, true)
			c.draw_circle(pv, 3.0, HOT_COL)
		"shop":
			c.draw_circle(pv, 8.0, Color(0.04, 0.05, 0.09, 0.9))
			c.draw_arc(pv, 8.0, 0.0, TAU, 24, FullMap.GOLD, 2.0, true)
			Icons.draw(c, "gem", pv, 5.0, FullMap.GOLD)
		_:
			var def: Dictionary = m.spawn_plan.cats.get(id, {}) if m.spawn_plan else {}
			fm.marker(c, String(def.get("shape", "star")), pv, 6.0, def.get("col", Color.WHITE), "active")

static func _dot(c: CanvasItem, pv: Vector2, col: Color) -> void:
	c.draw_circle(pv, 6.0, Color(0, 0, 0, 0.6))
	c.draw_circle(pv, 4.5, col)
