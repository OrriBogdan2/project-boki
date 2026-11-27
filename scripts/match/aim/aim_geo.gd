class_name AimGeo
extends RefCounted
## Triangle soup for the ground telegraphs (AimDraw rebuilds one ArrayMesh from it each frame, so
## showing a telegraph never adds a node). Points are flat (x, z); each vertex sits on the ground under
## it, lifted a little so it never z-fights, and keeps the shape's base height across cliffs and over
## the abyss (a lane doesn't climb a wall).

const LIFT := 0.06  # m above the ground (no z-fighting with the terrain)
const STEP := 0.7  # m: long ribbons are cut this fine so they follow terraces and stairs
const MAX_DY := 1.5  # m: ground further than this from the base height is ignored (walls, pits)

static var keep_points := true  # (off only for tools/perf/aim_ab.gd: the cost without the kept points)

var v := PackedVector3Array()
var c := PackedColorArray()
var world: World = null
var base_y := 0.0
# The ground points of every ring and sector the last rebuild drew, by shape: a telegraph that holds still keeps its
# points while only its colours move, so a repeat copies them in one call instead of looking each one up again (the
# same vertices, the same colour formulas). Dropped whenever the ground changes (ground_key).
var _pts_last := {}
var _pts_now := {}
var _ground := 0


func reset() -> void:
	v.clear()
	c.clear()
	_pts_last = _pts_now
	_pts_now = {}
	var gk := ground_key(world)
	if gk != _ground:
		_pts_last = {}
		_ground = gk


## Everything ground_at reads, hashed (native, once per rebuild): a changed tile, terrace, block or stair drops the
## kept points.
static func ground_key(wd: World) -> int:
	if wd == null:
		return 0
	return hash([wd.get_instance_id(), wd.w, wd.h, wd.kind, wd.level, wd.block_top, wd.stairs])


## The colour block of one strip step, `n` times over (doubling copies, no per-vertex call).
func _repeat(block: PackedColorArray, n: int) -> void:
	var out := block.duplicate()
	var have := 1
	while have * 2 <= n:
		out.append_array(out.duplicate())
		have *= 2
	c.append_array(out)
	if have < n:
		c.append_array(out.slice(0, (n - have) * block.size()))


func at_height(y: float) -> void:
	base_y = y


## A point on the ground under p (x, z): LIFT over the ground, or over base_y where the ground is a wall, a pit or
## the abyss. One call per vertex of every telegraph every frame, so it is kept to this one function.
func _p(p: Vector2) -> Vector3:
	if world != null:
		var g := world.ground_at(p.x, p.y)
		if g > World.VOID + 1.0 and absf(g - base_y) <= MAX_DY:
			return Vector3(p.x, g + LIFT, p.y)
	return Vector3(p.x, base_y + LIFT, p.y)


func tri(a: Vector2, b: Vector2, d: Vector2, col: Color) -> void:
	v.append(_p(a))
	v.append(_p(b))
	v.append(_p(d))
	c.append(col)
	c.append(col)
	c.append(col)


## A quad a-b-d-e (in order round the edge), with a colour per side: ca on a/e, cb on b/d.
func quad(a: Vector2, b: Vector2, d: Vector2, e: Vector2, ca: Color, cb := Color(0, 0, 0, -1)) -> void:
	if cb.a < 0.0:
		cb = ca
	_quad3(_p(a), _p(b), _p(d), _p(e), ca, cb)


## quad on points already on the ground: the strips below carry each step's far edge on as the next one's near
## edge, so a shared corner is looked up once (the same vertices as quad, in the same order).
func _quad3(pa: Vector3, pb: Vector3, pd: Vector3, pe: Vector3, ca: Color, cb: Color) -> void:
	v.append(pa)
	v.append(pb)
	v.append(pd)
	c.append(ca)
	c.append(cb)
	c.append(cb)
	v.append(pa)
	v.append(pd)
	v.append(pe)
	c.append(ca)
	c.append(cb)
	c.append(ca)


