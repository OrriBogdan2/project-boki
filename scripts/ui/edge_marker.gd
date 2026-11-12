class_name EdgeMarker
extends RefCounted
## The one screen-edge marker: an arrow on the rim of a rectangle (or the round minimap) pointing at
## something that is off it, in the caller's colour, with an optional label and distance. Callers
## add() what they want shown during a frame; draw() lays the markers out on the rim, the highest
## priority at its true angle and the rest slid along the rim until none overlaps, then draws them.

const PRIO_LOW := 0      # pings, sound
const PRIO_ALLY := 1     # squadmates and their boxes, rival hunters
const PRIO_GOAL := 2     # where to go: uplinks, the Heart, the Gate, beacons, the tutorial
const GAP := 6.0         # px kept clear between two markers along the rim
const LABEL_PX := 16     # label font size, px
const LABEL_H := 22.0    # px a label line takes
const LABEL_GAP := 12.0  # px between an arrow and its label
const BADGE_DY := 18.0   # px a downed Wisp's ring sits above its label
const BADGE_R := 10.0    # px radius of that ring

var _ctr := Vector2.ZERO
var _half := Vector2.ZERO        # half the rim rectangle's width and height (px)
var _radius := 0.0               # > 0: the rim is a circle of this radius round _ctr
var _size := 4.0                 # arrow scale: its tip is 1.4 and its wings 0.8 of this, px
var _items: Array[Dictionary] = []

## The safe box world markers sit on: under the tutorial panel, above the ability bar.
static func world_rim(sz: Vector2) -> Rect2:
	var half := Vector2(sz.x * 0.5 - 70.0, sz.y * 0.24)
	return Rect2(Vector2(sz.x * 0.5, sz.y * 0.47) - half, half * 2.0)

## Start a frame's markers on `rim` (a circle of `radius` round its centre when radius > 0).
func begin(rim: Rect2, arrow: float, radius := 0.0) -> void:
	_ctr = rim.get_center()
	_half = rim.size * 0.5
	_radius = radius
	_size = arrow
	_items.clear()

## A marker for something in direction `dir` (screen px, any length) from the rim's centre. `downed`: a
## Wisp whose bleed-out ring (DownedMarks.badge) is drawn above the label.
func add(dir: Vector2, col: Color, prio := PRIO_ALLY, label := "", dist := -1.0, downed: Hunter = null) -> void:
	if dir.length() < 0.1:
		return
	var text := label
	if dist >= 0.0:
		text = "%s  %dm" % [label, int(round(dist))]
	_items.append({"d": dir.normalized(), "col": col, "prio": prio, "text": text, "downed": downed})

## Lay the markers out: sets each one's "pos" and "rect" (arrow plus label); returns them.
func layout() -> Array[Dictionary]:
	_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["prio"] > b["prio"])
	var placed: Array[Dictionary] = []
	for it in _items:
		it["s"] = _slot(it, placed)
		_fix(it)
		placed.append(it)
	return placed

func draw(c: CanvasItem, time := 0.0) -> void:
	for it in layout():
		var d: Vector2 = it["d"]
		var p: Vector2 = it["pos"]
		var col: Color = it["col"]
		if it["text"] != "":      # a dark shadow keeps a world marker readable over the ground
			c.draw_colored_polygon(_arrow(p, d, _size * 1.25), Color(0, 0, 0, 0.5))
			HudStyle.ctext(c, _label_at(it, p) + Vector2(0, 5), it["text"], LABEL_PX, col, 3)
		if it["downed"] != null:
			DownedMarks.badge(c, _label_at(it, p) - Vector2(0, BADGE_DY), it["downed"], SideColor.ALLY, time, BADGE_R)
		c.draw_colored_polygon(_arrow(p, d, _size), col)

func _arrow(p: Vector2, d: Vector2, k: float) -> PackedVector2Array:
	var side := Vector2(-d.y, d.x)
	return PackedVector2Array([p + d * 1.4 * k, p - d * 0.4 * k + side * 0.8 * k, p - d * 0.4 * k - side * 0.8 * k])

