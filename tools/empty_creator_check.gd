extends RefCounted
## --empty-creator-check: the Empty's creator (docs/CHARACTER_CREATOR.md). A look saves and loads back exactly, per
## save slot; older saves (Short / Tall steps, a shroud, the detailed creator) migrate and a second run changes
## nothing; every outfit slot accepts empty and every item builds alone; no corner of the body sliders, for either
## sex, pokes the void body through any outfit (and the bare body is all void with an outline); a woman's frame is
## shorter, narrower in the shoulders and wider in the hips than any man's; the creator panel (tabs, undo, presets,
## randomize, gamepad focus) hands back the look it shows. Never touches the dev save.

const TOL := 0.003          # m: how far a body point may sit outside the garment over it
const COVER := 0.04         # m: a garment face this near a body point, right over it, is the garment it is under
const CELL := 0.05          # m: the spatial hash's cell (faces are found from the 27 cells round a point)
const FACING := 0.5         # a garment face over the body looks the same way as the body there at least this much
const HIDDEN := 0.004        # m: a body point this far inside its region's outer reach is inside the body
const SURFACE := 0.6        # a garment face's corners' normals agree with it at least this much
const STRIDE := 3           # every third body vertex: neighbours are a few mm apart
const MIN_ITEMS := 6
const POSED := ["Rig/Torso", "Rig/Torso/Skirt", "Rig/Torso/HeadPivot", "Rig/Legs/LegL", "Rig/Legs/LegR",
	"Rig/Legs/LegL/Knee",
	"Rig/Legs/LegR/Knee", "Rig/Torso/ArmLPivot", "Rig/Torso/ArmRPivot", "Rig/Torso/ArmLPivot/Elbow",
	"Rig/Torso/ArmRPivot/Elbow", "Rig/Torso/ArmLPivot/Elbow/Hand", "Rig/Torso/ArmRPivot/Elbow/Hand"]
const TRI_BUDGET := 15000   # the Hunter budget (S1), everything worn
const SLOT_PATH := "user://empty_creator_check_%d.json"

var bad := 0
var worst := {"m": 0.0, "what": ""}

func ok(cond: bool, what: String) -> void:
	print("EMPTY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	seed(1111)
	_round_trip()
	_migration()
	_empty_slots()
	_frames()
	_no_clipping()
	await _panel(main)
	Save.d = Save.fresh()
	print("EMPTY CHECK DONE, failures: %d" % bad)
	main.get_tree().quit()

func _build(lk: Dictionary) -> Node3D:
	return Models.hunter("medium", Data.TEAM_COLORS[0], "", "", lk)

# ---------------------------------------------------------------- save and load
func _round_trip() -> void:
	var same := true
	for i in 12:
		var lk := Unmasked.clean(Unmasked.random_look())
		Save.d = Save.fresh()
		Save.d["look"] = lk
		_write(SLOT_PATH % 1, Save.d)
		Save.load_from(SLOT_PATH % 1)
		if Save.d["look"] != lk or Unmasked.clean(lk) != lk:
			var after: Dictionary = Save.d["look"]
			var diff := lk.keys().filter(func(k): return not after.has(k) or str(after[k]) != str(lk[k]))
			diff.append_array(after.keys().filter(func(k): return not lk.has(k)))
			var was := diff.map(func(k): return [lk.get(k), after.get(k)])
			print("EMPTY  (round trip differs in %s: %s)" % [str(diff), str(was)])
			same = false
	ok(same, "12 random looks (frame, outfit, colours, face) save and load back exactly, and clean to themselves")
	var a := Unmasked.clean(Unmasked.random_look())
	var b := Unmasked.default_look()
	for k in [[1, a], [2, b]]:
		var d := Save.fresh()
		d["look"] = k[1]
		_write(SLOT_PATH % k[0], d)
	Save.load_from(SLOT_PATH % 1)
	var got_a: Dictionary = Save.d["look"]
	Save.load_from(SLOT_PATH % 2)
	ok(got_a == a and Save.d["look"] == b, "each save slot (profile) keeps its own look")
	for n in [1, 2]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOT_PATH % n))

