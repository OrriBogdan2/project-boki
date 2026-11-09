class_name Occluders
extends RefCounted
## Baked occlusion culling for the big expedition maps: one OccluderInstance3D of boxes that sit just
## inside the terrain's tall faces (island masses, rims, terrace cliffs) and inside large static rocks, so
## the renderer skips what the match camera can't see behind them. Generated from the tile grid and the
## placed props at map build (nothing hand-placed), so a bigger map or a new region needs no extra work.
## The boxes stay inside the real shapes, so culling never hides anything that is on screen.

const MIN_MAP := 96          # tiles: only maps this wide or wider (the home and town islands are tiny)
const TOP_GAP := 0.15        # m the box top sits under the ground (the grass and rim lip stay drawn)
const SIDE_INSET := 0.5      # m a face over a drop is pulled in (the traced cliffs round their corners)
const BOTTOM_GAP := 0.3      # m the box bottom sits above the underside (the mesh slopes between tile centres)
const MIN_DEPTH := 0.6       # m: a slab thinner than this hides nothing worth the triangles
const MAX_NODE := 16         # tiles: the largest square merged into one box
const UNDER_SPREAD := 5.0    # m: a square whose underside varies more than this is split
const ROCK_MIN_W := 1.6      # m across and
const ROCK_MIN_H := 1.2      # m tall (scaled): smaller rocks hide too little
const ROCK_FIT := 0.55       # share of a rock's bounds the box fills (under 0.577, so inside any ellipsoid)

var _w: World
var _verts := PackedVector3Array()
var _idx := PackedInt32Array()

## Adds the occluder node to `parent` when this preset culls and the map is big. `props` is what the map
## build batched (group key -> {mesh, items: [[Transform3D, Color]], label}): its large rocks become boxes too.
static func build(world: World, parent: Node3D, props: Dictionary) -> void:
	if world.w < MIN_MAP or not Settings.q("occlusion"):
		return
	var o := Occluders.new()
	o._w = world
	await o._terrain()
	o._rocks(props)
	if o._idx.is_empty():
		return
	var oc := ArrayOccluder3D.new()
	oc.set_arrays(o._verts, o._idx)
	var oi := OccluderInstance3D.new()
	oi.occluder = oc
	oi.name = "Occluders"
	parent.add_child(oi)

## Boxes in the shape of a quadtree over the tile grid: a square of tiles on one terrace with solid
## ground all through it is one box; mixed squares split down to single tiles.
func _terrain() -> void:
	for z0 in range(0, _w.h, MAX_NODE):
		await _w._slice()
		for x0 in range(0, _w.w, MAX_NODE):
			_node(x0, z0, MAX_NODE)

func _solid(x: int, z: int) -> bool:
	if not _w.inb(x, z):
		return false
	var i := _w.idx(x, z)
	return _w.kind[i] != World.T_VOID and not _w.bridge.has(i) and not _w.stairs.has(i)

func _node(x0: int, z0: int, s: int) -> void:
	if x0 >= _w.w or z0 >= _w.h:
		return
	var lv := -1
	var lo := INF
	var hi := -INF
	for z in range(z0, mini(z0 + s, _w.h)):
		for x in range(x0, mini(x0 + s, _w.w)):
			var i := _w.idx(x, z)
			if not _solid(x, z):
				lv = -2
				break
			if lv == -1: lv = _w.level[i]
			if _w.level[i] != lv:
				lv = -2
				break
			lo = minf(lo, _w.under[i])
			hi = maxf(hi, _w.under[i])
		if lv == -2:
			break
	if lv >= 0 and x0 + s <= _w.w and z0 + s <= _w.h and (hi - lo <= UNDER_SPREAD or s == 1):
		_box_tiles(x0, z0, s, lv)
	elif s > 1:
		var q := s / 2
		for d in [Vector2i(0, 0), Vector2i(q, 0), Vector2i(0, q), Vector2i(q, q)]:
			_node(x0 + d.x, z0 + d.y, q)

