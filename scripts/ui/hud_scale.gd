class_name HudScale
extends RefCounted
## "HUD size" (Settings > Accessibility, 80-130%). Each HUD group (a registered panel, see SafeArea.begin) is
## drawn scaled about the corner or edge it hangs from, so it stays on its margin and grows inward. Groups
## that share an anchor scale together, so their spacing holds. Growing never takes a corner cluster into
## the one on the same side under or over it (top-left minimap and squad vs bottom-left vitals): the factor
## steps down to what the last pass's extents leave room for, never below 100%.

const MIN := 0.8
const MAX := 1.3
const GAP := 8.0          # logical px kept between a top cluster and the bottom one it grows toward

const TL := Vector2(0.0, 0.0)
const TC := Vector2(0.5, 0.0)
const TR := Vector2(1.0, 0.0)
const BL := Vector2(0.0, 1.0)
const BC := Vector2(0.5, 1.0)
const BR := Vector2(1.0, 1.0)
const ANCHOR := {"top": TR, "feed": TR, "minimap": TL, "squad": TL, "boss": TC, "ways_strip": TC,
		"vitals": BL, "abilities": BL, "kin": BL, "status": BC, "weapon": BR, "gear": BR, "perks": BC}

static var xf := Transform2D.IDENTITY      # what the group being drawn is under (identity between passes)
static var _anchor := TL
static var _hover_from := 0
static var _ext := {}      # anchor -> the unscaled rect its groups covered in the last pass
static var _next := {}

static func setting() -> float:
	return clampf(float(Settings.get_v("hud_scale")), MIN, MAX)

## Start drawing `group` on hud.c: its scale and the rects it registers follow its anchor. Returns the group
## that was being drawn, for a widget that hangs from somewhere else to hand back to.
static func begin(hud, group: String, sz: Vector2) -> String:
	var back := SafeArea.group
	close(hud)
	SafeArea.begin(group)
	_anchor = ANCHOR[group]
	_hover_from = hud.hover_spots.size()
	var box := SafeArea.inner(sz)
	var at := box.position + box.size * _anchor
	var s := _factor(box)
	xf = Transform2D(0.0, Vector2(s, s), 0.0, at * (1.0 - s))
	hud.c.draw_set_transform_matrix(xf)
	return back

## The hover spots the group registered move with it; back to the plain canvas.
static func close(hud) -> void:
	for i in range(_hover_from, hud.hover_spots.size()):
		hud.hover_spots[i][0] = xf * (hud.hover_spots[i][0] as Rect2)
	_hover_from = hud.hover_spots.size()
	xf = Transform2D.IDENTITY
	hud.c.draw_set_transform_matrix(xf)

static func pass_start() -> void:
	_next.clear()
	_hover_from = 0
	xf = Transform2D.IDENTITY

static func pass_end() -> void:
	_ext = _next.duplicate()

## A rect the current group drew (unscaled).
static func grow(r: Rect2) -> void:
	_next[_anchor] = (_next[_anchor] as Rect2).merge(r) if _next.has(_anchor) else r

# Things drawn outside the panels that keep clear of them (message lane, edge markers, the Blight line) give
# way by the setting's growth (never below 100%: shrinking leaves room).
static func up() -> float:
	return maxf(1.0, setting())

## `px` measured in from a side margin, as it is once the HUD has grown.
static func from_edge(px: float) -> float:
	return SafeArea.MARGIN + (px - SafeArea.MARGIN) * up()

static func from_bottom(y: float, sz: Vector2) -> float:
	return sz.y - from_edge(sz.y - y)

## How far `r` (a centre-lane line: the Blight line, the Gate prompt) must rise, 0 or less, to stay clear of the
## bottom-left groups as they are once grown, where it would touch them sideways.
static func lift(r: Rect2, sz: Vector2) -> float:
	var grown := _grown_bl(sz)
	if grown.size == Vector2.ZERO:
		return 0.0
	if grown.position.x >= r.end.x or grown.end.x <= r.position.x or grown.position.y >= r.end.y:
		return 0.0
	return minf(grown.position.y - GAP - r.end.y, 0.0)

## How far `r` must move right (0 or more) to clear the bottom-left groups as they are once grown.
static func nudge_right(r: Rect2, sz: Vector2) -> float:
	var grown := _grown_bl(sz)
	if not grown.intersects(r.grow(GAP)):
		return 0.0
	return maxf(grown.end.x + GAP - r.position.x, 0.0)

static func _grown_bl(sz: Vector2) -> Rect2:
	if not _ext.has(BL):
		return Rect2()
	var box := SafeArea.inner(sz)
	var at := box.position + box.size * BL
	var e: Rect2 = _ext[BL]
	return Rect2(at + (e.position - at) * up(), e.size * up())

static func _factor(box: Rect2) -> float:
	var s := setting()
	if s <= 1.0 or not _ext.has(_anchor) or not _ext.has(Vector2(_anchor.x, 1.0 - _anchor.y)) or _anchor.y == 0.5:
		return s
	var mine: Rect2 = _ext[_anchor]
	var other: Rect2 = _ext[Vector2(_anchor.x, 1.0 - _anchor.y)]
	var depth := (mine.end.y - box.position.y) if _anchor.y == 0.0 else (box.end.y - mine.position.y)
	depth += (other.end.y - box.position.y) if _anchor.y == 1.0 else (box.end.y - other.position.y)
	return minf(s, maxf((box.size.y - GAP) / depth, 1.0))
