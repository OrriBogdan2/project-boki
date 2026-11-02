extends RefCounted
## --hunter-unlock-check (alias --class-unlock-check): Hunter unlocks (docs/decisions/0005,
## content/rules/class_unlock.json, content/rules/hunter_viewer.json).
##   1. the data: starters, the early goals, a goal and level per Hunter, the viewer's kit moves
##   2. pick 1 Hunter at character creation, in the Hunter viewer
##   3. the two early unlocks (free picks), then each Hunter's own goal and the account level
##   4. hold to unlock: a partial hold cancels, a full hold unlocks and plays the reveal burst
##   5. the viewer cycling abilities on the real model, with the kit's own moves
##   6. no Light/Medium/Heavy or weight labels and the Hunter wording on every screen it touches
##   7. locked Hunters playable in the Arena and the practice picker; old saves keep everything
## With --shots-dir=<dir>: creation_viewer, hunters_screen, viewer_strip (4 frames), hold_partial and
## reveal_burst as PNGs. Prints HUNTERCHECK lines and "HUNTERCHECK DONE, n checks, failures: n".

var bad := 0
var n := 0
var main: Node
var shots := ""

func ok(cond: bool, what: String) -> void:
	n += 1
	print("HUNTERCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func shot(tree: SceneTree, name: String, frames := 25) -> void:
	if shots == "": return
	for i in frames: await tree.process_frame
	tree.root.get_texture().get_image().save_png("%s/%s.png" % [shots, name])

## A finished-expedition result for ClassUnlock.after_match / Game.apply_result.
func result(extracted: bool, mobs := 0, knocks := 0, bosses := 0, lvl := 1, caught := 0) -> Dictionary:
	var r := {"extracted": extracted, "why": "extracted" if extracted else "knocked out", "knocks": knocks, "kills": 0, "gems": 0, "seeds": {},
		"stats": {"mobs": mobs, "bosses": bosses}, "lvl": lvl, "caught": [], "kin_runs": [], "tonics": 0}
	for i in caught: (r["caught"] as Array).append({})
	return r

func new_save(starter := "") -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip"); d["roster"].append(k); d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	if starter != "":
		ClassUnlock.choose_starter(starter)
		Save.d["cls"] = Arch.weight(starter); Save.d["arch"] = starter; Save.d["weapon"] = Arch.signature(starter)

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): shots = a.substr(12)
	var tree := main.get_tree()
	if shots != "" and main.fade != null:
		main.fade.reveal(0.05)      # (the boot splash would cover the screenshots)
		for i in 20: await tree.process_frame
	_rules()
	_starter_rules()
	_early_and_goals()
	_migration()
	await _creation(tree)
	await _viewer(tree)
	await _home(tree)
	await _arena(tree)
	print("HUNTERCHECK DONE, %d checks, failures: %d" % [n, bad])
	tree.quit()

# ---------------------------------------------------------------- 1. the data
func _rules() -> void:
	var st := ClassUnlock.starters()
	ok(st.size() >= 1 and st.all(func(a): return Arch.exists(String(a))), "the starters are real Hunters from data (%d)" % st.size())
	var early := ClassUnlock.early()
	var stats: Dictionary = ClassUnlock.rules()["stats"]
	ok(early.size() == 2 and early.all(func(g): return stats.has(String(g["stat"])) and int(g["target"]) >= 1 and String(g.get("text", "")) != ""), "two early goals, each a known stat with a target and text: %s" % str(early.map(func(g): return g["text"])))
	ok(early.all(func(g): return int(g["target"]) <= 3), "the early goals are cheap (targets %s)" % str(early.map(func(g): return g["target"])))
	var every_goal := Arch.ids().all(func(a): return not ClassUnlock.entry(String(a)).is_empty() and ClassUnlock.goal_text(String(a)) != "" and ClassUnlock.level_needed(String(a)) >= 1)
	ok(every_goal, "every Hunter has its own goal and an account level in content/rules/class_unlock.json")
	ok(Arch.ids().all(func(a): return stats.has(String(ClassUnlock.entry(String(a))["goal"]["stat"]))), "every goal counts a stat the rules name")
	ok(HoldUnlock.hold_s() >= 0.5 and HoldUnlock.hold_s() <= 4.0, "the hold time is data (%ss)" % HoldUnlock.hold_s())
	ok(ClassUnlock.level_of(0)[0] == 1 and ClassUnlock.level_of(ClassUnlock.xp_cost(1))[0] == 2 and ClassUnlock.level_of(ClassUnlock.xp_cost(1) - 1)[0] == 1, "account level steps at the XP the rules say")
	# the viewer's moves: every id in hunter_viewer.json is a kit move the animation knows
	var missing: Array = []
	var mv: Dictionary = HunterViewer.rules().get("moves", {})
	for a in mv:
		if not Arch.exists(String(a)): missing.append(String(a))
		for slot in mv[a]:
			for id in mv[a][slot]:
				if HunterViewer.move_len(String(id)) <= 0.0: missing.append("%s.%s:%s" % [a, slot, id])
	ok(missing.is_empty(), "every viewer move is a real Hunter's real kit move (HunterAnim.KMOVES / KMovesPair); missing: %s" % str(missing))
	ok(Arch.ids().all(func(a): return mv.has(String(a)) and (mv[a] as Dictionary).size() >= 2), "every Hunter has at least two abilities with their own move in the viewer")

