class_name Models
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

# ---------------------------------------------------------------- hunters
## Looks a player can pick for their hunter. Purely visual: the body's size never changes the hitbox.
# Natural tones first, then the wild ones (sky, moss, lilac, gold, stone...). New entries only ever
# go on the end, so saved looks keep their colours.
const LOOK_SKIN := [Color("f6d3b0"), Color("f1c9a0"), Color("e0ac7e"), Color("c68a5c"), Color("9a6440"), Color("6e4428"), Color("4a2e1e"),
	Color("fff0e6"), Color("3a2216"), Color("8ab4ff"), Color("4a6ad8"), Color("8ad07a"), Color("4f8f45"), Color("c4a2f0"), Color("7a4ab8"),
	Color("ff9ab8"), Color("e8c050"), Color("5ac8c0"), Color("d8604a"), Color("9a9aa8"), Color("e8eef8"), Color("ff8a3a")]
const LOOK_HAIR := [Color("2b2124"), Color("5a3a26"), Color("9a6a3a"), Color("e8c87a"), Color("d8d2c8"), Color("c4462e"), Color("6a8aff"), Color("ff8ac8"),
	Color("f6efd8"), Color("8a2e2a"), Color("3ac8c0"), Color("8a4ad8"), Color("5ac85a"), Color("ff8a2a"), Color("c8a8ff"), Color("9af0c8"),
	Color("d81e3c"), Color("2a3a7a"), Color("fbfbfb"), Color("ffd84a")]
const LOOK_BODIES := ["Slim", "Average", "Sturdy"]
const LOOK_GENDERS := ["Female", "Male"]
const LOOK_FACES := ["Bright eyes", "Calm", "Sleepy", "Cheerful", "Fierce", "Wink", "Starry", "Determined", "Smug"]
const LOOK_HAIRS := ["Short", "Long", "Ponytail", "Bun", "Spiky", "Buzzed", "Bob", "Pigtails", "Braid", "Mohawk", "Afro", "Curly", "Swoop", "Bald"]
## What grows on each race's head: every race has its own styles (all take the hair colour). The
## look's "hair" is an index into its race's list (looks saved before this, without "hair_v", held an
## index into LOOK_HAIRS for every race, and are mapped to the closest style with HAIR_FROM_OLD).
const HAIR_STYLES := {
	"human": LOOK_HAIRS,
	"vulpin": ["Fluffy tuft", "Mane", "Long fur", "Brush tail", "Spiky fur", "Sleek", "Fringe"],
	"stoneborn": ["Crystal crown", "Crystal ridge", "Stone ridge", "Moss cap", "Geode"],
	"sprig": ["Leaf crown", "Flower bud", "Vine locks", "Sprout", "Petal bob", "Toadstool"],
	"scalefolk": ["Crest", "Frills", "Horns", "Spines", "Twin crest"],
	"owlet": ["Ear tufts", "Feather crest", "Plume", "Fluffy crown", "Swept back", "Long plumes"],
}
## Old shared-list index (Short, Long, Ponytail, Bun, Spiky, Buzzed, Bob, Pigtails, Braid, Mohawk,
## Afro, Curly, Swoop, Bald) to the closest style of each race.
const HAIR_FROM_OLD := {
	"vulpin": [0, 2, 3, 0, 4, 5, 6, 3, 3, 1, 1, 0, 6, 5],
	"stoneborn": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	"sprig": [3, 2, 2, 1, 0, 3, 4, 2, 2, 0, 5, 0, 4, 3],
	"scalefolk": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	"owlet": [0, 5, 2, 3, 1, 0, 4, 5, 2, 1, 3, 3, 4, 0],
}

## The head styles a race can pick from (by race index).
static func hair_styles(race: int) -> Array:
	return HAIR_STYLES[String(RACES[clampi(race, 0, RACES.size() - 1)]["id"])]
## Outfits: a player's own colourway (their clothes at home; in a match it only tints the Warden's
## palette, MantleLook). A caller can name one by key to dress any hunter in it (galleries). The keys
## stay as they were so saved looks keep their colours.
const LOOK_OUTFITS := ["Lilac", "Nightshade", "Glacier", "Sage", "Saddle", "Ember", "Ivory", "Tusk", "Gilded"]
const OUTFIT_KEYS := ["veil", "nyx", "kestrel", "sage", "marlow", "pyra", "bastion", "tusk", "halo"]
const OUTFIT_COLS := [Color("c9bcff"), Color("b06ae0"), Color("6ad0e0"), Color("9ee2a0"), Color("e0b05a"), Color("ff7a5a"), Color("e6dbc4"), Color("c08a5a"), Color("f2d47a")]
const LOOK_DETAILS := ["None", "Freckles", "Scar", "Face paint", "Stubble", "Beard", "Moustache", "Beauty mark"]

## Races: each one changes the whole silhouette (size, head, build and features), so hunters read as
## different people at a glance from the high match camera. Purely visual: the hitbox comes from the
## class, never the race. "skin": the skin colour picked when you switch to it.
const RACES := [
	{"id": "human", "name": "Human", "scale": 1.0, "head": 1.0, "bulk": 1.0, "skin": 1,
		"desc": "Adaptable folk from every corner of the Skylands."},
	{"id": "vulpin", "name": "Vulpin", "scale": 0.95, "head": 1.06, "bulk": 0.94, "skin": 2,
		"desc": "Fox-eared and quick, with a big brush of a tail."},
	{"id": "stoneborn", "name": "Stoneborn", "scale": 1.17, "head": 0.86, "bulk": 1.3, "skin": 19,
		"desc": "Huge, slow-spoken folk of living rock, with crystals growing out of them."},
	{"id": "sprig", "name": "Sprig", "scale": 0.8, "head": 1.26, "bulk": 0.86, "skin": 11,
		"desc": "Tiny forest sprites with leaf wings and far too much nerve."},
	{"id": "scalefolk", "name": "Scalefolk", "scale": 1.06, "head": 0.96, "bulk": 1.02, "skin": 12,
		"desc": "Sun-loving lizardfolk with a crest and a long tail."},
	{"id": "owlet", "name": "Owlet", "scale": 0.92, "head": 1.18, "bulk": 1.06, "skin": 2,
		"desc": "Wide-eyed bird folk with ear tufts and a feather tail."},
]
const LOOK_RACES := ["Human", "Vulpin", "Stoneborn", "Sprig", "Scalefolk", "Owlet"]

static func default_look() -> Dictionary:
	return {"race": 0, "body": 1, "gender": 1, "face": 0, "skin": 1, "hair": 0, "hair_v": 2, "hair_col": 0, "detail": 0, "outfit": 3}

## A random look for bots and background hunters: any race, any style, the race's own colouring
## most of the time.
static func random_look(rng: RandomNumberGenerator = null) -> Dictionary:
	var R := func(n: int) -> int: return (rng.randi() if rng else randi()) % n
	var race := int(R.call(RACES.size()))
	var skin: int = int(RACES[race]["skin"]) if int(R.call(3)) > 0 else int(R.call(LOOK_SKIN.size()))
	if race == 0: skin = int(R.call(8))
	var gl := "classic" if int(R.call(5)) < 3 else String(Gliders.LIST[int(R.call(Gliders.LIST.size()))]["id"])
	return {"glider": gl, "race": race, "body": R.call(3), "gender": R.call(2), "face": R.call(LOOK_FACES.size()), "skin": skin,
		"hair": R.call(hair_styles(race).size()), "hair_v": 2, "hair_col": R.call(LOOK_HAIR.size()), "detail": R.call(LOOK_DETAILS.size()),
		"outfit": R.call(LOOK_OUTFITS.size())}

## A saved look with every value inside its list (older saves had a third gender option).
static func clean_look(lk: Dictionary) -> Dictionary:
	var out := default_look()
	out.merge(lk, true)
	var lists := {"race": LOOK_RACES, "body": LOOK_BODIES, "gender": LOOK_GENDERS, "face": LOOK_FACES, "skin": LOOK_SKIN, "hair_col": LOOK_HAIR, "detail": LOOK_DETAILS, "outfit": LOOK_OUTFITS}
	for k in lists:
		out[k] = clampi(int(out[k]), 0, (lists[k] as Array).size() - 1)
	var rid := String(RACES[int(out["race"])]["id"])
	if not lk.has("hair_v") and HAIR_FROM_OLD.has(rid):
		out["hair"] = HAIR_FROM_OLD[rid][clampi(int(out["hair"]), 0, LOOK_HAIRS.size() - 1)]
	out["hair_v"] = 2
	out["hair"] = clampi(int(out["hair"]), 0, hair_styles(int(out["race"])).size() - 1)
	return out

## How each class reads at a glance from the match camera, whatever the race or outfit (purely
## visual): overall size on top of the class scale (about 0.88 / 1.0 / 1.18 in all), build, boots,
## weapon size, and the class emblem on the pack (light: a chevron, medium: a diamond, heavy: a shield).
## Stylized like a hero brawler: big heads and hands, small tidy feet, tapered limbs, and a strong
## shoulder line per class ("pad_l"/"pad_r": pauldron size each side, "hands": glove size).
const CLASS_LOOK := {
	"light": {"size": 0.95, "build": 0.84, "boots": 0.84, "weapon": 0.98, "pad_l": 0.78, "pad_r": 0.78, "hands": 1.14},
	"medium": {"size": 1.0, "build": 1.0, "boots": 0.92, "weapon": 1.15, "pad_l": 1.32, "pad_r": 0.86, "hands": 1.2},
	"heavy": {"size": 1.035, "build": 1.14, "boots": 1.06, "weapon": 1.42, "pad_l": 1.85, "pad_r": 1.85, "hands": 1.5},
}

## The class's own marks: its emblem on top of the pack in the class colour (seen from above), a
## trailing scarf for lights, a plated collar and back plate for heavies.
## The class colour, made vivid enough to read on a badge (its own material: hits flash per hunter).
static func class_mat(cls: String) -> ShaderMaterial:
	var cc: Color = Data.CLASSES.get(cls, {}).get("color", Color.WHITE)
	cc = Color.from_hsv(cc.h, maxf(cc.s, 0.6), maxf(cc.v, 0.95))
	var m := toon(cc, true, 0.35)
	m.set_shader_parameter("gloss", 0.5)
	return m

## A named pivot on the torso that parts hang from (skirt, cape, scarf), made once and shared.
static func _pivot(torso: Node3D, nm: String, at: Vector3) -> Node3D:
	var n := torso.get_node_or_null(nm) as Node3D
	if n == null:
		n = Node3D.new(); n.name = nm; n.position = at
		torso.add_child(n)
	return n

static func _class_marks(torso: Node3D, cls: String, bw: float, m_acc: Material, m_trim: Material) -> void:
	var m_cls := class_mat(cls)
	var at := Vector3(0, 0.655, 0.27 * bw)
	var tilt := Vector3(-1.05, 0, 0)          # lying back on the rolled wing, facing up and back
	match cls:
		"light":
			for sx in [-1.0, 1.0]:
				part(torso, box(0.035, 0.15, 0.025), m_cls, at + Vector3(0.045 * sx, 0.0, 0.0), Vector3.ONE, tilt + Vector3(0, 0, 0.6 * sx))
		"medium":
			part(torso, box(0.12, 0.12, 0.025), m_cls, at, Vector3.ONE, tilt + Vector3(0, 0, PI * 0.25))
		"heavy":
			part(torso, box(0.2, 0.16, 0.03), m_cls, at + Vector3(0, 0.01, 0.0), Vector3.ONE, tilt)
			part(torso, box(0.08, 0.06, 0.032), m_trim, at + Vector3(0, 0.012, 0.005), Vector3.ONE, tilt)

## The hunter's chest and back as one smooth sculpted shape: narrow at the waist, full through the
## ribs, broad at the shoulders and rounded over into the neck. About 0.62 tall, centred.
static func torso_mesh() -> ArrayMesh:
	var key := "torso"
	if _lathes.has(key):
		return _lathes[key]
	var pts := PackedVector2Array([Vector2(0.0, -0.31), Vector2(0.13, -0.305), Vector2(0.2, -0.27), Vector2(0.218, -0.17), Vector2(0.205, -0.05),
		Vector2(0.212, 0.05), Vector2(0.236, 0.14), Vector2(0.248, 0.205), Vector2(0.236, 0.255), Vector2(0.19, 0.293), Vector2(0.11, 0.312), Vector2(0.0, 0.318)])
	var am := lathe(smooth_curve(pts, 4), 56)
	_lathes[key] = am
	return am

## A hunter: the class sets the size and hit radius, the archetype (HeroKit.ARCHES; by default the
## class's own) the silhouette and gear, and the look the person inside it: a player's look
## (PlayerLook) becomes the Warden's likeness nudged by the player (MantleLook), or the player's own
## person for a look from MantleLook.at_home(). outfit names a colourway that replaces the palette
## (galleries); "bare" leaves the head uncovered. arch "" takes the look's "arch", else the class default.
static func hunter(cls: String, team_col: Color, weapon: String, outfit := "", appearance := {}, arch := "") -> Node3D:
	ShadowPolicy.keep += 1       # a Hunter's parts cast at any size
	var root := _hunter(cls, team_col, weapon, outfit, appearance, arch)
	ShadowPolicy.keep -= 1
	return root

static func _hunter(cls: String, team_col: Color, weapon: String, outfit := "", appearance := {}, arch := "") -> Node3D:
	var um := Unmasked.is_look(appearance)       # your own character: the hunter rig without a hunter's gear
	var lk: Dictionary
	var race: Dictionary
	if um:
		# the Unmasked as MantleLook's own-person params (every slider neutral), its build and colour
		lk = MantleLook.own(PlayerLook.clean(Unmasked.legacy(appearance)))
		lk["build"] = float(Unmasked.BUILD_WIDTH[int(Unmasked.clean(appearance)["build"])])
		lk["skin_col"] = Unmasked.VOID_SKIN
		race = Unmasked.race(appearance)
		arch = "unmasked"
	else:
		arch = HeroKit.arch_for(cls, arch, appearance)
		lk = MantleLook.params(arch, appearance)
		if lk["own"]:
			arch = ""            # your own person at home: no Warden's gear, shape or class size
			cls = "medium"
		race = RACES[int(lk["race"])]
	var rid: String = race["id"]
	var root := Node3D.new()
	var bare := outfit == "bare"
	var oi: int = OUTFIT_KEYS.find(outfit)
	var hero_col: Color = OUTFIT_COLS[oi] if oi >= 0 else lk["outfit_col"]
	if um: hero_col = Unmasked.colour(appearance)      # the shroud's colour
	# the outfit is the gear's colourway: a saturated coat, a pale shirt, dark trousers, team colour
	# on the strongest shapes (hood, cape, crest, pauldron tops, shield), gold on the edges
	# a clean value structure (dark trousers and leather, a mid-dark coat, light shirt and trim), each
	# colour set in HSV from the outfit's hue so nothing goes muddy; the team colour is kept off the
	# cloth and only marks the key shapes
	var coat_col := Color.from_hsv(hero_col.h, clampf(hero_col.s * 1.1, 0.06, 0.7), clampf(hero_col.v * 0.6, 0.36, 0.6))
	var shirt_col := Color.from_hsv(hero_col.h, clampf(hero_col.s * 0.45, 0.04, 0.3), 0.9)
	var pants_col := Color.from_hsv(fposmod(coat_col.h + 0.02, 1.0), 0.28, 0.2)
	var m_body := toon(coat_col)
	var m_shirt := toon(shirt_col)
	var m_pants := toon(pants_col)
	var m_leather := toon(Color("6b4330").lerp(hero_col, 0.06))
	var skin_c: Color = lk["skin_col"]
	var hair_c: Color = lk["hair_col"]
	var m_skin := toon(skin_c)
	var m_hair := toon(hair_c)
	var m_dark := toon(Color("2b2a33"))
	var m_acc := toon(Color.from_hsv(team_col.h, minf(1.0, team_col.s * 1.08), team_col.v * 0.94))
	var m_gold := shiny(Color("dcaa48"), 0.65); m_gold.set_shader_parameter("glow", 0.08)
	var m_gun := shiny(Color("4a4d5c"), 0.5)
	var m_hero := toon(Color.from_hsv(hero_col.h, clampf(hero_col.s * 1.05, 0.06, 0.8), clampf(hero_col.v * 0.85, 0.45, 0.85)))
	var m_trim := toon(Color.from_hsv(hero_col.h, clampf(hero_col.s * 0.9, 0.05, 0.75), clampf(hero_col.v * 0.95, 0.55, 0.95)))
	var m_steel := shiny(Color("b0b2b8").lerp(hero_col, 0.06), 0.6)      # dark gunmetal: the highlights and the fresnel do the work
	var m_glow := toon(hero_col.lerp(Color.WHITE, 0.35), false, 1.4)
	var m_glow_soft := StandardMaterial3D.new()
	m_glow_soft.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_glow_soft.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m_glow_soft.albedo_color = Color(hero_col.lerp(Color.WHITE, 0.5), 0.28)
	m_glow_soft.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var m_bone := toon(Color("efe3c8"))
	var m_wood := toon(Color("7a5236"))
	var m_fur := toon(Color("4a3428").lerp(hero_col, 0.08))
	var m_feather := toon(Color("f6f0e2"))
	var m_cloak := toon(Color.from_hsv(hero_col.h, clampf(hero_col.s * 0.9, 0.06, 0.6), clampf(hero_col.v * 0.5, 0.3, 0.5)))
	var m_hat := toon(Color("6e4a30").lerp(hero_col, 0.1))
	for mm in [m_body, m_shirt, m_hair, m_acc, m_hero, m_trim, m_cloak, m_hat, m_feather]:
		(mm as ShaderMaterial).set_shader_parameter("rim_amount", 0.75)
	m_skin.set_shader_parameter("sss", 0.45)
	m_hair.set_shader_parameter("gloss", 0.35)
	m_leather.set_shader_parameter("gloss", 0.15)
	m_bone.set_shader_parameter("gloss", 0.3)
	for mm in [m_body, m_shirt, m_pants, m_acc, m_hero, m_trim, m_cloak, m_feather]:
		painted(mm, 1, 0.3, 0.3, 0.26)
	painted(m_leather, 2, 0.26, 0.26, 0.24); painted(m_hat, 2, 0.26, 0.24, 0.24); painted(m_dark, 2, 0.18, 0.2, 0.2)
	painted(m_skin, 4, 0.0, 0.0, 0.18)     # no part gradient on skin: the jaw, nose and ears would show seams
	painted(m_hair, 5, 0.3, 0.24, 0.24); painted(m_fur, 5, 0.3, 0.3, 0.3)
	painted(m_gun, 3, 0.12, 0.1, 0.1); painted(m_gold, 3, 0.1, 0.0, 0.0); painted(m_steel, 3, 0.14, 0.12, 0.14); m_steel.set_shader_parameter("sky_ao", 0.12)
	painted(m_bone, 0, 0.3, 0.2, 0.2); painted(m_wood, 2, 0.2, 0.2, 0.2)
	m_acc.set_shader_parameter("gloss", 0.12)
	var rig := Node3D.new(); rig.name = "Rig"; root.add_child(rig)
	var legs := Node3D.new(); legs.name = "Legs"; rig.add_child(legs)
	var bw: float = lk["build"]
	bw *= float(CLASS_LOOK.get(cls, {}).get("build", 1.0)) * float(Arch.body(arch).get("build", 1.0))
	var boot_k := float(CLASS_LOOK.get(cls, {}).get("boots", 1.0))
	var fem := int(lk["gender"]) == 0
	var heavy_gear := arch in ["juggernaut", "bulwark", "dredge", "ashwick"]
	# legs swing from the hip: a tapered thigh, a knee guard, and a boot in one piece hanging from
	# the knee (so the leg can bend), with a cuff that overlaps the trousers
	var knees := {}
	for sx in [-1.0, 1.0]:
		var leg := Node3D.new(); leg.name = "LegL" if sx < 0.0 else "LegR"
		leg.position = Vector3(0.11 * sx * bw, 0.44, 0)
		legs.add_child(leg)
		part(leg, limb(0.108 * bw, 0.068 * bw, 0.34, 0.16), m_pants, Vector3(0, -0.12, 0))
		var knee := Node3D.new(); knee.name = "Knee"; knee.position = Vector3(0, -0.2, 0)
		leg.add_child(knee)
		knees["L" if sx < 0.0 else "R"] = knee
		if not heavy_gear:
			part(knee, sphere(0.068, 14), m_pants, Vector3(0, 0.0, 0.0))      # (plate knee cops cover it on heavies)
			part(knee, HeroKit.dome_plate("kneepad", 0.065, 0.45, 0.8, 0.2, 0.012), m_leather if arch != "thief" else m_dark, Vector3(0, 0.0, -0.045), Vector3.ONE, Vector3(-PI * 0.5 + 0.1, 0, 0))
		part(knee, HeroKit.boot(boot_k), m_leather, Vector3.ZERO)
		part(knee, HeroKit.sole(boot_k), m_dark, Vector3.ZERO)
		part(knee, HeroKit.cuff(0.074, 0.088, 0.06), m_steel if heavy_gear else (m_trim if arch != "thief" else m_leather), Vector3(0, -0.06, 0.005))
	legs.scale.y = lk["limbs"] * float(Arch.body(arch).get("legs", 1.0))      # the Warden's leg length
	var torso := Node3D.new(); torso.name = "Torso"; torso.position = Vector3(0, 0.42 * legs.scale.y, 0); rig.add_child(torso)
	root.set_meta("hip_y", torso.position.y)      # HunterAnim keeps the torso on the legs at this height
	var chest_w := bw * (0.92 if fem else 1.12) * float(lk["shoulders"])
	# hips, then the sculpted torso (waist, ribcage, chest or bust, shoulder blades), then the neck
	# flaring into the shoulders so the head sits on the body, not on a peg
	part(torso, lathe(smooth_curve(PackedVector2Array([Vector2(0, -0.08), Vector2(0.18, -0.07), Vector2(0.225, -0.02), Vector2(0.22, 0.06), Vector2(0.2, 0.1), Vector2(0, 0.1)]), 3), 40, "hips"),
		m_pants, Vector3(0, 0.02, 0), Vector3((1.04 if fem else 1.0) * bw, 1.0, bw))
	part(torso, HeroKit.torso(fem), m_body, Vector3(0, 0.33, 0), Vector3(chest_w, 1.0, bw * 0.9))
	var nr := 0.072 if fem else 0.088
	part(torso, lathe(smooth_curve(PackedVector2Array([Vector2(0, 0.0), Vector2(nr * 2.0, 0.0), Vector2(nr * 1.3, 0.035), Vector2(nr, 0.08), Vector2(nr * 0.98, 0.16), Vector2(0, 0.16)]), 3), 28, "neck%.3f" % nr), m_skin, Vector3(0, 0.58, 0))
	var skirt_n := _pivot(torso, "Skirt", Vector3(0, 0.07, 0))
	# the glider pack: a rolled wing on a back plate (under whatever the archetype carries)
	if not um:      # (the Empty's shroud covers its back)
		part(torso, box(0.3, 0.32, 0.1), m_leather, Vector3(0, 0.36, 0.24 * bw))
		part(torso, cyl(0.075, 0.075, 0.44, 12), toon(Color("f3eee2")), Vector3(0, 0.56, 0.27 * bw), Vector3.ONE, Vector3(0, 0, PI / 2))
		for sx in [-1.0, 1.0]:
			part(torso, cyl(0.08, 0.08, 0.06, 12), m_acc, Vector3(0.2 * sx, 0.56, 0.27 * bw), Vector3.ONE, Vector3(0, 0, PI / 2))
	if not um: _class_marks(torso, cls, bw, m_acc, m_trim)      # (the shroud covers the back it would sit on)
	# head: the sculpted head (jaw, cheeks, brow, chin per race and gender) with its face
	var hk := HeroKit.head_key(rid, fem)
	part(torso, HeroKit.head(hk), m_skin, Vector3(0, 0.86, 0), Vector3.ONE, Vector3.ZERO, "Head")
	if rid == "human" and not um:
		for sx in [-1.0, 1.0]:
			var ear := HeroKit.loft("ear", [Vector3(0, -0.035, 0), Vector3(0, 0.0, 0.008), Vector3(0, 0.035, 0.02)], [Vector2(0.03, 0.012), Vector2(0.04, 0.014), Vector2(0.022, 0.01)], 10, Vector3.RIGHT, 0.75)
			part(torso, ear, m_skin, Vector3(0.226 * sx * (1.03 if not fem else 0.98), 0.85, 0.012), Vector3.ONE, Vector3(0, 0.25 * sx, 0))
	if um: Unmasked.face(torso, appearance)
	else: _face(torso, lk, m_dark, m_skin, team_col)
	# what the archetype wears on its head decides how much hair shows (a hat: all but the crown; a
	# hood or helm: only what spills out below)
	var cov := HeroGear.cover(arch, bare)
	var hair_n := Node3D.new(); hair_n.name = "Hair"; torso.add_child(hair_n)
	if rid == "human":
		HeroHair.human(hair_n, int(lk["hair"]), fem, m_hair, hk, cov)
	else:
		_race_hair(hair_n, rid, int(lk["hair"]), m_hair, hair_c, skin_c, cov in ["hood", "helm"])
	_race_parts(torso, rid, m_skin, m_hair, m_dark, skin_c, hair_c, hero_col)
	var gear := Node3D.new(); gear.name = "Gear"; torso.add_child(gear)
	# the arms and the gun move together from the shoulders ("Aim"), for recoil, reloads and poses
	var aim := Node3D.new(); aim.name = "Aim"; aim.position = Vector3(0, 0.5, 0.0); torso.add_child(aim)
	var gun := Node3D.new(); gun.name = "Gun"; gun.position = Vector3(0.22, -0.18, -0.18); aim.add_child(gun)
	# arms: they hang from the shoulders with an elbow and a hand on joints of their own, so HunterAnim
	# can put the hands on the weapon's grips (solving the elbows) or let them swing free.
	# ArmXPivot (shoulder) > sleeve, Elbow > forearm "ArmX" and a cuff, Hand > a mitten glove.
	# Rounded joints overlap at the shoulder and elbow so a bent arm never shows a gap.
	var hk2 := float(CLASS_LOOK.get(cls, {}).get("hands", 1.0)) * (1.3 if arch == "juggernaut" else 1.0)
	var m_glove: Material = m_skin if um else (m_steel if heavy_gear else (m_dark if arch == "thief" else m_leather))
	var arms := {}
	# (archetype body "arms": long arms as its art draws them; HunterAnim solves the same lengths)
	var arm_k := float(Arch.body(arch).get("arms", 1.0))
	root.set_meta("arm_k", arm_k)
	for sx in [-1.0, 1.0]:
		var sd := "L" if sx < 0.0 else "R"
		var piv := Node3D.new(); piv.name = "Arm%sPivot" % sd; piv.position = Vector3(0.215 * sx * chest_w,
				0.5 * float(Arch.body(arch).get("torso", 1.0)), 0.0)
		piv.position.x *= float(Arch.body(arch).get("shoulder", 1.0))
		torso.add_child(piv)
		part(piv, sphere(0.088, 16), m_body, Vector3(0, -0.005, 0), Vector3(1.0, 1.0, 1.0))
		part(piv, limb(0.088, 0.064, 0.25, 0.16), m_body, Vector3(0, -0.1, 0))
		var elbow := Node3D.new(); elbow.name = "Elbow"; elbow.position.y = -0.21 * arm_k; piv.add_child(elbow)
		part(elbow, sphere(0.064, 14), m_body)
		part(elbow, limb(0.068, 0.05, 0.22, 0.14), m_body, Vector3(0, -0.09, 0), Vector3.ONE, Vector3.ZERO, "Arm" + sd)
		var hand := Node3D.new(); hand.name = "Hand"; hand.position.y = -0.235 * arm_k; elbow.add_child(hand)
		part(hand, HeroKit.mitten(), m_glove, Vector3(0, 0.0, 0.0), Vector3(hk2, hk2, hk2) * Vector3(1.0, 1.0, 1.0))
		part(hand, HeroKit.thumb(), m_glove, Vector3(-0.042 * sx * hk2, 0.01, -0.03 * hk2), Vector3.ONE * hk2, Vector3(0, 0, 0.35 * sx))
		part(hand, HeroKit.cuff(0.062 * hk2, 0.078 * hk2, 0.05), m_glove if heavy_gear else m_leather, Vector3(0, 0.065, 0))
		if arch == "juggernaut":
			for k in 3:
				_spike(hand, m_bone, Vector3((k - 1) * 0.03 * hk2, -0.09 * hk2, -0.05 * hk2), Vector3(0, -0.3, -1.0), 0.014, 0.05)
		arms[sd] = [piv, elbow, hand]
	# shoulder pieces hang on their own pivots at the shoulders, which HunterAnim turns part of the
	# way with the arm, so raised arms never come up through the plate
	var pads := {}
	for sx in [-1.0, 1.0]:
		var pd := Node3D.new(); pd.name = "PauldronL" if sx < 0.0 else "PauldronR"
		pd.position = Vector3(0.215 * sx * chest_w, 0.5, 0.0)
		torso.add_child(pd)
		pads["L" if sx < 0.0 else "R"] = pd
	var ctx := {"torso": torso, "skirt": skirt_n, "gear": gear, "pl": pads["L"], "pr": pads["R"], "arms": arms, "knees": knees, "bw": bw, "cw": chest_w,
		"fem": fem, "rid": rid, "hk": hk, "bare": bare, "arch": arch, "hero_col": hero_col,
		"m": {"body": m_body, "shirt": m_shirt, "pants": m_pants, "leather": m_leather, "skin": m_skin, "hair": m_hair, "dark": m_dark, "acc": m_acc,
			"gold": m_gold, "gun": m_gun, "hero": m_hero, "trim": m_trim, "steel": m_steel, "glow": m_glow, "glow_soft": m_glow_soft, "bone": m_bone,
			"wood": m_wood, "fur": m_fur, "feather": m_feather, "cloak": m_cloak, "hat": m_hat}}
	if um: Unmasked.dress(ctx, appearance)
	else: HeroGear.dress(arch, ctx)
	gun_parts(gun, weapon, m_gun, m_dark, m_acc)
	gun.scale = Vector3.ONE * float(CLASS_LOOK.get(cls, {}).get("weapon", 1.0))     # heavies carry big guns
	if not gun.has_node("Mag"):
		part(gun, box(0.06, 0.15, 0.09), m_acc, Vector3(0, -0.13, -0.24), Vector3.ONE, Vector3(0.15, 0, 0), "Mag")
	if not gun.has_node("Muzzle"):
		var muzzle := Node3D.new(); muzzle.name = "Muzzle"; muzzle.position = Vector3(0, 0.02, -0.75); gun.add_child(muzzle)
	var shoulder := Node3D.new(); shoulder.name = "Shoulder"; shoulder.position = Vector3(-0.3, 0.8, 0.04); torso.add_child(shoulder)
	# a paraglider canopy that unfolds above the pack: an arched wing in stripes, with lines down to the harness
	var glider := Node3D.new(); glider.name = "Glider"; glider.position = Vector3(0, 0.62, 0.12); glider.visible = false
	torso.add_child(glider)
	var canopy := MeshInstance3D.new()
	var gskin := String(lk["glider"])
	canopy.mesh = Gliders.mesh(gskin, team_col, hero_col)
	canopy.material_override = vtoon_outlined()
	canopy.position = Vector3(0, 1.05, 0.02)
	glider.add_child(canopy)
	glider.set_meta("skin", gskin)
	var gtrail := Gliders.trail(gskin, team_col, hero_col)
	if gtrail:
		gtrail.position = Vector3(0, 1.0, 0.3)
		glider.add_child(gtrail)
	var m_line := toon(Color("5a4636"), false)
	for sx in [-1.0, -0.4, 0.4, 1.0]:
		part(glider, cyl(0.008, 0.008, 1.0, 4), m_line, Vector3(0.42 * sx, 0.55, 0), Vector3.ONE, Vector3(0, 0, -0.62 * sx))
	merge_static(glider)
	var ring := MeshInstance3D.new(); ring.name = "TeamRing"; ring.mesh = flat_quad(1.0)
	ring.material_override = ring_mat(team_col, 0.16); ring.position = Vector3(0, 0.04, 0)
	root.add_child(ring)
	# the head and everything on it turn and nod together from the neck
	var head := Node3D.new(); head.name = "HeadPivot"
	head.position = Vector3(0, 0.68 * float(Arch.body(arch).get("torso", 1.0)), 0)
	torso.add_child(head)
	for ch in torso.get_children():
		if ch is MeshInstance3D and (String(ch.name).begins_with("@") or ch.name == "Head") and (ch as Node3D).position.y > 0.72 and not ch.has_meta("stay"):
			torso.remove_child(ch)
			head.add_child(ch)
			(ch as Node3D).position.y -= 0.68
	for nd in [hair_n, gear]:
		torso.remove_child(nd); head.add_child(nd)
		(nd as Node3D).position.y -= 0.68
	merge_static(torso)
	merge_static(head)
	merge_static(hair_n)
	merge_static(gear)
	for nm in ["Skirt", "Cape", "Scarf", "PauldronL", "PauldronR", "Focus"]:
		if torso.has_node(nm): merge_static(torso.get_node(nm))
	for nm in ["LegL", "LegR"]:
		merge_static(legs.get_node(nm))
		merge_static(legs.get_node(nm + "/Knee"))
	for sd in ["L", "R"]:
		for nd in arms[sd]:
			merge_static(nd)
	if weapon not in ["twin_blades", "arc_bolts"]:
		merge_static(gun)      # (the twin blades' second dagger is handed to the left hand by HunterAnim)
	# the race's proportions: head size, how broad the body is, overall height
	var hkk := float(race["head"]) * (1.06 if arch == "thief" else 1.12)    # big-headed like a hero brawler (faces read from the match camera), heroic not chibi; the thief leaner
	hkk *= float(lk["head"]) * float(Arch.body(arch).get("head", 1.0))      # the Warden's head size
	var bk := float(race["bulk"]) * float(HeroGearPair.body(arch)["bulk"])
	head.scale = Vector3(hkk * float(lk["face_w"]), hkk * float(lk["jaw"]), hkk)
	# (a Warden can stand taller in the neck)
	head.position.y += (hkk - 1.0) * 0.05 + float(Arch.body(arch).get("neck", 0.0))
	if bk != 1.0:
		for ch in torso.get_children():
			if ch is MeshInstance3D and not String(ch.name).begins_with("Tail") and ch.name != "Wings":
				(ch as Node3D).scale = Vector3(bk, 1.0 + (bk - 1.0) * 0.35, bk)
		aim.scale = Vector3(lerpf(1.0, bk, 0.75), 1.0, 1.0)
		shoulder.position.x *= bk
		legs.scale = Vector3(bk, legs.scale.y, bk)      # (keeps the leg length set above)
		var bks := Vector3(bk, 1.0 + (bk - 1.0) * 0.35, bk)
		for nm in ["Skirt", "Cape", "Scarf"]:
			var pv := torso.get_node_or_null(nm) as Node3D
			if pv:
				pv.position *= bks; pv.scale = bks
		for sd in ["L", "R"]:
			var pd := pads[sd] as Node3D
			pd.position.x *= bk; pd.scale = Vector3(bk, 1.0, bk)
		# arms: thicker or thinner, but the same length (the elbows are solved to the grips)
		for sd in ["L", "R"]:
			var ap := torso.get_node("Arm%sPivot" % sd) as Node3D
			ap.position.x *= bk
			for n in [ap, ap.get_node("Elbow"), ap.get_node("Elbow/Hand")]:
				for ch in (n as Node3D).get_children():
					if ch is MeshInstance3D: (ch as Node3D).scale = Vector3(bk, 1.0, bk)
	if um: Shrouds.bind(root)
	bake_part_y(root)
	root.set_meta("mats", collect_mats(root))
	for mm in root.get_meta("mats"):
		var sm := mm as ShaderMaterial
		sm.set_shader_parameter("paint", 0.012)    # clean, sleek surfaces: barely any blotching
		# painted lighting for heroes: deeper, cooler shadows against a warm key, and the baked
		# occlusion in each piece's vertex colour (folds, roots of locks, under brims and plates)
		sm.set_shader_parameter("vertex_ao", true)
		sm.set_shader_parameter("shade", 0.37)
		sm.set_shader_parameter("shadow_tint", Color(0.6, 0.6, 0.86))
		sm.set_shader_parameter("light_tint", Color(1.08, 1.0, 0.9))
		hero_look(sm)
	WardenGlb.dress(root, arch, lk)      # its 3D model, when it has one and uses it (else this procedural one)
	root.set_meta("race", rid)
	root.set_meta("cls", cls)
	root.set_meta("arch", arch)
	root.set_meta("wid", weapon)
	HunterAnim.rest_pose(root)       # hands on the weapon even where nothing animates it (portraits, galleries)
	var rs := float(race["scale"])
	var ck := float(CLASS_LOOK.get(cls, {}).get("size", 1.0))
	var body := Arch.body(arch)
	var size_k := float(body.get("size", 1.0)) * float(HeroGearPair.body(arch)["size"])
	var bulk := float(body.get("bulk", 1.0))
	var look_k := rs * ck * size_k * float(lk["height"])
	root.scale = Vector3(bulk, 1.0, bulk) * float(Data.CLASSES[cls]["scale"]) * look_k
	# the ring under your feet is the real hitbox: its world radius is hit_r, whatever your size
	var ring_k := 2.0 * Arch.hit_r(arch, Data.CLASSES[cls]) / (float(Data.CLASSES[cls]["scale"]) * look_k)
	ring.scale = Vector3(1.0 / bulk, 1.0, 1.0 / bulk) * ring_k
	var torso_node := root.find_child("Torso", true, false) as Node3D
	if torso_node != null:
		torso_node.scale.x *= float(body.get("chest", 1.0))
	return root

