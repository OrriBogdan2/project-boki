class_name HeroKit
## Sculpted, stylized pieces for the hunters (Models.hunter): smooth parametric surfaces, thick cloth
## shells, lofted tubes (locks of hair, horns, feathers, straps), a sculpted head per race and
## gender, chunky hair clumps, mitten hands and lofted boots, and each archetype's gear (HeroGear).
## Every mesh carries baked ambient occlusion in its vertex colour (darker where cloth folds in, at
## the roots of locks, under brims and inside hoods); the hunter's toon materials multiply it in
## (toon.gdshader `vertex_ao`). Meshes are cached by key, so a crowd of hunters costs one build.

static var _cache := {}

## The six archetypes, two per weight class (docs/ARCHETYPES.md). Until the archetype system exists
## each class wears its default; any of the six can be asked for (galleries, the creator preview).
const ARCHES := {
	"thief": {"cls": "light"},
	"archer": {"cls": "light"},
	"mage": {"cls": "light"},
	"gunslinger": {"cls": "medium"},
	"juggernaut": {"cls": "heavy"},
	"bulwark": {"cls": "heavy"},
	"dredge": {"cls": "heavy"},
	"ashwick": {"cls": "heavy"},
	"tender": {"cls": "medium"},
	"rimewright": {"cls": "light"},
	"dolm": {"cls": "medium"},
	"ostra": {"cls": "medium"},
}
const ARCH_ORDER := ["gunslinger", "bulwark", "mage", "juggernaut", "archer", "rimewright", "dredge", "tender", "ashwick", "dolm", "ostra", "thief"]
const ARCH_DEFAULT := {"light": "thief", "medium": "gunslinger", "heavy": "juggernaut"}

## Which archetype a hunter wears: asked for by name, else from the look, else the class default.
static func arch_for(cls: String, arch := "", look := {}) -> String:
	if ARCHES.has(arch):
		return arch
	var la := String(look.get("arch", ""))
	if ARCHES.has(la):
		return la
	return String(ARCH_DEFAULT.get(cls, "gunslinger"))

# ------------------------------------------------------------------------------------------ core
static func _commit(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, cols: PackedColorArray, idx: Array) -> ArrayMesh:
	var arrs := []
	arrs.resize(Mesh.ARRAY_MAX)
	arrs[Mesh.ARRAY_VERTEX] = verts
	arrs[Mesh.ARRAY_NORMAL] = norms
	arrs[Mesh.ARRAY_TEX_UV] = uvs
	arrs[Mesh.ARRAY_COLOR] = cols
	arrs[Mesh.ARRAY_INDEX] = PackedInt32Array(idx)
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
	return am

## The normal of fn at (u, v) by finite differences (u runs round, v runs down: outward for a
## sphere laid out as in head()). Where the patch pinches to a point, a neighbouring row stands in.
static func _fn_normal(fn: Callable, u: float, v: float, sgn: float) -> Vector3:
	var e := 0.0025
	for k in 3:
		var vv := clampf(v + (0.0 if k == 0 else (0.01 * k if v < 0.5 else -0.01 * k)), 0.0, 1.0)
		var du: Vector3 = (fn.call(u + e, vv) as Vector3) - (fn.call(u - e, vv) as Vector3)
		var dv: Vector3 = (fn.call(u, minf(vv + e, 1.0)) as Vector3) - (fn.call(u, maxf(vv - e, 0.0)) as Vector3)
		var n := du.cross(dv)
		if n.length_squared() > 1e-14:
			return n.normalized() * sgn
	return Vector3.UP

## A smooth patch from fn(u, v) -> Vector3, u and v in 0..1 (cols x rows quads). ao(u, v) -> 0..1.
static func surf(key: String, fn: Callable, cols: int, rows: int, ao := Callable(), sgn := 1.0) -> ArrayMesh:
	if key != "" and _cache.has(key):
		return _cache[key]
	var verts := PackedVector3Array(); var norms := PackedVector3Array(); var uvs := PackedVector2Array(); var cs := PackedColorArray(); var idx: Array = []
	for j in rows + 1:
		var v := float(j) / rows
		for i in cols + 1:
			var u := float(i) / cols
			verts.append(fn.call(u, v)); norms.append(_fn_normal(fn, u, v, sgn)); uvs.append(Vector2(u, v))
			var a := float(ao.call(u, v)) if ao.is_valid() else 1.0
			cs.append(Color(a, a, a))
	for j in rows:
		for i in cols:
			var a0 := j * (cols + 1) + i
			Models._quad(verts, norms, idx, a0, a0 + 1, a0 + cols + 2, a0 + cols + 1)
	var am := _commit(verts, norms, uvs, cs, idx)
	if key != "": _cache[key] = am
	return am

