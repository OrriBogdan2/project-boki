extends "res://tools/rig_standard_check.gd"
## --ownrig-check --ids=mage,dolm --warden-variant=ryzz_own,tarek_own: own-rig glb as the Hunter's model: armature vs the game rig, rest pose, clips.
func run(main: Node) -> void:
	Save.no_write = true
	tree = main.get_tree()
	holder = Node3D.new()
	main.add_child(holder)
	var ids: Array = ["mage", "dolm"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ids="): ids = Array(a.substr(6).split(","))
	for id in ids:
		var m := _model(String(id))
		ok(m.has_node("Warden"), "%s: wears its 3D model (path %s)" % [id, WardenGlb.path(String(id))])
		if m.has_node("Warden"):
			_skeleton(String(id), m)
			_rest(String(id), m)
			var sk := WardenGlb.skeleton(m.get_node("Warden"))
			print("OWN bones ", sk.get_bone_count())
			var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
			print("OWN clips ", ap.get_animation_list().size() if ap else -1)
		m.free()
	print("OWNRIG_DONE failures: ", bad)
	tree.quit(1 if bad > 0 else 0)
