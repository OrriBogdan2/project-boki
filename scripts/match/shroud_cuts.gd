class_name ShroudCuts
extends RefCounted
## The ten cuts of the Empty's shroud (Shrouds.STYLES, same order). Each one is built around one shape that still
## reads at the match camera, where a body is about a tenth of the screen tall: the bell, the bare lean figure, the
## spikes, the swallowtail and flared collar, the box, the column with sleeves and streamer, the lopsided shoulder,
## the fat neck roll and long tail, the feather fan, and the stepped sack. Torso space throughout: y 0 at the hips,
## shoulders about 0.5, the head's middle 0.86, the ground t.floor_y; front is -Z.

const LIMB := {"legs": 0.85, "arms": 0.8}       # cloth that hangs round the body and has to stay round the limbs
const UPPER := {"arms": 0.85}                   # cloth above the hips

static func cut(t: ShroudTailor, style: int, hood_up: bool) -> void:
	match style:
		0: _cloak(t, hood_up)
		1: _wrap(t)
		2: _tatters(t, hood_up)
		3: _coat(t)
		4: _poncho(t, hood_up)
		5: _robe(t, hood_up)
		6: _mantle(t)
		7: _shawl(t)
		8: _feathers(t, hood_up)
		_: _patchwork(t, hood_up)

# ---------------------------------------------------------------------------------------------- shared shapes
static func _fold(th: float, n: float) -> float:
	return sin(n * th + 0.6 * sin(th * 3.0))

static func _shell(t: ShroudTailor, nm: String, fn: Callable, cols: int, rows: int, thick := 0.016,
		closed := false, sgn := 1.0) -> ArrayMesh:
	var ao := func(_u: float, v: float) -> float: return lerpf(0.74, 1.0, smoothstep(0.0, 0.3, v))
	return HeroKit.shell("shroud|%s|%s" % [nm, t.tag], fn, cols, rows, thick, ao, closed, sgn)

## A hem or edge of a garment as a trim band: fn at v0..v1, a hair outside it (fn's u along the edge).
static func _edge(fn: Callable, v0: float, v1: float) -> Callable:
	return func(u: float, w: float) -> Vector3:
		var p: Vector3 = fn.call(u, lerpf(v0, v1, w))
		return Vector3(p.x * 1.012, p.y, p.z * 1.012)

## The same along v: a band down an edge of a garment at u.
static func _edge_v(fn: Callable, u0: float, u1: float, v0: float, v1: float) -> Callable:
	return func(u: float, w: float) -> Vector3:
		var p: Vector3 = fn.call(lerpf(u0, u1, w), lerpf(v0, v1, u))
		return Vector3(p.x * 1.012, p.y, p.z * 1.012)

## A hood round the head: b round the opening, a from the back of the skull to the face; `peak` pulls the crown
## up and back into a point, `flop` tips that point to one side.
static func _hood(t: ShroudTailor, nm: String, mat: Material, radius: float, peak: float, flop := 0.0) -> void:
	radius *= 0.95 if t.fem else 1.0       # her smaller head (Unmasked.race "head")
	var fn := func(u: float, v: float) -> Vector3:
		var b := u * TAU
		var a := lerpf(0.06, 2.25, v)
		var p := Vector3(sin(a) * cos(b), sin(a) * sin(b), cos(a)) * Vector3(1.0, 1.05, 1.08) * radius
		var top := exp(-pow(wrapf(b - PI * 0.5, -PI, PI), 2.0) / 0.9) * exp(-pow(a - 0.8, 2.0) / 0.5)
		p += Vector3(flop, 1.0, 0.7) * top * peak
		p.y -= maxf(-sin(b), 0.0) * v * v * 0.13
		return p
	var mesh := _shell(t, "hood|" + nm, fn, 26, 10, 0.02, true, -1.0)
	t.rigid(t.torso, mesh, mat, Vector3(0, 0.86, 0.015))

## A hood worn down: a fat fold of cloth on the shoulders behind the neck.
static func _hood_down(t: ShroudTailor, nm: String, mat: Material, radius := 0.2) -> void:
	var fn := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var ph := v * TAU
		var back := 0.55 + 0.45 * clampf(sin(th) + 0.2, 0.0, 1.0)
		var tube := 0.085 * back
		var ring := Vector3(cos(th) * radius, 0.0, sin(th) * radius * 0.95 + 0.04 * back)
		return ring + Vector3(cos(th), 0.0, sin(th)) * cos(ph) * tube + Vector3.UP * sin(ph) * tube * 0.8
	var ao := func(_u: float, v: float) -> float: return lerpf(0.8, 1.0, clampf(sin(v * TAU) * 0.5 + 0.5, 0.0, 1.0))
	t.add("body", HeroKit.surf("shroud|hooddn|%s|%s" % [nm, t.tag], fn, 24, 8, ao, -1.0), {},
		Transform3D(Basis.IDENTITY, Vector3(0, 0.655, 0)))
	_collar(t, mat)

