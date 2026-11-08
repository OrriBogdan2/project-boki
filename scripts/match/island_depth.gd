class_name IslandDepth
## How deep each sky island reaches below its top: a tall rock underside that tapers from the coast
## down to a point under the middle, stepped into ledges every few metres (the owner's
## 11-08 playtest). One height per tile, from the tile grid alone, so the drawn underside (TerrainMesh),
## the collision (World.occupy) and the deep catch (Hunter._try_ledge_grab) all agree, on the server
## too. Numbers: content/rules/tuning.json "islands".

const RIM := 1.5      # m: how far an island's outer cliff drops before the rock underneath tapers in
const HEAD := 1.6     # m: a body's height against an underside (feet at y, head at y + HEAD)

static var T: Dictionary = Tuning.of("islands")

## Per tile: the height of the island's underside below it (0 on void tiles).
static func fill(W: World) -> PackedFloat32Array:
	var w := W.w
	var h := W.h
	var under := PackedFloat32Array()
	under.resize(w * h)
	var d := _coast_dist(W)
	var reach := {}
	for i in w * h:
		if d[i] > 0.0:
			reach[W.island[i]] = maxf(float(reach.get(W.island[i], 1.0)), d[i] - 0.5)
	var rn := FastNoiseLite.new()
	rn.seed = 77
	rn.frequency = 0.9
	var band: float = T["ledge_every_m"]
	for i in w * h:
		if d[i] <= 0.0:
			continue
		var x := i % w
		var z := i / w
		var R: float = maxf(1.5, float(reach.get(W.island[i], 1.5)))
		var deep := clampf(float(T["deep_base_m"]) + R * float(T["deep_per_reach"]), T["deep_min_m"], T["deep_max_m"])
		var t := clampf((d[i] - 0.5) / R, 0.0, 1.0)
		var taper := deep * pow(t, float(T["taper_pow"])) * (1.0 + rn.get_noise_2d(x * 0.31 + 50.0, z * 0.31) * 0.2)
		# ledges: each band of rock ends in a shelf, so the side reads as climbable strata
		var k := taper / band
		taper = band * (floorf(k) + smoothstep(1.0 - float(T["ledge_riser"]), 1.0, k - floorf(k)))
		var rim := RIM + rn.get_noise_2d(x * 0.45, z * 0.45) * 0.35
		under[i] = W.level[i] * World.LEVEL - rim - float(T["cliff_m"]) - taper
	return under

## Per tile: the smoothed distance (tiles) to the nearest void tile, 0 on the void (and bridges).
static func _coast_dist(W: World) -> PackedFloat32Array:
	var w := W.w
	var h := W.h
	var d := PackedFloat32Array()
	d.resize(w * h)
	for i in w * h:
		d[i] = 0.0 if W.kind[i] == World.T_VOID or W.bridge.has(i) else 1.0e6
	var dg := 1.4142
	# two-pass chamfer distance
	for z in h:
		for x in w:
			var i: int = z * w + x
			if d[i] == 0.0: continue
			var best: float = d[i]
			best = minf(best, (d[i - 1] if x > 0 else 0.0) + 1.0)
			best = minf(best, (d[i - w] if z > 0 else 0.0) + 1.0)
			best = minf(best, (d[i - w - 1] if x > 0 and z > 0 else 0.0) + dg)
			best = minf(best, (d[i - w + 1] if x < w - 1 and z > 0 else 0.0) + dg)
			d[i] = best
	for z in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i: int = z * w + x
			if d[i] == 0.0: continue
			var best: float = d[i]
			best = minf(best, (d[i + 1] if x < w - 1 else 0.0) + 1.0)
			best = minf(best, (d[i + w] if z < h - 1 else 0.0) + 1.0)
			best = minf(best, (d[i + w + 1] if x < w - 1 and z < h - 1 else 0.0) + dg)
			best = minf(best, (d[i + w - 1] if x > 0 and z < h - 1 else 0.0) + dg)
			d[i] = best
	# soften it, so diagonal coasts and thin necks don't alternate deep and shallow tile by tile
	for _pass in 2:
		var sm := d.duplicate()
		for z in range(1, h - 1):
			for x in range(1, w - 1):
				var i: int = z * w + x
				if d[i] <= 0.0: continue
				var sum := d[i - 1] + d[i + 1] + d[i - w] + d[i + w]
				sum += d[i - w - 1] + d[i - w + 1] + d[i + w - 1] + d[i + w + 1]
				sm[i] = maxf(0.5, (d[i] * 2.0 + sum) / 10.0)
		d = sm
	return d

