extends RefCounted
## --mask-lag-check: frame times while Mask cards are on screen and while one is accepted (item 88). Each
## scenario opens a screen on the farm, times every frame for a few seconds and reports the slowest, the median
## and how many went over the budget:
##   masks_first   the session's first Masks screen: reported, not judged (the first menu of a session pays
##                 one-time costs: fonts, themes)
##   masks_open    the Masks screen (12 tiles, the viewer's turntable and its ability clips)
##   masks_switch  clicking another Mask on that screen
##   reveal        a new Mask's reveal (its splash and clips)
##   offer         Hob's second-Mask offer: the three Masks side by side
##   offer_focus   moving the focus to another of the three
##   accept        picking one (Hob's answer types out)
##   put_on        the click after it: the short Mask moment starts
## Headless (nothing drawn) the time is the scripts' alone and a frame over BUDGET_MS fails, except a frame that
## built a Mask's model (PreviewBuild allows one a frame; reported with its time). Every scenario also counts the
## 3D previews rendering at once. Under xvfb with a software rasterizer every frame also pays the raster, so the
## times are reported, not judged.
##   xvfb-run -a godot --rendering-driver opengl3 --audio-driver Dummy -- --mask-lag-check

const BUDGET_MS := 33.0        # ms: two frames at 60 fps, the item's target
const SECS := 2.5              # s each scenario is timed headless
const DRAWN_SECS := 12.0       # s with a software rasterizer: a frame there costs 0.2-0.7 s
const SETTLE_FRAMES := 30      # frames the farm gets to load its last pieces before the first scenario
const MASKS_VIEWS := 2         # the Masks screen: the turntable and the ability clip in focus

var main: Node
var bad := 0
var headless := false
var home = null

func ok(cond: bool, what: String) -> void:
	print("MASKLAG %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	headless = DisplayServer.get_name() == "headless"
	if main.fade:
		main.fade.reveal(0.05)
	_new_save()
	home = await main._hb_home()
	var tree: SceneTree = main.get_tree()
	for i in SETTLE_FRAMES:
		await tree.process_frame
	home._close_panel()
	await _time("masks_first", func(): HomeClasses.open(home, "gunslinger"), MASKS_VIEWS, false)
	home._close_panel()
	await _time("masks_open", func(): HomeClasses.open(home, "gunslinger"), MASKS_VIEWS)
	await _time("masks_switch", func(): HomeClasses._show(home, "juggernaut"), MASKS_VIEWS)
	home._close_panel()
	await _time("reveal", func(): ClassReveal.show_for(home, "dolm"), 1)
	for rv in home.find_children("*", "ClassReveal", false, false):
		(rv as ClassReveal).queue_free()
	await _offer_scenarios(tree)
	print("MASKLAG DONE (%s), failures: %d" % ["headless: scripts only" if headless else "drawn", bad])
	tree.quit(1 if bad > 0 else 0)

## Vex worn, the first expedition done: the second Mask is on offer.
func _new_save() -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
	Save.d = d
	HomeLayout.ensure(Save.d)      # (a farm-start island, where Hob is)
	d["tutorial"]["home"] = true
	ClassUnlock.choose_starters(["gunslinger"])
	ClassUnlock.open_bonus()

## Hob's offer: the talk opened straight on the pick (HobTalk, HobOffer), a focus move, then taking Pip.
func _offer_scenarios(tree: SceneTree) -> void:
	var chat: HobTalk = home.hob.chat
	await _time("offer", func():
		chat.start()
		chat._show_offer(), 1)
	await _time("offer_focus", func(): chat.offer.focus(2), 1)
	await _time("accept", func():
		chat.offer.pick("tender")
		chat.box.advance())
	await _time("put_on", func(): chat.box.advance())
	ok(ClassUnlock.is_open("tender"), "the pick opened Pip")
	await tree.process_frame

## Runs `act` at the start of a frame and times the frames that follow. A frame that built a Mask's model
## (PreviewBuild: at most one a frame) is reported apart: tens of ms on this kind of machine, once per model.
func _time(scenario: String, act: Callable, max_views := -1, judged := true) -> void:
	var tree: SceneTree = main.get_tree()
	await tree.process_frame
	var plain: Array = []
	var builds: Array = []
	var views := 0
	var last_us := Time.get_ticks_usec()
	act.call()
	var t0 := last_us
	var secs := SECS if headless else DRAWN_SECS
	while Time.get_ticks_usec() - t0 < int(secs * 1000000.0):
		await tree.process_frame
		var now := Time.get_ticks_usec()
		var built := PreviewBuild.last_frame == Engine.get_process_frames() - 1
		(builds if built else plain).append((now - last_us) / 1000.0)
		if not built and now - last_us > int(BUDGET_MS * 1000.0):
			var n := plain.size() + builds.size()
			print("MASKLAG   %s: frame %d took %.1f ms" % [scenario, n, (now - last_us) / 1000.0])
		last_us = now
		views = maxi(views, _live_views(home))
	plain.sort()
	var worst := float(plain[-1]) if not plain.is_empty() else 0.0
	var build_max := float(builds.max()) if not builds.is_empty() else 0.0
	print("MASKLAG %-13s frames=%3d  max=%7.1f ms  median=%6.1f ms  model builds=%d (max %.1f ms)  views=%d" % [
			scenario, plain.size() + builds.size(), worst, float(plain[plain.size() / 2]), builds.size(), build_max,
			views])
	if headless and judged:
		var what := "%s: no frame over %d ms outside a model build (%.1f)" % [scenario, int(BUDGET_MS), worst]
		ok(worst <= BUDGET_MS, what)
	if max_views >= 0:
		ok(views <= max_views, "%s: at most %d 3D previews render a frame (%d)" % [scenario, max_views, views])

## The SubViewports that render every frame under `n` (a still or an unbuilt clip doesn't).
func _live_views(n: Node) -> int:
	var live := 0
	for vp in n.find_children("*", "SubViewport", true, false):
		var mode := (vp as SubViewport).render_target_update_mode
		if mode == SubViewport.UPDATE_ALWAYS or mode == SubViewport.UPDATE_WHEN_VISIBLE:
			live += 1
	return live
