extends RefCounted
## --dex-filter-shots --shots-dir=<dir>: the Field Book filter bar at 1280x720 (xvfb with a renderer), on
## a made-up save (some species seen, some caught, two owned): dex_f0_all, dex_f1_types (two type chips),
## dex_f2_caught, dex_f3_more (the "Thrives in" row open on a zone), dex_f4_none (nothing passes).
## <dir>/captions.txt gets "file: caption" per file.

const BOOT_S := 5.0      # seconds the title screen needs before a menu can open over it

var lines: Array = []

func run(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	_fixture()
	var ids: Array = DexView.TYPES.keys()
	await main.get_tree().create_timer(BOOT_S).timeout
	await main.fade.reveal(0.01)
	await _shot(main, dir, "dex_f0_all", "No filter: every species, legendaries at the end")
	DexFilter.types = [ids[0], ids[1]]
	await _shot(main, dir, "dex_f1_types", "Two type chips on: a species of either type")
	DexFilter.reset()
	DexFilter.status = "caught"
	await _shot(main, dir, "dex_f2_caught", "Status Caught")
	DexFilter.reset()
	DexFilter.more_open = true
	DexFilter.zone = "z1"
	await _shot(main, dir, "dex_f3_more", "More: Thrives in a zone")
	DexFilter.reset()
	DexFilter.status = "owned"
	DexFilter.types = [ids[ids.size() - 1]]
	await _shot(main, dir, "dex_f4_none", "A filter nobody passes")
	DexFilter.reset()
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("DEXFILTERSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

## Seen, caught and owned species spread over the roster, and two zones over the first types.
func _fixture() -> void:
	var ids: Array = Data.KIN.keys()
	var dex := {}
	var roster := []
	for i in ids.size():
		if i % 3 == 0:
			dex[ids[i]] = {"seen": true, "caught": i % 2 == 0, "forms": [], "shimmer": false, "mutations": []}
		if i % 11 == 0:
			roster.append({"species": ids[i]})
	Save.d["dex"] = dex
	Save.d["roster"] = roster
	var types: Array = DexView.TYPES.keys()
	Content._cache["rules/garden_zones"] = {"zones": {
		"z1": {"name": "Bramblebank", "types": types.slice(0, 4)},
		"z2": {"name": "Glasswater", "types": types.slice(4, 7)}}}

func _shot(main: Node, dir: String, file: String, caption: String) -> void:
	Overlay.shot_demo(PackedStringArray(["inventory", "Field Book"]))
	await main.get_tree().create_timer(1.5).timeout
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])
