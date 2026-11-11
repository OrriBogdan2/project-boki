class_name BuffStack
extends RefCounted
## What is on you right now, as a vertical stack of small icons on the right edge (hero-ref/HUD.md
## section 3). Each icon has a ring that drains with the time left and a count when it stacks. Only
## active things show (DECISIONS 11-08 "show only what's needed"); past MAX_ICONS the rest are "+N".
## Data-driven: content/rules/buff_stack.json names the fields to read on the Hunter, its kit and
## its kin buffs, so a new kit's status needs a row there and no code here.

const MAX_ICONS := 6
const TILE := 36.0         # px, one icon
const GAP := 6.0           # px between icons
const EDGE := 14.0         # px from the screen's right edge
const TOP := 250.0         # px from the top: under the counters and the kill feed
const RING_W := 3.0        # px, the draining ring

static var ROWS: Array = []

static func _static_init() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/buff_stack.json"))
	ROWS = d["rows"] if typeof(d) == TYPE_DICTIONARY else []

var peak := {}             # row id -> the most time it has had left (what the ring drains from)
var shown: Array = []      # what the last frame drew: [{id, name, stacks, frac}, ...]
var more := 0              # how many active rows did not fit

static func _field(o: Object, f: String) -> float:
	return float(o.get(f)) if o != null and f in o else 0.0

## [value, seconds left] of one row for this hunter ([0, 0] when it does not apply).
static func read(h: Hunter, row: Dictionary) -> Array:
	match String(row.get("on", "hunter")):
		"buff":
			var b: Array = h.kbuffs.get(row["value"], [0.0, 0.0])
			return [float(b[0]), float(b[1])]
		"owner":
			var n := 0
			for stat in KinParts.OWNER_STATS:
				if h.owner_stat(stat) > 0.0: n += 1
			return [float(n), 0.0]
		"kit":
			if h.ak == null or h.arch != String(row["arch"]):
				return [0.0, 0.0]
			return _read_on(h.ak, row)
	return _read_on(h, row)

static func _read_on(o: Object, row: Dictionary) -> Array:
	var left := _field(o, String(row.get("time", "")))
	return [_field(o, String(row["value"])) if row.has("value") else left, left]

## Every active row, in file order: {id, name, icon, col, stacks, left, frac}.
func active(h: Hunter) -> Array:
	var out: Array = []
	var live := {}
	for row in ROWS:
		var v := read(h, row)
		if float(v[0]) <= 0.0:
			continue
		var id := String(row["id"])
		live[id] = true
		var left := float(v[1])
		peak[id] = maxf(left, float(peak.get(id, 0.0))) if left > 0.0 else 0.0
		out.append({"id": id, "name": row["name"], "icon": row["icon"], "col": Color(String(row["col"])),
			"stacks": int(floor(float(v[0]))) if row.get("stacks", false) else 1, "left": left,
			"frac": clampf(left / float(peak[id]), 0.0, 1.0) if left > 0.0 else 1.0})
	for id in peak.keys():
		if not live.has(id): peak.erase(id)
	return out

## Draws the stack down the right edge of a screen `sz` wide, under TOP.
func draw(hud, p: Hunter, sz: Vector2) -> void:
	shown = []
	more = 0
	if p.out or p.downed or p.extracted:
		return
	var rows := active(p)
	more = maxi(0, rows.size() - MAX_ICONS)
	var c: CanvasItem = hud.c
	var x := sz.x - EDGE - TILE
	var y := TOP
	for r in rows.slice(0, MAX_ICONS):
		_tile(c, Rect2(Vector2(x, y), Vector2(TILE, TILE)), r)
		shown.append({"id": r["id"], "name": r["name"], "stacks": r["stacks"], "frac": r["frac"]})
		y += TILE + GAP
	if more > 0:
		HudStyle.ctext(c, Vector2(x + TILE * 0.5, y + 12.0), "+%d" % more, 14, HudStyle.MUTED)

static func _tile(c: CanvasItem, r: Rect2, row: Dictionary) -> void:
	var col: Color = row["col"]
	var mid := r.get_center()
	c.draw_style_box(HudStyle.box(HudStyle.SHADE, 8, Color(col, 0.55), 1), r)
	var rad := TILE * 0.5 - RING_W
	c.draw_arc(mid, rad, 0.0, TAU, 28, Color(1, 1, 1, 0.12), RING_W * 0.6, true)
	c.draw_arc(mid, rad, -PI * 0.5, -PI * 0.5 + TAU * float(row["frac"]), 28, col, RING_W, true)
	Icons.draw(c, String(row["icon"]), mid, TILE * 0.22, col)
	if int(row["stacks"]) > 1:
		HudStyle.count_badge(c, r.end - Vector2(4, 4), int(row["stacks"]), col)
