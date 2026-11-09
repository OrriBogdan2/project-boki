extends RefCounted
## --hunter-parity-check: the Training Area draws and plays every Hunter exactly as a real match does (owner
## playtest 11-08 item 26: Meeko's sun and moon gone, Lace in her old model). For every Hunter it builds the
## player three ways: in a real match, in the Training Area started as that Hunter, and in the Training Area
## swapped in place from another Hunter (the title screen's route: you start as the default and pick in the
## loadout). Each must load the same model file (WardenGlb.path, and the .glb really dressed, not the
## procedural fallback), the same kit script (ArchKit), the same node tree (auto names stripped, hidden flags
## kept), the same skeleton bone scales (a bone scaled to nothing hides what is skinned to it: the sun on
## pauldron.L) and the same surfaces: per mesh surface the override material's shader, its uniforms (albedo, glow,
## use_tex, the texture's presence) and the mesh's visibility range and shadow setting, so a surface drawn with the
## wrong shader, tinted away or culled by distance (Meeko's cloth-sun, skin-cloud and eyes-mood_* surfaces) fails
## even when the node tree agrees. Run with no save (the title screen before a profile) and with a fresh one, and
## again after the title screen has built its own Hunters.

const BASE := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
var fails := 0

func _tree(n: Node, pre := "") -> Array:
	var out: Array = []
	for c in n.get_children():
		if c.name.begins_with("@") or c.name.begins_with("_"):
			continue        # (merged static meshes and helpers get engine names)
		var vis := "" if not (c is Node3D) or (c as Node3D).visible else " [hidden]"
		out.append(pre + String(c.name) + vis)
		out.append_array(_tree(c, pre + String(c.name) + "/"))
	return out

func _mat(m: Material) -> String:
	if m == null:
		return "none"
	if not m is ShaderMaterial:
		return m.get_class() + ":" + m.resource_path
	var sm := m as ShaderMaterial
	var parts: Array = [sm.shader.resource_path if sm.shader else "noshader"]
	for u in sm.shader.get_shader_uniform_list() if sm.shader else []:
		var v = sm.get_shader_parameter(u["name"])
		if v is Texture:
			v = "tex:" + ((v as Texture).resource_path if (v as Texture).resource_path != "" else "runtime")
		elif v is float:
			v = snappedf(v, 0.01)
		elif v is Color or v is Vector3 or v is Vector4:
			v = str(v)
		parts.append("%s=%s" % [u["name"], str(v)])
	return ",".join(parts)

## Every mesh surface's look, keyed by node path (engine-named merges skipped as in _tree) and surface index.
func _surfaces(md: Node3D) -> Dictionary:
	var out := {}
	for mi in md.find_children("*", "MeshInstance3D", true, false):
		var path := String(md.get_path_to(mi))
		if path.contains("@") or path.begins_with("_") or path.contains("/_"):
			continue
		var gi := mi as GeometryInstance3D
		out[path] = "vis=%s range=%s shadow=%d" % [str(gi.visible), str(snappedf(gi.visibility_range_end, 0.1)),
			gi.cast_shadow]
		var mesh := (mi as MeshInstance3D).mesh
		for si in (mesh.get_surface_count() if mesh else 0):
			var m := (mi as MeshInstance3D).get_surface_override_material(si)
			out["%s#%d" % [path, si]] = _mat(m if m else (mesh.surface_get_material(si)))
	return out

func _sig(P: Hunter) -> Dictionary:
	var md: Node3D = P.model
	var bones := {}
	var sk := WardenGlb.skeleton(md.get_node_or_null("Warden"))
	if sk:
		for i in sk.get_bone_count():
			var s := sk.get_bone_global_pose(i).basis.get_scale()
			bones[sk.get_bone_name(i)] = snappedf(minf(s.x, minf(s.y, s.z)), 0.05)
	var kit := (P.ak.get_script() as Script).resource_path if P.ak else ""
	return {"glb": bool(md.get_meta("glb", false)), "path": WardenGlb.path(P.arch), "kit": kit,
		"cls": P.cls, "wid": P.wid, "tree": _tree(md), "bones": bones, "surfaces": _surfaces(md)}

