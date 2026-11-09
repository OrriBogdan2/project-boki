extends RefCounted
## --demo-quick-check: Settings > Demo's quick starts and recording mode's frame pacing.
## Recording mode caps frames at Record.REC_FPS with v-sync and gives the player's cap back when off.
## Each quick start (DemoQuick) is up within READY_S with no tutorial: the expedition has every seat
## filled, its bots in showcase Hunters and every kit open; the farm's Boki are evolved and its Goals card
## steps aside while recording; the hatch opens on the creator.
## Neither the real save file nor Save.d is touched: the title screen gives the real one back.
## With --shots-dir=<dir> (a real GPU run) each path also saves screenshots and logs its frame times:
##   jobq submit --needs gpu -- godot -- --demo-quick-check --record --shots-dir=/tmp/dq

const READY_S := 10.0          # s: the most a quick start may take to be playable
const WATCH_S := 12.0          # s: how long each path runs for its frame times and second shot
const FORMS_MIN := 3           # Evo forms every grown-farm Boki has (DemoQuick.FARM_LEVEL 13)

var main: Node
var fails := 0
var count := 0
var shots := ""

func ok(what: String, cond: bool, info := "") -> void:
	count += 1
	printerr("DEMOQ %-52s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): shots = String(a).substr(12)
	if shots != "": DirAccess.make_dir_recursive_absolute(shots)
	Save.no_write = true
	_pacing()
	var real := Save.d
	for id in DemoQuick.IDS:
		await _path(String(id))
		Game.goto("title")
		var t0 := Time.get_ticks_msec()
		while not is_same(Save.d, real) and Time.get_ticks_msec() - t0 < 5000:
			await main.get_tree().process_frame    # (with a GPU the screens fade, so the title takes a moment)
		ok("%s: the real save is back on the title" % id, is_same(Save.d, real) and Save.no_write)
	print("DEMOQ DONE, %d checks, failures: %d" % [count, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _pacing() -> void:
	var was := Record.level
	var cap: int = Settings.get_v("max_fps")
	Settings.v["max_fps"] = 144       # (not set_v: a check never writes the settings file)
	Record.set_level(1)
	ok("recording: frame cap", Engine.max_fps == Record.REC_FPS, "max_fps %d" % Engine.max_fps)
	ok("recording: v-sync forced on", Record.vsync(false))
	Record.set_level(0)
	ok("off: the player's cap back", Engine.max_fps == 144, "max_fps %d" % Engine.max_fps)
	ok("off: the player's v-sync back", not Record.vsync(false))
	Settings.v["max_fps"] = cap
	Record.set_level(was)

func _path(id: String) -> void:
	var t0 := Time.get_ticks_msec()
	DemoQuick.start(id)
	var scr: Node = null
	while (Time.get_ticks_msec() - t0) < 30000:
		await main.get_tree().process_frame
		scr = main.screen_node()
		if _up(id, scr):
			break
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	ok("%s: ready in under %.0f s" % [id, READY_S], _up(id, scr) and secs < READY_S, "%.1f s" % secs)
	ok("%s: a made-up save, never written" % id, Save.no_write)
	if not _up(id, scr):
		return
	match id:
		"expedition": _expedition(scr as Match)
		"farm": _farm(scr)
		"hatch": _hatch(scr)
	await _shot(id, "a")
	await _watch(id, scr)
	await _shot(id, "b")

func _up(id: String, scr: Node) -> bool:
	if not is_instance_valid(scr) or not scr.is_inside_tree():
		return false
	match id:
		"expedition":
			var ld = main.get("_ld")
			return scr is Match and (scr as Match).player != null and not (ld != null and is_instance_valid(ld))
		"farm":
			return scr.get("player") != null and not (scr.get("kins") as Array).is_empty()
		"hatch":
			return String(scr.get("stage")) == "create"
	return false

func _expedition(m: Match) -> void:
	ok("expedition: not a tutorial", not m.opts.get("tutorial", false))
	ok("expedition: every seat filled", m.hunters.size() == Data.MATCH_PLAYERS, "%d hunters" % m.hunters.size())
	var off: Array = []
	for h in m.hunters:
		if h != m.player and not String(h.arch) in DemoQuick.SHOWCASE: off.append(h.arch)
	ok("expedition: bots in showcase Hunters", off.is_empty(), str(off))
	ok("expedition: you as %s" % DemoQuick.YOU, String(m.player.arch) == DemoQuick.YOU, String(m.player.arch))
	var shut: Array = m.hunters.filter(func(h): return int(h.slot_lv["ult"]) < 1 or int(h.slot_lv["sec"]) < 1)
	ok("expedition: every kit open (no padlocks)", shut.is_empty(), "%d locked" % shut.size())

func _farm(h: Node) -> void:
	var tut: Dictionary = Save.d["tutorial"]
	ok("farm: no tutorial", bool(tut.get("home", false)) and bool(tut.get("day1_done", false)))
	var low: Array = []
	for r in Save.d["roster"]:
		if (r.get("forms", []) as Array).size() < FORMS_MIN: low.append(r["name"])
	ok("farm: every Boki evolved", low.is_empty(), "%d Boki, short: %s" % [Save.d["roster"].size(), low])
	ok("farm: the base built", (Save.d["layout"]["deco"] as Array).size() >= 10 and h.get("hb") != null)
	var card = (h.get("guide") as FarmGuide).tracker
	var was := Record.level
	Record.set_level(1)
	Record.tick(main.get_tree(), 0.0)
	ok("farm: no Goals card while recording", not is_instance_valid(card) or not card.visible)
	Record.set_level(was)
	Record.tick(main.get_tree(), 0.0)

func _hatch(hs: Node) -> void:
	ok("hatch: no intro card", hs.get("card_box") == null or not is_instance_valid(hs.get("card_box")))

## Runs the path for WATCH_S of real frames and logs their times; the hatch is played through meanwhile.
func _watch(id: String, scr: Node) -> void:
	var t0 := Time.get_ticks_usec()
	var last := t0
	var worst := 0
	var frames := 0
	var played := false
	while Time.get_ticks_usec() - t0 < int(WATCH_S * 1e6):
		await main.get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
		frames += 1
		if id == "hatch" and not played and now - t0 > 3e6 and is_instance_valid(scr):
			played = true
			scr.call("_looks_good")
			scr.set("auto_warm", true)
			scr.call("_pick", 0)
			scr.call("_pick", 0)
	var wall := (last - t0) / 1e6
	print("DEMOQ FPS %s: %.1f fps avg over %.0f s, worst frame %.1f ms" % [id, frames / wall, wall, worst / 1000.0])

func _shot(id: String, tag: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	if img and not img.is_empty():
		img.save_png("%s/demo_%s_%s.png" % [shots, id, tag])
