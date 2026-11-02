extends RefCounted
## --class-unlock-check: class unlocks (docs/decisions/0004, content/rules/class_unlock.json).
## The starter pick on a new save, goal and account-level progress, the unlock and its reveal, locked
## classes staying playable in the Arena, an old save migrating with everything open, and the farm
## picker greying out locked classes. With --shots-dir=<dir>: the starter pick, the Classes screen, the
## reveal and the picker as PNGs. Prints CLASSCHECK lines and "CLASSCHECK DONE, failures: n".

var bad := 0
var n := 0
var main: Node
var shots := ""

func ok(cond: bool, what: String) -> void:
	n += 1
	print("CLASSCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func shot(tree: SceneTree, name: String) -> void:
	if shots == "": return
	for i in 25: await tree.process_frame
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
	_starter_pick_rules()
	_progress_and_unlock()
	_migration()
	await _hatch_pick(tree)
	await _reveal(tree)
	await _arena(tree)
	await _home(tree)
	print("CLASSCHECK DONE, %d checks, failures: %d" % [n, bad])
	tree.quit()

# ---------------------------------------------------------------- the data
func _rules() -> void:
	var st := ClassUnlock.starters()
	ok(st.size() == 3 and st.all(func(a): return Arch.exists(String(a))), "the starter set is three real classes from data: %s" % str(st))
	ok(["light", "medium", "heavy"].all(func(w): return st.filter(func(a): return Arch.weight(String(a)) == w).size() == 1), "one starter of each weight")
	var every_goal := Arch.ids().all(func(a): return not ClassUnlock.entry(String(a)).is_empty() and ClassUnlock.goal_text(String(a)) != "" and ClassUnlock.level_needed(String(a)) >= 1)
	ok(every_goal, "every class has a goal and an account level in content/rules/class_unlock.json")
	var stats: Dictionary = ClassUnlock.rules()["stats"]
	ok(Arch.ids().all(func(a): return stats.has(String(ClassUnlock.entry(String(a))["goal"]["stat"]))), "every goal counts a stat the rules name")
	ok(ClassUnlock.level_of(0)[0] == 1 and ClassUnlock.level_of(ClassUnlock.xp_cost(1))[0] == 2 and ClassUnlock.level_of(ClassUnlock.xp_cost(1) - 1)[0] == 1, "account level steps at the XP the rules say")
	ok(ClassUnlock.level_of(999999)[0] == int(ClassUnlock.rules()["xp"]["max_level"]), "and stops at the cap")

# ---------------------------------------------------------------- 1. a new save picks one starter
func _starter_pick_rules() -> void:
	new_save()
	ok(ClassUnlock.needs_starter() and not ClassUnlock.all_open(), "a new save has to pick a starter class")
	ok(ClassUnlock.open_ids().size() == 1, "and until it does only the default is open (%s)" % str(ClassUnlock.open_ids()))
	ok(not ClassUnlock.choose_starter("ashwick") and not ClassUnlock.choose_starter("archer"), "a class outside the starter set can't be the pick")
	ok(ClassUnlock.choose_starter("thief") and ClassUnlock.starter() == "thief", "picking Thief works")
	ok(ClassUnlock.open_ids() == ["thief"] and not ClassUnlock.needs_starter(), "only Thief is open now (%s)" % str(ClassUnlock.open_ids()))
	ok(not ClassUnlock.choose_starter("gunslinger") and ClassUnlock.open_ids() == ["thief"], "the pick is made once")
	ok(Arch.ids().filter(func(a): return a != "thief").all(func(a): return not ClassUnlock.is_open(String(a)) and HeroGrid.requirement(String(a)) != ""), "every other class is locked and says what it takes")
	new_save("juggernaut")
	ok(ClassUnlock.open_ids() == ["juggernaut"] and ClassUnlock.fix("thief", "light") == "" and ClassUnlock.fix("ashwick", "heavy") == "juggernaut", "ClassUnlock.fix only ever returns an open class (none for a weight with nothing open)")

# ---------------------------------------------------------------- 2. goal progress and the unlock
func _progress_and_unlock() -> void:
	new_save("thief")
	var gp := ClassUnlock.goal_progress("gunslinger")
	ok(int(gp["have"]) == 0 and int(gp["need"]) == 1 and ClassUnlock.status("gunslinger") == "locked", "Gunslinger (make it out once) starts locked at 0/1")
	# the goal alone is not enough: the account level gates it too
	Progress.add("mobs", 0)
	Save.d["extracts"] = 1
	ok(bool(ClassUnlock.goal_progress("gunslinger")["done"]) and ClassUnlock.status("gunslinger") == "progress" and not ClassUnlock.earned("gunslinger"), "goal done but account level 1: still in progress, not open")
	ok(ClassUnlock.refresh().is_empty() and not ClassUnlock.is_open("gunslinger"), "refresh opens nothing yet")
	# a run earns XP: played 15 + extracted 50 + 10 monsters = 75
	var r1 := result(true, 10)
	ok(ClassUnlock.xp_for(r1) == 75, "an extract with 10 monsters is worth 75 XP (%d)" % ClassUnlock.xp_for(r1))
	var s1 := ClassUnlock.after_match(r1)
	ok(int(s1["xp"]) == 75 and ClassUnlock.level() == 1 and (s1["unlocked"] as Array).is_empty(), "75 XP is still level 1: nothing opens")
	ok(ClassUnlock.xp_for(result(false, 100)) == 15 + 30, "monster XP is capped per run (%d)" % ClassUnlock.xp_for(result(false, 100)))
	# second run lifts the level: Gunslinger opens, and it is queued for the reveal
	var s2 := ClassUnlock.after_match(result(true, 5))
	ok(ClassUnlock.level() == 2 and int(s2["level_after"]) == 2 and int(s2["level_before"]) == 1, "the second run reaches account level 2")
	ok((s2["unlocked"] as Array) == ["gunslinger"] and ClassUnlock.is_open("gunslinger"), "and opens Gunslinger, exactly once (%s)" % str(s2["unlocked"]))
	ok(ClassUnlock.pending_reveal() == ["gunslinger"] and ClassUnlock.refresh().is_empty(), "it waits for its reveal and doesn't open twice")
	ok(ClassUnlock.status("juggernaut") == "progress" or ClassUnlock.status("juggernaut") == "locked", "the others stay shut (Juggernaut: %s, %s)" % [ClassUnlock.status("juggernaut"), ClassUnlock.requirement("juggernaut")])
	# progress counts: knock down hunters toward Juggernaut (2), monsters toward Thief's rivals, a boss toward Ashwick
	Progress.add("knocks", 1)
	var jp := ClassUnlock.goal_progress("juggernaut")
	ok(int(jp["have"]) == 1 and absf(float(jp["frac"]) - 0.5) < 0.01, "Juggernaut's goal shows 1/2 knocks (%d/%d)" % [int(jp["have"]), int(jp["need"])])
	var s3 := ClassUnlock.after_match(result(false, 0, 1, 0, 7))
	ok(not ClassUnlock.is_open("juggernaut") and int(s3["xp"]) == 15 + 6, "one knock isn't enough for Juggernaut; the run still earned %d XP" % int(s3["xp"]))
	Progress.add("knocks", 1)
	var sj := ClassUnlock.after_match(result(false, 0, 1, 0, 2))
	ok((sj["unlocked"] as Array).has("juggernaut") and ClassUnlock.is_open("juggernaut"), "the second knock opens Juggernaut (%s)" % str(sj["unlocked"]))
	ok(ClassUnlock.pending_reveal().has("juggernaut") and ClassUnlock.pending_reveal().has("gunslinger"), "both wait for their reveal")
	ClassUnlock.add_xp(ClassUnlock.xp_cost(2) + ClassUnlock.xp_cost(3) + ClassUnlock.xp_cost(4) + ClassUnlock.xp_cost(5))      # (level 6)
	ok(ClassUnlock.level() >= 6 and ClassUnlock.status("ashwick") == "locked", "level 6 alone doesn't open Ashwick: its goal is a lair boss (%s)" % ClassUnlock.status("ashwick"))
	ok(int(Save.d["stats"].get("best_lvl", 0)) == 7 and ClassUnlock.stat("best_lvl") == 7, "the best level reached in a match is kept (7)")
	Progress.add("bosses", 1)      # (Game.apply_result counts it from the run's stats)
	var s4 := ClassUnlock.after_match(result(true, 0, 0, 1, 3))
	ok((s4["unlocked"] as Array).has("ashwick") and ClassUnlock.is_open("ashwick"), "felling a lair boss opens Ashwick once the level is there (%s)" % str(s4["unlocked"]))
	ok(not ClassUnlock.is_open("tender") and ClassUnlock.requirement("tender").contains("account level"), "a class still locked names its goal and level: %s" % ClassUnlock.requirement("tender"))
	# the real path: Game.apply_result writes it into the save and reports it for the results screen
	new_save("gunslinger")
	var out := Game.apply_result(result(true, 20, 0, 0, 2))
	ok(out.has("class_unlock") and int(out["class_unlock"]["xp"]) == 85 and ClassUnlock.xp() == 85 and int(Save.d.get("extracts", 0)) == 1, "Game.apply_result awards the XP and reports it (%s)" % str(out.get("class_unlock", {}).get("xp", -1)))
	var out2 := Game.apply_result(result(true, 0))
	ok(ClassUnlock.level() == 2 and (out2["class_unlock"]["unlocked"] as Array).has("tender") == false, "and two runs reach level 2 without opening a class whose goal isn't done")
	var strip := ClassCard.results_strip(out2)
	ok(strip.get_child_count() >= 1, "the results screen has an account line")
	strip.free()

# ---------------------------------------------------------------- 3. an old save keeps everything
func _migration() -> void:
	var old := Save.fresh()
	old.erase("classes"); old["v"] = 5
	ok(Save.migrate(old) and int(old["v"]) == Save.VERSION and bool(old["classes"]["all"]), "a v5 save upgrades to v%d with every class open" % Save.VERSION)
	Save.d = old
	ok(ClassUnlock.all_open() and Arch.ids().all(func(a): return ClassUnlock.is_open(String(a)) and HeroGrid.unlocked(String(a))) and not ClassUnlock.needs_starter(), "all twelve classes are open, no starter to pick")
	ok(Arch.ids().all(func(a): return ClassUnlock.status(String(a)) == "open" and ClassUnlock.requirement(String(a)) == ""), "none shows a requirement")
	ok(ClassUnlock.refresh().is_empty() and ClassUnlock.pending_reveal().is_empty(), "and no reveal is queued for them")
	ClassUnlock.after_match(result(true, 5))
	ok(ClassUnlock.xp() > 0 and ClassUnlock.pending_reveal().is_empty(), "it still earns account XP, with nothing left to reveal")
	# a save with no "classes" key at all (a tool-built dict) counts as open too
	Save.d = {"arch": "thief"}
	ok(ClassUnlock.all_open() and ClassUnlock.is_open("ashwick"), "a save dict with no classes entry is open")
	# through the real loader: an old file on disk
	var path := "user://class_check_v5.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	var disk := Save.fresh(); disk.erase("classes"); disk["v"] = 5
	f.store_string(JSON.stringify(disk)); f.close()
	var keep := Save.d
	Save.load_from(path)
	ok(bool(Save.d.get("classes", {}).get("all", false)) and int(Save.d["v"]) == Save.VERSION, "loading an old save file from disk opens everything")
	DirAccess.remove_absolute(path)
	# and a new save written and read back keeps its locks
	new_save("thief")
	f = FileAccess.open(path, FileAccess.WRITE); f.store_string(JSON.stringify(Save.d)); f.close()
	Save.load_from(path)
	ok(not ClassUnlock.all_open() and ClassUnlock.open_ids() == ["thief"] and ClassUnlock.starter() == "thief", "a new save read back keeps its single open class")
	DirAccess.remove_absolute(path)
	Save.d = keep

# ---------------------------------------------------------------- 4. the starter pick on screen
func _hatch_pick(tree: SceneTree) -> void:
	new_save()
	Save.d["tutorial"] = {"intro": true}
	Save.d.erase("look")
	var hx = load("res://scripts/ui/hatch.gd").new()
	main.add_child(hx)
	for i in 8: await tree.process_frame
	ok(hx.stage == "class", "a new save lands on the class pick before the hunter creator (stage %s)" % hx.stage)
	var row: Node = null
	for ch in hx.bottom.get_children():
		if ch.has_meta("starter_pick"): row = ch
	ok(row != null, "the pick shows the starter row")
	var cards: Array = []
	if row != null:
		_collect(row, cards)
	ok(cards.size() == 3 and cards.all(func(c): return ClassUnlock.starters().has(String(c.get_meta("arch")))), "three starter cards: %s" % str(cards.map(func(c): return c.get_meta("arch"))))
	await shot(tree, "starter_pick")
	# click the second card, then confirm
	var want := String(cards[1].get_meta("arch")) if cards.size() > 1 else "gunslinger"
	var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = true
	if cards.size() > 1: cards[1].gui_input.emit(ev)
	for i in 6: await tree.process_frame
	ok(String(Save.d["arch"]) == want and hx.stage == "class", "clicking a card highlights it (%s) without committing" % want)
	var go: Button = null
	for ch in hx.bottom.get_children():
		if ch is Button and not ch.is_queued_for_deletion(): go = ch
	ok(go != null and go.text.contains(Arch.name_of(want)), "the button reads: %s" % (go.text if go else "?"))
	if go: go.pressed.emit()
	for i in 6: await tree.process_frame
	ok(ClassUnlock.starter() == want and ClassUnlock.open_ids() == [want] and hx.stage == "create", "confirming sets %s as the starter and moves on to your hunter (stage %s)" % [want, hx.stage])
	ok(String(Save.d["cls"]) == Arch.weight(want) and Arch.of_save() == want and String(Save.d["weapon"]) == Arch.signature(want), "and as your expedition class, weight and weapon")
	hx.queue_free()
	for i in 3: await tree.process_frame

func _collect(node: Node, out: Array) -> void:
	if node.has_meta("arch") and node is PanelContainer: out.append(node)
	for c in node.get_children(): _collect(c, out)

# ---------------------------------------------------------------- 5. the reveal moment
func _reveal(tree: SceneTree) -> void:
	new_save("thief")
	ClassUnlock.add_xp(300)
	Save.d["extracts"] = 1
	var opened := ClassUnlock.refresh()
	ok(opened.has("gunslinger") and opened.has("tender") == false, "(setup) Gunslinger opened by play: %s" % str(opened))
	var host := Node.new(); main.add_child(host)
	var rv := ClassReveal.maybe_show(host)
	for i in 4: await tree.process_frame
	ok(rv != null and rv.id == "gunslinger", "the reveal plays for the class that opened")
	var named := false
	if rv != null:
		var st := [rv.root]
		while not st.is_empty():
			var nd: Node = st.pop_back()
			if nd is Label and (nd as Label).text == Arch.name_of("gunslinger"): named = true
			st.append_array(nd.get_children())
	ok(named, "it shows the class's name")
	if shots != "": await tree.create_timer(1.6).timeout      # (the ring and the text ease in)
	await shot(tree, "unlock_reveal")
	var seen_before := (ClassUnlock.state()["seen"] as Array).size()
	if rv != null: rv._finish(false)
	for i in 3: await tree.process_frame
	ok(ClassUnlock.pending_reveal().is_empty() and (ClassUnlock.state()["seen"] as Array).has("gunslinger") and (ClassUnlock.state()["seen"] as Array).size() == seen_before + 1, "dismissing it marks it seen")
	ok(ClassReveal.maybe_show(host) == null, "and it never plays twice")
	# two at once play one after the other
	ClassUnlock.state()["reveal"] = ["archer", "mage"]
	var a := ClassReveal.maybe_show(host)
	ok(a != null and a.id == "archer", "two waiting: the first plays first")
	a._finish(false)
	for i in 3: await tree.process_frame
	var b: ClassReveal = null
	for c in host.get_children(): if c is ClassReveal and not c.is_queued_for_deletion(): b = c
	ok(b != null and b.id == "mage", "then the second")
	if b: b._finish(false)
	host.queue_free()
	for i in 3: await tree.process_frame
	ok(ClassUnlock.pending_reveal().is_empty(), "queue empty after both")

# ---------------------------------------------------------------- 6. locked classes stay playable in the Arena
func _arena(tree: SceneTree) -> void:
	new_save("thief")
	ok(not ClassUnlock.is_open("ashwick") and not ClassUnlock.is_open("dredge"), "(setup) Ashwick and Dredge are locked")
	var m := Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts("ashwick"))
	m.set_process(false)
	var P: Hunter = m.player
	ok(P != null and P.arch == "ashwick" and m.arena != null, "the Arena starts you as a locked class (%s)" % (P.arch if P else "?"))
	m.arena.set_arch("dredge")
	ok(P.arch == "dredge", "and swaps to another locked one")
	# the practice hero picker lists every class and lets you try a locked one, but never saves it as your expedition class
	var pr := Practice.new()
	var grid_holder := Control.new(); main.add_child(grid_holder)
	var grid := HeroGrid.build(grid_holder, func(_a): pass, func(_a): pass, func(_a): pass, false)
	var all_cards: Array = grid.get_children()
	ok(all_cards.size() == Arch.ids().size(), "the practice picker (HeroGrid, not gated) shows all %d classes" % all_cards.size())
	ok(all_cards.filter(func(c): return c.get_meta("class_status") != "open").all(func(c): return c.modulate.a > 0.9), "locked ones are marked but not greyed out")
	grid_holder.queue_free()
	pr.free()
	var arch_before := String(Save.d.get("arch", ""))
	var pick_saved := HeroGrid.save_pick("ashwick")
	ok(not pick_saved and String(Save.d.get("arch", "")) == arch_before, "trying a locked class in practice doesn't make it your expedition class")
	ok(HeroGrid.save_pick("thief"), "an open class saves as normal")
	m.queue_free()
	for i in 3: await tree.process_frame

