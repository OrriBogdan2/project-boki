extends RefCounted
## --meeko-orbit-check: Meeko's sun and raincloud (art pip, warden_anim/pip.json "companions") float round her upper
## body on a mostly horizontal circle instead of riding her shoulders: they are their own unskinned meshes (cut out
## of the body at load, WardenCompanions), 180 degrees apart, one turn in the configured time, with a small vertical
## bob at its own frequency, a speed that is not constant, and never inside her body, head or wings. The faces still
## swap (the mood atlas), the sun's FX points ride the sun, and the pair eases behind her when she runs.

const DT := 1.0 / 30.0
const CELL := 0.06

var bad := 0
var n := 0
var holder: Node3D
var grid := {}

func ok(cond: bool, what: String) -> void:
	n += 1
	print("MEEKOORBIT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	var m := Models.hunter(Arch.weight("tender"), Data.TEAM_COLORS[0], Arch.signature("tender"), "",
		PlayerLook.neutral(), "tender")
	holder.add_child(m)
	var sync := m.get_node_or_null("Warden/Sync")
	ok(sync != null and sync.get("companions") != null, "Meeko's model has floating companions")
	if sync == null or sync.get("companions") == null:
		_done(main)
		return
	sync.set_process(false)
	var wc: WardenCompanions = sync.companions
	var cfg: Dictionary = wc.d
	ok(wc.parts.size() == 2, "a sun and a raincloud (%d parts)" % wc.parts.size())
	_cut(m, wc)
	await _orbit(m, sync, wc, cfg)
	_clearance(m, wc, cfg)
	await _trail(m, sync, wc, cfg)
	m.free()
	_done(main)

func _done(main: Node) -> void:
	print("MEEKOORBIT %d checks, %d failed" % [n, bad])
	print("MEEKOORBIT_DONE %s" % ("PASS" if bad == 0 else "FAIL"))
	main.get_tree().quit()

## The companions are no longer in the skinned body, and keep their faces.
func _cut(m: Node3D, wc: WardenCompanions) -> void:
	var skinned_names: Array = []
	for mi in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).skin == null:
			continue
		for si in (mi as MeshInstance3D).mesh.get_surface_count():
			var src := (mi as MeshInstance3D).mesh.surface_get_material(si)
			skinned_names.append(String(src.resource_name) if src else "")
	var wanted: Array = []
	for p in wc.d["list"]:
		wanted.append_array(p["surfaces"])
	var left := wanted.filter(func(w): return w in skinned_names)
	ok(left.is_empty(), "no companion surface is left in the skinned body (%s)" % str(left))
	for p in wc.parts:
		var part := p as WardenCompanions.Part
		ok(part.node != null and part.node.skin == null and part.node.get_parent() == wc.skel
				and part.node.mesh.get_surface_count() >= 2,
				"%s is an unskinned mesh of its own, not on a shoulder bone" % part.id)
		var face := false
		for si in part.node.mesh.get_surface_count():
			var o := part.node.get_surface_override_material(si) as ShaderMaterial
			face = face or (o != null and o.shader == WardenMood.ATLAS_SHADER)
		ok(face, "%s's face is still on the mood atlas shader" % part.id)

func _pos(m: Node3D, part: WardenCompanions.Part) -> Vector3:
	return m.to_local(part.node.global_position)

## Position over time: a circle round her, two turns, 180 degrees apart, a bob, an uneven speed.
func _orbit(m: Node3D, sync: Node, wc: WardenCompanions, cfg: Dictionary) -> void:
	for i in 20:
		sync.call("_process", DT)
	var period := float(cfg["period"])
	ok(period >= 3.5 and period <= 4.5, "one turn takes %.1f s (3.5 to 4.5)" % period)
	var steps := int(period * 2.0 / DT)
	var series := [[], []]
	var ys := [[], []]
	for i in steps:
		sync.call("_process", DT)
		for k in 2:
			var q := _pos(m, wc.parts[k])
			series[k].append(q)
	var cx := 0.0
	var cz := 0.0
	for k in 2:
		for q in series[k]:
			cx += (q as Vector3).x
			cz += (q as Vector3).z
	cx /= float(series[0].size() * 2)
	cz /= float(series[0].size() * 2)
	var r: Array = cfg["radius"]
	var turned := [0.0, 0.0]
	var speeds := [[], []]
	var first: Array = []
	var worst_fit := 0.0
	for k in 2:
		var last := 0.0
		for i in series[k].size():
			var q: Vector3 = series[k][i]
			var u: float = (q.x - cx) / float(r[0])
			var v: float = (q.z - cz) / float(r[1])
			worst_fit = maxf(worst_fit, absf(sqrt(u * u + v * v) - 1.0))
			var ang := atan2(-v, u)
			if i > 0:
				var dd := wrapf(ang - last, -PI, PI)
				turned[k] += dd
				speeds[k].append(dd / DT)
			else:
				first.append(ang)
			last = ang
			ys[k].append(q.y)
	ok(worst_fit < 0.12, "each sits on the circle (ellipse %.2f x %.2f m) within %.0f%%"
			% [r[0], r[1], worst_fit * 100.0])
	var want := TAU * 2.0 * float(cfg.get("dir", 1))
	ok(absf(turned[0] - want) < 0.5 and absf(turned[1] - want) < 0.5,
			"both go twice round in two periods (%.1f and %.1f rad, want %.1f)" % [turned[0], turned[1], want])
	var apart := absf(wrapf(float(first[0]) - float(first[1]), -PI, PI))
	ok(absf(apart - PI) < 0.2, "the two are 180 degrees apart (%.0f degrees)" % rad_to_deg(apart))
	var lo := 9.0
	var hi := -9.0
	for k in 2:
		var ymin := 9.0
		var ymax := -9.0
		for y in ys[k]:
			ymin = minf(ymin, y)
			ymax = maxf(ymax, y)
		var amp := (ymax - ymin) * 0.5
		lo = minf(lo, amp)
		hi = maxf(hi, amp)
	ok(lo > 0.05 and hi < 0.11, "a little vertical bob, %.3f to %.3f m each way (0.05 to 0.11)" % [lo, hi])
	ok(float(cfg["bob"]) <= 0.1 and float(cfg["bob"]) >= 0.06, "data bob %.2f m is in 0.06 to 0.1" % float(cfg["bob"]))
	ok(wc.parts[0].bob_period != wc.parts[1].bob_period and absf(wc.parts[0].bob_period - float(cfg["period"])) > 0.3,
			"the bob runs at its own frequencies (%.1f s and %.1f s) not the turn's"
			% [wc.parts[0].bob_period, wc.parts[1].bob_period])
	var smin := 99.0
	var smax := -99.0
	for s in speeds[0]:
		smin = minf(smin, absf(s))
		smax = maxf(smax, absf(s))
	ok(smax / maxf(smin, 0.001) > 1.1,
			"the turn's speed breathes (%.2f to %.2f rad/s), not a constant spin" % [smin, smax])
	ok(absf(cx) < 0.1, "the circle is centred on her (mean x %.3f m)" % cx)
	await m.get_tree().process_frame