func _write(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()

# ---------------------------------------------------------------- old saves
func _migration() -> void:
	var old := {"unmasked": true, "gender": 0, "height": 2, "build": 0, "shroud": 4, "colour": 5, "accent": 2,
		"hood": 1, "trim": 3, "accessory": 2, "hollow": 1, "glow": 2, "ghost": 3, "aura": 2, "marks": []}
	var u := Unmasked.clean(old)
	var fr: Dictionary = u["frame"]
	ok(not u.has("height") and not u.has("build") and fr["height"] > 0.8 and fr["build"] < 0.2,
		"an Empty saved Tall and Slight gets the frame sliders closest to them (%s)" % str(fr))
	ok(int(u["shroud"]) == 4 and int(u["colour"]) == 5 and int(u["accent"]) == 2 and int(u["trim"]) == 3
		and int(u["accessory"]) == 2 and int(u["hollow"]) == 1 and int(u["aura"]) == 2,
		"it keeps its shroud (now the cloak layer), colours, accessory and face")
	var layers_empty := EmptyWear.LAYERS.all(func(id: String) -> bool: return EmptyWear.item(u, id) == EmptyWear.NONE)
	ok(layers_empty and int(u["hair"]) == 0, "it gains the new layers empty and no hair: it looks as it did")
	var detailed := {"race": 2, "gender": 0, "body": 2, "face": 4, "skin": 5, "outfit": 1, "hair": 3, "glider": "kite"}
	var d2 := Unmasked.clean(detailed)
	ok(int(d2["shroud"]) >= 0 and float(d2["frame"]["build"]) > 0.8 and String(d2["glider"]) == "kite",
		"a look from the detailed creator keeps a cloak, its build and its glider")
	var file := Save.fresh()
	file["v"] = Save.VERSION - 1
	file["look"] = old
	_write(SLOT_PATH % 3, file)
	Save.load_from(SLOT_PATH % 3)
	var once: Dictionary = Save.d["look"].duplicate(true)
	ok(Unmasked.is_look(once) and once.has("frame") and once.has("wear"), "an older save file loads with the new look")
	var data := {"look": once.duplicate(true)}
	Unmasked.migrate(data)
	ok(data["look"] == once, "migrating twice changes nothing")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOT_PATH % 3))
	var junk := Unmasked.clean({"unmasked": true, "frame": {"height": "x", "hips": 9}, "wear": {"top": [99, -4],
		"shoes": "no"}, "shroud": 99, "acc_col": 1e9})
	ok(float(junk["frame"]["hips"]) == 1.0 and float(junk["frame"]["height"]) == 0.5
		and EmptyWear.item(junk, "top") == EmptyWear.items("top").size() - 1 and int(junk["wear"]["top"][1]) == 0
		and EmptyWear.item(junk, "shoes") == EmptyWear.NONE, "odd frame and outfit data lands in range")

# ---------------------------------------------------------------- empty slots, every item
func _empty_slots() -> void:
	var bare := _build(Unmasked.default_look())
	var mats := _mats(bare)
	var all_void := mats.all(func(m: Material) -> bool: return _is_body(m) or _is_head(m))
	ok(all_void and mats.any(_is_body), "a new Empty is the bare void body: only the void and its outline")
	var ink: Material = mats.filter(_is_body)[0].next_pass
	ok(ink is ShaderMaterial and (ink as ShaderMaterial).shader == Models.OUTLINE, "the bare body has an outline pass")
	bare.free()
	var counts := true
	var builds := 0
	var total := 0
	for s in EmptyWear.slots():
		var id := String(s["id"])
		var n := EmptyWear.items(id).size()
		counts = counts and n >= MIN_ITEMS and (s["cols"] as Array).size() >= 2
		for it in range(EmptyWear.NONE, n):
			var lk := Unmasked.default_look()
			EmptyWear.set_item(lk, id, it)
			var m := _build(Unmasked.clean(lk))
			var worn := _mats(m).any(func(mm: Material) -> bool: return not (_is_body(mm) or _is_head(mm)))
			if worn == (it != EmptyWear.NONE) and EmptyWear.item(Unmasked.clean(lk), id) == it:
				builds += 1
			else:
				print("EMPTY  (did not build as asked: %s item %d)" % [id, it])
			total += 1
			m.free()
	ok(counts, "every slot offers at least %d items and 2-3 colour slots" % MIN_ITEMS)
	ok(builds == total, "every item of every slot builds alone, and every slot empty shows nothing (%d / %d)"
		% [builds, total])
	var full := Unmasked.default_look()
	for id in EmptyWear.LAYERS:
		EmptyWear.set_item(full, id, 1)
	EmptyWear.set_item(full, "back", 0)
	for id in EmptyWear.LAYERS + ["back"]:
		EmptyWear.set_item(full, id, EmptyWear.NONE)
	ok(Unmasked.clean(full) == Unmasked.default_look(), "taking every layer off gives the bare Empty back")
	var heavy := Unmasked.default_look()
	for id in EmptyWear.LAYERS:
		EmptyWear.set_item(heavy, id, {"top": 5, "bottom": 3, "shoes": 2, "gloves": 3, "head": 0}[id])
	EmptyWear.set_item(heavy, "back", 0)
	EmptyWear.set_item(heavy, "accessory", 4)
	var hm := _build(Unmasked.clean(heavy))
	var tris := _tris(hm)
	ok(tris <= TRI_BUDGET, "the heaviest outfit stays in the Hunter budget (%d / %d triangles)" % [tris, TRI_BUDGET])
	hm.free()