## A sheet of cloth or plate with real thickness: fn is the outer face; the inner face sits `thick`
## inside it, darker (the inside of a coat or a hood), and the open edges are closed with a rim.
## closed_u: the patch wraps round (a skirt), so only its top and bottom edges get a rim.
static func shell(key: String, fn: Callable, cols: int, rows: int, thick: float, ao := Callable(), closed_u := false, sgn := 1.0, inner_ao := 0.55) -> ArrayMesh:
	if key != "" and _cache.has(key):
		return _cache[key]
	var verts := PackedVector3Array(); var norms := PackedVector3Array(); var uvs := PackedVector2Array(); var cs := PackedColorArray(); var idx: Array = []
	var W := cols + 1
	var outer: Array = []
	var nrm: Array = []
	var aos: Array = []
	for j in rows + 1:
		var v := float(j) / rows
		for i in cols + 1:
			var u := float(i) / cols
			outer.append(fn.call(u, v)); nrm.append(_fn_normal(fn, u, v, sgn))
			aos.append(float(ao.call(u, v)) if ao.is_valid() else 1.0)
	# outer face, then inner face
	for side in 2:
		var base := verts.size()
		for k in outer.size():
			var p: Vector3 = outer[k]; var n: Vector3 = nrm[k]
			var a: float = aos[k] * (1.0 if side == 0 else inner_ao)
			verts.append(p if side == 0 else p - n * thick); norms.append(n if side == 0 else -n)
			uvs.append(Vector2(float(k % W) / cols, float(k / W) / rows)); cs.append(Color(a, a, a))
		for j in rows:
			for i in cols:
				var a0 := base + j * W + i
				Models._quad(verts, norms, idx, a0, a0 + 1, a0 + W + 1, a0 + W)
	# rims along the open edges
	var edges: Array = []
	var top: Array = []; var bot: Array = []
	for i in cols + 1:
		top.append(i); bot.append(rows * W + i)
	edges.append([top, -1]); edges.append([bot, 1])
	if not closed_u:
		var l: Array = []; var r: Array = []
		for j in rows + 1:
			l.append(j * W); r.append(j * W + cols)
		edges.append([l, -2]); edges.append([r, 2])
	for e in edges:
		var ks: Array = e[0]
		var dir: int = e[1]
		var base := verts.size()
		for m in ks.size():
			var k: int = ks[m]
			var p: Vector3 = outer[k]; var n: Vector3 = nrm[k]
			# the rim faces away from the patch: from the next row (or column) in to this one
			var kin := k + (W if dir == -1 else (-W if dir == 1 else (1 if dir == -2 else -1)))
			var out: Vector3 = (p - (outer[kin] as Vector3))
			out = (out - n * out.dot(n)).normalized() if out.length() > 1e-6 else n
			var a: float = aos[k] * 0.8
			verts.append(p); norms.append(out); uvs.append(Vector2.ZERO); cs.append(Color(a, a, a))
			verts.append(p - n * thick); norms.append(out); uvs.append(Vector2.ZERO); cs.append(Color(a, a, a))
		for m in ks.size() - 1:
			var a0 := base + m * 2
			Models._quad(verts, norms, idx, a0, a0 + 2, a0 + 3, a0 + 1)
	var am := _commit(verts, norms, uvs, cs, idx)
	if key != "": _cache[key] = am
	return am

## Catmull-Rom through 3D points, `sub` steps per span.
static func curve3(pts: Array, sub := 4) -> Array:
	var out: Array = []
	var n := pts.size()
	for i in n - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]; var p1: Vector3 = pts[i]; var p2: Vector3 = pts[i + 1]; var p3: Vector3 = pts[mini(i + 2, n - 1)]
		for k in sub:
			var t := float(k) / sub
			var t2 := t * t; var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[n - 1])
	return out