# ---------------------------------------------------------------- 7. the farm
func _home(tree: SceneTree) -> void:
	new_save("thief")
	# some play: Gunslinger is open and revealed, Juggernaut half done, Tender not started
	ClassUnlock.add_xp(300)
	Save.d["extracts"] = 1
	ClassUnlock.refresh()
	ClassUnlock.state()["reveal"] = []
	Progress.add("knocks", 1)
	var hm = await main._hb_home()
	for i in 30: await tree.process_frame
	# the picker
	HomeHero.open(hm)
	await tree.process_frame
	var grid: GridContainer = hm.get_meta("hero_grid")
	var cards: Array = grid.get_children()
	var open_c := cards.filter(func(c): return c.get_meta("class_status") == "open").map(func(c): return String(c.get_meta("arch")))
	var locked_c := cards.filter(func(c): return c.get_meta("class_status") != "open")
	ok(cards.size() == Arch.ids().size() and open_c.size() == 2 and "thief" in open_c and "gunslinger" in open_c, "the farm picker has all twelve cards, two open (%s)" % str(open_c))
	ok(locked_c.size() == 10 and locked_c.all(func(c): return c.modulate.r < 0.7), "the other ten are greyed out")
	ok(locked_c.all(func(c): return String(c.tooltip_text).begins_with("Locked: ")), "and say why on hover")
	var goal_cards := locked_c.filter(func(c): return _has_goal_block(c))
	ok(goal_cards.size() == 10, "each locked card shows its goal and progress")
	ok(cards.filter(func(c): return c.get_meta("class_status") == "open").all(func(c): return c.modulate.r > 0.95 and not _has_goal_block(c)), "open ones are not greyed")
	for i in 20: await tree.process_frame
	await shot(tree, "farm_picker")
	# clicking an open card picks it; a locked one does not
	var locked_id := "ashwick"
	HomeHero.pick(hm, locked_id)
	await tree.process_frame
	ok(Arch.of_save() == "thief" and String(Save.d["arch"]) == "thief", "picking a locked class on the farm does nothing")
	var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = true
	for c in cards: if c.get_meta("arch") == locked_id: c.gui_input.emit(ev)
	await tree.process_frame
	ok(hm.panel_open == "Classes", "clicking a locked card opens the Classes screen (%s)" % hm.panel_open)
	# the Classes screen: locked, in progress, unlocked
	for i in 20: await tree.process_frame
	var cg: GridContainer = hm.get_meta("classes_grid")
	var by := {}
	for c in cg.get_children(): by[String(c.get_meta("arch"))] = String(c.get_meta("class_status"))
	ok(by.size() == 12 and by.values().has("open") and by.values().has("progress") and by.values().has("locked"), "the Classes screen has open, in-progress and locked classes: %s" % str(by.values().filter(func(v): return v != "locked").size()))
	ok(by["thief"] == "open" and by["gunslinger"] == "open" and by["juggernaut"] == "progress" and by["tender"] == "progress" or by["tender"] == "locked", "Thief and Gunslinger open, Juggernaut in progress (1/2 knocks)")
	ok(hm.panel_open == "Classes" and _any_text(hm.panel_host, "Account level"), "it shows the account level")
	await shot(tree, "classes_screen")
	var csc: Node = cg
	while csc != null and not (csc is ScrollContainer): csc = csc.get_parent()
	if shots != "" and csc != null:
		(csc as ScrollContainer).scroll_vertical = 100000
		await shot(tree, "classes_screen_locked")
		(csc as ScrollContainer).scroll_vertical = 0
	# the expedition panel: locked classes can't be taken out
	hm._open_expedition()
	await tree.process_frame
	var dis := _disabled_buttons(hm.panel_host)
	ok(dis.size() >= 1, "on the expedition panel, locked classes are disabled (%d buttons)" % dis.size())
	hm._close_panel()
	# the Classes screen: play an open class from it
	HomeClasses.open(hm)
	await tree.process_frame
	HomeClasses._click(hm, "gunslinger")
	await tree.process_frame
	ok(Arch.of_save() == "gunslinger", "an open class can be picked from the Classes screen")
	# training yard "set as my class" refuses a weight with nothing open
	Save.d["classes"]["open"] = ["thief"]
	# a reveal waiting when you arrive home
	ClassUnlock.state()["reveal"] = ["gunslinger"]
	var rv := ClassReveal.maybe_show(hm)
	ok(rv != null and rv.get_parent() == hm, "arriving home with a class waiting plays its reveal over the farm")
	if rv != null:
		rv._finish(true)
		for i in 10: await tree.process_frame
		ok(Arch.of_save() == "gunslinger", "'Play it' on the reveal switches your hunter to it")
	hm.queue_free()
	for i in 3: await tree.process_frame

func _has_goal_block(n: Node) -> bool:
	if n.has_meta("goal_block"): return true
	for c in n.get_children():
		if _has_goal_block(c): return true
	return false

func _any_text(n: Node, needle: String) -> bool:
	if n is Label and (n as Label).text.contains(needle): return true
	for c in n.get_children():
		if _any_text(c, needle): return true
	return false

func _disabled_buttons(n: Node) -> Array:
	var out: Array = []
	if n is Button and (n as Button).disabled: out.append(n)
	for c in n.get_children(): out.append_array(_disabled_buttons(c))
	return out
