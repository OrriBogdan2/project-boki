extends RefCounted
## --first-choice-shots --shots-dir=<dir>: the naming card after the hatch, with its two ways on:
## "Tutorial" (bright) and "Skip tutorial" (flat grey). Run on a real GPU (jobq). File: <dir>/first_choice.png.

const HATCH := "res://scripts/ui/hatch.gd"


func run(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Save.d["tutorial"] = {"intro": true}
	Save.d["look"] = Unmasked.default_look()
	var tree := main.get_tree()
	if main.fade != null:
		main.fade.reveal(0.05)
	var hx = load(HATCH).new()
	main.add_child(hx)
	await tree.process_frame
	hx._looks_good()
	hx._pick(3)
	hx._show_name()
	await tree.create_timer(1.5).timeout
	tree.root.get_texture().get_image().save_png(dir.path_join("first_choice.png"))
	print("FIRSTCHOICE shot")
	tree.quit(0)