# ---------------------------------------------------------------- 2. pick 1 Hunter
func _starter_rules() -> void:
	new_save()
	ok(ClassUnlock.needs_starter() and not ClassUnlock.all_open(), "a new save has to pick its starting Hunter")
	ok(ClassUnlock.free_picks() == 0 and ClassUnlock.ready_count() == 0 and not ClassUnlock.can_unlock("archer"), "nothing can be unlocked before the pick")
	ok(ClassUnlock.choose_starter("dolm") and ClassUnlock.starter() == "dolm", "picking %s works" % Arch.name_of("dolm"))
	ok(ClassUnlock.open_ids() == ["dolm"] and not ClassUnlock.needs_starter(), "exactly 1 Hunter is open after the pick (%s)" % str(ClassUnlock.open_ids()))
	ok(not ClassUnlock.choose_starter("thief") and ClassUnlock.open_ids() == ["dolm"], "the pick is made once")
	ok(Arch.ids().filter(func(a): return a != "dolm").all(func(a): return ClassUnlock.status(String(a)) == "locked" and ClassUnlock.requirement(String(a)) != ""), "every other Hunter is locked and says what it takes")

# ---------------------------------------------------------------- 3. the early unlocks, then the goals
func _early_and_goals() -> void:
	new_save("thief")
	var ne := ClassUnlock.next_early()
	ok(int(ne.get("index", -1)) == 0 and String(ne["text"]) == String(ClassUnlock.early()[0]["text"]) and int(ne["have"]) == 0, "the first early goal is next: %s" % ne.get("text", "?"))
	ok(ClassUnlock.requirement("ashwick").contains(String(ne["text"])), "a locked Hunter names the early goal as a way in: %s" % ClassUnlock.requirement("ashwick"))
	# the first expedition: one free pick, so every locked Hunter is ready
	var out := Game.apply_result(result(false))
	ok(ClassUnlock.free_picks() == 1 and int(out["class_unlock"]["new"]) >= 1, "playing 1 expedition gives the first free pick (results: %s new)" % str(out["class_unlock"].get("new", -1)))
	ok(Arch.ids().filter(func(a): return a != "thief").all(func(a): return ClassUnlock.status(String(a)) == "ready"), "with a free pick every locked Hunter is ready")
	ok(not ClassUnlock.is_open("dredge"), "nothing opens by itself: a ready Hunter waits for the hold")
	var strip := ClassCard.results_strip(out)
	ok(_find_meta(strip, "hunter_unlock_ready") != null, "the results screen says a Hunter unlock is ready")
	ok(_texts(strip).any(func(t): return String(t).contains("Hunter unlock")), "in Hunter words")
	strip.free()
	ok(ClassUnlock.unlock("dredge") and ClassUnlock.is_open("dredge") and int(ClassUnlock.state()["early_used"]) == 1 and ClassUnlock.free_picks() == 0, "unlocking %s spends the free pick" % Arch.name_of("dredge"))
	ok(not ClassUnlock.unlock("ashwick") and ClassUnlock.status("ashwick") != "ready", "with no pick left the others are locked again")
	# the second: make it out once
	Save.d["extracts"] = 1
	ok(ClassUnlock.free_picks() == 1, "making it out of an expedition gives the second free pick")
	ok(ClassUnlock.unlock("ashwick") and ClassUnlock.open_ids().size() == 3, "the second free pick unlocks a third Hunter: %s" % str(ClassUnlock.open_ids()))
	ok(ClassUnlock.next_early().is_empty() and ClassUnlock.free_picks() == 0, "both early unlocks are used: from here each Hunter has its own goal")
	# the goals: making it out once is Marlowe's goal, but it needs account level 2 too
	ok(bool(ClassUnlock.goal_progress("gunslinger")["done"]) and ClassUnlock.level() == 1 and ClassUnlock.status("gunslinger") == "progress", "%s's goal is done but the account is level 1: in progress" % Arch.name_of("gunslinger"))
	ClassUnlock.add_xp(ClassUnlock.xp_cost(1))
	ok(ClassUnlock.level() == 2 and ClassUnlock.status("gunslinger") == "ready", "at account level 2 it is ready")
	ok(ClassUnlock.unlock("gunslinger") and int(ClassUnlock.state()["early_used"]) == 2, "its own goal unlocks it without a free pick")
	Progress.add("knocks", 1)
	var jp := ClassUnlock.goal_progress("juggernaut")
	ok(int(jp["have"]) == 1 and absf(float(jp["frac"]) - 0.5) < 0.01 and ClassUnlock.status("juggernaut") == "progress", "%s's goal shows 1/2 knocks" % Arch.name_of("juggernaut"))
	ok(ClassUnlock.xp_for(result(false, 100)) == 15 + 30, "monster XP is capped per run (%d)" % ClassUnlock.xp_for(result(false, 100)))
	ClassUnlock.take_news()
	ok(ClassUnlock.take_news() == 0, "a ready unlock is announced once")