## A tube along a smooth spine through `pts`, with an elliptical section per point (x across, y
## through: a flat lock of hair, a strap, a horn), rounded off at both ends. `up` orients the flat
## side; ao runs from `ao_root` at the start to 1 at the tip.
static func loft(key: String, pts: Array, wid: Array, seg := 12, up := Vector3.UP, ao_root := 0.7, sub := 4) -> ArrayMesh:
	if key != "" and _cache.has(key):
		return _cache[key]
	var sp := curve3(pts, sub)
	var n := sp.size()
	var ws: Array = []
	for i in n:
		var f := float(i) / (n - 1) * (wid.size() - 1)
		var i0 := mini(int(f), wid.size() - 2)
		ws.append((wid[i0] as Vector2).lerp(wid[i0 + 1], f - i0))
	var verts := PackedVector3Array(); var norms := PackedVector3Array(); var uvs := PackedVector2Array(); var cs := PackedColorArray(); var idx: Array = []
	var side := Vector3.ZERO
	var tans: Array = []
	for i in n:
		var t: Vector3 = ((sp[mini(i + 1, n - 1)] as Vector3) - (sp[maxi(i - 1, 0)] as Vector3)).normalized()
		tans.append(t)
	side = up.cross(tans[0])
	if side.length() < 1e-4: side = Vector3.RIGHT.cross(tans[0])
	side = side.normalized()
	for i in n:
		var t: Vector3 = tans[i]
		side = (side - t * side.dot(t)).normalized()
		var bn := t.cross(side).normalized()
		var w: Vector2 = ws[i]
		w = Vector2(maxf(w.x, 0.0006), maxf(w.y, 0.0006))
		var a := lerpf(ao_root, 1.0, smoothstep(0.0, 0.5, float(i) / (n - 1)))
		for j in seg + 1:
			var ang := TAU * float(j) / seg
			var ca := cos(ang); var sa := sin(ang)
			verts.append((sp[i] as Vector3) + side * ca * w.x + bn * sa * w.y)
			norms.append((side * ca / w.x + bn * sa / w.y).normalized())
			uvs.append(Vector2(float(j) / seg, float(i) / (n - 1)))
			cs.append(Color(a, a, a))
	for i in n - 1:
		for j in seg:
			var a0 := i * (seg + 1) + j
			Models._quad(verts, norms, idx, a0, a0 + 1, a0 + seg + 2, a0 + seg + 1)
	# end caps: a point just past each end
	for e in 2:
		var ri := 0 if e == 0 else n - 1
		var t: Vector3 = tans[ri] * (-1.0 if e == 0 else 1.0)
		var w: Vector2 = ws[ri]
		var c := verts.size()
		verts.append((sp[ri] as Vector3) + t * minf(w.x, w.y) * 0.8); norms.append(t); uvs.append(Vector2.ZERO)
		var a: float = cs[ri * (seg + 1)].r
		cs.append(Color(a, a, a))
		for j in seg:
			var a0 := ri * (seg + 1) + j
			var tri := [c, a0, a0 + 1]
			var fn := (verts[tri[1]] - verts[tri[0]]).cross(verts[tri[2]] - verts[tri[0]])
			if fn.dot(t) > 0.0: idx.append_array([tri[0], tri[2], tri[1]])
			else: idx.append_array(tri)
	var am := _commit(verts, norms, uvs, cs, idx)
	if key != "": _cache[key] = am
	return am

## Puts a mesh on a node (the same as Models.part).
static func put(n: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	return Models.part(n, mesh, mat, pos, scl, rot)

## A unit direction on a sphere laid out with u round (from +X toward +Z) and v down from the top.
static func sdir(u: float, v: float) -> Vector3:
	var th := u * TAU; var ph := clampf(v, 0.0, 1.0) * PI
	return Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))