## The cloth round the neck, at the body's neck girth (ShroudTailor.NECK).
static func _collar(t: ShroudTailor, mat: Material, top := 0.1, bottom := 0.14, tall := 0.1) -> void:
	var k := float(ShroudTailor.NECK[t.fem])
	t.rigid(t.torso, Models.cyl(top * k, bottom * k, tall, 14), mat, Vector3(0, 0.63, 0))

static func _hood_for(t: ShroudTailor, nm: String, up: bool, peak: float, flop := 0.0, tone := "body") -> void:
	if up:
		_hood(t, nm, t.m[tone], 0.27, peak, flop)
	else:
		_hood_down(t, nm, t.m[tone])

## A point on a smooth curve through pts, v 0..1 along it.
static func _curve(pts: PackedVector3Array, v: float) -> Vector3:
	var last := pts.size() - 1
	var k := v * last
	var i := mini(int(k), last - 1)
	return pts[i].cubic_interpolate(pts[i + 1], pts[maxi(i - 1, 0)], pts[mini(i + 2, last)], k - i)

## A strip of cloth along a curve (a tail, a sash end, a bandage). u across, v along; widths w0..w1.
static func _ribbon(t: ShroudTailor, nm: String, pts: PackedVector3Array, w0: float, w1: float, side := Vector3.RIGHT,
		rows := 12, point := false) -> ArrayMesh:
	var fn := func(u: float, v: float) -> Vector3:
		var c := _curve(pts, v)
		var wid := lerpf(w0, w1, v) * (1.0 - smoothstep(0.86, 1.0, v) * 0.9 if point else 1.0)
		return c + side * (u - 0.5) * wid + Vector3(0, 0, 0.012 * sin(v * 17.0)) * (1.0 + 2.0 * absf(u - 0.5))
	return _shell(t, "ribbon|" + nm, fn, 3, rows, 0.012, false, -1.0)

## A band wound round a limb or body in a spiral: axis y0 to y1 at radius rad(k), k 0..1 down it.
static func _helix(key: String, rad: Callable, y0: float, y1: float, turns: float, wide: float, cz := 0.0) -> ArrayMesh:
	var fn := func(u: float, v: float) -> Vector3:
		var k := clampf(u + (v - 0.5) * wide / absf(y1 - y0), 0.0, 1.0)
		var th := u * turns * TAU
		var r := float(rad.call(k)) + 0.012 * sin(v * PI)
		return Vector3(cos(th) * r, lerpf(y0, y1, k), sin(th) * r + cz)
	return HeroKit.surf("shroud|helix|" + key, fn, int(turns * 10.0), 2, Callable(), -1.0 if y1 > y0 else 1.0)

## One feather: u across a creased vane, v from quill to tip, length ln, width wid, curling back by `curl`.
static func _feather(t: ShroudTailor, nm: String, ln: float, wid: float, curl: float) -> ArrayMesh:
	var fn := func(u: float, v: float) -> Vector3:
		var w := wid * pow(sin(PI * pow(v * 0.96 + 0.04, 0.62)), 0.7)
		var a := u - 0.5
		return Vector3(a * w, ln * v, curl * v * v - absf(a) * w * 0.34)
	return _shell(t, "feather|" + nm, fn, 2, 4, 0.007, false, -1.0)

## A transform that puts a piece's +Y along `dir` from `at`, its face out from the axis at angle th.
static func _lay(at: Vector3, dir: Vector3, th: float) -> Transform3D:
	var y := dir.normalized()
	var x := Vector3(-sin(th), 0.0, cos(th))
	x = (x - y * x.dot(y)).normalized()
	return Transform3D(Basis(x, y, x.cross(y)), at)

# ----------------------------------------------------------------------------------------------- 0 Hooded Cloak
## The bell: closed at the throat, sweeping out to a wide floor-length hem with a train, open up the front; a deep
## pointed hood. Nothing of the arms or legs shows: the widest, tallest triangle of the ten.
static func _cloak(t: ShroudTailor, hood_up: bool) -> void:
	var f := t.floor_y
	var s := t.span
	var flare := 0.24 if t.fem else 0.15        # a woman's shoulders are narrower and her hem wider
	var yoke := 0.3 if t.fem else 0.2           # how far down it reaches full width: his square shoulders
	var fn := func(u: float, v: float) -> Vector3:
		var gap := 0.03 + 0.3 * v * v
		var th := PI * 0.5 + (2.0 * u - 1.0) * (PI - gap)
		var rr := lerpf(0.13, 0.385 * s, smoothstep(-0.04, yoke, v)) + flare * pow(v, 1.6)
		rr *= 1.0 + 0.07 * v * _fold(th, 7.0)
		var train := 0.3 * maxf(sin(th), 0.0) * v * v * v
		return Vector3(cos(th) * rr, lerpf(0.67, f + 0.02, v), sin(th) * rr * 0.94 + train)
	t.keep = 0.85       # (one big surface: its folds are all it has)
	t.add("body", _shell(t, "cloak", fn, 48, 14), {"legs": 0.8, "arms": 0.9})
	t.band(_edge(fn, 0.95, 1.0), 2.8, LIMB)
	t.band(_edge_v(fn, 0.985, 1.0, 0.1, 0.96), 1.1, LIMB)
	t.band(_edge_v(fn, 0.0, 0.015, 0.1, 0.96), 1.1, LIMB)
	_hood_for(t, "cloak", hood_up, 0.16)
	_collar(t, t.m["body"])
	t.add("trim", Models.sphere(0.035, 8), {}, Transform3D(Basis.IDENTITY, Vector3(0, 0.56, -0.2)))