func _build(main: Node, o: Dictionary, swap_to := "") -> Dictionary:
	var m := Match.new()
	main.add_child(m)
	await m.start(o)
	if swap_to != "":
		m.arena.set_arch(swap_to)
	for i in 8:
		await main.get_tree().process_frame
	var out := _sig(m.player)
	m.queue_free()
	await main.get_tree().process_frame
	return out

func _cmp(a: String, what: String, ref: Dictionary, got: Dictionary) -> void:
	for k in ["glb", "path", "kit", "cls", "wid"]:
		if ref[k] != got[k]:
			fails += 1
			print("FAIL hunter_parity %s %s: %s %s vs match %s" % [a, what, k, str(got[k]), str(ref[k])])
	if ref["tree"] != got["tree"]:
		fails += 1
		var miss: Array = (ref["tree"] as Array).filter(func(x): return not (got["tree"] as Array).has(x))
		var extra: Array = (got["tree"] as Array).filter(func(x): return not (ref["tree"] as Array).has(x))
		print("FAIL hunter_parity %s %s: node tree differs, missing %s extra %s"
			% [a, what, str(miss.slice(0, 4)), str(extra.slice(0, 4))])
	for b in ref["bones"]:
		if absf(float(ref["bones"][b]) - float(got["bones"].get(b, -1.0))) > 0.06:
			fails += 1
			var g = got["bones"].get(b)
			print("FAIL hunter_parity %s %s: bone %s scale %s vs match %s" % [a, what, b, str(g), str(ref["bones"][b])])
			break
	var shown := 0
	for k in ref["surfaces"]:
		var g = got["surfaces"].get(k, "missing")
		if g != ref["surfaces"][k] and shown < 3:
			fails += 1
			shown += 1
			print("FAIL hunter_parity %s %s: surface %s is %s vs match %s"
				% [a, what, k, str(g), str(ref["surfaces"][k])])

func run(main: Node) -> void:
	Save.no_write = true
	var ids: Array = Arch.ids()
	var refs := {}
	for save_mode in ["none", "fresh"]:
		if save_mode == "fresh":
			Save.reset()
		for a in ids:
			var mo: Dictionary = BASE.duplicate()
			mo.merge({"arch": a, "cls": Arch.weight(a), "weapon": Arch.signature(a)}, true)
			var ref: Dictionary = await _build(main, mo)
			refs[a] = ref
			if not ref["glb"] and WardenGlb.has_model(a):
				fails += 1
				print("FAIL hunter_parity %s: a real match draws the procedural model though %s exists"
					% [a, ref["path"]])
			var direct: Dictionary = await _build(main, Match.arena_opts(a))
			_cmp(a, "training (%s save)" % save_mode, ref, direct)
			var from: String = ids[0] if a != ids[0] else ids[1]
			var swapped: Dictionary = await _build(main, Match.arena_opts(from), a)
			_cmp(a, "training swap from %s (%s save)" % [from, save_mode], ref, swapped)
	# The owner's route: the title screen first (it builds its own squad and a glider with Models.hunter, which
	# fill the session's model caches), then the Training Area. Every Hunter must still match the match built
	# before the title ever showed. Twice: as a Warden of the default kit, then leading as Meeko.
	for lead in ["", "tender"]:
		if lead != "":
			Save.d["arch"] = lead
			Save.d["cls"] = Arch.weight(lead)
		var title: Node = load("res://scripts/ui/title.gd").new()
		main.add_child(title)
		for i in 30:
			await main.get_tree().process_frame
		title.queue_free()
		await main.get_tree().process_frame
		for a in ids:
			var from: String = Arch.of_save()
			if a == from:
				from = ids[0] if a != ids[0] else ids[1]
			var after: Dictionary = await _build(main, Match.arena_opts(from), a)
			_cmp(a, "training after the title (lead %s)" % (lead if lead != "" else "default"), refs[a], after)
	if fails == 0:
		print("OK hunter_parity: %d Hunters match the real match in the Training Area" % ids.size())
	else:
		print("FAIL hunter_parity: %d differences" % fails)
	main.get_tree().quit()