# ------------------------------------------------------------------------------------------ heads
## Head shapes: how the jaw narrows (and how square it stays at the front), the chin, cheek volume,
## brow ridge, a fuller skull behind, how boxy (Stoneborn), and the overall width.
const HEADS := {
	"human_m": {"jaw": 0.17, "jaw_sq": 0.85, "chin": 0.05, "chin_w": 0.42, "cheek": 0.075, "brow": 0.04, "skull": 0.06, "w": 1.04},
	"human_f": {"jaw": 0.3, "jaw_sq": 0.15, "chin": 0.04, "chin_w": 0.26, "cheek": 0.09, "brow": 0.015, "skull": 0.06, "w": 0.98},
	"vulpin": {"jaw": 0.2, "jaw_sq": 0.0, "chin": 0.0, "cheek": 0.16, "brow": 0.015, "skull": 0.04, "w": 1.04},
	"stoneborn": {"jaw": -0.06, "jaw_sq": 1.0, "chin": 0.03, "chin_w": 0.6, "cheek": 0.02, "brow": 0.05, "skull": 0.0, "box": 3.2, "w": 1.06, "flat": 0.12},
	"sprig": {"jaw": 0.3, "jaw_sq": 0.0, "chin": 0.02, "chin_w": 0.25, "cheek": 0.08, "brow": 0.0, "skull": 0.09, "w": 1.0},
	"scalefolk": {"jaw": 0.12, "jaw_sq": 0.4, "chin": 0.0, "cheek": 0.03, "brow": 0.05, "skull": 0.12, "w": 0.98, "flat": 0.1},
	"owlet": {"jaw": 0.14, "jaw_sq": 0.2, "chin": 0.0, "cheek": 0.1, "brow": 0.02, "skull": 0.03, "w": 1.06, "flat": 0.08},
}

static func head_key(rid: String, fem: bool) -> String:
	if rid == "human":
		return "human_f" if fem else "human_m"
	return rid if HEADS.has(rid) else "human_m"

## A point on the sculpted head (centred on 0, radius about 0.235) in the unit direction n. The eye
## band in front is left on the plain sphere, so the painted-on face sits where it always did.
static func head_pt(n: Vector3, s: Dictionary) -> Vector3:
	var R := 0.235
	var p := n
	var bx := float(s.get("box", 0.0))
	if bx > 0.0:
		var d := pow(pow(absf(n.x), bx) + pow(absf(n.y), bx) + pow(absf(n.z), bx), 1.0 / bx)
		p = (n / d).lerp(n, 0.45)
	p *= R
	var front := clampf(-n.z, 0.0, 1.0)
	var low := smoothstep(0.05, -0.95, n.y)
	var taper := float(s.get("jaw", 0.15)) * low * (1.0 - float(s.get("jaw_sq", 0.0)) * front * 0.8)
	p.x *= 1.0 - taper
	p.z *= 1.0 - taper * 0.45 * (1.0 - front)
	var chin := float(s.get("chin", 0.03)) * exp(-pow(n.x / float(s.get("chin_w", 0.35)), 2.0)) * smoothstep(-0.45, -0.92, n.y) * front
	p.z -= chin; p.y -= chin * 0.8
	for sx in [-1.0, 1.0]:
		var c := Vector3(0.62 * sx, -0.3, -0.72).normalized()
		p += n * R * float(s.get("cheek", 0.05)) * exp(-n.distance_squared_to(c) / 0.09)
	var brow := float(s.get("brow", 0.02)) * exp(-pow((n.y - 0.32) / 0.12, 2.0)) * smoothstep(0.55, 0.9, front) * (1.0 - smoothstep(0.55, 0.85, absf(n.x)))
	p.z -= brow * R
	p += n * R * float(s.get("skull", 0.04)) * smoothstep(0.0, 0.8, n.z) * smoothstep(-0.3, 0.3, n.y)
	if n.y > 0.0:
		p.y *= 1.0 - float(s.get("flat", 0.03)) * n.y
	p.x *= float(s.get("w", 1.0))
	return p

## The sculpted head itself: shaded a touch darker under the jaw and behind the ears.
static func head(hk: String) -> ArrayMesh:
	var s: Dictionary = HEADS.get(hk, HEADS["human_m"])
	var fn := func(u: float, v: float) -> Vector3: return head_pt(sdir(u, v), s)
	var ao := func(u: float, v: float) -> float:
		var n := sdir(u, v)
		return 1.0 - 0.28 * smoothstep(-0.5, -0.95, n.y)
	return surf("head|" + hk, fn, 40, 26, ao)

