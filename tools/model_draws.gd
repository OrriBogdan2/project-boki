extends RefCounted
## --model-draws: loads every Hunter and Boki .glb and prints its mesh surfaces (one draw call each per
## view), materials, bones and triangles; lists the models over the surface budget. Then each Hunter as the game
## builds it (toon materials, equal surfaces joined by WardenMerge): the surfaces and ink passes it really draws.

const DRAW_BUDGET := 4          # surfaces per model; every one is a draw call per view and shadow cascade

func run(main: Node) -> void:
	var paths: Array[String] = []
	for dir in ["res://art/wardens", "res://art/kin"]:
		for d in DirAccess.get_directories_at(dir):
			for f in DirAccess.get_files_at("%s/%s" % [dir, d]):
				if f.ends_with(".glb"):
					paths.append("%s/%s/%s" % [dir, d, f])
	paths.sort()
	var over := 0
	var total := 0
	for p in paths:
		var node := (load(p) as PackedScene).instantiate()
		var st := _count(node)
		node.free()
		total += st.surfaces
		if st.surfaces > DRAW_BUDGET:
			over += 1
		print("MODELDRAWS %s meshes %d surfaces %d materials %d bones %d tris %d%s" % [
			p.trim_prefix("res://art/"), st.meshes, st.surfaces, st.materials.size(), st.bones, st.tris,
			"  OVER" if st.surfaces > DRAW_BUDGET else ""])
	var built := 0
	for a in Arch.ids():
		if WardenGlb.has_model(a):
			var m := Models.hunter(Arch.weight(a), Data.TEAM_COLORS[0], Arch.signature(a), "", PlayerLook.neutral(), a)
			main.add_child(m)
			var st := _count(m.get_node("Warden"))
			var inks := 0
			for mi in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
				for si in (mi as MeshInstance3D).mesh.get_surface_count():
					var mat := (mi as MeshInstance3D).get_active_material(si)
					inks += 1 if mat and mat.next_pass else 0
			built += st.surfaces + inks
			print("MODELDRAWS built %s surfaces %d ink passes %d tris %d" % [a, st.surfaces, inks, st.tris])
			m.free()
	print("MODELDRAWS built draws per Hunter set: %d" % built)
	print("MODELDRAWS DONE models %d surfaces %d over budget (%d) %d" % [paths.size(), total, DRAW_BUDGET, over])
	main.get_tree().quit()

func _count(n: Node) -> Dictionary:
	var st := {"meshes": 0, "surfaces": 0, "materials": {}, "bones": 0, "tris": 0}
	var todo: Array[Node] = [n]
	while not todo.is_empty():
		var c: Node = todo.pop_back()
		todo.append_array(c.get_children())
		if c is Skeleton3D:
			st.bones += (c as Skeleton3D).get_bone_count()
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var mi := c as MeshInstance3D
			st.meshes += 1
			for s in mi.mesh.get_surface_count():
				st.surfaces += 1
				st.tris += _tris(mi.mesh, s)
				var m := mi.get_active_material(s)
				st.materials[m if m else s] = true
	return st

func _tris(mesh: Mesh, s: int) -> int:
	var a := mesh.surface_get_arrays(s)
	var idx = a[Mesh.ARRAY_INDEX]
	return (idx.size() if idx != null else a[Mesh.ARRAY_VERTEX].size()) / 3
