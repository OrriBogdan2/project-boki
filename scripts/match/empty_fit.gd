class_name EmptyFit
extends RefCounted
## How far the Empty's body reaches out from an upright axis, by direction and height: sampled from the body's own
## meshes once the frame sliders are applied, so a garment drawn as a shell over it (tube) is always outside the
## body, whatever the sliders say. Each part is sampled on its own and gaps between its rings are filled along the
## part, then the parts are combined by their furthest reach; each direction also takes its neighbours' reach, so the
## surface between two sampled directions is covered too.

const SECTORS := 32                 # directions round the axis
const ROW := 0.01                   # m: the height of one row
const COLS := 28                    # most columns all round a tube (drawn at this, never reduced: EmptySlim)
const MIN_COLS := 12
const COL_SPAN := 0.056             # m: a tube's columns are about this far apart round it
const ROW_SPAN := 0.05              # m: and its rows down it
const MAX_ROWS := 14

var y0 := 0.0
var rows := 0
var reach := PackedFloat32Array()   # rows x SECTORS, metres from the axis; 0 where there is no body

## The fit of these parts: [[mesh, transform into the fit's space], ...]. spread false keeps each sector's own reach
## (a measure, not a garment's fit).
static func of(parts: Array, spread := true) -> EmptyFit:
	var fit := EmptyFit.new()
	var lo := INF
	var hi := -INF
	for pc in parts:
		var box: AABB = (pc[1] as Transform3D) * (pc[0] as Mesh).get_aabb()
		lo = minf(lo, box.position.y)
		hi = maxf(hi, box.end.y)
	if parts.is_empty():
		return fit
	fit.y0 = lo
	fit.rows = int(ceil((hi - lo) / ROW)) + 1
	fit.reach.resize(fit.rows * SECTORS)
	fit.reach.fill(0.0)
	for pc in parts:
		fit._add(pc[0], pc[1])
	if spread:
		fit._spread()
	return fit

## The body meshes under node (its direct children) drawn in this material, as parts for of(), placed by `to` on
## top of their own transforms.
static func parts_of(node: Node3D, mat: Material, to := Transform3D.IDENTITY) -> Array:
	var out: Array = []
	for ch in node.get_children():
		var mi := ch as MeshInstance3D
		if mi and mi.material_override == mat and mi.mesh:
			out.append([mi.mesh, to * mi.transform])
	return out

## The body's reach in direction th (radians from +X toward +Z) at height y.
func at(th: float, y: float) -> float:
	if rows == 0:
		return 0.0
	var fs := fposmod(th / TAU, 1.0) * SECTORS - 0.5
	var fr := clampf((y - y0) / ROW, 0.0, rows - 1.0)
	var s0 := int(floor(fs))
	var r0 := mini(int(fr), rows - 2) if rows > 1 else 0
	var ts := fs - s0
	var tr := clampf(fr - r0, 0.0, 1.0)
	var r1 := mini(r0 + 1, rows - 1)
	var a := lerpf(_cell(r0, s0), _cell(r0, s0 + 1), ts)
	var b := lerpf(_cell(r1, s0), _cell(r1, s0 + 1), ts)
	return lerpf(a, b, tr)

## A garment round the body from height y_top down to y_bot, `off` m out from it, over the directions u0..u1 of a
## turn (0..1 wraps right round; front is u = 0.75). One-sided: its inside never shows, the void body fills any
## opening. flare(v) adds metres down it.
func tube(y_top: float, y_bot: float, off: float, u0 := 0.0, u1 := 1.0, flare := Callable()) -> ArrayMesh:
	var tube_rows := clampi(int(absf(y_top - y_bot) / ROW_SPAN), 2, MAX_ROWS)
	var half := absf(y_top - y_bot) / tube_rows * 0.5
	var fn := func(u: float, v: float) -> Vector3:
		var th := lerpf(u0, u1, u) * TAU
		var y := lerpf(y_top, y_bot, v)
		var r := reach_near(th, y, half, minf(y_top, y_bot), maxf(y_top, y_bot)) + off
		r += float(flare.call(v)) if flare.is_valid() else 0.0
		return Vector3(cos(th) * r, y, sin(th) * r)
	var round_cols := clampi(int(TAU * widest(lerpf(y_top, y_bot, 0.5)) / COL_SPAN), MIN_COLS, COLS)
	var tube_cols := maxi(MIN_COLS, int(round_cols * (u1 - u0)))
	var ao := func(_u: float, v: float) -> float: return lerpf(0.85, 1.0, smoothstep(0.0, 0.25, minf(v, 1.0 - v)))
	return HeroKit.surf("", fn, tube_cols, tube_rows, ao)

## The furthest reach in direction th within `half` m of height y (kept between lo and hi): a shell whose rows are
## that far apart and each this far out never cuts through a bulge between two rows.
func reach_near(th: float, y: float, half: float, lo := -INF, hi := INF) -> float:
	var out := 0.0
	var steps := maxi(1, int(ceil(half * 2.0 / ROW)))
	for k in steps + 1:
		out = maxf(out, at(th, clampf(y - half + half * 2.0 * k / steps, lo, hi)))
	return out

## The widest reach at height y, in any direction.
func widest(y: float) -> float:
	var out := 0.0
	for s in SECTORS:
		out = maxf(out, at((s + 0.5) / SECTORS * TAU, y))
	return out

func _cell(row: int, sector: int) -> float:
	return reach[row * SECTORS + posmod(sector, SECTORS)]

## One part: the furthest vertex per row and direction, then its own gaps filled along each direction.
func _add(mesh: Mesh, xf: Transform3D) -> void:
	var own := PackedFloat32Array()
	own.resize(rows * SECTORS)
	own.fill(-1.0)
	for sidx in mesh.get_surface_count():
		for p in mesh.surface_get_arrays(sidx)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			var q := xf * p
			var row := clampi(int(round((q.y - y0) / ROW)), 0, rows - 1)
			var sector := int(fposmod(atan2(q.z, q.x) / TAU, 1.0) * SECTORS) % SECTORS
			var k := row * SECTORS + sector
			own[k] = maxf(own[k], Vector2(q.x, q.z).length())
	for sector in SECTORS:
		var last := -1
		for row in rows:
			var k := row * SECTORS + sector
			if own[k] < 0.0:
				continue
			if last >= 0 and row - last > 1:
				var a := own[last * SECTORS + sector]
				for fill in range(last + 1, row):
					own[fill * SECTORS + sector] = lerpf(a, own[k], float(fill - last) / (row - last))
			last = row
	for k in own.size():
		reach[k] = maxf(reach[k], own[k])

## Each direction takes its neighbours' reach (so the body between two directions is inside), and each row its
## neighbours' (so a ring that fell between two rows is inside too).
func _spread() -> void:
	var out := reach.duplicate()
	for row in rows:
		for s in SECTORS:
			var m := 0.0
			for dr in [-1, 0, 1]:
				var rr: int = clampi(row + dr, 0, rows - 1)
				for ds in [-1, 0, 1]:
					m = maxf(m, reach[rr * SECTORS + posmod(s + ds, SECTORS)])
			out[row * SECTORS + s] = m
	reach = out