## A hair cap that follows the sculpted head: a shell of chunky rounded locks (creased between),
## whose lower edge comes down in pointed lock tips. edge(u) gives how far down (0 crown .. 1 chin)
## each part of the cap reaches; `locks` how many clumps go round; `th` how thick the hair is.
static func hair_cap(key: String, hk: String, edge: Callable, locks := 11, th := 0.04, tip := 0.12, lift := 0.0) -> ArrayMesh:
	var s: Dictionary = HEADS.get(hk, HEADS["human_m"])
	var fn := func(u: float, v: float) -> Vector3:
		var t := fposmod(u * locks + 0.5, 1.0)
		var round_k := sqrt(maxf(0.0, 1.0 - pow(2.0 * t - 1.0, 2.0)))
		var e := float(edge.call(fposmod(u, 1.0))) + tip * pow(round_k, 1.4)
		var n := sdir(u, v * e)
		var k := smoothstep(0.08, 0.45, v)
		var bulge := lerpf(1.0, 0.45 + 0.55 * round_k, k)
		var thick := th * bulge * (1.0 - 0.8 * pow(v, 2.2)) + 0.004
		var p := head_pt(n, s) + n * thick
		p += n * lift * (1.0 - v)
		return p
	var ao := func(u: float, v: float) -> float:
		var t := fposmod(u * locks + 0.5, 1.0)
		var crease := 1.0 - pow(absf(2.0 * t - 1.0), 6.0)
		return lerpf(1.0, lerpf(0.7, 1.0, crease), smoothstep(0.1, 0.4, v)) * lerpf(1.0, 0.82, v * v)
	return surf("cap|" + key + "|" + hk, fn, locks * 8, 16, ao)

## One chunky lock of hair (or fur, a feather, a horn): a flattened tube along a curve that
## tapers to a point. w: width at the root, flat: thickness as a share of the width.
static func lock_mesh(key: String, pts: Array, w: float, flat := 0.5, up := Vector3.UP, ao_root := 0.65, blunt := 0.0) -> ArrayMesh:
	var wid: Array = []
	var n := pts.size()
	for i in n:
		var t := float(i) / (n - 1)
		var k := pow(1.0 - t, 1.15) * (1.0 + 0.55 * sin(t * PI)) + blunt * t * (1.0 - t) * 2.0
		wid.append(Vector2(w * k, w * flat * k))
	return loft(key, pts, wid, 10, up, ao_root)

# ------------------------------------------------------------------------------------------ hands, boots
## A mitten hand: palm and fingers as one chunky curled form (fingers curl toward -Z), knuckles
## standing proud, and a separate thumb. About the old hand's size, centred on the joint.
static func mitten() -> ArrayMesh:
	var pts := [Vector3(0, 0.055, 0.008), Vector3(0, 0.0, 0.004), Vector3(0, -0.06, -0.006), Vector3(0, -0.1, -0.03), Vector3(0, -0.115, -0.065)]
	var wid := [Vector2(0.06, 0.04), Vector2(0.07, 0.044), Vector2(0.074, 0.046), Vector2(0.066, 0.04), Vector2(0.04, 0.026)]
	return loft("mitten", pts, wid, 18, Vector3.FORWARD, 0.85)

static func thumb() -> ArrayMesh:
	return loft("thumb", [Vector3(0, 0.03, 0), Vector3(0, -0.005, -0.03), Vector3(0, -0.04, -0.05)], [Vector2(0.03, 0.026), Vector2(0.028, 0.024), Vector2(0.02, 0.018)], 12, Vector3.RIGHT, 0.8)

## A flared cuff: overlaps the sleeve so the wrist (or ankle) never shows a seam.
static func cuff(r0: float, r1: float, h: float) -> ArrayMesh:
	var pts := PackedVector2Array([Vector2(0.0, -h * 0.5), Vector2(r0 * 0.96, -h * 0.5), Vector2(r0, -h * 0.3), Vector2(lerpf(r0, r1, 0.6), h * 0.2), Vector2(r1, h * 0.46), Vector2(r1 * 0.9, h * 0.5), Vector2(0.0, h * 0.5)])
	return Models.lathe(Models.smooth_curve(pts, 2), 28, "cuff|%.3f|%.3f|%.3f" % [r0, r1, h])

## A boot in one piece: a shaft that flares at the cuff, then the foot sweeping forward to a
## rounded, slightly upturned toe (-Z), on a thick sole. Hangs from the knee like the old boot.
static func boot(k: float) -> ArrayMesh:
	var pts := [Vector3(0, -0.07, 0.01), Vector3(0, -0.16, 0.012), Vector3(0, -0.205, 0.0), Vector3(0, -0.225, -0.07), Vector3(0, -0.222, -0.15 * k)]
	var wid := [Vector2(0.072, 0.072), Vector2(0.066, 0.07), Vector2(0.07 * k, 0.062), Vector2(0.07 * k, 0.04), Vector2(0.05 * k, 0.03)]
	return loft("boot|%.3f" % k, pts, wid, 18, Vector3.UP, 0.85)

