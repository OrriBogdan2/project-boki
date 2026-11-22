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
const CARD_PAD := 8.0      # px, inside the hover card

static var ROWS: Array = []

static func _static_init() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/buff_stack.json"))
	ROWS = d["rows"] if typeof(d) == TYPE_DICTIONARY else []

var peak := {}             # row id -> the most time it has had left (what the ring drains from)
var shown: Array = []      # what the last frame drew: [{id, name, src, left, stacks, frac, rect}, ...]
var more := 0              # how many active rows did not fit
var carded: Array = []     # ids whose card the last frame drew

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

## Every active row, in file order: {id, name, src, icon, col, stacks, left, frac}.
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
		out.append({"id": id, "name": row["name"], "src": row["src"], "icon": row["icon"],
			"col": Color(String(row["col"])), "left": left,
			"stacks": int(floor(float(v[0]))) if row.get("stacks", false) else 1,
			"frac": clampf(left / float(peak[id]), 0.0, 1.0) if left > 0.0 else 1.0})
	for id in peak.keys():
		if not live.has(id): peak.erase(id)
	return out

## Draws the stack down the right edge of a screen `sz` wide, under TOP.
func draw(hud, p: Hunter, sz: Vector2) -> void:
	shown = []
	carded = []
	more = 0
	if p.out or p.downed or p.extracted:
		return
	var rows := active(p)
	more = maxi(0, rows.size() - MAX_ICONS)
	var c: CanvasItem = hud.c
	var x := sz.x - EDGE - TILE
	var y := TOP
	for r in rows.slice(0, MAX_ICONS):
		var rect := Rect2(Vector2(x, y), Vector2(TILE, TILE))
		_tile(c, rect, r)
		shown.append({"id": r["id"], "name": r["name"], "src": r["src"], "left": r["left"], "stacks": r["stacks"],
			"frac": r["frac"], "rect": rect, "col": r["col"]})
		y += TILE + GAP
	if more > 0:
		HudStyle.ctext(c, Vector2(x + TILE * 0.5, y + 12.0), "+%d" % more, 14, HudStyle.MUTED)
	var all: bool = Input.is_action_pressed("scores") or (hud.pack_panel != null and hud.pack_panel.visible)
	var at: Vector2 = c.get_local_mouse_position()
	for r in shown:
		if all or (r["rect"] as Rect2).has_point(at):
			_card(c, r)
			carded.append(r["id"])
			if not all:
				var tip := "Hold %s: every status" % Settings.key_cap("scores")
				var tip_w := TextCache.width(HudStyle.BIG, tip, 11)
				var tip_at: Vector2 = (r["rect"] as Rect2).end - Vector2(TILE + GAP + tip_w, -12.0)
				HudStyle.text(c, tip_at, tip, 11, HudStyle.MUTED, 3)

## What the hover card says about a row: the status name, then where it comes from and the seconds left.
static func card_lines(r: Dictionary) -> Array:
	var left := float(r["left"])
	var when := "%.1f s left" % left if left > 0.0 else "while it lasts"
	return [String(r["name"]), "%s, %s" % [r["src"], when]]

## The card to the left of an icon: its name over its source and time. Every card shows while Tab
## (the scores key) is held or the backpack is open; otherwise only the hovered icon's.
static func _card(c: CanvasItem, r: Dictionary) -> void:
	var lines := card_lines(r)
	var w := maxf(TextCache.width(HudStyle.BIG, lines[0], 13), TextCache.width(HudStyle.BIG, lines[1], 11))
	var rect := r["rect"] as Rect2
	var box := Rect2(Vector2(rect.position.x - GAP - w - CARD_PAD * 2.0, rect.position.y),
		Vector2(w + CARD_PAD * 2.0, TILE))
	c.draw_style_box(HudStyle.box(HudStyle.SHADE, 8, Color(r["col"], 0.55), 1), box)
	HudStyle.text(c, box.position + Vector2(CARD_PAD, 15.0), lines[0], 13, HudStyle.INK, 3)
	HudStyle.text(c, box.position + Vector2(CARD_PAD, 29.0), lines[1], 11, HudStyle.MUTED, 3)

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