## Moves a hunter's toon material onto the hero shader (hero_toon.gdshader) with the same settings,
## plus the hero tuning: a crisper light/shadow split, shadows that keep their colour, a coloured
## fresnel rim (cool on metal, the surface's own colour elsewhere) and a little top light.
static func hero_look(sm: ShaderMaterial) -> void:
	if sm.shader != TOON:
		return
	var keep := {}
	for u in TOON.get_shader_uniform_list():
		var nm := String(u["name"])
		var v = sm.get_shader_parameter(nm)
		if v != null: keep[nm] = v
	sm.shader = HERO
	for nm in keep:
		sm.set_shader_parameter(nm, keep[nm])
	var surf := int(keep.get("surface", 0))
	var metal := surf == 3
	sm.set_shader_parameter("ramp", 0.5)
	sm.set_shader_parameter("shadow_sat", 0.4)
	sm.set_shader_parameter("fres", 0.75 if surf == 4 else (1.15 if metal else 1.0))
	sm.set_shader_parameter("fres_tint", 0.55 if metal else 0.7)
	if metal:
		sm.set_shader_parameter("shadow_tint", Color(0.66, 0.66, 0.8))     # metal shadows a cool grey, not violet
	sm.set_shader_parameter("top_light", 1.0)
	if metal:
		sm.set_shader_parameter("gloss", maxf(float(keep.get("gloss", 0.0)), 0.7))

## A cone of radius r and length h growing from `at` along `dir` (spikes, fur tufts, horns).
static func _spike(n: Node3D, m: Material, at: Vector3, dir: Vector3, r: float, h: float, flat := 1.0) -> MeshInstance3D:
	var d := dir.normalized()
	var mi := part(n, cyl(0.0, r, h), m, at + d * h * 0.5)
	var b := Basis(Quaternion(Vector3.UP, d)) if absf(d.dot(Vector3.UP)) < 0.9999 else (Basis.IDENTITY if d.y > 0.0 else Basis(Vector3.RIGHT, PI))
	mi.basis = b * Basis.from_scale(Vector3(flat, 1.0, 1.0))
	return mi

## A soft blade (a feather, a leaf, a petal, a fin): an elongated, flattened ellipsoid from `at`
## along `dir`, `w` wide; `face` turns its flat side.
static func _blade(n: Node3D, m: Material, at: Vector3, dir: Vector3, ln: float, w: float, face := 0.0, thick := 0.24) -> MeshInstance3D:
	var d := dir.normalized()
	var mi := part(n, _blade_mesh(), m, at + d * ln * 0.5)
	var b := Basis(Quaternion(Vector3.UP, d)) if absf(d.dot(Vector3.UP)) < 0.9999 else (Basis.IDENTITY if d.y > 0.0 else Basis(Vector3.RIGHT, PI))
	mi.basis = b * Basis(Vector3.UP, face) * Basis.from_scale(Vector3(w, ln, w * thick))
	return mi

static var _blade_m: SphereMesh
## The unit ellipsoid every blade is stretched from (small on screen, so a modest segment count).
static func _blade_mesh() -> SphereMesh:
	if _blade_m == null:
		_blade_m = SphereMesh.new()
		_blade_m.radius = 0.5; _blade_m.height = 1.0; _blade_m.radial_segments = 24; _blade_m.rings = 14
	return _blade_m

## A point on the head (centre 0, 0.86, 0, radius about 0.235) in the direction (x, y, z).
static func _on_head(x: float, y: float, z: float, out := 0.0) -> Vector3:
	return Vector3(0, 0.86, 0) + Vector3(x, y, z).normalized() * (0.23 + out)

## Each race's own head styles (see HAIR_STYLES): fur for the Vulpin (parted round their ears),
## crystals, stone and moss for the Stoneborn, leaves and flowers for Sprigs, crests, frills, horns
## and spines for Scalefolk, feathers for Owlets. All in the hair colour.
static func _race_hair(n: Node3D, rid: String, style: int, m_hair: Material, hair_c: Color, skin_c: Color, covered: bool) -> void:
	var light := toon(hair_c.lightened(0.3)); (light as ShaderMaterial).set_shader_parameter("rim_amount", 0.75)
	var dark := toon(hair_c.darkened(0.25))
	match rid:
		"vulpin":
			var tip := toon(hair_c.lightened(0.55))
			if not covered:
				part(n, sphere(0.248), m_hair, Vector3(0, 0.905, 0.03), Vector3(1.04, 0.8 if style == 5 else 0.85, 1.02))
			match style:
				0:   # fluffy tuft: a curl of fur between the ears, cheek fluff
					for i in 3:
						var a := (i - 1) * 0.4
						_spike(n, m_hair, _on_head(sin(a) * 0.35, 0.9, -0.5), Vector3(sin(a) * 0.4, 0.6, -0.9), 0.065 - absf(i - 1) * 0.012, 0.2)
					for sx in [-1.0, 1.0]:
						_spike(n, m_hair, _on_head(0.9 * sx, -0.35, -0.2), Vector3(sx, -0.45, -0.1), 0.055, 0.15)
				1:   # mane: a ruff of fur round the back of the head and the neck
					for k in 9:
						var a := (k - 4) * 0.36
						var d := Vector3(sin(a), -0.35, cos(a))
						_spike(n, m_hair if k % 2 == 0 else light, Vector3(0, 0.8, 0.03) + Vector3(sin(a), 0, cos(a)) * 0.16, d, 0.085, 0.2)
					for i in 3:
						_spike(n, m_hair, _on_head((i - 1) * 0.3, 0.9, -0.45), Vector3((i - 1) * 0.3, 0.3, -1.0), 0.05, 0.13)
				2:   # long fur down the back, tips lighter
					part(n, capsule(0.17, 0.5), m_hair, Vector3(0, 0.71, 0.11), Vector3(1.3, 1.0, 0.65))
					for i in 3:
						_spike(n, tip, Vector3((i - 1) * 0.11, 0.5, 0.15), Vector3((i - 1) * 0.2, -1.0, 0.15), 0.07, 0.16)
				3:   # brush tail: a fat fox brush of a ponytail with a white tip
					for p in [[Vector3(0, 0.99, 0.2), 0.08], [Vector3(0, 0.92, 0.29), 0.1], [Vector3(0, 0.8, 0.34), 0.112], [Vector3(0, 0.68, 0.34), 0.095]]:
						part(n, sphere(float(p[1])), m_hair, p[0])
					part(n, sphere(0.075), tip, Vector3(0, 0.58, 0.31))
				4:   # spiky fur swept back over the crown
					for i in 6:
						var a := (i - 2.5) * 0.32
						_spike(n, m_hair, _on_head(sin(a) * 0.6, 0.75, 0.2 + absf(a) * 0.1), Vector3(sin(a) * 0.6, 0.5, 1.0), 0.06, 0.22)
				5:   # sleek: close fur with a flick at the back and cheek tufts
					_spike(n, m_hair, _on_head(0, 0.2, 1.0), Vector3(0, -0.6, 1.0), 0.07, 0.2)
					for sx in [-1.0, 1.0]:
						_spike(n, tip, _on_head(0.92 * sx, -0.3, -0.25), Vector3(sx, -0.3, 0), 0.05, 0.13)
				6:   # fringe: soft locks over the forehead
					for k in 4:
						part(n, sphere(0.075), m_hair, Vector3(-0.12 + k * 0.08, 0.99 - absf(k - 1.5) * 0.015, -0.17), Vector3(0.9, 1.0, 0.7), Vector3(0.4, 0, -0.3 + k * 0.2))
					for sx in [-1.0, 1.0]:
						_spike(n, m_hair, _on_head(0.85 * sx, -0.1, -0.35), Vector3(0.3 * sx, -1.0, -0.1), 0.055, 0.18)
		"stoneborn":
			var gem := toon(hair_c.lightened(0.15), false, 0.75); (gem as ShaderMaterial).set_shader_parameter("gloss", 0.8)
			var rock := toon(skin_c.darkened(0.28).lerp(hair_c, 0.25))
			match style:
				0:   # crystal crown
					for c in [[Vector3(0, 1.14, 0.03), Vector3(-0.2, 0, 0), 0.38], [Vector3(0.12, 1.07, 0.06), Vector3(-0.35, 0, -0.55), 0.28], [Vector3(-0.13, 1.06, 0.05), Vector3(-0.3, 0, 0.6), 0.26], [Vector3(0.0, 1.0, 0.18), Vector3(-0.9, 0, 0), 0.22]]:
						part(n, crystal(0.085, float(c[2]), 6), gem, c[0], Vector3.ONE, c[1])
				1:   # crystal ridge: a row of shards front to back
					for i in 5:
						var h := 0.34 - absf(i - 1.5) * 0.06
						part(n, crystal(0.06, h, 5), gem, _on_head(0, 1.0 - absf(i - 1.5) * 0.1, -0.45 + i * 0.3) + Vector3(0, h * 0.35, 0), Vector3.ONE, Vector3(-0.35 + i * 0.22, 0, 0))
				2:   # stone ridge: rounded plates with glowing seams
					for i in 4:
						var at := _on_head(0, 1.0, -0.5 + i * 0.4, 0.01)
						var pl := part(n, box(0.16 - absf(i - 1.5) * 0.02, 0.09, 0.12), rock, at, Vector3.ONE, Vector3(-0.5 + i * 0.35, 0, 0))
						pl.position += Vector3(0, 0.02, 0)
						if i < 3: part(n, box(0.12, 0.03, 0.02), gem, _on_head(0, 1.0, -0.3 + i * 0.4, 0.03), Vector3.ONE, Vector3(-0.3 + i * 0.35, 0, 0))
				3:   # moss cap with a little crystal sprouting from it
					if not covered:
						part(n, sphere(0.25), m_hair, Vector3(0, 0.93, 0.03), Vector3(1.03, 0.68, 1.03))
					var rng := RandomNumberGenerator.new(); rng.seed = 77
					for k in 9:
						var a := TAU * k / 9.0
						part(n, sphere(0.05), light if k % 2 == 0 else m_hair, _on_head(cos(a) * 0.8, 0.75 + rng.randf() * 0.3, sin(a) * 0.8, 0.0), Vector3(1.0, 0.6, 1.0))
					part(n, crystal(0.04, 0.16, 5), gem, Vector3(0.06, 1.13, 0.0), Vector3.ONE, Vector3(0, 0, -0.3))
				4:   # geode: a cluster of crystals bursting out of the back of the head
					for c in [[Vector3(0.0, 0.25, 1.0), 0.3, 0.075], [Vector3(0.45, 0.5, 0.8), 0.22, 0.06], [Vector3(-0.45, 0.45, 0.85), 0.24, 0.06], [Vector3(0.15, 0.85, 0.5), 0.2, 0.055], [Vector3(-0.2, 0.9, 0.35), 0.16, 0.05], [Vector3(0.0, -0.1, 1.0), 0.18, 0.05]]:
						var d: Vector3 = (c[0] as Vector3).normalized()
						var mi := part(n, crystal(float(c[2]), float(c[1]), 6), gem, _on_head(d.x, d.y, d.z, -0.02) + d * float(c[1]) * 0.4)
						mi.basis = Basis(Quaternion(Vector3.UP, d))
		"sprig":
			var gold := toon(Color("ffd84a"), true, 0.3)
			if not covered and style != 5:
				part(n, sphere(0.25), m_hair, Vector3(0, 0.9, 0.03), Vector3(1.03, 0.82, 1.0))
			match style:
				0:   # leaf crown
					for k in 7:
						var a := TAU * k / 7.0 + 0.2
						var d := Vector3(cos(a) * 0.55, 1.0, sin(a) * 0.55)
						_blade(n, m_hair if k % 2 == 0 else light, Vector3(cos(a) * 0.14, 1.03, sin(a) * 0.13 + 0.02), d, 0.24, 0.11, a)
				1:   # flower bud on top
					var c := Vector3(0, 1.13, 0.02)
					for k in 5:
						var a := TAU * k / 5.0
						_blade(n, light, c, Vector3(cos(a) * 0.8, 0.9, sin(a) * 0.8), 0.17, 0.12, a + PI * 0.5, 0.3)
					part(n, sphere(0.05), gold, c + Vector3(0, 0.03, 0))
					part(n, cyl(0.015, 0.02, 0.06, 8), dark, Vector3(0, 1.08, 0.02))
				2:   # vine locks, each ending in a leaf
					for k in 5:
						var a := PI * 0.5 + (k - 2) * 0.55
						var p := Vector3(cos(a) * 0.2, 0.86, sin(a) * 0.17 + 0.03)
						for j in 4:
							part(n, sphere(0.04 - j * 0.004), dark if j % 2 == 0 else m_hair, p + Vector3(cos(a) * j * 0.02, -j * 0.08, sin(a) * j * 0.02))
						_blade(n, light, p + Vector3(cos(a) * 0.08, -0.3, sin(a) * 0.08), Vector3(cos(a) * 0.3, -1.0, sin(a) * 0.3), 0.12, 0.07, a)
				3:   # a sprout: a stem and two leaves
					part(n, cyl(0.012, 0.016, 0.16, 8), dark, Vector3(0, 1.15, 0.0), Vector3.ONE, Vector3(0, 0, 0.1))
					for sx in [-1.0, 1.0]:
						_blade(n, light if sx > 0.0 else m_hair, Vector3(-0.008, 1.22, 0.0), Vector3(sx, 0.55, 0), 0.2, 0.1, PI * 0.5, 0.3)
				4:   # petal bob: petals hanging round the head like a bob cut
					for k in 9:
						var a := PI * 0.5 + (k - 4) * 0.42
						var d := Vector3(cos(a), 0, sin(a))
						_blade(n, m_hair if k % 2 == 0 else light, Vector3(0, 0.97, 0.02) + d * 0.2, d * 0.35 + Vector3(0, -1.0, 0), 0.24, 0.13, a + PI * 0.5, 0.3)
				5:   # a toadstool cap with spots
					part(n, sphere(0.3), m_hair, Vector3(0, 1.02, 0.02), Vector3(1.15, 0.55, 1.15))
					part(n, cyl(0.26, 0.3, 0.03), toon(Color("f3e6c8")), Vector3(0, 0.96, 0.02))
					var spot := toon(Color("fbf6ee"))
					for k in 6:
						var a := TAU * k / 6.0
						part(n, sphere(0.04), spot, Vector3(cos(a) * 0.2, 1.12, sin(a) * 0.2 + 0.02), Vector3(1.0, 0.45, 1.0))
					part(n, sphere(0.045), spot, Vector3(0, 1.185, 0.02), Vector3(1.0, 0.4, 1.0))
		"scalefolk":
			match style:
				0, 4:   # crest of fins front to back (twin: two of them, splayed), and frills
					for side in ([0.0] if style == 0 else [-1.0, 1.0]):
						for i in 5:
							var z := -0.1 + i * 0.075
							var h := 0.2 - absf(i - 1.5) * 0.025
							_blade(n, m_hair if i % 2 == 0 else light, Vector3(0.07 * side, 1.05 - i * 0.02, z), Vector3(0.3 * side, 1.0, 0.55 + i * 0.2), h + 0.04, 0.09, PI * 0.5, 0.3)
					for sx in [-1.0, 1.0]:
						_blade(n, dark, _on_head(0.9 * sx, 0.1, 0.25), Vector3(sx, 0.35, 0.4), 0.18, 0.1, 0.0, 0.25)
				1:   # frills: a fan of webbed spines round the back of the head
					for sx in [-1.0, 1.0]:
						for i in 4:
							var a := 0.15 + i * 0.32
							_blade(n, m_hair if i % 2 == 0 else light, _on_head(0.9 * sx, 0.1, 0.3), Vector3(sx * cos(a), sin(a) * 0.9 + 0.1, 0.5), 0.22 - i * 0.02, 0.12, 0.0, 0.2)
					_blade(n, dark, _on_head(0, 0.5, 0.9), Vector3(0, 0.4, 1.0), 0.2, 0.14, PI * 0.5, 0.2)
				2:   # horns swept back, and two small brow nubs
					for sx in [-1.0, 1.0]:
						var p := _on_head(0.45 * sx, 0.75, 0.15, -0.02)
						var d := Vector3(0.35 * sx, 0.6, 0.75)
						var r := 0.05
						for j in 4:
							var dd := d.normalized()
							if j == 3:
								_spike(n, light, p, dd, r, 0.13)
							else:
								KinModels.seg(n, p, p + dd * 0.11, r, r * 0.8, m_hair, 14)
								part(n, sphere(r * 0.8), m_hair, p + dd * 0.11)
							p += dd * 0.11
							r *= 0.8
							d = d.rotated(Vector3.RIGHT, 0.4)
						_spike(n, dark, _on_head(0.35 * sx, 0.55, -0.75), Vector3(0.2 * sx, 1.0, -0.2), 0.025, 0.06)
				3:   # spines: rows of little spikes over the crown and down the neck
					for row in 3:
						var x := (row - 1) * 0.35
						for i in 5:
							var at := _on_head(x, 1.0 - i * 0.35, -0.3 + i * 0.4, -0.01)
							_spike(n, m_hair if (row + i) % 2 == 0 else light, at, (at - Vector3(0, 0.86, 0)).normalized() + Vector3(0, 0, 0.5), 0.035 - absf(row - 1) * 0.008, 0.11 - absf(row - 1) * 0.03)
		"owlet":
			match style:
				0:   # ear tufts: a pair of feathers each side
					for sx in [-1.0, 1.0]:
						_blade(n, m_hair, Vector3(0.15 * sx, 1.04, 0.0), Vector3(0.6 * sx, 1.0, 0.1), 0.3, 0.1, 0.0, 0.25)
						_blade(n, light, Vector3(0.12 * sx, 1.04, 0.04), Vector3(0.35 * sx, 1.0, 0.2), 0.22, 0.08, 0.0, 0.25)
				1:   # feather crest fanning up from the brow
					for i in 5:
						var a := (i - 2) * 0.3
						_blade(n, m_hair if i % 2 == 0 else light, _on_head(sin(a) * 0.3, 0.9, -0.3), Vector3(sin(a) * 0.5, 1.0, 0.45), 0.28 - absf(i - 2) * 0.04, 0.085, PI * 0.5 + a, 0.25)
				2:   # plume: two tall curling feathers
					_blade(n, m_hair, Vector3(0, 1.06, 0.02), Vector3(0.05, 1.0, 0.35), 0.4, 0.1, PI * 0.5, 0.22)
					_blade(n, light, Vector3(0.02, 1.06, 0.0), Vector3(0.3, 1.0, 0.1), 0.3, 0.08, PI * 0.5, 0.22)
				3:   # fluffy crown: soft feathers all over the top
					if not covered:
						part(n, sphere(0.248), m_hair, Vector3(0, 0.91, 0.03), Vector3(1.03, 0.84, 1.02))
					for k in 10:
						var a := TAU * k / 10.0
						var at := _on_head(cos(a) * 0.55, 0.85, sin(a) * 0.55)
						_blade(n, light if k % 2 == 0 else m_hair, at, (at - Vector3(0, 0.86, 0)) + Vector3(0, 0.12, 0), 0.13, 0.08, a, 0.35)
				4:   # swept back: feathers laid back along the head
					if not covered:
						part(n, sphere(0.246), m_hair, Vector3(0, 0.9, 0.04), Vector3(1.02, 0.82, 1.02))
					for i in 5:
						var x := (i - 2) * 0.07
						_blade(n, light if i % 2 == 0 else m_hair, _on_head(x * 2.5, 0.85, -0.2), Vector3(x, 0.25, 1.0), 0.32, 0.075, PI * 0.5, 0.25)
				5:   # long plumes hanging down the back
					if not covered:
						part(n, sphere(0.246), m_hair, Vector3(0, 0.9, 0.04), Vector3(1.02, 0.82, 1.02))
					for i in 4:
						var x := (i - 1.5) * 0.08
						_blade(n, m_hair if i % 2 == 0 else light, _on_head(x * 2.0, 0.4, 0.9), Vector3(x, -1.0, 0.35), 0.44 - absf(i - 1.5) * 0.06, 0.08, PI * 0.5, 0.25)