## Where along the rim (px from its top-left, clockwise) the item sits free of the ones already placed,
## nearest its true angle.
func _slot(it: Dictionary, placed: Array[Dictionary]) -> float:
	var want := _rim_s(it["d"])
	var ext := _extent(it, want)
	var best := want
	var best_gap := INF
	var tries: Array[float] = [want]
	for o in placed:
		var step: float = float(o["ext"]) + ext + GAP + 0.5      # (+0.5: float slack, so the slot tests clear)
		tries.append(float(o["s"]) + step)
		tries.append(float(o["s"]) - step)
	for s in tries:
		var wrapped := fposmod(s, _rim_len())
		if _clear(wrapped, ext, placed) and _rim_dist(wrapped, want) < best_gap:
			best = wrapped
			best_gap = _rim_dist(wrapped, want)
	it["ext"] = ext
	return best

func _clear(s: float, ext: float, placed: Array[Dictionary]) -> bool:
	for o in placed:
		if _rim_dist(s, float(o["s"])) < float(o["ext"]) + ext + GAP:
			return false
	return true

## Half the room the item needs along the rim: its label's width on the top and bottom, else its
## height, plus how far the label is pushed along the rim by the arrow's slant.
func _extent(it: Dictionary, s: float) -> float:
	var arrow := _size * 1.4
	if it["text"] == "":
		return arrow
	var d: Vector2 = it["d"]
	var w := _half.x * 2.0
	var flat := _radius <= 0.0 and (s < w or (s >= w + _half.y * 2.0 and s < 2.0 * w + _half.y * 2.0))
	var along := absf(d.x if flat else d.y) * (arrow + LABEL_GAP)
	return maxf(arrow, (_label_w(it) if flat else LABEL_H) * 0.5 + along)

func _label_w(it: Dictionary) -> float:
	return TextCache.width(HudStyle.BIG, it["text"], LABEL_PX)

## The label sits this far inside the arrow, along -d.
func _label_at(it: Dictionary, p: Vector2) -> Vector2:
	return p - (it["d"] as Vector2) * (_size * 1.4 + LABEL_GAP)

func _fix(it: Dictionary) -> void:
	var p := _rim_at(float(it["s"]))
	it["pos"] = p
	var box := Rect2(p - Vector2.ONE * _size * 1.4, Vector2.ONE * _size * 2.8)
	if it["text"] != "":
		var w := _label_w(it)
		box = box.merge(Rect2(_label_at(it, p) - Vector2(w, LABEL_H) * 0.5, Vector2(w, LABEL_H)))
	it["rect"] = box

func _rim_len() -> float:
	return TAU * _radius if _radius > 0.0 else 4.0 * (_half.x + _half.y)

func _rim_dist(a: float, b: float) -> float:
	var g := absf(a - b)
	return minf(g, _rim_len() - g)

## Rim position (px along it) where the ray from the centre along d crosses it.
func _rim_s(d: Vector2) -> float:
	if _radius > 0.0:
		return fposmod(atan2(d.y, d.x), TAU) * _radius
	var w := _half.x * 2.0
	var h := _half.y * 2.0
	var tx := _half.x / maxf(0.001, absf(d.x))
	var ty := _half.y / maxf(0.001, absf(d.y))
	var e := _half + d * minf(tx, ty)      # the rim point, from the top-left corner
	if ty <= tx:
		return clampf(e.x, 0.0, w) if d.y < 0.0 else w + h + clampf(w - e.x, 0.0, w)
	return w + clampf(e.y, 0.0, h) if d.x > 0.0 else 2.0 * w + h + clampf(h - e.y, 0.0, h)

func _rim_at(s: float) -> Vector2:
	if _radius > 0.0:
		var a := s / _radius
		return _ctr + Vector2(cos(a), sin(a)) * _radius
	var w := _half.x * 2.0
	var h := _half.y * 2.0
	var tl := _ctr - _half
	if s < w:
		return tl + Vector2(s, 0.0)
	if s < w + h:
		return tl + Vector2(w, s - w)
	if s < 2.0 * w + h:
		return tl + Vector2(w - (s - w - h), h)
	return tl + Vector2(0.0, h - (s - 2.0 * w - h))
