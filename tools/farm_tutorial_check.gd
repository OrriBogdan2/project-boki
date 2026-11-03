extends RefCounted
## --farm-tutorial-check: Hob the builder, the guided farm tutorial and the Goals tracker
## (docs/decisions/0011-farm-builder-tutorial.md). Also --farm-hob-shots=<dir> for screenshots.
##   1. Hob: the starter set, blueprints drawn up on talking, the toast once, the spread over levels
##      2-5, hidden tabs and the footer line, a v7 save keeps what it could build
##   2. the tutorial: steps in order, free order with the house first, skip, the one reward, old saves
##   3. the Goals tracker: at most 5 rows, none of the tutorial, sorted, hidden when empty
##   4. in the world: Hob stands by the house and is talked to, the house is a free site that Boki
##      and the player build, save and load mid-build, skipping still puts the house down
## Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("FTUT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _new_save(kin_count := 1) -> Dictionary:
	var d := Save.fresh()
	for i in kin_count:
		var k := Save.new_kin(["zapple", "cindle"][i], ["Pip", "Ash"][i])
		k["level"] = 5
		Care.ensure(k)
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	return d

func _stats(extracts := 0, bosses := 0, caught := 0, harvested := 0) -> void:
	Save.d["stats"] = {"extracts": extracts, "bosses": bosses, "caught": caught, "harvested": harvested,
			"hatched": 0, "fb_built": 0}
	Save.d["extracts"] = extracts

func _add_house(lay: Dictionary, site := false) -> Dictionary:
	var e := {"u": HomeLayout._next_uid(lay), "id": "house", "x": 36, "z": 24, "r": 0}
	if site:
		FarmSites.begin(e, {"labour": 8})
	(lay["deco"] as Array).append(e)
	return e

