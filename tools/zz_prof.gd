extends RefCounted
func run(m: Node) -> void:
	var tree: SceneTree = m.get_tree()
	for i in 5:
		await tree.process_frame
	var ids := ["gunslinger", "juggernaut", "dolm", "tender", "thief", "gunslinger", "juggernaut"]
	for a in Arch.ids():
		WardenGlb.fetch(a)
	for i in 120:
		await tree.process_frame
	for a in ids:
		var t0 := Time.get_ticks_usec()
		WardenGlb.neutral_rest(a)
		var t1 := Time.get_ticks_usec()
		var mdl := PreviewBuild.model(a)
		var t2 := Time.get_ticks_usec()
		print("PROF %s rest=%.1f model=%.1f" % [a, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0])
		mdl.free()
		await tree.process_frame
	tree.quit(0)
