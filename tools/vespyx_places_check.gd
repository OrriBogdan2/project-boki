extends RefCounted
## --vespyx-places-check [--species=cindle] [--save=fresh|old|shimmer] [--shots-dir=<abs dir>]: in every
## screen where a player meets a Boki (starter pick, hatch reveal, farm home, party, results, a match with
## your own Boki out, a menu portrait, the Bokidex card), is the Boki its rigged Meshy model (a BokiRig under
## Body/Flex) or the old primitive body (KinModels' fallback, a Flex with no BokiRig)? Meant to run from an
## exported .pck (godot --main-pack <pck> -- --vespyx-places-check), so a missing import remap shows up.
## --save=old builds the record like a pre-0.24 save (no dna, no sex, no care block); shimmer: a shimmer.
## --glb=<abs path>: wear that .glb (a pre-swap one from git, say) instead of the species' own, to see old and new side by side.
## --pack (with --shots-dir): this process exports the Windows pack of its own project, then runs this check in
## a second godot from that .pck alone for the fresh, old and shimmer saves, and prints their VESPYX lines.
## With a renderer and --shots-dir it also saves the whole window of each place. Fails on any OLD body.

var main: Node
var species := "cindle"
var kind := "fresh"
var out := ""
var bad := 0
var tag := ""


