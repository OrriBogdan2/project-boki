extends RefCounted
## Hunter-vs-background contrast for --clarity-shots (docs/COMBAT_CLARITY.md "Hunter against the ground"). Pictures
## of one frame: `with` as played, `bare` with the Hunters' bodies taken out (their shadows kept), and the bodies
## drawn alone (`solo`, against `empty`: the same camera drawing nothing) for a clean silhouette, so grass, VFX and
## shader-time flicker never pass for a Hunter. At each step across a silhouette the score is the strongest colour
## step there (RGB distance, 0-100): the body's edge pixel or the one just outside it (where an outline or rim
## sits), against the bare ground a step farther out. A Hunter's score is the mean over its edge; a frame's is the
## mean over its Hunters.

const STEP := 2  # px between samples
const DIFF := 0.1  # most-changed channel (0-1) above which a pixel of `solo` is a body's
const MIN_EDGE := 30  # edge samples a Hunter needs to count (one behind a rock has none)


## The mean silhouette contrast of the Hunters in `boxes` (screen px), or -1.0 when none shows an edge.
static func frame_score(with: Image, bare: Image, solo: Image, empty: Image, boxes: Array[Rect2]) -> float:
	var sum := 0.0
	var n := 0
	var img := Rect2i(Vector2i.ZERO, with.get_size()).grow(-2 * STEP)
	for box in boxes:
		var s := _edge([with, bare, solo, empty], Rect2i(box).intersection(img))
		if s >= 0.0:
			sum += s
			n += 1
	return sum / n if n > 0 else -1.0


static func _edge(pics: Array, r: Rect2i) -> float:
	var with: Image = pics[0]
	var bare: Image = pics[1]
	var sum := 0.0
	var n := 0
	for y in range(r.position.y, r.end.y - STEP, STEP):
		for x in range(r.position.x, r.end.x - STEP, STEP):
			var here := Vector2i(x, y)
			for d: Vector2i in [Vector2i(STEP, 0), Vector2i(0, STEP)]:
				var in_here := _body(pics, here)
				if in_here == _body(pics, here + d):
					continue
				var body: Vector2i = here if in_here else here + d
				var out: Vector2i = body + d if in_here else body - d  # the first pixel outside the body
				var ground: Vector2i = out + (out - body)  # and the ground beyond it
				if _body(pics, ground):
					continue
				var g := bare.get_pixelv(ground)
				sum += maxf(_dist(with.get_pixelv(body), g), _dist(with.get_pixelv(out), g))
				n += 1
	return sum / n if n >= MIN_EDGE else -1.0


static func _body(pics: Array, p: Vector2i) -> bool:
	var a: Color = (pics[2] as Image).get_pixelv(p)
	var b: Color = (pics[3] as Image).get_pixelv(p)
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b)) > DIFF


static func _dist(a: Color, b: Color) -> float:
	return 100.0 * Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() / sqrt(3.0)