## A flat strip of width w from p0 to p1, cut into STEP pieces; colour fades from c0 to c1.
func ribbon(p0: Vector2, p1: Vector2, w: float, c0: Color, c1 := Color(0, 0, 0, -1)) -> void:
	if c1.a < 0.0:
		c1 = c0
	var d := p1 - p0
	var l := d.length()
	if l < 0.001:
		return
	var n := Vector2(-d.y, d.x) / l * (w * 0.5)
	var k := maxi(1, int(ceil(l / STEP)))
	var al := _p(p0 - n)
	var ar := _p(p0 + n)
	for i in k:
		var b := p0 + d * (float(i + 1) / k)
		var bl := _p(b - n)
		var br := _p(b + n)
		_quad3(al, bl, br, ar, c0.lerp(c1, float(i) / k), c0.lerp(c1, float(i + 1) / k))
		al = bl
		ar = br


## A filled strip p0 -> p1 of width w0 at p0 and w1 at p1 (lanes, taper), cut into STEP pieces.
func band(p0: Vector2, p1: Vector2, w0: float, w1: float, c0: Color, c1 := Color(0, 0, 0, -1)) -> void:
	if c1.a < 0.0:
		c1 = c0
	var d := p1 - p0
	var l := d.length()
	if l < 0.001:
		return
	var n := Vector2(-d.y, d.x) / l
	var k := maxi(1, int(ceil(l / STEP)))
	var wa := lerpf(w0, w1, 0.0) * 0.5
	var al := _p(p0 - n * wa)
	var ar := _p(p0 + n * wa)
	for i in k:
		var t0 := float(i) / k
		var t1 := float(i + 1) / k
		var b := p0 + d * t1
		var wb := lerpf(w0, w1, t1) * 0.5
		var bl := _p(b - n * wb)
		var br := _p(b + n * wb)
		_quad3(al, bl, br, ar, c0.lerp(c1, t0), c0.lerp(c1, t1))
		al = bl
		ar = br


## A dashed line: dash metres on, gap metres off.
func dashes(p0: Vector2, p1: Vector2, w: float, col: Color, dash := 0.35, gap := 0.25) -> void:
	var d := p1 - p0
	var l := d.length()
	if l < 0.001:
		return
	var u := d / l
	var s := 0.0
	while s < l:
		ribbon(p0 + u * s, p0 + u * minf(l, s + dash), w, col)
		s += dash + gap


## A ring (or an arc of it from a0 to a1, radians, 0 = +x) of radius r and line width w.
func ring(ctr: Vector2, r: float, w: float, col: Color, a0 := 0.0, a1 := TAU, col_in := Color(0, 0, 0, -1)) -> void:
	if col_in.a < 0.0:
		col_in = col
	var segs := clampi(int(r * absf(a1 - a0) / 0.4), 10, 64)
	var key := [1, ctr, r, w, a0, a1, base_y]
	if keep_points and _pts_last.has(key):
		var pts: PackedVector3Array = _pts_last[key]
		v.append_array(pts)
		_repeat(PackedColorArray([col_in, col, col, col_in, col, col_in]), segs)
		_pts_now[key] = pts
		return
	var n0 := v.size()
	var ri := maxf(0.0, r - w * 0.5)
	var ro := r + w * 0.5
	var e0 := Vector2(cos(a0), sin(a0))
	var pi0 := _p(ctr + e0 * ri)
	var po0 := _p(ctr + e0 * ro)
	for i in segs:
		var t1 := lerpf(a0, a1, float(i + 1) / segs)
		var e1 := Vector2(cos(t1), sin(t1))
		var pi1 := _p(ctr + e1 * ri)
		var po1 := _p(ctr + e1 * ro)
		_quad3(pi0, pi1, po1, po0, col_in, col)
		pi0 = pi1
		po0 = po1
	if keep_points:
		_pts_now[key] = v.slice(n0)