# ------------------------------------------------------------------------------------------------------ 1 Wrap
## The bare figure: nothing hangs, the body itself is wound in bandage over the void, with loose ends trailing from
## the waist, one wrist and the back of the head. The narrowest shape of the ten.
static func _wrap(t: ShroudTailor) -> void:
	var dark: Material = t.m["pants"]
	var body: Material = t.m["body"]
	var torso := t.torso
	for ch in torso.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).material_override == body:
			(ch as MeshInstance3D).material_override = dark
	var chest := func(k: float) -> float: return HeroKit.torso_prof(lerpf(0.1, 0.92, k)).x * t.span * 0.97 + 0.012
	var y_top := 0.33 + HeroKit.torso_prof(0.1).y
	var y_bot := 0.33 + HeroKit.torso_prof(0.92).y
	t.rigid(torso, _helix("chest|" + t.tag, chest, y_top, y_bot, 6.0, 0.1), body)
	var waist := func(u: float, w: float) -> Vector3:
		var rr := 0.26 * t.bw
		return Vector3(cos(u * TAU) * rr, 0.1 - 0.09 * w, sin(u * TAU) * rr * 0.94)
	t.band(waist, 1.5, {})
	var hips := func(k: float) -> float: return lerpf(0.23, 0.24, k) * t.bw
	t.rigid(torso, _helix("hips|" + t.tag, hips, 0.1, -0.1, 3.0, 0.1), body)
	for sd in ["L", "R"]:
		var parts: Array = t.c["arms"][sd]
		for n in parts:
			for ch in (n as Node3D).get_children():
				if ch is MeshInstance3D and (ch as MeshInstance3D).material_override == body:
					(ch as MeshInstance3D).material_override = dark
		var up := func(k: float) -> float: return lerpf(0.09, 0.066, k)
		var low := func(k: float) -> float: return lerpf(0.07, 0.054, k)
		t.rigid(parts[0], _helix("uparm", up, 0.04, -0.23, 3.2, 0.075), body)
		t.rigid(parts[1], _helix("forearm", low, 0.0, -0.22, 3.0, 0.07), body)
		var leg := t.torso.get_parent().get_node("Legs/Leg" + sd) as Node3D
		var thigh := func(k: float) -> float: return lerpf(0.11, 0.074, k) * t.bw
		t.rigid(leg, _helix("thigh|" + t.tag, thigh, 0.05, -0.28, 3.4, 0.085), body)
		var shin := func(k: float) -> float: return lerpf(0.074, 0.086, k)
		t.rigid(t.c["knees"][sd], _helix("shin", shin, 0.03, -0.14, 2.0, 0.07), body)
	_collar(t, body, 0.095, 0.13, 0.15)
	var brow := func(k: float) -> float: return sqrt(0.0538 - pow(lerpf(0.11, 0.02, k), 2.0)) + 0.004
	t.rigid(torso, _helix("brow", brow, 0.11, 0.02, 2.0, 0.045), body, Vector3(0, 0.86, 0), Vector3(0.25, 0, 0))
	var tails := [
		[PackedVector3Array([Vector3(0.14, 0.02, 0.2), Vector3(0.2, -0.16, 0.34), Vector3(0.28, -0.3, 0.52),
			Vector3(0.22, -0.36, 0.8)]), 0.09, 0.05],
		[PackedVector3Array([Vector3(-0.12, 0.0, 0.19), Vector3(-0.22, -0.2, 0.3), Vector3(-0.34, -0.3, 0.44)]),
			0.08, 0.05],
		[PackedVector3Array([Vector3(0.03, 0.8, 0.26), Vector3(0.1, 0.72, 0.42), Vector3(0.05, 0.66, 0.62),
			Vector3(0.14, 0.62, 0.82)]), 0.09, 0.05],
	]
	for i in tails.size():
		var at: Vector3 = tails[i][0][0]
		t.add("trim" if i == 2 else "body", _ribbon(t, "wrap%d" % i, tails[i][0], tails[i][1], tails[i][2]),
			{"bone": ShroudSkin.SCARF, "from": at, "reach": 0.5})
	var cuff: Vector3 = t.joints["ha"][0]
	var loose := PackedVector3Array([cuff + Vector3(-0.03, 0.05, 0), cuff + Vector3(-0.1, -0.08, 0.05),
		cuff + Vector3(-0.15, -0.26, 0.1)])
	t.add("body", _ribbon(t, "wrapwrist", loose, 0.07, 0.04), {"arms": 1.0})

