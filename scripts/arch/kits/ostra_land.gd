class_name OstraLand
extends RefCounted
## Where Motley's Lantern Trade puts him: he can throw it onto high, hard-to-reach ledges and get there, and it
## never leaves him inside a wall. The world is a terrace heightmap plus blocker tiles (rocks, trees,
## walls: never standable) and dynamic walls (some standable stones). The lantern lands on the top surface under
## the cursor; a cursor just in front of a higher terrace (pointing at the cliff face) lands on that terrace's top.
## The spot is then settled: if his body would overlap a wall, rock or cliff there, the nearest free spot on the
## same ledge is taken, else the nearest free one stepping back along the throw, else where he threw from.
## Over the abyss the lantern keeps the height it was thrown at (the Trade's float, unchanged).

const LIP := 1.0  # m: a cursor this close in front of a higher terrace counts as aimed at its top
const LIP_STEP := 0.1  # m between the samples looking for that terrace
const EDGE_IN := 0.15  # m past his radius he lands in from the terrace's edge
const RING_STEP := 0.25  # m between the rings searched round a blocked spot...
const RING_MAX := 1.5  # ...out to this far
const RING_N := 12  # spots on each ring
const BACK_STEP := 0.25  # m between the spots tried stepping back along the throw
const HIGH := 1.0e6  # a height above everything (StoneStand's "the top under a falling body")


## The landing for a throw from `from` at the target `to` (xz already clamped to reach) by a body of radius r.
static func spot(m: Match, from: Vector3, to: Vector3, r: float) -> Vector3:
	return settle(m, onto_ledge(m, from, top(m, to, r, from.y), r), from, r)


## The surface at (p.x, p.z): the terrace, or a standable stone on it; over the abyss, height `void_y`.
static func top(m: Match, p: Vector3, r: float, void_y: float) -> Vector3:
	var g: float = m.world.ground_at(p.x, p.z)
	if g <= World.VOID + 1.0:
		return Vector3(p.x, void_y, p.z)
	return Vector3(p.x, StoneStand.top_under(m.world.dyn_walls, Vector3(p.x, HIGH, p.z), r, g), p.z)


## A target on low ground just short of a higher terrace (the cursor on its face) moves up onto that terrace,
## EDGE_IN past his radius from the edge, so throwing at a cliff lands on its top.
static func onto_ledge(m: Match, from: Vector3, p: Vector3, r: float) -> Vector3:
	var d := Vector2(p.x - from.x, p.z - from.z)
	if d.length() < 0.01 or m.world.is_void(p.x, p.z):
		return p
	d = d.normalized()
	var s := LIP_STEP
	while s <= LIP:
		var q := Vector3(p.x + d.x * s, p.y, p.z + d.y * s)
		var g: float = m.world.ground_at(q.x, q.z)
		if m.world.is_block(q.x, q.z):
			return p
		if g > p.y + World.STEP:
			var inn := s + r + EDGE_IN
			return top(m, Vector3(p.x + d.x * inn, 0, p.z + d.y * inn), r, p.y)
		s += LIP_STEP
	return p


## Can a body of radius r stand at p (feet at p.y) without overlapping a rock, tree, wall or cliff?
static func fits(m: Match, p: Vector3, r: float) -> bool:
	return m.world.occupy(p.x, p.z, r, p.y, false) == 0.0


## The nearest free spot to `want`: there; else round it on ground at least as high (it stays on the ledge);
## else back along the throw toward `from`; else `from` itself.
static func settle(m: Match, want: Vector3, from: Vector3, r: float) -> Vector3:
	if fits(m, want, r):
		return want
	var pb: Vector2 = m.world.push_out_blocks(want.x, want.z, r, want.y)
	var q := top(m, Vector3(pb.x, 0, pb.y), r, want.y)
	if q.y >= want.y - World.STEP and fits(m, q, r):
		return q
	var rad := RING_STEP
	while rad <= RING_MAX:
		for k in RING_N:
			var a := TAU * k / RING_N
			q = top(m, Vector3(want.x + cos(a) * rad, 0, want.z + sin(a) * rad), r, want.y)
			if q.y >= want.y - World.STEP and fits(m, q, r):
				return q
		rad += RING_STEP
	var back := Vector2(from.x - want.x, from.z - want.z)
	var n := int(back.length() / BACK_STEP)
	for i in range(1, n + 1):
		var u := float(i) / n
		q = top(m, Vector3(want.x + back.x * u, 0, want.z + back.y * u), r, lerpf(want.y, from.y, u))
		if fits(m, q, r):
			return q
	return from