func _tris(m: Node3D) -> int:
	var out := 0
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null or _under(mi, ["Glider", "Gun", "TeamRing"], m):
			continue
		for s in mesh.get_surface_count():
			var idx: PackedInt32Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
			var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			out += (idx.size() if not idx.is_empty() else verts.size()) / 3
	return out

## The materials a model is drawn in, not counting its glider, weapon and team ring.
func _mats(m: Node3D) -> Array:
	var out: Array = []
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		if _under(mi, ["Glider", "Gun", "TeamRing"], m):
			continue
		var mat := (mi as MeshInstance3D).material_override
		var mesh := (mi as MeshInstance3D).mesh
		if mat and mesh and mesh.get_surface_count() > 0 and not mat in out:
			out.append(mat)
	return out

func _is_body(m: Material) -> bool:
	return m is ShaderMaterial and (m as ShaderMaterial).shader == EmptyWear.VOID_BODY

func _is_head(m: Material) -> bool:
	return m is ShaderMaterial and (m as ShaderMaterial).shader == Unmasked.VOID_SHADER

# ---------------------------------------------------------------- male and female frames
func _frames() -> void:
	var rules: Dictionary = EmptyFrame.rules()["frame"]
	var mid := func(k: String, sex: String) -> float: return (float(rules[k][sex][0]) + float(rules[k][sex][1])) * 0.5
	var apart := float(rules["shoulders"]["f"][1]) < float(rules["shoulders"]["m"][0])
	apart = apart and float(rules["hips"]["f"][0]) > float(rules["hips"]["m"][1])
	ok(apart and mid.call("height", "f") < mid.call("height", "m") * 0.95,
		"at any sliders a woman's shoulders are narrower and her hips wider than any man's; she is shorter on average")
	var woman := _build(Unmasked.default_look().merged({"gender": 0}, true))
	var man := _build(Unmasked.default_look())
	var arm := func(m: Node3D) -> float: return absf((m.get_node("Rig/Torso/ArmLPivot") as Node3D).position.x)
	var hip := func(m: Node3D) -> float: return absf((m.get_node("Rig/Legs/LegL") as Node3D).position.x)
	ok(arm.call(woman) < arm.call(man) * 0.88 and hip.call(woman) > hip.call(man) * 1.08
		and String(woman.get_meta("stance")) == "empty_f" and String(man.get_meta("stance")) == "empty_m",
		"built, her shoulders are narrower, her hips wider and her stance her own (%.3f / %.3f, %.3f / %.3f)" % [
			arm.call(woman), arm.call(man), hip.call(woman), hip.call(man)])
	woman.free()
	man.free()

