class_name AimGeo
extends RefCounted
## Triangle soup for the ground telegraphs (AimDraw rebuilds one ImmediateMesh from it each frame, so
## showing a telegraph never adds a node). Points are flat (x, z); each vertex sits on the ground under
## it, lifted a little so it never z-fights, and keeps the shape's base height across cliffs and over
## the abyss (a lane doesn't climb a wall).

const LIFT := 0.06        # m above the ground (no z-fighting with the terrain)
const STEP := 0.7         # m: long ribbons are cut this fine so they follow terraces and stairs
const MAX_DY := 1.5       # m: ground further than this from the base height is ignored (walls, pits)

var v := PackedVector3Array()
var c := PackedColorArray()
var world = null
var base_y := 0.0

func reset() -> void:
	v.clear(); c.clear()

func at_height(y: float) -> void:
	base_y = y

func y_at(p: Vector2) -> float:
	if world != null:
		var g: float = world.ground_at(p.x, p.y)
		if g > World.VOID + 1.0 and absf(g - base_y) <= MAX_DY:
			return g + LIFT
	return base_y + LIFT

func _p(p: Vector2) -> Vector3:
	return Vector3(p.x, y_at(p), p.y)

func tri(a: Vector2, b: Vector2, d: Vector2, col: Color) -> void:
	v.append(_p(a)); v.append(_p(b)); v.append(_p(d))
	c.append(col); c.append(col); c.append(col)

## A quad a-b-d-e (in order round the edge), with a colour per side: ca on a/e, cb on b/d.
func quad(a: Vector2, b: Vector2, d: Vector2, e: Vector2, ca: Color, cb := Color(0, 0, 0, -1)) -> void:
	if cb.a < 0.0: cb = ca
	var pa := _p(a); var pb := _p(b); var pd := _p(d); var pe := _p(e)
	v.append(pa); v.append(pb); v.append(pd)
	c.append(ca); c.append(cb); c.append(cb)
	v.append(pa); v.append(pd); v.append(pe)
	c.append(ca); c.append(cb); c.append(ca)

## A flat strip of width w from p0 to p1, cut into STEP pieces; colour fades from c0 to c1.
func ribbon(p0: Vector2, p1: Vector2, w: float, c0: Color, c1 := Color(0, 0, 0, -1)) -> void:
	if c1.a < 0.0: c1 = c0
	var d := p1 - p0
	var l := d.length()
	if l < 0.001:
		return
	var n := Vector2(-d.y, d.x) / l * (w * 0.5)
	var k := maxi(1, int(ceil(l / STEP)))
	for i in k:
		var a := p0 + d * (float(i) / k)
		var b := p0 + d * (float(i + 1) / k)
		quad(a - n, b - n, b + n, a + n, c0.lerp(c1, float(i) / k), c0.lerp(c1, float(i + 1) / k))

## A filled strip p0 -> p1 of width w0 at p0 and w1 at p1 (lanes, taper), cut into STEP pieces.
func band(p0: Vector2, p1: Vector2, w0: float, w1: float, c0: Color, c1 := Color(0, 0, 0, -1)) -> void:
	if c1.a < 0.0: c1 = c0
	var d := p1 - p0
	var l := d.length()
	if l < 0.001:
		return
	var n := Vector2(-d.y, d.x) / l
	var k := maxi(1, int(ceil(l / STEP)))
	for i in k:
		var t0 := float(i) / k; var t1 := float(i + 1) / k
		var a := p0 + d * t0; var b := p0 + d * t1
		var wa := lerpf(w0, w1, t0) * 0.5; var wb := lerpf(w0, w1, t1) * 0.5
		quad(a - n * wa, b - n * wb, b + n * wb, a + n * wa, c0.lerp(c1, t0), c0.lerp(c1, t1))

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
	if col_in.a < 0.0: col_in = col
	var segs := clampi(int(r * absf(a1 - a0) / 0.4), 10, 64)
	var ri := maxf(0.0, r - w * 0.5); var ro := r + w * 0.5
	for i in segs:
		var t0 := lerpf(a0, a1, float(i) / segs); var t1 := lerpf(a0, a1, float(i + 1) / segs)
		var e0 := Vector2(cos(t0), sin(t0)); var e1 := Vector2(cos(t1), sin(t1))
		quad(ctr + e0 * ri, ctr + e1 * ri, ctr + e1 * ro, ctr + e0 * ro, col_in, col)

## A filled annulus sector between radii r0 and r1, angles a0..a1 (discs, cones, wall bands).
func sector(ctr: Vector2, r0: float, r1: float, a0: float, a1: float, c0: Color, c1 := Color(0, 0, 0, -1)) -> void:
	if c1.a < 0.0: c1 = c0
	var segs := clampi(int(r1 * absf(a1 - a0) / 0.5), 8, 48)
	var rings := maxi(1, int(ceil((r1 - r0) / (STEP * 1.5))))
	for j in rings:
		var ra := lerpf(r0, r1, float(j) / rings); var rb := lerpf(r0, r1, float(j + 1) / rings)
		var ca := c0.lerp(c1, float(j) / rings); var cb := c0.lerp(c1, float(j + 1) / rings)
		for i in segs:
			var t0 := lerpf(a0, a1, float(i) / segs); var t1 := lerpf(a0, a1, float(i + 1) / segs)
			var e0 := Vector2(cos(t0), sin(t0)); var e1 := Vector2(cos(t1), sin(t1))
			if ra < 0.001:
				tri(ctr, ctr + e0 * rb, ctr + e1 * rb, cb)
			else:
				quad(ctr + e0 * ra, ctr + e1 * ra, ctr + e1 * rb, ctr + e0 * rb, ca, cb)

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
		tri(p, r, tip, col); tri(p, tip, l, col)

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