# --------------------------------------------------------------------------------------------------- 2 Tatters
## The spikes: a torn yoke and long separate strips of uneven length that flare out into a star, with gaps through
## to the dark between them.
static func _tatters(t: ShroudTailor, hood_up: bool) -> void:
	var s := t.span
	var f := t.floor_y
	var yoke := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var jag := absf(fposmod(u * 9.0, 1.0) * 2.0 - 1.0)
		var rr := lerpf(0.13, 0.4 * s, pow(v, 0.7)) * (1.0 + 0.1 * v * jag)
		return Vector3(cos(th) * rr, lerpf(0.67, 0.34 - 0.2 * jag, pow(v, 0.9)), sin(th) * rr * 0.94)
	t.add("body", _shell(t, "tatyoke", yoke, 54, 6, 0.016, true), UPPER)
	var n := 15
	for i in n:
		var th0 := TAU * (i + 0.3 * sin(i * 2.7)) / n
		var ln := 0.62 + 0.46 * absf(sin(i * 1.9 + 0.6))
		var flare := 0.56 + 0.3 * absf(sin(i * 2.3 + 1.1))     # how far out the strip's point flies: uneven, spiky
		var wide := TAU / n * 0.72
		var r0 := lerpf(0.27, 0.37, absf(cos(th0))) * s
		var top := 0.52
		var low := maxf(top - ln, f + 0.05)
		var strip := func(u: float, v: float) -> Vector3:
			var th := th0 + (u - 0.5) * wide * (1.0 - 0.92 * pow(v, 1.6)) + 0.1 * sin(v * 5.0 + i) * v
			var rr := lerpf(r0, flare, pow(v, 1.4))
			return Vector3(cos(th) * rr, lerpf(top, low, v), sin(th) * rr * 0.96)
		var tone := "alt" if i % 3 == 1 else "body"
		t.add(tone, _shell(t, "tat%d" % i, strip, 3, 7, 0.014), {"legs": 0.7, "arms": 0.6, "bone": ShroudSkin.CAPE,
			"from": Vector3(0, 0.5, 0.2), "reach": 1.0, "share": 0.3 if sin(th0) > 0.2 else 0.0})
	t.band(_edge(yoke, 0.72, 0.8), 2.0, UPPER)
	_hood_for(t, "tatters", hood_up, 0.1)

# ------------------------------------------------------------------------------------------------- 3 Long Coat
## The swallowtail: a fitted body, wide square shoulders, a tall collar flaring round the back of the head, and coat
## skirts open at the front that split behind into two long tails.
static func _coat(t: ShroudTailor) -> void:
	var f := t.floor_y
	var bw := t.bw
	for i in 2:
		var sgn := 1.0 if i == 1 else -1.0
		var panel := func(u: float, v: float) -> Vector3:
			var a := u if i == 1 else 1.0 - u
			var th := -PI * 0.5 + 0.2 + a * (PI - 0.25) if i == 1 else PI * 1.5 - 0.2 - a * (PI - 0.25)
			var ln := lerpf(0.5, minf(0.98, 0.0 - f - 0.02 + 0.08), pow(a, 1.5))
			var rr := lerpf(0.235 * bw, lerpf(0.31, 0.46, a), pow(v, 0.9)) * (1.0 + 0.05 * v * _fold(th, 6.0))
			var p := Vector3(cos(th) * rr, 0.06 - ln * v, sin(th) * rr * 0.94)
			p.z += a * a * v * v * 0.42
			p.x += sgn * a * a * v * v * 0.12
			return p
		t.add("body", _shell(t, "coat%d" % i, panel, 18, 9), {"legs": 0.6, "bone": ShroudSkin.CAPE,
			"from": Vector3(0, 0.06, 0.2), "reach": 0.95, "share": 0.5})
		t.band(_edge(panel, 0.93, 1.0), 1.0, {"legs": 0.6})
		var sd: Node3D = t.c["pr"] if i == 1 else t.c["pl"]
		t.rigid(sd, HeroKit.box_plate("shroud_board", 0.145, 0.125, 0.06, 0.02, 0.45), t.m["body"],
			Vector3(0.03 * sgn, 0.04, 0))
		t.rigid(sd, HeroKit.box_plate("shroud_board2", 0.15, 0.13, 0.03, 0.012, 0.3), t.m["trim"],
			Vector3(0.03 * sgn, 0.0, 0))
	var collar := func(u: float, v: float) -> Vector3:
		var th := PI * 0.5 + (2.0 * u - 1.0) * (PI - 0.55)
		var back := pow(clampf(sin(th) * 0.5 + 0.5, 0.0, 1.0), 1.3)
		var rise := lerpf(0.78, 1.14, back)
		var rr := lerpf(lerpf(0.26, 0.37, back), 0.13, pow(v, 0.8))
		return Vector3(cos(th) * rr, lerpf(rise, 0.6, v), sin(th) * rr * 0.96 + 0.02)
	t.add("body", _shell(t, "coatcollar", collar, 22, 5, 0.018), {})
	t.band(_edge(collar, 0.0, 0.1), 1.2, {})
	t.rigid(t.torso, Models.cyl(0.25 * t.bw, 0.25 * t.bw, 0.05, 20), t.m["leather"], Vector3(0, 0.05, 0))
	t.rigid(t.torso, Models.box(0.09, 0.07, 0.02), t.m["trim"], Vector3(0, 0.05, -0.25 * t.bw))
	for k in 4:
		t.rigid(t.torso, Models.sphere(0.016, 6), t.m["trim"], Vector3(0.05, 0.16 + k * 0.1, -0.215 - 0.006 * k))

