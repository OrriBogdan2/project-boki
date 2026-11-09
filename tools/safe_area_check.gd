extends RefCounted
## --safe-area-check: the HUD and the main screens at five window sizes (1280x720, 1920x1080, 2560x1440,
## 2560x1080 ultrawide, 1024x640). At each, every group (a registered HUD panel, or a top-level control of a
## screen) sits inside SafeArea's margin and no two groups of one screen overlap. The match HUD is read from
## SafeArea's registry; the pick (prematch), pause, results, farm HUD and expedition panel from their controls.
## --safe-area-shots [--size=WxH] --shots-dir=<dir>: the same run with a real renderer, one PNG per screen
## and size (<dir>/<W>x<H>_<screen>.png) and a contact sheet of them.

const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(2560, 1080),
		Vector2i(1024, 640)]
const RESULT := {"extracted": true, "gems": 42, "seeds": {"sunroot": 1}, "caught": [], "knocks": 3, "damage": 512,
		"taken": 388, "kills": 1, "downs": 1, "deaths": 0, "revives": 2, "armor_tier": 3, "time": 201.0}

var main: Node
var bad := 0
var shots := ""
var sizes: Array = SIZES.duplicate()
var m: Match
var home

func ok(cond: bool, what: String) -> void:
	print("SAFEAREA %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(mn: Node, mode: String) -> void:
	main = mn
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots = String(a).substr(12)
		if String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			sizes = [Vector2i(int(wh[0]), int(wh[1]))]
	if mode == "shots":
		DirAccess.make_dir_recursive_absolute(shots)
	if main.fade:
		await main.fade.reveal(0.01)
	await _hud()
	await _screens()
	await _farm()
	print("SAFEAREA DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

## Resizes the window and returns the logical size the interface is laid out in.
func _resize(win: Vector2i) -> Vector2:
	main.get_tree().root.size = win
	await _frames(3)
	return main.get_tree().root.get_visible_rect().size

func _judge(screen: String, win: Vector2i, groups: Dictionary, sz: Vector2) -> void:
	var tag := "%dx%d %s" % [win.x, win.y, screen]
	var problems := SafeArea.problems(groups, sz)
	var what := "%s: %d groups in the %d px margin, no overlap (logical %s) %s"
	ok(not groups.is_empty() and problems.is_empty(),
			what % [tag, groups.size(), int(SafeArea.MARGIN), sz, problems.slice(0, 4)])
	if shots != "":
		await _frames(2)
		main.get_viewport().get_texture().get_image().save_png("%s/%dx%d_%s.png" % [shots, win.x, win.y, screen])

func _hud() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 3, "tier": 0, "length": 1500.0, "seed": 7, "demo_kin": "cindle"})
	m.set_process(false)
	main.current = m      # (the pause menu reads its options; the next screen frees it)
	for line in ["Kael knocked Ryzz down", "Team 3 is out", "Ember revived Pip"]:
		m.feed.append({"text": line, "t": 0.0})
	m.hud.toast("Picked up a long-range rifle", Color.WHITE)
	m.hud.toast("Armor cracked: it held one more hit", Color.WHITE)
	for win: Vector2i in sizes:
		var sz := await _resize(win)
		await _hud_at(win, sz, "drop")
		m.player.riding = false
		m.player.dropping = false
		await _hud_at(win, sz, "hud")
		Overlay.open_pause("match")
		await main.get_tree().create_timer(0.8).timeout
		await _judge("pause", win, SafeArea.groups_of(Overlay.host, sz), sz)
		Overlay.close()

func _hud_at(win: Vector2i, sz: Vector2, screen: String) -> void:
	SafeArea.seen.clear()
	SafeArea.recording = true
	m.hud.panels.queue_redraw()
	await _frames(4)
	SafeArea.recording = false
	SafeArea.seen["toasts"] = m.hud.msgs.rects()
	await _judge(screen, win, SafeArea.seen.duplicate(), sz)

func _screens() -> void:
	for win: Vector2i in sizes:
		var sz := await _resize(win)
		main.show_screen("prematch", {"teams": 10, "squad": 3, "tier": 0})
		await main.get_tree().create_timer(0.8).timeout
		await _judge("pick", win, SafeArea.groups_of(main.current, sz), sz)
		main.show_screen("results", RESULT)
		await main.get_tree().create_timer(1.0).timeout
		await _judge("results", win, SafeArea.groups_of(main.current, sz), sz)

func _farm() -> void:
	home = await main._hb_home()
	for i in 600:
		if home.root_ui != null and home.hub != null and home.player != null:
			break
		await _frames(1)
	home._close_panel()
	for win: Vector2i in sizes:
		var sz := await _resize(win)
		await main.get_tree().create_timer(0.6).timeout
		home._close_panel()      # (a Boki's evolve card can open by itself: it is a panel, not the farm HUD)
		await _frames(2)
		await _judge("farm", win, SafeArea.groups_of(home.root_ui, sz), sz)
		home._open_expedition()
		await main.get_tree().create_timer(0.8).timeout
		await _judge("expedition", win, SafeArea.groups_of(home.panel_host, sz), sz)
