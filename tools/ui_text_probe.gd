extends RefCounted
## --ui-text-probe-check [--size=WxH] [--scenes=a,b] [--report=<file>]: opens every reachable screen, panel, popup
## (title, prologue, the hatch creator, eggs and naming, results, the pick, the farm and its panels, settings, the
## pause menu, the inventory and Field Book, a tooltip, a confirm box, the match HUD) at 1280x720, 1920x1080 and
## 2560x1440 and runs UiTextScan on each: no text one letter per line (a narrow wrapped column), no text over
## 6 lines for under 40 characters, none outside the window, none drawn over other text. Needs no GPU (layout only).
## --shots-dir=<dir> also saves a jpg per scene (xvfb-run, LP_NUM_THREADS=2).
## Never writes the save. The check fails on any hit that is not in KNOWN.
## Docs: docs/UI_TEXT_PROBE.md.

const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const BIG_TEXT := 1.5  # Settings text size of the extra pass, at the first window size (the biggest choice)
const SETTLE_S := 0.6  # seconds a screen gets to build and fade in before it is scanned
## [scene, node path prefix, rule] of a hit another branch is fixing; delete the entry when it merges.
## The naming column of hatch.gd (ext/name-it-vertical-1117).
const KNOWN := [["hatch_name", "Main/", "narrow"], ["hatch_name", "Main/", "outside"]]

var main: Node
var tree: SceneTree
var scene := ""
var only: PackedStringArray = []
var size_px := Vector2i(1280, 720)
var hits := {}  # "scene|path|rule" -> {scene, path, rule, text, detail, sizes: []}
var screens_seen := {}  # scene -> true
var seen_texts := {}  # scene -> most text controls any size scanned
var shots := ""  # --shots-dir=<dir>: one picture per scene scanned (needs a real renderer)
var self_bad := 0
var text_k := 1.0  # Settings text size of this pass
var text_arg := 0.0
var report := ""
var _plain := RegEx.create_from_string("@(\\w+)@\\d+")


func run(mn: Node) -> void:
	main = mn
	tree = main.get_tree()
	var passes: Array = []
	for win: Vector2i in SIZES:
		passes.append([win, 1.0])
	passes.append([SIZES[0], BIG_TEXT])
	var win_arg := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--size="):
			win_arg = String(a).substr(7)
		elif String(a).begins_with("--scenes="):
			only = String(a).substr(9).split(",")
		elif String(a).begins_with("--text="):
			text_arg = float(String(a).substr(7))
		elif String(a).begins_with("--shots-dir="):
			shots = String(a).substr(12)
		elif String(a).begins_with("--report="):
			report = String(a).substr(9)
	Save.no_write = true
	Save.d = Save.fresh()
	if main.fade:
		await main.fade.reveal(0.01)
	await _self_test()
	if win_arg != "" or text_arg > 0.0:  # --size=WxH and/or --text=K: one pass
		var wh := (win_arg if win_arg != "" else "1280x720").split("x")
		passes = [[Vector2i(int(wh[0]), int(wh[1])), text_arg if text_arg > 0.0 else 1.0]]
	for pass_cfg in passes:
		size_px = pass_cfg[0]
		text_k = pass_cfg[1]
		UI.set_text_size(text_k)
		tree.root.size = size_px
		await _frames(3)
		await _front()
		await _farm()
		await _overlays()
		await _other()
		await _hud()
	UI.set_text_size(1.0)
	_finish()


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func _wait(s: float) -> void:
	await tree.create_timer(s).timeout


func _wanted_prefix(prefix: String) -> bool:
	for n in only:
		if n.begins_with(prefix):
			return true
	return false


func _wanted(name: String) -> bool:
	return only.is_empty() or only.has(name)


## Scans everything on screen now and files each hit under `name`.
func _look(name: String) -> void:
	if not _wanted(name):
		return
	print("UITEXT scan %s %dx%d@%d%%" % [name, size_px.x, size_px.y, text_k * 100])  # (a line a check's watchdog sees)
	await _wait(SETTLE_S)
	TextCache.seen_at.clear()
	TextCache.recording = true  # (what the HUD draws itself these frames)
	await _frames(2)
	TextCache.recording = false
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
		await RenderingServer.frame_post_draw
		var png := "%s/%s_%dx%d_%d.jpg" % [shots, name, size_px.x, size_px.y, text_k * 100]
		tree.root.get_texture().get_image().save_jpg(png, 0.88)
	scene = name
	screens_seen[name] = true
	var view := tree.root.get_visible_rect().size
	var found := UiTextScan.scan(tree.root, view, TextCache.seen_at)
	seen_texts[name] = maxi(int(seen_texts.get(name, 0)), UiTextScan.texts)
	TextCache.seen_at.clear()
	TextCache.seen.clear()
	for h in found:
		h["path"] = _plain.sub(h["path"], "$1", true)
		var key := "%s|%s|%s" % [name, h["path"], h["rule"]]
		if not hits.has(key):
			hits[key] = {"scene": name, "path": h["path"], "rule": h["rule"], "text": h["text"], "detail": {}}
		hits[key]["detail"]["%dx%d@%d%%" % [size_px.x, size_px.y, text_k * 100]] = h["detail"]