# ---------------------------------------------------------------------------------------------------- 4 Poncho
## The box: a square of heavy cloth with the head through it, flat across the shoulders and wider than anything
## else here, hanging to the hips with straight sides and a fringe; thin legs below.
static func _poncho(t: ShroudTailor, hood_up: bool) -> void:
	var s := t.span
	var fn := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var k := 6.0
		var sq := pow(pow(absf(cos(th)), k) + pow(absf(sin(th)), k), -1.0 / k)
		var rr := lerpf(0.13, 0.6 * s * sq, pow(v, 0.8))
		var corner := pow(absf(sin(th * 2.0)), 2.0)
		var y := lerpf(0.67, 0.17, pow(v, 0.62)) - 0.1 * pow(v, 5.0) * corner
		return Vector3(cos(th) * rr, y, sin(th) * rr * 0.86)
	t.add("body", _shell(t, "poncho", fn, 52, 8, 0.02, true), {"arms": 0.95})
	var fringe := func(u: float, v: float) -> Vector3:
		var p: Vector3 = fn.call(u, 1.0)
		var tooth := absf(fposmod(u * 70.0, 1.0) * 2.0 - 1.0)
		return Vector3(p.x, p.y - v * (0.03 + 0.07 * tooth), p.z)
	var ao := func(_u: float, _v: float) -> float: return 0.9
	t.add("alt", HeroKit.surf("shroud|fringe|" + t.tag, fringe, 120, 1, ao, 1.0), {"arms": 0.95})
	for v0 in [0.6, 0.8]:
		t.add("trim", HeroKit.surf("shroud|ponstripe%.1f|%s" % [v0, t.tag], _edge(fn, v0, v0 + 0.09), 52, 1,
			Callable(), 1.0), {"arms": 0.95})
	t.band(_edge(fn, 0.95, 1.0), 3.0, {"arms": 0.95})
	_hood_for(t, "poncho", hood_up, 0.1)

