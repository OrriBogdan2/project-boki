extends RefCounted
## --tutorial-strip-shots --shots-dir=<dir> [--size=WxH]: the one objective strip of both tutorials at the
## window's size, as <dir>/<WxH>_<what>.jpg: the match tutorial's first step pulsing (just changed) and calm
## (3 s on, two notices in the lane beside it), then the farm tutorial's first step pulsing and calm. Also
## prints each strip's rect and whether it is inside the title-safe margin and clear of the message lane.
## Needs a real renderer (jobq submit --needs gpu). Never writes the save.

var main: Node
var tree: SceneTree
var dir := "/tmp/tutorial_strip"
var win := Vector2i(1280, 720)
var bad := 0

func _wait(s: float) -> void:
	await tree.create_timer(s).timeout

func _shot(what: String) -> void:
	await tree.process_frame
	var img := tree.root.get_viewport().get_texture().get_image()
	img.save_jpg(dir.path_join("%dx%d_%s.jpg" % [win.x, win.y, what]), 0.9)

## The farm strip's rect in window pixels (the farm's UI root is scaled up on big screens).
func _on_screen(sv: StripView) -> Rect2:
	var r := sv.rect()
	var xf := sv.get_global_transform_with_canvas()
	var k := tree.root.content_scale_factor      # Settings scales the node UI with the window height
	return Rect2(xf * r.position * k, r.size * xf.get_scale() * k)

func _check(what: String, r: Rect2, notice: Rect2) -> void:
	var sz := Vector2(win)
	var margin := maxf(24.0, sz.y * 0.04)
	var inside := Rect2(Vector2.ZERO, sz).grow(-margin + 1.0).encloses(r)
	var slim := r.size.y <= sz.y * 0.06 + 0.5
	var clear := not r.intersects(notice)
	var good := inside and slim and clear
	var verdict := "PASS" if good else "FAIL"
	print("TUTSTRIP %s %s rect=%s safe=%s slim=%s clear=%s" % [verdict, what, r, inside, slim, clear])
	if not good:
		bad += 1

func run(main_node: Node) -> void:
	main = main_node
	tree = main.get_tree()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--size="):
			var p := String(a).substr(7).split("x")
			win = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	tree.root.size = win
	await _wait(1.0)
	if main.fade: main.fade.reveal(0.05)      # the boot splash stays up for a screen a tool starts
	await _match()
	await _farm()
	print("TUTSTRIP DONE, failures: ", bad)
	tree.quit(1 if bad > 0 else 0)

func _match() -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	m.tut.ack()
	var guard := 0
	while guard < 4000 and m.tut.id() != "land" and m.tut.step < 2:
		guard += 1
		TutorialDrive.drive(m)
		m.step(Match.DT)
	for i in 14:      # 0.25 s into the step: the strip pops and pulses
		m.step(Match.DT)
		await tree.process_frame
	var lane: Rect2 = TutorialHud.lanes(Vector2(win))["toast"]
	_check("match strip", TutorialStrip.rect(Vector2(win)), lane)
	await _shot("match_pulse")
	for i in 40:
		m.step(Match.DT)
	m.hud.toast("Notice one", Color.WHITE)
	m.hud.toast("Notice two", Color.WHITE)
	m.tut.card_t = 3.0
	await _wait(0.5)
	await _shot("match_calm")
	m.queue_free()
	await _wait(0.5)

func _farm() -> void:
	var rec := Save.new_kin("cindle", "Ember")
	Save.d["roster"] = [rec]
	Save.d["active"] = rec["uid"]
	main.show_screen("home", {})
	var guard := 0
	while guard < 600 and (main.screen_node() == null or main.screen_node().get("player") == null):
		guard += 1
		await _wait(0.5)
	await _wait(1.0)
	var h = main.screen_node()
	if String(h.panel_open) == "Welcome home":
		h._close_panel()      # its dim would hide the strip; closed as its "Let's go" does
		await _wait(0.5)
	print("TUTSTRIP farm tutorial active: ", FarmTutorial.active(), " step ", FarmTutorial.current())
	h.guide.tick(0.6)
	await _wait(0.25)
	await _shot("farm_pulse")
	await _wait(3.0)
	var notice := Rect2(Vector2(win.x * 0.72, 0), Vector2(win.x * 0.28, win.y * 0.04))
	_check("farm strip", _on_screen(h.guide.hint_box), notice)
	await _shot("farm_calm")
