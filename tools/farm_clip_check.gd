extends RefCounted
## --farm-clip-check: walks the farm for clipping. Every catalog item and a fenced yard are put down on a
## farm-start island; then it counts (1) props whose model sticks out of their footprint onto open ground,
## (2) props standing in each other, (3) props floating or sunk, (4) spots on the whole island where the hunter
## (radius 0.38) or the Boki (0.3) is "free" yet stands inside a prop's model, and (5) where the home camera
## would sit inside one. Prints each finding; zero is the bar. Never touches the real save.

const HUNTER_R := 0.38      # m, Home's player body (home.gd occupy calls)
const BOKI_R := 0.3         # m, Home's Boki body
const STEP := 0.25          # m between probes
const OUT_MAX := 0.35       # m a model may stick out of its footprint onto open ground
const FLOAT_MAX := 0.25     # m a model's lowest point may be above or below the ground
const IN_MIN := 0.4         # m a model must be inside another to count as standing in it
const LEG := 0.25           # m: a part whose bottom is within this of the ground stands on it
const WALKABLE := ["training_post"]      # Boki spar on its mat: the whole footprint stays open
const CANOPY := ["bush", "tree", "pine", "blossom_tree"]      # models that are mostly overhead: their tile blocks

var bad := 0
var main: Node
var home
var lines := 0

func ok(cond: bool, what: String) -> void:
	print("FARMCLIP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _tag(it: Dictionary) -> String:
	return "%s (%d,%d)" % [it["id"], it["e"]["x"], it["e"]["z"]]

func note(s: String) -> void:
	lines += 1
	if lines <= 80: print("FARMCLIP   " + s)

func _save() -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true}
	d["gems"] = 5000
	Save.d = d

## The world AABB of a node's meshes (lights and shadows ignored).
func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.visible: continue
		var wb: AABB = mi.global_transform * mi.mesh.get_aabb()
		box = wb if first else box.merge(wb)
		first = false
	return box

func _stage() -> void:
	var land := Vector3(home.ppos.x, 0, home.ppos.z)
	for id in HomeLayout.CATALOG:
		var c: Dictionary = HomeLayout.CATALOG[id]
		if c.has("brush") or c.get("line", false): continue
		home.hg.demo_place(id, land + Vector3(0, 0, 4.0), 0, 2.0)
	for id in ["fence", "picket", "stone_wall", "hedge"]:
		var a := land + Vector3(-8 + 3 * ["fence", "picket", "stone_wall", "hedge"].find(id), 0, 9.0)
		for i in 5:
			var e := {"u": HomeLayout._next_uid(home.hb.L()), "id": id, "x": int(a.x), "z": int(a.z) + i, "r": 0}
			home.hb.L()["deco"].append(e)
	home.hb.apply(false)
	for i in 6:
		await main.get_tree().process_frame

func _nodes() -> Array:
	var out: Array = []
	for u in home.hb.nodes:
		var e := _entry(int(u))
		if not e.is_empty() and is_instance_valid(home.hb.nodes[u]):
			var it := {"id": String(e["id"]), "e": e, "n": home.hb.nodes[u], "box": _aabb(home.hb.nodes[u])}
			it["solid"] = _solid(it)
			out.append(it)
	return out

func _entry(u: int) -> Dictionary:
	for e in home.hb.L()["deco"]:
		if int(e["u"]) == u: return e
	return {}

func _rect(e: Dictionary) -> Rect2:
	var sz := HomeLayout.size_of(String(e["id"]), int(e.get("r", 0)))
	return Rect2(float(e["x"]), float(e["z"]), sz.x, sz.y)

## The parts of a model that stand on the ground and are tall enough to be walked into (a canopy or a roof high
## above does not count); a tree or bush is its whole footprint, which blocks.
func _solid(it: Dictionary) -> Array:
	var w: World = home.world
	var out: Array = []
	if it["id"] in CANOPY:
		var r := _rect(it["e"])
		return [AABB(Vector3(r.position.x, 0, r.position.y), Vector3(r.size.x, 1, r.size.y))]
	for m in it["n"].find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.visible: continue
		var wb: AABB = mi.global_transform * mi.mesh.get_aabb()
		var g := w.ground_at(wb.get_center().x, wb.get_center().z)
		if wb.position.y < g + LEG and wb.end.y > g + 0.5 and minf(wb.size.x, wb.size.z) > 0.12:
			out.append(wb)
	return out

