extends RefCounted
## Hunter-vs-background contrast for --clarity-shots (docs/COMBAT_CLARITY.md "Hunter against the ground"). Two pictures
## of one frame: `with` as played and `bare` with every Hunter and Boki hidden. A pixel that differs between them is
## a Hunter's; along each Hunter's silhouette the metric is the colour distance (RGB, 0-100) from a Hunter pixel to
## the bare ground beside it. A Hunter's score is the mean over its edge; a frame's is the mean over its Hunters.

const STEP := 2  # px between samples (the box scan reads 2 neighbours a sample)
const DIFF := 0.05  # most-changed channel (0-1) above which a pixel is the Hunter's
const MIN_EDGE := 30  # edge samples a Hunter needs to count (one behind a rock has none)


## The mean silhouette contrast of the Hunters in `boxes` (screen px), or -1.0 when none shows an edge.
static func frame_score(with: Image, bare: Image, boxes: Array[Rect2]) -> float:
	var sum := 0.0
	var n := 0
	for box in boxes:
		var s := _edge(with, bare, Rect2i(box).intersection(Rect2i(Vector2i.ZERO, with.get_size())))
		if s >= 0.0:
			sum += s
			n += 1
	return sum / n if n > 0 else -1.0


static func _edge(with: Image, bare: Image, r: Rect2i) -> float:
	var sum := 0.0
	var n := 0
	for y in range(r.position.y, r.end.y - STEP, STEP):
		for x in range(r.position.x, r.end.x - STEP, STEP):
			var in_here := _is_hunter(with, bare, x, y)
			for d in [Vector2i(STEP, 0), Vector2i(0, STEP)]:
				var in_next := _is_hunter(with, bare, x + d.x, y + d.y)
				if in_here == in_next:
					continue
				var body := with.get_pixel(x, y) if in_here else with.get_pixel(x + d.x, y + d.y)
				var ground := bare.get_pixel(x + d.x, y + d.y) if in_here else bare.get_pixel(x, y)
				sum += _dist(body, ground)
				n += 1
	return sum / n if n >= MIN_EDGE else -1.0


static func _is_hunter(with: Image, bare: Image, x: int, y: int) -> bool:
	var a := with.get_pixel(x, y)
	var b := bare.get_pixel(x, y)
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b)) > DIFF


static func _dist(a: Color, b: Color) -> float:
	return 100.0 * Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() / sqrt(3.0)
