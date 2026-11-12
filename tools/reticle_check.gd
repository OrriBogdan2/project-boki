extends RefCounted
## --reticle-check: the aiming reticle (Reticle) and its settings (Settings > Gameplay > Reticle).
##   1. the defaults: the small broken ring with a dot, white, full opacity, outlined, smaller than the
##      old cross (13 px out from the cursor)
##   2. set every option: the settings file holds them (they belong to the player, not the run save) and
##      the reticle's draw style follows
##   3. every shape and colour draws without errors, with and without the outline
## Runs with a temporary XDG_DATA_HOME: it writes user://settings.cfg.

const OLD_REACH := 13.0     # px: how far the old cross reached from the cursor at rest (gap 6 + arm 7)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("RETICLE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Settings.reset_all()
	var st := Reticle.style()
	var white: Color = Reticle.COLORS["white"][1]
	ok(st["shape"] == "default" and float(st["k"]) == 1.0 and st["outline"] == true, "defaults: %s" % str(st))
	ok((st["col"] as Color).is_equal_approx(white), "default colour: white at full opacity")
	ok(Reticle.RING_R + Reticle.LINE_W < OLD_REACH * 0.6, "the default is clearly smaller than the old cross")
	# ---------------------------------------------------------------- 2. set, persist, apply
	var want := {"reticle_shape": "cross", "reticle_size": 1.5, "reticle_col": "yellow", "reticle_alpha": 0.6,
		"reticle_outline": false}
	for key in want:
		Settings.set_v(key, want[key])
	var cf := ConfigFile.new()
	ok(cf.load(Settings.PATH) == OK, "the settings file exists")
	var saved := true
	for key in want:
		saved = saved and cf.get_value("s", key, null) == want[key]
	ok(saved, "every reticle option is in the settings file")
	var in_save: bool = Save.d.has("reticle_shape") or (Save.d.get("settings", {}) as Dictionary).has("reticle_shape")
	ok(not in_save, "nothing went into the run save")
	st = Reticle.style()
	var yellow: Color = Reticle.COLORS["yellow"][1]
	var col: Color = st["col"]
	ok(st["shape"] == "cross" and absf(float(st["k"]) - 1.5) < 0.001, "shape and size follow: %s" % str(st))
	ok(Color(col, 1.0).is_equal_approx(yellow) and absf(col.a - 0.6) < 0.001, "colour and opacity follow")
	ok(st["outline"] == false, "outline off follows")
	Settings.set_v("reticle_col", "nonsense")
	ok(Color(Reticle.style()["col"], 1.0).is_equal_approx(white), "an unknown colour id falls back to white")
	# ---------------------------------------------------------------- 3. every style draws
	var canvas := Control.new()
	canvas.size = Vector2(80, 80)
	main.add_child(canvas)
	var drawn := [0]
	canvas.draw.connect(func():
		for s in Reticle.SHAPES:
			for cid in Reticle.COLORS:
				Settings.v["reticle_shape"] = s[0]
				Settings.v["reticle_col"] = cid
				for outline in [true, false]:
					Settings.v["reticle_outline"] = outline
					Reticle.draw(canvas, Vector2(40, 40), 3.0)
					drawn[0] += 1)
	canvas.queue_redraw()
	for i in 3:
		await main.get_tree().process_frame
	var all_n := Reticle.SHAPES.size() * Reticle.COLORS.size() * 2
	ok(drawn[0] == all_n, "every shape x colour x outline draws (%d)" % drawn[0])
	canvas.queue_free()
	Settings.reset_all()
	print("RETICLE CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