## What each race adds: ears, tails, wings, snouts, crests, crystals.
static func _race_parts(torso: Node3D, rid: String, m_skin: Material, m_hair: Material, m_dark: Material, skin_c: Color, hair_c: Color, hero_col: Color) -> void:
	match rid:
		"vulpin":
			var inner := toon(Color("ffb6bf"))
			for sx in [-1.0, 1.0]:
				part(torso, cyl(0.0, 0.16, 0.46, 4), m_hair, Vector3(0.17 * sx, 1.16, 0.01), Vector3(1.0, 1.0, 0.55), Vector3(0, 0.785, -0.4 * sx))
				part(torso, cyl(0.0, 0.095, 0.3, 4), inner, Vector3(0.165 * sx, 1.13, -0.035), Vector3(1.0, 1.0, 0.3), Vector3(0, 0.785, -0.4 * sx))
			part(torso, sphere(0.1, 12), toon(skin_c.lightened(0.35)), Vector3(0, 0.79, -0.19), Vector3(1.15, 0.75, 0.9))   # muzzle
			part(torso, sphere(0.035, 8), m_dark, Vector3(0, 0.81, -0.285))   # nose
			# the tail: a big brush that sweeps up behind, with a white tip
			var tail := Node3D.new(); tail.name = "Tail"; tail.position = Vector3(0, 0.02, 0.26); torso.add_child(tail)
			var pts := [[Vector3(0, -0.02, 0.08), 0.11], [Vector3(0.07, 0.07, 0.28), 0.19], [Vector3(0.19, 0.21, 0.46), 0.23], [Vector3(0.31, 0.4, 0.55), 0.19]]
			for p in pts:
				part(tail, sphere(float(p[1]), 12), m_hair, p[0])
			part(tail, sphere(0.15, 10), toon(Color("fbf6ee")), Vector3(0.39, 0.56, 0.57))
		"stoneborn":
			var rock := toon(skin_c.darkened(0.28))
			var glow := toon(hero_col.lightened(0.2), false, 0.9)
			for sx in [-1.0, 1.0]:
				part(torso, box(0.16, 0.12, 0.18), rock, Vector3(0.25 * sx, 0.62, 0.03), Vector3.ONE, Vector3(0.1, 0.3 * sx, -0.25 * sx))     # rock plates on the shoulders
				part(torso, crystal(0.05, 0.2, 6), glow, Vector3(0.24 * sx, 0.74, 0.1), Vector3.ONE, Vector3(-0.3, 0, -0.45 * sx))   # shoulder crystals
			# glowing cracks across the chest
			part(torso, box(0.025, 0.2, 0.02), glow, Vector3(-0.05, 0.36, -0.235), Vector3.ONE, Vector3(0, 0, 0.5))
			part(torso, box(0.025, 0.14, 0.02), glow, Vector3(0.05, 0.27, -0.235), Vector3.ONE, Vector3(0, 0, -0.6))
			part(torso, box(0.18, 0.08, 0.18), rock, Vector3(0, 0.84, -0.17), Vector3.ONE, Vector3(0.2, 0, 0))   # heavy brow
		"sprig":
			var tipm := toon(hero_col.lightened(0.3), false, 1.0)
			for sx in [-1.0, 1.0]:
				# antennae with glowing tips, and long pointed ears
				part(torso, cyl(0.012, 0.014, 0.3, 6), m_dark, Vector3(0.08 * sx, 1.16, 0.0), Vector3.ONE, Vector3(-0.25, 0, -0.38 * sx))
				part(torso, sphere(0.045, 8), tipm, Vector3(0.14 * sx, 1.3, -0.04))
				part(torso, cyl(0.0, 0.055, 0.2, 4), m_skin, Vector3(0.28 * sx, 0.88, 0.0), Vector3(1.0, 1.0, 0.5), Vector3(0, 0, -1.25 * sx))
			# leaf wings on the back, see-through and faintly lit
			var wing_m := StandardMaterial3D.new()
			wing_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			wing_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wing_m.albedo_color = Color(hero_col.lerp(Color("c8ffd8"), 0.5), 0.55)
			wing_m.cull_mode = BaseMaterial3D.CULL_DISABLED
			var wings := Node3D.new(); wings.name = "Wings"; wings.position = Vector3(0, 0.5, 0.3); torso.add_child(wings)
			for sx in [-1.0, 1.0]:
				var wmi := part(wings, sphere(0.26, 12), wing_m, Vector3(0.26 * sx, 0.1, 0.1), Vector3(0.8, 1.9, 0.06), Vector3(1.0, 0.35 * sx, 0.95 * sx))
				wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var w2 := part(wings, sphere(0.18, 12), wing_m, Vector3(0.2 * sx, -0.16, 0.12), Vector3(0.75, 1.5, 0.06), Vector3(1.0, 0.25 * sx, 2.0 * sx))
				w2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"scalefolk":
			part(torso, sphere(0.16, 14), m_skin, Vector3(0, 0.8, -0.19), Vector3(0.9, 0.72, 1.25))   # snout
			for sx in [-1.0, 1.0]:
				part(torso, sphere(0.02, 6), m_dark, Vector3(0.05 * sx, 0.84, -0.385))
			# a long tail that tapers down to the ground behind
			var tail := Node3D.new(); tail.name = "Tail"; tail.position = Vector3(0, 0.0, 0.24); torso.add_child(tail)
			var segs := [[Vector3(0, -0.04, 0.08), 0.11, 0.3], [Vector3(0, -0.16, 0.3), 0.085, 0.3], [Vector3(0, -0.3, 0.52), 0.06, 0.28], [Vector3(0, -0.38, 0.72), 0.035, 0.22]]
			for sg in segs:
				part(tail, capsule(float(sg[1]), float(sg[2]) + float(sg[1]) * 2.0), m_skin, sg[0], Vector3.ONE, Vector3(1.05, 0, 0))
		"owlet":
			part(torso, cyl(0.0, 0.05, 0.13, 4), toon(Color("f2a24a")), Vector3(0, 0.8, -0.26), Vector3(1.0, 1.0, 0.8), Vector3(-PI / 2 + 0.35, 0, 0))   # beak
			for sx in [-1.0, 1.0]:
				part(torso, sphere(0.11, 14), m_hair, Vector3(0.27 * sx, 0.3, 0.05), Vector3(0.3, 1.0, 0.15), Vector3(0.1, 0, -0.25 * sx))   # wing feathers at the sides
			var tail := Node3D.new(); tail.name = "Tail"; tail.position = Vector3(0, 0.0, 0.26); torso.add_child(tail)
			for i in 5:
				var a := (i - 2) * 0.32
				part(tail, sphere(0.12, 16), m_hair if i % 2 == 0 else toon(hair_c.lightened(0.25)), Vector3(sin(a) * 0.12, -0.1, 0.14), Vector3(0.4, 1.95, 0.11), Vector3(1.0, 0, a))

