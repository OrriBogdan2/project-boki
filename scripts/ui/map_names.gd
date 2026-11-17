class_name MapNames
extends RefCounted
## The words on a map (the minimap and the full map) never print over each other. A map draw calls begin(),
## queues each word with put() (and reserves the boxes of pills it draws itself with claim()), then flush()
## draws them: the `force` words first (live readouts: a halt's "Next train", a Way Out's timer, the region
## names), each moved a line or two up or down (or aside) inside the map when its box is taken, then the rest in
## order, each skipped when its box would overlap. The boxes are the shaped text's own (TextCache), Text size in.
## A map draws one at a time (the minimap, the full map), so the queue is static.

const PAD := 3.0  # px kept clear on each side of a word
const NUDGE_LINES := [0.0, 1.0, -1.0, 2.0, -2.0, 3.0, -3.0]  # box heights a forced word may move ...
const NUDGE_SIDE := [0.0, 0.6, -0.6]  # ... and box widths, nearest spots first

static var _queue: Array = []  # [txt, at, size, col, font, outline, force]
static var _taken: Array[Rect2] = []
static var _room := Rect2()  # the map's area: a moved word stays inside it


static func begin(room: Rect2) -> void:
	_queue.clear()
	_taken.clear()
	_room = room


## Keeps the words off a box the map draws itself (a pill with its own text).
static func claim(r: Rect2) -> void:
	_taken.append(r)


## A word centred on x at baseline `at.y` (as HudStyle.ctext).
static func put(txt: String, at: Vector2, size: int, col: Color, font: Font, force := false, outline := 4) -> void:
	_queue.append([txt, at, size, col, font, outline, force])


static func flush(c: CanvasItem) -> void:
	for pass_force in [true, false]:
		for e: Array in _queue:
			if bool(e[6]) == pass_force:
				_draw(c, e)
	_queue.clear()


static func _draw(c: CanvasItem, e: Array) -> void:
	var font: Font = e[4]
	var size: int = e[2]
	var at: Vector2 = e[1]
	var tl := TextCache.line(font, e[0], size)
	var sz := tl.get_size()
	var r := Rect2(at + Vector2(-sz.x * 0.5 - PAD, -tl.get_line_ascent()), sz + Vector2(PAD * 2.0, 0))
	var d := Vector2.ZERO
	if bool(e[6]):
		d = _spot(r)
	elif not _free(r):
		return
	_taken.append(Rect2(r.position + d, r.size))
	HudStyle.ctext(c, at + d, e[0], size, e[3], e[5], font)


## The nearest free offset for a forced word's box inside the map; none free: the least covered one.
static func _spot(r: Rect2) -> Vector2:
	var best := Vector2.ZERO
	var best_cover := INF
	for ny: float in NUDGE_LINES:
		for nx: float in NUDGE_SIDE:
			var d := Vector2(nx * r.size.x, ny * r.size.y)
			var moved := Rect2(r.position + d, r.size)
			if d != Vector2.ZERO and not _room.encloses(moved):
				continue
			var cover := _cover(moved)
			if cover <= 0.0:
				return d
			if cover < best_cover:
				best_cover = cover
				best = d
	return best


static func _free(r: Rect2) -> bool:
	return _cover(r) <= 0.0


## Area of `r` under words already drawn.
static func _cover(r: Rect2) -> float:
	var a := 0.0
	for q in _taken:
		if q.intersects(r):
			a += q.intersection(r).get_area()
	return a