# -------------------------------------------------------------------------------------------------- 5 Robe & Sash
## The column: a straight fall of cloth to the floor, deep vertical folds, great bell sleeves that hang past the
## hands, and a wide sash knotted at the hip with one long end trailing off the side.
static func _robe(t: ShroudTailor, hood_up: bool) -> void:
	var f := t.floor_y
	var fn := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var rr := lerpf(0.13, 0.25 * t.span, smoothstep(0.0, 0.14, v)) + 0.05 * v
		rr *= 1.0 + 0.09 * smoothstep(0.1, 0.5, v) * _fold(th, 6.0)
		return Vector3(cos(th) * rr, lerpf(0.66, f + 0.02, v), sin(th) * rr * 0.92)
	t.add("body", _shell(t, "robe", fn, 40, 10, 0.016, true), {"legs": 0.9})
	t.band(_edge(fn, 0.94, 1.0), 2.2, {"legs": 0.9})
	for i in 2:
		var sgn := 1.0 if i == 1 else -1.0
		var sh: Vector3 = t.joints["sh"][i]
		var sleeve := func(u: float, v: float) -> Vector3:
			var th := u * TAU
			var rr := lerpf(0.105, 0.3, pow(v, 0.9))
			var y := sh.y + 0.04 - v * 0.42 - 0.34 * v * v * maxf(cos(th) * sgn * 0.7 + sin(th) * 0.5, 0.0)
			return Vector3(sh.x + sgn * (0.02 + 0.26 * v) + cos(th) * rr, y, sin(th) * rr * 0.8 + 0.03 * v)
		t.add("body", _shell(t, "sleeve%d" % i, sleeve, 18, 6, 0.014, true), {"arms": 1.0})
		t.band(_edge(sleeve, 0.9, 1.0), 1.2, {"arms": 1.0})
	var y := float(Shrouds.STYLES[5]["fit"]["belt"])
	var sash := func(u: float, v: float) -> Vector3:          # on the robe's own folds, a little proud of them
		var p: Vector3 = fn.call(u, (0.66 - (y + 0.07 - 0.14 * v)) / (0.66 - f))
		return Vector3(p.x * 1.05, p.y, p.z * 1.05)
	t.add("trim", HeroKit.surf("shroud|sash|" + t.tag, sash, 40, 2), {"legs": 0.9})
	var knot := Vector3(0.25, y, -0.25)
	t.add("trim", Models.sphere(0.055, 8), {}, Transform3D(Basis.IDENTITY, knot))
	var long_end := PackedVector3Array([knot, knot + Vector3(0.2, -0.14, 0.2), knot + Vector3(0.3, -0.28, 0.5),
		knot + Vector3(0.2, -0.32, 0.8), knot + Vector3(0.28, -0.36, 1.1)])
	t.add("trim", _ribbon(t, "sashlong", long_end, 0.11, 0.13, Vector3(0.5, 0, -0.5).normalized(), 12),
		{"bone": ShroudSkin.SCARF, "from": knot, "reach": 0.9})
	var short_end := PackedVector3Array([knot, knot + Vector3(0.05, -0.2, 0), knot + Vector3(0.03, -0.42, 0.02)])
	t.add("trim", _ribbon(t, "sashshort", short_end, 0.1, 0.11), {"legs": 0.8})
	_hood_for(t, "robe", hood_up, 0.06)
	for sg in [-1.0, 1.0]:
		var lap := PackedVector3Array([Vector3(0.12 * sg, 0.62, -0.17), Vector3(0.06 * sg, 0.42, -0.3 * t.bw),
			Vector3(-0.01 * sg, 0.2, -0.31 * t.bw)])
		t.add("trim", _ribbon(t, "lapel%d" % int(sg), lap, 0.06, 0.06, Vector3.RIGHT, 5), {})

# ----------------------------------------------------------------------------------------------- 6 Mantle Cape
## The lopsided top: a short stiff cape that juts out over the left arm like a single wing and stops at the shoulder
## on the right, with a short point down the back and a standing collar, over a fitted body and a brief tunic, so
## the legs and the free arm stay in plain sight.
static func _mantle(t: ShroudTailor) -> void:
	var s := t.span
	var fn := func(u: float, v: float) -> Vector3:
		var th := PI * 0.5 + (2.0 * u - 1.0) * (PI - 0.3)
		var left := clampf(-cos(th), -1.0, 1.0)
		var wing := pow(maxf(left, 0.0), 14.0)
		var aft := pow(maxf(sin(th), 0.0), 8.0)
		var bot := lerpf(0.47, 0.36, wing) - 0.5 * aft
		var rr := lerpf(0.13, (0.33 + 0.62 * wing) * s, pow(v, 0.6)) * (1.0 + 0.04 * v * _fold(th, 5.0))
		return Vector3(cos(th) * rr, lerpf(0.68, bot, pow(v, 0.85)), sin(th) * rr * 0.92)
	t.add("body", _shell(t, "mantle", fn, 56, 8, 0.02), {"arms": 0.9, "bone": ShroudSkin.CAPE,
		"from": Vector3(0, 0.62, 0.1), "reach": 0.7, "share": 0.4})
	t.band(_edge(fn, 0.93, 1.0), 2.4, UPPER)
	var collar := func(u: float, v: float) -> Vector3:
		var th := PI * 0.5 + (2.0 * u - 1.0) * 1.45
		var rr := lerpf(0.3, 0.14, pow(v, 0.8))
		return Vector3(cos(th) * rr, lerpf(0.9, 0.62, v), sin(th) * rr + 0.05)
	t.add("alt", _shell(t, "mantlecollar", collar, 16, 4, 0.018), {})
	var tunic := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var rr := lerpf(0.235 * t.bw, 0.27 * t.bw, pow(v, 0.9)) * (1.0 + 0.04 * v * _fold(th, 6.0))
		return Vector3(cos(th) * rr, lerpf(0.05, -0.16, v), sin(th) * rr * 0.92)
	t.add("alt", _shell(t, "mantletunic", tunic, 26, 4, 0.014, true), {"legs": 0.9})
	t.rigid(t.torso, Models.cyl(0.24 * t.bw, 0.24 * t.bw, 0.045, 18), t.m["leather"], Vector3(0, 0.05, 0))
	t.rigid(t.torso, Models.sphere(0.04, 8), t.m["trim"], Vector3(0.13, 0.57, -0.19))
	_collar(t, t.m["body"])

