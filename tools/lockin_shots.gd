extends RefCounted
## --lockin-shots --shots-dir=<dir> [--hunters=a,b]: the pre-match lobby's stage with each Hunter's lock-in pose, a PNG
## of the stage per beat (<dir>/<hunter>_<beat>.png: 0.2, 0.5, 0.9, 1.3 s in, then idle). Needs a renderer.

const BEATS := [0.2, 0.5, 0.9, 1.3]
const WAIT_FRAMES := 900     # frames to wait for a model to build before the shot is skipped
const IDLE_AFTER := 0.6      # s after the pose: the idle frame

func run(main: Node) -> void:
	var tree := main.get_tree()
	var out := "lockin_shots"
	var ids: Array = Arch.ids()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--hunters="): ids = Array(a.substr(10).split(",", false))
	DirAccess.make_dir_recursive_absolute(out)
	Save.no_write = true
	Save.d = Save.fresh()
	var open := ClassUnlock.fresh()
	open["open"] = Arch.ids()
	Save.d["classes"] = open
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var view: Control = load("res://scripts/ui/prematch_view.gd").new()
	view.setup({"teams": 10, "squad": 1, "tier": 0})
	main.add_child(view)
	for ak in ids:
		view._choose(String(ak))
		var stage: HunterViewer = view.stage
		for _i in WAIT_FRAMES:
			if stage.model != null and stage.lockin_t >= 0.0:
				break
			await tree.process_frame
		for t in BEATS:
			while stage.lockin_t >= 0.0 and stage.lockin_t < t:
				await tree.process_frame
			await _grab(stage, "%s/%s_%.1f.png" % [out, ak, t])
		while stage.lockin_t >= 0.0:
			await tree.process_frame
		await tree.create_timer(IDLE_AFTER).timeout
		await _grab(stage, "%s/%s_idle.png" % [out, ak])
	print("LOCKIN_SHOTS_DONE %d" % ids.size())
	tree.quit()

func _grab(stage: HunterViewer, path: String) -> void:
	await RenderingServer.frame_post_draw
	stage.vp.get_texture().get_image().save_png(path)