func run(m: Node) -> void:
	main = m
	if "--pack" in OS.get_cmdline_user_args():
		_via_pack()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--species="):
			species = a.substr(10)
		if a.begins_with("--save="):
			kind = a.substr(7)
		if a.begins_with("--glb="):
			_use_glb(a.substr(6))
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
	if out != "" and not out.is_absolute_path():
		out = ProjectSettings.globalize_path("res://").path_join(out)
	if out != "" and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(out)
	else:
		out = ""
	Save.no_write = true
	var rec := _record()
	Save.d = Save.fresh()
	Save.d["roster"] = [rec]
	Save.d["active"] = rec["uid"]
	Save.d["tutorial"]["home"] = true
	Save.d["tutorial"]["day1_done"] = true
	print("VESPYX_PLACES species=%s save=%s renderer=%s glb=%s has=%s" % [species, kind, DisplayServer.get_name(), BokiRig.PATH % [species, species], BokiRig.has(species)])
	await _place("starter_pick", "hatch", {})
	await _place("farm_home", "home", {})
	await _place("party", "party", {})
	await _place("results_caught", "results", {"extracted": true, "gems": 1, "seeds": {}, "caught": [rec], "knocks": 0, "damage": 1, "taken": 1, "kills": 0, "downs": 0, "deaths": 0, "revives": 0, "armor_tier": 1, "time": 60.0})
	await _place("match_own_boki", "match", {"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "demo_kin": species, "sandbox_demo": false, "kin_demo": true})
	await _reveal()
	await _portrait(rec)
	await _dex_card()
	print("VESPYX_PLACES %s: %d place(s) showed the old body" % ["FAIL" if bad else "OK", bad])
	main.get_tree().quit(1 if bad else 0)


func _via_pack() -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			dir = a.substr(12)
	var exe := OS.get_executable_path()
	var proj := ProjectSettings.globalize_path("res://")
	if not dir.is_absolute_path():
		dir = proj.path_join(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var pck := dir.path_join("win.pck")
	var exp_out: Array = []
	var rc := OS.execute(exe, ["--headless", "--path", proj, "--export-pack", "Windows", pck], exp_out, true)
	print("VESPYX_PACK export rc=%d pck=%s bytes=%d" % [rc, pck, FileAccess.get_file_as_bytes(pck).size() if FileAccess.file_exists(pck) else -1])
	var worst := rc
	for kind_s in ["fresh", "old", "shimmer"]:
		var res: Array = []
		var cmd := "cd /tmp && timeout 900 '%s' --main-pack '%s' -- --vespyx-places-check --save=%s --shots-dir='%s'" % [exe, pck, kind_s, dir]
		var r := OS.execute("sh", ["-c", cmd], res, true)
		worst = maxi(worst, r)
		var full := String(res[0] if res.size() > 0 else "")
		var lf := FileAccess.open(dir.path_join("child_%s.log" % kind_s), FileAccess.WRITE)
		lf.store_string(full)
		lf.close()
		for line in full.split("\n"):
			if line.begins_with("VESPYX_PLACES"):
				print(line)
		print("VESPYX_PACK save=%s rc=%d" % [kind_s, r])
	main.get_tree().quit(1 if worst else 0)


## Reads a .glb at run time and has BokiRig build the species from it.
func _use_glb(path: String) -> void:
	var st := GLTFState.new()
	var doc := GLTFDocument.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(path), st)
	var root := doc.generate_scene(st) as Node3D
	for n in root.find_children("*", "", true, false):
		n.owner = root
	var ps := PackedScene.new()
	print("VESPYX_PLACES glb=%s read=%d pack=%d" % [path, err, ps.pack(root)])
	BokiRig._scenes[BokiRig.PATH % [species, species]] = ps
	tag = "oldglb_"


## A Boki record as the chosen save kind would hold it.
func _record() -> Dictionary:
	var rec := Save.new_kin(species, "Pip", 4242)
	rec["level"] = 5
	match kind:
		"old":
			for k in ["dna", "sex", "ivs", "care", "edition", "bonds", "born"]:
				rec.erase(k)
		"shimmer":
			rec["shimmer"] = true
	return rec


func _place(label: String, screen: String, opts: Dictionary) -> void:
	main.show_screen(screen, opts)
	for i in 600:       # a farm or a match takes a while to build: up to 600 frames until a rigged Boki shows
		await main.get_tree().process_frame
		if i >= 90 and not _rigs().is_empty():
			break
	var ld = main.get("_ld")
	for i in 900:       # the loading screen of a match, then the fade in
		if ld == null or not is_instance_valid(ld) or not ld.is_inside_tree():
			break
		await main.get_tree().process_frame
	for i in 240:
		await main.get_tree().process_frame
	_report(label)
	await _grab(label)


func _reveal() -> void:
	var holder := Node3D.new()
	main.add_child(holder)
	var rv := KinReveal.new(species, _record())
	holder.add_child(rv)
	for i in 120:
		await main.get_tree().process_frame
	_report("hatch_reveal")
	await _grab("hatch_reveal")
	holder.queue_free()


func _portrait(rec: Dictionary) -> void:
	var t := KinPortrait.tex(rec, main.get_tree())
	for i in 10:
		await main.get_tree().process_frame
	_report("menu_portrait")
	if out != "" and t != null:
		await RenderingServer.frame_post_draw
		t.get_image().save_png(out.path_join("%s%s_%s_menu_portrait.png" % [tag, kind, species]))


func _dex_card() -> void:
	var holder := CanvasLayer.new()
	var v := VBoxContainer.new()
	holder.add_child(v)
	main.add_child(holder)
	DexView.detail(v, species, main.get_tree(), func(_s): pass)
	for i in 60:
		await main.get_tree().process_frame
	_report("dex_card")
	await _grab("dex_card")
	holder.queue_free()


## Counts the rigged and the primitive bodies in the tree right now (a body is the Flex node under Body).
func _report(label: String) -> void:
	var names := _rigs()
	var rigs := names.size()
	var old := 0
	for f in _bodies():
		if f.get_node_or_null("BokiRig") == null and (f.get_node_or_null("Tail") != null or f.get_node_or_null("Legs") != null):
			old += 1
	print("VESPYX_PLACES %s: rigs=%d (%s) old=%d" % [label, rigs, ",".join(names), old])
	if old > 0:
		bad += 1


func _bodies() -> Array:
	return main.get_tree().root.find_children("Flex", "Node3D", true, false).filter(func(f): return f.get_parent() != null and f.get_parent().name == "Body")


## The species of every rigged Boki body in the tree.
func _rigs() -> PackedStringArray:
	var names := PackedStringArray()
	for f in _bodies():
		var rig: Node = f.get_node_or_null("BokiRig")
		if rig != null:
			names.append(String(rig.get("species")))
	return names


func _grab(label: String) -> void:
	if out != "":
		await RenderingServer.frame_post_draw
		main.get_viewport().get_texture().get_image().save_png(out.path_join("%s%s_%s_%s.png" % [tag, kind, species, label]))