# ---------------------------------------------------------------------------------------------- 7 Shawl & Scarf
## The fat neck and the long tail: a huge rolled scarf as wide as the shoulders right under the head, one end hanging
## down the chest and the other streaming far out behind, over a pointed shawl and a short tunic.
static func _shawl(t: ShroudTailor) -> void:
	var s := t.span
	var roll := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var ph := v * TAU
		var tube := 0.14 * (1.0 + 0.1 * sin(th * 3.0 + 1.0))
		var ring := Vector3(cos(th), 0.0, sin(th)) * 0.235
		return ring + Vector3(cos(th), 0.0, sin(th)) * cos(ph) * tube + Vector3.UP * sin(ph) * tube * 0.82
	t.add("trim", HeroKit.surf("shroud|scarfroll", roll, 26, 9, Callable(), -1.0), {},
		Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 0.665, 0.01)))
	var back := PackedVector3Array([Vector3(0.1, 0.66, 0.28), Vector3(0.16, 0.42, 0.42), Vector3(0.18, 0.12, 0.62),
		Vector3(0.1, -0.08, 0.9), Vector3(0.2, -0.16, 1.2), Vector3(0.14, -0.22, 1.5)])
	t.add("trim", _ribbon(t, "scarfback", back, 0.25, 0.3, Vector3.RIGHT, 16), {"bone": ShroudSkin.SCARF,
		"from": Vector3(0.1, 0.66, 0.28), "reach": 1.2})
	var front := PackedVector3Array([Vector3(-0.1, 0.6, -0.24), Vector3(-0.13, 0.36, -0.3), Vector3(-0.12, 0.1, -0.31),
		Vector3(-0.1, -0.14, -0.33)])
	t.add("trim", _ribbon(t, "scarffront", front, 0.22, 0.26, Vector3.RIGHT, 9), {"legs": 0.4, "bone": ShroudSkin.SKIRT,
		"from": Vector3(-0.1, 0.5, -0.24), "reach": 0.6, "share": 0.4})
	var shawl := func(u: float, v: float) -> Vector3:
		var th := PI * 0.5 + (2.0 * u - 1.0) * (PI - 0.42)
		var aft := pow(maxf(sin(th), 0.0), 2.0)
		var bot := lerpf(0.34, -0.16, aft)
		var rr := lerpf(0.14, 0.39 * s, pow(v, 0.6)) * (1.0 + 0.05 * v * _fold(th, 5.0))
		return Vector3(cos(th) * rr, lerpf(0.66, bot, pow(v, 0.9)), sin(th) * rr * 0.92)
	t.add("body", _shell(t, "shawl", shawl, 34, 7), {"arms": 0.9, "bone": ShroudSkin.CAPE, "from": Vector3(0, 0.6, 0.1),
		"reach": 0.8, "share": 0.35})
	t.band(_edge(shawl, 0.92, 1.0), 2.0, UPPER)
	var tunic := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var rr := lerpf(0.235 * t.bw, 0.31 * t.bw, pow(v, 0.9)) * (1.0 + 0.05 * v * _fold(th, 7.0))
		return Vector3(cos(th) * rr, lerpf(0.05, -0.27, v), sin(th) * rr * 0.92)
	t.add("alt", _shell(t, "shawltunic", tunic, 26, 4, 0.014, true), {"legs": 0.9})

# -------------------------------------------------------------------------------------------- 8 Cowl & Feathers
## The fan: a raised collar of long feathers standing out behind the head like a crest, a shorter feathered mantle on
## the shoulders, and a spray of tail feathers behind a knee-length under-robe.
static func _feathers(t: ShroudTailor, hood_up: bool) -> void:
	t.keep = 1.0        # (each feather is a handful of triangles already: fewer would thin the fan)
	var big := _feather(t, "big", 0.56, 0.17, 0.08)
	var mid := _feather(t, "mid", 0.34, 0.15, -0.04)
	var tail := _feather(t, "tail", 0.82, 0.17, 0.1)
	var n := 13
	for i in n:
		var k := float(i) / (n - 1)
		var th := lerpf(-0.45, PI + 0.45, k)
		var el := lerpf(0.55, 1.1, sin(k * PI))
		var d := Vector3(cos(th) * cos(el), sin(el), sin(th) * cos(el))
		var at := Vector3(cos(th) * 0.17, 0.66, sin(th) * 0.16 + 0.03)
		t.add("trim" if i % 2 == 1 else "body", big, {}, _lay(at, d, th))
	for ring in 2:
		var m2 := 12 + ring * 4
		for i in m2:
			var th := TAU * (i + 0.5 * ring) / m2
			var at := Vector3(cos(th) * (0.2 + 0.1 * ring), 0.63 - 0.1 * ring, sin(th) * (0.19 + 0.09 * ring))
			var d := Vector3(cos(th) * 0.8, -0.72, sin(th) * 0.74)
			t.add("alt" if (i + ring) % 2 == 0 else "body", mid, {"arms": 0.9}, _lay(at, d, th))
	for i in 7:
		var k := float(i) / 6.0
		var th := PI * 0.5 + (k - 0.5) * 1.5
		var d := Vector3(cos(th) * 0.8, -0.34, sin(th) * 0.8 + 0.2)
		t.add("body" if i % 2 == 0 else "trim", tail, {"bone": ShroudSkin.CAPE, "from": Vector3(0, 0.04, 0.2),
			"reach": 0.7}, _lay(Vector3(cos(th) * 0.2, 0.04, sin(th) * 0.2), d, th))
	var robe := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var rr := lerpf(0.245 * t.bw, 0.32 * t.bw, pow(v, 0.9)) * (1.0 + 0.05 * v * _fold(th, 7.0))
		return Vector3(cos(th) * rr, lerpf(0.34, -0.3, v), sin(th) * rr * 0.92)
	t.add("alt", _shell(t, "featherrobe", robe, 30, 6, 0.014, true), {"legs": 0.9})
	t.band(_edge(robe, 0.93, 1.0), 2.0, {"legs": 0.9})
	if hood_up:
		_hood(t, "feathers", t.m["alt"], 0.265, 0.07)
	else:
		_collar(t, t.m["alt"])