func _made_up_save() -> void:
	Save.d = Save.fresh()
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


func _screen() -> Node:
	return main.screen_node()


# ------------------------------------------------------------------ screens
func _front() -> void:
	Save.d = Save.fresh()
	main.show_screen("title", {})
	await _look("title")
	main.show_screen("prologue", {"then": "hatch"})
	await _look("prologue")
	main.show_screen("hatch", {})
	await _wait(3.0)
	await _look("hatch_card")
	var hx := _screen()
	hx._end_intro()
	await _look("hatch_creator")
	hx._looks_good()
	await _wait(1.0)
	await _look("hatch_eggs")
	hx._pick(0)
	await _wait(0.8)
	hx._pick(0)
	await _wait(1.0)
	await _look("hatch_knock")
	hx._show_name()
	await _look("hatch_name")
	hx._finish(String(hx.egg_defs[0]["species"]), "", "", true)
	await _wait(2.0)
	await _look("hatch_first_relic")
	hx.queue_free()
	await _frames(2)
	_made_up_save()
	main.show_screen("prematch", {"teams": 10, "squad": 3, "tier": 0})
	await _look("pick")
	main.show_screen("results", {"extracted": true, "gems": 42, "seeds": {"sunroot": 1}, "knocks": 3, "kills": 1})
	await _wait(2.0)
	await _look("results")


func _farm() -> void:
	main.show_screen("home", {})
	var guard := 0
	while guard < 600 and (_screen() == null or _screen().get("player") == null):
		guard += 1
		await _wait(0.5)
	await _wait(2.0)
	var h := _screen()
	h._close_panel()
	await _look("farm")
	Save.d["gems"] = 500
	var rec: Dictionary = Save.active_kin()
	var panels := {
		"expedition": func(): h._open_expedition(),
		"hunters": func(): HomeClasses.open(h, Arch.of_save()),
		"loadout": func(): h._open_loadout(),
		"kit_card": func(): h._open_kit_card(),
		"challenges": func(): h._open_challenges(),
		"kitchen": func(): h._open_kitchen(),
		"burrow": func(): h._open_burrow(),
		"armory": func(): h.hecon.open_armory(),
		"plot": func(): h._open_plot("plots", 0),
		"ferry": func(): h._open_ferry(),
		"music": func(): h._open_music(),
		"hall": func(): h._open_hall(),
		"house": func(): h._open_house(),
		"rack": func(): h._open_rack(),
		"job_board": func(): h.open_job_board(),
		"blackmarket": func(): h.hbm.open(),
		"nook": func(): h._open_nook(),
		"feed": func(): h._open_feed(rec),
		"wear": func(): h._open_wear(rec),
		"train": func(): h._open_train(rec),
		"chat": func(): h._open_chat(rec),
	}
	for t in ["Vendor", "Relics", "Exchange", "Shelter", "My stall", "Search", "Auctions"]:
		panels["market_" + t.to_lower().replace(" ", "_")] = func(): h.hmk.open(t)
	for t in ["Care", "Training", "Growth", "Family", "About"]:
		panels["kin_" + t.to_lower()] = func():
			h.kin_tab = t
			h._open_kin(rec)
	for name in panels:
		if _wanted("farm_" + name):
			panels[name].call()
		await _look("farm_" + name)
		h._close_panel()
		await _frames(2)


## The other screens Main can show: the lobby, the party, the town, a house interior.
func _other() -> void:
	_made_up_save()
	var screens := {
		"lobby": {},
		"party": {},
		"town_hub": {"mode": "hub"},
		"interior": {"room": "house"},
	}
	for name in screens:
		if not _wanted(name):
			continue
		main.show_screen(name.get_slice("_", 0), screens[name])
		await _wait(1.0)
		await _look(name)


func _overlays() -> void:
	for tab_name in Overlay.SETTINGS_TABS:
		Overlay.shot_demo(PackedStringArray(["settings", tab_name]))
		await _look("settings_" + tab_name.to_lower())
		Overlay.close()
	for t in ["pause", "confirm", "tooltip", "controls", "controls:rebound", "saves", "admin"]:
		var before := Overlay.root.get_children()
		Overlay.shot_demo(t.split(":"))
		await _look("overlay_" + t.replace(":", "_"))
		Overlay.close()
		for ch in Overlay.root.get_children():
			if not before.has(ch):
				ch.queue_free()  # (a confirm box sits on the Overlay root, not in its host)
		await _frames(2)
	for tab_name in ["Items", "Seeds", "Crops", "Furniture", "Kin", "Field Book"]:
		Overlay.shot_demo(PackedStringArray(["inventory", tab_name]))
		await _look("inventory_" + tab_name.to_lower().replace(" ", "_"))
		Overlay.close()
	Overlay.shot_demo(PackedStringArray(["dex", "cindle"]))
	await _look("dex")
	Overlay.close()


