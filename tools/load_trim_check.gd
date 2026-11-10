extends RefCounted
## --load-trim-check: what build.hunters no longer does on the main thread. A glider canopy's sheet is built
## once per skin and only recoloured per Hunter (same geometry, the skin's colours on it). A duel reads only
## your Warden's .glb; a match with rival squads reads every Warden's and every common Boki's on loader
## threads from its start. A Hunter's glider shares its strings' mesh and paints its own canopy. A Warden
## drawn from its .glb keeps the rig nodes that drive its bones but none of the hidden procedural body's
## loose parts; set to procedural, the same Warden still merges its body.

const RIG := ["Rig/Torso", "Rig/Torso/HeadPivot", "Rig/Torso/ArmLPivot/Elbow/Hand", "Rig/Legs/LegR/Knee"]

var bad := 0

func run(main: Node) -> void:
	Save.no_write = true
	_gliders()
	_fetches()
	_bodies(main)
	print("LOADTRIM DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _gliders() -> void:
	for g in Gliders.LIST:
		var id := String(g["id"])
		var a := Gliders.mesh(id, Color("d04040"), Color("3060c0"))
		var sheets := Gliders._sheets.size()
		var b := Gliders.mesh(id, Color("40c060"), Color("e0b030"))
		var va: PackedVector3Array = a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var vb: PackedVector3Array = b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var same := Gliders._sheets.size() == sheets and va == vb
		_ok("%s: a second Hunter's canopy reuses the sheet, same geometry" % id, same)
		var cols: PackedColorArray = b.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var cloth := Gliders.col(String(g["cloth"]), Color("40c060"), Color("e0b030"))
		_ok("%s: the canopy wears its own cloth colour" % id, Array(cols).any(func(c): return _near(c, cloth)))

func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.02

func _asked(p: String) -> bool:
	return ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE

func _fetches() -> void:
	var own := "gunslinger"
	var other := "juggernaut" if WardenGlb.has_model("juggernaut") else ""
	WardenGlb.fetch_for({"duel": true, "arch": own})
	_ok("a duel reads your Warden's .glb", _asked(WardenGlb.path(own)))
	_ok("a duel reads no other Warden's", other == "" or not _asked(WardenGlb.path(other)))
	WardenGlb.fetch_for({"teams": 4, "arch": own})
	var missing := Arch.ids().filter(func(a): return WardenGlb.uses_model(a) and not _asked(WardenGlb.path(a)))
	_ok("a match with rivals reads every Warden's .glb (missing %s)" % str(missing), missing.is_empty())
	BokiRig.fetch_common()
	var kin_missing := Data.common_kin().filter(func(k): return BokiRig.has(k) and not _asked(BokiRig.PATH % [k, k]))
	_ok("and every common Boki's (missing %s)" % str(kin_missing), kin_missing.is_empty())
	BackgroundWork.drain()

func _loose(n: Node) -> int:
	var c := 0
	for ch in n.get_children():
		if String(ch.name) in WardenGlb.KEEP or ch.name == "Warden":
			continue
		if ch is MeshInstance3D and String(ch.name).begins_with("@"):
			c += 1
		c += _loose(ch)
	return c

func _glider_meshes(m: Node3D) -> Array:
	var gl := m.get_node("Rig/Torso/Glider")
	var mis := gl.get_children().filter(func(c): return c is MeshInstance3D)
	return mis.map(func(c): return c.mesh)

func _bodies(main: Node) -> void:
	var a := "gunslinger"
	if not WardenGlb.will_dress(a):
		_ok("Vex is drawn from her .glb", false)
		return
	var look := PlayerLook.random()      # (one look for both Hunters below: the same glider skin)
	var m := Models.hunter(Arch.weight(a), Data.TEAM_COLORS[0], Arch.signature(a), "", look, a)
	main.add_child(m)
	_ok("a .glb Warden keeps its rig nodes", RIG.all(func(p): return m.has_node(p)))
	_ok("a .glb Warden keeps no hidden loose parts (%d)" % _loose(m), _loose(m) == 0)
	var m2 := Models.hunter(Arch.weight(a), Data.TEAM_COLORS[1], Arch.signature(a), "", look, a)
	var g1 := _glider_meshes(m)
	var g2 := _glider_meshes(m2)
	_ok("a glider is its canopy and its strings", g1.size() == 2 and g2.size() == 2)
	var shared: bool = g1[1] == g2[1] and g1[0] != g2[0]
	_ok("Hunters share the strings' mesh, each paints its own canopy", shared)
	m.free()
	m2.free()
	WardenGlb.set_model(a, false)
	var pm := Models.hunter(Arch.weight(a), Data.TEAM_COLORS[0], Arch.signature(a), "", PlayerLook.random(), a)
	_ok("set to procedural, the body is built and merged", not WardenGlb.will_dress(a) and _loose(pm) > 0)
	pm.free()
	WardenGlb.set_model(a, true)

func _ok(what: String, cond: bool) -> void:
	print("LOADTRIM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1