## A paraglider wing: arched across its span, rounded at the tips, striped in the given colours.
static func glider_mesh(cloth: Color, stripe: Color, edge: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 12
	var span := 1.05
	for side in [1.0, -1.0]:
		for k in segs:
			var x0 := -span + 2.0 * span * k / segs
			var x1 := -span + 2.0 * span * (k + 1) / segs
			var col: Color = stripe if k % 3 == 1 else (edge if k == 0 or k == segs - 1 else cloth)
			var pts := []
			for x in [x0, x1]:
				var u: float = absf(x) / span
				var y: float = -0.32 * u * u
				var chord: float = 0.42 * sqrt(maxf(0.0, 1.0 - pow(u, 3.0))) + 0.05
				pts.append(Vector3(x, y + side * 0.012, -chord * 0.55))
				pts.append(Vector3(x, y + side * 0.012, chord * 0.45))
			var n: Vector3 = Vector3.UP * side
			st.set_color(col)
			var order := [0, 2, 3, 0, 3, 1] if side > 0.0 else [0, 3, 2, 0, 1, 3]
			for i in order:
				st.set_normal(n)
				st.add_vertex(pts[i])
	return st.commit()

static func vtoon_outlined() -> ShaderMaterial:
	var m := vtoon()
	m.set_shader_parameter("rim_amount", 0.5)
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = OUTLINE
	m.next_pass = _outline_mat
	return m

## Bakes a node's plain mesh parts into one mesh per look, so a detailed character costs a handful
## of draw calls. Named parts (Head, ArmR, Halo, ...) and anything with children stay separate.
static func merge_static(node: Node3D) -> void:
	var groups := {}
	var drop: Array = []
	for ch in node.get_children():
		if not (ch is MeshInstance3D) or ch.get_child_count() > 0 or not String(ch.name).begins_with("@"):
			continue
		var mi: MeshInstance3D = ch
		var mat: Material = mi.material_override
		if mat == null or mi.mesh == null:
			continue
		var key := _mat_key(mat)
		if not groups.has(key):
			groups[key] = {"mat": mat, "st": SurfaceTool.new(), "n": 0}
			(groups[key]["st"] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
		var st: SurfaceTool = groups[key]["st"]
		var pm := _with_part_y(mi.mesh, mi.transform)
		for si in pm.get_surface_count():
			st.append_from(pm, si, mi.transform)
		groups[key]["n"] = int(groups[key]["n"]) + 1
		drop.append(mi)
	for key in groups:
		var g: Dictionary = groups[key]
		var mi := MeshInstance3D.new()
		mi.mesh = (g["st"] as SurfaceTool).commit()
		mi.material_override = g["mat"]
		ShadowPolicy.judge(mi)       # a merged clump of small parts is still small (item 94)
		node.add_child(mi)
	for d in drop:
		node.remove_child(d)
		d.free()

## A copy of a mesh whose UV2 holds the height range (bottom, top) the part spans once placed with
## xf, which the toon shader turns into the part's painted light-to-dark gradient and crease.
static func _with_part_y(mesh: Mesh, xf := Transform3D.IDENTITY) -> ArrayMesh:
	var ab := xf * mesh.get_aabb()
	var am := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arrs := mesh.surface_get_arrays(si)
		var n: int = (arrs[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var uv2 := PackedVector2Array(); uv2.resize(n); uv2.fill(Vector2(ab.position.y, ab.end.y))
		arrs[Mesh.ARRAY_TEX_UV2] = uv2
		if arrs[Mesh.ARRAY_COLOR] == null:
			var cw := PackedColorArray(); cw.resize(n); cw.fill(Color.WHITE)     # no baked occlusion: plain white
			arrs[Mesh.ARRAY_COLOR] = cw
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	return am

static var _part_y_cache := {}
## Gives every toon-shaded part under `n` that isn't merged its own part range (in its own space).
static func bake_part_y(n: Node) -> void:
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.mesh and mi.mesh.get_surface_count() > 0 and mi.material_override is ShaderMaterial \
					and (mi.material_override as ShaderMaterial).shader == TOON \
					and not (mi.mesh is ArrayMesh and ((mi.mesh as ArrayMesh).surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV2)):
				var id := mi.mesh.get_instance_id()
				if not _part_y_cache.has(id):
					_part_y_cache[id] = _with_part_y(mi.mesh)
				mi.mesh = _part_y_cache[id]
		for ch in c.get_children(): stack.append(ch)

## Sets a toon material's painted structure: its brushwork (see toon.gdshader's `surface`), the
## part gradient, the crease darkening and the form-shadow on edges.
static func painted(m: ShaderMaterial, surface := 0, grad := 0.22, crease_k := 0.26, edge := 0.24) -> ShaderMaterial:
	m.set_shader_parameter("surface", surface)
	m.set_shader_parameter("part_grad", grad)
	m.set_shader_parameter("crease", crease_k)
	m.set_shader_parameter("edge_dark", edge)
	return m

static func _mat_key(m: Material) -> String:
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		return "%s|%s|%s|%s|%s|%s" % [sm.shader.resource_path, str(sm.get_shader_parameter("albedo")), str(sm.get_shader_parameter("glow")), str(sm.get_shader_parameter("rim_amount")), str(sm.next_pass != null), str(sm.get_shader_parameter("use_vertex_color"))]
	return str(m.get_instance_id())

## Every toon material in a model, for the hit flash.
static func collect_mats(n: Node) -> Array:
	var out: Array = []
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is MeshInstance3D and (c as MeshInstance3D).material_override is ShaderMaterial:
			var sm := (c as MeshInstance3D).material_override as ShaderMaterial
			if sm.shader == TOON and not out.has(sm):
				out.append(sm)
		for ch in c.get_children(): stack.append(ch)
	return out

static func m_trim0(c: Color) -> ShaderMaterial:
	return toon(c.darkened(0.55).lerp(Color("3a2f2a"), 0.5))

## Eyes, brows and a mouth: small shapes, but they carry a lot of character.
## The face on the head: eyes, brows, nose and mouth for the look's expression and gender, sized and
## placed by its face factors (MantleLook params: eye_size, eye_shape, brow, nose), and its markings.
static func _face(torso: Node3D, lk: Dictionary, m_dark: Material, m_skin: Material, paint: Color) -> void:
	var face := int(lk["face"])
	var detail := int(lk["detail"])
	var skin: Color = lk["skin_col"]
	var hair_c: Color = lk["hair_col"]
	var fem := int(lk["gender"]) == 0
	var shine := toon(Color.WHITE, false, 1.0)
	var white := toon(Color("fbf8f2"), false, 0.1)
	var iris := toon(lk["eye_col"], false)
	iris.set_shader_parameter("gloss", 0.85)
	iris.set_shader_parameter("sss", 0.0)
	var y := 0.868
	# big readable eyes; rounder for her, narrower for him
	var es: float = (1.3 if fem else 1.1) * float(lk["eye_size"])
	var eh := float(lk["eye_shape"])        # taller (rounder) or flatter (narrower) eyes
	var brow_up := float(lk["brow"])        # how high the brows sit over the eyes
	var m_hairf := toon(hair_c.darkened(0.15), false)
	for sx in [-1.0, 1.0]:
		var ex: float = (0.093 if fem else 0.095) * sx
		var kind := face
		if face == 5:
			kind = 3 if sx > 0.0 else 0        # wink: one eye shut
		var open := kind in [0, 1, 4, 6, 7, 8]
		match kind:
			0, 4, 6, 7:   # bright eyes, fierce, starry, determined: white, iris, pupil and a shine
				part(torso, sphere(0.05 * es, 12), white, Vector3(ex, y, -0.2), Vector3(0.85, (1.12 if kind in [0, 6] else 0.88) * eh, 0.45))
				part(torso, sphere(0.036 * es, 10), iris, Vector3(ex + 0.004 * sx, y - 0.006, -0.219), Vector3(0.9, 1.12 * eh, 0.4))
				part(torso, sphere(0.018 * es, 8), m_dark, Vector3(ex + 0.004 * sx, y - 0.008, -0.229), Vector3(1.0, 1.15, 0.4))
				part(torso, sphere(0.014 * es, 6), shine, Vector3(ex + 0.016, y + 0.018, -0.237))
				part(torso, sphere(0.007 * es, 6), shine, Vector3(ex - 0.012, y - 0.022, -0.236))
				if kind == 6:
					part(torso, sphere(0.02 * es, 6), shine, Vector3(ex - 0.01, y + 0.012, -0.233), Vector3(1.0, 1.0, 0.4))
					part(torso, sphere(0.008, 6), shine, Vector3(ex - 0.014, y - 0.022, -0.233))
				if kind == 7:
					part(torso, box(0.085 * es, 0.022, 0.02), m_skin, Vector3(ex, y + 0.034 * es, -0.228))   # heavy lid
			1:   # calm: soft dark eyes with a shine
				part(torso, sphere(0.034 * es, 10), m_dark, Vector3(ex, y, -0.215), Vector3(0.9, 1.1 * eh, 0.5))
				part(torso, sphere(0.01, 6), shine, Vector3(ex + 0.012, y + 0.014, -0.232))
			2:   # sleepy: half-closed lids
				part(torso, box(0.065 * es, 0.016, 0.02), m_dark, Vector3(ex, y - 0.006, -0.222), Vector3.ONE, Vector3(0, 0, 0.12 * sx))
			8:   # smug: half-lidded, looking sideways
				part(torso, sphere(0.04 * es, 10), white, Vector3(ex, y - 0.01, -0.205), Vector3(0.95, 0.6, 0.45))
				part(torso, sphere(0.022, 8), m_dark, Vector3(ex + 0.016, y - 0.014, -0.224), Vector3(1.0, 0.8, 0.4))
				part(torso, box(0.08 * es, 0.016, 0.02), m_dark, Vector3(ex, y + 0.008, -0.226))
			3:   # cheerful: eyes that smile
				var t := TorusMesh.new(); t.inner_radius = 0.024 * es; t.outer_radius = 0.036 * es; t.rings = 28; t.ring_segments = 10
				part(torso, t, m_dark, Vector3(ex, y - 0.01, -0.215), Vector3(1.0, 1.0, 0.5), Vector3(PI / 2, 0, 0))
				part(torso, box(0.08, 0.032, 0.03), m_skin, Vector3(ex, y - 0.032, -0.22))
		# brows: thin and arched for her, thick and straight for him; angled in when fierce
		var tilt: float = (-0.4 if kind == 4 else (-0.2 if kind == 7 else 0.15)) * sx
		if fem:
			part(torso, box(0.066, 0.016, 0.016), m_hairf, Vector3(ex + 0.006 * sx, y + 0.08 * brow_up, -0.208), Vector3.ONE, Vector3(0, 0, tilt + 0.18 * sx))
		else:
			part(torso, box(0.088, 0.03, 0.022), m_hairf, Vector3(ex, y + 0.072 * brow_up, -0.208), Vector3.ONE, Vector3(0, 0, tilt * 0.9))
		# lashes on her open eyes: two flicks at the outer corner
		if fem and open:
			part(torso, box(0.036, 0.013, 0.012), m_dark, Vector3(ex + 0.056 * sx, y + 0.036, -0.206), Vector3.ONE, Vector3(0, 0, 0.55 * sx))
			part(torso, box(0.026, 0.01, 0.012), m_dark, Vector3(ex + 0.058 * sx, y + 0.014, -0.206), Vector3.ONE, Vector3(0, 0, 0.15 * sx))
			part(torso, box(0.075 * es, 0.015, 0.012), m_dark, Vector3(ex, y + 0.05 * es, -0.222), Vector3.ONE, Vector3(0, 0, -0.08 * sx))
	# his jaw: wider and squarer at the bottom of the face, with a hint of a chin
	# (the jaw and chin are sculpted into the head itself: HeroKit.head)
	# a small stylized nose: a soft wedge with a lit bridge
	part(torso, HeroKit.loft("nose|%s" % fem, [Vector3(0, 0.04, 0.0), Vector3(0, 0.0, -0.012), Vector3(0, -0.02, -0.018)], [Vector2(0.01, 0.008), Vector2(0.016 if fem else 0.02, 0.012), Vector2(0.012 if fem else 0.016, 0.01)], 10, Vector3.FORWARD, 0.95), m_skin, Vector3(0, 0.825, -0.226), Vector3.ONE * float(lk["nose"]))
	# mouth: rosy lips for her, a plain line or grin for him
	var mz := -0.236
	var smile := face in [0, 3, 5, 6]
	var lip_m: Material = toon(skin.lerp(Color("d0405a"), 0.55), false) if fem else m_dark
	if face == 8:
		part(torso, box(0.06, 0.015, 0.012), lip_m, Vector3(0.012, 0.778, mz), Vector3.ONE, Vector3(0, 0, 0.3))    # smirk
	elif smile:
		# a smile: a curved stroke (a run of overlapping dots along the bottom of a circle), upturned
		# at the corners, and an open grin on the cheerful faces
		var sr := 0.036 if fem else 0.034
		var cy := 0.796
		for k in 11:
			var a := lerpf(PI * 1.16, PI * 1.84, k / 10.0)
			part(torso, sphere(0.0115 if fem else 0.0105, 6), lip_m, Vector3(cos(a) * sr, cy + sin(a) * sr * 0.75, mz + 0.002 + absf(cos(a)) * 0.01), Vector3(1.0, 0.8, 0.5))
		if face in [3, 6]:
			part(torso, sphere(0.022, 8), m_dark, Vector3(0, cy - sr * 0.62, mz + 0.004), Vector3(1.2, 0.55, 0.35))
	elif fem:
		part(torso, sphere(0.025, 8), lip_m, Vector3(0, 0.776, mz), Vector3(1.35, 0.6, 0.4))
	else:
		part(torso, box(0.058, 0.016, 0.012), m_dark, Vector3(0, 0.776, mz))
	if fem or face == 3:
		var blush := toon(Color("ff9a9a"), false)
		for sx in [-1.0, 1.0]:
			part(torso, sphere(0.03, 8), blush, Vector3(0.14 * sx, 0.815, -0.185), Vector3(1.0, 0.6, 0.4))
	# little extras
	match detail:
		1:   # freckles
			var fm := toon(skin.darkened(0.35), false)
			for sx in [-1.0, 1.0]:
				for k in 3:
					part(torso, sphere(0.007, 5), fm, Vector3(sx * (0.1 + k * 0.022), 0.83 + (k % 2) * 0.012, -0.212 + k * 0.006))
		2:   # a scar over one eye
			part(torso, box(0.012, 0.11, 0.012), toon(skin.lerp(Color("c86a6a"), 0.6), false), Vector3(0.1, 0.87, -0.228), Vector3.ONE, Vector3(0, 0, 0.25))
		3:   # face paint in the team colour
			var pm := toon(paint, false, 0.2)
			for sx in [-1.0, 1.0]:
				for k in 2:
					part(torso, box(0.055, 0.012, 0.012), pm, Vector3(sx * 0.12, 0.812 - k * 0.022, -0.2), Vector3.ONE, Vector3(0, 0.4 * sx, 0))
		4:   # stubble
			part(torso, sphere(0.205, 14), toon(skin.lerp(hair_c, 0.45).darkened(0.12), false), Vector3(0, 0.76, -0.025), Vector3(1.18 if not fem else 1.0, 0.6, 1.03))
		5:   # a full beard
			var bm := toon(hair_c)
			part(torso, sphere(0.21, 14), bm, Vector3(0, 0.75, -0.02), Vector3(1.2, 0.72, 1.05))
			part(torso, sphere(0.08, 10), bm, Vector3(0, 0.69, -0.17), Vector3(1.3, 1.1, 0.9))
			part(torso, box(0.06, 0.012, 0.012), m_dark, Vector3(0, 0.79, -0.25))
		6:   # moustache
			for sx in [-1.0, 1.0]:
				part(torso, capsule(0.018, 0.08), toon(hair_c), Vector3(0.03 * sx, 0.808, -0.236), Vector3.ONE, Vector3(0, 0, PI / 2 + 0.35 * sx))
		7:   # beauty mark
			part(torso, sphere(0.008, 5), m_dark, Vector3(0.055, 0.8, -0.23))

## Hair that peeks out under whatever the hero wears on their head: a cap of hair, chunky fringe
## locks over the forehead, then the style.
static func _hair(torso: Node3D, style: int, gender: int, m_hair: Material, covered := false) -> void:
	if style == 13:
		return   # bald
	if covered:
		# under a hood or helmet only what hangs below it shows
		if style not in [5, 9]:
			for sx in [-1.0, 1.0]:
				part(torso, cyl(0.0, 0.06, 0.2, 8), m_hair, Vector3(0.2 * sx, 0.84, -0.06), Vector3(1.0, 1.0, 0.8), Vector3(PI, 0, 0.15 * sx))
		match style:
			1: part(torso, capsule(0.17, 0.52), m_hair, Vector3(0, 0.7, 0.1), Vector3(1.35, 1.0, 0.7))
			7: _pigtails(torso, m_hair)
			8: _braid(torso, m_hair)
		return
	if style == 5 or style == 9:
		part(torso, sphere(0.242), m_hair, Vector3(0, 0.885, 0.02), Vector3(1.0, 0.82, 1.0))
		if style == 9:
			# mohawk: a crest of spikes front to back
			for i in 6:
				var z := -0.16 + i * 0.07
				part(torso, cyl(0.0, 0.05, 0.2 - absf(i - 2.5) * 0.02, 6), m_hair, Vector3(0, 1.08 - absf(i - 2.0) * 0.012, z), Vector3(0.6, 1.0, 1.2), Vector3(-0.3 + i * 0.12, 0, 0))
		return
	if style == 10:
		# afro: a big round cloud of hair
		part(torso, sphere(0.31, 16), m_hair, Vector3(0, 0.98, 0.08), Vector3(1.1, 0.95, 1.0))
		for k in 5:
			var x := -0.13 + k * 0.065
			part(torso, sphere(0.07, 10), m_hair, Vector3(x, 1.0 - absf(k - 2) * 0.012, -0.165), Vector3(1.0, 0.9, 0.7))
		return
	part(torso, sphere(0.25), m_hair, Vector3(0, 0.91, 0.035), Vector3(1.05, 0.86, 1.02))
	# fringe: soft locks sweeping across the forehead
	for k in 4:
		var x := -0.12 + k * 0.08
		part(torso, sphere(0.075, 10), m_hair, Vector3(x, 0.99 - absf(k - 1.5) * 0.015, -0.17), Vector3(0.9, 1.0, 0.7), Vector3(0.4, 0, -0.3 + k * 0.2))
	for sx in [-1.0, 1.0]:
		part(torso, cyl(0.0, 0.06, 0.2, 8), m_hair, Vector3(0.2 * sx, 0.84, -0.06), Vector3(1.0, 1.0, 0.8), Vector3(PI, 0, 0.15 * sx))   # sideburn locks
	match style:
		1:   # long
			part(torso, capsule(0.17, 0.52), m_hair, Vector3(0, 0.7, 0.1), Vector3(1.35, 1.0, 0.7))
			for sx in [-1.0, 1.0]:
				part(torso, cyl(0.0, 0.07, 0.26, 8), m_hair, Vector3(0.16 * sx, 0.5, 0.14), Vector3.ONE, Vector3(PI, 0, 0.1 * sx))
		2:   # ponytail with a tie
			part(torso, sphere(0.05, 8), toon(Color("e0607e")), Vector3(0, 0.95, 0.24))
			part(torso, capsule(0.075, 0.38), m_hair, Vector3(0, 0.82, 0.3), Vector3.ONE, Vector3(0.55, 0, 0))
			part(torso, cyl(0.0, 0.07, 0.16, 8), m_hair, Vector3(0, 0.62, 0.38), Vector3.ONE, Vector3(PI - 0.4, 0, 0))
		3:   # bun
			part(torso, sphere(0.11), m_hair, Vector3(0, 1.08, 0.16))
			part(torso, cyl(0.06, 0.06, 0.03, 10), toon(Color("f2c84a")), Vector3(0, 1.04, 0.13), Vector3.ONE, Vector3(-0.6, 0, 0))
		4:   # spiky
			for i in 7:
				var a := -1.2 + i * 0.4
				part(torso, cyl(0.0, 0.065, 0.22, 8), m_hair, Vector3(sin(a) * 0.14, 1.08, 0.05 + cos(a) * 0.06), Vector3.ONE, Vector3(-0.35, 0, -a * 0.75))
		6:   # bob: straight sides down to the jaw
			for sx in [-1.0, 1.0]:
				part(torso, sphere(0.13, 12), m_hair, Vector3(0.17 * sx, 0.82, 0.04), Vector3(0.6, 1.35, 1.2))
			part(torso, sphere(0.2, 12), m_hair, Vector3(0, 0.82, 0.12), Vector3(1.2, 1.1, 0.7))
		7:   # pigtails
			_pigtails(torso, m_hair)
		8:   # a long braid down the back
			_braid(torso, m_hair)
		11:  # curly: little curls all over
			for k in 14:
				var a := TAU * k / 14.0
				var yy := 0.95 + (k % 3) * 0.05
				part(torso, sphere(0.075, 8), m_hair, Vector3(cos(a) * 0.21, yy, sin(a) * 0.19 + 0.04))
			part(torso, sphere(0.09, 8), m_hair, Vector3(0, 1.12, 0.03))
		12:  # swoop: a big side-swept fringe
			part(torso, sphere(0.16, 12), m_hair, Vector3(0.06, 1.02, -0.13), Vector3(1.4, 0.7, 0.8), Vector3(0.3, 0, -0.35))
			part(torso, cyl(0.0, 0.06, 0.22, 8), m_hair, Vector3(0.2, 0.92, -0.13), Vector3.ONE, Vector3(0.2, 0, -2.2))
		_:   # short: a tuft on the crown
			part(torso, cyl(0.0, 0.05, 0.12, 8), m_hair, Vector3(0.03, 1.12, 0.02), Vector3.ONE, Vector3(-0.3, 0, -0.5))

static func _pigtails(torso: Node3D, m_hair: Material) -> void:
	for sx in [-1.0, 1.0]:
		part(torso, sphere(0.04, 8), toon(Color("e0607e")), Vector3(0.22 * sx, 0.93, 0.12))
		part(torso, capsule(0.07, 0.34), m_hair, Vector3(0.27 * sx, 0.78, 0.15), Vector3.ONE, Vector3(0.25, 0, 0.3 * sx))

static func _braid(torso: Node3D, m_hair: Material) -> void:
	for k in 5:
		part(torso, sphere(0.065 - k * 0.006, 8), m_hair, Vector3(0, 0.86 - k * 0.09, 0.27 + k * 0.01))
	part(torso, sphere(0.03, 6), toon(Color("e0607e")), Vector3(0, 0.44, 0.3))

static func prism_tip() -> PrismMesh:
	var pm := PrismMesh.new(); pm.size = Vector3(1, 1, 1)
	return pm

## The gun's pieces, shared by hunters and the weapons lying around on the islands: chunky,
## exaggerated hero-shooter shapes (rounded receivers, flared muzzles, fat grips and stocks) with a
## glowing accent per weapon. The barrel runs along -Z; the trigger hand holds near the origin.
static func gun_parts(gun: Node3D, weapon: String, m_gun: Material, m_dark: Material, m_acc: Material) -> void:
	if HeroArms.build(gun, weapon, m_gun, m_dark, m_acc): return      # Dolm's and Ostra's fixed weapons
	var glow := func(c: Color) -> ShaderMaterial: return toon(c, false, 1.1)
	var stock := func(z0: float, z1: float, h: float, w: float) -> void:
		part(gun, HeroKit.loft("stock|%.2f|%.2f|%.2f" % [z0, z1, h], [Vector3(0, 0.0, z0), Vector3(0, -0.02, lerpf(z0, z1, 0.5)), Vector3(0, -0.05, z1)], [Vector2(w * 0.5, h * 0.4), Vector2(w * 0.5, h * 0.5), Vector2(w * 0.55, h * 0.75)], 10, Vector3.UP, 0.85), m_dark)
	var grip := func(z: float, h: float) -> void:
		part(gun, HeroKit.loft("grip|%.2f" % h, [Vector3(0, 0.0, 0), Vector3(0, -h * 0.5, 0.025), Vector3(0, -h, 0.05)], [Vector2(0.026, 0.04), Vector2(0.028, 0.044), Vector2(0.03, 0.046)], 10, Vector3.FORWARD, 0.85), m_dark, Vector3(0, -0.04, z))
	match weapon:
		"smg":
			part(gun, box(0.11, 0.13, 0.34), m_gun, Vector3(0, 0, -0.1))
			part(gun, box(0.12, 0.05, 0.22), m_acc, Vector3(0, 0.08, -0.12))
			part(gun, cyl(0.045, 0.045, 0.2, 14), m_dark, Vector3(0, 0.01, -0.34), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, cyl(0.055, 0.05, 0.05, 14), m_gun, Vector3(0, 0.01, -0.45), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, box(0.02, 0.025, 0.2), glow.call(Color("8ff0ff")), Vector3(0.058, 0.02, -0.12))
			grip.call(-0.02, 0.15)
			stock.call(0.07, 0.2, 0.08, 0.05)
		"rifle":
			# a lever-action: walnut stock and forend, a dark receiver with a brass side plate, a long
			# barrel bound in brass, a loop lever; the accent (team or rarity) on the forend cap
			var walnut := toon(Color("7a4a2e")); painted(walnut, 2, 0.24, 0.2, 0.2); walnut.set_shader_parameter("gloss", 0.35)
			var brass := shiny(Color("d6a447"), 0.7)
			part(gun, HeroKit.loft("lever_rcv", [Vector3(0, 0.0, 0.06), Vector3(0, 0.01, -0.08), Vector3(0, 0.0, -0.2)], [Vector2(0.05, 0.065), Vector2(0.052, 0.07), Vector2(0.045, 0.058)], 10, Vector3.UP, 0.9), m_gun, Vector3(0, 0, -0.04))
			for sx in [-1.0, 1.0]:
				part(gun, box(0.006, 0.07, 0.18), brass, Vector3(0.05 * sx, 0.0, -0.12))
			part(gun, HeroKit.loft("lever_fore", [Vector3(0, -0.02, -0.25), Vector3(0, -0.02, -0.4), Vector3(0, -0.015, -0.54)], [Vector2(0.045, 0.045), Vector2(0.046, 0.044), Vector2(0.04, 0.04)], 10, Vector3.UP, 0.9), walnut)
			part(gun, cyl(0.046, 0.046, 0.04, 12), m_acc, Vector3(0, -0.018, -0.565), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, cyl(0.022, 0.026, 0.62, 10), m_dark, Vector3(0, 0.03, -0.53), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, cyl(0.018, 0.018, 0.44, 8), m_dark, Vector3(0, -0.012, -0.44), Vector3.ONE, Vector3(PI / 2, 0, 0))
			for k in 3:
				part(gun, cyl(0.032, 0.032, 0.02, 10), brass, Vector3(0, 0.02, -0.38 - k * 0.16), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, box(0.012, 0.03, 0.02), brass, Vector3(0, 0.065, -0.8))
			var loop := TorusMesh.new(); loop.inner_radius = 0.03; loop.outer_radius = 0.042; loop.rings = 14; loop.ring_segments = 5
			part(gun, loop, brass, Vector3(0, -0.085, 0.0), Vector3(1.0, 1.0, 1.3), Vector3(0, 0, PI / 2))
			part(gun, box(0.016, 0.022, 0.16), glow.call(Color("ffc46a")), Vector3(0.052, 0.04, -0.12))
			grip.call(0.0, 0.16)
			part(gun, HeroKit.loft("lever_stock", [Vector3(0, 0.0, 0.08), Vector3(0, -0.03, 0.18), Vector3(0, -0.07, 0.3)], [Vector2(0.03, 0.05), Vector2(0.034, 0.06), Vector2(0.036, 0.085)], 10, Vector3.UP, 0.85), walnut)
			part(gun, box(0.07, 0.09, 0.02), m_dark, Vector3(0, -0.07, 0.31), Vector3.ONE, Vector3(0.25, 0, 0))
		"sniper":
			part(gun, box(0.09, 0.12, 0.5), m_gun, Vector3(0, 0, -0.16))
			part(gun, cyl(0.028, 0.03, 0.56, 12), m_dark, Vector3(0, 0.02, -0.66), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, box(0.08, 0.06, 0.1), m_acc, Vector3(0, 0.02, -0.96))
			part(gun, cyl(0.05, 0.045, 0.3, 14), m_dark, Vector3(0, 0.12, -0.18), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, cyl(0.058, 0.05, 0.06, 14), m_acc, Vector3(0, 0.12, -0.35), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, cyl(0.04, 0.04, 0.02, 14), glow.call(Color("9af0ff")), Vector3(0, 0.12, -0.385), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, box(0.03, 0.03, 0.4), glow.call(Color("9af0ff")), Vector3(0.048, 0.0, -0.2))
			grip.call(0.0, 0.16)
			stock.call(0.09, 0.32, 0.14, 0.06)
		"pulse":
			part(gun, HeroKit.loft("pulse_body", [Vector3(0, 0, 0.1), Vector3(0, 0.01, -0.15), Vector3(0, 0.0, -0.42)], [Vector2(0.065, 0.075), Vector2(0.075, 0.085), Vector2(0.05, 0.06)], 16, Vector3.UP, 0.9), m_gun)
			for k in 3:
				var rr := TorusMesh.new(); rr.inner_radius = 0.06; rr.outer_radius = 0.085; rr.rings = 24; rr.ring_segments = 8
				part(gun, rr, glow.call(Color("8ff0ff")), Vector3(0, 0.0, -0.2 - k * 0.09), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, cyl(0.06, 0.06, 0.12, 14), glow.call(Color("8ff0ff")), Vector3(0, 0.0, -0.56), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, box(0.08, 0.04, 0.2), m_acc, Vector3(0, 0.09, -0.08))
			grip.call(0.0, 0.16)
		"rocket":
			part(gun, cyl(0.1, 0.1, 0.62, 16), toon(Color("5a6a4a")), Vector3(0, 0.04, -0.22), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, cyl(0.14, 0.11, 0.12, 16), toon(Color("ff7a5a")), Vector3(0, 0.04, -0.58), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, cyl(0.12, 0.13, 0.08, 16), m_dark, Vector3(0, 0.04, 0.12), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, box(0.04, 0.08, 0.1), m_acc, Vector3(0, 0.17, -0.2))
			grip.call(-0.05, 0.16)
		"burst_rifle":
			part(gun, box(0.09, 0.12, 0.38), m_gun, Vector3(0, 0, -0.1))
			part(gun, box(0.1, 0.06, 0.18), m_acc, Vector3(0, 0.08, -0.06))
			part(gun, cyl(0.026, 0.03, 0.2, 10), m_dark, Vector3(0, 0.02, -0.38), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, box(0.02, 0.02, 0.3), glow.call(Color("d6a8ff")), Vector3(0.05, 0.02, -0.14))
			part(gun, cyl(0.04, 0.036, 0.04, 10), glow.call(Color("d6a8ff")), Vector3(0, 0.02, -0.49), Vector3.ONE, Vector3(PI / 2, 0, 0))
			grip.call(-0.02, 0.14)
			stock.call(0.09, 0.18, 0.1, 0.05)
		"shotgun": HeroGearPair.scattergun(gun, m_gun, m_dark, m_acc)      # Dredge's harbour scattergun
		"slugger":
			part(gun, cyl(0.1, 0.12, 0.78, 14), m_gun, Vector3(0, 0, -0.26), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, cyl(0.15, 0.15, 0.1, 14), m_acc, Vector3(0, 0, -0.64), Vector3.ONE, Vector3(PI / 2, 0, 0))
			grip.call(-0.02, 0.18)
		"twin_blades":
			# two long curved fighting knives (a forward grip and a reversed one), dark steel with a
			# glowing cutting edge and a team-coloured wrap on the hilt
			var bl := shiny(Color("5c6170"), 0.75)
			var edge: ShaderMaterial = glow.call(Color("aef4ff"))
			for k in 2:
				var x := 0.06 if k == 0 else -0.12
				var pts := [Vector3(0, 0, 0), Vector3(0, 0.03, -0.2), Vector3(0, 0.01, -0.4), Vector3(0, -0.07, -0.56)] if k == 0 else [Vector3(0, 0, 0), Vector3(0, 0.03, 0.15), Vector3(0, -0.01, 0.32), Vector3(0, -0.08, 0.45)]
				var at := Vector3(x, 0, -0.08) if k == 0 else Vector3(x, -0.06, -0.02)
				var yr := Vector3(0, 0.12 if k == 0 else -0.3, 0)
				part(gun, HeroKit.loft("dagger2_%d" % k, pts, [Vector2(0.014, 0.06), Vector2(0.016, 0.07), Vector2(0.012, 0.05), Vector2(0.002, 0.004)], 8, Vector3.UP, 1.0), bl, at, Vector3.ONE, yr)
				part(gun, HeroKit.loft("dagedge2_%d" % k, pts, [Vector2(0.006, 0.016), Vector2(0.006, 0.018), Vector2(0.005, 0.014), Vector2(0.001, 0.002)], 6, Vector3.UP, 1.0), edge, at + Vector3(0, 0.062, 0), Vector3.ONE, yr)
				part(gun, HeroKit.loft("daggrip%d" % k, [Vector3(0, 0, 0.0), Vector3(0, 0, 0.06 if k == 0 else -0.06), Vector3(0, 0, 0.12 if k == 0 else -0.12)], [Vector2(0.024, 0.03), Vector2(0.026, 0.032), Vector2(0.03, 0.036)], 8, Vector3.UP, 0.9), m_dark, Vector3(x, 0 if k == 0 else -0.06, 0.0 if k == 0 else -0.04))
				part(gun, HeroKit.loft("dagguard%d" % k, [Vector3(-0.07, 0.03, 0), Vector3(0, 0, 0), Vector3(0.07, -0.03, 0)], [Vector2(0.018, 0.018), Vector2(0.022, 0.022), Vector2(0.016, 0.016)], 8, Vector3.FORWARD, 0.9), m_acc, Vector3(x, 0 if k == 0 else -0.06, -0.06 if k == 0 else -0.04))
		"longsword":
			var steel := toon(Color("e9e4d4"), true, 0.2)
			part(gun, HeroKit.loft("lsword", [Vector3(0, 0.02, -0.1), Vector3(0, 0.02, -0.5), Vector3(0, 0.02, -0.9), Vector3(0, 0.02, -1.06)], [Vector2(0.018, 0.065), Vector2(0.016, 0.06), Vector2(0.012, 0.045), Vector2(0.002, 0.004)], 8, Vector3.UP, 1.0), steel)
			part(gun, box(0.026, 0.02, 0.72), glow.call(Color("9af0ff")), Vector3(0, 0.02, -0.46))
			part(gun, HeroKit.loft("lguard", [Vector3(-0.15, 0.04, 0), Vector3(0, 0, 0), Vector3(0.15, 0.04, 0)], [Vector2(0.03, 0.03), Vector2(0.04, 0.04), Vector2(0.024, 0.024)], 10, Vector3.FORWARD, 0.9), m_acc, Vector3(0, 0, -0.06))
			part(gun, cyl(0.026, 0.03, 0.18, 10), m_dark, Vector3(0, 0, 0.05), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, sphere(0.04, 12), m_acc, Vector3(0, 0, 0.16))
		"greatsword":
			# a slab of a blade, wider than the juggernaut's helm, with a notched spine, a burning rune
			# channel, a heavy crossguard and a long wrapped grip
			var steel := shiny(Color("8d929c"), 0.6)
			var dark := shiny(Color("3d4049"), 0.5)
			var run_m: ShaderMaterial = glow.call(Color("ffb648"))
			var blade := [Vector3(0, 0.02, -0.14), Vector3(0, 0.02, -0.55), Vector3(0, 0.03, -1.0), Vector3(0, 0.03, -1.22), Vector3(0, 0.02, -1.36)]
			part(gun, HeroKit.loft("gsword2", blade, [Vector2(0.034, 0.15), Vector2(0.032, 0.165), Vector2(0.028, 0.15), Vector2(0.02, 0.1), Vector2(0.003, 0.006)], 8, Vector3.UP, 1.0), steel)
			part(gun, HeroKit.loft("gsword2b", blade.slice(0, 4), [Vector2(0.042, 0.05), Vector2(0.04, 0.06), Vector2(0.036, 0.05), Vector2(0.02, 0.02)], 8, Vector3.UP, 1.0), dark, Vector3(0, 0.0, 0.0))
			for k in 3:
				part(gun, box(0.05, 0.05, 0.05), dark, Vector3(0, 0.13 + 0.01 * k, -0.42 - k * 0.2), Vector3.ONE, Vector3(0, 0, PI * 0.25))
			part(gun, box(0.074, 0.03, 0.78), run_m, Vector3(0, 0.025, -0.62))
			part(gun, HeroKit.loft("gguard2", [Vector3(-0.3, 0.12, 0.04), Vector3(-0.16, 0.02, 0), Vector3(0, -0.01, 0), Vector3(0.16, 0.02, 0), Vector3(0.3, 0.12, 0.04)], [Vector2(0.045, 0.045), Vector2(0.06, 0.06), Vector2(0.07, 0.07), Vector2(0.06, 0.06), Vector2(0.035, 0.035)], 10, Vector3.FORWARD, 0.9), dark, Vector3(0, 0, -0.12))
			part(gun, box(0.09, 0.09, 0.05), m_acc, Vector3(0, 0, -0.13), Vector3.ONE, Vector3(0, 0, PI * 0.25))
			part(gun, cyl(0.034, 0.038, 0.34, 10), m_dark, Vector3(0, 0, 0.08), Vector3.ONE, Vector3(PI / 2, 0, 0))
			for k in 3:
				part(gun, cyl(0.041, 0.041, 0.02, 10), m_acc, Vector3(0, 0, 0.0 + k * 0.08), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, sphere(0.06, 12), dark, Vector3(0, 0, 0.27))
		"flamethrower": HeroGearPair.flamer(gun, m_gun, m_dark, m_acc)
		"minigun":
			# a spinning bundle of six barrels on a chunky drum
			part(gun, box(0.22, 0.22, 0.36), m_gun, Vector3(0, 0, -0.06))
			part(gun, cyl(0.16, 0.16, 0.16, 18), m_acc, Vector3(0.16, -0.04, 0.0), Vector3.ONE, Vector3(0, 0, PI / 2))
			part(gun, cyl(0.14, 0.13, 0.12, 18), m_dark, Vector3(0, 0, -0.29), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, cyl(0.15, 0.15, 0.03, 18), glow.call(Color("ffb070")), Vector3(0, 0, -0.24), Vector3.ONE, Vector3(PI / 2, 0, 0))
			var spin := Node3D.new(); spin.name = "Barrels"; spin.position = Vector3(0, 0, -0.56); gun.add_child(spin)
			for k in 6:
				var a := TAU * k / 6.0
				part(spin, cyl(0.026, 0.026, 0.56, 8), m_dark, Vector3(cos(a) * 0.078, sin(a) * 0.078, 0), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(spin, cyl(0.12, 0.12, 0.04, 16), m_gun, Vector3(0, 0, -0.24), Vector3.ONE, Vector3(PI / 2, 0, 0))
			merge_static(spin)
			part(gun, box(0.08, 0.18, 0.14), m_dark, Vector3(0, -0.17, 0.0))
		"longbow", "tower_shield":
			PinBjornWeapons.build(gun, weapon, m_dark, m_acc)      # Hem's recurve, Breaker's war hammer and aegis
		"coilcaster":
			# Sparkle's forearm coil: a copper tube wound in rings with a glowing mouth and a bracer grip
			var cop := shiny(Color("c8793c"), 0.7)
			part(gun, cyl(0.04, 0.05, 0.5, 12), m_dark, Vector3(0, 0.0, -0.22), Vector3.ONE, Vector3(PI / 2, 0, 0))
			for k in 6:
				part(gun, cyl(0.062, 0.062, 0.022, 12), cop, Vector3(0, 0.0, -0.06 - k * 0.075), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, cyl(0.075, 0.05, 0.07, 12), cop, Vector3(0, 0.0, -0.5), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, sphere(0.045, 10), glow.call(Color("ff8fd0")), Vector3(0, 0.0, -0.55))
			part(gun, box(0.09, 0.05, 0.16), m_acc, Vector3(0, 0.05, 0.06))
			grip.call(-0.02, 0.15)
		"quill_rifle":
			# Vex's drum rifle: a squat receiver, a drum of burr charges under it, a long needle barrel
			var bronze := shiny(Color("b9732f"), 0.6)
			part(gun, box(0.1, 0.12, 0.42), m_gun, Vector3(0, 0, -0.12))
			part(gun, cyl(0.1, 0.1, 0.1, 14), bronze, Vector3(0, -0.12, -0.14), Vector3.ONE, Vector3(0, 0, PI / 2))
			part(gun, cyl(0.02, 0.024, 0.55, 8), m_dark, Vector3(0, 0.02, -0.56), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, box(0.05, 0.05, 0.2), m_acc, Vector3(0, 0.08, -0.14))
			part(gun, box(0.016, 0.03, 0.3), glow.call(Color("ffb36a")), Vector3(0.056, 0.0, -0.16))
			grip.call(-0.02, 0.15)
			stock.call(0.07, 0.2, 0.08, 0.05)
		"lantern_crook", "hoar_fan":
			HeroGearCare.weapon(gun, weapon, m_gun, m_dark, m_acc)
		"spellstaff":
			# the Mage's staff: a long rune-carved rod with a glowing focus caught in a ring
			var wood2 := toon(Color("5a4636"))
			part(gun, cyl(0.022, 0.028, 1.15, 10), wood2, Vector3(0, 0, -0.32), Vector3.ONE, Vector3(PI / 2, 0, 0))
			for k in 3:
				part(gun, cyl(0.032, 0.032, 0.03, 10), m_acc, Vector3(0, 0, -0.2 - k * 0.22), Vector3.ONE, Vector3(PI / 2, 0, 0))
			var rr := TorusMesh.new(); rr.inner_radius = 0.07; rr.outer_radius = 0.095; rr.rings = 20; rr.ring_segments = 8
			part(gun, rr, m_acc, Vector3(0, 0, -0.98), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, sphere(0.06, 12), glow.call(Color("9ad8ff")), Vector3(0, 0, -0.98))
		"thumper":
			part(gun, cyl(0.12, 0.12, 0.62, 14), m_gun, Vector3(0, 0, -0.2), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(gun, cyl(0.15, 0.14, 0.1, 14), m_acc, Vector3(0, 0, -0.52), Vector3.ONE, Vector3(PI / 2, 0, 0))
			grip.call(-0.02, 0.18)

## A piece of gear lying on the ground: a glowing gem-like token with a light beam.
static func gear_drop(col: Color, rar: int) -> Node3D:
	var root := Node3D.new()
	var rc: Color = Data.RARITY[clampi(rar, 0, Data.RARITY.size() - 1)]["color"]
	var spin := Node3D.new(); spin.name = "Spin"; spin.position = Vector3(0, 0.7, 0); root.add_child(spin)
	var core := PrismMesh.new(); core.size = Vector3(0.38, 0.38, 0.38)
	part(spin, core, toon(col, true, 0.6), Vector3(0, 0.1, 0))
	part(spin, core, toon(col, true, 0.6), Vector3(0, -0.12, 0), Vector3.ONE, Vector3(PI, 0, 0))
	var t := TorusMesh.new(); t.inner_radius = 0.28; t.outer_radius = 0.33
	part(spin, t, toon(rc, false, 0.8), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0))
	var beam := part(root, cyl(0.12, 0.22, 4.0, 10), glow_mat(Color(col, 0.3)), Vector3(0, 2.0, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := MeshInstance3D.new(); ring.mesh = flat_quad(1.2)
	ring.material_override = ring_mat(rc, 0.12); ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # (a ground ring: no shadow, item 94)
	root.add_child(ring)
	return root

static func gear_pad(col: Color) -> Node3D:
	var root := Node3D.new()
	part(root, cyl(0.5, 0.58, 0.14, 18), toon(Color("3a3f52")), Vector3(0, 0.07, 0))
	var top := part(root, cyl(0.38, 0.38, 0.06, 18), toon(col, false, 1.0), Vector3(0, 0.16, 0), Vector3.ONE, Vector3.ZERO, "Top")
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

static func gear_platform(col: Color) -> Node3D:
	var root := Node3D.new()
	part(root, cyl(1.6, 1.3, 0.24, 24), toon(Color("e8dcc0")), Vector3(0, -0.12, 0))
	part(root, cyl(1.62, 1.62, 0.06, 24), toon(col, false, 0.7), Vector3(0, 0.0, 0))
	var g := part(root, cyl(1.0, 0.2, 0.7, 18), glow_mat(Color(col, 0.35)), Vector3(0, -0.6, 0))
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

static func gear_smoke() -> Node3D:
	var root := Node3D.new()
	var m := toon(Color(0.78, 0.78, 0.84), false)
	var rng := RandomNumberGenerator.new(); rng.randomize()
	for i in 14:
		var a := rng.randf() * TAU; var r := rng.randf_range(0.0, 3.0)
		var s := rng.randf_range(0.9, 1.6)
		var p := part(root, sphere(0.8), m, Vector3(cos(a) * r, rng.randf_range(0.4, 1.6), sin(a) * r), Vector3.ONE * s)
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

## Things that break when shot or dashed through.
static func breakable(kind_s: String) -> Node3D:
	if Flora.v2():
		return PropSculpt.breakable(kind_s)
	if kind_s == "crate":
		var pc := Assets.prop("dungeon/box_small", 0.78, false, {"bright": 1.1})
		if pc: return pc
	elif kind_s in ["barrel", "keg"]:
		# the red powder keg: the barrel's wood painted red, its fuse still glowing on top
		var pb := Assets.prop("dungeon/barrel_small", 0.85, true, {"band": Assets.BAND_WOOD, "paint": Color("d8483a"), "bright": 1.1})
		if pb:
			var top := (pb.get_child(0) as MeshInstance3D).get_aabb().size.y * (pb.get_child(0) as MeshInstance3D).scale.y
			part(pb, sphere(0.09, 8), toon(Color("ffd25a"), false, 0.9), Vector3(0, top + 0.06, 0), Vector3.ONE, Vector3.ZERO, "Fuse")
			return pb
	var root := Node3D.new()
	match kind_s:
		"crate":
			var wood := toon(Color("a07448")); var dark := toon(Color("6a4a30"))
			part(root, box(0.7, 0.6, 0.7), wood, Vector3(0, 0.3, 0))
			for y in [0.06, 0.54]:
				part(root, box(0.74, 0.08, 0.74), dark, Vector3(0, y, 0))
			part(root, box(0.08, 0.6, 0.74), dark, Vector3(0, 0.3, 0), Vector3.ONE, Vector3(0, 0, 0.75))
		"pot":
			var clay := toon(Color("c9825a"))
			part(root, sphere(0.3, 14), clay, Vector3(0, 0.3, 0), Vector3(1, 1.05, 1))
			part(root, cyl(0.14, 0.18, 0.14, 12), clay, Vector3(0, 0.62, 0))
			part(root, cyl(0.31, 0.31, 0.05, 14), toon(Color("e8c07a")), Vector3(0, 0.36, 0))
		"barrel", "keg":
			var red := toon(Color("c8483a"), true, 0.15); var band := toon(Color("3a3440"))
			part(root, cyl(0.3, 0.3, 0.75, 14), red, Vector3(0, 0.375, 0))
			for y in [0.12, 0.62]:
				part(root, cyl(0.315, 0.315, 0.07, 14), band, Vector3(0, y, 0))
			part(root, sphere(0.09, 8), toon(Color("ffd25a"), false, 0.9), Vector3(0, 0.8, 0), Vector3.ONE, Vector3.ZERO, "Fuse")
	return root

# ---------------------------------------------------------------- kin
static var AURA: Shader = preload("res://shaders/kin_aura.gdshader")

static func aura_mat(c: Color, strength := 0.6) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = AURA
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("strength", strength)
	return m

## The glow a hunter wears while a kin is fused onto them as armor.
static func kin_shell(c: Color) -> Node3D:
	var root := Node3D.new()
	var mi := part(root, capsule(0.62, 2.0), aura_mat(c, 0.75), Vector3(0, 1.0, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := part(root, flat_quad(2.6), ring_mat(Color(c, 0.9), 0.1), Vector3(0, 0.06, 0))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

## A kin. Every species has its own body shape, tail, feet and ears (from its "look" in
## content/kin), a rim of light in its glow colour, a soft aura shell and a few drifting particles,
## so you can tell them apart at a glance and see them against busy ground.
static func kin(species: String, rec := {}) -> Node3D:
	var sp: Dictionary = Data.KIN[species]
	var look: Dictionary = sp.get("look", {})
	var shimmer: bool = rec.get("shimmer", false)
	var ghost: bool = rec.get("ghost", false)       # brought back by the Soul Shrine: pale and glowing
	# a shimmer wears its species' own alternate palette (Shiny.palette, hand-picked in content/kin)
	var glow_c: Color = Shiny.col(species, rec, "glow") if (shimmer or ghost) else sp.get("glow", sp["color"])
	var body_c: Color = Shiny.col(species, rec, "color")
	var root := Node3D.new()
	var mats: Array = []
	var m_body := toon(body_c); mats.append(m_body)
	m_body.set_shader_parameter("rim_color", glow_c)
	m_body.set_shader_parameter("rim_amount", 2.2 if ghost else 1.4)
	var m_belly := toon(Shiny.col(species, rec, "belly")); mats.append(m_belly)
	m_belly.set_shader_parameter("rim_color", glow_c)
	var m_dark := toon(((Shiny.palette(species)["color"] if shimmer else sp["color"]) as Color).darkened(0.3)); mats.append(m_dark)
	var m_glow := toon(glow_c, false, 0.7); mats.append(m_glow)
	var m_eye := toon(Color.WHITE, false); mats.append(m_eye)
	m_eye.set_shader_parameter("use_vertex_color", true)
	m_eye.set_shader_parameter("gloss", 0.9)
	m_eye.set_shader_parameter("sss", 0.0)
	m_eye.set_shader_parameter("rim_amount", 0.25)
	m_eye.set_meta("iris", Unique.iris(rec, glow_c.lerp(sp["color"], 0.35).darkened(0.08)))     # its own eye colour (Unique)
	var m_white := toon(Color.WHITE, false, 0.6)
	var m_blush := toon(Color("ff9aa8"), false, 0.2)
	# Body moves the kin around (hops, lunges, tumbles); Flex inside it squashes and stretches (KinPuppet)
	var body_root := Node3D.new(); body_root.name = "Body"; root.add_child(body_root)
	var body := Node3D.new(); body.name = "Flex"; body_root.add_child(body)
	var built := KinModels.build(species, body, {"body": m_body, "belly": m_belly, "dark": m_dark, "glow": m_glow, "eye": m_eye, "white": m_white,
		"wing_col": Shiny.palette(species).get("wing", (Shiny.col(species, rec, "belly") as Color).lerp(glow_c, 0.3)) if shimmer else sp.get("wing", (sp["belly"] as Color).lerp(glow_c, 0.3))}, mats)
	if built.is_empty():
		var shape := String(look.get("body", "round"))
		var head_y := 0.44      # where the eyes sit
		var top_y := 0.68       # where ears sit
		var front_z := -0.28
		match shape:
			"drop":
				# a water drop: round below, tapering to a curl on top
				part(body, sphere(0.34), m_body, Vector3(0, 0.32, 0), Vector3(1.0, 0.88, 1.0))
				part(body, cyl(0.02, 0.24, 0.34), m_body, Vector3(0, 0.66, 0.04), Vector3.ONE, Vector3(0.25, 0, 0))
				part(body, sphere(0.05, 8), m_body, Vector3(0, 0.84, 0.12))
				part(body, sphere(0.24), m_belly, Vector3(0, 0.28, -0.14), Vector3(1.0, 0.95, 0.7))
				top_y = 0.6
			"burr":
				# a round burr of leaves with little thorns all over its back
				part(body, sphere(0.33), m_body, Vector3(0, 0.33, 0), Vector3(1.05, 0.95, 1.0))
				part(body, sphere(0.23), m_belly, Vector3(0, 0.29, -0.15), Vector3(1.0, 0.95, 0.7))
				for i in 9:
					var a := float(i) / 9.0 * TAU
					var up := 0.35 + 0.18 * float(i % 3)
					var dir := Vector3(cos(a) * 0.9, up, sin(a) * 0.9 + 0.35).normalized()
					if dir.z < -0.2: continue
					var sp_n := part(body, cyl(0.0, 0.05, 0.16, 6), m_dark, Vector3(0, 0.36, 0.02) + dir * 0.3)
					sp_n.basis = Basis(Quaternion(Vector3.UP, dir))
			"pear":
				# a pear: a wide bottom and a narrower head, always a little jittery
				part(body, sphere(0.33), m_body, Vector3(0, 0.3, 0), Vector3(1.05, 0.85, 1.0))
				part(body, sphere(0.25), m_body, Vector3(0, 0.56, -0.02))
				part(body, sphere(0.22), m_belly, Vector3(0, 0.26, -0.15), Vector3(1.0, 0.9, 0.7))
				head_y = 0.58; top_y = 0.78; front_z = -0.22
			"boulder":
				# a chunky rock: a wide body with stone plates on its back and a heavy brow
				part(body, sphere(0.36), m_body, Vector3(0, 0.33, 0), Vector3(1.18, 0.86, 1.08))
				part(body, sphere(0.24), m_belly, Vector3(0, 0.27, -0.17), Vector3(1.1, 0.9, 0.65))
				for i in 3:
					part(body, box(0.3 - i * 0.06, 0.08, 0.2), m_dark, Vector3(0, 0.6 - i * 0.12, 0.12 + i * 0.12), Vector3.ONE, Vector3(-0.5 - i * 0.3, 0, 0))
				part(body, box(0.4, 0.07, 0.12), m_dark, Vector3(0, 0.53, -0.26), Vector3.ONE, Vector3(0.35, 0, 0))
				head_y = 0.42
			"cloud":
				# a puff of cloud that floats, with no feet at all
				for pf in [[Vector3(0, 0.42, 0), 0.3], [Vector3(-0.2, 0.38, 0.08), 0.2], [Vector3(0.2, 0.38, 0.08), 0.2], [Vector3(0, 0.6, 0.06), 0.2], [Vector3(0, 0.34, 0.22), 0.18]]:
					part(body, sphere(pf[1]), m_body, pf[0])
				part(body, sphere(0.2), m_belly, Vector3(0, 0.38, -0.14), Vector3(1.0, 0.9, 0.6))
				head_y = 0.48; top_y = 0.72
			_:
				part(body, sphere(0.34), m_body, Vector3(0, 0.34, 0), Vector3(1.05, 0.92, 1.0))
				part(body, sphere(0.24), m_belly, Vector3(0, 0.3, -0.14), Vector3(1.0, 0.95, 0.7))
		# face: big eyes with a catch light, and rosy cheeks
		for sx in [-1.0, 1.0]:
			var sd := "L" if sx < 0.0 else "R"
			part(body, eye_mesh(0.068, m_eye.get_meta("iris")), m_eye, Vector3(0.12 * sx, head_y, front_z), Vector3(1, 1.15, 1), Vector3.ZERO, "Eye" + sd)
			part(body, sphere(0.024, 6), m_white, Vector3(0.12 * sx + 0.025, head_y + 0.035, front_z - 0.05), Vector3.ONE, Vector3.ZERO, "Shine" + sd)
			part(body, sphere(0.04, 6), m_blush, Vector3(0.2 * sx, head_y - 0.08, front_z + 0.05), Vector3(1, 0.5, 0.4))
		# feet
		match String(look.get("feet", "paws")):
			"stumps":
				for sx in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						part(body, cyl(0.08, 0.1, 0.14, 8), m_dark, Vector3(0.2 * sx, 0.06, 0.12 * sz))
			"none":
				body.position.y = 0.12
			_:
				for sx in [-1.0, 1.0]:
					part(body, sphere(0.08, 8), m_body, Vector3(0.2 * sx, 0.06, -0.08), Vector3(1, 0.6, 1.2))
		# tail, on its own pivot so it can wag
		var flex := body
		var tail_n := Node3D.new(); tail_n.name = "Tail"; flex.add_child(tail_n)
		body = tail_n
		match String(look.get("tail", "nub")):
			"flame":
				part(body, cyl(0.0, 0.11, 0.3, 8), m_glow, Vector3(0, 0.36, 0.38), Vector3.ONE, Vector3(-1.0, 0, 0))
				part(body, cyl(0.0, 0.06, 0.2, 8), toon(Color("fff0a0"), false, 0.9), Vector3(0, 0.42, 0.46), Vector3.ONE, Vector3(-0.8, 0, 0))
			"fish":
				part(body, box(0.02, 0.24, 0.22), m_belly, Vector3(0, 0.3, 0.42), Vector3.ONE, Vector3(0.3, 0, 0))
				part(body, sphere(0.09, 8), m_body, Vector3(0, 0.26, 0.32))
			"sprout":
				part(body, cyl(0.015, 0.02, 0.22, 6), toon(Color("5a8a3a")), Vector3(0, 0.4, 0.36), Vector3.ONE, Vector3(-0.6, 0, 0))
				part(body, sphere(0.08, 8), toon(Color("8fd16a")), Vector3(0, 0.5, 0.44), Vector3(1.4, 0.3, 0.8))
			"zig":
				for i in 3:
					part(body, box(0.05, 0.16, 0.05), m_glow, Vector3(0.05 * (1 if i % 2 == 0 else -1), 0.3 + i * 0.1, 0.34 + i * 0.05), Vector3.ONE, Vector3(-0.6, 0, 0.6 * (1 if i % 2 == 0 else -1)))
			"stub":
				part(body, sphere(0.09, 8), m_dark, Vector3(0, 0.22, 0.36))
			"wisp":
				for i in 3:
					part(body, sphere(0.07 - i * 0.015, 8), m_glow, Vector3(0, 0.36 + i * 0.05, 0.36 + i * 0.12), Vector3.ONE, Vector3.ZERO, "Wisp%d" % i)
			_:
				part(body, sphere(0.1, 8), m_body, Vector3(0, 0.26, 0.32))
		body = flex
		_repivot(tail_n, Vector3(0, 0.3, 0.3))
		var ears_n := Node3D.new(); ears_n.name = "Ears"; flex.add_child(ears_n)
		body = ears_n
		match String(sp["ears"]):
			"flame":
				var m_f := toon(Color("ffb347"), true, 0.5); mats.append(m_f)
				part(body, cyl(0.0, 0.12, 0.3), m_f, Vector3(0, top_y + 0.06, 0.02))
				part(body, cyl(0.0, 0.08, 0.22), m_f, Vector3(-0.13, top_y, 0.04), Vector3.ONE, Vector3(0, 0, 0.4))
				part(body, cyl(0.0, 0.08, 0.22), m_f, Vector3(0.13, top_y, 0.04), Vector3.ONE, Vector3(0, 0, -0.4))
			"fin":
				part(body, sphere(0.14), m_belly, Vector3(0, top_y - 0.02, 0.06), Vector3(0.35, 1.1, 1.3))
				part(body, sphere(0.1), m_body, Vector3(-0.3, 0.3, 0.05), Vector3(0.4, 0.8, 1.2))
				part(body, sphere(0.1), m_body, Vector3(0.3, 0.3, 0.05), Vector3(0.4, 0.8, 1.2))
			"leaf":
				var m_l := toon(Color("3e8f3a")); mats.append(m_l)
				part(body, sphere(0.14), m_l, Vector3(-0.14, top_y, 0), Vector3(0.5, 1.2, 0.25), Vector3(0, 0, 0.5))
				part(body, sphere(0.14), m_l, Vector3(0.14, top_y, 0), Vector3(0.5, 1.2, 0.25), Vector3(0, 0, -0.5))
			"bolt":
				var m_b := toon(Color("fff27a"), true, 0.4); mats.append(m_b)
				part(body, box(0.06, 0.26, 0.06), m_b, Vector3(-0.14, top_y + 0.04, 0), Vector3.ONE, Vector3(0, 0, 0.5))
				part(body, box(0.06, 0.26, 0.06), m_b, Vector3(0.14, top_y + 0.04, 0), Vector3.ONE, Vector3(0, 0, -0.5))
				part(body, box(0.05, 0.16, 0.05), m_b, Vector3(-0.22, top_y + 0.18, 0), Vector3.ONE, Vector3(0, 0, -0.4))
				part(body, box(0.05, 0.16, 0.05), m_b, Vector3(0.22, top_y + 0.18, 0), Vector3.ONE, Vector3(0, 0, 0.4))
			"horn":
				var m_h := toon(Color("e8e0cc")); mats.append(m_h)
				part(body, cyl(0.0, 0.07, 0.2), m_h, Vector3(-0.15, top_y - 0.02, -0.05), Vector3.ONE, Vector3(-0.2, 0, 0.35))
				part(body, cyl(0.0, 0.07, 0.2), m_h, Vector3(0.15, top_y - 0.02, -0.05), Vector3.ONE, Vector3(-0.2, 0, -0.35))
			"wisp":
				var m_w := toon(Color("efe8ff"), false, 0.8); mats.append(m_w)
				for i in 3:
					var a := float(i) / 3.0 * TAU
					part(body, sphere(0.06, 8), m_w, Vector3(cos(a) * 0.3, top_y + 0.04 + sin(a * 2.0) * 0.04, sin(a) * 0.3), Vector3.ONE, Vector3.ZERO, "Orb%d" % i)
		body = flex
		_repivot(ears_n, Vector3(0, top_y - 0.06, 0))
	# the aura shell: an outline of light in its glow colour, brightest at the silhouette
	var shell := part(body_root, sphere(0.4, 18), aura_mat(glow_c, 0.0), Vector3(0, 0.4, 0.02), Vector3(1.12, 1.15, 1.1), Vector3.ZERO, "Shell")
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.visible = false
	# a few particles that say what it is: embers, bubbles, leaves, sparks, grit, wind
	var pt := CPUParticles3D.new()
	pt.name = "Aura"
	pt.amount = 7
	pt.lifetime = 1.1
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	pt.emission_sphere_radius = 0.38
	pt.position = Vector3(0, 0.4, 0)
	pt.mesh = sphere(0.035, 4)
	pt.scale_amount_min = 0.6; pt.scale_amount_max = 1.4
	pt.color = glow_c
	pt.local_coords = false
	pt.direction = Vector3.UP
	pt.spread = 30.0
	pt.initial_velocity_min = 0.3; pt.initial_velocity_max = 0.8
	pt.gravity = Vector3(0, 0.6, 0)
	match String(look.get("aura", "")):
		"bubbles": pt.gravity = Vector3(0, 0.9, 0); pt.mesh = sphere(0.045, 6)
		"leaves": pt.gravity = Vector3(0, -0.5, 0); pt.initial_velocity_min = 0.5; pt.spread = 120.0; pt.mesh = box(0.07, 0.01, 0.04)
		"sparks": pt.gravity = Vector3.ZERO; pt.spread = 180.0; pt.initial_velocity_min = 0.8; pt.initial_velocity_max = 1.6; pt.lifetime = 0.5; pt.mesh = box(0.02, 0.09, 0.02)
		"pebbles": pt.gravity = Vector3(0, -2.0, 0); pt.mesh = box(0.05, 0.05, 0.05); pt.amount = 4
		"wind": pt.gravity = Vector3.ZERO; pt.spread = 180.0; pt.initial_velocity_min = 0.6; pt.initial_velocity_max = 1.0; pt.mesh = sphere(0.025, 4)
		"drips": pt.gravity = Vector3(0, -1.6, 0); pt.initial_velocity_min = 0.0; pt.initial_velocity_max = 0.2; pt.mesh = sphere(0.03, 6); pt.scale_amount_min = 0.8
		"prism":
			var pp := PrismMesh.new(); pp.size = Vector3(0.05, 0.08, 0.02)
			pt.mesh = pp; pt.gravity = Vector3(0, 0.3, 0); pt.spread = 180.0; pt.initial_velocity_min = 0.2; pt.initial_velocity_max = 0.5; pt.angular_velocity_min = -180.0; pt.angular_velocity_max = 180.0
		"spores": pt.gravity = Vector3(0, 0.15, 0); pt.spread = 180.0; pt.initial_velocity_min = 0.05; pt.initial_velocity_max = 0.25; pt.lifetime = 2.2; pt.mesh = sphere(0.022, 4); pt.amount = 10
		"rings":
			var tr := TorusMesh.new(); tr.inner_radius = 0.06; tr.outer_radius = 0.075; tr.rings = 12; tr.ring_segments = 3
			pt.mesh = tr; pt.gravity = Vector3.ZERO; pt.direction = Vector3(0, 0.4, -1); pt.spread = 25.0; pt.initial_velocity_min = 0.5; pt.initial_velocity_max = 0.8; pt.amount = 4
			pt.scale_amount_min = 1.0; pt.scale_amount_max = 2.6
		"moondust": pt.gravity = Vector3(0, -0.15, 0); pt.spread = 180.0; pt.initial_velocity_min = 0.05; pt.initial_velocity_max = 0.2; pt.lifetime = 1.8; pt.mesh = sphere(0.02, 4); pt.amount = 9
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.vertex_color_use_as_albedo = true
	pm.albedo_color = Color(1, 1, 1, 0.9)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pt.material_override = pm
	pt.emitting = false
	root.add_child(pt)
	root.set_meta("mats", mats)
	for mm in collect_mats(body_root):
		(mm as ShaderMaterial).set_shader_parameter("paint", 0.015)
		if (mm as ShaderMaterial).get_shader_parameter("glow") == 0.0 and not (mm as ShaderMaterial).get_shader_parameter("use_vertex_color"):
			painted(mm, 0, 0.24, 0.26, 0.22)
	painted(m_dark, 2, 0.2, 0.2, 0.2)
	bake_part_y(body_root)
	Evo.dress(root, rec)
	if shimmer:
		# a shimmer sparkles a little, all the time
		for i in 3:
			var a := TAU * i / 3.0
			part(body, sphere(0.035, 6), toon(Color("fff6c0"), false, 1.6), Vector3(cos(a) * 0.42, 0.62 + i * 0.08, sin(a) * 0.42), Vector3.ONE, Vector3.ZERO, "Spark%d" % i)
	var acc: String = rec.get("acc", "")
	if acc != "" and Data.ACCS.has(acc):
		accessory(body, acc, Goods.wear_col(rec))
	var pup: Node = KinPuppet.new(); pup.set("species", species)
	root.add_child(pup)
	if int(rec.get("level", 1)) < 4 and (rec.get("forms", []) as Array).is_empty() and not rec.is_empty():
		# hatchlings are small
		root.set_meta("evo_scale", 0.82)
		root.scale = Vector3.ONE * 0.82
	Unique.dress(root, rec)          # this kin's own: size, palette shift, coat marks, proportions, shapes
	Mutations.dress(root, rec)       # rare mutations: size, palette, extra parts
	ShadowPolicy.boki(root)      # the body casts, the bits don't (item 94)
	return root

## Moves a group's pivot to `at` without moving what's in it.
static func _repivot(n: Node3D, at: Vector3) -> void:
	n.position = at
	for ch in n.get_children():
		(ch as Node3D).position -= at

## Something a kin wears, on its body at head height, in colour c (its own, or a dye's).
static func accessory(body: Node3D, id: String, c: Color) -> void:
	var m := toon(c)
	match id:
		"bell":
			part(body, sphere(0.07, 10), toon(c, true, 0.4), Vector3(0, 0.2, -0.33))
			part(body, cyl(0.2, 0.2, 0.04, 16), toon(Color("d9604a")), Vector3(0, 0.25, -0.02), Vector3(1.05, 1, 1.05))
		"bow":
			for sx in [-1.0, 1.0]:
				part(body, sphere(0.09, 8), m, Vector3(0.1 * sx + 0.16, 0.66, -0.06), Vector3(1.2, 0.7, 0.5), Vector3(0, 0, 0.5 * sx))
			part(body, sphere(0.04, 6), m, Vector3(0.16, 0.66, -0.07))
		"leafhat":
			part(body, sphere(0.2, 10), m, Vector3(0, 0.66, 0), Vector3(1.3, 0.25, 1.3))
			part(body, cyl(0.01, 0.015, 0.14, 6), toon(Color("6b4a33")), Vector3(0, 0.76, 0))
		"scarf":
			part(body, cyl(0.29, 0.31, 0.09, 16), m, Vector3(0, 0.24, -0.02))
			part(body, box(0.09, 0.2, 0.04), m, Vector3(0.12, 0.13, -0.29), Vector3.ONE, Vector3(0.2, 0, 0.2))
		"crown":
			for i in 7:
				var a := TAU * i / 7.0
				part(body, sphere(0.05, 6), toon(Color("ffd0e8") if i % 2 == 0 else Color("fff27a"), false, 0.3), Vector3(cos(a) * 0.2, 0.68, sin(a) * 0.2))
		"goggles":
			part(body, cyl(0.3, 0.3, 0.05, 16), toon(Color("4e3424")), Vector3(0, 0.53, 0), Vector3(1.0, 1, 1.0), Vector3(0.25, 0, 0))
			for sx in [-1.0, 1.0]:
				part(body, cyl(0.07, 0.07, 0.05, 12), toon(Color("9af0ff"), false, 0.5), Vector3(0.11 * sx, 0.58, -0.27), Vector3.ONE, Vector3(PI / 2 + 0.25, 0, 0))
		"cape":
			part(body, box(0.42, 0.36, 0.03), m, Vector3(0, 0.3, 0.3), Vector3.ONE, Vector3(-0.35, 0, 0))
			part(body, cyl(0.2, 0.2, 0.04, 14), m, Vector3(0, 0.46, 0.05))
		"tophat":
			part(body, cyl(0.17, 0.17, 0.03, 14), m, Vector3(0, 0.68, 0))
			part(body, cyl(0.11, 0.11, 0.2, 14), m, Vector3(0, 0.79, 0))
			part(body, cyl(0.113, 0.113, 0.04, 14), toon(Color("d9604a")), Vector3(0, 0.72, 0))
		_:
			BokiWear.build(body, id, c)

## An air ring: fly through it for a burst of speed.
static func air_ring() -> Node3D:
	var root := Node3D.new()
	var t := TorusMesh.new(); t.inner_radius = 1.2; t.outer_radius = 1.42; t.rings = 28; t.ring_segments = 8
	var ring := part(root, t, toon(Color("5ad0f0"), true, 0.45), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0), "Ring")
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc := part(root, cyl(1.2, 1.2, 0.02, 24), glow_mat(Color(0.55, 0.9, 1.0, 0.12)), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0), "Disc")
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

## The training yard: a straw dummy on a post, a mat and a couple of hoops.
static func training_yard() -> Node3D:
	var root := Node3D.new()
	var wood := toon(Color("8b6d52")); var straw := toon(Color("e2c47a")); var mat := toon(Color("c9604a"))
	part(root, cyl(0.07, 0.08, 1.3, 8), wood, Vector3(1.0, 0.65, -0.6))
	var dummy := Node3D.new(); dummy.name = "Dummy"; dummy.position = Vector3(1.0, 0.0, -0.6); root.add_child(dummy)
	part(dummy, sphere(0.28, 12), straw, Vector3(0, 0.95, 0), Vector3(1, 1.3, 1))
	part(dummy, sphere(0.16, 10), straw, Vector3(0, 1.45, 0))
	part(dummy, box(0.7, 0.08, 0.08), wood, Vector3(0, 1.1, 0))
	# a sparring mat painted like a target
	part(root, cyl(0.78, 0.8, 0.05, 24), toon(Color("e9dcc0")), Vector3(0, 0.025, 0))
	part(root, cyl(0.62, 0.62, 0.02, 24), mat, Vector3(0, 0.055, 0))
	part(root, cyl(0.44, 0.44, 0.02, 24), toon(Color("e9dcc0"), false), Vector3(0, 0.065, 0))
	part(root, cyl(0.22, 0.22, 0.02, 20), mat, Vector3(0, 0.075, 0))
	var ring_m := toon(Color("f2c84a"))
	for i in 2:
		var t := TorusMesh.new(); t.inner_radius = 0.26; t.outer_radius = 0.32
		part(root, t, ring_m, Vector3(-1.1 - i * 0.6, 0.34, 0.3 - i * 0.2), Vector3.ONE, Vector3(PI / 2, 0.3, 0))
		part(root, cyl(0.025, 0.025, 0.34, 6), wood, Vector3(-1.1 - i * 0.6, 0.0, 0.3 - i * 0.2))
	return root

## The Nesting Nook at home: a flower arbor over a big straw nest with two cushions, where two kin
## who are close can leave an egg. (The egg itself sits in the middle, from nest_egg().)
static func nesting_nook() -> Node3D:
	var root := Node3D.new()
	var wood := toon(Color("8a6a45")); var straw := toon(Color("d8b46a")); var straw_d := toon(Color("b08a48"))
	var pink := toon(Color("ff9ab8"), false, 0.15); var leaf := toon(Color("6aa64a"))
	# a stepping-stone floor
	for i in 7:
		var a := TAU * i / 7.0
		part(root, cyl(0.24, 0.26, 0.06, 8), toon(Color("cfc8bb")), Vector3(cos(a) * 1.45, 0.03, sin(a) * 1.45))
	# the nest: a thick ring of straw with a few loose stalks
	var t := TorusMesh.new(); t.inner_radius = 0.42; t.outer_radius = 0.82; t.rings = 18; t.ring_segments = 8
	part(root, t, straw, Vector3(0, 0.16, 0), Vector3(1.0, 0.7, 1.0))
	for i in 10:
		var a := TAU * i / 10.0 + 0.2
		part(root, box(0.03, 0.03, 0.4), straw_d, Vector3(cos(a) * 0.66, 0.3, sin(a) * 0.66), Vector3.ONE, Vector3(0.3, -a, 0.2))
	# two cushions for the pair, either side
	for sx in [-1.0, 1.0]:
		part(root, sphere(0.3, 14), toon(Color("f2c84a") if sx < 0 else Color("8ab4ff")), Vector3(1.2 * sx, 0.12, 0.55), Vector3(1.0, 0.35, 1.0))
	# the arbor: two posts and an arch of vine and flowers behind the nest
	for sx in [-1.0, 1.0]:
		part(root, cyl(0.06, 0.07, 1.9, 8), wood, Vector3(1.05 * sx, 0.95, -0.7))
	var arch := TorusMesh.new(); arch.inner_radius = 0.98; arch.outer_radius = 1.12; arch.rings = 24; arch.ring_segments = 6
	var ar := part(root, arch, leaf, Vector3(0, 1.9, -0.7), Vector3.ONE, Vector3(PI / 2, 0, 0))
	ar.scale = Vector3(1.0, 1.0, 0.75)
	for i in 11:
		var a := PI * i / 10.0
		part(root, sphere(0.09, 8), pink if i % 2 == 0 else toon(Color("fff3a8"), false, 0.15), Vector3(cos(a) * 1.05, 1.9 + sin(a) * 0.78, -0.7))
	# a heart sign hanging from the top of the arch
	var heart := Node3D.new(); heart.name = "Heart"; heart.position = Vector3(0, 2.25, -0.66); root.add_child(heart)
	part(heart, sphere(0.13, 12), toon(Color("ff5a7a"), false, 0.35), Vector3(-0.08, 0.04, 0))
	part(heart, sphere(0.13, 12), toon(Color("ff5a7a"), false, 0.35), Vector3(0.08, 0.04, 0))
	part(heart, cyl(0.0, 0.19, 0.24, 4), toon(Color("ff5a7a"), false, 0.35), Vector3(0, -0.1, 0), Vector3(1.0, 1.0, 0.45), Vector3(PI, PI / 4, 0))
	PropAnim.on(heart, 0.0, 0.05, 2.0)
	return root

## An egg in a straw nest, for kin you raise from an egg at home.
static func nest_egg(c: Color, spot: Color) -> Node3D:
	var root := Node3D.new()
	part(root, cyl(0.42, 0.34, 0.16, 16), toon(Color("c9a46a")), Vector3(0, 0.08, 0))
	var shell := Node3D.new(); shell.name = "Shell"; root.add_child(shell)
	part(shell, sphere(0.26, 16), toon(c.lightened(0.15)), Vector3(0, 0.36, 0), Vector3(0.92, 1.25, 0.92))
	var rng := RandomNumberGenerator.new(); rng.seed = int(c.r * 1000 + spot.g * 100)
	for i in 6:
		var a := rng.randf() * TAU; var y := rng.randf_range(0.2, 0.55)
		part(shell, sphere(0.05, 8), toon(spot), Vector3(cos(a) * 0.22, y, sin(a) * 0.22), Vector3(1, 1, 0.5))
	return root

## The Incubator beside the Nesting Nook: a clay brazier with a copper hood on a round stone hearth,
## and eight straw cradles in an arc in front of it ("C0".."C7", each with an "Egg" anchor, a ring
## of six ember pebbles "P0".."P5" that light as its egg warms, and a "Lock" grate shown while that
## cradle isn't bought yet). Beside it, a little shelf ("Shelf", slots "S0".."S5") for eggs waiting
## for a free cradle. "Embers" glow in the brazier; "Glow" is its light.
static func incubator() -> Node3D:
	var root := Node3D.new()
	var stone := toon(Color("b9b0a2")); var stone_d := toon(Color("8f877b"))
	var clay := toon(Color("b4583a")); var clay_d := toon(Color("7e3a26"))
	var iron := toon(Color("3a3236")); var copper := toon(Color("c8774a"), true, 0.1)
	var wood := toon(Color("8a6a45")); var wood_d := toon(Color("6a4e32"))
	var straw := toon(Color("d8b46a"))
	var pebble := toon(Color("4a3a36"))
	# the hearth: a low round of fitted stones
	part(root, cyl(1.02, 1.08, 0.12, 22), stone_d, Vector3(0, 0.06, 0.05))
	part(root, cyl(0.94, 0.98, 0.06, 22), stone, Vector3(0, 0.15, 0.05))
	# the brazier at the back: a clay bowl on three stubby feet, glowing coals inside
	var bz := Vector3(0, 0, -0.38)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		part(root, cyl(0.05, 0.07, 0.2, 8), clay_d, bz + Vector3(cos(a) * 0.24, 0.27, sin(a) * 0.24))
	part(root, cyl(0.4, 0.24, 0.3, 16), clay, bz + Vector3(0, 0.48, 0))
	var lip := TorusMesh.new(); lip.inner_radius = 0.35; lip.outer_radius = 0.44; lip.rings = 20; lip.ring_segments = 8
	part(root, lip, clay_d, bz + Vector3(0, 0.63, 0), Vector3(1.0, 0.6, 1.0))
	var embers := Node3D.new(); embers.name = "Embers"; embers.position = bz; root.add_child(embers)
	var rng := RandomNumberGenerator.new(); rng.seed = 41
	for i in 9:
		var a := rng.randf() * TAU; var r := rng.randf_range(0.04, 0.28)
		part(embers, sphere(rng.randf_range(0.06, 0.09), 8), toon(Color("ff8a3a").lerp(Color("ffd06a"), rng.randf()), false, 1.4), Vector3(cos(a) * r, 0.62, sin(a) * r), Vector3(1, 0.6, 1))
	# the hood: three iron posts and a copper cap with a little chimney
	for i in 3:
		var a := TAU * i / 3.0 + PI * 0.5
		part(root, cyl(0.025, 0.03, 1.35, 6), iron, bz + Vector3(cos(a) * 0.46, 0.85, sin(a) * 0.46), Vector3.ONE, Vector3(sin(a) * 0.08, 0, -cos(a) * 0.08))
	part(root, cyl(0.1, 0.5, 0.28, 14), copper, bz + Vector3(0, 1.62, 0))
	part(root, cyl(0.08, 0.1, 0.2, 10), copper, bz + Vector3(0, 1.84, 0))
	part(root, cyl(0.13, 0.11, 0.05, 10), iron, bz + Vector3(0, 1.95, 0))
	var glow := OmniLight3D.new(); glow.name = "Glow"
	glow.light_color = Color("ffa04a"); glow.light_energy = 0.0; glow.omni_range = 2.6; glow.position = bz + Vector3(0, 0.9, 0.5)
	root.add_child(glow)
	# the cradles: an arc of eight round the front of the hearth, each with ember pebbles in front
	for i in 8:
		var a := PI * (0.04 + 0.92 * float(i) / 7.0)
		var c := Node3D.new(); c.name = "C%d" % i
		c.position = Vector3(-cos(a) * 0.74, 0.18, 0.02 + sin(a) * 0.62)
		root.add_child(c)
		part(c, cyl(0.14, 0.16, 0.1, 12), stone, Vector3(0, 0.05, 0))
		var tr := TorusMesh.new(); tr.inner_radius = 0.06; tr.outer_radius = 0.14; tr.rings = 14; tr.ring_segments = 7
		part(c, tr, straw, Vector3(0, 0.13, 0), Vector3(1.0, 0.6, 1.0), Vector3.ZERO, "Nest")
		for j in 6:
			var b := PI * (0.18 + 0.64 * float(j) / 5.0)
			part(c, sphere(0.028, 6), pebble, Vector3(cos(b) * 0.17, 0.02, sin(b) * 0.17), Vector3(1.2, 0.7, 1.2), Vector3.ZERO, "P%d" % j)
		var egg := Node3D.new(); egg.name = "Egg"; egg.position = Vector3(0, 0.08, 0); c.add_child(egg)
		var lock := Node3D.new(); lock.name = "Lock"; c.add_child(lock)
		for k in 3:
			part(lock, box(0.24, 0.02, 0.025), iron, Vector3(0, 0.12, -0.07 + k * 0.07))
		lock.visible = false
	# the shelf for eggs waiting their turn, behind and to one side: two planks, three eggs a plank
	var shelf := Node3D.new(); shelf.name = "Shelf"; shelf.position = Vector3(0.95, 0, -0.95); shelf.rotation.y = -0.35; root.add_child(shelf)
	for sx in [-1.0, 1.0]:
		part(shelf, box(0.06, 0.95, 0.06), wood_d, Vector3(sx * 0.36, 0.47, -0.1))
		part(shelf, box(0.06, 0.95, 0.06), wood_d, Vector3(sx * 0.36, 0.47, 0.1))
	for y in [0.3, 0.7]:
		part(shelf, box(0.82, 0.05, 0.28), wood, Vector3(0, y, 0))
		for j in 3:
			var x := -0.24 + j * 0.24
			var straw_ring := TorusMesh.new(); straw_ring.inner_radius = 0.045; straw_ring.outer_radius = 0.09; straw_ring.rings = 10; straw_ring.ring_segments = 6
			part(shelf, straw_ring, straw, Vector3(x, y + 0.04, 0), Vector3(1.0, 0.6, 1.0))
			var mk := Marker3D.new(); mk.name = "S%d" % ((0 if y < 0.5 else 3) + j); mk.position = Vector3(x, y + 0.03, 0)
			shelf.add_child(mk)
	return root

## A small gold Rare Egg for the incubator's shelf and cradle, spotted in the colour of the kin inside.
static func rare_egg_small(spot: Color, s := 1.0) -> Node3D:
	var root := Node3D.new()
	var shell := Node3D.new(); shell.name = "Shell"; root.add_child(shell)
	var gold := toon(Color("ffd36a"), true, 0.35)
	part(shell, sphere(0.26 * s, 16), gold, Vector3(0, 0.3 * s, 0), Vector3(0.9, 1.22, 0.9))
	var rng := RandomNumberGenerator.new(); rng.seed = int(spot.r * 991 + spot.g * 113 + spot.b * 7)
	var sm := toon(spot, false, 1.0)
	for i in 7:
		var a := rng.randf() * TAU; var y := rng.randf_range(0.16, 0.5)
		part(shell, sphere(0.045 * s, 8), sm, Vector3(cos(a) * 0.215 * s, y * s, sin(a) * 0.215 * s), Vector3(1, 1, 0.5))
	return root

# ---------------------------------------------------------------- monsters
static func mob(kind: String) -> Node3D:
	if kind == "shrubling":
		return ShrublingModel.build(Color("5f9a46"))      # (Shrubling re-dresses it in its island's leaf colour)
	var md: Dictionary = Data.MOBS[kind]
	if md.get("blight", false):
		return BlightModels.build(kind)
	if md.get("boss", false) or md.get("ward", false):
		return BossModels.build(kind)
	if Flora.v2():
		return MobModels.build(kind)
	var pk := Assets.mob(kind, md["color"]) if Assets.on() else null
	if pk:
		if kind == "warden":
			# the boss: half again as big, a gold crown and a violet heart-gem
			pk.scale = Vector3.ONE * 1.5
			var gold := toon(Color("f2c84a"), true, 0.5)
			var crown := Node3D.new(); crown.position = Vector3(0, 1.78, 0); pk.get_node("Body").add_child(crown)
			for i in 5:
				var a := TAU * i / 5.0
				part(crown, cyl(0.0, 0.07, 0.24, 6), gold, Vector3(cos(a) * 0.2, 0.12, sin(a) * 0.2))
			part(crown, cyl(0.24, 0.24, 0.08, 14), gold, Vector3.ZERO)
			part(pk.get_node("Body"), sphere(0.11, 8), toon(Color("c9a0ff"), false, 1.2), Vector3(0, 1.15, -0.22))
			(pk.get_meta("mats") as Array).append(gold)
		return pk
	var root := Node3D.new()
	var mats: Array = []
	var m := toon(md["color"]); mats.append(m)
	var m_dark := toon(Color(md["color"]).darkened(0.5)); mats.append(m_dark)
	var m_eye := toon(Color("ffe25a"), false, 1.2); mats.append(m_eye)
	var body := Node3D.new(); body.name = "Body"; root.add_child(body)
	match kind:
		"skitter":
			# a scuttling beetle: domed shell with a seam, mandibles, six jointed legs on pivots
			part(body, sphere(0.36), m_dark, Vector3(0, 0.36, 0.02), Vector3(1.05, 0.62, 1.2))
			part(body, sphere(0.36), m, Vector3(0, 0.44, 0.06), Vector3(1.0, 0.62, 1.15))
			part(body, box(0.03, 0.05, 0.62), m_dark, Vector3(0, 0.66, 0.08), Vector3.ONE, Vector3(-0.08, 0, 0))
			part(body, sphere(0.2), m_dark, Vector3(0, 0.36, -0.36), Vector3(1.1, 0.8, 0.9))
			for sx in [-1.0, 1.0]:
				part(body, sphere(0.055, 6), m_eye, Vector3(0.1 * sx, 0.44, -0.5))
				var jaw := Node3D.new(); jaw.name = "Jaw" + ("L" if sx < 0 else "R"); jaw.position = Vector3(0.09 * sx, 0.3, -0.5); body.add_child(jaw)
				part(jaw, cyl(0.0, 0.035, 0.2, 5), m_dark, Vector3(0.02 * sx, 0, -0.08), Vector3.ONE, Vector3(-PI / 2, 0, -0.5 * sx))
				for i in 3:
					var lg := Node3D.new(); lg.name = "Leg%d%d" % [i, int(sx)]
					lg.position = Vector3(0.24 * sx, 0.3, -0.2 + i * 0.2); body.add_child(lg)
					part(lg, box(0.26, 0.05, 0.05), m_dark, Vector3(0.12 * sx, 0.03, 0), Vector3.ONE, Vector3(0, 0, 0.35 * sx))
					part(lg, box(0.05, 0.3, 0.05), m_dark, Vector3(0.25 * sx, -0.12, 0), Vector3.ONE, Vector3(0, 0, 0.2 * sx))
		"spitter":
			part(body, cyl(0.1, 0.16, 0.6), m_dark, Vector3(0, 0.3, 0))
			part(body, sphere(0.36), m, Vector3(0, 0.8, 0), Vector3(1.0, 0.9, 1.0), Vector3.ZERO, "Bulb")
			for i in 5:
				var a2 := TAU * i / 5.0
				part(body.get_node("Bulb"), sphere(0.16, 8), m_dark, Vector3(cos(a2) * 0.3, 0.12, sin(a2) * 0.3), Vector3(1.2, 0.3, 0.7), Vector3(0, -a2, 0.6))
			part(body, cyl(0.16, 0.2, 0.12), m_eye, Vector3(0, 0.8, -0.3), Vector3.ONE, Vector3(PI / 2, 0, 0))
			for i in 4:
				var a := float(i) / 4.0 * TAU + 0.4
				part(body, sphere(0.2), m, Vector3(cos(a) * 0.32, 0.08, sin(a) * 0.32), Vector3(1.4, 0.25, 0.7), Vector3(0, -a, 0))
		"bomber":
			var puff := Node3D.new(); puff.name = "Puff"; body.add_child(puff)
			part(puff, sphere(0.42, 16), m, Vector3(0, 0.5, 0))
			for i in 6:
				var a := TAU * i / 6.0
				part(puff, sphere(0.12, 8), m_dark, Vector3(cos(a) * 0.36, 0.5 + sin(a * 2.0) * 0.12, sin(a) * 0.36))
			part(puff, sphere(0.05, 6), m_eye, Vector3(-0.13, 0.6, -0.38))
			part(puff, sphere(0.05, 6), m_eye, Vector3(0.13, 0.6, -0.38))
			part(puff, cyl(0.03, 0.03, 0.22, 6), m_dark, Vector3(0, 0.98, 0))
			part(puff, sphere(0.07, 8), toon(Color("ffd25a"), false, 1.4), Vector3(0, 1.11, 0))
		"glimmer":
			var gold := toon(md["color"], true, 0.8); mats.append(gold)
			part(body, sphere(0.36, 16), gold, Vector3(0, 0.42, 0), Vector3(1, 0.9, 1.1))
			part(body, sphere(0.14, 10), gold, Vector3(-0.22, 0.76, 0.02), Vector3(0.6, 1.4, 0.6))
			part(body, sphere(0.14, 10), gold, Vector3(0.22, 0.76, 0.02), Vector3(0.6, 1.4, 0.6))
			part(body, sphere(0.05, 6), toon(Color("2b2a33")), Vector3(-0.11, 0.5, -0.32))
			part(body, sphere(0.05, 6), toon(Color("2b2a33")), Vector3(0.11, 0.5, -0.32))
			var pm := PrismMesh.new(); pm.size = Vector3(0.2, 0.24, 0.2)
			for i in 3:
				var a := TAU * i / 3.0
				part(body, pm, toon(Color("fff4c0"), false, 1.4), Vector3(cos(a) * 0.55, 0.9, sin(a) * 0.55))
		"sentinel":
			var stone := toon(Color("6a7080")); mats.append(stone)
			var plinth := Assets.prop("halloween/pillar", 0.95, true, {"bright": 1.15, "cache": false}) if Assets.on() else null
			if plinth:
				# a carved stone plinth (pack model) holding the crystal
				plinth.scale = Vector3(1.45, 1.0, 1.45)
				body.add_child(plinth)
				mats.append_array(plinth.get_meta("mats"))
			else:
				part(body, cyl(0.42, 0.55, 0.35, 8), stone, Vector3(0, 0.18, 0))
				part(body, cyl(0.22, 0.32, 0.6, 8), stone, Vector3(0, 0.6, 0))
			var cr := Node3D.new(); cr.name = "Crystal"; cr.position = Vector3(0, 1.25, 0); body.add_child(cr)
			var pm := PrismMesh.new(); pm.size = Vector3(0.42, 0.5, 0.42)
			var cm := toon(md["color"], false, 0.9); mats.append(cm)
			part(cr, pm, cm, Vector3(0, 0.25, 0))
			part(cr, pm, cm, Vector3(0, -0.25, 0), Vector3.ONE, Vector3(PI, 0, 0))
			part(cr, sphere(0.08, 8), m_eye, Vector3(0, 0, -0.2))
		"brute", "warden":
			# a hulking brute: barrel chest, hunched head with tusks, arms and legs on joints so it can swing
			var torso := Node3D.new(); torso.name = "Torso"; torso.position = Vector3(0, 0.62, 0); body.add_child(torso)
			part(torso, sphere(0.6, 14), m, Vector3(0, 0.38, 0), Vector3(1.05, 0.85, 0.85))
			part(torso, sphere(0.42, 12), toon(Color(md["color"]).lightened(0.25)), Vector3(0, 0.28, -0.22), Vector3(1.0, 0.85, 0.6))
			part(torso, sphere(0.34, 10), m_dark, Vector3(-0.48, 0.66, 0.0), Vector3(1.1, 0.8, 1.0))
			part(torso, sphere(0.34, 10), m_dark, Vector3(0.48, 0.66, 0.0), Vector3(1.1, 0.8, 1.0))
			var hd := Node3D.new(); hd.name = "Head"; hd.position = Vector3(0, 0.82, -0.28); torso.add_child(hd)
			part(hd, box(0.5, 0.38, 0.42), m_dark, Vector3(0, 0.05, 0))
			part(hd, box(0.56, 0.1, 0.2), m_dark, Vector3(0, 0.2, -0.16), Vector3.ONE, Vector3(0.25, 0, 0))
			part(hd, sphere(0.055, 6), m_eye, Vector3(-0.12, 0.1, -0.22))
			part(hd, sphere(0.055, 6), m_eye, Vector3(0.12, 0.1, -0.22))
			var tusk := toon(Color("efe6cf")); mats.append(tusk)
			part(hd, cyl(0.0, 0.05, 0.18, 6), tusk, Vector3(-0.15, -0.1, -0.22), Vector3.ONE, Vector3(-0.3, 0, 0.25))
			part(hd, cyl(0.0, 0.05, 0.18, 6), tusk, Vector3(0.15, -0.1, -0.22), Vector3.ONE, Vector3(-0.3, 0, -0.25))
			for sx in [-1.0, 1.0]:
				var arm := Node3D.new(); arm.name = "ArmL" if sx < 0 else "ArmR"
				arm.position = Vector3(0.62 * sx, 0.62, -0.02); torso.add_child(arm)
				part(arm, box(0.3, 0.62, 0.3), m_dark, Vector3(0.04 * sx, -0.3, 0))
				part(arm, sphere(0.24, 10), m, Vector3(0.05 * sx, -0.7, -0.02), Vector3(1.0, 0.9, 1.0))
				var leg := Node3D.new(); leg.name = "LegL" if sx < 0 else "LegR"
				leg.position = Vector3(0.26 * sx, 0.58, 0); body.add_child(leg)
				part(leg, box(0.3, 0.5, 0.34), m_dark, Vector3(0, -0.28, 0))
				part(leg, box(0.34, 0.12, 0.42), m_dark, Vector3(0, -0.52, -0.04))
			if kind == "warden":
				root.scale = Vector3.ONE * 1.5
				var gold := toon(Color("f2c84a"), true, 0.5); mats.append(gold)
				for sx in [-1.0, 0.0, 1.0]:
					part(hd, cyl(0.0, 0.08, 0.3, 6), gold, Vector3(0.15 * sx, 0.42, 0.02))
				part(hd, box(0.56, 0.08, 0.46), gold, Vector3(0, 0.28, 0.02))
				part(torso, sphere(0.12, 8), toon(Color("c9a0ff"), false, 1.2), Vector3(0, 0.4, -0.52))
	root.set_meta("mats", mats)
	return root

# ---------------------------------------------------------------- props
## A rough stone: a faceted lump, sometimes a smaller one beside it, often a cap of moss.
static func rock(rng: RandomNumberGenerator, s: float, moss := Color("6f9a4a")) -> Node3D:
	var root := Node3D.new()
	var g := Color("8d8a86").lerp(Color("6f6a73"), rng.randf())
	var m := toon(g, true)
	m.set_shader_parameter("rim_amount", 0.5)
	var sm := SphereMesh.new(); sm.radius = 0.5; sm.height = 1.0; sm.radial_segments = 7; sm.rings = 4
	var ys := s * rng.randf_range(0.8, 1.3)
	part(root, sm, m, Vector3(0, 0.42 * ys, 0), Vector3(s * rng.randf_range(0.9, 1.2), ys, s * rng.randf_range(0.9, 1.2)), Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2)))
	if rng.randf() < 0.6:
		part(root, sm, m, Vector3(rng.randf_range(-0.35, 0.35) * s, 0.2 * s, rng.randf_range(-0.35, 0.35) * s), Vector3.ONE * s * rng.randf_range(0.4, 0.6), Vector3(0, rng.randf() * TAU, 0))
	if rng.randf() < 0.65:
		var mm := SphereMesh.new(); mm.radius = 0.5; mm.height = 0.5; mm.radial_segments = 8; mm.rings = 3; mm.is_hemisphere = true
		part(root, mm, toon(moss.darkened(rng.randf_range(0.0, 0.2)), false), Vector3(0, 0.78 * ys, 0), Vector3(s * 0.8, ys * 0.35, s * 0.8))
	return root

## Trees in three styles: "round" (layered leafy canopy), "pine" (tiers of needles) and
## "blossom" (pale pink canopy). Leaf colour comes from the biome; each canopy has a darker
## underside and a lighter top so it reads as a volume from above.
static func tree(rng: RandomNumberGenerator, leaf: Color, style := "round") -> Node3D:
	var root := Node3D.new()
	var bark := Color("6b4a35").lerp(Color("4e3a30"), rng.randf())
	var mt := toon(bark)
	var h := rng.randf_range(1.7, 2.5)
	var lean := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
	part(root, cyl(0.09, 0.16, h * 0.62), mt, Vector3(0, h * 0.31, 0), Vector3.ONE, lean)
	for k in 3:
		var a := TAU * k / 3.0 + rng.randf()
		part(root, cyl(0.02, 0.08, 0.36, 6), mt, Vector3(cos(a) * 0.14, 0.08, sin(a) * 0.14), Vector3.ONE, Vector3(sin(a) * 1.1, 0, -cos(a) * 1.1))
	var top := Vector3(lean.z * h * 0.6, h * 0.62, -lean.x * h * 0.6)
	match style:
		"pine":
			var c0 := leaf.lerp(Color("2f5a3a"), 0.45)
			var tiers := 4
			for k in tiers:
				var t := float(k) / tiers
				var r := lerpf(0.85, 0.28, t)
				var shade_c := c0.lerp(c0.lightened(0.25), t)
				part(root, cyl(0.0, r, 0.75, 9), toon(shade_c), top + Vector3(0, -0.15 + k * 0.42, 0), Vector3.ONE, Vector3(0, rng.randf() * TAU, 0))
			if leaf.v > 0.75:
				part(root, cyl(0.0, 0.22, 0.3, 9), toon(Color("f4f8ff")), top + Vector3(0, -0.15 + tiers * 0.42 - 0.05, 0))
		_:
			var base := leaf if style != "blossom" else Color("ffb3d0").lerp(leaf, 0.15)
			var dark := toon(base.lerp(Color("1f3a2a") if style != "blossom" else Color("c86a9a"), 0.35))
			var mid := toon(base)
			var light := toon(base.lightened(0.2).lerp(Color("fff6c0"), 0.08))
			for m2 in [dark, mid, light]:
				(m2 as ShaderMaterial).set_shader_parameter("rim_amount", 0.6)
			var blobs := rng.randi_range(4, 6)
			part(root, sphere(0.62, 12), dark, top + Vector3(0, 0.25, 0), Vector3(1.25, 0.8, 1.25))
			for k in blobs:
				var a := TAU * k / blobs + rng.randf_range(-0.3, 0.3)
				var rr := rng.randf_range(0.32, 0.46)
				part(root, sphere(rr, 10), mid, top + Vector3(cos(a) * 0.5, 0.42 + rng.randf_range(-0.1, 0.15), sin(a) * 0.5), Vector3.ONE)
			part(root, sphere(0.5, 12), light, top + Vector3(0.08, 0.78, -0.06), Vector3(1.0, 0.8, 1.0))
			if style == "blossom":
				for k in 6:
					part(root, sphere(0.06, 6), toon(Color("fff0f6"), false, 0.4), top + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.5, 1.05), rng.randf_range(-0.6, 0.6)))
	return root

## Meshes for grass tufts and tall grass: a handful of tapered, slightly bent blades. UV.y runs
## from root (0) to tip (1) for the grass shader's colour and sway.
static var _grass_meshes := {}
static func grass_mesh(tall: bool) -> ArrayMesh:
	var key := "tall" if tall else "short"
	if _grass_meshes.has(key):
		return _grass_meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new(); r.seed = 77 if tall else 33
	var blades := 11 if tall else 8
	for b in blades:
		var a := r.randf() * TAU
		var dist := r.randf_range(0.0, 0.34 if tall else 0.17)
		var base := Vector3(cos(a) * dist, 0, sin(a) * dist)
		var hgt := r.randf_range(0.65, 1.05) if tall else r.randf_range(0.13, 0.3)
		var wid := r.randf_range(0.06, 0.09) if tall else r.randf_range(0.03, 0.045)
		# blades lean out from the middle of the tuft, so a tuft reads as a fan, not a post
		var face := a + PI * 0.5 + r.randf_range(-0.5, 0.5)
		var side := Vector3(cos(face), 0, sin(face))
		var bend := Vector3(cos(a), 0, sin(a)) * hgt * r.randf_range(0.2, 0.45)
		var out_n := Vector3(cos(a), 1.6, sin(a)).normalized()
		var segs := 3 if tall else 2
		for k in segs:
			var t0 := float(k) / segs; var t1 := float(k + 1) / segs
			var w0 := wid * (1.0 - t0 * 0.92); var w1 := wid * (1.0 - t1 * 0.92)
			var p0 := base + Vector3(0, hgt * t0, 0) + bend * t0 * t0
			var p1 := base + Vector3(0, hgt * t1, 0) + bend * t1 * t1
			var v := [p0 - side * w0, p0 + side * w0, p1 + side * w1, p1 - side * w1]
			var uv := [Vector2(0, t0), Vector2(1, t0), Vector2(1, t1), Vector2(0, t1)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(out_n)
				st.set_uv(uv[idx])
				st.add_vertex(v[idx])
	var m := st.commit()
	_grass_meshes[key] = m
	return m

## A tiny flower: three petals around a dot, on a short stem (coloured per instance).
static func flower_mesh() -> ArrayMesh:
	if _grass_meshes.has("flower"):
		return _grass_meshes["flower"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := 0.2
	for k in 5:
		var a := TAU * k / 5.0
		var c := Vector3(0, top, 0)
		var p1 := c + Vector3(cos(a - 0.45), 0.02, sin(a - 0.45)) * 0.07
		var p2 := c + Vector3(cos(a), 0.03, sin(a)) * 0.11
		var p3 := c + Vector3(cos(a + 0.45), 0.02, sin(a + 0.45)) * 0.07
		for v in [c, p1, p2, c, p2, p3]:
			st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, 1.0)); st.add_vertex(v)
	var m := st.commit()
	_grass_meshes["flower"] = m
	return m

static var GRASS: Shader = preload("res://shaders/grass.gdshader")
static func grass_material(sway: float, flower := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GRASS
	m.set_shader_parameter("sway", sway)
	if flower:
		m.set_shader_parameter("tip_tint", Color(1.0, 1.0, 1.0))
	return m

const CHEST_COL := [Color("8a5a35"), Color("f2c84a")]    # (wood, trim) of the primitive chest

## The chest (there is one kind, and it is locked: see KeyChest): the sculpted model, the imported
## one (its lid on a hinge), or the primitive one.
static func chest() -> Node3D:
	if Flora.v2():
		return PropSculpt.chest()
	var pk := _pack_chest()
	return pk if pk else chest_prim()

static func _pack_chest() -> Node3D:
	var id := "dungeon/chest"
	var base := Assets.part(id, "chest")
	var lidp := Assets.part(id, "chest_lid")
	if base.is_empty() or lidp.is_empty():
		return null
	var m := Assets.material("dungeon", {"rim": 0.3, "bright": 1.12})
	var root := Node3D.new()
	var body := Node3D.new(); body.name = "Body"; root.add_child(body)
	var sc := 0.62
	# the model's lock faces +z and its hinge is at the back (-z); turned round inside Body so the
	# hinge is at +z like the primitive chest, then Body faces the lock to the camera
	var turn := Node3D.new(); turn.rotation.y = PI; turn.scale = Vector3.ONE * sc; body.add_child(turn)
	part(turn, base[0], m, (base[1] as Transform3D).origin)
	var lid := Node3D.new(); lid.name = "Lid"
	lid.set_meta("hinged", true)
	var hinge: Vector3 = (lidp[1] as Transform3D).origin
	lid.position = Vector3(-hinge.x, hinge.y, -hinge.z) * sc
	lid.scale = Vector3.ONE * sc
	body.add_child(lid)
	part(lid, lidp[0], m, Vector3.ZERO, Vector3.ONE, Vector3(0, PI, 0))
	body.rotation.y = PI
	var beam := part(root, cyl(0.16, 0.3, 6.0, 10), glow_mat(Color(CHEST_COL[1], 0.22)), Vector3(0, 3.0, 0), Vector3.ONE, Vector3.ZERO, "Beacon")
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.set_meta("mats", [m, m])
	return root

## The chest built from primitives (also the base of a deathbox).
static func chest_prim() -> Node3D:
	var root := Node3D.new()
	var mw := toon(CHEST_COL[0]); var mg := toon(CHEST_COL[1], true, 0.5)
	var m_seam := toon(Color(CHEST_COL[0]).darkened(0.35), false)
	var body := Node3D.new(); body.name = "Body"; root.add_child(body)
	# the box: planks, metal corners and a lock plate
	part(body, box(0.8, 0.42, 0.55), mw, Vector3(0, 0.21, 0))
	for k in 2:
		part(body, box(0.81, 0.015, 0.56), m_seam, Vector3(0, 0.14 + k * 0.14, 0))
	for x in [-0.36, 0.36]:
		for z in [-0.25, 0.25]:
			part(body, box(0.1, 0.44, 0.1), mg, Vector3(x, 0.22, z))
	part(body, box(0.84, 0.05, 0.59), mg, Vector3(0, 0.03, 0))
	# the lid hinges at the back; a rounded top with two straps
	var lid := Node3D.new(); lid.name = "Lid"; lid.position = Vector3(0, 0.42, 0.27); body.add_child(lid)
	lid.set_meta("hinged", true)
	part(lid, cyl(0.28, 0.28, 0.8, 14), mw, Vector3(0, 0.0, -0.27), Vector3(0.6, 1.0, 1.0), Vector3(0, 0, PI / 2))
	for x in [-0.27, 0.27]:
		part(lid, cyl(0.29, 0.29, 0.07, 14), mg, Vector3(x, 0.0, -0.27), Vector3(0.6, 1.0, 1.0), Vector3(0, 0, PI / 2))
	part(lid, cyl(0.29, 0.29, 0.04, 14), mg, Vector3(-0.4, 0.0, -0.27), Vector3(0.6, 1.0, 1.0), Vector3(0, 0, PI / 2))
	part(lid, cyl(0.29, 0.29, 0.04, 14), mg, Vector3(0.4, 0.0, -0.27), Vector3(0.6, 1.0, 1.0), Vector3(0, 0, PI / 2))
	part(body, box(0.16, 0.2, 0.05), mg, Vector3(0, 0.4, -0.29))
	part(body, sphere(0.035, 6), toon(Color("2b2a33"), false), Vector3(0, 0.38, -0.32))
	body.scale = Vector3.ONE * 1.18
	body.rotation.y = PI   # lock facing the camera
	# a light pillar you can see from other islands
	var beam := part(root, cyl(0.16, 0.3, 6.0, 10), glow_mat(Color(CHEST_COL[1], 0.22)), Vector3(0, 3.0, 0), Vector3.ONE, Vector3.ZERO, "Beacon")
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.set_meta("mats", [mw, mg])
	return root

## A dead hunter's deathbox: a squat crate with a glow in its value colour.
static func deathbox(col: Color) -> Node3D:
	var root := PropSculpt.chest() if Flora.v2() else chest_prim()
	var own := root.get_node_or_null("Beacon")
	if own:
		root.remove_child(own); own.free()      # a deathbox glows in its value colour, not a chest's
	var g := Node3D.new(); g.name = "Glow"; root.add_child(g)
	var beam := part(g, cyl(0.12, 0.24, 5.0, 10), glow_mat(Color(col, 0.3)), Vector3(0, 2.5, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := MeshInstance3D.new(); ring.mesh = flat_quad(1.6)
	ring.material_override = ring_mat(col, 0.1); ring.position.y = 0.04
	g.add_child(ring)
	# the soul: a little wisp bobbing over the box while a teammate can still bring them back
	var soul := Node3D.new(); soul.name = "Soul"; soul.position = Vector3(0, 1.3, 0); root.add_child(soul)
	part(soul, sphere(0.16, 10), glow_mat(Color(0.85, 1.0, 0.95, 0.9)), Vector3.ZERO)
	part(soul, sphere(0.28, 10), glow_mat(Color(0.6, 1.0, 0.85, 0.25)), Vector3.ZERO)
	PropAnim.on(soul, 1.4, 0.12)
	((root.get_meta("mats") as Array)[0] as ShaderMaterial).set_shader_parameter("albedo", Color("5a5560"))
	((root.get_meta("mats") as Array)[1] as ShaderMaterial).set_shader_parameter("albedo", col.darkened(0.2))
	return root

# ------------------------------------------------------------------ world legend: interactable icons
## Everything you can use out in the world (not loot, not breakables) wears a small floating badge
## with a symbol, in one colour per kind, so it reads at a glance from the match camera:
## shrines (blessing, teal), exits (hatches violet, uplinks cyan), rift keys (violet, like the
## hatch they open), eggs (warm gold), revive beacons (mint). Loot is gold / rarity coloured with
## a pillar and a ground pool; breakables are matte with no glow; decor stays low-contrast.
const ICON_COLS := {"bless": Color("5fd0b0"), "hatch": Color("b98aff"), "key": Color("b98aff"), "ckey": Color("f2c84a"),
	"egg": Color("ffc04a"), "revive": Color("6ae8a0"), "dock": Color("ffb84a")}
static var _icon_tex := {}

## Is the point (x, y) (-1..1, y up) inside the white symbol for this kind?
static func _icon_sym(kind: String, x: float, y: float) -> bool:
	match kind:
		"bless":     # a four-point sparkle
			return pow(absf(x), 0.5) + pow(absf(y + 0.02), 0.5) < 0.86
		"hatch", "dock":   # an arrow up and out
			if y >= -0.02 and y <= 0.56 and absf(x) < 0.48 * (0.56 - y) / 0.58: return true
			return absf(x) < 0.15 and y > -0.56 and y < 0.0
		"key", "ckey":
			var d := Vector2(x, y - 0.24).length()
			if d < 0.27 and d > 0.12: return true
			if absf(x) < 0.075 and y < 0.0 and y > -0.6: return true
			if x > 0.0 and x < 0.26 and ((y > -0.58 and y < -0.47) or (y > -0.38 and y < -0.28)): return true
			return false
		"egg":
			var ry := 0.5 if y > -0.08 else 0.4
			var rx := 0.36 - 0.1 * clampf((y + 0.08) / 0.5, 0.0, 1.0)
			return pow(x / rx, 2.0) + pow((y + 0.08) / ry, 2.0) < 1.0
		"revive":   # a plus
			return (absf(x) < 0.15 and absf(y) < 0.48) or (absf(y) < 0.15 and absf(x) < 0.48)
	return false

static func icon_texture(kind: String) -> ImageTexture:
	if _icon_tex.has(kind):
		return _icon_tex[kind]
	var N := 96
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var col: Color = ICON_COLS.get(kind, Color.WHITE)
	var dark := col.darkened(0.7).lerp(Color("1a1626"), 0.4)
	for py in N:
		for px in N:
			var acc := Color(0, 0, 0, 0)
			for sy in 2:
				for sx in 2:
					var x := ((px + 0.25 + sx * 0.5) / N) * 2.0 - 1.0
					var y := 1.0 - ((py + 0.25 + sy * 0.5) / N) * 2.0
					# a diamond-ish rounded badge: a dark rim, the colour inside lighter at the top
					var r := pow(pow(absf(x), 1.6) + pow(absf(y), 1.6), 1.0 / 1.6)
					var c := Color(0, 0, 0, 0)
					if r < 0.97:
						c = dark
					if r < 0.84:
						c = col.lerp(col.lightened(0.35), clampf(y * 0.5 + 0.5, 0.0, 1.0))
						var sym := _icon_sym(kind, x / 0.78, y / 0.78)
						# a dark edge round the symbol so it pops on the colour
						var edge := false
						if not sym:
							for o in [Vector2(0.06, 0), Vector2(-0.06, 0), Vector2(0, 0.06), Vector2(0, -0.06)]:
								if _icon_sym(kind, (x + o.x) / 0.78, (y + o.y) / 0.78): edge = true; break
						if sym: c = Color("fffdf6")
						elif edge: c = dark.lerp(col, 0.25)
					acc += c * 0.25
			img.set_pixel(px, py, acc)
	var tex := ImageTexture.create_from_image(img)
	_icon_tex[kind] = tex
	return tex

## A floating badge for an interactable: a billboard that bobs gently above it. Named "Icon".
static func icon_badge(kind: String, height: float, size := 0.8) -> Node3D:
	var holder := Node3D.new(); holder.name = "Icon"; holder.position = Vector3(0, height, 0)
	var sp := Sprite3D.new()
	sp.texture = icon_texture(kind)
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.shaded = false
	sp.double_sided = true
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.pixel_size = size / 96.0
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(sp)
	PropAnim.on(holder, 0.0, 0.07, 2.2)
	return holder

## A revive beacon: a stone pylon with a green crystal. Stand on it with a dead teammate waiting
## and it brings them back.
static func revive_beacon() -> Node3D:
	var root := Node3D.new()
	var stone := toon(Color("8f9aa0"))
	var glow := Color("8fffc0")
	part(root, cyl(1.2, 1.3, 0.16, 8), stone, Vector3(0, 0.08, 0))
	part(root, cyl(0.9, 0.96, 0.12, 8), toon(Color("b8c2c6")), Vector3(0, 0.22, 0))
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		part(root, box(0.22, 1.5, 0.22), stone, Vector3(cos(a) * 1.0, 0.75, sin(a) * 1.0), Vector3.ONE, Vector3(0, -a, 0))
		part(root, box(0.05, 0.9, 0.02), toon(glow, false, 0.9), Vector3(cos(a) * 0.88, 0.85, sin(a) * 0.88), Vector3.ONE, Vector3(0, -a, 0))
	var g := Node3D.new(); g.name = "Glow"; root.add_child(g)
	var cr := Node3D.new(); cr.position = Vector3(0, 1.7, 0); g.add_child(cr)
	var pm := PrismMesh.new(); pm.size = Vector3(0.5, 0.7, 0.5)
	var cm := toon(glow.darkened(0.1), true, 0.7)
	part(cr, pm, cm, Vector3(0, 0.35, 0))
	part(cr, pm, cm, Vector3(0, -0.35, 0), Vector3.ONE, Vector3(PI, 0, 0))
	PropAnim.on(cr, 0.7, 0.1)
	var beam := part(g, cyl(0.2, 0.4, 12.0, 10), glow_mat(Color(glow, 0.2)), Vector3(0, 6.0, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := MeshInstance3D.new(); ring.name = "Ring"; ring.mesh = flat_quad(4.6)
	ring.material_override = ring_mat(glow, 0.05); ring.position.y = 0.3
	g.add_child(ring)
	g.add_child(icon_badge("revive", 2.75))
	return root

static func shrine() -> Node3D:
	var root := Node3D.new()
	var stone := toon(Color("a9a39a"))
	var stone_l := toon(Color("cfc8bb"))
	var moss := toon(Color("7fa65a"), false)
	var glow := Color("8fe3c8")
	# a two-step hexagonal dais with a carved, glowing inlay
	if Flora.v2():
		# (cut stones laid in two rings, a glowing inlay, a carved round altar)
		ExitModels._stone_ring(root, 1.15, 0.2, 9, Color("a39d92"), 0.62)
		ExitModels._stone_ring(root, 0.84, 0.36, 7, Color("bdb6a8"), 0.0)
		part(root, cyl(0.52, 0.52, 0.025, 24), toon(glow, false, 0.8), Vector3(0, 0.37, 0))
		part(root, lathe(smooth_curve(PackedVector2Array([Vector2(0, 0), Vector2(0.42, 0), Vector2(0.4, 0.06), Vector2(0.33, 0.1), Vector2(0.31, 0.2), Vector2(0.38, 0.25), Vector2(0.36, 0.29), Vector2(0, 0.29)]), 2), 22, "shrine_altar"), stone, Vector3(0, 0.36, 0))
	else:
		part(root, cyl(1.05, 1.15, 0.18, 6), stone, Vector3(0, 0.09, 0))
		part(root, cyl(0.78, 0.86, 0.18, 6), stone_l, Vector3(0, 0.27, 0))
		part(root, cyl(0.5, 0.5, 0.02, 6), toon(glow, false, 0.8), Vector3(0, 0.37, 0))
		part(root, cyl(0.35, 0.42, 0.22, 6), stone, Vector3(0, 0.47, 0))
	# three leaning standing stones with moss on top
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		var at := Vector3(cos(a) * 0.98, 0.0, sin(a) * 0.98)
		var tilt := Vector3(sin(a) * 0.12, -a, -cos(a) * 0.12)
		part(root, box(0.26, 1.0 - i * 0.12, 0.2), stone, at + Vector3(0, 0.5 - i * 0.06, 0), Vector3.ONE, tilt)
		part(root, box(0.28, 0.06, 0.22), moss, at + Vector3(0, 1.0 - i * 0.12, 0), Vector3.ONE, tilt)
		part(root, box(0.04, 0.3, 0.01), toon(glow, false, 0.9), at + Vector3(0, 0.55, 0) - Vector3(cos(a), 0, sin(a)) * 0.105, Vector3.ONE, tilt)
	# the healing crystal floats and turns above the dais
	var cr := Node3D.new(); cr.name = "Crystal"; cr.position = Vector3(0, 1.45, 0); root.add_child(cr)
	var pm := PrismMesh.new(); pm.size = Vector3(0.42, 0.62, 0.42)
	var cm := toon(glow.darkened(0.15), true, 0.55)
	if Flora.v2():
		cm.set_shader_parameter("gloss", 0.7)
		part(cr, crystal(0.22, 0.8, 6), cm, Vector3(0, 0.12, 0))
		part(cr, crystal(0.22, 0.36, 6), cm, Vector3(0, -0.36, 0), Vector3.ONE, Vector3(PI, 0, 0))
		for i in 3:
			var a2 := TAU * i / 3.0
			part(cr, crystal(0.07, 0.24, 5), cm, Vector3(cos(a2) * 0.45, -0.1, sin(a2) * 0.45), Vector3.ONE, Vector3(0.3, a2, 0.25))
	else:
		part(cr, pm, cm, Vector3(0, 0.31, 0))
		part(cr, pm, cm, Vector3(0, -0.31, 0), Vector3.ONE, Vector3(PI, 0, 0))
		for i in 3:
			var a2 := TAU * i / 3.0
			part(cr, pm, cm, Vector3(cos(a2) * 0.42, -0.1, sin(a2) * 0.42), Vector3.ONE * 0.3)
	PropAnim.on(cr, 0.9, 0.08)
	cr.add_child(icon_badge("bless", 1.05))     # hidden with the crystal once the shrine is used
	var base := MeshInstance3D.new(); base.name = "Ring"; base.mesh = flat_quad(3.0)
	base.material_override = ring_mat(glow, 0.06); base.position.y = 0.04
	root.add_child(base)
	Flora.paint_set_piece(root)
	return root

static func nest() -> Node3D:
	var root := Node3D.new()
	var twig := toon(Color("8a6a45"))
	var t := TorusMesh.new(); t.inner_radius = 0.55; t.outer_radius = 0.95; t.rings = 16; t.ring_segments = 6
	part(root, t, twig, Vector3(0, 0.15, 0), Vector3(1, 0.7, 1))
	part(root, cyl(0.6, 0.6, 0.06, 14), toon(Color("c9a77a")), Vector3(0, 0.1, 0))
	var cols := [Color("ffe8c4"), Color("cfe8ff"), Color("ffd0dc")]
	for i in 3:
		var a := TAU * i / 3.0
		part(root, sphere(0.16, 10), toon(cols[i]), Vector3(cos(a) * 0.25, 0.28, sin(a) * 0.25), Vector3(1, 1.25, 1))
	return root

const EXTRACT_R := 2.6
static func portal(c: Color) -> Node3D:
	var root := Node3D.new()
	var t := TorusMesh.new(); t.inner_radius = 0.95; t.outer_radius = 1.2; t.rings = 24; t.ring_segments = 8
	var mr := toon(Color("6a6f80"), true)
	var ring := part(root, t, mr, Vector3(0, 1.25, 0), Vector3.ONE, Vector3(PI / 2, 0, 0), "Ring")
	# runes around the ring that light up, and a pair of stone feet
	for i in 8:
		var a := TAU * i / 8.0
		part(ring, box(0.12, 0.3, 0.14), toon(c, false, 0.9), Vector3(cos(a) * 1.08, 0.0, sin(a) * 1.08), Vector3.ONE, Vector3(0, -a, 0))
	for sx in [-1.0, 1.0]:
		part(root, box(0.42, 0.34, 0.5), toon(Color("585c6a")), Vector3(0.95 * sx, 0.17, 0))
		part(root, box(0.3, 0.06, 0.38), toon(Color("7fa65a"), false), Vector3(0.95 * sx, 0.36, 0))
	var disc := part(root, cyl(1.0, 1.0, 0.02, 24), glow_mat(c), Vector3(0, 1.25, 0), Vector3.ONE, Vector3(PI / 2, 0, 0), "Disc")
	disc.visible = false
	var base := MeshInstance3D.new(); base.name = "Base"; base.mesh = flat_quad(3.2)
	base.material_override = ring_mat(c, 0.1); base.position.y = 0.05; root.add_child(base)
	# the extraction circle: dim until you stand in it, then it fills around as you extract
	var zone := MeshInstance3D.new(); zone.name = "Zone"; zone.mesh = flat_quad(EXTRACT_R * 2.0)
	zone.material_override = ring_mat(Color(c, 0.35), 0.035); zone.position.y = 0.06; root.add_child(zone)
	var zf := MeshInstance3D.new(); zf.name = "ZoneFill"; zf.mesh = flat_quad(EXTRACT_R * 2.0)
	var zm := ring_mat(Color(c.lightened(0.35), 0.95), 0.07)
	zm.set_shader_parameter("arc", 0.0)
	zf.material_override = zm; zf.position.y = 0.07; root.add_child(zf)
	var beam := CPUParticles3D.new(); beam.name = "Beam"
	beam.amount = 40; beam.lifetime = 1.6; beam.emitting = false
	var bm := SphereMesh.new(); bm.radius = 0.07; bm.height = 0.14; bm.radial_segments = 6; bm.rings = 3
	var pmat := StandardMaterial3D.new(); pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; pmat.albedo_color = c.lightened(0.3)
	bm.material = pmat
	beam.mesh = bm
	beam.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	beam.emission_ring_axis = Vector3.UP; beam.emission_ring_radius = 1.1; beam.emission_ring_inner_radius = 0.6; beam.emission_ring_height = 0.1
	beam.direction = Vector3.UP; beam.spread = 8.0; beam.gravity = Vector3(0, 2.5, 0)
	beam.initial_velocity_min = 1.0; beam.initial_velocity_max = 2.5
	beam.position = Vector3(0, 0.1, 0)
	root.add_child(beam)
	return root

static func jump_pad(c: Color) -> Node3D:
	var root := Node3D.new()
	part(root, cyl(0.7, 0.8, 0.14, 20), toon(Color("3f4456")), Vector3(0, 0.07, 0))
	var top := part(root, cyl(0.55, 0.55, 0.02, 20), toon(c.darkened(0.25), false, 0.45), Vector3(0, 0.15, 0), Vector3.ONE, Vector3.ZERO, "Top")
	for i in 3:
		part(root, box(0.3, 0.03, 0.08), toon(Color("e8fff6"), false, 0.6), Vector3(0, 0.18, 0.2 - i * 0.2), Vector3.ONE, Vector3(0, 0, 0), "Chev%d" % i)
	return root

static func gem() -> Node3D:
	var root := Node3D.new()
	var p := PrismMesh.new(); p.size = Vector3(0.28, 0.3, 0.28)
	var m := toon(Color("7ef0d0"), false, 0.7)
	part(root, p, m, Vector3(0, 0.15, 0))
	part(root, p, m, Vector3(0, -0.15, 0), Vector3.ONE, Vector3(PI, 0, 0))
	return root

static func armor_shard() -> Node3D:
	var root := Node3D.new()
	var pm := PrismMesh.new(); pm.size = Vector3(0.22, 0.34, 0.08)
	var m := toon(Color("7ac8ff"), false, 0.8)
	part(root, pm, m, Vector3(0, 0.2, 0))
	part(root, pm, m, Vector3(0, 0.05, 0), Vector3(0.7, 0.7, 1), Vector3(PI, 0, 0))
	return root

static func tonic() -> Node3D:
	var root := Node3D.new()
	part(root, sphere(0.16, 12), toon(Color("8ff0a0"), false, 0.6), Vector3(0, 0.16, 0))
	part(root, cyl(0.05, 0.06, 0.14, 8), toon(Color("e6f2ea")), Vector3(0, 0.34, 0))
	part(root, cyl(0.065, 0.065, 0.05, 8), toon(Color("8b6d52")), Vector3(0, 0.43, 0))
	return root

static func seed_bag(c: Color) -> Node3D:
	var root := Node3D.new()
	part(root, sphere(0.2), toon(Color("c8a26a")), Vector3(0, 0.2, 0), Vector3(1, 1.1, 1))
	part(root, sphere(0.09), toon(c, false, 0.4), Vector3(0, 0.42, 0))
	return root

# ---------------------------------------------------------------- home
static func house() -> Node3D:
	var root := Node3D.new()
	var wall := toon(Color("efe2c8")); var roof := toon(Color("b4553f")); var wood := toon(Color("7a5236"))
	var glass := toon(Color("ffd98a"), false, 0.8)
	part(root, box(4.2, 2.2, 3.2), wall, Vector3(0, 1.1, 0))
	var pr := PrismMesh.new(); pr.size = Vector3(4.8, 1.6, 3.6)
	part(root, pr, roof, Vector3(0, 3.0, 0))
	part(root, box(0.9, 1.5, 0.1), wood, Vector3(0, 0.75, 1.62))
	part(root, box(0.8, 0.7, 0.08), glass, Vector3(-1.3, 1.3, 1.62))
	part(root, box(0.8, 0.7, 0.08), glass, Vector3(1.3, 1.3, 1.62))
	part(root, box(0.5, 1.2, 0.5), toon(Color("8a8078")), Vector3(1.3, 3.4, -0.6))
	part(root, box(4.4, 0.25, 3.4), wood, Vector3(0, 0.12, 0))
	return root

static func plot() -> Node3D:
	var root := Node3D.new()
	var soil := toon(Color("6b4a33")); var dark := toon(Color("4e3424"))
	part(root, box(1.7, 0.2, 1.7), soil, Vector3(0, 0.1, 0))
	for i in 3:
		part(root, box(1.5, 0.05, 0.14), dark, Vector3(0, 0.21, -0.5 + i * 0.5))
	# watered soil: darker and a little shiny
	var wet := part(root, box(1.66, 0.02, 1.66), toon(Color("3a2618"), false, 0.25), Vector3(0, 0.205, 0), Vector3.ONE, Vector3.ZERO, "Wet")
	wet.visible = false
	var crop := Node3D.new(); crop.name = "Crop"; root.add_child(crop)
	return root

static func crop(stage: int, grow: int, col: Color) -> Node3D:
	var root := Node3D.new()
	var leaf := toon(Color("5aa04a"))
	var k := clampf(float(stage) / float(grow), 0.0, 1.0)
	for i in 3:
		var x := -0.5 + i * 0.5
		if stage <= 0:
			part(root, sphere(0.06, 6), toon(Color("8a6a45")), Vector3(x, 0.25, 0))
			continue
		var hgt := 0.15 + k * 0.45
		part(root, cyl(0.03, 0.04, hgt, 6), leaf, Vector3(x, 0.2 + hgt * 0.5, 0))
		part(root, sphere(0.12 + k * 0.12, 8), leaf, Vector3(x, 0.22 + hgt, 0), Vector3(1.2, 0.6, 1.2))
		if stage >= grow:
			part(root, sphere(0.13, 10), toon(col, true, 0.25), Vector3(x + 0.08, 0.3 + hgt, 0.08))
	return root

static func cauldron() -> Node3D:
	var root := Node3D.new()
	var iron := toon(Color("3a3a44"))
	part(root, sphere(0.6), iron, Vector3(0, 0.55, 0), Vector3(1, 0.8, 1))
	var t := TorusMesh.new(); t.inner_radius = 0.45; t.outer_radius = 0.58
	part(root, t, iron, Vector3(0, 0.9, 0))
	part(root, cyl(0.47, 0.47, 0.04, 20), toon(Color("7fe0a0"), false, 0.6), Vector3(0, 0.9, 0))
	for i in 3:
		var a := i * TAU / 3.0
		part(root, cyl(0.05, 0.05, 0.4), iron, Vector3(cos(a) * 0.4, 0.15, sin(a) * 0.4))
	part(root, box(0.5, 0.15, 0.5), toon(Color("ff9a4a"), false, 1.0), Vector3(0, 0.08, 0))
	return root

static func stall() -> Node3D:
	var root := Node3D.new()
	var wood := toon(Color("8a5a35"))
	part(root, box(2.2, 0.9, 0.9), wood, Vector3(0, 0.45, 0))
	for x in [-1.0, 1.0]:
		part(root, cyl(0.06, 0.06, 2.0), wood, Vector3(x, 1.0, -0.35))
		part(root, cyl(0.06, 0.06, 2.0), wood, Vector3(x, 1.0, 0.35))
	for i in 4:
		part(root, box(0.56, 0.08, 1.2), toon(Color("e0607e") if i % 2 == 0 else Color("f3eee2")), Vector3(-0.84 + i * 0.56, 2.05, 0), Vector3.ONE, Vector3(0.25, 0, 0))
	for i in 3:
		part(root, sphere(0.14), toon([Color("ff6a4a"), Color("5ab8f0"), Color("f2c84a")][i]), Vector3(-0.6 + i * 0.6, 1.0, 0))
	return root

static func fence(length: float) -> Node3D:
	var root := Node3D.new()
	var wood := toon(Color("a07a52"))
	var posts := maxi(2, int(length / 1.0) + 1)
	for i in posts:
		var x := -length * 0.5 + length * float(i) / float(posts - 1)
		part(root, box(0.12, 0.7, 0.12), wood, Vector3(x, 0.35, 0))
	part(root, box(length, 0.08, 0.06), wood, Vector3(0, 0.5, 0))
	part(root, box(length, 0.08, 0.06), wood, Vector3(0, 0.25, 0))
	return root

static func lamp() -> Node3D:
	var root := Node3D.new()
	var iron := toon(Color("3a3a44"))
	part(root, cyl(0.06, 0.08, 1.9), iron, Vector3(0, 0.95, 0))
	part(root, box(0.3, 0.06, 0.3), iron, Vector3(0, 1.95, 0))
	part(root, box(0.22, 0.28, 0.22), toon(Color("ffd98a"), false, 1.4), Vector3(0, 2.12, 0))
	part(root, cyl(0.0, 0.2, 0.18), iron, Vector3(0, 2.34, 0))
	var l := OmniLight3D.new()
	l.light_color = Color("ffd9a8"); l.light_energy = 0.55; l.omni_range = 4.0
	l.position = Vector3(0, 2.1, 0)
	root.add_child(l)
	return root

static func pond(rx: float, rz: float) -> Node3D:
	var root := Node3D.new()
	var rim := toon(Color("8d8a86"))
	part(root, cyl(1.0, 1.0, 0.06, 28), toon(Color("3d78a8"), false, 0.12), Vector3(0, 0.03, 0), Vector3(rx, 1, rz))
	for i in 14:
		var a := TAU * i / 14.0
		part(root, sphere(0.2, 6), rim, Vector3(cos(a) * rx, 0.06, sin(a) * rz), Vector3(1.2, 0.6, 1.0))
	for i in 3:
		var a := TAU * i / 3.0 + 0.4
		part(root, cyl(0.18, 0.18, 0.02, 10), toon(Color("5fae4f"), false), Vector3(cos(a) * rx * 0.5, 0.08, sin(a) * rz * 0.45))
	return root

static func flower_bed(rng: RandomNumberGenerator, n := 7) -> Node3D:
	var root := Node3D.new()
	var cols := [Color("ff8fb0"), Color("ffd35a"), Color("b48cf2"), Color("ff7a5a"), Color("ffffff")]
	for i in n:
		var p := Vector3(rng.randf_range(-0.7, 0.7), 0, rng.randf_range(-0.35, 0.35))
		part(root, cyl(0.02, 0.02, 0.3, 4), toon(Color("4f8a3e"), false), p + Vector3(0, 0.15, 0))
		part(root, sphere(0.08, 6), toon(cols[rng.randi_range(0, cols.size() - 1)], false, 0.2), p + Vector3(0, 0.32, 0))
	return root

static func kin_bed(c: Color) -> Node3D:
	var root := Node3D.new()
	part(root, cyl(0.42, 0.46, 0.14, 16), toon(c.darkened(0.25)), Vector3(0, 0.07, 0))
	part(root, cyl(0.32, 0.32, 0.06, 16), toon(c.lightened(0.25)), Vector3(0, 0.14, 0))
	return root

static func signpost(text_lines: Array) -> Node3D:
	var root := Node3D.new()
	var wood := toon(Color("8a5a35"))
	part(root, box(0.12, 1.4, 0.12), wood, Vector3(0, 0.7, 0))
	part(root, box(1.1, 0.4, 0.08), toon(Color("c49a6a")), Vector3(0, 1.25, 0.05))
	var l := Label3D.new()
	l.text = "\n".join(text_lines)
	l.font = load("res://fonts/LilitaOne-Regular.ttf")
	l.font_size = 40; l.pixel_size = 0.005; l.modulate = Color("3a2a1a"); l.outline_size = 0
	l.position = Vector3(0, 1.25, 0.1)
	root.add_child(l)
	return root

# ---------------------------------------------------------------- home buildings
static func building(id: String) -> Node3D:
	if id in ["armory", "shrine"]:
		return EconModels.building(id)
	var root := Node3D.new()
	var body := Node3D.new(); body.name = "Body"; root.add_child(body)
	var wood := toon(Color("7a5236")); var stone := toon(Color("9a948c")); var dark := toon(Color("4a4550"))
	var glass := toon(Color("ffd98a"), false, 0.8)
	match id:
		"workshop":
			part(body, box(3.0, 1.9, 2.4), toon(Color("d9c3a0")), Vector3(0, 0.95, -0.1))
			var pr := PrismMesh.new(); pr.size = Vector3(3.5, 1.2, 2.8)
			part(body, pr, toon(Color("4f6a8a")), Vector3(0, 2.5, -0.1))
			part(body, box(1.3, 1.3, 0.08), dark, Vector3(-0.5, 0.65, 1.12))
			part(body, box(0.6, 0.5, 0.08), glass, Vector3(0.85, 1.2, 1.12))
			part(body, box(0.4, 1.4, 0.4), stone, Vector3(1.1, 2.7, -0.6))
			# anvil and a glider hung up to dry
			part(body, box(0.5, 0.35, 0.3), dark, Vector3(1.0, 0.18, 1.6))
			part(body, box(0.7, 0.12, 0.3), dark, Vector3(1.0, 0.42, 1.6))
			part(body, box(1.6, 0.04, 0.5), toon(Color("f3eee2")), Vector3(-0.3, 1.75, 1.2), Vector3.ONE, Vector3(-0.4, 0, 0))
			part(body, box(0.3, 0.05, 0.52), toon(Color("ff9a4a")), Vector3(-0.95, 1.76, 1.2), Vector3.ONE, Vector3(-0.4, 0, 0))
		"board":
			# a little guild house with a big notice board out front and pennants on the roof
			part(body, box(2.6, 1.6, 1.6), toon(Color("e8d2b0")), Vector3(0, 0.8, -0.2))
			var pr0 := PrismMesh.new(); pr0.size = Vector3(3.0, 1.1, 2.0)
			part(body, pr0, toon(Color("b84a3a")), Vector3(0, 2.15, -0.2))
			part(body, box(0.8, 1.2, 0.08), dark, Vector3(-0.6, 0.6, 0.62))
			part(body, box(1.3, 0.9, 0.08), wood, Vector3(0.65, 1.05, 0.66))
			for k in 4:
				var pc: Color = [Color("fff6c0"), Color("cfeaff"), Color("ffd6e0"), Color("e0ffd6")][k]
				part(body, box(0.26, 0.3, 0.02), toon(pc, false), Vector3(0.38 + (k % 2) * 0.55, 1.22 - (k / 2) * 0.38, 0.71), Vector3.ONE, Vector3(0, 0, randf_range(-0.12, 0.12)))
			part(body, cyl(0.03, 0.03, 1.0, 6), wood, Vector3(0.65, 0.3, 0.66))
			for k in 5:
				part(body, PrismMesh.new(), toon([Color("ffd23f"), Color("5ab0f0"), Color("e0607e"), Color("8fd16a"), Color("b48cf2")][k], false), Vector3(-1.2 + k * 0.6, 2.75 - absf(k - 2) * 0.12, -0.2), Vector3(0.22, 0.28, 0.04), Vector3(PI, 0, 0))
			part(body, sphere(0.16, 10), toon(Color("ffd23f"), false, 0.8), Vector3(0, 2.85, -0.2))
		"ransom":
			# Old Pell's Ransom House: a crooked dark-wood shop with a hanging lantern, a kin-shaped
			# sign, and little hutches out front where lost kin wait
			var plum := toon(Color("5a3f5e")); var trim := toon(Color("c9a46a"))
			part(body, box(2.6, 1.7, 1.7), toon(Color("6e5a4a")), Vector3(0, 0.85, -0.2))
			var pr1 := PrismMesh.new(); pr1.size = Vector3(3.0, 1.2, 2.1)
			part(body, pr1, plum, Vector3(0, 2.3, -0.2), Vector3.ONE, Vector3(0, 0, 0.04))
			part(body, box(0.8, 1.2, 0.08), dark, Vector3(0.6, 0.6, 0.66))
			part(body, box(0.5, 0.45, 0.08), toon(Color("ffd58a"), false, 0.8), Vector3(-0.6, 1.15, 0.66))
			part(body, box(2.8, 0.08, 0.5), trim, Vector3(0, 1.72, 0.6))
			# the sign: a round kin face on a post
			part(body, cyl(0.03, 0.03, 0.7, 6), wood, Vector3(-1.45, 1.4, 0.75), Vector3.ONE, Vector3(0, 0, PI / 2))
			part(body, cyl(0.3, 0.3, 0.06, 18), trim, Vector3(-1.75, 1.05, 0.75), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(body, sphere(0.16, 12), toon(Color("ff9a5a")), Vector3(-1.75, 1.05, 0.8), Vector3(1, 1, 0.4))
			for sx in [-1.0, 1.0]:
				part(body, cyl(0.0, 0.06, 0.12, 6), toon(Color("ff9a5a")), Vector3(-1.75 + 0.09 * sx, 1.22, 0.8))
			# lantern
			part(body, cyl(0.01, 0.01, 0.3, 4), dark, Vector3(1.3, 1.6, 0.85))
			part(body, sphere(0.11, 10), toon(Color("ffd25a"), false, 1.2), Vector3(1.3, 1.4, 0.85), Vector3.ONE, Vector3.ZERO, "Lamp")
			# hutches
			for k in 2:
				var hx := -0.5 + k * 1.1
				part(body, box(0.6, 0.45, 0.45), wood, Vector3(hx, 0.22, 1.2))
				for b in 3:
					part(body, box(0.03, 0.4, 0.03), dark, Vector3(hx - 0.2 + b * 0.2, 0.22, 1.43))
				part(body, sphere(0.12, 10), toon([Color("4aa8e8"), Color("b9a6f5")][k]), Vector3(hx, 0.16, 1.22))
		"cottage", "cottage2":
			var wall := Color("f3dcc4") if id == "cottage" else Color("dfe8cf")
			var roof := Color("5a9ab8") if id == "cottage" else Color("c28a3a")
			part(body, box(2.6, 1.5, 2.0), toon(wall), Vector3(0, 0.75, 0))
			var pr := PrismMesh.new(); pr.size = Vector3(3.0, 1.3, 2.4)
			part(body, pr, toon(roof), Vector3(0, 2.15, 0))
			part(body, cyl(0.38, 0.38, 0.08, 16), wood, Vector3(0, 0.38, 1.02), Vector3(1, 1, 1), Vector3(PI / 2, 0, 0))
			part(body, cyl(0.25, 0.25, 0.06, 12), glass, Vector3(0.85, 1.0, 1.02), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(body, cyl(0.25, 0.25, 0.06, 12), glass, Vector3(-0.85, 1.0, 1.02), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(body, box(0.7, 0.16, 0.2), wood, Vector3(0.85, 0.66, 1.1))
			for i in 3:
				part(body, sphere(0.08, 6), toon([Color("ff8fb0"), Color("ffd35a"), Color("b48cf2")][i], false, 0.2), Vector3(0.62 + i * 0.22, 0.8, 1.12))
			part(body, sphere(0.2, 8), toon(Color("ffb3c6"), false, 0.5), Vector3(0, 2.9, 0))
		"greenhouse":
			var frame := toon(Color("f0f0ea"))
			var pane := glow_mat(Color(0.7, 0.95, 1.0, 0.22))
			part(body, box(3.6, 0.2, 2.8), stone, Vector3(0, 0.1, 0))
			part(body, box(3.4, 1.6, 2.6), pane, Vector3(0, 1.0, 0))
			var pr := PrismMesh.new(); pr.size = Vector3(3.5, 1.0, 2.7)
			part(body, pr, pane, Vector3(0, 2.3, 0))
			for x in [-1.7, -0.57, 0.57, 1.7]:
				part(body, box(0.08, 1.7, 0.08), frame, Vector3(x, 1.0, 1.3))
				part(body, box(0.08, 1.7, 0.08), frame, Vector3(x, 1.0, -1.3))
			part(body, box(3.5, 0.08, 0.08), frame, Vector3(0, 1.8, 1.3))
			part(body, box(3.5, 0.08, 0.08), frame, Vector3(0, 1.8, -1.3))
			part(body, box(3.5, 0.08, 0.08), frame, Vector3(0, 2.8, 0))
			for i in 6:
				var px := -1.2 + (i % 3) * 1.2; var pz := -0.6 + (i / 3) * 1.2
				part(body, cyl(0.2, 0.16, 0.3, 8), toon(Color("b4553f")), Vector3(px, 0.35, pz))
				part(body, sphere(0.3, 8), toon(Color("5aa04a")), Vector3(px, 0.75, pz), Vector3(1, 1.2, 1))
		"dojo":
			for side in [[Vector3(0, 0, -1.6), 0.0], [Vector3(0, 0, 1.6), 0.0], [Vector3(-1.9, 0, 0), PI / 2], [Vector3(1.9, 0, 0), PI / 2]]:
				var f := fence(3.2 if side[1] == 0.0 else 3.2)
				f.position = side[0]; f.rotation.y = side[1]
				body.add_child(f)
			part(body, box(3.6, 0.04, 3.0), toon(Color("c9a77a")), Vector3(0, 0.02, 0))
			for x in [-0.9, 0.9]:
				part(body, cyl(0.07, 0.07, 1.3), wood, Vector3(x, 0.65, -0.3))
				part(body, capsule(0.28, 0.8), toon(Color("d8b98a")), Vector3(x, 1.05, -0.3))
				part(body, cyl(0.2, 0.2, 0.04, 14), toon(Color("e0607e")), Vector3(x, 1.15, -0.02), Vector3.ONE, Vector3(PI / 2, 0, 0))
				part(body, cyl(0.08, 0.08, 0.05, 10), toon(Color("f3eee2")), Vector3(x, 1.15, 0.01), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(body, box(1.4, 0.12, 0.4), wood, Vector3(0, 0.4, 1.1))
			part(body, box(0.1, 0.4, 0.3), wood, Vector3(-0.6, 0.2, 1.1))
			part(body, box(0.1, 0.4, 0.3), wood, Vector3(0.6, 0.2, 1.1))
		"vault":
			part(body, box(3.0, 2.0, 2.2), stone, Vector3(0, 1.0, 0))
			part(body, box(3.3, 0.3, 2.5), toon(Color("7a746c")), Vector3(0, 2.15, 0))
			part(body, cyl(0.7, 0.7, 0.12, 24), toon(Color("6a6f7a")), Vector3(0, 0.95, 1.1), Vector3.ONE, Vector3(PI / 2, 0, 0))
			var t := TorusMesh.new(); t.inner_radius = 0.5; t.outer_radius = 0.66
			part(body, t, toon(Color("f2c84a"), true, 0.3), Vector3(0, 0.95, 1.17), Vector3.ONE, Vector3(PI / 2, 0, 0))
			part(body, box(0.5, 0.08, 0.08), toon(Color("f2c84a")), Vector3(0, 0.95, 1.2))
			var g := gem(); g.position = Vector3(0, 2.75, 0); g.scale = Vector3.ONE * 1.8; g.name = "Gem"; body.add_child(g)
		"hall":
			part(body, box(3.2, 0.3, 2.6), toon(Color("e8e2d6")), Vector3(0, 0.15, 0))
			part(body, box(3.0, 0.2, 2.4), toon(Color("d8d0c0")), Vector3(0, 0.38, 0))
			for x in [-1.2, -0.4, 0.4, 1.2]:
				for z in [-0.9, 0.9]:
					part(body, cyl(0.15, 0.17, 1.8, 10), toon(Color("f3eee2")), Vector3(x, 1.38, z))
			part(body, box(3.2, 0.25, 2.6), toon(Color("e8e2d6")), Vector3(0, 2.38, 0))
			var pr := PrismMesh.new(); pr.size = Vector3(3.4, 0.7, 2.8)
			part(body, pr, toon(Color("b4553f")), Vector3(0, 2.85, 0))
			var gold := toon(Color("f2c84a"), true, 0.4)
			part(body, cyl(0.16, 0.08, 0.2, 10), gold, Vector3(0, 0.6, 0))
			part(body, cyl(0.25, 0.12, 0.35, 12), gold, Vector3(0, 0.88, 0))
			part(body, sphere(0.09, 8), gold, Vector3(0.26, 0.95, 0))
			part(body, sphere(0.09, 8), gold, Vector3(-0.26, 0.95, 0))
	return root

## An empty building site: corner stakes, a rope line, a stack of planks and a sign.
static func lot(w: float, d: float, title: String, price: String) -> Node3D:
	var root := Node3D.new()
	var wood := toon(Color("a07a52"))
	var rope := toon(Color("e8d8b0"), false)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		part(root, box(0.1, 0.5, 0.1), wood, Vector3(c.x * w * 0.5, 0.25, c.y * d * 0.5))
	part(root, box(w, 0.03, 0.03), rope, Vector3(0, 0.42, -d * 0.5))
	part(root, box(w, 0.03, 0.03), rope, Vector3(0, 0.42, d * 0.5))
	part(root, box(0.03, 0.03, d), rope, Vector3(-w * 0.5, 0.42, 0))
	part(root, box(0.03, 0.03, d), rope, Vector3(w * 0.5, 0.42, 0))
	for i in 3:
		part(root, box(1.2, 0.1, 0.24), toon(Color("b08a5c").darkened(i * 0.08)), Vector3(-w * 0.18, 0.06 + i * 0.11, -d * 0.15 + i * 0.03), Vector3.ONE, Vector3(0, i * 0.15, 0))
	part(root, box(0.5, 0.4, 0.5), toon(Color("8d8a86")), Vector3(w * 0.22, 0.2, -d * 0.2))
	var s := signpost([title, price])
	s.position = Vector3(0, 0, d * 0.5 + 0.35)
	s.name = "Sign"
	root.add_child(s)
	return root

## One plank of a bridge, roughly a tile deep and two tiles wide.
static func plank(rng: RandomNumberGenerator, width: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = box(width, 0.14, 0.42)
	mi.material_override = toon(Color("a07a52").lerp(Color("7a5a3c"), rng.randf()))
	mi.rotation.y = rng.randf_range(-0.04, 0.04)
	return mi


## The ferry stop at home: a post with a bell and a sign, and a short jetty.
static func ferry_post() -> Node3D:
	var root := Node3D.new()
	var wood := toon(Color("7a5236"))
	part(root, box(0.16, 2.2, 0.16), wood, Vector3(0, 1.1, 0))
	part(root, box(0.9, 0.1, 0.1), wood, Vector3(0.38, 2.1, 0))
	part(root, cyl(0.06, 0.18, 0.26, 12), toon(Color("f2c84a"), true, 0.3), Vector3(0.7, 1.86, 0))
	part(root, box(1.2, 0.36, 0.08), toon(Color("c49a6a")), Vector3(0, 1.3, 0.1))
	var l := Label3D.new(); l.text = "Ferry"; l.font = load("res://fonts/LilitaOne-Regular.ttf")
	l.font_size = 48; l.pixel_size = 0.005; l.modulate = Color("3a2a1a"); l.outline_size = 0; l.position = Vector3(0, 1.3, 0.15)
	root.add_child(l)
	for i in 3:
		part(root, box(1.4, 0.08, 0.36), wood, Vector3(0, 0.04, -0.6 - i * 0.38))
	return root


## Guild landmarks.
static func lighthouse(col: Color) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new(); body.name = "Body"; root.add_child(body)
	var white := toon(Color("f3eee2")); var red := toon(Color("c0443a"))
	part(body, cyl(1.3, 1.5, 0.5, 18), toon(Color("8d8a86")), Vector3(0, 0.25, 0))
	for i in 4:
		part(body, cyl(0.95 - i * 0.12, 1.05 - i * 0.12, 1.4, 16), white if i % 2 == 0 else red, Vector3(0, 1.2 + i * 1.4, 0))
	part(body, cyl(0.7, 0.7, 0.9, 12), toon(col, false, 1.4), Vector3(0, 6.6, 0))
	part(body, cyl(0.0, 0.9, 0.8, 12), red, Vector3(0, 7.45, 0))
	var l := OmniLight3D.new(); l.light_color = col; l.light_energy = 1.4; l.omni_range = 9.0; l.position = Vector3(0, 6.6, 0)
	body.add_child(l)
	return root

static func banner(col: Color) -> Node3D:
	var root := Node3D.new()
	part(root, cyl(0.06, 0.06, 3.2, 8), toon(Color("5a4636")), Vector3(0, 1.6, 0))
	part(root, box(0.7, 1.1, 0.04), toon(col), Vector3(0.38, 2.5, 0), Vector3.ONE, Vector3.ZERO, "Flag")
	part(root, sphere(0.09, 8), toon(Color("f2c84a"), true, 0.4), Vector3(0, 3.25, 0))
	return root

static func notice_board() -> Node3D:
	var root := Node3D.new()
	var wood := toon(Color("7a5236"))
	for x in [-1.0, 1.0]:
		part(root, box(0.14, 2.0, 0.14), wood, Vector3(x, 1.0, 0))
	part(root, box(2.3, 1.3, 0.1), toon(Color("c49a6a")), Vector3(0, 1.35, 0))
	part(root, box(2.5, 0.14, 0.3), wood, Vector3(0, 2.05, 0))
	var cols := [Color("f3eee2"), Color("ffe08a"), Color("cfe8ff"), Color("ffd0dc")]
	for i in 5:
		part(root, box(0.42, 0.5, 0.02), toon(cols[i % 4]), Vector3(-0.8 + i * 0.4, 1.35 + (0.12 if i % 2 else -0.1), 0.07), Vector3.ONE, Vector3(0, 0, (i - 2) * 0.06))
	return root

static func fountain() -> Node3D:
	var root := Node3D.new()
	var stone := toon(Color("b8b2a8"))
	part(root, cyl(1.8, 1.9, 0.5, 24), stone, Vector3(0, 0.25, 0))
	part(root, cyl(1.55, 1.55, 0.06, 24), toon(Color("3d78a8"), false, 0.15), Vector3(0, 0.48, 0))
	part(root, cyl(0.3, 0.4, 1.3, 12), stone, Vector3(0, 1.0, 0))
	part(root, cyl(0.7, 0.5, 0.2, 16), stone, Vector3(0, 1.7, 0))
	var sp := CPUParticles3D.new(); sp.name = "Spray"
	sp.amount = 40; sp.lifetime = 0.9
	var m := SphereMesh.new(); m.radius = 0.05; m.height = 0.1; m.radial_segments = 6; m.rings = 3
	var pm := StandardMaterial3D.new(); pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; pm.albedo_color = Color(0.75, 0.9, 1.0, 0.8); pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = pm; sp.mesh = m
	sp.direction = Vector3.UP; sp.spread = 18.0; sp.initial_velocity_min = 2.5; sp.initial_velocity_max = 3.4
	sp.gravity = Vector3(0, -9, 0); sp.position = Vector3(0, 1.8, 0)
	root.add_child(sp)
	return root


## Furniture for building interiors, built at the origin of its footprint's first tile and
## spanning size[0] x size[1] tiles along +x / +z.
static func furniture(id: String) -> Node3D:
	var root := Node3D.new()
	var wood := toon(Color("8a5a3a")); var dark := toon(Color("5e3c26")); var light := toon(Color("c99a6a"))
	var cloth := toon(Color("d9604a")); var cream := toon(Color("f1e6cf")); var leaf := toon(Color("4f9a4a")); var pot := toon(Color("c0663e"))
	var metal := toon(Color("3d3f4a"))
	match id:
		"bed":
			part(root, box(1.8, 0.35, 2.8), wood, Vector3(1.0, 0.25, 1.5))
			part(root, box(1.7, 0.18, 2.5), cream, Vector3(1.0, 0.5, 1.55))
			part(root, box(1.72, 0.12, 1.6), cloth, Vector3(1.0, 0.62, 2.0))
			part(root, box(0.9, 0.16, 0.45), toon(Color("fffaf0")), Vector3(1.0, 0.66, 0.5))
			part(root, box(1.9, 0.9, 0.12), dark, Vector3(1.0, 0.55, 0.12))
		"kin_bed":
			part(root, cyl(0.42, 0.36, 0.22, 16), toon(Color("c9a46a")), Vector3(0.5, 0.11, 0.5))
			part(root, cyl(0.32, 0.32, 0.06, 16), toon(Color("e8b0c0")), Vector3(0.5, 0.2, 0.5))
		"table":
			part(root, box(1.8, 0.1, 0.9), light, Vector3(1.0, 0.72, 0.5))
			for p in [Vector3(0.2, 0.36, 0.15), Vector3(1.8, 0.36, 0.15), Vector3(0.2, 0.36, 0.85), Vector3(1.8, 0.36, 0.85)]:
				part(root, box(0.1, 0.72, 0.1), wood, p)
			part(root, cyl(0.1, 0.08, 0.14, 10), toon(Color("e0e8f0")), Vector3(0.6, 0.84, 0.5))
		"chair":
			part(root, box(0.55, 0.08, 0.55), light, Vector3(0.5, 0.45, 0.5))
			part(root, box(0.55, 0.55, 0.08), wood, Vector3(0.5, 0.72, 0.25))
			for p in [Vector3(0.28, 0.22, 0.28), Vector3(0.72, 0.22, 0.28), Vector3(0.28, 0.22, 0.72), Vector3(0.72, 0.22, 0.72)]:
				part(root, box(0.07, 0.45, 0.07), wood, p)
		"stool":
			part(root, cyl(0.25, 0.25, 0.08, 12), light, Vector3(0.5, 0.45, 0.5))
			part(root, cyl(0.06, 0.1, 0.42, 8), wood, Vector3(0.5, 0.21, 0.5))
		"rug":
			part(root, box(2.9, 0.03, 1.9), toon(Color("6a4c8c"), false), Vector3(1.5, 0.015, 1.0))
			part(root, box(2.5, 0.035, 1.5), toon(Color("e0b25a"), false), Vector3(1.5, 0.02, 1.0))
			part(root, box(2.1, 0.04, 1.1), toon(Color("6a4c8c"), false), Vector3(1.5, 0.025, 1.0))
		"rug_round":
			part(root, cyl(0.95, 0.95, 0.03, 28), toon(Color("3f7a8c"), false), Vector3(1.0, 0.015, 1.0))
			part(root, cyl(0.6, 0.6, 0.035, 28), toon(Color("f2e8d2"), false), Vector3(1.0, 0.02, 1.0))
		"lamp":
			part(root, cyl(0.18, 0.22, 0.06, 12), metal, Vector3(0.5, 0.03, 0.5))
			part(root, cyl(0.03, 0.03, 1.4, 8), metal, Vector3(0.5, 0.72, 0.5))
			part(root, cyl(0.16, 0.28, 0.32, 14), toon(Color("ffe9b8"), false, 0.8), Vector3(0.5, 1.45, 0.5))
			var ol := OmniLight3D.new(); ol.light_color = Color("ffd9a0"); ol.light_energy = 1.4; ol.omni_range = 4.5
			ol.position = Vector3(0.5, 1.4, 0.5); root.add_child(ol)
		"plant":
			part(root, cyl(0.2, 0.15, 0.3, 12), pot, Vector3(0.5, 0.15, 0.5))
			part(root, sphere(0.28), leaf, Vector3(0.5, 0.48, 0.5), Vector3(1, 0.9, 1))
		"big_plant":
			part(root, cyl(0.26, 0.2, 0.4, 12), pot, Vector3(0.5, 0.2, 0.5))
			part(root, cyl(0.04, 0.05, 0.7, 6), dark, Vector3(0.5, 0.7, 0.5))
			for i in 4:
				var a := TAU * i / 4.0
				part(root, sphere(0.26), leaf, Vector3(0.5 + cos(a) * 0.18, 1.1 + (i % 2) * 0.12, 0.5 + sin(a) * 0.18))
		"shelf":
			part(root, box(1.8, 1.8, 0.45), wood, Vector3(1.0, 0.9, 0.3))
			for row in 3:
				for b in 7:
					part(root, box(0.17, 0.42, 0.3), toon([Color("c0443a"), Color("3f6a9c"), Color("d9b04a"), Color("4f8a5a")][(row + b) % 4]), Vector3(0.35 + b * 0.22, 0.42 + row * 0.55, 0.38))
		"chest":
			part(root, box(0.8, 0.5, 0.55), wood, Vector3(0.5, 0.25, 0.5))
			part(root, box(0.84, 0.1, 0.6), dark, Vector3(0.5, 0.52, 0.5))
			part(root, box(0.12, 0.14, 0.04), toon(Color("e0b84a"), false, 0.3), Vector3(0.5, 0.4, 0.78))
		"stove":
			part(root, box(0.85, 0.85, 0.75), metal, Vector3(0.5, 0.42, 0.45))
			part(root, box(0.5, 0.3, 0.05), toon(Color("ff8a3a"), false, 0.9), Vector3(0.5, 0.35, 0.84))
			part(root, cyl(0.08, 0.08, 0.8, 8), metal, Vector3(0.5, 1.2, 0.3))
		"fireplace":
			part(root, box(1.9, 1.2, 0.6), toon(Color("9a8f86")), Vector3(1.0, 0.6, 0.35))
			part(root, box(1.0, 0.6, 0.3), toon(Color("2a2024")), Vector3(1.0, 0.35, 0.55))
			part(root, sphere(0.22), toon(Color("ff9a3a"), false, 1.0), Vector3(1.0, 0.25, 0.6), Vector3(1.4, 0.8, 1))
			var fl := OmniLight3D.new(); fl.light_color = Color("ffb070"); fl.light_energy = 1.6; fl.omni_range = 5.0
			fl.position = Vector3(1.0, 0.5, 0.9); root.add_child(fl)
		"wardrobe":
			part(root, box(1.8, 2.0, 0.6), wood, Vector3(1.0, 1.0, 0.35))
			part(root, box(0.04, 1.8, 0.02), dark, Vector3(1.0, 1.0, 0.66))
			for x in [0.85, 1.15]:
				part(root, sphere(0.04), toon(Color("e0b84a")), Vector3(x, 1.0, 0.68))
		"fishbowl":
			part(root, box(0.6, 0.6, 0.6), wood, Vector3(0.5, 0.3, 0.5))
			part(root, sphere(0.28), toon(Color(0.6, 0.85, 1.0), false, 0.3), Vector3(0.5, 0.86, 0.5))
			part(root, sphere(0.06), toon(Color("ff8a3a")), Vector3(0.55, 0.84, 0.5), Vector3(1.4, 1, 1))
		"easel":
			part(root, box(0.06, 1.4, 0.06), wood, Vector3(0.3, 0.7, 0.55), Vector3.ONE, Vector3(0.12, 0, 0.1))
			part(root, box(0.06, 1.4, 0.06), wood, Vector3(0.7, 0.7, 0.55), Vector3.ONE, Vector3(0.12, 0, -0.1))
			part(root, box(0.8, 0.6, 0.04), toon(Color("f6efe0")), Vector3(0.5, 1.05, 0.45), Vector3.ONE, Vector3(-0.12, 0, 0))
			part(root, sphere(0.14), toon(Color("f2a24a")), Vector3(0.45, 1.08, 0.42), Vector3(1, 1, 0.2))
			part(root, box(0.6, 0.12, 0.02), toon(Color("5aa04a")), Vector3(0.5, 0.86, 0.43))
		"trophy":
			part(root, box(0.6, 0.7, 0.6), dark, Vector3(0.5, 0.35, 0.5))
			part(root, cyl(0.18, 0.08, 0.3, 12), toon(Color("f2c84a"), false, 0.5), Vector3(0.5, 0.95, 0.5))
			part(root, cyl(0.1, 0.12, 0.08, 10), toon(Color("f2c84a"), false, 0.5), Vector3(0.5, 0.74, 0.5))
		"cushion":
			part(root, cyl(0.38, 0.4, 0.16, 16), toon(Color("e07a9a")), Vector3(0.5, 0.08, 0.5))
		"toy_ball":
			part(root, sphere(0.18), toon(Color("ff6a5a")), Vector3(0.5, 0.18, 0.5))
			part(root, cyl(0.185, 0.185, 0.04, 16), toon(Color("fff0d8")), Vector3(0.5, 0.18, 0.5), Vector3.ONE, Vector3(0, 0, PI / 2))
	return root


## The skyship that carries everyone over the islands at the start of an expedition.
# ---------------------------------------------------------------- scenery islands
## A free-standing floating island for scenery (the title screen, distant backdrops): a grassy top
## with a wavy outline, a grass lip, cliffs with rock strata that taper into a jagged spike below.
## Drawn with the island terrain shader so it matches the playable islands.
static func float_island(rng: RandomNumberGenerator, radius: float, depth: float, top_c := Color("6aa64a"), side_c := Color("8b6d52"), deep_c := Color("3a3140")) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 44
	var ph := rng.randf() * 10.0
	var rim: Array = []
	for i in n:
		var a := TAU * i / n
		var wob := 1.0 + 0.13 * sin(a * 3.0 + ph) + 0.07 * sin(a * 7.0 + ph * 2.0) + rng.randf_range(-0.03, 0.03)
		rim.append(Vector2(cos(a), sin(a)) * radius * wob)
	var top_y := 0.0
	# top: a gentle dome, fanned from the middle
	var cen := Vector3(0, top_y + radius * 0.04, 0)
	for i in n:
		var a2: Vector2 = rim[i]; var b2: Vector2 = rim[(i + 1) % n]
		var a := Vector3(a2.x, top_y, a2.y); var b := Vector3(b2.x, top_y, b2.y)
		var ca := top_c.darkened(0.06 + 0.05 * sin(TAU * i / n * 3.0 + ph)); var cb := top_c.darkened(0.06 + 0.05 * sin(TAU * (i + 1) / n * 3.0 + ph))
		st.set_normal(Vector3.UP)
		st.set_color(top_c.lightened(0.05)); st.add_vertex(cen)
		st.set_color(ca); st.add_vertex(a)
		st.set_color(cb); st.add_vertex(b)
	# cliffs: rings shrinking toward a point, with a jagged edge
	var rings := 7
	var prev: Array = []
	for i in n:
		prev.append(Vector3(rim[i].x, top_y, rim[i].y))
	for k in range(1, rings + 1):
		var t := float(k) / rings
		var ring: Array = []
		var shrink := pow(1.0 - t, 1.5) if k < rings else 0.0
		var y := top_y - (0.22 if k == 1 else depth * pow(t, 0.85))
		for i in n:
			var aa := TAU * i / n
			var jag := 0.92 + 0.1 * sin(aa * 5.0 + k * 1.3 + ph) + 0.06 * sin(aa * 11.0 - k * 0.7)
			var r2: Vector2 = rim[i] * (0.97 if k == 1 else shrink * jag)
			ring.append(Vector3(r2.x, y + (sin(aa * 4.0 + k + ph) * depth * 0.05 if k > 1 else 0.0), r2.y))
		var c0: Color = (top_c.darkened(0.1) if k == 1 else side_c.lerp(deep_c, float(k - 1) / rings))
		var c1: Color = (top_c.darkened(0.1) if k == 1 else side_c.lerp(deep_c, float(k) / rings))
		for i in n:
			var a: Vector3 = prev[i]; var b: Vector3 = prev[(i + 1) % n]
			var c: Vector3 = ring[(i + 1) % n]; var d: Vector3 = ring[i]
			var nrm := (d - a).cross(b - a).normalized()
			if nrm.dot(Vector3(a.x, 0, a.z)) < 0.0: nrm = -nrm
			st.set_normal(nrm)
			st.set_color(c0); st.add_vertex(a)
			st.set_color(c0); st.add_vertex(b)
			st.set_color(c1); st.add_vertex(c)
			st.set_color(c0); st.add_vertex(a)
			st.set_color(c1); st.add_vertex(c)
			st.set_color(c1); st.add_vertex(d)
		prev = ring
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = World.terrain_material()
	mi.set_meta("rim", rim)
	return mi

## A curtain of water pouring off an island edge, with mist where it fades out.
static func waterfall(width: float, height: float) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(width, height)
	mi.mesh = qm
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/waterfall.gdshader")
	mi.material_override = m
	mi.position = Vector3(0, -height * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var p := CPUParticles3D.new()
	p.amount = 24; p.lifetime = 2.0; p.preprocess = 2.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; p.emission_box_extents = Vector3(width * 0.4, 0.3, 0.3)
	p.direction = Vector3(0, 1, 0); p.spread = 60.0; p.initial_velocity_min = 0.3; p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, -0.2, 0)
	p.scale_amount_min = 1.0; p.scale_amount_max = 2.5
	p.mesh = sphere(0.25, 6)
	p.material_override = glow_mat(Color(0.9, 0.95, 1.0, 0.25))
	p.position = Vector3(0, -height * 0.8, 0)
	root.add_child(p)
	return root

static func skyship() -> Node3D:
	var root := Node3D.new()
	var wood := toon(Color("7a5236")); var dark := toon(Color("4e3424")); var cloth := toon(Color("f2e6cf"))
	var stripe := toon(Color("d9604a")); var brass := toon(Color("e0b84a"), true, 0.3)
	# the balloon
	part(root, sphere(2.6, 22), cloth, Vector3(0, 4.2, 0), Vector3(1.0, 0.8, 1.9))
	for i in 3:
		part(root, cyl(2.08 * (1.0 - absf(i - 1) * 0.18), 2.08 * (1.0 - absf(i - 1) * 0.18), 0.32, 22), stripe, Vector3(0, 4.2, -2.2 + i * 2.2), Vector3(1, 1, 0.82), Vector3(PI / 2, 0, 0))
	# ribbons running nose to tail over the top, so it reads from the bird's-eye camera too
	for rz in [-0.42, 0.0, 0.42]:
		part(root, sphere(2.63, 22), stripe if rz == 0.0 else toon(Color("f2c84a")), Vector3(0, 4.2, 0), Vector3(0.09, 0.84, 1.92), Vector3(0, 0, rz))
	part(root, sphere(0.5, 12), brass, Vector3(0, 6.3, 0), Vector3(1.0, 0.4, 1.0))
	# ropes
	for x in [-1.0, 1.0]:
		for z in [-1.6, 1.6]:
			part(root, cyl(0.03, 0.03, 2.4, 6), dark, Vector3(x * 0.9, 2.0, z), Vector3.ONE, Vector3(0, 0, x * 0.25))
	# the hull
	part(root, box(2.0, 0.7, 4.4), wood, Vector3(0, 0.35, 0))
	part(root, box(2.2, 0.18, 4.6), dark, Vector3(0, 0.75, 0))
	part(root, cyl(0.6, 0.2, 2.0, 12), wood, Vector3(0, 0.35, -2.8), Vector3(1.6, 1, 0.5), Vector3(PI / 2, 0, 0))
	# propellers at the back
	for x in [-1.3, 1.3]:
		var hub := Node3D.new(); hub.name = "Prop%s" % ("L" if x < 0 else "R"); hub.position = Vector3(x, 0.6, 2.4)
		root.add_child(hub)
		part(hub, cyl(0.12, 0.12, 0.3, 10), brass, Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0))
		for b in 3:
			part(hub, box(0.12, 1.1, 0.04), wood, Vector3.ZERO, Vector3.ONE, Vector3(0, 0, TAU * b / 3.0))
	part(root, box(0.1, 1.2, 0.8), stripe, Vector3(0, 1.3, 2.3))
	return root