static func sole(k: float) -> ArrayMesh:
	var pts := [Vector3(0, -0.245, 0.03), Vector3(0, -0.25, -0.06), Vector3(0, -0.246, -0.16 * k)]
	return loft("sole|%.3f" % k, pts, [Vector2(0.074 * k, 0.018), Vector2(0.078 * k, 0.018), Vector2(0.056 * k, 0.016)], 16, Vector3.FORWARD, 0.9)

## A smooth domed plate (a pauldron lame, a knee cop, a helm cheek): a slice of a squashed sphere
## with thickness, its rim turned out a little. Faces +Y; `span` is how far down its sides reach.
static func dome_plate(key: String, r: float, span := 0.5, squash := 0.75, flare := 0.15, thick := 0.02) -> ArrayMesh:
	var fn := func(u: float, v: float) -> Vector3:
		var n := sdir(u, v * span)
		var rr := r * (1.0 + flare * pow(v, 3.0))
		return Vector3(n.x * rr, n.y * r * squash, n.z * rr)
	var ao := func(u: float, v: float) -> float: return lerpf(1.0, 0.82, v * v)
	return shell("dome|" + key, fn, 28, 8, thick, ao, true)

## A cloth or leather strap round a body: a band of height h following an ellipse rx x rz.
static func band(key: String, rx: float, rz: float, h: float, thick := 0.012) -> ArrayMesh:
	var fn := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		return Vector3(cos(th) * rx, lerpf(h * 0.5, -h * 0.5, v), sin(th) * rz)
	return shell("band|" + key, fn, 40, 2, thick, Callable(), true)

# ------------------------------------------------------------------------------------------ torso
const _TORSO_PROF := [Vector2(0.0, 0.318), Vector2(0.11, 0.312), Vector2(0.19, 0.293), Vector2(0.236, 0.255), Vector2(0.248, 0.205), Vector2(0.236, 0.14),
	Vector2(0.212, 0.05), Vector2(0.205, -0.05), Vector2(0.218, -0.17), Vector2(0.2, -0.27), Vector2(0.13, -0.305), Vector2(0.0, -0.31)]
static var _tprof: PackedVector2Array

## The torso's outline (radius, height) from the top down, at v in 0..1.
static func torso_prof(v: float) -> Vector2:
	if _tprof.is_empty():
		_tprof = Models.smooth_curve(PackedVector2Array(_TORSO_PROF), 4)
	var f := clampf(v, 0.0, 1.0) * (_tprof.size() - 1)
	var i := mini(int(f), _tprof.size() - 2)
	return _tprof[i].lerp(_tprof[i + 1], f - i)

## A point on the sculpted torso (u round from +X toward +Z, v down; front is -Z), before the
## body's width scale. Women get a bust and a slimmer waist, men a fuller chest; both get shoulder
## blades and a hollow down the spine.
static func torso_pt(u: float, v: float, fem: bool, off := 0.0) -> Vector3:
	var pr := torso_prof(v)
	var th := u * TAU
	var r := pr.x + off * smoothstep(0.0, 0.08, pr.x)
	var p := Vector3(cos(th) * r, pr.y, sin(th) * r)
	var front := clampf(-sin(th), 0.0, 1.0)
	var back := clampf(sin(th), 0.0, 1.0)
	if fem:
		for sx in [-1.0, 1.0]:
			var d := Vector2(p.x - 0.078 * sx, (p.y - 0.07) * 1.15)
			p.z -= 0.05 * exp(-d.length_squared() / 0.0042) * front
		p.x *= 1.0 - 0.06 * exp(-pow((pr.y + 0.08) / 0.08, 2.0))
	else:
		for sx in [-1.0, 1.0]:
			var d := Vector2(p.x - 0.085 * sx, p.y - 0.11)
			p.z -= 0.014 * exp(-d.length_squared() / 0.006) * front
	for sx in [-1.0, 1.0]:
		var d := Vector2(p.x - 0.1 * sx, p.y - 0.13)
		p.z += 0.012 * exp(-d.length_squared() / 0.006) * back
	p.z -= 0.008 * exp(-pow(p.x / 0.03, 2.0)) * back * smoothstep(0.25, -0.1, p.y)
	return p

