extends RefCounted
## --load-trim-check: what build.hunters no longer does on the main thread. A glider canopy is built once per shape,
## one mesh for every Hunter, and a Hunter's material carries its skin's colours. A duel reads only your Warden's
## .glb; a match with rival squads reads every Warden's and every common Boki's on loader threads from its start, on
## the Compatibility renderer only (BackgroundWork.can_read_ahead; elsewhere none). Hunters on skins of one shape
## share its glider's meshes, each with its own canopy material. A Warden drawn from its .glb keeps the rig nodes
## that drive its bones but none of the hidden procedural body's loose parts; set to procedural, the same Warden
## still merges its body.

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
	var team := Color("40c060")
	var hero := Color("e0b030")
	var by_shape := {}
	for g in Gliders.LIST:
		var id := String(g["id"])
		var canopy := Gliders.canopy(id)
		if not by_shape.has(g["shape"]):
			by_shape[g["shape"]] = canopy
		_ok("%s: its canopy is the one %s mesh, built once" % [id, g["shape"]],
				canopy == by_shape[g["shape"]] and Gliders.canopy(id) == canopy)
		_ok("%s: the canopy's material wears the skin's colours, the team's and hero's in them" % id,
				_wears(Gliders.canopy_material(id, team, hero), g, team, hero))
	var meshes := {}
	for canopy in by_shape.values():
		meshes[canopy] = true
	_ok("each of the %d shapes has its own canopy" % by_shape.size(), meshes.size() == by_shape.size())

## Whether a canopy material mixes the skin's cloth, stripe and edge colours (for this team and hero).
func _wears(mat: ShaderMaterial, g: Dictionary, team: Color, hero: Color) -> bool:
	if not _weighs(mat):
		return false
	for w in Gliders.WEIGHTS:
		if mat.get_shader_parameter(w) != Gliders.weight(String(g["id"]), Gliders.WEIGHTS[w], team, hero):
			return false
	return true

## Whether a material reads its vertex colours as colour weights: set, and declared by the shader it is on
## now (a material keeps parameters its shader lacks, and Models.hero_look moves a Hunter's to another).
func _weighs(mat: ShaderMaterial) -> bool:
	var declared := mat.shader.get_shader_uniform_list().map(func(u): return String(u["name"]))
	return mat.get_shader_parameter("vertex_weights") == true \
			and ["vertex_weights", "weight_r", "weight_g", "weight_b"].all(func(nm): return nm in declared)

func _asked(p: String) -> bool:
	return ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE

func _fetches() -> void:
	var own := "gunslinger"
	if not BackgroundWork.can_read_ahead():
		WardenGlb.fetch_for({"teams": 4, "arch": own})
		BokiRig.fetch_common()
		var read := Arch.ids().filter(func(a): return WardenGlb.uses_model(a) and _asked(WardenGlb.path(a)))
		read += Data.common_kin().filter(func(k): return BokiRig.has(k) and _asked(BokiRig.PATH % [k, k]))
		_ok("%s: no .glb is read on a loader thread (read %s)" % [DisplayServer.get_name(), str(read)], read.is_empty())
		return
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

func _glider_parts(m: Node3D) -> Array:
	return m.get_node("Rig/Torso/Glider").get_children().filter(func(c): return c is MeshInstance3D)

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
	var g1 := _glider_parts(m)
	var g2 := _glider_parts(m2)
	_ok("a glider is its canopy and its strings", g1.size() == 2 and g2.size() == 2)
	var shared: bool = g1[0].mesh == g2[0].mesh and g1[1].mesh == g2[1].mesh
	_ok("Hunters on one skin share its canopy's and strings' meshes", shared)
	var mat1: ShaderMaterial = g1[0].material_override
	_ok("each colours the canopy with its own material", mat1 != g2[0].material_override)
	_ok("a Hunter's canopy shader mixes the weights (%s)" % mat1.shader.resource_path, _weighs(mat1))
	m.free()
	m2.free()
	WardenGlb._measuring = true
	var pm := Models.hunter(Arch.weight(a), Data.TEAM_COLORS[0], Arch.signature(a), "", PlayerLook.random(), a)
	_ok("built without its .glb, the body is built and merged", not WardenGlb.will_dress(a) and _loose(pm) > 0)
	pm.free()
	WardenGlb._measuring = false

func _ok(what: String, cond: bool) -> void:
	print("LOADTRIM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1