## The match: the drop plan, the HUD after landing, the pause and More pages, then the tutorial's intro card.
func _hud() -> void:
	if not only.is_empty() and not _wanted_prefix("match_") and not _wanted_prefix("tutorial_"):
		return
	if main.current:
		main.current.queue_free()  # (the farm: a match added here is not freed by Main's screen change)
	await _frames(2)
	var m := Match.new()
	main.add_child(m)
	main.current = m
	await m.start({"teams": 4, "squad": 3, "tier": 0, "length": 1500.0, "seed": 7, "demo_kin": "cindle"})
	m.set_process(false)
	await _look("match_plan")
	m.ship_jump(m.player, true)
	m.player.teleport(m.world.spawns[0])
	for i in 600:
		m.step(Match.DT)
		if i % 4 == 0:
			await _frames(1)
	await _look("match_hud")
	for pg in ["pause", "more", "words", "controls", "settings"]:
		match pg:
			"pause":
				Overlay.open_pause("match")
			"more":
				Overlay.open_more()
			"words":
				Overlay.open_words()
			"controls":
				Overlay.open_controls()
			"settings":
				Overlay.open_settings()
		await _look("match_" + pg)
		Overlay.close()
	m.queue_free()
	await _frames(2)
	if size_px == SIZES[0] and text_k == 1.0:
		await _tutorial()  # (the steps' prompts are drawn, not nodes: only the intro card is looked at)


func _tutorial() -> void:
	_made_up_save()
	Save.d["tutorial"]["match"] = false
	var m := Match.new()
	main.add_child(m)
	main.current = m
	await m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0})
	m.set_process(false)
	await _look("tutorial_intro")
	m.queue_free()
	await _frames(2)


## The rules catch what they are for: one made-up screen with a Label per rule (and a clean one), judged at 1280x720.
func _self_test() -> void:
	tree.root.size = SIZES[0]
	await _frames(3)
	var box := Control.new()
	box.name = "SelfTest"
	tree.root.add_child(box)
	var words := "Male, he/him. A babbler for now."
	var squeezed := _label(box, words, Vector2(300, 100))
	squeezed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	squeezed.custom_minimum_size = Vector2(1, 1)
	squeezed.size = Vector2(1, 1)
	_label(box, "Runs off the left edge", Vector2(-60, 300))
	_label(box, "Fine", Vector2(600, 300))
	_label(box, "Under it is drawn text", Vector2(605, 400))
	_label(box, "Overlap A is here", Vector2(100, 500))
	_label(box, "Overlap B is here", Vector2(110, 505))
	box.size = Vector2(SIZES[0])
	box.draw.connect(
		func():
			HudStyle.text(box, Vector2(SIZES[0].x - 40, 200), "Drawn off the right", 15, Color.WHITE)
			HudStyle.text(box, Vector2(600, 418), "Drawn under a label", 15, Color.WHITE)
	)
	TextCache.seen_at.clear()
	TextCache.recording = true
	await _frames(3)
	TextCache.recording = false
	var rules := {}
	var view := tree.root.get_visible_rect().size
	for h in UiTextScan.scan(box, view, TextCache.seen_at):
		rules["%s %s" % [h["rule"], h["text"].left(5)]] = true
	for want in ["narrow Male,", "tall Male,", "outside Runs ", "overlap Overl", "outside drawn", "overlap Under"]:
		_ok(rules.has(want), "the probe's rules catch '%s' on a made-up screen" % want)
	_ok(not rules.keys().any(func(k): return String(k).ends_with("Fine")), "a clean label has no hit")
	box.queue_free()
	await _frames(2)


func _label(host: Control, text: String, at: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	host.add_child(l)
	return l


func _ok(cond: bool, what: String) -> void:
	print("UITEXT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		self_bad += 1


# ------------------------------------------------------------------ verdict
func _finish() -> void:
	var rows: Array = hits.values()
	rows.sort_custom(func(a, b): return a["scene"] + a["path"] < b["scene"] + b["path"])
	var lines := PackedStringArray()
	var fresh := 0
	for r in rows:
		var known := _known(r)
		fresh += 0 if known else 1
		lines.append(
			(
				"UITEXT %s %s | %s | %s | '%s' | %s"
				% ["known" if known else "HIT  ", r["scene"], r["path"], r["rule"], r["text"], str(r["detail"])]
			)
		)
	for l in lines:
		print(l)
	if report != "":
		var f := FileAccess.open(report, FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		f.close()
	print("UITEXT texts per screen: ", seen_texts)
	print("UITEXT DONE, %d screens, %d hits (%d new)" % [screens_seen.size(), rows.size(), fresh])
	tree.quit(1 if fresh + self_bad > 0 else 0)


func _known(r: Dictionary) -> bool:
	for k: Array in KNOWN:
		if k[0] == r["scene"] and String(r["path"]).begins_with(k[1]) and k[2] == r["rule"]:
			return true
	return false
