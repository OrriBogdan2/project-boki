extends RefCounted
## --first15-shots --shots-dir=<dir> [--size=WxH] [--part=match|panels]: every screen of the first 15 minutes on a
## fresh save (title, prologue, hatch card, creator, eggs, name, first Hunter, tutorial steps, results, farm, expedition
## panel, Hunter pick, first expedition HUD, pause), one .jpg each plus <dir>/layout.txt with, per shot:
## the screen's UI controls (nodes, not the HUD's own drawing) that cross the window edge or sit inside the
## 5% margin. --part=match (first expedition and pause) or --part=panels (farm, expedition panel, Relics)
## plays one part alone from a made-up save.
## Needs a real renderer (jobq submit --needs gpu).
## Never writes the save. The write-up is docs/UI_FIRST15.md.

const MARGIN := 0.05          # fraction of the window kept free on every side (the safe area)
const TUT_END := 24           # tutorial step index after which the walk-through stops

var main: Node
var tree: SceneTree
var dir := "/tmp/first15"
var n := 0
var lines: PackedStringArray = []
var m: Match
var part := ""

func run(main_node: Node) -> void:
	main = main_node
	tree = main.get_tree()
	var win := Vector2i(1280, 720)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--part="):
			part = String(a).substr(7)
		elif String(a).begins_with("--size="):
			var p := String(a).substr(7).split("x")
			win = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	tree.root.size = win
	await _wait(1.0)
	match part:
		"match":
			_made_up_save()
			await _first_match()
		"panels":
			_made_up_save()
			await _farm()
		_:
			await _front()
			await _tutorial()
			await _farm()
			await _first_match()
	var f := FileAccess.open(dir.path_join("layout.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("FIRST15 %d shots in %s (%dx%d)" % [n, dir, win.x, win.y])
	tree.quit(0)

func _wait(s: float) -> void:
	await tree.create_timer(s).timeout

func _frames(k: int) -> void:
	for i in k:
		await tree.process_frame

func _screen() -> Node:
	return main.screen_node()

## A finished tutorial: one hatched Boki, Vex worn.
func _made_up_save() -> void:
	Save.d["look"] = Unmasked.default_look()
	Save.d["arch"] = "gunslinger"
	Save.d["cls"] = Arch.weight("gunslinger")
	Save.d["weapon"] = Arch.signature("gunslinger")
	var rec := Save.new_kin("cindle", "Ember")
	rec["trust"] = 55.0
	Save.d["roster"] = [rec]
	Save.d["active"] = rec["uid"]
	for k in ["intro", "prologue", "hatched", "match", "home"]:
		Save.d["tutorial"][k] = true

# ------------------------------------------------------------------ screens
func _front() -> void:
	main.show_screen("title", {})
	await _wait(3.5)
	await _shot("title")
	main.show_screen("prologue", {"then": "hatch"})
	await _wait(4.5)
	await _shot("prologue_1")
	var pr := _screen()
	pr.set("shot_t", 9.0)
	pr._advance()
	await _wait(4.0)
	await _shot("prologue_2")
	main.show_screen("hatch", {})
	await _wait(3.5)
	var hx := _screen()
	await _shot("hatch_card")
	hx._end_intro()
	await _wait(2.0)
	await _shot("creator")
	hx._looks_good()
	await _wait(1.5)
	await _shot("hatch_eggs")
	hx._pick(0)
	await _wait(0.8)
	hx._pick(0)
	await _wait(1.5)
	await _shot("hatch_knock")
	hx._show_name()
	await _wait(1.0)
	await _shot("hatch_name")
	hx._finish(String(hx.egg_defs[0]["species"]), "", "", true)
	await _wait(2.5)
	await _shot("first_mask")
	hx.queue_free()
	await _frames(2)

func _tutorial() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0})
	m.set_process(false)
	await _wait(0.5)
	await _shot("tutorial_intro")
	m.tut.ack()
	var seen := {}
	var guard := 0
	while guard < 9000 and m.tut.step < TUT_END and not m.player.extracted:
		guard += 1
		TutorialDrive.drive(m)
		for i in 2:
			m.step(Match.DT)
		m.cam.snap(m.player.pos)
		var sid := m.tut.id()
		if m.tut.t >= 1.5 and not seen.has(sid):
			seen[sid] = true
			await _shot("tutorial_%02d_%s" % [m.tut.step, sid])
		if guard % 4 == 0:
			await _frames(1)
	# the end: keep playing until the match hands over to the results
	guard = 0
	while guard < 6000 and is_instance_valid(m) and m.is_inside_tree() and not m.over:
		guard += 1
		TutorialDrive.drive(m)
		m.step(Match.DT)
		if guard % 4 == 0:
			await _frames(1)
	await _wait(1.0)
	if is_instance_valid(m):
		m.queue_free()      # (the match was added here, not by Main, so Main's screen change leaves it behind)
	await _wait(3.0)
	await _shot("results")