# ---------------------------------------------------------------- clipping
## Every corner of the sliders that change the body's shape (build, shoulders, hips; height and head size, which scale
## the whole model or the head with all it wears, alternate between their ends), both sexes, in seven outfits that
## between them wear every item of every layer: in the rest pose no body point pokes out past the garment over it.
func _no_clipping() -> void:
	var looks := 0
	var t0 := Time.get_ticks_msec()
	for g in 2:
		for corner in 8:
			for outfit in 7:
				var lk := Unmasked.default_look()
				lk["gender"] = g
				var fr: Dictionary = lk["frame"]
				fr["build"] = float(corner & 1)
				fr["shoulders"] = float((corner >> 1) & 1)
				fr["hips"] = float((corner >> 2) & 1)
				fr["height"] = float((corner + outfit) & 1)
				fr["head"] = float(((corner + outfit) >> 1) & 1)
				for id in EmptyWear.LAYERS:
					EmptyWear.set_item(lk, id, outfit % EmptyWear.items(id).size())
				var m := _build(Unmasked.clean(lk))
				_unpose(m)
				_pokes(m, "%s corner %d outfit %d" % ["F" if g == 0 else "M", corner, outfit])
				m.free()
				looks += 1
	var found: Dictionary = worst.duplicate()
	worst = {"m": 0.0, "what": ""}
	_measure_bites(found)
	worst = found
	var msg := "no shape corner (x2 sexes x 7 outfits, %d looks, %d ms) clips through an outfit (worst %.1f mm: %s)"
	ok(worst["m"] <= TOL, msg % [looks, Time.get_ticks_msec() - t0, worst["m"] * 1000.0, worst["what"]])

## The joints straight, as the outfit was fitted (Models.hunter hands the model over in its stance: knees and elbows
## bent, legs apart). Clothes are rigid per joint, so a bent joint can still fold a hem into the next part.
func _unpose(m: Node3D) -> void:
	for nm in POSED:
		var n := m.get_node_or_null(nm) as Node3D
		if n:
			n.rotation = Vector3.ZERO

## The measure itself: a body grown 3 cm under a long-sleeved top must read as clipping through it.
func _measure_bites(found: Dictionary) -> void:
	var lk := Unmasked.default_look()
	EmptyWear.set_item(lk, "top", 2)
	var m := _build(Unmasked.clean(lk))
	_unpose(m)
	var torso := m.get_node("Rig/Torso") as Node3D
	for ch in torso.get_children():
		var mi := ch as MeshInstance3D
		if mi and _is_body(mi.material_override):
			mi.mesh = EmptyWearKit.grown(mi.mesh, 0.03, -INF, INF)
	_pokes(m, "grown")
	ok(float(worst["m"]) > 0.01, "the clipping measure catches a body grown through its top (%.1f mm; %d pairs)"
		% [float(worst["m"]) * 1000.0, int(found.get("pairs", 0))])
	m.free()

## The furthest any body point sits outside the garment over it. A garment face is over a body point when the point
## projects inside the triangle, the face looks the same way as the body there (the garment's outside, not its
## lining) and lies within COVER of it; of those, the nearest decides: a point in front of it pokes through.
func _pokes(m: Node3D, what: String) -> void:
	var body := [PackedVector3Array(), PackedVector3Array(), PackedInt32Array()]
	var tris: Array = []        # [a, b, c, normal, region]
	var skin := {}              # region root -> [model to root space, the body's parts there]
	var roots: Array = []       # each body mesh's region root, by names index
	var names: Array = []
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		if _under(mi, EmptySlim.SKIP, m) or (mi as MeshInstance3D).mesh == null:
			continue
		var kind := _kind((mi as MeshInstance3D).material_override)
		names.append(_region(mi, m))
		if kind == "body":
			_points((mi as MeshInstance3D).mesh, _xf(mi, m), body, names.size() - 1)
			var root := _region_root(mi, m)
			var into := _xf(root, m).affine_inverse()
			var group: Array = skin.get(root, [into, []])
			(group[1] as Array).append([(mi as MeshInstance3D).mesh, into * _xf(mi, m)])
			skin[root] = group
			roots.resize(names.size())
			roots[names.size() - 1] = root
		elif kind == "wear":
			_faces((mi as MeshInstance3D).mesh, _xf(mi, m), tris, names[-1])
	var grid := _hash(tris)
	var reach := {}
	for root in skin:
		reach[root] = EmptyFit.of(skin[root][1], false)
	for i in range(0, body[0].size(), STRIDE):
		var at: Vector3 = body[0][i]
		var root: Node3D = roots[body[2][i]]
		var local: Vector3 = (skin[root][0] as Transform3D) * at
		if Vector2(local.x, local.z).length() < (reach[root] as EmptyFit).at(atan2(local.z, local.x), local.y) - HIDDEN:
			continue      # inside the body (a limb's rounded end inside the next joint, the thumb's root in the palm)
		var past := _past(grid, tris, at, body[1][i], names[body[2][i]])
		worst["pairs"] = int(worst.get("pairs", 0)) + (1 if past > -INF else 0)
		var where := "%s %s at %s" % [what, names[body[2][i]], str(at.snapped(Vector3.ONE * 0.001))]
		if past > float(worst["m"]):
			worst["m"] = past
			worst["what"] = where

