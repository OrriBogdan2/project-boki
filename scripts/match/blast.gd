class_name Blast
extends RefCounted
## How a shot's explosion lands on one body (Match._boom): a share of its damage by distance from the centre
## (content/rules/blast.json "curve") and nothing at all through rock or a cliff (the line from the blast, World.los).

const RULES_PATH := "res://content/rules/blast.json"
static var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))


## The share of a blast's damage (0..1) at `frac` of its radius: the first point's before it, the last's past the edge.
static func curve_k(frac: float) -> float:
	var pts: Array = rules["curve"]
	if frac <= float(pts[0][0]):
		return float(pts[0][1])
	for i in range(1, pts.size()):
		var x1 := float(pts[i][0])
		if frac <= x1:
			var x0 := float(pts[i - 1][0])
			return lerpf(float(pts[i - 1][1]), float(pts[i][1]), (frac - x0) / (x1 - x0))
	return float(pts[-1][1])


## The share of a blast's damage that reaches `e` from a blast at `at` of `radius`: the curve at its distance, 0 when
## rock or a cliff stands between (unless `open`).
static func share(w: World, at: Vector3, e: Ent, radius: float, open := false) -> float:
	if not open and not w.los(at, e.pos, maxf(at.y, e.pos.y) + float(rules["cover_height"])):
		return 0.0
	return curve_k(Vector2(e.pos.x - at.x, e.pos.z - at.z).length() / radius)