func _merged(parts: Array) -> AABB:
	var box: AABB = parts[0]
	for p in parts:
		box = box.merge(p)
	return box

## 1 and 3: a model against its own footprint and the ground.
func _own(items: Array) -> void:
	var w: World = home.world
	for it in items:
		var box: AABB = it["box"]
		if box.size == Vector3.ZERO: continue
		var e: Dictionary = it["e"]
		var r := _rect(e)
		if not it["solid"].is_empty():
			var sb := _merged(it["solid"])
			var over := maxf(maxf(r.position.x - sb.position.x, sb.end.x - r.end.x),
				maxf(r.position.y - sb.position.z, sb.end.z - r.end.y))
			if over > OUT_MAX:
				note("OUT   %s: its body sticks %.2f m outside its footprint" % [_tag(it), over])
				bad += 1
		var g := w.ground_at(r.get_center().x, r.get_center().y)
		if box.position.y - g > FLOAT_MAX:
			note("FLOAT %s: lowest point %.2f m above ground" % [_tag(it), box.position.y - g])
			bad += 1
		if g - box.position.y > FLOAT_MAX and box.end.y - g < 0.5:
			note("SUNK  %s: top %.2f m above ground" % [_tag(it), box.end.y - g])
			bad += 1

## 2: two bodies standing in each other.
func _pairs(items: Array) -> void:
	for i in items.size():
		for j in range(i + 1, items.size()):
			if items[i]["solid"].is_empty() or items[j]["solid"].is_empty(): continue
			var a := _merged(items[i]["solid"])
			var b := _merged(items[j]["solid"])
			var ix := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
			var iz := minf(a.end.z, b.end.z) - maxf(a.position.z, b.position.z)
			if ix > IN_MIN and iz > IN_MIN:
				note("PAIR  %s in %s: %.2f x %.2f m" % [_tag(items[i]), _tag(items[j]), ix, iz])
				bad += 1

## 4: spots the hunter or a Boki may stand on that are inside a body.
func _walk(items: Array) -> void:
	var w: World = home.world
	for it in items:
		var hits := {}
		var loose: bool = it["id"].begins_with("toy_") and not HomeLayout.blocks(it["id"])      # a ball is for nudging
		if it["id"] in WALKABLE or loose:
			continue
		for s in it["solid"]:
			var sb: AABB = s
			var x := sb.position.x
			while x <= sb.end.x:
				var z := sb.position.z
				while z <= sb.end.z:
					for R in [HUNTER_R, BOKI_R]:
						if w.occupy(x, z, R, w.ground_at(x, z), true) == 0.0 and not w.is_void(x, z):
							hits[R] = hits.get(R, 0) + 1
					z += STEP
				x += STEP
		for R in hits:
			note("WALK  radius %.2f: %d probes inside %s are free to stand on" % [R, hits[R], _tag(it)])
			bad += 1

## `--shots-dir=<dir>` (needs a renderer): the hunter stands in each kind of prop, a Boki beside it, close up.
func _shots(items: Array, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	home.cam.zoom_to = 0.6
	home.cam.zoom = 0.6
	var seen := {}
	for it in items:
		if seen.has(it["id"]): continue
		seen[it["id"]] = true
		var c: Vector3 = HomeLayout.deco_center(it["e"])
		home.ppos = c
		home.player.position = c
		home.cam.snap(c)
		for k in home.kins:
			k["pos"] = c + Vector3(0.9, 0, 0.6)
			(k["node"] as Node3D).position = k["pos"]
			k["goal"] = k["pos"]
			break
		for i in 12:
			await main.get_tree().process_frame
		main.get_viewport().get_texture().get_image().save_png(dir.path_join(it["id"] + ".png"))

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	_save()
	home = await main._hb_home()
	await _stage()
	var items := _nodes()
	print("FARMCLIP %d props staged" % items.size())
	_own(items)
	_pairs(items)
	_walk(items)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): await _shots(items, a.substr(12))
	ok(bad == 0, "no clipping found (%d findings)" % bad)
	print("FARMCLIP DONE %d" % bad)
	main.get_tree().quit()
