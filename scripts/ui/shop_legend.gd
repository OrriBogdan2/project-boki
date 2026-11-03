class_name ShopLegend
extends RefCounted
## The full map's shop and area legend: each vendor's icon, name and stock theme (with its mark on
## the map), then each region's drop lean from BiomeRun (slot_lean_at / rarity_bonus_at data).

const SLOT_WORDS := {"glove": "gloves", "passive": "passives", "armor": "armour", "boots": "boots"}
const ROW_H := 36.0
const HEAD_H := 30.0

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

## "gloves and armour more likely" and a rarity note, from a biome's loot data.
static func lean_text(def: Dictionary) -> String:
	var loot: Dictionary = def.get("loot", {})
	var words: Array = []
	var slots: Dictionary = loot.get("slots", {})
	for k in SLOT_WORDS:
		if float(slots.get(k, 1.0)) > 1.0:
			words.append(SLOT_WORDS[k])
	var text := ""
	if not words.is_empty():
		text = ", ".join(words) + " more likely"
	if int(loot.get("rarity_bonus", 0)) > 0:
		text += ("; " if text != "" else "") + "rarer loot"
	return text if text != "" else "no particular lean"

## Marks every vendor on the map itself.
static func markers(fm, c: Control) -> void:
	for v in Shops.list(fm.m):
		var th := ShopStock.theme(String(v["theme"]))
		var col := Color(String(th["col"]))
		var pv: Vector2 = fm.to_screen(v["pos"])
		if not fm.rect.grow(-6.0).has_point(pv):
			continue
		c.draw_circle(pv, 11.0, Color(0.04, 0.05, 0.09, 0.9))
		c.draw_arc(pv, 11.0, 0.0, TAU, 24, col, 2.0, true)
		Icons.draw(c, String(th["icon"]), pv, 7.0, col)

## How tall the legend wants to be.
static func height(m) -> float:
	return HEAD_H * 2.0 + ROW_H * Shops.legend_rows(m).size() + 28.0

## The legend panel in r: SHOPS (icon, name, theme) then AREAS (name, lean).
static func draw(fm, c: Control, r: Rect2) -> void:
	var hud = fm.hud
	hud._rounded(r, Color(0.04, 0.05, 0.08, 0.88), 12)
	var rows := Shops.legend_rows(fm.m)
	var y := r.position.y + 24.0
	var last := ""
	for row in rows:
		if row["kind"] != last:
			last = String(row["kind"])
			var head := "SHOPS" if last == "shop" else "AREAS: WHAT DROPS MORE"
			hud._text(Vector2(r.position.x + 14, y), head, 14, HudStyle.GOLD, hud.big)
			y += HEAD_H - 8.0
		var col: Color = row["col"]
		var x := r.position.x + 14.0
		if String(row["icon"]) != "":
			Icons.draw(c, String(row["icon"]), Vector2(x + 9, y + 4), 8.0, col)
		else:
			c.draw_circle(Vector2(x + 9, y + 4), 4.0, col)
		hud._text(Vector2(x + 28, y), String(row["name"]), 14, col, hud.big)
		hud._text(Vector2(x + 28, y + 16), String(row["text"]), 11, HudStyle.INK)
		y += ROW_H