static func torso(fem: bool) -> ArrayMesh:
	var fn := func(u: float, v: float) -> Vector3: return torso_pt(u, v, fem)
	var ao := func(u: float, v: float) -> float:
		var pr := torso_prof(v)
		return lerpf(0.86, 1.0, smoothstep(-0.3, -0.05, pr.y)) * lerpf(1.0, 0.9, smoothstep(0.25, 0.31, pr.y))
	return surf("torso|%s" % fem, fn, 48, 26, ao)

## A piece of clothing or armour fitted over the torso: the patch u0..u1 round, v0..v1 down,
## `off` out from the skin, with thickness (a breastplate, a jerkin's front, a back plate).
static func torso_patch(key: String, fem: bool, u0: float, u1: float, v0: float, v1: float, off: float, thick := 0.014, bevel := 0.0) -> ArrayMesh:
	var fn := func(u: float, v: float) -> Vector3:
		var uu := lerpf(u0, u1, u); var vv := lerpf(v0, v1, v)
		var e := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
		return torso_pt(uu, vv, fem, off + bevel * smoothstep(0.0, 0.18, e))
	var ao := func(u: float, v: float) -> float: return lerpf(0.85, 1.0, smoothstep(0.0, 0.3, minf(v, 1.0 - v)))
	return shell("tp|%s|%s" % [key, fem], fn, 24, 14, thick, ao)

# ------------------------------------------------------------------------------------------ cloth
## A skirt, coat tail or robe: a flared shell from angle a0 to a1 round (front is -Z, at u = 0.75),
## from the waist (radius r0) down h to the hem (r1), with folds deepening toward the hem, a wavy
## hem, and a darker inside. a0 = 0, a1 = 1 wraps right round.
static func drape(key: String, r0: float, r1: float, h: float, a0 := 0.0, a1 := 1.0, folds := 9.0, amp := 0.06, wave := 0.0, back_long := 0.0, thick := 0.016, rows := 10) -> ArrayMesh:
	var closed := a0 <= 0.0 and a1 >= 1.0
	var fn := func(u: float, v: float) -> Vector3:
		var th := lerpf(a0, a1, u) * TAU
		var fold := sin(folds * th + 0.6 * sin(th * 3.0))
		var rr := lerpf(r0, r1, pow(v, 0.8)) * (1.0 + amp * pow(v, 1.3) * fold)
		var y := -h * v * (1.0 + back_long * clampf(sin(th), 0.0, 1.0)) + wave * v * v * sin(th * 5.0 + 1.3)
		return Vector3(cos(th) * rr, y, sin(th) * rr * 0.92)
	var ao := func(u: float, v: float) -> float:
		var th := lerpf(a0, a1, u) * TAU
		var fold := sin(folds * th + 0.6 * sin(th * 3.0))
		return lerpf(0.72, 1.0, smoothstep(0.0, 0.25, v)) * (1.0 + 0.16 * fold * smoothstep(0.1, 0.8, v))
	return shell("drape|" + key, fn, int(56 * (a1 - a0)) + 6, rows, thick, ao, closed)

## A trim band along the hem of a drape (same parameters), standing a little proud of it.
static func drape_hem(key: String, r0: float, r1: float, h: float, a0 := 0.0, a1 := 1.0, folds := 9.0, amp := 0.06, wave := 0.0, back_long := 0.0, depth := 0.08) -> ArrayMesh:
	var closed := a0 <= 0.0 and a1 >= 1.0
	var fn := func(u: float, v: float) -> Vector3:
		var th := lerpf(a0, a1, u) * TAU
		var vv := lerpf(1.0 - depth, 1.0, v)
		var fold := sin(folds * th + 0.6 * sin(th * 3.0))
		var rr := lerpf(r0, r1, pow(vv, 0.8)) * (1.0 + amp * pow(vv, 1.3) * fold) + 0.007
		var y := -h * vv * (1.0 + back_long * clampf(sin(th), 0.0, 1.0)) + wave * vv * vv * sin(th * 5.0 + 1.3)
		return Vector3(cos(th) * rr, y, sin(th) * rr * 0.92)
	return shell("hem|" + key, fn, int(56 * (a1 - a0)) + 6, 1, 0.02, Callable(), closed)

