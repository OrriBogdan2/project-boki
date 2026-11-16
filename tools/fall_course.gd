extends World
## --move-feel-check's fall course (tools/fall_carry_rows.gd): the live world, with one straight test lane
## laid over a patch of open sky. Along the lane (+x from `at`) the ground is a run of straight pieces
## [from u (m), height at u (m), rise per metre], so a ledge, a deep drop, a slope of any angle or a
## wall to mantle is a row of numbers. Everywhere else is the map as it was.

const LANE_HALF := 1.5      # m: half the lane's width (the body's ground probes stay inside it)
const LANE_LEN := 44.0      # m: long enough for a 10 m/s knock over a 15 m fall

var at := Vector2.ZERO      # the lane's start (x, z centre line)
var pieces: Array = []      # [[u0, y0, grade], ...] sorted by u0 (set through lay_pieces)
var _was := {}              # tile index -> [kind, level] before the lane stamped it

## The open-sky patch where the lane fits, or Vector2.INF: whole tiles of sky round the lane.
func find_lane() -> Vector2:
	var span := int(LANE_LEN) + 2
	for z in range(3, h - 3):
		for x in range(1, w - span - 1):
			if _sky(x, z, span):
				return Vector2(x + 1, z + 0.5)
	return Vector2.INF

func _sky(x0: int, z0: int, span: int) -> bool:
	for z in range(z0 - 3, z0 + 4):
		for x in range(x0, x0 + span):
			if kind[idx(x, z)] != T_VOID:
				return false
	return true

## Lays this row's ground ([] clears the lane). A whole tile of flat ground on a whole terrace becomes a real
## ground tile too: the match's ledge rise reads tiles (Hunter._try_ledge_grab), not ground_at.
func lay_pieces(list: Array) -> void:
	for i in _was:
		kind[i] = _was[i][0]
		level[i] = _was[i][1]
	_was.clear()
	pieces = list
	if list.is_empty():
		return
	for tx in range(int(at.x), int(at.x + LANE_LEN)):
		var g := ground_at(tx + 0.01, at.y)
		var lv := g / LEVEL
		if absf(ground_at(tx + 0.99, at.y) - g) > 0.001 or absf(lv - roundf(lv)) > 0.001 or lv < 0.0:
			continue
		for tz in range(int(floor(at.y - LANE_HALF)), int(floor(at.y + LANE_HALF))):
			var i := idx(tx, tz)
			_was[i] = [kind[i], level[i]]
			kind[i] = T_GROUND
			level[i] = int(roundf(lv))

func _in_lane(x: float, z: float) -> bool:
	var u := x - at.x
	return not pieces.is_empty() and absf(z - at.y) <= LANE_HALF and u >= 0.0 and u <= LANE_LEN

## No wind road or updraft blows in the lane: nothing but the movement code moves the body.
func wind_at(p: Vector3) -> Dictionary:
	return {} if _in_lane(p.x, p.z) else super(p)

func updraft_at(p: Vector3) -> Dictionary:
	return {} if _in_lane(p.x, p.z) else super(p)

func ground_at(x: float, z: float) -> float:
	if not _in_lane(x, z):
		return super(x, z)
	var u := x - at.x
	var g := VOID
	for p in pieces:
		if u >= float(p[0]):
			g = float(p[1]) + float(p[2]) * (u - float(p[0]))
	return g
