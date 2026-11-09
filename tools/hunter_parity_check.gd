extends RefCounted
## --hunter-parity-check: the Training Area draws and plays every Hunter exactly as a real match does (owner
## playtest 11-08 item 26: Meeko's sun and moon gone, Lace in her old model). For every Hunter it builds the
## player three ways: in a real match, in the Training Area started as that Hunter, and in the Training Area
## swapped in place from another Hunter (the title screen's route: you start as the default and pick in the
## loadout). Each must load the same model file (WardenGlb.path, and the .glb really dressed, not the
## procedural fallback), the same kit script (ArchKit), the same node tree (auto names stripped, hidden flags
## kept) and the same skeleton bone scales (a bone scaled to nothing hides what is skinned to it: the sun on
## pauldron.L). Run with no save (the title screen before a profile) and with a fresh one.

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
		"cls": P.cls, "wid": P.wid, "tree": _tree(md), "bones": bones}

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

func run(main: Node) -> void:
	Save.no_write = true
	var ids: Array = Arch.ids()
	for save_mode in ["none", "fresh"]:
		if save_mode == "fresh":
			Save.reset()
		for a in ids:
			var mo: Dictionary = BASE.duplicate()
			mo.merge({"arch": a, "cls": Arch.weight(a), "weapon": Arch.signature(a)}, true)
			var ref: Dictionary = await _build(main, mo)
			if not ref["glb"] and WardenGlb.has_model(a):
				fails += 1
				print("FAIL hunter_parity %s: a real match draws the procedural model though %s exists"
					% [a, ref["path"]])
			var direct: Dictionary = await _build(main, Match.arena_opts(a))
			_cmp(a, "training (%s save)" % save_mode, ref, direct)
			var from: String = ids[0] if a != ids[0] else ids[1]
			var swapped: Dictionary = await _build(main, Match.arena_opts(from), a)
			_cmp(a, "training swap from %s (%s save)" % [from, save_mode], ref, swapped)
	if fails == 0:
		print("OK hunter_parity: %d Hunters match the real match in the Training Area" % ids.size())
	else:
		print("FAIL hunter_parity: %d differences" % fails)
	main.get_tree().quit()
