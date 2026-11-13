class_name ShopLegend
extends RefCounted
## The full map's shop and area legend: each vendor's icon, name and stock theme (with its mark on
## the map and the minimap), then each region's drop lean from BiomeRun (slot_lean_at / rarity_bonus_at data).

const SLOT_WORDS := {"glove": "gloves", "passive": "gloves", "armor": "armor", "boots": "boots"}
const ROW_H := 31.0
const ROW_COMPACT := 18.0   # px: a one-line row, when the two-line legend doesn't fit the screen
const HEAD_H := 22.0
const TOP_MIN := 284.0      # px: below the minimap and the clock chips that show through the map
const PAD := 14.0

## One row per region on the map: {kind: "area", name, text, col, icon, pos}.
static func area_rows(m) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for isl in m.world.islands:
		var b := String(isl.get("biome", ""))
		if b == "" or seen.has(b) or not m.biomes.defs.has(b):
			continue
		seen[b] = true
		var def: Dictionary = m.biomes.defs[b]
		out.append({"kind": "area", "name": String(def.get("name", b)), "text": lean_text(def),
			"col": Color(String(def.get("tint", "ffffff"))), "icon": "", "pos": Vector3.INF})
	return out

## "gloves and armor more likely" and a rarity note, from a biome's loot data.
static func lean_text(def: Dictionary) -> String:
	var loot: Dictionary = def.get("loot", {})
	var words: Array = []
	var slots: Dictionary = loot.get("slots", {})
	for k in SLOT_WORDS:
		if float(slots.get(k, 1.0)) > 1.0 and not words.has(SLOT_WORDS[k]):
			words.append(SLOT_WORDS[k])
	var text := ""
	if not words.is_empty():
		text = ", ".join(words) + " more likely"
	if int(loot.get("rarity_bonus", 0)) > 0:
		text += ("; " if text != "" else "") + "rarer loot"
	return text if text != "" else "no particular lean"

## Marks every vendor on the map itself (the drop map too).
static func markers(fm, c: Control) -> void:
	for v in Shops.list(fm.m):
		var pv: Vector2 = fm.to_screen(v["pos"])
		if fm.rect.grow(-6.0).has_point(pv):
			badge(c, pv, 11.0, String(v["theme"]))

## Vendors on the minimap: a detail kind (MapDetail "shop"), so on the ground only the ones in view.
static func minimap(hud, to_map: Callable, on_map: Callable, hold: bool) -> void:
	var p: Hunter = hud.m.player
	for v in Shops.list(hud.m):
		var near := p != null and p.flat_dist(v["pos"]) < MapDetail.GROUND_R
		var pv: Vector2 = to_map.call(v["pos"])
		if MapDetail.shows("shop", hold, near) and on_map.call(pv, 6.0):
			badge(hud.c, pv, MapDetail.ICON_R * 1.3, String(v["theme"]))

## A vendor's round badge: its stock's icon in its colour on a dark disc.
static func badge(c: Control, pv: Vector2, r: float, theme_id: String) -> void:
	var th := ShopStock.theme(theme_id)
	var col := Color(String(th["col"]))
	c.draw_circle(pv, r, Color(0.04, 0.05, 0.09, 0.9))
	c.draw_arc(pv, r, 0.0, TAU, 24, col, maxf(1.5, r * 0.18), true)
	Icons.draw(c, String(th["icon"]), pv, r * 0.64, col)

## How tall the legend wants to be, with rows of row_h.
static func height(m, row_h := ROW_H) -> float:
	return HEAD_H * 2.0 + row_h * Shops.legend_rows(m).size() + PAD

## Where the legend goes in the left column: under the squad panel, never above TOP_MIN; one-line
## rows when the full legend would run past bottom.
static func place(m, x: float, width: float, below: float, bottom: float) -> Rect2:
	var top := maxf(below + 10.0, TOP_MIN)
	var h := height(m)
	if top + h > bottom:
		h = height(m, ROW_COMPACT)
	return Rect2(Vector2(x, top), Vector2(width, h))

## The legend panel in r: SHOPS (icon, name, theme) then AREAS (name, lean).
static func draw(fm, c: Control, r: Rect2) -> void:
	var hud = fm.hud
	hud._rounded(r, Color(0.04, 0.05, 0.08, 0.88), 12)
	var rows := Shops.legend_rows(fm.m)
	var compact := r.size.y < height(fm.m)
	var y := r.position.y + 20.0
	var last := ""
	for row in rows:
		if row["kind"] != last:
			last = String(row["kind"])
			var head := "SHOPS" if last == "shop" else "AREAS: WHAT DROPS MORE"
			hud._text(Vector2(r.position.x + 14, y), head, 14, HudStyle.GOLD, hud.big)
			y += HEAD_H - 4.0
		var col: Color = row["col"]
		var x := r.position.x + 14.0
		if String(row["icon"]) != "":
			Icons.draw(c, String(row["icon"]), Vector2(x + 9, y + 4), 8.0, col)
		else:
			c.draw_circle(Vector2(x + 9, y + 4), 4.0, col)
		if compact:
			hud._text(Vector2(x + 28, y + 2), "%s  ·  %s" % [row["name"], row["text"]], 12, col)
			y += ROW_COMPACT
			continue
		hud._text(Vector2(x + 28, y), String(row["name"]), 14, col, hud.big)
		hud._text(Vector2(x + 28, y + 14), String(row["text"]), 11, HudStyle.INK)
		y += ROW_H