## Over the void, below an island's lip, a body pressed against (or just under) the island's rock
## catches it this far down: the whole side down to the abyss is one climbable face.
static func catch_depth() -> float:
	return T["catch_depth_m"]

## A deep climb takes this long at most (s), on top of the rise's own grace.
static func rise_max_s() -> float:
	return T["rise_max_s"]

## Is p under an island's rock (below its underside, with open air above the head)?
static func below(W: World, p: Vector3) -> bool:
	var ix := int(floor(p.x))
	var iz := int(floor(p.z))
	return W.inb(ix, iz) and W.kind[W.idx(ix, iz)] != World.T_VOID and p.y + HEAD <= W.under_heights()[W.idx(ix, iz)]

## Can a body at p catch tile i's rock: it reaches down to p's height, or hangs just over the head?
static func touches(W: World, i: int, p: Vector3) -> bool:
	return W.under_heights()[i] < p.y + HEAD + float(T["under_reach_m"])

## Hunter._unclip's rock rules: true when it's handled (see clear).
static func unclip(h: Hunter) -> bool:
	var p := clear(h.m.world, h.pos, h.lfloat, h.r, h.vel.y)
	if p == Vector3.INF:
		return false
	if p.y < h.pos.y:
		h.vel.y = 0.0
	h.pos = p
	return true

## Where a body of radius r at p (rising at vy, mid-climb when lf, a ledge rise {n, at}, isn't empty)
## belongs against the rock, or Vector3.INF when the usual rules apply. Under an island's rock it's
## open air (p itself); rising into the underside from below bumps the head (lower p: stop rising);
## mid-climb, the overhang above pushes it out along the face, and the rise's "moved off the face"
## mark (lf.at) moves with it. The farm's movement uses it too.
static func clear(W: World, p: Vector3, lf: Dictionary, r: float, vy: float) -> Vector3:
	var ix := int(floor(p.x))
	var iz := int(floor(p.z))
	if not W.inb(ix, iz) or W.kind[W.idx(ix, iz)] == World.T_VOID:
		return Vector3.INF
	if _free(W, p, r):
		return p if p.y + HEAD <= W.under_heights()[W.idx(ix, iz)] else Vector3.INF
	if not lf.is_empty():
		var q := slide_out(W, p, lf["n"], r)
		if q == p:
			return Vector3.INF      # no way out along the face: the usual unclip
		lf["at"] = (lf["at"] as Vector2) + Vector2(q.x - p.x, q.z - p.z)
		return q
	if vy > 0.0:
		for k in range(1, int(BUMP / 0.1) + 1):
			var q := Vector3(p.x, p.y - 0.1 * k, p.z)
			if _free(W, q, r):
				return q
	return Vector3.INF

const BUMP := 0.6     # m: rising this far into an underside from below is a head bump, not a clip

## Is there rock right in front of a body at pos facing n (the face it's climbing)?
static func on_face(W: World, pos: Vector3, n: Vector2, r: float) -> bool:
	var p := Vector2(pos.x, pos.z) + n * 0.35
	return W.occupy(p.x, p.y, r, pos.y, false, true) > 0.0

const EDGE_OUT := 0.15     # m a step: how fast a climber edges out under a shelf (9 m/s)

## (deep climb) Rising up a stepped, tapered side: the overhang above pushes the climber out along
## it (-n; n points into the face). A little overhang it just slides past; under a shelf it edges
## out at EDGE_OUT a step, held just under the shelf until clear, then rises on. Returns pos
## unchanged when it's already free (or nothing nearby is).
static func slide_out(W: World, pos: Vector3, n: Vector2, r: float) -> Vector3:
	if _free(W, pos, r):
		return pos
	for s in range(1, 4):
		var q := Vector3(pos.x - n.x * 0.05 * s, pos.y, pos.z - n.y * 0.05 * s)
		if _free(W, q, r):
			return q
	for k in range(1, 13):
		var q := Vector3(pos.x - n.x * EDGE_OUT, pos.y - 0.1 * k, pos.z - n.y * EDGE_OUT)
		if _free(W, q, r):
			return q
	return pos

static func _free(W: World, p: Vector3, r: float) -> bool:
	return W.occupy(p.x, p.z, r, p.y, false, true) == 0.0
