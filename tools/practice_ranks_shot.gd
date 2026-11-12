extends RefCounted
## --practice-ranks-shot --shots-dir=<dir> (GPU): the Training Area's Esc-menu Practice page after
## Max all, as <dir>/practice_page.png (1280x720).

func run(main: Node) -> void:
	var tree := main.get_tree()
	var out := "user://practice_ranks_shot"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): out = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	main.get_window().size = Vector2i(1280, 720)
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts())
	for i in 30: await tree.process_frame
	PracticeRanks.max_all(m.player)
	Overlay.ctx = "match"
	Overlay.open_practice(m.player)
	for i in 30: await tree.process_frame
	if main.get("fade"): (main.get("fade") as CanvasLayer).visible = false
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(out.path_join("practice_page.png"))
	print("PRACTICE_RANKS_SHOT_DONE")
	tree.quit()