## One box over s x s tiles at terrace `lv`: top under the ground, bottom above the highest underside in
## and around the square, faces that meet lower ground or the void pulled in, faces that meet more ground
## of the same height or higher left out (the neighbour's box continues them).
func _box_tiles(x0: int, z0: int, s: int, lv: int) -> void:
	var top := lv * World.LEVEL - TOP_GAP
	var bottom := -INF
	for z in range(z0 - 1, z0 + s + 1):
		for x in range(x0 - 1, x0 + s + 1):
			if _solid(x, z):
				bottom = maxf(bottom, _w.under[_w.idx(x, z)])
	bottom += BOTTOM_GAP
	if top - bottom < MIN_DEPTH:
		return
	var open := [false, false, false, false]      # -x, +x, -z, +z: meets lower ground or the void
	for k in s:
		open[0] = open[0] or _drops(x0 - 1, z0 + k, lv)
		open[1] = open[1] or _drops(x0 + s, z0 + k, lv)
		open[2] = open[2] or _drops(x0 + k, z0 - 1, lv)
		open[3] = open[3] or _drops(x0 + k, z0 + s, lv)
	var ins := [0.0, 0.0, 0.0, 0.0]
	for f in 4:
		if open[f]: ins[f] = SIDE_INSET
	var a := Vector3(x0 + ins[0], bottom, z0 + ins[2])
	var b := Vector3(x0 + s - ins[1], top, z0 + s - ins[3])
	_add_box(a, b, open)

func _drops(x: int, z: int, lv: int) -> bool:
	return not _solid(x, z) or _w.level[_w.idx(x, z)] < lv

## An axis-aligned box from a (low corner) to b: the top and the faces in `open` (-x, +x, -z, +z).
func _add_box(a: Vector3, b: Vector3, open: Array) -> void:
	var c := _verts.size()
	_verts.append_array(PackedVector3Array([
		Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z),
		Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]))
	var mid := (a + b) * 0.5
	_quad(c, 4, 5, 6, 7, mid)
	var faces := [[0, 3, 7, 4], [1, 5, 6, 2], [0, 4, 5, 1], [3, 2, 6, 7]]
	for f in 4:
		if open[f]:
			_quad(c, faces[f][0], faces[f][1], faces[f][2], faces[f][3], mid)

## Two triangles for the quad of vertices c+i0..c+i3, wound clockwise seen from outside (Godot's front
## face) for a box centred on `mid`.
func _quad(c: int, i0: int, i1: int, i2: int, i3: int, mid: Vector3) -> void:
	var p0 := _verts[c + i0]
	var out := (p0 + _verts[c + i2]) * 0.5 - mid
	if (_verts[c + i1] - p0).cross(_verts[c + i2] - p0).dot(out) > 0.0:
		_idx.append_array(PackedInt32Array([c + i0, c + i2, c + i1, c + i0, c + i3, c + i2]))
	else:
		_idx.append_array(PackedInt32Array([c + i0, c + i1, c + i2, c + i0, c + i2, c + i3]))

## A box inside each large rock that was placed: centred on its bounds, ROCK_FIT of their size.
func _rocks(props: Dictionary) -> void:
	for key in props:
		var g: Dictionary = props[key]
		if not (g["mesh"] is Mesh) or not String(g["label"]).contains("rock"):
			continue
		var ab: AABB = (g["mesh"] as Mesh).get_aabb()
		for item in g["items"]:
			var t: Transform3D = item[0]
			var full := ab.size * t.basis.get_scale()
			if full.x < ROCK_MIN_W or full.y < ROCK_MIN_H:
				continue
			var half := full * ROCK_FIT * 0.5
			var at := t * (ab.position + ab.size * 0.5)
			var rot := t.basis.orthonormalized()
			var c := _verts.size()
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						_verts.append(at + rot * Vector3(half.x * sx, half.y * sy, half.z * sz))
			# corner index = (x < 0 ? 0 : 4) + (y < 0 ? 0 : 2) + (z < 0 ? 0 : 1)
			for q in [[2, 3, 7, 6], [0, 4, 5, 1], [0, 1, 3, 2], [4, 6, 7, 5], [0, 2, 6, 4], [1, 5, 7, 3]]:
				_quad(c, q[0], q[1], q[2], q[3], at)
