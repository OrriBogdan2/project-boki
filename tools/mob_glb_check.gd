extends RefCounted
## --mob-glb-check: the skinned monster models (scripts/match/mob_glb.gd, docs/art/MOB_MODELS.md).
## For every monster with an art/mobs model: the model replaces the primitives (only the kept glow
## parts still draw), it fits the triangle budget, its paint repaints with the region's colour, and
## turning a pivot the way mob.gd does moves the bone of the same name. Prints MOBGLB ok/FAIL lines
## and "MOBGLB DONE, failures: N". Never touches the save.

const KINDS := ["skitter", "spitter", "brute", "warden", "bomber", "sentinel", "glimmer", "bl_skitter", "bl_warden"]
const MAX_TRIS := 7000        # per model: one draw call, under what the primitives cost (4-9k)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("MOBGLB %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	var seen := 0
	for kind in KINDS:
		if MobGlb.has(kind):
			seen += 1
			await _one(main, kind)
	ok(seen > 0, "%d monsters have a model" % seen)
	print("MOBGLB DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _one(main: Node, kind: String) -> void:
	var root := Models.mob(kind)
	main.add_child(root)
	var f := root.get_node_or_null("MobGlb") as MobGlb
	var linked := f._links.size() if f else 0
	ok(linked > 0, "%s: model dressed, %d bones linked to pivots" % [kind, linked])
	if f == null:
		root.queue_free()
		return
	var body := root.get_node("Body") as Node3D
	var tris := 0
	var stray := 0
	var measured := false
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.is_ancestor_of(f._skel) or f._skel.is_ancestor_of(m):
			tris += m.mesh.get_faces().size() / 3
			measured = measured or (m.get_meta("extras", {}) as Dictionary).has("band")
		elif m.is_visible_in_tree() and not _kept(m, body, kind):
			stray += 1
	ok(tris > 0 and tris <= MAX_TRIS, "%s: %d triangles (<= %d)" % [kind, tris, MAX_TRIS])
	ok(stray == 0, "%s: no primitive draws over the model (%d)" % [kind, stray])
	var mats: Array = root.get_meta("mats")
	var paint := mats.back() as ShaderMaterial
	var band := float(paint.get_shader_parameter("recolor_hue"))
	var textured: bool = paint.get_shader_parameter("albedo_tex") != null
	ok(textured and measured, "%s: textured, measured repaint band at hue %.2f" % [kind, band])
	BiomeRun.recolor_mats(mats, kind, Color("3a8fd0"))
	ok(paint.get_shader_parameter("recolor_to") == Color("3a8fd0"), "%s: the region's colour reaches the paint" % kind)
	var l: Array = f._links[0]
	var before := f._skel.get_bone_global_pose(l[0])
	(l[1] as Node3D).rotate_x(0.6)
	f._process(0.0)
	var moved := not f._skel.get_bone_global_pose(l[0]).is_equal_approx(before)
	ok(moved, "%s: turning pivot %s moves its bone" % [kind, (l[1] as Node3D).name])
	root.queue_free()
	await main.get_tree().process_frame

func _kept(m: MeshInstance3D, body: Node3D, kind: String) -> bool:
	for k in MobGlb.KEEP.get(kind, []):
		var n := body.find_child(k, true, false)
		if n and (n == m or n.is_ancestor_of(m)):
			return true
	return false