func _farm() -> void:
	main.show_screen("home", {})
	var guard := 0
	while guard < 600 and (_screen() == null or _screen().get("player") == null):
		guard += 1
		await _wait(0.5)
	await _wait(2.5)
	await _shot("farm_arrival")
	await _wait(8.0)
	await _shot("farm_after_8s")
	var h := _screen()
	h._open_expedition()
	await _wait(1.2)
	await _shot("expedition_panel")
	HomeClasses.open(h, Arch.of_save())
	await _wait(1.2)
	await _shot("hunter_pick")
	h._close_panel()

func _first_match() -> void:
	if main.current:
		main.current.queue_free()
	await _frames(2)
	m = Match.new()
	main.add_child(m)
	main.current = m      # (the pause menu reads the screen's options from Main's current screen)
	await m.start({"teams": Data.MATCH_PLAYERS, "squad": 1, "total": Data.MATCH_PLAYERS, "tier": 0, "seed": 7})
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)      # (this part never went through show_screen, which lifts the cover)
	await _wait(0.5)
	await _shot("expedition_plan")
	var guard := 0
	while guard < 3000 and m.skydrop.planning:
		guard += 1
		m.step(Match.DT)
		if guard % 4 == 0:
			await _frames(1)
	await _shot("expedition_ship")
	m.ship_jump(m.player, true)
	m.player.teleport(m.world.spawns[0])      # (the drop itself is not under test: land on the first spawn)
	guard = 0
	while guard < 2400 and not (m.player.grounded and not m.player.dropping):
		guard += 1
		m.step(Match.DT)
		if guard % 4 == 0:
			await _frames(1)
	await _shot("expedition_landed")
	for i in 900:
		m.step(Match.DT)
		if i % 4 == 0:
			await _frames(1)
	await _shot("expedition_15s")
	Overlay.open_pause("match")
	await _wait(1.0)
	await _shot("pause")

# ------------------------------------------------------------------ shots and layout
## Saves the window as <dir>/NN_<what>.jpg and appends what the layout scan found to the report.
func _shot(what: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	n += 1
	var vp := main.get_viewport()
	vp.get_texture().get_image().save_jpg(dir.path_join("%02d_%s.jpg" % [n, what]), 0.85)
	var view := vp.get_visible_rect().size
	lines.append("## %02d_%s (window %dx%d, laid out in %dx%d)" % [n, what, vp.size.x, vp.size.y, view.x, view.y])
	_scan_controls(main, view, false)

## Visible controls that cross the window edge or sit inside the margin (ones inside a scroll area
## or clipping parent are skipped: they are cut on purpose).
func _scan_controls(nd: Node, view: Vector2, clipped: bool) -> void:
	var cut := clipped
	if nd is CanvasItem and not (nd as CanvasItem).visible:
		return
	if nd is Control:
		var c := nd as Control
		cut = cut or c.clip_contents or c is ScrollContainer
		var r := c.get_global_rect()
		var texty := c is Label or c is BaseButton or c is RichTextLabel or c is LineEdit
		if not cut and texty and r.size.x > 2.0 and r.size.y > 2.0 and r.size.x < view.x - 2.0:
			var why := _breach(r, view)
			if why != "":
				var txt: String = c.get("text") if c.get("text") != null else ""
				lines.append("  %s %s \"%s\" at %s" % [why, c.get_class(), txt.left(40).replace("\n", " "), _fmt(r)])
	for ch in nd.get_children():
		_scan_controls(ch, view, cut)

func _breach(r: Rect2, view: Vector2) -> String:
	if r.position.x < -1.0 or r.position.y < -1.0 or r.end.x > view.x + 1.0 or r.end.y > view.y + 1.0:
		return "CLIPPED"
	var mx := view.x * MARGIN
	var my := view.y * MARGIN
	if r.position.x < mx or r.position.y < my or r.end.x > view.x - mx or r.end.y > view.y - my:
		return "margin"
	return ""

func _fmt(r: Rect2) -> String:
	return "%d,%d %dx%d" % [r.position.x, r.position.y, r.size.x, r.size.y]
