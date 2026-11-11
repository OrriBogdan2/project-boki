extends RefCounted
## --edge-marker-check: the one screen-edge marker (scripts/ui/edge_marker.gd).
##   1. two markers at the same edge angle, on the world's rectangular rim (with labels) and on the
##      minimap's round one, do not overlap: the lower priority slides along the rim
##   2. the higher priority keeps the true angle; a lone marker sits on the rim exactly where it points
##   3. a crowd of markers close together never overlaps on either rim
## Never touches the save.

const ANGLES := [0.0, 0.7, -1.57, 2.3, 3.14, 3.9]      # rad: right, down-right, up, down-left, left, up-left
const MINI := Rect2(Vector2(10, 10), Vector2(180, 180))
const MINI_R := 90.0      # px: the round minimap's rim

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("EDGEMARK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _overlaps(items: Array[Dictionary]) -> int:
	var n := 0
	for i in items.size():
		for j in range(i + 1, items.size()):
			if (items[i]["rect"] as Rect2).intersects(items[j]["rect"]):
				n += 1
	return n

## A rim to test: the world's (labelled markers, a radius of 0) or the minimap's (round, bare arrows).
func _rim(e: EdgeMarker, world: bool) -> void:
	if world:
		e.begin(EdgeMarker.world_rim(Vector2(1920, 1080)), 16.0)
	else:
		e.begin(MINI, 4.0, MINI_R)

func _add(e: EdgeMarker, world: bool, dir: Vector2, col: Color, prio: int, i: int) -> void:
	if world:
		e.add(dir, col, prio, "Marker %d" % i, 10.0 * i)
	else:
		e.add(dir, col, prio)

func run(main: Node) -> void:
	var e := EdgeMarker.new()
	for world in [true, false]:
		var rid := "world" if world else "minimap"
		for ang in ANGLES:
			var dir := Vector2.from_angle(ang)
			_rim(e, world)
			_add(e, world, dir, Color.RED, EdgeMarker.PRIO_LOW, 4)
			_add(e, world, dir, Color.GREEN, EdgeMarker.PRIO_GOAL, 9)
			var two := e.layout()
			ok(_overlaps(two) == 0, "%s rim, angle %.1f: two markers at one angle do not overlap" % [rid, ang])
			var apart := (two[0]["pos"] as Vector2).distance_to(two[1]["pos"]) > 1.0
			var slid := "%s rim, angle %.1f: the goal keeps its place, the other slides" % [rid, ang]
			ok(two[0]["col"] == Color.GREEN and apart, slid)
		_rim(e, world)
		e.add(Vector2.RIGHT, Color.WHITE)
		var lone: Vector2 = e.layout()[0]["pos"]
		var edge_x := MINI_R if not world else EdgeMarker.world_rim(Vector2(1920, 1080)).size.x * 0.5
		var ctr: Vector2 = MINI.get_center() if not world else EdgeMarker.world_rim(Vector2(1920, 1080)).get_center()
		ok(lone.is_equal_approx(ctr + Vector2(edge_x, 0.0)), "%s rim: a lone marker sits on the rim at its angle" % rid)
		_rim(e, world)
		for i in 8:
			_add(e, world, Vector2.from_angle(0.1 * i), Color.WHITE, i % 3, i)
		ok(_overlaps(e.layout()) == 0, "%s rim: eight markers close together do not overlap" % rid)
	print("EDGEMARK DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)
