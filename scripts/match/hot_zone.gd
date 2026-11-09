class_name HotZone
extends RefCounted
## The match's hot drop zone: one named area per match whose loot is one rarity step better, drawn
## on the drop map and the minimap in one colour with a label. content/rules/hot_zone.json.
## The region id is picked once (by the host online, in the lobby's "start" message) and every
## game builds the same zone from it.

## The zone the previous match used in this game, so the same one never comes up twice in a row.
static var last_id := ""
static var _rules := {}

var id := ""
var isl := -1                    # the island's index in World.islands
var _w: World

static func rules() -> Dictionary:
	if _rules.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/hot_zone.json"))
		_rules = d if d is Dictionary else {}
	return _rules

static func color() -> Color:
	return Color(String(rules()["color"]))

## A region id from a layout's islands (JSON dicts): any named area but the perches, by seed.
## Empty when the layout has none.
static func pick(layout_islands: Array, seed_val: int) -> String:
	var ids: Array = []
	for d in layout_islands:
		if String(d.get("name", "")) != "" and String(d.get("role", "")) != "perch" and String(d["id"]) != last_id:
			ids.append(String(d["id"]))
	if ids.is_empty():
		return ""
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|hot_zone" % seed_val)
	return ids[r.randi_range(0, ids.size() - 1)]

func _init(w: World, region_id: String) -> void:
	_w = w
	for i in w.islands.size():
		if String(w.islands[i].get("id", "")) == region_id:
			id = region_id
			isl = i
	if isl >= 0:
		last_id = id

func active() -> bool:
	return isl >= 0

func zone_name() -> String:
	return String(_w.islands[isl]["name"])

func contains(p: Vector3) -> bool:
	return isl >= 0 and _w.island_of(p.x, p.z) == isl

## Rarity steps this spot's loot gains: the tier-up inside the zone, nothing anywhere else.
func bonus_at(p: Vector3) -> int:
	return int(rules()["tier_up"]) if contains(p) else 0

func center() -> Vector3:
	var c: Vector2 = _w.islands[isl]["c"]
	return Vector3(c.x, 0.0, c.y)

func radius() -> float:
	return float(_w.islands[isl]["r"])

## One marker, shared by both maps: a tinted disc, a pulsing ring and the label above it.
## px_r is the disc's radius on screen; a small one (the close minimap) is just a ring and a dot.
func paint(hud, at: Vector2, px_r: float, labelled: bool) -> void:
	var col := color()
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.004)
	if px_r >= 14.0:
		hud.c.draw_circle(at, px_r, Color(col, 0.16))
	hud.c.draw_arc(at, maxf(px_r, 7.0), 0.0, TAU, 40, Color(col, 0.55 + 0.4 * pulse), 2.5, true)
	hud.c.draw_circle(at, 3.0, col)
	if labelled:
		hud._ctext(at + Vector2(0, -maxf(px_r, 7.0) - 14.0), String(rules()["label"]), 13, col, hud.big)

## On the minimap: the whole zone while riding or dropping; on the ground a ring at its centre
## when it is in view, else an arrow at the rim pointing to it.
func paint_mini(hud, inner: Rect2, to_map: Callable, on_map: Callable, whole: bool) -> void:
	var pv: Vector2 = to_map.call(center())
	if not on_map.call(pv, 4.0):
		hud._edge_arrow(inner, inner.get_center(), pv, color())
		return
	paint(hud, pv, radius() * (inner.size.x / _w.w) if whole else 0.0, whole)