## Every companion vertex stays out of her body, head and wings over the whole circle and the bob.
func _clearance(m: Node3D, wc: WardenCompanions, cfg: Dictionary) -> void:
	grid.clear()
	for mi in wc.skel.find_children("*", "MeshInstance3D", false, false):
		if (mi as MeshInstance3D).skin == null:
			continue
		var mesh := (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(si)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			for i in range(0, idx.size(), 3):
				var p0 := v[idx[i]]
				var p1 := v[idx[i + 1]]
				var p2 := v[idx[i + 2]]
				var l := maxf(maxf(p0.distance_to(p1), p1.distance_to(p2)), p2.distance_to(p0))
				var k := 1 + int(l / 0.03)
				for a1 in k + 1:
					for b1 in k + 1 - a1:
						_put(p0 + (p1 - p0) * (float(a1) / k) + (p2 - p0) * (float(b1) / k))
	var floor_gap := float(cfg.get("clear_min", 0.0))
	var worst := 9.0
	var who := ""
	for p in wc.parts:
		var part := p as WardenCompanions.Part
		var verts: Array = []
		for si in part.node.mesh.get_surface_count():
			var v: PackedVector3Array = part.node.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for i in range(0, v.size(), 3):
				verts.append(v[i])
		var c: Array = cfg["at"]
		for s in 48:
			var a := part.phase + TAU * s / 48.0
			for bob in [-1.0, 0.0, 1.0]:
				var at := wc.spot(Vector3(c[0], c[1], c[2]), a, bob * float(cfg["bob"]))
				for v in verts:
					var d := _near(at + (v as Vector3), 0.2)
					if d < worst:
						worst = d
						who = part.id
	ok(worst >= floor_gap, ("the companions stay %.3f m (needs %.3f) clear of her body, head and wings"
			+ " round the whole circle (%s closest)") % [worst, floor_gap, who])

func _put(p: Vector3) -> void:
	var k := Vector3i(floori(p.x / CELL), floori(p.y / CELL), floori(p.z / CELL))
	if not grid.has(k):
		grid[k] = []
	grid[k].append(p)

func _near(p: Vector3, cap: float) -> float:
	var k := Vector3i(floori(p.x / CELL), floori(p.y / CELL), floori(p.z / CELL))
	var best := cap * cap
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				var l = grid.get(k + Vector3i(dx, dy, dz))
				if l:
					for q in l:
						best = minf(best, p.distance_squared_to(q))
	return sqrt(best)

## She runs: the circle eases behind her (never further than trail_max), and catches up when she stops; the sun's FX
## points ride the sun, not the shoulder.
func _trail(m: Node3D, sync: Node, wc: WardenCompanions, cfg: Dictionary) -> void:
	var muzzle := WardenGlb.anchor(m, "weapon_muzzle")
	sync.call("_process", DT)
	var sun: WardenCompanions.Part = wc.parts[0]
	var near: float = muzzle.global_position.distance_to(sun.node.global_position) if muzzle else 9.0
	ok(near < 0.2, "the sun's muzzle empty rides the sun (%.3f m from it)" % near)
	var base := wc.centre
	var sc := maxf(wc.skel.global_basis.y.length(), 0.01)
	var worst := 0.0
	var side := 0.0
	for i in 45:
		m.global_position.x += 5.0 * DT
		sync.call("_process", DT)
		var gap := wc._target() - wc.centre
		if gap.length() > worst:
			worst = gap.length()
			side = gap.x
	ok(side > 0.0 and worst > 0.03, "running at 5 m/s the circle trails behind her (%.2f m)" % worst)
	var lim := float(cfg["trail_max"]) * sc
	ok(worst <= lim * 1.05, "and never further behind than its limit (%.2f of %.2f m)" % [worst, lim])
	var lag_now := _lag(m, wc)
	for i in 90:
		sync.call("_process", DT)
	var lag_end := _lag(m, wc)
	ok(lag_end < 0.05 and lag_end < lag_now, "standing again it catches up (%.3f m behind, from %.3f)"
			% [lag_end, lag_now])
	ok(base != wc.centre, "the centre moved with her")
	await m.get_tree().process_frame

func _lag(m: Node3D, wc: WardenCompanions) -> float:
	return (wc._target() - wc.centre).length()