# ---------------------------------------------------------------- 7a. an old save keeps everything
func _migration() -> void:
	var old := Save.fresh()
	old.erase("classes"); old["v"] = 5
	ok(Save.migrate(old) and int(old["v"]) == Save.VERSION and bool(old["classes"]["all"]), "a v5 save upgrades to v%d with every Hunter open" % Save.VERSION)
	Save.d = old
	ok(ClassUnlock.all_open() and Arch.ids().all(func(a): return ClassUnlock.status(String(a)) == "open") and not ClassUnlock.needs_starter() and ClassUnlock.ready_count() == 0, "all twelve open, no pick, nothing to unlock")
	# a v6 save from before the early picks (no early_used / told keys) still loads and counts
	new_save("thief")
	Save.d["classes"].erase("early_used"); Save.d["classes"].erase("told")
	Save.d["matches"] = 1
	ok(ClassUnlock.free_picks() == 1 and ClassUnlock.unlock("archer"), "a v6 save without the new keys reads them as 0")
	var path := "user://hunter_check_v5.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	var disk := Save.fresh(); disk.erase("classes"); disk["v"] = 5
	f.store_string(JSON.stringify(disk)); f.close()
	Save.load_from(path)
	ok(bool(Save.d.get("classes", {}).get("all", false)), "loading an old save file from disk opens everything")
	new_save("thief")
	f = FileAccess.open(path, FileAccess.WRITE); f.store_string(JSON.stringify(Save.d)); f.close()
	Save.load_from(path)
	ok(not ClassUnlock.all_open() and ClassUnlock.open_ids() == ["thief"], "a new save read back keeps its single open Hunter")
	DirAccess.remove_absolute(path)

# ---------------------------------------------------------------- 2b. character creation, in the viewer
func _pick_panel(hx: Node) -> Node:
	for ch in hx.bottom.get_children():
		if ch.has_meta("starter_pick") and not ch.is_queued_for_deletion(): return ch
	return null

