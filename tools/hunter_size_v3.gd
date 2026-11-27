extends "res://tools/hunter_size_sheet.gd"
## --hunter-size-v3 --shots-dir=<dir> --k-file=<json {"<arch>": k}> [--hero=a,b] [--verify]: each hunter alone on open
## floor at the game camera in a 3840x2160 frame, drawn at k 1 (live, <hero>_v3live.png) and at its k from the file
## (<hero>_v3new.png). One HFRM row per frame (crown height on screen, px per m, feet px). --verify reads the new-k
## body silhouette (HSIL lean rows, 8 facings) so the target on-screen height can be checked.
## Needs a renderer (jobq --needs gpu).

const FRAME := Vector2i(3840, 2160)
const GAME_ZOOM := 1.4572


func run(main_node: Node) -> void:
	main = main_node
	var heroes: Array = Arch.ids()
	var ks := {}
	var verify := false
	for a in OS.get_cmdline_user_args():
		if String(a) == "--verify":
			verify = true
		if String(a).begins_with("--hero="):
			heroes = String(a).substr(7).split(",")
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--k-file="):
			ks = JSON.parse_string(FileAccess.get_file_as_string(String(a).substr(9)))
	main.get_window().size = FRAME
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Settings.v["tips"] = false
	for hero in heroes:
		await _start(hero, "cindle")
		for h in m.hunters:
			h.out = h != m.player
		for kin in m.kins:
			kin.model.visible = false
		var at := _arena_spot(m.player.pos)
		_bare_floor(at)
		for tag in ["live", "new"]:
			var k := 1.0 if tag == "live" else float(ks.get(hero, 1.0))
			_draw_k(hero, k)
			m.cam.user_zoom = GAME_ZOOM
			m.cam.zoom = GAME_ZOOM
			m.cam.zoom_to = GAME_ZOOM
			m.player.render(0.0, 1.0)
			await _settle(at)
			m.player.render(0.0, 1.0)
			_clean()
			await _measure(hero, "v3" + tag)
			print("HFRM %s %s: k %.3f" % [hero, tag, k])
		if verify:
			m.cam.user_zoom = SIL_ZOOM
			m.cam.zoom = SIL_ZOOM
			m.cam.zoom_to = SIL_ZOOM
			await _settle(at)
			m.cam.lean_scale = 1.0
			await _silhouette(hero, "lean")
		m.queue_free()
	main.get_tree().quit(0)
