extends "res://tools/hit_shape_fine.gd"
## --hit-shape-shots --shots-dir=<dir> [--fine-hero=<arch>] (under xvfb or a GPU with a renderer): the inputs
## of --hit-shape-fine, each fired at a field of training dummies at the gameplay camera. Every dummy wears
## its ground circle, which is its hitbox (the shape hits what that circle touches), so a shape can be read
## against the circles: <dir>/<arch>_<n>_<input>_<k>.png (k = 0..2, early, middle, late) and
## <dir>/hits.txt (which dummies lost health, as metres ahead / aside of the hero).

const GAP := 2.5                 # m between dummies
const COLS := 7                  # dummies ahead: 2.5 .. 17.5 m
const ROWS := [-3.0, -1.5, 0.0, 1.5, 3.0]
const FRAME_DT := 1.0 / 30.0     # s of match per rendered frame

var axis_row := false            # a dummy stands on the aim line (an area move; a shot would stop on it)

func _slot(i: int) -> Vector3:
	var z: float = ROWS[i % ROWS.size()]
	if z == 0.0 and not axis_row: return home + Vector3(-6.0, 0.0, 6.0)
	return home + Vector3(GAP * float(1 + i / ROWS.size()), 0.0, z)

func run(main: Node) -> void:
	var dir := ""
	var only := ""
	var from := 0
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
		if String(a).begins_with("--fine-hero="): only = String(a).substr(12)
		if String(a).begins_with("--from-row="): from = int(String(a).substr(11))
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Save.d["tutorial"][KitDrill.SAVE_KEY] = true      # (no drill banner over the frame)
	n_dummies = COLS * ROWS.size()
	step_dt = FRAME_DT
	await _spawn(main)
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	for c in m.find_children("*", "CanvasLayer", true, false): (c as CanvasLayer).visible = false
	var log := FileAccess.open(dir.path_join("hits.txt"), FileAccess.WRITE)
	for a in HEROES:
		if only != "" and a != only: continue
		var n := -1
		for row in HEROES[a]:
			n += 1
			if n < from: continue
			var kind: String = row[0]
			axis_row = row.size() > 4
			for mb in m.mobs: mb.queue_free()
			m.mobs.clear()
			_prep(a)
			var secs: float = row[2]
			var marks := [0.1, secs * 0.45, secs * 0.9]
			var hit := {}
			var t := 0.0
			var k := 0
			while t < secs:
				_press(kind, row[1], t, t == 0.0)
				m.step(0.002 if t == 0.0 else FRAME_DT)
				t += FRAME_DT
				for i in _took_damage(): hit[i] = true
				for h in m.hunters: h.render(FRAME_DT, 1.0)
				m.cam.snap(home + Vector3(6.0, 0.0, 0.0))
				await main.get_tree().process_frame
				if k < marks.size() and t >= float(marks[k]):
					var png := "%s_%d_%s_%d.png" % [a, n, kind, k]
					main.get_viewport().get_texture().get_image().save_png(dir.path_join(png))
					k += 1
			_release()
			var spots: Array = []
			for i in hit: spots.append("%.1f/%.1f" % [_slot(i).x - home.x, _slot(i).z - home.z])
			log.store_line("%s %d %s hold %.2f: %d hit: %s" % [a, n, kind, row[1], hit.size(), " ".join(spots)])
	log.close()
	print("HIT SHAPE SHOTS done ", dir)
	main.get_tree().quit(0)