func _creation(tree: SceneTree) -> void:
	new_save()
	Save.d["tutorial"] = {"intro": true}
	Save.d.erase("look")
	var hx = load("res://scripts/ui/hatch.gd").new()
	main.add_child(hx)
	for i in 8: await tree.process_frame
	ok(hx.stage == "class", "a new save starts character creation on the Hunter pick (stage %s)" % hx.stage)
	var panel: Node = _pick_panel(hx)
	ok(panel != null, "the pick shows the starter panel")
	var chips: Array = []
	var viewer: HunterViewer = null
	if panel:
		_collect_meta(panel, "starter_chip", chips)
		viewer = panel.get_meta("viewer")
	ok(chips.size() == ClassUnlock.starters().size(), "a chip for every starter (%d)" % chips.size())
	ok(viewer != null and viewer.id == Arch.of_save() and viewer.model != null and viewer.vp != null, "with the Hunter viewer on the highlighted one (%s)" % (viewer.id if viewer else "?"))
	ok(panel != null and _find_meta(panel, "plain_card") != null, "the viewer has the plain-words card")
	ok(panel != null and _no_weight(panel) and _hunter_words(panel), "the pick has no weight labels and says Hunter, not class or hero")
	ok(String(hx.title.text).contains("Hunter"), "the title: %s" % hx.title.text)
	await shot(tree, "creation_viewer", 60)
	var want := "archer"
	for c in chips:
		if String(c.get_meta("arch")) == want: (c as Button).pressed.emit()
	for i in 6: await tree.process_frame
	panel = _pick_panel(hx)
	viewer = panel.get_meta("viewer") if panel else null
	ok(String(Save.d["arch"]) == want and viewer != null and viewer.id == want and hx.stage == "class", "clicking a chip shows it in the viewer without committing (%s)" % want)
	var go: Button = null
	for ch in hx.bottom.get_children():
		if ch is Button and not ch.is_queued_for_deletion(): go = ch
	ok(go != null and go.text.contains(Arch.name_of(want)), "the button reads: %s" % (go.text if go else "?"))
	if go: go.pressed.emit()
	for i in 6: await tree.process_frame
	ok(ClassUnlock.starter() == want and ClassUnlock.open_ids() == [want] and hx.stage == "create", "confirming picks 1 Hunter and moves on to your look (stage %s)" % hx.stage)
	ok(Arch.of_save() == want and String(Save.d["weapon"]) == Arch.signature(want), "and saves it as your expedition Hunter")
	hx.queue_free()
	for i in 3: await tree.process_frame

# ---------------------------------------------------------------- 5. the viewer cycling abilities
func _viewer(tree: SceneTree) -> void:
	new_save("juggernaut")
	var layer := CanvasLayer.new(); layer.layer = 50
	main.add_child(layer)
	var bg := ColorRect.new(); bg.color = Color(0.07, 0.06, 0.1); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var host := CenterContainer.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme = UI.theme()
	layer.add_child(host)
	var v := HunterViewer.make("juggernaut", Vector2(300, 360))
	host.add_child(v)
	for i in 4: await tree.process_frame
	v.set_process(false)       # (stepped by hand below)
	var want: Array = KitCard.slots_of("juggernaut")
	if not want.has("r"): want.append("r")
	ok(v.slots == want, "the viewer shows every ability in order: %s" % str(v.slots))
	ok(v.rows.size() == want.size() and v.rows.all(func(b): return _texts(b).any(func(t): return t in ["Shift", "LMB", "RMB", "E", "R", "auto"])), "each ability row has its key")
	ok(v.pivot.get_child_count() == 1 and v.model.get_parent() == v.pivot and v.vp.own_world_3d, "the real Hunter model stands in its own SubViewport")
	var seen: Array = []
	var moves_ok := true
	var spun := v.pivot.rotation.y
	var strip: Array = []
	v.slot_changed.connect(func(s): seen.append(s))
	var slot_s := float(HunterViewer.rules()["slot_s"])
	for k in want.size():
		var slot := v.current_slot()
		var mv := HunterViewer.moves_for("juggernaut", slot)
		# a little into the slot: the kit's own move is on the model
		for i in 6: v.tick(0.05)
		if not mv.is_empty() and v.anim.km_id != String(mv[0]):
			moves_ok = false
			print("  %s plays %s, wanted %s" % [slot, v.anim.km_id, mv[0]])
		if shots != "" and k in [1, 2, 3, 5]:
			v.tick(0.25)
			await tree.process_frame; await tree.process_frame; await tree.process_frame
			strip.append(_grab(tree, v))
		var left := slot_s - v.slot_t + 0.01
		while left > 0.0:
			v.tick(minf(0.1, left)); left -= 0.1
	ok(seen.slice(0, want.size() - 1) == want.slice(1) and v.slot_i == 0, "it steps through each ability by itself and loops back (%s)" % str(seen))
	ok(moves_ok, "each ability drives the model with the kit's own move (KMOVES)")
	ok(absf(v.pivot.rotation.y - spun) > 0.5, "the model turns on its turntable")
	ok(v.cap_name.text == String(KitCard.slot_text("juggernaut", v.current_slot())["name"]) and (v.cap_key.get_child(0) as Label).text != "", "the caption names the ability playing, with its key")
	(v.rows[3] as Button).pressed.emit()
	ok(v.slot_i == 3 and v.current_slot() == String(want[3]), "clicking an ability shows it at once")
	ok(_no_weight(v) and _hunter_words(v), "the viewer has no weight labels or class/hero wording")
	if shots != "" and strip.size() == 4:
		_save_strip(strip, "%s/viewer_strip.png" % shots)
	layer.queue_free()
	for i in 3: await tree.process_frame

