extends RefCounted
## --next-form-shots=<dir>: a Boki card's Growth tab on the farm with its Next form block (EvoView), one
## shot per line: soon.png as the data stands (a Vespyx: Vespox has no model yet), then level.png and
## ink.png with a test line in the loaded rules standing in for a next form that has art. Run with a
## real renderer and --resolution 1280x720. Never touches the real save. Prints "NFSHOT <name>".

const TEST_INTO := "pebbit"       # any species with art: the line names the level or the Ink, never the form

var main: Node
var dir := ""

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--next-form-shots="):
			dir = String(a).substr(18)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("cindle", "Ash")
	rec["starter"] = true
	rec["level"] = 9
	rec["xp"] = 450
	Care.ensure(rec)
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
	Save.d = d
	var home = await main._hb_home()
	while home.root_ui == null or home.panel_host == null:
		await main.get_tree().process_frame
	if main.fade:
		main.fade.reveal(0.05)
	home.kin_tab = "Growth"
	var lines: Dictionary = Evo.rules()["lines"]
	var own: Dictionary = lines["cindle"]
	await _shot(home, rec, "soon")
	lines["cindle"] = {"level": int(own["level"]), "into": [{"id": TEST_INTO}]}
	await _shot(home, rec, "level")
	lines["cindle"] = {"into": [{"id": TEST_INTO, "item": "ink_tide"}]}
	await _shot(home, rec, "ink")
	lines["cindle"] = own
	print("NFSHOT DONE")
	main.get_tree().quit()

## Opens the card on the Growth tab, lets it settle and saves <dir>/<shot_name>.png.
func _shot(home: Node, rec: Dictionary, shot_name: String) -> void:
	home._open_kin(rec)
	await main.get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
	print("NFSHOT %s %s %s" % [shot_name, main.get_viewport().get_visible_rect().size, EvoView.next_form(rec)])