# ------------------------------------------------------------------------------------------------- 9 Patchwork
## The stepped sack: panels of two tones cut to different lengths, so the hem falls in square steps, long on one side
## and short on the other, a stuffed shoulder patch, a rope belt, and a floppy hood that droops to one side.
static func _patchwork(t: ShroudTailor, hood_up: bool) -> void:
	var s := t.span
	var f := t.floor_y
	var lens := [0.78, 1.05, 0.62, 1.16, 0.74, 0.5, 0.86, 0.56]
	var out_by := [0.0, 0.09, -0.04, 0.13, 0.02, -0.07, 0.08, -0.05]      # each panel stands out its own way
	var n := lens.size()
	var bodice := func(v: float, th: float) -> float:
		return (lerpf(0.13, 0.36 * s, smoothstep(0.0, 0.22, v)) + 0.1 * v) * (1.0 + 0.012 * sin(th * 11.0))
	for i in n:
		var ln: float = lens[i]
		var low := maxf(0.66 - ln, f + 0.04)
		var a0 := float(i) / n - 0.012
		var a1 := float(i + 1) / n + 0.012
		var panel := func(u: float, v: float) -> Vector3:
			var th := lerpf(a0, a1, u) * TAU + PI * 0.12
			var y := lerpf(0.67, low, v)
			var rr: float = bodice.call((0.67 - y) / 1.1, th) + 0.004 * (i % 2) + float(out_by[i]) * v
			return Vector3(cos(th) * rr, y, sin(th) * rr * 0.92)
		t.add("alt" if i % 2 == 1 else "body", _shell(t, "patch%d" % i, panel, 5, 7, 0.016),
			{"legs": 0.8, "arms": 0.9})
		t.band(_edge(panel, 0.93, 1.0), 0.32, {"legs": 0.8})
	var pad := HeroKit.lumpy("shroud_pad", Vector3(0.19, 0.14, 0.18), 4.0, 0.08)
	t.rigid(t.c["pl"], pad, t.m["alt"], Vector3(-0.05, 0.05, 0))
	for k in 3:
		var at := Vector3(0.1 - k * 0.09, 0.42 - k * 0.14, -0.32 - 0.004 * k)
		t.rigid(t.torso, Models.box(0.1 + k * 0.03, 0.09 + 0.02 * k, 0.012), t.m["trim" if k == 1 else "alt"], at,
			Vector3(0, 0, 0.15 * (k - 1)))
	var y := float(Shrouds.STYLES[9]["fit"]["belt"])
	t.rigid(t.torso, Models.cyl(0.335 * t.bw, 0.335 * t.bw, 0.035, 18), t.m["leather"], Vector3(0, y, 0))
	_hood_for(t, "patch", hood_up, 0.05, 0.0, "alt")
	if hood_up:
		_sock(t)

## The floppy end of the sack hood: a stuffed tube leaving the crown and drooping past the right ear, with a tassel.
static func _sock(t: ShroudTailor) -> void:
	var ends := PackedVector3Array([Vector3(0.02, 0.1, 0.1), Vector3(0.16, 0.3, 0.16), Vector3(0.4, 0.27, 0.2),
		Vector3(0.56, 0.06, 0.2), Vector3(0.6, -0.14, 0.2)])
	var fn := func(u: float, v: float) -> Vector3:
		var r := lerpf(0.17, 0.045, pow(v, 0.8))
		return _curve(ends, v) + Vector3(0, cos(u * TAU), sin(u * TAU)) * r
	t.rigid(t.torso, HeroKit.surf("shroud|sock", fn, 10, 10, Callable(), -1.0), t.m["alt"], Vector3(0, 0.86, 0.015))
	t.rigid(t.torso, Models.sphere(0.06, 8), t.m["trim"], Vector3(0.6, 0.86 - 0.17, 0.215))
