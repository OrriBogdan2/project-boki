class_name KitMeshes
extends RefCounted
## Small cached ArrayMeshes for the Hem and Breaker effects: flat arc bands (crescents, swirl rings), curved
## standing walls (Breaker's aegis), a cone pillar. UV.x runs along the arc, UV.y across it (inner 0 ->
## outer 1 on a band; top 0 -> foot 1 on a wall), which is what KitShaders expects.

static var _cache := {}

## A flat band on the XZ plane between radii r0 and r1, from angle a0 to a1 (radians, 0 = -Z, clockwise
## seen from above, so a0 = -PI/2 .. a1 = PI/2 is the front half when the node faces -Z).
static func band(r0: float, r1: float, a0: float, a1: float, seg := 32) -> ArrayMesh:
	var key := "band|%.2f|%.2f|%.3f|%.3f|%d" % [r0, r1, a0, a1, seg]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var u0 := float(i) / seg
		var u1 := float(i + 1) / seg
		var b0 := lerpf(a0, a1, u0)
		var b1 := lerpf(a0, a1, u1)
		var p := [Vector3(sin(b0) * r0, 0, -cos(b0) * r0), Vector3(sin(b0) * r1, 0, -cos(b0) * r1),
			Vector3(sin(b1) * r1, 0, -cos(b1) * r1), Vector3(sin(b1) * r0, 0, -cos(b1) * r0)]
		var uv := [Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[k])
			st.add_vertex(p[k])
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh

## A standing curved wall of radius r and height hgt round the origin, from angle a0 to a1 (as band); its
## top edge sits `lean` metres further out than its foot.
static func wall(r: float, a0: float, a1: float, hgt: float, seg := 24, lean := 0.0) -> ArrayMesh:
	var key := "wall|%.2f|%.3f|%.3f|%.2f|%d|%.2f" % [r, a0, a1, hgt, seg, lean]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var u0 := float(i) / seg
		var u1 := float(i + 1) / seg
		var b0 := lerpf(a0, a1, u0)
		var b1 := lerpf(a0, a1, u1)
		var q0 := Vector3(sin(b0) * r, 0, -cos(b0) * r)
		var q1 := Vector3(sin(b1) * r, 0, -cos(b1) * r)
		var top0 := q0 * (r + lean) / r + Vector3(0, hgt, 0)
		var top1 := q1 * (r + lean) / r + Vector3(0, hgt, 0)
		var p := [top0, q0, q1, top1]
		var uv := [Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0)]
		var n := Vector3(sin((b0 + b1) * 0.5), 0, -cos((b0 + b1) * 0.5))
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(uv[k])
			st.add_vertex(p[k])
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh

## An open cylinder (a light pillar) with UV.y 0 at the top, 1 at the foot.
static func pillar(r_top: float, r_foot: float, hgt: float, seg := 18) -> ArrayMesh:
	var key := "pillar|%.2f|%.2f|%.2f|%d" % [r_top, r_foot, hgt, seg]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var u0 := float(i) / seg
		var u1 := float(i + 1) / seg
		var b0 := TAU * u0
		var b1 := TAU * u1
		var p := [Vector3(cos(b0) * r_top, hgt, sin(b0) * r_top), Vector3(cos(b0) * r_foot, 0, sin(b0) * r_foot),
			Vector3(cos(b1) * r_foot, 0, sin(b1) * r_foot), Vector3(cos(b1) * r_top, hgt, sin(b1) * r_top)]
		var uv := [Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0)]
		var ns := [
			Vector3(cos(b0), 0, sin(b0)),
			Vector3(cos(b0), 0, sin(b0)),
			Vector3(cos(b1), 0, sin(b1)),
			Vector3(cos(b1), 0, sin(b1))
		]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(ns[k])
			st.set_uv(uv[k])
			st.add_vertex(p[k])
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh

## A quad facing +Z (for billboards and standing panels), centred, with UV (0,0) at the top left.
static func quad(w: float, hgt: float) -> QuadMesh:
	var key := "quad|%.2f|%.2f" % [w, hgt]
	if _cache.has(key):
		return _cache[key]
	var q := QuadMesh.new()
	q.size = Vector2(w, hgt)
	_cache[key] = q
	return q

## One pooled effect node: a MeshInstance3D with its own material, no shadow, hidden.
static func inst(parent: Node3D, mesh: Mesh, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	mi.visible = false
	parent.add_child(mi)
	return mi