## A flat-ish sheet hanging from its top edge (a cape, a tabard, a banner): width w, length
## len(u) per column, curved round the body by `wrap` and swinging out `belly` at the bottom;
## `points` cuts the hem into that many points.
static func sheet(key: String, w: float, len0: float, len1: float, wrap := 0.3, belly := 0.06, points := 0, point_d := 0.06, thick := 0.016) -> ArrayMesh:
	var fn := func(u: float, v: float) -> Vector3:
		var x := lerpf(-w * 0.5, w * 0.5, u)
		var ln := lerpf(len0, len1, u)
		if points > 0:
			var t := fposmod(u * points, 1.0)
			ln += point_d * (1.0 - absf(2.0 * t - 1.0))
		var y := -ln * v
		var z := wrap * pow(x / (w * 0.5), 2.0) * w * 0.25 * -1.0 + belly * v * v + 0.015 * sin(u * 18.0) * v
		return Vector3(x, y, -z)
	var ao := func(u: float, v: float) -> float: return lerpf(0.8, 1.0, smoothstep(0.0, 0.3, v)) * (1.0 + 0.12 * sin(u * 18.0) * v)
	return shell("sheet|" + key, fn, 28, 10, thick, ao, false, -1.0)

## A lumpy roll (a fur mantle, a bun, an afro, a bedroll): an ellipsoid whose surface bulges into
## soft clumps.
static func lumpy(key: String, r: Vector3, bumps := 8.0, amp := 0.12, ph0 := 0.0) -> ArrayMesh:
	var fn := func(u: float, v: float) -> Vector3:
		var n := sdir(u, v)
		var b := sin(u * TAU * bumps + ph0) * sin(v * PI * bumps * 0.6 + ph0 * 1.7)
		var k := 1.0 + amp * (absf(b) * 2.0 - 1.0) * sin(v * PI)
		return Vector3(n.x * r.x, n.y * r.y, n.z * r.z) * k
	var ao := func(u: float, v: float) -> float:
		var b := sin(u * TAU * bumps + ph0) * sin(v * PI * bumps * 0.6 + ph0 * 1.7)
		return lerpf(0.75, 1.0, absf(b)) * lerpf(1.0, 0.8, smoothstep(0.6, 1.0, v))
	return surf("lumpy|" + key, fn, 40, 22, ao)

## A ring of fur or cloth round the neck and shoulders: a fat lumpy torus, flatter underneath.
static func mantle(key: String, rx: float, rz: float, tube: float, lumps := 11.0, front := 1.0) -> ArrayMesh:
	var fn := func(u: float, v: float) -> Vector3:
		var th := u * TAU; var ph := v * TAU
		var lump := 1.0 + 0.22 * absf(sin(th * lumps)) * clampf(cos(ph) * 0.5 + 0.5, 0.0, 1.0)
		var tr := tube * lump * lerpf(front, 1.0, smoothstep(-0.9, 0.2, sin(th)))
		var c := Vector3(cos(th) * rx, 0.0, sin(th) * rz)
		var out := Vector3(cos(th), 0.0, sin(th))
		return c + out * cos(ph) * tr + Vector3.UP * sin(ph) * tr * 0.75
	var ao := func(u: float, v: float) -> float:
		var th := u * TAU
		return lerpf(0.72, 1.0, absf(sin(th * lumps))) * lerpf(0.8, 1.0, clampf(sin(v * TAU) * 0.5 + 0.5, 0.0, 1.0))
	return surf("mantle|%s|%.2f" % [key, front], fn, 56, 12, ao, -1.0)

## A squarish plate dome (a Bulwark pauldron lame): a superellipse in plan, rx by rz, h tall,
## with thickness; `span` how far its sides come down. Faces +Y.
static func box_plate(key: String, rx: float, rz: float, h: float, thick := 0.02, span := 0.5, k := 3.5) -> ArrayMesh:
	var fn := func(u: float, v: float) -> Vector3:
		var n := sdir(u, v * span)
		var hr := sqrt(n.x * n.x + n.z * n.z)
		if hr < 1e-5:
			return Vector3(0, h, 0)
		var cx := n.x / hr; var cz := n.z / hr
		var sup := pow(pow(absf(cx), k) + pow(absf(cz), k), -1.0 / k)
		return Vector3(n.x * sup * rx, n.y * h, n.z * sup * rz)
	var ao := func(u: float, v: float) -> float: return lerpf(1.0, 0.8, v * v)
	return shell("boxp|" + key, fn, 32, 8, thick, ao, true)