## Faces by the cell their middle is in.
func _hash(faces: Array) -> Dictionary:
	var grid := {}
	for j in faces.size():
		var t: Array = faces[j]
		var cell := Vector3i((((t[0] as Vector3) + t[1] + t[2]) / (3.0 * CELL)).floor())
		var list: PackedInt32Array = grid.get(cell, PackedInt32Array())
		list.append(j)
		grid[cell] = list      # (a packed array is a value: store it back)
	return grid

## How far p lies in front of the nearest garment face over it (-INF: none over it).
func _past(grid: Dictionary, tris: Array, p: Vector3, n: Vector3, part: String) -> float:
	var c := Vector3i((p / CELL).floor())
	var best := COVER
	var out := -INF
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				for j in grid.get(c + Vector3i(dx, dy, dz), PackedInt32Array()):
					var t: Array = tris[j]
					var fn: Vector3 = t[3]
					if fn.dot(n) < FACING or not _covers(t[4], part):
						continue
					var d := (p - (t[0] as Vector3)).dot(fn)
					if absf(d) < best and _inside(p - fn * d, t[0], t[1], t[2]):
						best = absf(d)
						out = d
	return out

func _inside(q: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var v0 := b - a
	var v1 := c - a
	var v2 := q - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var den := d00 * d11 - d01 * d01
	if den <= 1e-12:
		return false
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var v := (d11 * d20 - d01 * d21) / den
	var w := (d00 * d21 - d01 * d20) / den
	return v >= 0.0 and w >= 0.0 and v + w <= 1.0

## A garment's triangles in the model's space, each with its normal turned the way its vertex normals point; a face
## its corners' normals disagree with (EmptySlim's long slivers across a rim) is not the garment's surface.
func _faces(mesh: Mesh, xf: Transform3D, into: Array, part: String) -> void:
	var nb := xf.basis.inverse().transposed()
	for s in mesh.get_surface_count():
		var arrs := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arrs[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrs[Mesh.ARRAY_INDEX]
		for t in range(0, idx.size(), 3):
			var a := xf * vs[idx[t]]
			var b := xf * vs[idx[t + 1]]
			var c := xf * vs[idx[t + 2]]
			var fn := (b - a).cross(c - a)
			if fn.length_squared() < 1e-14:
				continue
			fn = fn.normalized()
			var corners := [(nb * ns[idx[t]]).normalized(), (nb * ns[idx[t + 1]]).normalized(),
				(nb * ns[idx[t + 2]]).normalized()]
			if fn.dot(corners[0] + corners[1] + corners[2]) < 0.0:
				fn = -fn
			if corners.all(func(cn: Vector3) -> bool: return cn.dot(fn) > SURFACE):
				into.append([a, b, c, fn, part])

## Which part of the body a mesh is on: a garment only covers its own part (a sleeve its arm, a glove its hand), and
## what hangs from the trunk (a top, trousers, a skirt) the legs too.
## The node a body region hangs from (its upright axis in the straight pose).
func _region_root(mi: Node, top: Node) -> Node3D:
	var n := mi.get_parent()
	while n != top:
		if String(n.name) in ["HeadPivot", "Hand", "Elbow", "ArmLPivot", "ArmRPivot", "LegL", "LegR", "Torso"]:
			return n
		n = n.get_parent()
	return top as Node3D

func _region(mi: Node, top: Node) -> String:
	var n := mi.get_parent()
	while n != top:
		var nm := String(n.name)
		if nm in ["HeadPivot", "Hand", "Elbow", "ArmLPivot", "ArmRPivot", "LegL", "LegR"]:
			return nm
		if nm == "Knee":
			return String(n.get_parent().name)
		if nm == "Torso":
			return "trunk"
		n = n.get_parent()
	return ""

func _covers(wear_part: String, body_part: String) -> bool:
	return wear_part == body_part or (wear_part == "trunk" and body_part.begins_with("Leg"))

func _points(mesh: Mesh, xf: Transform3D, into: Array, owner_id: int) -> void:
	var nb := xf.basis.inverse().transposed()
	var at: PackedVector3Array = into[0]
	var facing: PackedVector3Array = into[1]
	var whose: PackedInt32Array = into[2]
	for s in mesh.get_surface_count():
		var arrs := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arrs[Mesh.ARRAY_NORMAL]
		for k in vs.size():
			at.append(xf * vs[k])
			facing.append((nb * ns[k]).normalized())
			whose.append(owner_id)
	into[0] = at
	into[1] = facing
	into[2] = whose

## A node's transform in the model's space (the model is not in the scene tree).
func _xf(n: Node3D, top: Node3D) -> Transform3D:
	var out := Transform3D.IDENTITY
	while n != top:
		out = n.transform * out
		n = n.get_parent()
	return out

func _under(n: Node, names: Array, top: Node) -> bool:
	while n != top and n != null:
		if String(n.name) in names:
			return true
		n = n.get_parent()
	return false

func _kind(mat: Material) -> String:
	if _is_body(mat) or _is_head(mat):
		return "body"
	return "wear" if mat and mat.has_meta("wear") else ""

# ---------------------------------------------------------------- the creator panel
func _panel(main: Node) -> void:
	var tree := main.get_tree()
	var c := CreatorPanel.make(Unmasked.default_look())
	var ui := CanvasLayer.new()
	main.add_child(ui)
	ui.add_child(c)
	for i in 4:
		await tree.process_frame
	ok(_find_text(c, "Randomize") != null and _find_text(c, "Looks good") != null and _find_text(c, "Undo") != null,
		"Randomize, Undo and Looks good are there")
	ok(c.get_viewport().gui_get_focus_owner() != null, "a control has focus from the start, so a gamepad can drive it")
	var start: Dictionary = c.look.duplicate(true)
	c.randomize_look()
	var rolled: Dictionary = c.look.duplicate(true)
	ok(rolled != start and Unmasked.clean(rolled) == rolled, "Randomize makes a whole new valid person")
	c.undo()
	ok(c.look == start, "Undo brings back the look before")
	for tab in CreatorPanel.TABS:
		c.show_tab(tab)
		await tree.process_frame
	c.show_tab("Outfit")
	c.pick_item("top", 2)
	c.pick_colour("top", 0, 5)
	ok(EmptyWear.item(c.look, "top") == 2 and EmptyWear.colour(c.look, "top", 0) == 5,
		"the Outfit tab puts on an item and colours it")
	c.pick_item("top", EmptyWear.NONE)
	ok(EmptyWear.item(c.look, "top") == EmptyWear.NONE, "and takes it off again")
	c.use_preset(String(EmptyFrame.rules()["presets"].keys()[0]))
	ok(EmptyWear.item(c.look, "bottom") != EmptyWear.NONE, "a preset dresses the whole person")
	var made := [{}]
	c.done.connect(func(lk: Dictionary): made[0] = lk)
	var want: Dictionary = c.look.duplicate(true)
	(_find_text(c, "Looks good") as Button).pressed.emit()
	ok(made[0] == want, "Looks good hands back the look it shows")
	ui.queue_free()
	for i in 3:
		await tree.process_frame

func _find_text(nd: Node, txt: String) -> Control:
	if nd is Button and (nd as Button).text == txt:
		return nd
	for ch in nd.get_children():
		var f := _find_text(ch, txt)
		if f:
			return f
	return null