func _grab(tree: SceneTree, c: Control) -> Image:
	var img := tree.root.get_texture().get_image()
	var r := Rect2i(c.get_global_rect())
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	return img.get_region(r)

func _save_strip(frames: Array, path: String) -> void:
	var w := 0; var h := 0
	for f in frames: w += (f as Image).get_width() + 8; h = maxi(h, (f as Image).get_height())
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.03, 0.03, 0.05))
	var x := 0
	for f in frames:
		var fi: Image = f
		fi.convert(Image.FORMAT_RGBA8)
		out.blit_rect(fi, Rect2i(Vector2i.ZERO, fi.get_size()), Vector2i(x, 0))
		x += fi.get_width() + 8
	out.save_png(path)

# ---------------------------------------------------------------- 4 + 6. the farm: the Hunters screen and the hold
func _home(tree: SceneTree) -> void:
	new_save("thief")
	# some play: one free pick waiting (1 expedition played), Juggernaut 1/2 knocks
	Save.d["matches"] = 1
	Progress.add("knocks", 1)
	var hm = await main._hb_home()
	for i in 30: await tree.process_frame
	var items: Array = hm.hub_items().filter(func(it): return String(it[0]) == "hero")
	ok(not items.is_empty() and String(items[0][1]) == "Hunters", "the farm's bar button is Hunters")
	hm._close_panel()
	var ev := InputEventAction.new(); ev.action = "hero"; ev.pressed = true
	hm._unhandled_input(ev)
	await tree.process_frame
	ok(hm.panel_open == "Hunters", "J opens the Hunters screen (%s)" % hm.panel_open)
	var grid: GridContainer = hm.get_meta("classes_grid")
	var by := {}
	for c in grid.get_children(): by[String(c.get_meta("arch"))] = String(c.get_meta("class_status"))
	ok(by.size() == Arch.ids().size(), "every Hunter has a tile (%d)" % by.size())
	ok(by.get("thief", "") == "open" and by.get("dredge", "") == "ready" and by.get("juggernaut", "") == "ready", "with a free pick waiting, every locked Hunter is ready (%s)" % str(by))
	var sel := String(hm.get_meta("hunters_sel"))
	var hu: HoldUnlock = hm.get_meta("hold_unlock") if hm.has_meta("hold_unlock") else null
	ok(hu != null and is_instance_valid(hu) and hu.id == sel and by.get(sel, "") == "ready", "a ready Hunter is shown first, with Hold to unlock (%s)" % sel)
	ok(_no_weight(hm.panel_host) and _hunter_words(hm.panel_host), "the Hunters screen has no weight labels and says Hunter, not class or hero")
	if hu == null:
		hm.queue_free()
		return
	# --- a partial hold cancels
	var viewer: HunterViewer = hm.get_meta("hunter_viewer")
	hu.set_process(false); viewer.set_process(false)
	hu.press()
	for i in int(HoldUnlock.hold_s() * 0.55 / 0.05): hu.tick(0.05); viewer.tick(0.05)
	ok(hu.k > 0.45 and hu.k < 0.7 and hu.slide >= 1.0 and viewer.power_k > 0.4, "holding: the bar slides out and fills (%.2f), the Hunter powers up (%.2f)" % [hu.k, viewer.power_k])
	ok(not ClassUnlock.is_open(sel), "half a hold unlocks nothing")
	await shot(tree, "hold_partial", 4)
	var cancelled := [false]
	hu.cancelled.connect(func(_id): cancelled[0] = true)
	hu.release()
	for i in 20: hu.tick(0.05); viewer.tick(0.05)
	ok(cancelled[0] and hu.k == 0.0 and viewer.power_k == 0.0 and not ClassUnlock.is_open(sel) and ClassUnlock.free_picks() == 1, "letting go early cancels: the bar drains, nothing is spent")
	# --- a full hold unlocks it and bursts
	var done := [false]
	hu.done.connect(func(_id): done[0] = true)
	hu.press()
	for i in int(HoldUnlock.hold_s() / 0.05) + 3: hu.tick(0.05); viewer.tick(0.05)
	ok(done[0] and hu.finished and ClassUnlock.is_open(sel) and ClassUnlock.free_picks() == 0, "a full hold unlocks %s and spends the free pick" % Arch.name_of(sel))
	ok(viewer.burst_t >= 0.0, "the viewer bursts")
	# the reveal steps in
	var rv: ClassReveal = null
	for i in 90:
		await tree.process_frame
		for c in hm.get_children(): if c is ClassReveal and not c.is_queued_for_deletion(): rv = c
		if rv: break
	ok(rv != null and rv.id == sel, "then the reveal plays for it")
	if rv:
		ok(_texts(rv.root).any(func(t): return t == "NEW HUNTER") and _no_weight(rv.root), "the reveal says NEW HUNTER, with no weight label")
		if shots != "":
			await tree.create_timer(0.15).timeout
			tree.root.get_texture().get_image().save_png("%s/reveal_burst.png" % shots)
		rv._finish(false)
		for i in 6: await tree.process_frame
	ok(hm.panel_open == "Hunters", "Later goes back to the Hunters screen")
	ok(ClassReveal.maybe_show(hm) == null, "and the reveal never plays twice")
	# --- the screen with open, in-progress and locked Hunters (the pick is spent now)
	HomeClasses.open(hm, "juggernaut")
	await tree.process_frame
	grid = hm.get_meta("classes_grid")
	by = {}
	for c in grid.get_children(): by[String(c.get_meta("arch"))] = String(c.get_meta("class_status"))
	ok(by.values().has("open") and by.values().has("progress") and by.values().has("locked"), "the Hunters screen shows open, in-progress and locked Hunters")
	ok(by.get("juggernaut", "") == "progress" and _find_meta(hm.panel_host, "goal_block") != null, "an in-progress one shows its goal and bar")
	ok(_any_text(hm.panel_host, "Account level"), "and the account level")
	await shot(tree, "hunters_screen", 50)
	# play an open one from the screen
	var old_model: Node3D = hm.player
	HomeClasses._click(hm, sel)
	await tree.process_frame
	ok(Arch.of_save() == sel and hm.player != old_model, "an unlocked Hunter can be played from the screen; the farm hunter turns into it")
	HomeHero.pick(hm, "bulwark")
	ok(Arch.of_save() == sel, "a locked one can't be")
	# the expedition panel: one Hunter row, no weight tabs, locked ones disabled
	hm._open_expedition()
	await tree.process_frame
	ok(_disabled_buttons(hm.panel_host).size() >= 1 and _no_weight(hm.panel_host), "the expedition panel picks a Hunter (locked ones disabled) with no weight tabs")
	ok(not _texts(hm.panel_host).any(func(t): return t == "Weight" or t == "Class"), "no Weight or Class section")
	hm._close_panel()
	# the Try-on rack: Hunters, not weights; "Set as my Hunter" refuses a locked one
	var tr: HomeTraining = hm.training
	tr.try = {"arch": "bulwark", "cls": Arch.weight("bulwark")}
	tr.apply_try()
	tr.open_tryon()
	await tree.process_frame
	ok(hm.panel_open == "Try-on rack" and _no_weight(hm.panel_host) and _hunter_words(hm.panel_host), "the Try-on rack lists Hunters with no weight labels")
	tr.set_my_class()
	ok(Arch.of_save() == sel, "'Set as my Hunter' refuses a locked Hunter")
	tr.try = {"arch": sel, "cls": Arch.weight(sel)}
	tr.set_my_class()
	ok(Arch.of_save() == sel and String(Save.d["cls"]) == Arch.weight(sel), "and takes an open one")
	tr.try = {}
	hm._close_panel()
	hm.queue_free()
	for i in 3: await tree.process_frame

