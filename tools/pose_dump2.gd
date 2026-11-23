extends RefCounted
## scratch (job dir only, never in the PR): --pose-dump --wardens=id --out=file.json [--calm-step=0.0333] [--step=0.125]
## each clip of the game lib sampled like tools/stretch_check.gd (settle 12 frames, then t=0..length step), every bone's
## global pose. Calm clips (idle, stance, walk_*, crouch_idle) use --calm-step.
var tree: SceneTree
const CALM := ["idle", "stance", "walk_f", "walk_b", "walk_l", "walk_r", "crouch_idle"]

func run(main: Node) -> void:
	Save.no_write = true
	tree = main.get_tree()
	var id := "ostra"
	var out := "/tmp/pose_dump.json"
	var step := 0.125
	var calm_step := 1.0 / 30.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wardens="): id = a.substr(10)
		if a.begins_with("--out="): out = a.substr(6)
		if a.begins_with("--step="): step = float(a.substr(7))
		if a.begins_with("--calm-step="): calm_step = float(a.substr(12))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var holder := Node3D.new()
	main.add_child(holder)
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	holder.add_child(m)
	for k in 30:
		await tree.process_frame
	var w := m.get_node("Warden")
	var sync := w.get_node("Sync")
	var clips: WardenClips = sync.get("clips")
	sync.set_process(false)
	var skel := WardenGlb.skeleton(w)
	var res := {}
	var times := {}
	for nm in clips.lib.get_animation_list():
		var length := clips.lib.get_animation(nm).length
		var st: float = calm_step if CALM.has(nm) else step
		clips.force = {"clip": nm, "t": 0.0}
		for k in 12:
			sync.call("_process", 1.0 / 30.0)
			await tree.process_frame
		var samples: Array = []
		var ts: Array = []
		var t := 0.0
		while t < length + st:
			var tt := minf(t, length - 0.001)
			clips.force = {"clip": nm, "t": tt}
			sync.call("_process", 1.0 / 30.0)
			for k in 2:
				await tree.process_frame
			var flat: Array = []
			for b in skel.get_bone_count():
				var g := skel.get_bone_global_pose(b)
				for v in [g.basis.x, g.basis.y, g.basis.z, g.origin]:
					flat.append_array([v.x, v.y, v.z])
			samples.append(flat)
			ts.append(tt)
			t += st
		res[nm] = samples
		times[nm] = ts
	clips.force = {}
	var names: Array = []
	for b in skel.get_bone_count():
		names.append(skel.get_bone_name(b))
	var rest: Array = []
	for b in skel.get_bone_count():
		var g := skel.get_bone_global_rest(b)
		for v in [g.basis.x, g.basis.y, g.basis.z, g.origin]:
			rest.append_array([v.x, v.y, v.z])
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"bones": names, "clips": res, "rest": rest, "times": times}))
	f.close()
	print("POSE_DUMP_DONE ", res.size())
	tree.quit()
