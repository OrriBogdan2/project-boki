extends "res://tools/vv_shots.gd"
## --rank-ui-shots --shots-dir=<dir>: the ability bar's rank marks in a live match (xvfb with a
## renderer), as Vex. 1 a fresh point: the gold + on every slot that can rank, the ALT+key hints,
## tier pips (E maxed in gold); 2 the same a few seconds on, the hint gone and only the + pulsing;
## 3 no points left: pips only. <dir>/captions.txt gets "file: caption" per file.

const BAR_CROP := Vector2i(560, 200)       # px: the bottom-left block with the ability bar

func run(main_node: Node) -> void:
	main = main_node
	who = "gunslinger"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	_ranks(1, {"sec": 1, "dash": 0, "kin": 3, "ult": 1}, 9)
	await _go(0.6, Callable(), [[0.5, "bar", "rank_fresh_point",
		"A new point: gold + on RMB, UNLOCK on locked dash, ALT+key hints, E's pips gold at max"]])
	await _go(6.0, Callable(), [[5.9, "bar", "rank_pulse",
		"Seconds later: the hints are gone (hover brings one back); the + and frame keep pulsing"]])
	_ranks(0, {"sec": 2, "dash": 1, "kin": 3, "ult": 1}, 9)
	await _go(0.6, Callable(), [[0.5, "bar", "rank_spent",
		"No points left: tier pips only (RMB 2/3, dash 1/3, E 3/3 in gold)"]])
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		var cols := String(l).split("|")
		f.store_line("%s: %s" % [cols[1], cols[2]])
	f.close()
	print("RANKSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _ranks(pts: int, ranks: Dictionary, level: int) -> void:
	P.lvl = level
	P.xp = float(Hunter.XP_TO[level - 1])
	P.slot_lv = ranks.duplicate()
	P.skill_pts = pts

func _take(kind: String, file: String, caption: String, _focus: Callable) -> void:
	var img := main.get_viewport().get_texture().get_image()
	var sz := img.get_size()
	img.save_png(dir.path_join(file + "_full.png"))
	var crop := img.get_region(Rect2i(0, sz.y - BAR_CROP.y, BAR_CROP.x, BAR_CROP.y))
	crop.resize(BAR_CROP.x * 2, BAR_CROP.y * 2, Image.INTERPOLATE_BILINEAR)
	crop.save_png(dir.path_join(file + ".png"))
	lines.append("%s|%s.png|%s" % [kind, file, caption])