# ---------------------------------------------------------------- 7b. locked Hunters stay playable in the Arena
func _arena(tree: SceneTree) -> void:
	new_save("thief")
	var m := Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts("ashwick"))
	m.set_process(false)
	var P: Hunter = m.player
	ok(P != null and P.arch == "ashwick" and m.arena != null, "the Arena starts you as a locked Hunter")
	m.arena.set_arch("dredge")
	ok(P.arch == "dredge", "and swaps to another locked one")
	m.arena.open_menu()
	await tree.process_frame
	var ml: Node = m.arena.menu_layer
	ok(ml != null and _no_weight(ml) and _texts(ml).any(func(t): return String(t).to_lower().begins_with("hunter")), "the Arena's L loadout lists Hunters with no weight letters")
	m.arena.close_menu()
	var holder := Control.new(); main.add_child(holder)
	var grid := HeroGrid.build(holder, func(_a): pass, func(_a): pass, func(_a): pass, false)
	ok(grid.get_child_count() == Arch.ids().size() and _no_weight(holder) and _hunter_words(holder), "the practice picker shows all %d Hunters, no weight labels" % grid.get_child_count())
	holder.queue_free()
	var arch_before := String(Save.d.get("arch", ""))
	ok(not HeroGrid.save_pick("ashwick") and String(Save.d.get("arch", "")) == arch_before, "trying a locked Hunter in practice doesn't make it your expedition Hunter")
	m.queue_free()
	for i in 3: await tree.process_frame

