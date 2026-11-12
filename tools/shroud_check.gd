extends RefCounted
## --shroud-check: the Empty's ten shrouds (item 153). The data the creator wires to (labels, ranges, bad values, old
## saves); every cut on both sexes within the Hunter budget, skinned, its weights whole; no two cuts share a shape at
## the match camera (the overlap of their flat silhouettes); and in the poses (idle, a run's full stride, jump, crouch,
## glide) no leg comes through a floor-length cut and no arm through a cut that covers the arms. (Not the arms in a
## glide: the hands go up to the lines overhead, out past the cloth, in the sleeves' colour.)
## SHROUD_TABLE lines print each cut's triangles for the art report.

const MAX_TRIS := 15000           # Hunter budget (S1), everything worn
const MAX_MATS := 8
const MAX_OVERLAP := 0.86         # the most two cuts' match-camera silhouettes may share (intersection / union)
const GRID := 72                  # cells of the silhouette raster
const LIMB_MARGIN := 0.0          # m: how far a limb's axis must stay inside the cloth
## Which cuts hide which limb (the others show it on purpose): the check holds these inside the cloth.
const COVER_LEGS := [0, 5]
const COVER_ARMS := [0, 4]
const CAM_PITCH := 66.0
const POSES := ["idle", "run", "jump", "crouch", "glide"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("SHROUD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	_data()
	_builds()
	_shapes()
	await _poses(main)
	print("SHROUD_CHECK %s" % ("FAILED %d" % bad if bad > 0 else "PASSED"))
	main.get_tree().quit(1 if bad > 0 else 0)

func _build(lk: Dictionary) -> Node3D:
	return Models.hunter("medium", Data.TEAM_COLORS[0], "", "", _look(lk))

func _look(lk: Dictionary) -> Dictionary:
	var look := {"unmasked": true}
	look.merge(lk, true)
	return Unmasked.clean(look)

func _data() -> void:
	ok(Shrouds.STYLES.size() >= 10 and Unmasked.SHROUDS == Shrouds.LABELS, "at least ten cuts, in the creator's row")
	var same := true
	var ids := {}
	for i in Shrouds.STYLES.size():
		same = same and Shrouds.STYLES[i]["name"] == Shrouds.LABELS[i]
		ids[Shrouds.STYLES[i]["id"]] = true
	ok(same and ids.size() == Shrouds.STYLES.size(), "labels match the table and every id is its own")
	ok(Shrouds.LABELS[1] == "Wrap" and Shrouds.LABELS[2] == "Tatters", "old saves' Wrap and Tatters keep their index")
	var junk := Shrouds.settings({"shroud": 99, "hood": "x", "trim": -3, "accent": 500, "accessory": null})
	ok(int(junk["style"]) == Shrouds.STYLES.size() - 1 and int(junk["trim"]) == 0 and int(junk["accessory"]) == 0
		and int(junk["accent"]) == Unmasked.COLOURS.size() - 1, "bad values land in range (%s)" % str(junk))
	var dflt := Shrouds.settings({})
	ok(int(dflt["style"]) == 0 and int(dflt["hood"]) == 1 and int(dflt["accent"]) == Shrouds.NO_ACCENT,
		"a look without the new keys wears the default cut, hood up, plain, no accent")
	ok(int(Shrouds.settings({"shroud": 1, "hood": 1})["hood"]) == -1, "a cut without a hood ignores the hood key")
	var kept := Unmasked.clean({"unmasked": true, "shroud": 7, "hood": 0, "trim": 3, "accent": 2, "accessory": 4})
	ok(int(kept["shroud"]) == 7 and int(kept["trim"]) == 3 and int(kept["accent"]) == 2 and int(kept["accessory"]) == 4,
		"Unmasked.clean keeps the new keys")

func _builds() -> void:
	var worst := 0
	for g in 2:
		for s in Shrouds.STYLES.size():
			var loaded := {"shroud": s, "gender": g, "trim": 4, "accent": 3, "accessory": 4, "hood": 1}
			var m := _build(loaded)
			var tris := _tris(m)
			worst = maxi(worst, tris)
			var mats := _worn_mats(m)
			var skin := m.find_child("ShroudBones", true, false) as ShroudSkin
			ok(skin != null and skin.get_child_count() > 0 and _whole_weights(skin) and mats <= MAX_MATS,
				"%s (%s) is skinned, its weights whole, %d materials" % [Shrouds.LABELS[s], "FM"[g], mats])
			if g == 1:
				var plain := _build({"shroud": s, "gender": 1})
				print("SHROUD_TABLE %s plain=%d loaded=%d cloth=%d" % [Shrouds.LABELS[s], _tris(plain), tris,
					_tris(plain.find_child("ShroudBones", true, false))])
				plain.free()
			m.free()
	_breakdown()
	for s in Shrouds.STYLES.size():
		for a in range(1, Shrouds.ACCESSORIES.size()):
			for hood in 2:
				var m := _build({"shroud": s, "gender": 1, "trim": 4, "accent": 3, "accessory": a, "hood": hood})
				worst = maxi(worst, _tris(m))
				m.free()
	ok(worst <= MAX_TRIS, "every cut, trim and accessory is within %d tris (worst %d)" % [MAX_TRIS, worst])

## The materials on what the body wears: the glider and the weapon are their own items.
func _worn_mats(m: Node3D) -> int:
	var seen := {}
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var path := str(m.get_path_to(mi))
		if not (path.contains("Glider") or path.contains("Gun") or mi.name == "TeamRing"):
			seen[(mi as MeshInstance3D).material_override] = true
	return seen.size()

## Where a body's triangles go, heaviest first (SHROUD_PART lines).
func _breakdown() -> void:
	var m := _build({"shroud": 0, "gender": 1})
	var rows: Array = []
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		rows.append([_tris(g), str(m.get_path_to(g))])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for r in rows.slice(0, 26):
		print("SHROUD_PART %d %s" % [r[0], r[1]])
	var t0 := Time.get_ticks_usec()
	var again := _build({"shroud": 3, "gender": 0, "build": 2})
	print("SHROUD_BUILD_MS %.1f" % ((Time.get_ticks_usec() - t0) / 1000.0))
	again.free()
	m.free()

func _tris(n: Node) -> int:
	var total := 0
	var list: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		list.append(n)
	for mi in list:
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null or String((mi as Node).name) == "TeamRing":
			continue
		for i in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(i)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			if idx != null:
				total += (idx as PackedInt32Array).size() / 3
			else:
				total += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total

func _whole_weights(skin: ShroudSkin) -> bool:
	for mi in skin.get_children():
		var arr: Array = ((mi as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
		var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		if ws.size() != (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * 4:
			return false
		for i in range(0, ws.size(), 4):
			if absf(ws[i] + ws[i + 1] + ws[i + 2] + ws[i + 3] - 1.0) > 0.01:
				return false
			if bs[i] >= ShroudSkin.COUNT:
				return false
	return true

# --------------------------------------------------------------------------------------------- the shapes
## Each cut's flat silhouette as the match camera sees it, and how much of it any other cut shares.
func _shapes() -> void:
	var sil: Array = []
	for s in Shrouds.STYLES.size():
		var m := _build({"shroud": s, "gender": 1})
		sil.append(_raster(m))
		m.free()
	var worst := 0.0
	var pair := ""
	for a in sil.size():
		for b in range(a + 1, sil.size()):
			var both := 0
			var either := 0
			for i in GRID * GRID:
				both += 1 if sil[a][i] and sil[b][i] else 0
				either += 1 if sil[a][i] or sil[b][i] else 0
			var iou := float(both) / maxf(1.0, float(either))
			if iou > worst:
				worst = iou
				pair = "%s / %s" % [Shrouds.LABELS[a], Shrouds.LABELS[b]]
	ok(worst <= MAX_OVERLAP, "no two cuts share more than %.2f of their silhouette (closest %.2f: %s)"
		% [MAX_OVERLAP, worst, pair])

## Fills the model's triangles into a grid in the camera's plane (facing as the contact sheet does).
func _raster(m: Node3D) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(GRID * GRID)
	m.rotation.y = PI * 0.82
	var p := deg_to_rad(CAM_PITCH)
	var view := Basis(Vector3.RIGHT, -p)     # world to camera axes: drop z
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		if g.mesh == null or g.name == "TeamRing" or not _shown(g, m):
			continue
		var xf := _chain(g, m.get_parent())
		for sf in g.mesh.get_surface_count():
			var arr: Array = g.mesh.surface_get_arrays(sf)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			if idx == null or vs.size() == 0 or String(g.get_path()).contains("Glider"):
				continue
			var cell := PackedVector2Array()
			cell.resize(vs.size())
			for i in vs.size():
				var q: Vector3 = view.inverse() * (xf * vs[i])
				cell[i] = Vector2((q.x + 1.8) / 3.6, (2.0 - q.y) / 3.6) * GRID
			var ii: PackedInt32Array = idx
			for t in range(0, ii.size(), 3):
				_fill(out, cell[ii[t]], cell[ii[t + 1]], cell[ii[t + 2]])
	return out

func _shown(n: Node, top: Node) -> bool:
	while n != top and n != null:
		if n is Node3D and not (n as Node3D).visible:
			return false
		n = n.get_parent()
	return true

func _chain(n: Node, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while n != top and n != null:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf

static func _fill(out: PackedByteArray, a: Vector2, b: Vector2, c: Vector2) -> void:
	var x0 := clampi(int(minf(a.x, minf(b.x, c.x))), 0, GRID - 1)
	var x1 := clampi(int(ceilf(maxf(a.x, maxf(b.x, c.x)))), 0, GRID - 1)
	var y0 := clampi(int(minf(a.y, minf(b.y, c.y))), 0, GRID - 1)
	var y1 := clampi(int(ceilf(maxf(a.y, maxf(b.y, c.y)))), 0, GRID - 1)
	var d := (b - a).cross(c - a)
	if absf(d) < 1e-5:
		return
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var u := (p - a).cross(c - a) / d
			var v := (b - a).cross(p - a) / d
			if u >= 0.0 and v >= 0.0 and u + v <= 1.0:
				out[y * GRID + x] = 1

# ---------------------------------------------------------------------------------------------- the poses
## Steps a body through each pose and tests its limbs against the cloth as skinned in that frame: a limb point is
## inside when some cloth at its height and bearing stands at least as far from the body's axis as it does.
func _poses(main: Node) -> void:
	var host := Node3D.new()
	main.add_child(host)
	for s in Shrouds.STYLES.size():
		var legs_on: bool = s in COVER_LEGS
		var arms_on: bool = s in COVER_ARMS
		if not legs_on and not arms_on:
			continue
		var m := _build({"shroud": s, "gender": 1})
		host.add_child(m)
		var an := HunterAnim.new(m)
		var skin := m.find_child("ShroudBones", true, false) as ShroudSkin
		var pokes := {}
		for st in POSES:
			pokes[st] = 0
			for k in 90:
				an.update(1.0 / 60.0, _state(st, m))
				if k >= 40 and k % 4 == 0:
					skin.sync_pose()
					pokes[st] += _pokes(m, skin, legs_on, arms_on and st != "glide")
		var total := 0
		for st in pokes:
			total += int(pokes[st])
		ok(total == 0, "%s holds its limbs in every pose (%s)" % [Shrouds.LABELS[s], str(pokes)])
		m.queue_free()
		await main.get_tree().process_frame
	host.queue_free()

func _state(st: String, m: Node3D) -> Dictionary:
	var fwd := Vector3(-sin(m.rotation.y), 0, -cos(m.rotation.y))
	var s := {"fired": 99.0, "face": m.rotation.y, "grounded": true}
	match st:
		"run": s["vel"] = fwd * 5.5
		"jump":
			s["grounded"] = false
			s["vel"] = fwd * 2.0 + Vector3.UP * 3.0
		"crouch": s["crouch"] = 1.0
		"glide":
			s["grounded"] = false
			s["gliding"] = true
			s["vel"] = fwd * 7.0 + Vector3.DOWN * 2.0
	return s

func _pokes(m: Node3D, skin: ShroudSkin, legs_on: bool, arms_on: bool) -> int:
	var inv := skin.global_transform.affine_inverse()
	var pts: Array = []
	if legs_on:
		for nm in ["LegL", "LegR"]:
			var leg := m.get_node("Rig/Legs/" + nm) as Node3D
			pts.append(inv * leg.get_node("Knee").global_position)
			pts.append(inv * (leg.get_node("Knee") as Node3D).to_global(Vector3(0, -0.14, 0)))
	if arms_on:
		for sd in ["L", "R"]:
			var el := m.get_node("Rig/Torso/Arm%sPivot/Elbow" % sd) as Node3D
			pts.append(inv * el.global_position)
			pts.append(inv * (el.get_node("Hand") as Node3D).global_position)
	var cloth := _skinned(skin)
	var n := 0
	for p in pts:
		if not _inside(p, cloth):
			n += 1
	return n

## The cloth's vertices as the bones hold them now (a sample of them: one in three).
func _skinned(skin: ShroudSkin) -> PackedVector3Array:
	var out := PackedVector3Array()
	var poses: Array[Transform3D] = []
	for b in ShroudSkin.COUNT:
		poses.append(skin.get_bone_pose(b))
	for mi in skin.get_children():
		var arr: Array = ((mi as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		for i in range(0, vs.size(), 3):
			var q := Vector3.ZERO
			for k in 4:
				if ws[i * 4 + k] > 0.0:
					q += (poses[bs[i * 4 + k]] * vs[i]) * ws[i * 4 + k]
			out.append(q)
	return out

static func _inside(p: Vector3, cloth: PackedVector3Array) -> bool:
	var at := Vector2(p.x, p.z)
	var want := at.length() + LIMB_MARGIN
	if want < 0.12:
		return true
	var bearing := at.angle()
	for q in cloth:
		if absf(q.y - p.y) < 0.14:
			var c := Vector2(q.x, q.z)
			if c.length() >= want and absf(wrapf(c.angle() - bearing, -PI, PI)) < 0.5:
				return true
	return false
