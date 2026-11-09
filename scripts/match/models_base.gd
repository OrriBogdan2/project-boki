class_name ModelsBase
## Shaders, materials and the shared mesh primitives. Moved out of Models; callers still use the Models facade.

## Builds every character and prop out of simple meshes. Each character returns a Node3D whose
## meta "mat" holds the ShaderMaterials to flash on hits, and named child nodes for animation.

static var TOON: Shader = preload("res://shaders/toon.gdshader")
static var OUTLINE: Shader = preload("res://shaders/outline.gdshader")
static var RING: Shader = preload("res://shaders/ring.gdshader")
static var GLOW: Shader = preload("res://shaders/glowball.gdshader")
static var HERO: Shader = preload("res://shaders/hero_toon.gdshader")
static var _outline_mat: ShaderMaterial

static func toon(c: Color, outline := true, glow := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("glow", glow)
	if outline:
		if _outline_mat == null:
			_outline_mat = ShaderMaterial.new()
			_outline_mat.shader = OUTLINE
		m.next_pass = _outline_mat
	return m

static func vtoon() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("use_vertex_color", true)
	m.set_shader_parameter("rim_amount", 0.12)
	return m

static func ring_mat(c: Color, thickness := 0.14) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = RING
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("thickness", thickness)
	return m

static func glow_mat(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GLOW
	m.set_shader_parameter("color", c)
	return m

static func part(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO, pname := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	if pname != "":
		mi.name = pname
	ShadowPolicy.judge(mi)       # small parts don't cast (item 94)
	parent.add_child(mi)
	return mi

static var _spheres := {}

## A smooth sphere. The segment count scales with size (so big shapes stay round in close-ups and
## tiny dots stay cheap); `seg` is a floor. Cached, so every eye of every hunter shares one mesh.
static func sphere(r: float, seg := 16) -> SphereMesh:
	var sg := seg + (8 if r > 0.12 else 4)
	if seg > 8 or r >= 0.1:
		sg = maxi(sg, int(clampf(r * 170.0, 16.0, 48.0)))
	sg += sg % 2
	var key := "%.4f|%d" % [r, sg]
	if _spheres.has(key):
		return _spheres[key]
	var s := SphereMesh.new()
	s.radius = r; s.height = r * 2.0; s.radial_segments = sg; s.rings = maxi(8, sg / 2)
	_spheres[key] = s
	return s

static func capsule(r: float, h: float) -> CapsuleMesh:
	var key := "cap|%.4f|%.4f" % [r, h]
	if _spheres.has(key):
		return _spheres[key]
	var c := CapsuleMesh.new()
	c.radius = r; c.height = h; c.radial_segments = int(clampf(r * 380.0, 20.0, 48.0)); c.rings = 16
	_spheres[key] = c
	return c

static var _rbox := {}

## A box with softly rounded edges and corners (a real fillet with several steps, so it shades and
## outlines cleanly instead of reading as a cube). Cached by size, so it costs nothing after the first.
static func box(x: float, y: float, z: float) -> Mesh:
	var mn := minf(x, minf(y, z))
	var r := minf(mn * 0.22, 0.07) if mn >= 0.04 else mn * 0.36
	if r < 0.0015:
		var b := BoxMesh.new()
		b.size = Vector3(x, y, z)
		return b
	var key := "%.4f|%.4f|%.4f" % [x, y, z]
	if _rbox.has(key):
		return _rbox[key]
	var am := rounded_box(Vector3(x, y, z), r, 4 if mn > 0.1 else (3 if mn > 0.03 else 2))
	_rbox[key] = am
	return am

## A rounded box: every face is a grid whose outer rows are bent around the edges and corners on a
## radius r, with `steps` grid lines per 45 degrees of the bend.
static func rounded_box(size: Vector3, r: float, steps := 3) -> ArrayMesh:
	var h := size * 0.5
	var inner := (h - Vector3(r, r, r)).max(Vector3.ZERO)
	var verts := PackedVector3Array(); var norms := PackedVector3Array(); var uvs := PackedVector2Array(); var idx: Array = []
	var axes := [[0, 1, 2], [1, 2, 0], [2, 0, 1]]
	for ax in axes:
		var w: int = ax[0]; var u: int = ax[1]; var v: int = ax[2]
		var cu := _bevel_coords(h[u], inner[u], r, steps)
		var cv := _bevel_coords(h[v], inner[v], r, steps)
		for sgn in [-1.0, 1.0]:
			var base := verts.size()
			for j in cv.size():
				for i in cu.size():
					var p := Vector3.ZERO
					p[w] = h[w] * sgn; p[u] = cu[i]; p[v] = cv[j]
					var cl := p.clamp(-inner, inner)
					var d := p - cl
					var nd := d.normalized() if d.length() > 0.000001 else Vector3.ZERO
					if nd == Vector3.ZERO: nd[w] = sgn
					verts.append(cl + nd * r)
					norms.append(nd)
					uvs.append(Vector2(float(i) / (cu.size() - 1), float(j) / (cv.size() - 1)))
			var nu := cu.size()
			for j in cv.size() - 1:
				for i in nu - 1:
					var a := base + j * nu + i
					_quad(verts, norms, idx, a, a + 1, a + nu + 1, a + nu)
	return _commit(verts, norms, uvs, idx)

## Grid lines across one face of a rounded box: the flat middle, then the bend toward each edge.
static func _bevel_coords(hh: float, ii: float, r: float, steps: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var bend := PackedFloat32Array()
	for k in range(1, steps + 1):
		bend.append(ii + r * tan(PI * 0.25 * float(k) / steps))
	for k in range(bend.size() - 1, -1, -1): out.append(-bend[k])
	if ii > 0.0001:
		out.append(-ii); out.append(ii)
	else:
		out.append(0.0)
	for b in bend: out.append(b)
	out[0] = -hh; out[out.size() - 1] = hh
	return out

## Two triangles for the quad a-b-c-d, wound so they face along the vertex normals (Godot draws
## clockwise faces as the front).
static func _quad(verts: PackedVector3Array, norms: PackedVector3Array, idx: Array, a: int, b: int, c: int, d: int) -> void:
	for tri in [[a, b, c], [a, c, d]]:
		var p0 := verts[tri[0]]; var p1 := verts[tri[1]]; var p2 := verts[tri[2]]
		var fn := (p1 - p0).cross(p2 - p0)
		if fn.length_squared() < 1e-14:
			continue
		var nsum := norms[tri[0]] + norms[tri[1]] + norms[tri[2]]
		if fn.dot(nsum) > 0.0:
			idx.append(tri[0]); idx.append(tri[2]); idx.append(tri[1])
		else:
			idx.append(tri[0]); idx.append(tri[1]); idx.append(tri[2])

static func _commit(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, idx: Array) -> ArrayMesh:
	var arrs := []
	arrs.resize(Mesh.ARRAY_MAX)
	arrs[Mesh.ARRAY_VERTEX] = verts
	arrs[Mesh.ARRAY_NORMAL] = norms
	arrs[Mesh.ARRAY_TEX_UV] = uvs
	arrs[Mesh.ARRAY_INDEX] = PackedInt32Array(idx)
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	return am

static var _lathes := {}

## A smooth solid of revolution around Y: `profile` is (radius, height) from the bottom up. Points
## with radius 0 close the shape on the axis. Normals come from the profile's own curve, so it
## shades as one soft surface. Cached by `key` when one is given.
static func lathe(profile: PackedVector2Array, seg := 24, key := "") -> ArrayMesh:
	if key != "" and _lathes.has(key):
		return _lathes[key]
	var n := profile.size()
	var verts := PackedVector3Array(); var norms := PackedVector3Array(); var uvs := PackedVector2Array(); var idx: Array = []
	var total := 0.0
	var acc := PackedFloat32Array([0.0])
	for i in range(1, n):
		total += profile[i].distance_to(profile[i - 1])
		acc.append(total)
	for i in n:
		var p := profile[i]
		var t := profile[mini(i + 1, n - 1)] - profile[maxi(i - 1, 0)]
		if t.length() < 1e-6: t = Vector2(0, 1)
		t = t.normalized()
		var n2 := Vector2(t.y, -t.x)
		if p.x < 1e-5 and i == 0: n2 = Vector2(0, -1)
		elif p.x < 1e-5 and i == n - 1: n2 = Vector2(0, 1)
		for j in seg + 1:
			var a := TAU * float(j) / seg
			var ca := cos(a); var sa := sin(a)
			verts.append(Vector3(p.x * ca, p.y, p.x * sa))
			norms.append(Vector3(n2.x * ca, n2.y, n2.x * sa).normalized())
			uvs.append(Vector2(float(j) / seg, acc[i] / maxf(total, 1e-5)))
	for i in n - 1:
		for j in seg:
			var a0 := i * (seg + 1) + j
			var b0 := (i + 1) * (seg + 1) + j
			_quad(verts, norms, idx, a0, a0 + 1, b0 + 1, b0)
	var am := _commit(verts, norms, uvs, idx)
	if key != "": _lathes[key] = am
	return am

## A smooth curve through the given points (Catmull-Rom), `sub` steps per span. The ends are kept.
static func smooth_curve(pts: PackedVector2Array, sub := 4) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n - 1:
		var p0 := pts[maxi(i - 1, 0)]; var p1 := pts[i]; var p2 := pts[i + 1]; var p3 := pts[mini(i + 2, n - 1)]
		for k in sub:
			var t := float(k) / sub
			var t2 := t * t; var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[n - 1])
	for i in out.size():
		out[i].x = maxf(out[i].x, 0.0)
	return out

## Rounds every corner of a closed polygon with an arc of radius r (smaller where the sides are short).
static func _fillet(poly: Array, r: float, steps: int) -> Array:
	var out: Array = []
	var n := poly.size()
	for i in n:
		var p: Vector2 = poly[i]
		var a: Vector2 = poly[(i - 1 + n) % n]
		var b: Vector2 = poly[(i + 1) % n]
		var u := (a - p).normalized(); var v := (b - p).normalized()
		var th := acos(clampf(u.dot(v), -1.0, 1.0))
		if th > PI - 0.02 or th < 0.01 or r <= 0.0:
			out.append(p)
			continue
		var d := r / tan(th * 0.5)
		var rr := r
		var dmax := 0.49 * minf(a.distance_to(p), b.distance_to(p))
		if d > dmax:
			d = dmax; rr = d * tan(th * 0.5)
		var t1 := p + u * d
		var c := p + (u + v).normalized() * rr / sin(th * 0.5)
		var a1 := (t1 - c).angle()
		var a2 := (p + v * d - c).angle()
		var da := wrapf(a2 - a1, -PI, PI)
		for k in steps + 1:
			var ang := a1 + da * float(k) / steps
			out.append(c + Vector2(cos(ang), sin(ang)) * rr)
	return out

static var _cyls := {}

## A plain cylinder (open ends possible), for beams and columns of light.
static func plain_cyl(top: float, bottom: float, h: float, seg := 14) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top; c.bottom_radius = bottom; c.height = h; c.radial_segments = seg + 6; c.rings = 1
	return c

## A cylinder or cone with softly rounded rims (and a rounded tip on a cone), so it shades and
## outlines as one clean shape. Hair-thin ones stay plain. Cached by size.
static func cyl(top: float, bottom: float, h: float, seg := 14) -> Mesh:
	var mr := maxf(top, bottom)
	var radial := maxi(seg + 10, int(clampf(mr * 170.0, 16.0, 56.0)))
	if mr < 0.014 or h < 0.012:
		var c := CylinderMesh.new()
		c.top_radius = top; c.bottom_radius = bottom; c.height = h; c.radial_segments = maxi(seg + 2, 8); c.rings = 1
		return c
	var key := "%.4f|%.4f|%.4f|%d" % [top, bottom, h, radial]
	if _cyls.has(key):
		return _cyls[key]
	var hh := h * 0.5
	var poly: Array = []
	poly.append(Vector2(bottom, -hh) if bottom > 0.0005 else Vector2(0.0, -hh))
	poly.append(Vector2(top, hh) if top > 0.0005 else Vector2(0.0, hh))
	if top > 0.0005: poly.append(Vector2(-top, hh))
	if bottom > 0.0005: poly.append(Vector2(-bottom, -hh))
	var bev := clampf(minf(h, 2.0 * mr) * 0.16, 0.0, 0.045)
	var loop := _fillet(poly, bev, 5)
	var prof := _right_half(loop)
	var am := lathe(prof, radial)
	_cyls[key] = am
	return am

## The x >= 0 half of a closed, counter-clockwise outline that is mirror-symmetric about x = 0,
## from where it crosses the axis at the bottom to where it crosses back at the top.
static func _right_half(loop: Array) -> PackedVector2Array:
	var n := loop.size()
	var out := PackedVector2Array()
	var start := -1
	for i in n:
		if (loop[i] as Vector2).x < 0.0 and (loop[(i + 1) % n] as Vector2).x >= 0.0:
			start = i
			break
	if start < 0:
		return out
	var cross := func(p: Vector2, q: Vector2) -> Vector2:
		var t := p.x / (p.x - q.x) if absf(p.x - q.x) > 1e-9 else 0.0
		return Vector2(0.0, lerpf(p.y, q.y, t))
	out.append(cross.call(loop[start], loop[(start + 1) % n]))
	var k := (start + 1) % n
	for _g in n:
		var p: Vector2 = loop[k]
		var q: Vector2 = loop[(k + 1) % n]
		if p.distance_to(out[out.size() - 1]) > 1e-6:
			out.append(p)
		if q.x < 0.0:
			var c: Vector2 = cross.call(p, q)
			if c.distance_to(out[out.size() - 1]) > 1e-6: out.append(c)
			else: out[out.size() - 1] = c
			break
		k = (k + 1) % n
	return out

## A tapered limb along -Y from the joint: rounded at both ends, `r0` at the top, `r1` at the
## bottom, a little fuller a third of the way down (a muscle, a sleeve). Centred like a capsule.
static func limb(r0: float, r1: float, h: float, bulge := 0.08) -> ArrayMesh:
	var key := "limb|%.4f|%.4f|%.4f|%.3f" % [r0, r1, h, bulge]
	if _lathes.has(key):
		return _lathes[key]
	var hh := h * 0.5
	var pts := PackedVector2Array()
	# bottom cap
	for k in 5:
		var a := -PI * 0.5 + PI * 0.5 * float(k) / 4.0
		pts.append(Vector2(cos(a) * r1, -hh + r1 + sin(a) * r1))
	var mid := lerpf(r1, r0, 0.62) * (1.0 + bulge)
	pts.append(Vector2(lerpf(r1, r0, 0.3), lerpf(-hh + r1, hh - r0, 0.3)))
	pts.append(Vector2(mid, lerpf(-hh + r1, hh - r0, 0.66)))
	for k in 5:
		var a := PI * 0.5 * float(k) / 4.0
		pts.append(Vector2(cos(a) * r0, hh - r0 + sin(a) * r0))
	var prof := smooth_curve(pts, 3)
	prof[0] = Vector2(0, -hh); prof[prof.size() - 1] = Vector2(0, hh)
	var am := lathe(prof, int(clampf(maxf(r0, r1) * 380.0, 24.0, 40.0)))
	_lathes[key] = am
	return am

static var _eyes := {}

## A glossy creature eye in one mesh: a dark eyeball with a big coloured iris (lighter toward the
## bottom, like a painted anime eye) and a pupil, all facing -Z. Coloured by vertex, so it squashes
## as one piece when the kin blinks.
static func eye_mesh(r: float, iris: Color, dark := Color("1a1620")) -> ArrayMesh:
	var key := "%.4f|%s" % [r, iris.to_html()]
	if _eyes.has(key):
		return _eyes[key]
	var sm := SphereMesh.new()
	sm.radius = r; sm.height = r * 2.0; sm.radial_segments = 40; sm.rings = 24
	var arrs := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
	var cols := PackedColorArray()
	cols.resize(verts.size())
	var lo := iris.lightened(0.38)
	var pupil := dark.darkened(0.5)
	for i in verts.size():
		var v := verts[i] / r
		var ang := acos(clampf(-v.z, -1.0, 1.0))
		var c := dark
		if ang < 0.78:
			var k := clampf((-v.y * 0.5 + 0.5), 0.0, 1.0)
			c = iris.lerp(lo, smoothstep(0.35, 0.9, k))
			if ang > 0.66: c = c.lerp(dark, 0.55)          # a dark ring round the iris
			if ang < 0.34: c = pupil
		cols[i] = c
	arrs[Mesh.ARRAY_COLOR] = cols
	arrs[Mesh.ARRAY_TANGENT] = null
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	_eyes[key] = am
	return am

## A coat skirt or tunic: flares from r_top down to r_bot over h, with soft cloth folds that deepen
## toward the hem (their normals follow the folds, so they catch the light like painted drapery).
static func skirt(r_top: float, r_bot: float, h: float, folds := 9, amp := 0.07) -> ArrayMesh:
	var key := "skirt|%.4f|%.4f|%.4f|%d|%.3f" % [r_top, r_bot, h, folds, amp]
	if _lathes.has(key):
		return _lathes[key]
	var seg := 72
	var rows := 12
	var hh := h * 0.5
	var surf := func(a: float, t: float) -> Vector3:
		var rr := lerpf(r_bot, r_top, pow(t, 0.85))
		rr *= 1.0 + amp * pow(1.0 - t, 1.4) * sin(float(folds) * a + 0.35 * sin(a * 3.0))
		return Vector3(cos(a) * rr, lerpf(-hh, hh, t), sin(a) * rr)
	var verts := PackedVector3Array(); var norms := PackedVector3Array(); var uvs := PackedVector2Array(); var idx: Array = []
	for i in rows + 1:
		var t := float(i) / rows
		for j in seg + 1:
			var a := TAU * float(j) / seg
			var p: Vector3 = surf.call(a, t)
			var da: Vector3 = (surf.call(a + 0.01, t) as Vector3) - (surf.call(a - 0.01, t) as Vector3)
			var dt: Vector3 = (surf.call(a, minf(t + 0.01, 1.0)) as Vector3) - (surf.call(a, maxf(t - 0.01, 0.0)) as Vector3)
			var nrm := da.cross(dt).normalized()
			if nrm.dot(Vector3(p.x, 0.0, p.z)) < 0.0: nrm = -nrm
			verts.append(p); norms.append(nrm); uvs.append(Vector2(float(j) / seg, t))
	for i in rows:
		for j in seg:
			var a0 := i * (seg + 1) + j
			var b0 := (i + 1) * (seg + 1) + j
			_quad(verts, norms, idx, a0, a0 + 1, b0 + 1, b0)
	# the hem: a short lip turned in underneath, and a cap
	var base := verts.size()
	for j in seg + 1:
		var a := TAU * float(j) / seg
		var p: Vector3 = surf.call(a, 0.0)
		verts.append(p * Vector3(0.9, 1.0, 0.9) + Vector3(0, 0.004, 0)); norms.append(Vector3.DOWN); uvs.append(Vector2(float(j) / seg, 0.0))
	var c := verts.size()
	verts.append(Vector3(0, -hh + 0.004, 0)); norms.append(Vector3.DOWN); uvs.append(Vector2(0.5, 0.0))
	for j in seg:
		_quad(verts, norms, idx, j, j + 1, base + j + 1, base + j)
		var tri := [c, base + j, base + j + 1]
		var fn := (verts[tri[1]] - verts[tri[0]]).cross(verts[tri[2]] - verts[tri[0]])
		if fn.dot(Vector3.DOWN) > 0.0: idx.append_array([tri[0], tri[2], tri[1]])
		else: idx.append_array(tri)
	var am := _commit(verts, norms, uvs, idx)
	_lathes[key] = am
	return am

static var _crystals := {}

## A cut crystal: a faceted prism with a pointed top, flat-shaded on purpose so it glints.
static func crystal(r: float, h: float, sides := 6) -> ArrayMesh:
	var key := "%.4f|%.4f|%d" % [r, h, sides]
	if _crystals.has(key):
		return _crystals[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y0 := -h * 0.5; var y1 := h * 0.18; var y2 := h * 0.5
	var ring0: Array = []; var ring1: Array = []
	for i in sides:
		var a := TAU * float(i) / sides
		ring0.append(Vector3(cos(a) * r * 0.78, y0, sin(a) * r * 0.78))
		ring1.append(Vector3(cos(a) * r, y1, sin(a) * r))
	var tip := Vector3(0, y2, 0)
	var bot := Vector3(0, y0, 0)
	var tris: Array = []
	for i in sides:
		var j := (i + 1) % sides
		tris.append([ring0[i], ring0[j], ring1[j]]); tris.append([ring0[i], ring1[j], ring1[i]])
		tris.append([ring1[i], ring1[j], tip])
		tris.append([bot, ring0[j], ring0[i]])
	for t in tris:
		var a: Vector3 = t[0]; var b: Vector3 = t[1]; var c: Vector3 = t[2]
		var fn := (b - a).cross(c - a).normalized()
		var out := ((a + b + c) / 3.0).normalized() if ((a + b + c) / 3.0).length() > 1e-5 else Vector3.UP
		if fn.dot(out) > 0.0:
			var tmp := b; b = c; c = tmp
			fn = -fn
		for p in [a, b, c]:
			st.set_normal(-fn)
			st.add_vertex(p)
	var am := st.commit()
	_crystals[key] = am
	return am

## A glossy material: metal, gems, polished things catch a crisp highlight.
static func shiny(c: Color, gloss := 0.6) -> ShaderMaterial:
	var m := toon(c)
	m.set_shader_parameter("gloss", gloss)
	m.set_shader_parameter("paint", 0.03)
	return m

static func flat_quad(size: float) -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = Vector2(size, size)
	return p