# ---------------------------------------------------------------- helpers
func _texts(n: Node) -> Array:
	var out: Array = []
	if n is Label: out.append((n as Label).text)
	elif n is Button: out.append((n as Button).text)
	if n is Control and String((n as Control).tooltip_text) != "": out.append((n as Control).tooltip_text)
	for c in n.get_children(): out.append_array(_texts(c))
	return out

## No Light/Medium/Heavy label (a weight name on its own, as a tag, a suffix or "X weight") and no
## "weight" anywhere. Ability names that happen to use the word ("Heavy Shot") are not labels.
func _no_weight(n: Node) -> bool:
	var rx := RegEx.create_from_string("(?i)\\bweight\\b|^(light|medium|heavy)$|\\((light|medium|heavy)\\)|·\\s*[LMH]$|\\b(light|medium|heavy)\\s+(weight|class|frame)\\b")
	var hits: Array = []
	for t in _texts(n):
		for line in String(t).split("\n"):
			if rx.search(line.strip_edges()) != null: hits.append(line)
	if not hits.is_empty(): print("  weight label: %s" % str(hits))
	return hits.is_empty()

## Says Hunter: no "class", "classes", "hero" or "heroes" in what the player reads.
func _hunter_words(n: Node) -> bool:
	var rx := RegEx.create_from_string("(?i)\\b(class|classes|hero|heroes|archetypes?)\\b")
	var hits: Array = _texts(n).filter(func(t): return rx.search(String(t)) != null)
	if not hits.is_empty(): print("  old wording: %s" % str(hits))
	return hits.is_empty()

func _find_meta(n: Node, key: String) -> Node:
	if n.has_meta(key): return n
	for c in n.get_children():
		var f := _find_meta(c, key)
		if f: return f
	return null

func _collect_meta(n: Node, key: String, out: Array) -> void:
	if n.has_meta(key): out.append(n)
	for c in n.get_children(): _collect_meta(c, key, out)

func _any_text(n: Node, needle: String) -> bool:
	return _texts(n).any(func(t): return String(t).contains(needle))

func _disabled_buttons(n: Node) -> Array:
	var out: Array = []
	if n is Button and (n as Button).disabled: out.append(n)
	for c in n.get_children(): out.append_array(_disabled_buttons(c))
	return out