func run(m: Node, mode := "") -> void:
	main = m
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--farm-hob-shots="):
			await load("res://tools/farm_hob_shots.gd").new().run(m, String(a).substr(17))
			return
	_hob_rules()
	_tutorial_rules()
	_tracker_rules()
	await _world()
	print("FTUT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ 1. Hob
func _hob_rules() -> void:
	Save.d = _new_save()
	var L := HomeLayout.ensure(Save.d)
	_stats()
	var start_open := ["house", "crop_patch", "cook_pot", "ranch_pen", "fence", "path_dirt", "flowers"]
	ok(start_open.all(func(id): return FarmUnlocks.open(id)),
			"the starter set is open: house, crop patch, cook pot, pen, fence, dirt path, flowers")
	ok(not FarmUnlocks.open("path_clear") and not FarmUnlocks.open("lumber_camp") and not FarmUnlocks.open("bench"),
			"grass clearing and the rest are not")
	var by_level := {}
	for id in FarmUnlocks.rules()["unlock"]:
		var need: Dictionary = FarmUnlocks.need_of(String(id))
		if need.has("level"):
			by_level[int(need["level"])] = int(by_level.get(int(need["level"]), 0)) + 1
	ok(by_level.keys().size() == 4 and by_level.keys().min() == 2 and by_level.keys().max() == 5,
			"the T1 list is spread over farm levels 2 to 5 (%s)" % str(by_level))
	ok(by_level.values().all(func(n): return n >= 6 and n <= 12), "a few new things per level, not a flood")
	ok(FarmBuilder.pending().is_empty() and not FarmBuilder.toast_due(), "nothing to draw at level 1, no toast")
	_stats(0, 0, 0, 24)
	ok(FarmUnlocks.level() == 2 and FarmBuilder.pending().has("path_clear") and not FarmUnlocks.open("path_clear"),
			"level 2 earns blueprints, but they are not buildable until Hob draws them")
	ok(FarmBuilder.toast_due() and not FarmBuilder.toast_due(), "the 'new blueprints' toast is due once per batch")
	var ids := FarmBuilder.draw_up()
	var drawn_ok: bool = ids.has("path_clear") and ids.has("lumber_camp") and FarmUnlocks.open("path_clear")
	ok(drawn_ok and FarmBuilder.pending().is_empty(),
			"talking to him draws them up (%d) and opens them" % ids.size())
	ok(FarmBuilder.line_for(ids, false) == String(FarmBuilder.rules()["lines"]["level_2"]),
			"his line follows the level")
	ok(FarmBuilder.line_for([], true) == String(FarmBuilder.rules()["lines"]["first"]),
			"the first visit has its own greeting")
	_stats(1, 0, 0, 24)
	var armory_line := String(FarmBuilder.rules()["lines"]["first_extract"])
	ok(FarmBuilder.pending() == ["armory"] and FarmBuilder.line_for(FarmBuilder.pending(), false) == armory_line,
			"a milestone is a blueprint too, with its own line")
	ok(FarmBuilder.more_to_come(), "the menu footer shows while something is still locked")
	_stats(10, 3, 6, 400)
	FarmBuilder.draw_up()
	ok(not FarmBuilder.more_to_come(), "and goes once everything is open")
	# a v7 save: finished play keeps every blueprint it could already build, and skips the tutorial
	var old := _new_save()
	old["v"] = 7
	old["layout"] = HomeLayout.fresh()
	old["layout"]["fs"] = 1
	old["layout"]["fb"] = 1
	old["stats"] = {"extracts": 4, "bosses": 0, "caught": 0, "harvested": 60, "hatched": 3}
	old["extracts"] = 4
	old = JSON.parse_string(JSON.stringify(old))
	ok(Save.migrate(old) and int(old["v"]) == Save.VERSION, "a v7 save upgrades to v%d" % Save.VERSION)
	var marked: bool = old["tutorial"]["ft"]["done"] and old["tutorial"]["day1_done"] and old["layout"]["hob"]["legacy"]
	ok(marked,
			"it skips the tutorial and is marked legacy for Hob")
	Save.d = old
	var kept: bool = FarmUnlocks.open("lumber_camp") and FarmUnlocks.open("hearth_oven") and FarmUnlocks.open("armory")
	ok(FarmUnlocks.level() >= 3 and kept,
			"its first look hands over everything it could already build (level %d)" % FarmUnlocks.level())
	ok(FarmBuilder.pending().is_empty() and not FarmTutorial.active(), "nothing is pending, and no tutorial")
	var blank := {"roster": [], "tutorial": {}}
	FarmBuilder.migrate(blank)
	ok(not blank["tutorial"].has("ft"), "a save with no Boki yet keeps the tutorial for later")

# ------------------------------------------------------------------ 2. the tutorial
func _tutorial_rules() -> void:
	Save.d = _new_save()
	var L := HomeLayout.ensure(Save.d)
	_stats()
	ok(FarmTutorial.active() and FarmTutorial.current() == "house", "a new farm starts the tutorial on the house")
	ok(not FarmTutorial.available("feed") and not FarmTutorial.available("expedition"),
			"other steps wait for the house, the last waits for all")
	FarmTutorial.event("pet")
	ok(not FarmTutorial.did("pet"), "doing a later step early does not count")
	var g0 := int(Save.d["gems"])
	_add_house(L, true)
	FarmTutorial.detect()
	ok(FarmTutorial.did("house") and FarmTutorial.current() == "feed",
			"a house site down finishes step 1 and the next prompt is feeding")
	var feed_hint := FarmTutorial.hint_text("feed")
	var has_key := feed_hint.contains(Settings.key_cap("build")) and not feed_hint.contains("{")
	ok(FarmTutorial.stage("feed") == "place" and has_key,
			"the hint names the real key, no leftovers")
	FarmTutorial.event("pet")
	ok(FarmTutorial.did("pet") and FarmTutorial.current() == "feed",
			"free order: petting first is fine, the prompt stays on the first step left")
	Save.d["feeders"] = [{"id": "f1", "kind": "trough", "x": 40.0, "z": 30.0, "food": [], "auto": false}]
	ok(FarmTutorial.stage("feed") == "fill", "a trough down moves the prompt to filling it")
	Save.d["feeders"][0]["food"] = ["kibble"]
	FarmTutorial.detect()
	ok(FarmTutorial.did("feed") and FarmTutorial.current() == "crop", "food in a trough finishes feeding")
	ok(FarmTutorial.stage("crop") == "patch", "crops start at the patch")
	var pe := {"u": HomeLayout._next_uid(L), "id": "crop_patch", "x": 44, "z": 30, "r": 0}
	(L["deco"] as Array).append(pe)
	ok(FarmTutorial.stage("crop") == "plant", "a patch down: plant")
	Save.d["plots"][0] = {"crop": "tidebloom", "stage": 0, "wt": 0.0}
	ok(FarmTutorial.stage("crop") == "water", "planted: water it")
	Save.d["plots"][0]["wt"] = 100.0
	ok(FarmTutorial.stage("crop") == "grow", "watered: wait")
	Save.d["plots"][0]["stage"] = int(Data.CROPS["tidebloom"]["grow"])
	ok(FarmTutorial.stage("crop") == "pick", "grown: pick it")
	_stats(0, 0, 0, 1)
	FarmTutorial.detect()
	ok(FarmTutorial.did("crop") and FarmTutorial.current() == "hob", "a harvest finishes the crop step")
	FarmTutorial.event("portal")
	ok(not FarmTutorial.did("expedition"), "the portal does not count before the rest is done")
	FarmTutorial.event("hob")
	ok(FarmTutorial.current() == "expedition", "meeting Hob leaves only the expedition")
	FarmTutorial.event("portal")
	ok(not FarmTutorial.active() and int(Save.d["gems"]) == g0 + int(FarmTutorial.option("end_gems")),
			"the portal ends it with one reward of %d gems" % int(FarmTutorial.option("end_gems")))
	FarmTutorial.event("hob")
	ok(int(Save.d["gems"]) == g0 + int(FarmTutorial.option("end_gems")), "nothing is granted twice")
	# skipping grants and takes nothing
	Save.d = _new_save()
	L = HomeLayout.ensure(Save.d)
	_stats()
	var g1 := int(Save.d["gems"])
	var inv1 := JSON.stringify(Save.d["items"])
	FarmTutorial.skip()
	var untouched: bool = int(Save.d["gems"]) == g1 and JSON.stringify(Save.d["items"]) == inv1
	ok(not FarmTutorial.active() and FarmTutorial.current() == "" and FarmTutorial.state()["skipped"] and untouched,
			"skipping ends the prompts and grants or takes nothing")
	var steps_ok := FarmTutorial.steps().size() == 6
	steps_ok = steps_ok and FarmTutorial.steps().all(func(s): return not (s["hints"] as Dictionary).is_empty())
	ok(steps_ok, "six steps, each with its hints")
	for key in ["tracker_replaces_day1", "player_swing", "end_gems", "house_first", "strict_order", "skippable"]:
		ok(FarmTutorial.rules()["options"].has(key), "option '%s' is data" % key)
	# a test save that says the first day is done never sees it
	Save.d = _new_save()
	Save.d["tutorial"]["day1_done"] = true
	HomeLayout.ensure(Save.d)
	ok(not FarmTutorial.active(), "a save with day1_done never runs the tutorial")

# ------------------------------------------------------------------ 3. the tracker
func _tracker_rules() -> void:
	Save.d = _new_save()
	HomeLayout.ensure(Save.d)
	_stats(0, 0, 1, 4)
	ClassUnlock.choose_starters(ClassUnlock.starters().slice(0, ClassUnlock.picks_needed()))
	var rows := GoalTracker.lines()
	ok(rows.size() >= 2 and rows.size() <= 5, "the tracker has a few rows, at most 5 (%d)" % rows.size())
	var tut_words: Array = []
	for s in FarmTutorial.steps():
		tut_words.append(String(s["title"]))
		for k in s["hints"]:
			tut_words.append(String(s["hints"][k]))
	ok(rows.all(func(r): return not tut_words.has(String(r["text"]))), "no row is tutorial text")
	ok(String(rows[-1]["source"]) == "level", "the next farm level is the last row")
	var counts := {}
	for r in rows:
		counts[r["source"]] = int(counts.get(r["source"], 0)) + 1
	var caps: Dictionary = GoalTracker.cfg()["per_source"]
	ok(counts.keys().all(func(k): return int(counts[k]) <= int(caps[k])),
			"each source stays inside its cap %s" % str(counts))
	var mil := rows.filter(func(r): return r["source"] == "milestone")
	ok(mil.size() == 1 and int(mil[0]["need"]) >= 1, "a farm milestone shows with its counter")
	var unl := rows.filter(func(r): return r["source"] == "unlock")
	var sorted := true
	for i in range(1, unl.size()):
		if float(unl[i]["frac"]) > float(unl[i - 1]["frac"]):
			sorted = false
	ok(sorted, "inside a source the closest to done comes first")
	# a ready-to-claim unlock leads everything
	var c := ClassUnlock.state()
	var target := ""
	for id in Arch.ids():
		if not ClassUnlock.is_open(String(id)) and ClassUnlock.open_needed(String(id)) <= ClassUnlock.open_ids().size():
			target = String(id)
			break
	if target != "":
		var ch := ClassUnlock.challenge(target)
		(c["stats"] as Dictionary)[String(ch["stat"])] = int(ch["target"])
		var rows2 := GoalTracker.lines()
		ok(ClassUnlock.can_unlock(target) == bool(rows2[0]["ready"]) and rows2.any(func(r): return bool(r["ready"])),
				"a ready-to-claim challenge is a gold row at the top")
	else:
		ok(false, "found a Hunter to ready")
	var box := GoalTracker.build()
	ok(box != null and box.get_child_count() > 0, "the card builds")
	if box:
		box.free()
	# nothing to show: every Hunter open, milestones done, top level
	Save.d["classes"]["all"] = true
	_stats(10, 3, 6, 400)
	var mast_id := Arch.of_save()
	for i in ClassUnlock.mastery(mast_id).size():
		var g: Dictionary = ClassUnlock.mastery(mast_id)[i]
		var hs: Dictionary = (ClassUnlock.state().get("hunters", {}) as Dictionary)
		hs[mast_id] = hs.get(mast_id, {})
		hs[mast_id][String(g["stat"])] = int(g["target"])
	ok(GoalTracker.lines().is_empty() and GoalTracker.build() == null,
			"with nothing left to work towards the card is hidden")

# ------------------------------------------------------------------ 4. in the world
func _sim(home, hw: HomeWork, secs: float, until := Callable()) -> int:
	var ticks := 0
	for i in int(secs / 0.05):
		for k in home.kins:
			for n in Care.NEEDS:
				k["rec"]["needs"][n] = maxf(float(k["rec"]["needs"][n]), 70.0)
		home.day_t = 0.5
		home._move_kin(0.05)
		hw.tick(0.05)
		ticks += 1
		if until.is_valid() and until.call():
			return ticks
		if i % 100 == 0:
			await main.get_tree().process_frame
	return ticks

func _entry(id: String) -> Dictionary:
	for e in HomeLayout.of(Save.d)["deco"]:
		if String(e["id"]) == id:
			return e
	return {}

func _home(kin_count: int):
	Save.d = _new_save(kin_count)
	HomeLayout.ensure(Save.d)
	_stats()
	var home = await main._hb_home()
	home._close_panel()
	return home

func _world() -> void:
	var home = await _home(1)
	ok(home.guide != null and home.hob != null and home.hob.node == null, "no Hob before there is a house")
	ok(is_instance_valid(home.guide.hint_box) and home.guide.hint_lbl.text.contains(Settings.key_cap("build")),
			"the first prompt is on screen: %s" % home.guide.hint_lbl.text)
	ok(home.get("day1_box") == null, "the old first-day card is gone")
	var g0 := int(Save.d["gems"])
	ok(home.guide.place_house() and FarmSites.is_site(_entry("house")), "the house goes down as a site")
	ok(int(Save.d["gems"]) == g0, "and costs no gems on a new save")
	home._sync_fixtures()
	ok(is_instance_valid(home.hob.node), "Hob turns up once the house is down")
	var hc: Vector3 = HomeLayout.deco_center(_entry("house"))
	var hd: float = Vector2(home.hob.pos.x - hc.x, home.hob.pos.z - hc.z).length()
	ok(hd > 3.0 and hd < 8.0, "he stands near the house, not on it (%.1f m)" % hd)
	var w: World = home.world
	ok(not w.is_void(home.hob.pos.x, home.hob.pos.z), "on solid ground")
	# talking
	home.ppos = home.hob.pos + Vector3(1.0, 0, 0)
	var it: Dictionary = home.hob.find(Vector2(home.ppos.x, home.ppos.z))
	ok(String(it.get("kind", "")) == "hob" and home._label_for(it).begins_with("Talk to Hob"),
			"walking up to him offers to talk: '%s'" % home._label_for(it))
	home.ppos = hc + Vector3(2.0, 0, 2.2)
	it = home.hob.find(Vector2(home.ppos.x, home.ppos.z))
	ok(String(it.get("kind", "")) == "site" and home._label_for(it).contains("0/8"),
			"by the site you may swing a hammer: '%s'" % home._label_for(it))
	var e := _entry("house")
	home.hob.use(it)
	ok(int(e["site"]["got"]) == 1, "a swing adds one")
	home.hob.use(it)
	ok(int(e["site"]["got"]) == 1,
			"but not again at once (cool-down %.0fs)" % float(FarmTutorial.option("swing_cooldown_s")))
	home.hob.swing_cd = 0.0
	home.hob.use(it)
	ok(int(e["site"]["got"]) == 2, "and again after it")
	# the tracker card sits in the old first-day slot, and the Hob step
	ok(is_instance_valid(home.guide.tracker) and home.guide.tracker.get_parent() == home.root_ui,
			"the Goals card is on screen")
	home.hob.talk()
	ok(home.panel_open == "Hob Brackenridge" and FarmTutorial.did("hob"),
			"talking opens his panel and ticks the meet-Hob step")
	home._close_panel()
	# the build menu
	home.hb.toggle()
	ok(home.hb.cat == "Buildings", "B opens on Buildings")
	var labels: Array = home.hb.bar.find_children("*", "Label", true, false)
	var foot := labels.filter(func(l): return String(l.text) == "Talk to Hob for more")
	ok(foot.size() == 1, "the menu says 'Talk to Hob for more'")
	var tabs: Array = []
	for b in home.hb.bar.find_children("*", "Button", true, false):
		tabs.append(String(b.text))
	var shown: bool = ["Buildings", "Fences", "Paths", "Garden", "Work"].all(func(t): return tabs.has(t))
	var hidden: bool = ["Lights", "Furniture", "Statues"].all(func(t): return not tabs.has(t))
	ok(shown and hidden,
			
		"tabs with something to build stay, empty ones are hidden (%s)" % ", ".join(tabs))
	home.hb.toggle()
	# the one Boki builds it alone, and it is finished by the work
	var need := int(e["site"]["need"])
	e["site"]["got"] = 0
	home.hw.scan_t = 0.0
	home.hw.scan()
	var ticks1: int = await _sim(home, home.hw, 400.0, func() -> bool: return not FarmSites.has_site(_entry("house")))
	ok(not FarmSites.has_site(_entry("house")) and ticks1 > 0,
			"one Boki finishes the house on its own (%d of %d swings, %.0fs)" % [need, need, ticks1 * 0.05])
	home._sync_fixtures()
	ok(home.spots["house"].x > 0.0 and FarmHob.house_entry().get("site") == null,
			"the house is the farm's house when done")
	# save and load mid-build keeps progress and the tutorial
	var e2 := {}
	home.hb.toggle()
	home.hb.take("crop_patch")
	home.hb.toggle()
	FarmTutorial.detect()
	var js := JSON.stringify(Save.d)
	home.queue_free()
	await main.get_tree().process_frame
	Save.d = JSON.parse_string(js)
	ok(bool(FarmTutorial.did("house")) and FarmTutorial.did("hob") and not FarmTutorial.did("feed"),
			"after save and load the tutorial is where it was")
	home = await main._hb_home()
	home._close_panel()
	ok(is_instance_valid(home.hob.node), "Hob is there again")
	home.queue_free()
	await main.get_tree().process_frame
	# skipping with no house puts one down as a site
	home = await _home(1)
	home.guide.skip()
	ok(not FarmTutorial.active() and FarmSites.is_site(_entry("house")) and not is_instance_valid(home.guide.hint_box),
			"skipping puts the house down as a site and clears the prompts")
	home.queue_free()
	await main.get_tree().process_frame
	# two Boki finish it in about half the time of one
	var home2 = await _home(2)
	home2.guide.place_house()
	home2.hw.scan_t = 0.0
	home2.hw.scan()
	await _sim(home2, home2.hw, 15.0)
	var crew: Array = home2.kins.filter(func(k): return k.has("job") and String(k["job"].get("kind", "")) == "build")
	for k in home2.kins:
		print("FTUT   ", k["rec"]["name"], " job=", k.get("job", {}).get("kind", "-"), " phase=", k.get("job", {}).get("phase", "-"), " why=", Work.why_not(k["rec"]))
	print("FTUT crew at 15s: %d of %d, got %d" % [crew.size(), home2.kins.size(), int(_entry("house")["site"]["got"])])
	var ticks2: int = 300 + await _sim(home2, home2.hw, 400.0, func() -> bool: return not FarmSites.has_site(_entry("house")))
	ok(not FarmSites.has_site(_entry("house")) and float(ticks2) < float(ticks1) * 0.9,
			"two Boki are quicker (%.0fs against %.0fs)" % [ticks2 * 0.05, ticks1 * 0.05])
	home2.queue_free()
	await main.get_tree().process_frame
