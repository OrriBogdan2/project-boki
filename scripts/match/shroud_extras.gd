class_name ShroudExtras
extends RefCounted
## What a shroud wears on top of its cut: the trim along its edges (geometry, so a pattern costs no texture) and the
## accessory. Both take the accent colour through the model's trim material.

## Each cut's edges wear a band in the accent colour; the pattern adds small marks along it.
static func trim(t: ShroudTailor, kind: int) -> void:
	if t.cached:
		return
	for i in t.bands.size():
		var b: Dictionary = t.bands[i]
		var cols := clampi(int(float(b["len"]) * 14.0), 4, 44)
		var mesh := HeroKit.surf("", b["fn"], cols, 1, Callable(), 1.0)
		t.add("trim", mesh, b["rule"])
		if kind > 0:
			t.add("alt", _marks(b["fn"], float(b["len"]), kind), b["rule"])

## A pattern's marks on a band, as flat quads a hair proud of it (u along the band, w across it).
static func _marks(fn: Callable, metres: float, kind: int) -> ArrayMesh:
	var rects: Array = []        # [u0, u1, w0, w1, slant]
	var n := clampi(int(metres / (0.045 if kind == 1 else 0.09)), 6, 48)
	match kind:
		1:
			for k in n:
				rects.append([(k + 0.2) / n, (k + 0.75) / n, 0.42, 0.58, 0.0])
		2:
			for k in n:
				var g := k % 3
				rects.append([(k + 0.42) / n, (k + 0.58) / n, 0.16, 0.84, 0.0])
				if g != 1:
					var low := 0.72 if g == 0 else 0.42
					rects.append([(k + 0.25) / n, (k + 0.75) / n, low, low + 0.12, 0.0])
				if g != 2:
					rects.append([(k + 0.25) / n, (k + 0.75) / n, 0.2, 0.32, 0.0])
		3:
			rects.append([0.0, 1.0, 0.16, 0.34, 0.0])
			rects.append([0.0, 1.0, 0.66, 0.84, 0.0])
		_:
			for k in n:
				rects.append([float(k) / n, (k + 0.5) / n, 0.14, 0.3, 0.5 / n])
				rects.append([(k + 0.5) / n, (k + 1.0) / n, 0.14, 0.3, -0.5 / n])
				rects.append([(k + 0.25) / n, (k + 0.75) / n, 0.56, 0.86, 0.0])
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cs := PackedColorArray()
	var idx := PackedInt32Array()
	for r in rects:
		var steps := clampi(int((float(r[1]) - float(r[0])) * n), 1, 24)
		for s in steps:
			var a := lerpf(r[0], r[1], float(s) / steps)
			var b := lerpf(r[0], r[1], float(s + 1) / steps)
			var q := [fn.call(a, r[2]), fn.call(b, r[2]), fn.call(b + r[4], r[3]), fn.call(a + r[4], r[3])]
			var nrm: Vector3 = ((q[1] - q[0]) as Vector3).cross((q[3] - q[0]) as Vector3).normalized()
			var base := vs.size()
			for p in q:
				vs.append((p as Vector3) + nrm * 0.004)
				ns.append(nrm)
				uvs.append(Vector2.ZERO)
				cs.append(Color.WHITE)
			for j in [0, 1, 2, 0, 2, 3]:
				idx.append(base + j)
	var arrs := []
	arrs.resize(Mesh.ARRAY_MAX)
	arrs[Mesh.ARRAY_VERTEX] = vs
	arrs[Mesh.ARRAY_NORMAL] = ns
	arrs[Mesh.ARRAY_TEX_UV] = uvs
	arrs[Mesh.ARRAY_COLOR] = cs
	arrs[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	return am

## The accessory, placed by the cut's fit (Shrouds.STYLES): rigid parts on the torso, the lantern on the Skirt spring.
static func accessory(t: ShroudTailor, kind: int, fit: Dictionary) -> void:
	match kind:
		1: _pouches(t, fit)
		2: _satchel(t, fit)
		3: _charm(t, fit)
		4: _lantern(t, fit)
		5: _bandolier(t, fit)

## A strap round the body in a ring tilted from one shoulder to the other hip.
static func _strap(t: ShroudTailor, nm: String, fit: Dictionary, sgn: float, wide: float) -> Mesh:
	var cr := float(fit["chest"]) + 0.02
	var fn := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var y := 0.34 + 0.3 * sgn * cos(th) + (v - 0.5) * wide
		var dip := 1.0 + 0.14 * sin(th) * sin(th)
		return Vector3(cos(th) * (cr + 0.03) * dip, y, sin(th) * cr * dip)
	return HeroKit.surf("shroud|strap|%s|%.3f|%.0f" % [nm, cr, sgn], fn, 30, 1)

static func _belt(t: ShroudTailor, fit: Dictionary) -> void:
	var r := float(fit["waist"]) + 0.012
	t.rigid(t.torso, Models.cyl(r, r, 0.05, 22), t.m["leather"], Vector3(0, float(fit["belt"]), 0))

static func _pouches(t: ShroudTailor, fit: Dictionary) -> void:
	_belt(t, fit)
	var r := float(fit["waist"]) + 0.03
	var y := float(fit["belt"])
	for th in [-0.5, 0.42, 2.7]:
		var at := Vector3(sin(th) * r, y - 0.04, -cos(th) * r)
		t.rigid(t.torso, Models.box(0.1, 0.12, 0.07), t.m["leather"], at, Vector3(0, -th, 0))
		t.rigid(t.torso, Models.box(0.105, 0.04, 0.075), t.m["trim"], at + Vector3(0, 0.05, 0), Vector3(0, -th, 0))

static func _satchel(t: ShroudTailor, fit: Dictionary) -> void:
	t.rigid(t.torso, _strap(t, "sat", fit, 1.0, 0.05), t.m["leather"])
	var r := float(fit["waist"]) + 0.05
	var at := Vector3(-r, -0.02, 0.05)
	t.rigid(t.torso, Models.box(0.1, 0.2, 0.26), t.m["leather"], at)
	t.rigid(t.torso, Models.box(0.11, 0.09, 0.27), t.m["trim"], at + Vector3(0, 0.07, 0))

static func _charm(t: ShroudTailor, fit: Dictionary) -> void:
	var cr := float(fit["chest"]) + 0.015
	var fn := func(u: float, v: float) -> Vector3:
		var a := lerpf(-1.1, 1.1, u)
		return Vector3(sin(a) * 0.16, 0.6 - 0.3 * cos(a * 0.72) + 0.12 + (v - 0.5) * 0.016, -cr + 0.12 * a * a * 0.5)
	t.rigid(t.torso, HeroKit.surf("shroud|charm|%.3f" % cr, fn, 14, 1, Callable(), -1.0), t.m["gold"])
	t.rigid(t.torso, Models.sphere(0.05, 8), t.m["glow"], Vector3(0, 0.38, -cr - 0.02))
	var rim := Models.cyl(0.058, 0.058, 0.014, 10)
	t.rigid(t.torso, rim, t.m["gold"], Vector3(0, 0.38, -cr - 0.012), Vector3(PI * 0.5, 0, 0))

static func _lantern(t: ShroudTailor, fit: Dictionary) -> void:
	_belt(t, fit)
	var r := float(fit["waist"]) + 0.03
	var skirt: Node3D = t.c["skirt"]
	var at := Vector3(r + 0.05, -0.14, -0.04)
	t.rigid(skirt, Models.box(0.09, 0.03, 0.02), t.m["leather"], Vector3(r + 0.02, -0.02, -0.04))
	t.rigid(skirt, Models.cyl(0.008, 0.008, 0.06, 5), t.m["leather"], at + Vector3(0, 0.09, 0))
	t.rigid(skirt, Models.sphere(0.052, 8), t.m["glow"], at)
	t.rigid(skirt, Models.cyl(0.05, 0.062, 0.024, 8), t.m["leather"], at + Vector3(0, 0.07, 0))
	t.rigid(skirt, Models.cyl(0.062, 0.05, 0.018, 8), t.m["leather"], at + Vector3(0, -0.07, 0))

static func _bandolier(t: ShroudTailor, fit: Dictionary) -> void:
	t.rigid(t.torso, _strap(t, "ban", fit, -1.0, 0.075), t.m["leather"])
	var cr := float(fit["chest"]) + 0.05
	for k in 5:
		var a := -0.55 + 0.275 * k
		var at := Vector3(a * 0.5, 0.34 + 0.58 * a * 0.5, -cr)
		t.rigid(t.torso, Models.box(0.05, 0.075, 0.03), t.m["trim"], at, Vector3(0, 0, -0.5))