## A filled annulus sector between radii r0 and r1, angles a0..a1 (discs, cones, wall bands).
func sector(ctr: Vector2, r0: float, r1: float, a0: float, a1: float, c0: Color, c1 := Color(0, 0, 0, -1)) -> void:
	if c1.a < 0.0:
		c1 = c0
	var segs := clampi(int(r1 * absf(a1 - a0) / 0.5), 8, 48)
	var rings := maxi(1, int(ceil((r1 - r0) / (STEP * 1.5))))
	var key := [0, ctr, r0, r1, a0, a1, base_y]
	if keep_points and _pts_last.has(key):
		var pts: PackedVector3Array = _pts_last[key]
		v.append_array(pts)
		for j in rings:
			var ca := c0.lerp(c1, float(j) / rings)
			var cb := c0.lerp(c1, float(j + 1) / rings)
			if lerpf(r0, r1, float(j) / rings) < 0.001:
				_repeat(PackedColorArray([cb, cb, cb]), segs)
			else:
				_repeat(PackedColorArray([ca, cb, cb, ca, cb, ca]), segs)
		_pts_now[key] = pts
		return
	var n0 := v.size()
	var dirs := PackedVector2Array()  # the unit vector at each angle step, the same for every ring
	dirs.resize(segs + 1)
	for i in segs + 1:
		var t := lerpf(a0, a1, float(i) / segs)
		dirs[i] = Vector2(cos(t), sin(t))
	# each ring's outer row is the next ring's inner row (the same radius), so it is looked up once
	var inner := PackedVector3Array()
	inner.resize(segs + 1)
	if r0 >= 0.001:
		for i in segs + 1:
			inner[i] = _p(ctr + dirs[i] * r0)
	var outer := PackedVector3Array()
	outer.resize(segs + 1)
	for j in rings:
		var ra := lerpf(r0, r1, float(j) / rings)
		var rb := lerpf(r0, r1, float(j + 1) / rings)
		var ca := c0.lerp(c1, float(j) / rings)
		var cb := c0.lerp(c1, float(j + 1) / rings)
		var pc := _p(ctr) if ra < 0.001 else Vector3.ZERO
		outer[0] = _p(ctr + dirs[0] * rb)
		for i in segs:
			outer[i + 1] = _p(ctr + dirs[i + 1] * rb)
			if ra < 0.001:
				v.append(pc)
				v.append(outer[i])
				v.append(outer[i + 1])
				c.append(cb)
				c.append(cb)
				c.append(cb)
			else:
				_quad3(inner[i], inner[i + 1], outer[i + 1], outer[i], ca, cb)
		var row := inner
		inner = outer
		outer = row
	if keep_points:
		_pts_now[key] = v.slice(n0)


func disc(ctr: Vector2, r: float, col: Color, col_edge := Color(0, 0, 0, -1)) -> void:
	sector(ctr, 0.0, r, 0.0, TAU, col, col if col_edge.a < 0.0 else col_edge)


## A chevron (a ">" pointing along u) of arm length s and line width w, its tip at p.
func chevron(p: Vector2, u: Vector2, s: float, w: float, col: Color) -> void:
	var n := Vector2(-u.y, u.x)
	ribbon(p - u * s * 0.7 + n * s * 0.7, p, w, col)
	ribbon(p - u * s * 0.7 - n * s * 0.7, p, w, col)


## A flat 4-point star (a glint) of radius s at p, turned by rot radians.
func star(p: Vector2, s: float, col: Color, rot := 0.0) -> void:
	var waist := s * 0.22
	for i in 4:
		var a := rot + i * PI * 0.5
		var tip := p + Vector2(cos(a), sin(a)) * s
		var l := p + Vector2(cos(a + PI * 0.25), sin(a + PI * 0.25)) * waist
		var r := p + Vector2(cos(a - PI * 0.25), sin(a - PI * 0.25)) * waist
		tri(p, r, tip, col)
		tri(p, tip, l, col)


## A leaf (a long pointed lozenge) of length s centred on p, lying along u: Hem's glint on her draw line.
func leaf(p: Vector2, u: Vector2, s: float, col: Color) -> void:
	var n := Vector2(-u.y, u.x) * s * 0.22
	var tip := p + u * s * 0.5
	var tail := p - u * s * 0.5
	tri(tail, p + n, tip, col)
	tri(tail, tip, p - n, col)


## An open arrowhead at p pointing along u.
func arrow(p: Vector2, u: Vector2, s: float, w: float, col: Color) -> void:
	chevron(p, u, s, w, col)
