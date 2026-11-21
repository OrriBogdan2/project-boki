extends RefCounted
## --loading-check: the loading screen (scripts/ui/loading.gd). Every Hunter resolves a splash, a tip
## and a map name; then a real expedition load runs with the screen up and the bar is sampled every
## frame: it only moves forward, in steps small enough to read as smooth, passes the build and the
## graphics warm-up stages in order, and is full when the screen leaves.

const LOADING := "res://scripts/ui/loading.gd"
const TIMEOUT_S := 240.0       # a real load that takes longer than this is hung
const MAX_STEP := 0.25         # the most the bar may move in one frame (of a frame under HITCH_S)
const HITCH_S := 0.2           # a longer frame may carry the bar further: the load itself stalled
const REAL_LOAD := {"teams": 6, "squad": 1, "tier": 0, "seed": 7, "autoplay": true, "probe": true,
	"god": true, "plan_t": 3.0}

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LOADING %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d["tutorial"]["home"] = true
	if Save.d["roster"].is_empty():
		var tk := Save.new_kin("zapple", "Pip")
		Save.d["roster"].append(tk)
		Save.d["active"] = tk["uid"]
	_hunters()
	await _shots(main)
	await _real_load(main)
	print("LOADING DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Every Hunter: a splash that loads, a tip (none about the Blight when it is off), the map's name and mode line.
func _hunters() -> void:
	var ids := Arch.ids()
	ok(ids.size() >= 12, "every Hunter (%d)" % ids.size())
	for ak in ids:
		var ld: Node = load(LOADING).new()
		ld.setup({"teams": 10, "squad": 3, "tier": 0, "arch": ak})
		var tex: Texture2D = ld.splash
		var loads: bool = ld.splash_path != "" and tex != null and tex.get_width() > 0
		ok(loads, "%s: its splash loads (%s)" % [ak, ld.splash_path])
		ok(ld.tip != "", "%s: a tip" % ak)
		ok(ld.title != "" and ld.mode_line != "", "%s: the map's name and a mode line (%s)" % [ak, ld.title])
		ld.free()
		var calm: Node = load(LOADING).new()
		calm.setup({"teams": 10, "squad": 3, "tier": 0, "arch": ak, "blight": false})
		ok(calm.tip != "" and not calm.tip.contains("Blight"), "%s: no Blight tip when the Blight is off" % ak)
		calm.free()

## With --shots-dir=<dir> [--size=WxH]: the screen for a trio mid-load, as <dir>/loading_<W>x<H>.png.
func _shots(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			dir = a.substr(12)
		if a.begins_with("--size="):
			var wh := a.substr(7).split("x")
			main.get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	if dir == "":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	if main.fade != null:
		await main.fade.reveal(0.01)
	var ld: Node = load(LOADING).new()
	var opts := {"teams": 10, "squad": 3, "tier": 0, "arch": "gunslinger", "seed": 3}
	Prematch.deal_mates(opts)
	ld.setup(opts)
	main.add_child(ld)
	ld.want = 0.6
	ld.set_stage("graphics")
	for i in 40:
		await main.get_tree().process_frame
	var win := main.get_window().size
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("loading_%dx%d.png" % [win.x, win.y]))
	ld.queue_free()

func _screen(main: Node) -> Node:
	for ch in main.get_children():
		var sc = ch.get_script()
		if sc and String(sc.resource_path) == LOADING:
			return ch
	return null

## A real load: the bar's target and what it shows, every frame the screen is up.
func _real_load(main: Node) -> void:
	var opts := REAL_LOAD.duplicate()
	opts["arch"] = "mage"
	main.show_screen("match", opts)
	var tree := main.get_tree()
	var shown: Array = []          # [prog, want, frame seconds, stage] per frame
	var stages: Array = []
	var waited := 0.0
	var left := [-1.0]             # the bar as the screen leaves the tree (its last frame runs after our last sample)
	while waited < TIMEOUT_S:
		await tree.process_frame
		var dt := tree.root.get_process_delta_time()
		waited += dt
		var ld := _screen(main)
		if ld:
			if left[0] < 0.0 and shown.is_empty():
				ld.tree_exiting.connect(func() -> void: left[0] = float(ld.prog))
			shown.append([float(ld.prog), float(ld.want), dt, String(ld.stage_label)])
			if stages.is_empty() or stages[-1] != String(ld.stage_label): stages.append(String(ld.stage_label))
		elif not shown.is_empty() and main.current is Match and (main.current as Match).is_processing():
			break
	if main.current is Match:
		(main.current as Match).set_process(false)
	var what := "the load ran with the screen up (%d frames, %.1f s)" % [shown.size(), waited]
	ok(waited < TIMEOUT_S and shown.size() > 10, what)
	var back := 0
	var jumps := 0
	var want_back := 0
	for i in range(1, shown.size()):
		if shown[i][0] < shown[i - 1][0]: back += 1
		if shown[i][1] < shown[i - 1][1]: want_back += 1
		# a sample is taken before that frame's _process: the step into sample i ran in frame i - 1
		if shown[i][0] - shown[i - 1][0] > MAX_STEP and shown[i - 1][2] < HITCH_S:
			jumps += 1
			var at := [i, shown[i][3], shown[i - 1][0], shown[i][0], shown[i - 1][2]]
			print("LOADING jump at frame %d (%s): %.2f -> %.2f in %.3f s" % at)
	ok(back == 0, "the bar never goes backwards (%d frames did)" % back)
	ok(want_back == 0, "the stage target never goes backwards (%d frames did)" % want_back)
	ok(jumps == 0, "the bar never jumps more than %d%% in a normal frame (%d did)" % [int(MAX_STEP * 100.0), jumps])
	var last: float = shown[-1][0] if not shown.is_empty() else 0.0
	if left[0] >= 0.0:
		last = left[0]
	ok(last >= 0.99, "the bar is full when the screen leaves (%.2f)" % last)
	var names := ["Building the map", "Spawning", "Preparing graphics", "Ready"]
	var at := -1
	var order_ok := true
	for s in stages:
		var k := names.find(s)
		if k < at: order_ok = false
		at = maxi(at, k)
	# headless has nothing to warm up (Match.warm_up returns at once), so its graphics stage never shows
	var warm_seen := stages.has("Preparing graphics") or DisplayServer.get_name() == "headless"
	var seen := ", ".join(stages)
	var complete := order_ok and at == names.size() - 1 and warm_seen
	ok(complete, "the stages come in order, graphics warm-up included: " + seen)
