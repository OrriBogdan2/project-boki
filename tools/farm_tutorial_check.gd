extends RefCounted
## --farm-tutorial-check: Hob the builder, the guided farm tutorial and the Goals tracker
## (docs/decisions/0011-farm-builder-tutorial.md). Also --farm-hob-shots=<dir> and --farm-spot-shots=<dir>: screenshots.
##   1. Hob: the starter set, blueprints drawn up on talking, the toast once, the spread over levels
##      2-5, hidden tabs and the footer line, a v7 save keeps what it could build
##   2. the tutorial: steps in order, free order with the house first, skip, the one reward, old saves
##   3. the Goals tracker: at most 5 rows, none of the tutorial, sorted, hidden when empty
##   4. the spotlight (FarmSpotlight) and the Boki page: one beat per target, clickable, fades; "Not set";
##      Done (not Feed) is the page's filled button until the trough step
##   5. in the world: Hob stands by the house and is talked to, the house is a free site that Boki
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
		if String(a).begins_with("--farm-spot-shots="):
			await load("res://tools/farm_spot_shots.gd").new().run(m, String(a).substr(18))
			return
		if String(a).begins_with("--farm-hob-shots="):
			await load("res://tools/farm_hob_shots.gd").new().run(m, String(a).substr(17))
			return
	_hob_rules()
	_tutorial_rules()
	_tracker_rules()
	await _world()
	await _spotlight()
	await _farm2()
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
	Save.d["matches"] = 1
	FarmBuilder.draw_up()
	ok(not FarmBuilder.more_to_come(), "and goes once everything is open")
	# a v7 save: finished play keeps every blueprint it could already build, and skips the tutorial
	var old := _new_save()
	old["v"] = 7
	old.erase("farm_builder")      # a real v7 save has no such field
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
	var other_v8 := {"v": 8, "roster": [{}], "tutorial": {}}
	FarmBuilder.migrate(other_v8)
	ok(other_v8["farm_builder"] == 1 and other_v8["tutorial"]["ft"]["done"],
			"a v8 save from elsewhere without the field is migrated by the field, not the version")
	FarmBuilder.migrate(other_v8)
	ok(other_v8["tutorial"]["ft"]["done"] and Save.fresh().has("farm_builder"),
			"it runs once, and a new save carries the field")
	var blank := {"roster": [], "tutorial": {}}
	FarmBuilder.migrate(blank)
	ok(not blank["tutorial"].has("ft"), "a save with no Boki yet keeps the tutorial for later")

# ------------------------------------------------------------------ 2. the tutorial
func _tutorial_rules() -> void:
	Save.d = _new_save()
	var L := HomeLayout.ensure(Save.d)
	_stats()
	ok(FarmTutorial.active() and FarmTutorial.current() == "hob", "a new farm starts with Hob calling you over")
	FarmTutorial.event("hob")
	ok(FarmTutorial.did("hob") and FarmTutorial.current() == "axe", "talking to him moves it on to the axe")
	ok(not FarmTutorial.available("house") and not FarmTutorial.available("expedition"),
			"the house waits for the wood, the last step for all")
	ok(FarmTutorial.give_step_tool("axe") == "axe" and HomeGather.has_tool("axe") and FarmTutorial.give_step_tool("axe") == "",
			"the tutorial hands over the axe once (free_tools)")
	FarmTutorial.detect()
	ok(FarmTutorial.did("axe") and FarmTutorial.current() == "chop", "owning an axe finishes step 1: chop a tree")
	Work.add_mat("wood", int(FarmSites.build_cost("house")["wood"]))
	FarmTutorial.detect()
	ok(FarmTutorial.did("chop") and FarmTutorial.current() == "stone",
			"enough wood for the house finishes chopping; the rocks are next")
	ok(FarmTutorial.give_step_tool("stone") == "pickaxe" and HomeGather.has_tool("pickaxe"),
			"the rock step hands over a pickaxe")
	ok(FarmTutorial.hint_text("stone").contains("stone") and FarmTutorial.world_text("stone") != "",
			"it says what stone is for and marks a rock")
	ok(not FarmTutorial.available("house"), "the house waits until its stone is in hand too")
	Work.add_mat("stone", int(FarmSites.build_cost("house")["stone"]))
	FarmTutorial.detect()
	ok(FarmTutorial.did("stone") and FarmTutorial.current() == "house", "enough stone for the house finishes mining")
	var house_hint := FarmTutorial.hint_text("house")
	ok(house_hint.contains(FarmSites.cost_text(FarmSites.build_cost("house"))) and not house_hint.contains("{"),
			"the house hint names what it costs: %s" % house_hint)
	FarmTutorial.event("swing")
	ok(not FarmTutorial.did("hammer"), "doing a later step early does not count")
	var site := _add_house(L, true)
	FarmTutorial.detect()
	ok(FarmTutorial.did("house") and FarmTutorial.current() == "hammer",
			"a house site down finishes the house; the prompt is the hammer")
	ok(not FarmTutorial.available("task"),
			"a job for your Boki waits until the house stands (a pinned Boki would stop building)")
	FarmTutorial.event("swing")
	ok(FarmTutorial.did("hammer") and FarmTutorial.current() == "feed",
			"a swing counts, and the first step left is feeding (the job waits for the house)")
	var feed_hint := FarmTutorial.hint_text("feed")
	var has_key := feed_hint.contains(Settings.key_cap("build")) and not feed_hint.contains("{")
	ok(FarmTutorial.stage("feed") == "place" and has_key, "the hint names the real key, no leftovers")
	ok(FarmTutorial.did("hob") and FarmTutorial.current() == "feed",
			"free order: the prompt stays on the first step left")
	site.erase("site")
	ok(FarmTutorial.available("task") and FarmTutorial.current() == "task",
			"once the house stands the job step is next")
	FarmTutorial.event("task")
	ok(FarmTutorial.did("task") and FarmTutorial.current() == "feed", "pinning a Boki to a job finishes it")
	Save.d["feeders"] = [{"id": "f1", "kind": "trough", "x": 40.0, "z": 30.0, "food": [], "auto": false}]
	ok(FarmTutorial.stage("feed") == "fill", "a trough down moves the prompt to filling it")
	Save.d["feeders"][0]["food"] = ["kibble"]
	FarmTutorial.detect()
	ok(FarmTutorial.did("feed") and FarmTutorial.current() == "crop", "food in a trough finishes feeding")
	(L["water"] as Dictionary).clear()
	ok(FarmTutorial.stage("crop") == "patch_dry" and FarmTutorial.world_text("crop") == "", "no water on the island: the plain patch hint, no marker")
	L["water"][HomeLayout.key(46, 35)] = 1
	ok(FarmTutorial.stage("crop") == "patch" and FarmTutorial.hint_text("crop").contains("water") and FarmTutorial.world_text("crop") != "",
			"crops start at the patch, by the water, with a marker")
	var pe := {"u": HomeLayout._next_uid(L), "id": "crop_patch", "x": 44, "z": 30, "r": 0}
	(L["deco"] as Array).append(pe)
	(L["water"] as Dictionary).clear()
	ok(FarmTutorial.stage("crop") == "plant", "a patch down: plant")
	Save.d["plots"][0] = {"crop": "tidebloom", "stage": 0, "wt": 0.0}
	ok(FarmTutorial.stage("crop") == "water", "planted: water it")
	L["water"][HomeLayout.key(46, 35)] = 1
	ok(FarmWater.plot_near(Save.d, 0) and FarmTutorial.stage("crop") == "grow", "a patch by the water needs no watering by hand")
	L["water"].clear()
	Save.d["plots"][0]["wt"] = 100.0
	ok(FarmTutorial.stage("crop") == "grow", "watered: wait")
	ok(FarmTutorial.current() == "buy", "while the crop only grows the next open step is shown (the market)")
	Save.d["plots"][0]["stage"] = int(Data.CROPS["tidebloom"]["grow"])
	ok(FarmTutorial.stage("crop") == "pick" and FarmTutorial.current() == "crop", "grown: pick it, and it takes the prompt back")
	_stats(0, 0, 0, 1)
	FarmTutorial.detect()
	ok(FarmTutorial.did("crop") and FarmTutorial.current() == "buy", "a harvest finishes the crop step; the market is next")
	# the market: gems enough for a seed, the buy and the sell
	ok(FarmTutorial.stage("buy") == "bar" and not FarmTutorial.hint_text("buy").contains("{"), "no stall yet: the hint points at the Market on the bar")
	(L["deco"] as Array).append({"u": HomeLayout._next_uid(L), "id": "market_stall", "x": 50, "z": 30, "r": 0})
	ok(FarmTutorial.stage("buy") == "stall" and FarmTutorial.world_text("buy") != "", "a stall on the farm: walk there, with a marker")
	Save.d["gems"] = 0
	var cheapest := 1000000
	for c in Data.CROPS: cheapest = mini(cheapest, int(Data.CROPS[c]["price"]))
	ok(FarmTutorial.give_seed_gems() == cheapest and int(Save.d["gems"]) == cheapest and FarmTutorial.give_seed_gems() == 0,
			"nobody is stuck at the stall: gems for one seed, not more")
	FarmTutorial.event("sell")
	ok(not FarmTutorial.did("sell"), "selling before buying does not count")
	FarmTutorial.event("buy")
	ok(FarmTutorial.did("buy") and FarmTutorial.current() == "sell" and FarmTutorial.hint_text("sell").contains("Gems come from"),
			"buying a seed finishes it; selling is next and says where gems come from")
	FarmTutorial.event("sell")
	ok(FarmTutorial.did("sell") and FarmTutorial.current() == "expedition", "selling a crop finishes it, leaving the portal")
	var g_end := int(Save.d["gems"])
	FarmTutorial.event("portal")
	var reward := int(FarmTutorial.option("end_gems"))
	ok(not FarmTutorial.active() and int(Save.d["gems"]) == g_end + reward,
			"the portal ends it with one reward of %d gems" % reward)
	FarmTutorial.event("hob")
	ok(int(Save.d["gems"]) == g_end + reward, "nothing is granted twice")
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
	var steps_ok := FarmTutorial.steps().size() == 12
	steps_ok = steps_ok and FarmTutorial.steps().all(func(s): return not (s["hints"] as Dictionary).is_empty())
	ok(steps_ok, "twelve steps, each with its hints")
	ok(not bool(FarmTutorial.option("skippable")),
			"the owner's decision: the farm tutorial is not skippable (a data option)")
	for key in ["tracker_replaces_day1", "player_swing", "end_gems", "free_order", "skippable"]:
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
		var sid := String(id)    # a second-Relic pick (is_bonus) waits for Hob, never a challenge
		if not ClassUnlock.is_open(sid) and not ClassUnlock.is_bonus(sid) and ClassUnlock.open_needed(sid) <= ClassUnlock.open_ids().size():
			target = sid
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
	Save.d["matches"] = 3
	var mast_id := Arch.of_save()
	for i in ClassUnlock.mastery(mast_id).size():
		var g: Dictionary = ClassUnlock.mastery(mast_id)[i]
		var hs: Dictionary = (ClassUnlock.state().get("hunters", {}) as Dictionary)
		hs[mast_id] = hs.get(mast_id, {})
		hs[mast_id][String(g["stat"])] = int(g["target"])
	ok(GoalTracker.lines().is_empty() and GoalTracker.build() == null,
			"with nothing left to work towards the card is hidden")

# ------------------------------------------------------------------ 4. in the world
# ------------------------------------------------------------------ 4. the spotlight
func _spotlight() -> void:
	FarmSpotlight.reset()
	Save.d = _new_save()
	var lay := HomeLayout.ensure(Save.d)
	_stats()
	_add_house(lay)
	FarmTutorial.mark("hob")
	FarmTutorial.detect()
	ok(FarmTutorial.current() == "task" and FarmTutorial.spot("task") == {"world": true},
			"the job step asks for the spotlight on the Boki in the world")
	var by_id := {}
	for st in FarmTutorial.steps():
		by_id[st["id"]] = st
	ok(FarmTutorial.stage("task") == "go" and by_id["buy"]["spot"]["bar"] == {"hub": "shop"}
			and by_id["house"]["spot"]["place"] == {"hub": "build"}, "the Market bar and build menu steps too")
	var spots_named := FarmTutorial.steps().filter(func(st): return st.has("spot")).all(func(st):
		return (st["spot"] as Dictionary).keys().all(func(k): return (st["hints"] as Dictionary).has(k)))
	ok(spots_named, "every spot is on a stage the step really has")
	var home = await _ready_home()
	home.guide.tick(0.6)
	ok(FarmSpotlight.showing() and FarmSpotlight.in_beat(), "entering the job step opens the spotlight beat")
	var node := FarmSpotlight._node
	await main.get_tree().process_frame
	ok(node.mouse_filter == Control.MOUSE_FILTER_STOP, "game clicks are held during the beat only")
	ok(node._holes.size() == 1 and node._holes[0].size.x >= FarmSpotlight.BOKI_MIN_PX,
			"the cut-out is round the Boki (%d holes)" % node._holes.size())
	ok(node._card != null and node._card.get_child(0).text.contains("Click"), "the hint text is beside it")
	await main.get_tree().create_timer(FarmSpotlight.BEAT_S + FarmSpotlight.EASE_S + 0.3).timeout
	ok(FarmSpotlight.showing() and not FarmSpotlight.in_beat(), "after the beat it stays up (a vignette, a soft ring)")
	var blocking := [node].filter(func(c): return c.mouse_filter == Control.MOUSE_FILTER_STOP)
	for c in node.find_children("*", "Control", true, false):
		if (c as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			blocking.append(c)
	ok(blocking.is_empty(), "nothing in it takes a click once the beat is over: the target stays clickable")
	var dim: float = node._mat.get_shader_parameter("dim")
	ok(is_equal_approx(dim, FarmSpotlight.DIM_VIGNETTE), "the dark has faded to the light vignette (%.2f)" % dim)
	home._open_kin(Save.active_kin())      # what clicking the Boki does
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	ok(not FarmSpotlight.showing(), "opening the page puts the spotlight away")
	ok(home.panel_open != "" and FarmTaskGuide.page_up(), "the Boki page is up with the job dropdown")
	await _page_rules(home)
	home._close_panel()
	home.guide.tick(0.6)
	ok(FarmSpotlight.showing() and not FarmSpotlight.in_beat() and not FarmSpotlight._node.beat,
			"closing the page without a job brings back only the soft ring: the beat is once")
	FarmTutorial.event("task")
	home.guide.tick(0.6)
	ok(not FarmSpotlight.showing() or FarmSpotlight._node.spec != {"world": true},
			"the job step done: its spotlight is gone")
	ok(home.guide.hint_box.get_child(0).get_child(0).text.contains("Done"), "a tick says Done! on the goal line")
	home.queue_free()
	await main.get_tree().process_frame
	FarmSpotlight.reset()

## The open Boki page: "Not set" in orange, Feed not the filled button, then Done once a job is picked.
func _page_rules(home) -> void:
	var drop: OptionButton = FarmTaskGuide._drop
	ok(drop.get_item_text(0) == "Not set" and drop.has_theme_color_override("font_color"),
			"an unset job reads Not set, in a colour that asks to be chosen")
	var feed := _page_button(home, "Feed")
	ok(feed != null and feed.theme_type_variation != "Primary" and _page_button(home, "Done") == null,
			"before a job is set Feed is an ordinary button and nothing on the page is filled")
	var rec: Dictionary = Save.active_kin()
	var jobs := Work.list(rec)
	var picked := drop.item_count - 1
	drop.select(picked)
	drop.item_selected.emit(picked)
	await main.get_tree().process_frame
	ok(FarmTutorial.did("task") and Work.pin(rec) != "",
			"picking a job sets it and finishes the step")
	var done := _page_button(home, "Done")
	ok(done != null and done.theme_type_variation == "Primary" and done.get_node_or_null(FarmTaskGuide.PULSE) != null,
			"then Done is the filled, ringed button")
	feed = _page_button(home, "Feed")
	ok(feed != null and feed.theme_type_variation != "Primary", "and Feed is still not the loud one")
	FarmTutorial.mark("feed")
	home._open_kin(rec)
	await main.get_tree().process_frame
	feed = _page_button(home, "Feed")
	ok(feed != null and feed.theme_type_variation == "Primary", "after the trough step Feed is the main button again")
	FarmTutorial.state()["did"].erase("feed")
	FarmTutorial.state()["did"].erase("task")      # back to before the pick, for the checks that follow
	Work.set_pin(rec, "")

func _page_button(home, label: String) -> Button:
	for b in home.panel_host.find_children("*", "Button", true, false):
		if String(b.text) == label and not b.is_queued_for_deletion():
			return b
	return null

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
	return await _ready_home()

## A Home with its interface built (its meshes build over a few frames; slower on a software rasterizer).
func _ready_home():
	var home = await main._hb_home()
	var t0 := Time.get_ticks_msec()
	while home.panel_host == null and Time.get_ticks_msec() - t0 < 60000:
		await main.get_tree().process_frame
	home._close_panel()
	return home

func _world() -> void:
	var home = await _home(1)
	var stall := HomeLayout.deco_center(HomeLayout.fixtures(Save.d, "stall")[0])
	ok(home.guide != null and home.hob != null and is_instance_valid(home.hob.node)
			and Vector2(home.hob.pos.x - stall.x, home.hob.pos.z - stall.z).length() < 4.0,
			"Hob waits by the market stall from the start")
	ok(is_instance_valid(home.guide.hint_box) and home.guide.hint_lbl.text.contains("Hob"),
			"the first prompt is on screen: %s" % home.guide.hint_lbl.text)
	FarmTutorial.event("hob")
	ok(home.get("day1_box") == null, "the old first-day card is gone")
	var g0 := int(Save.d["gems"])
	var house_cost := FarmSites.build_cost("house")
	ok(home.guide.place_house() and FarmSites.is_site(_entry("house")), "the house goes down as a site")
	ok(int(Save.d["gems"]) == g0 and Work.mat("wood") == 0 and Work.mat("stone") == 0,
			"marking it out is free: nothing is spent yet")
	home._sync_fixtures()
	var hc: Vector3 = HomeLayout.deco_center(_entry("house"))
	var hd: float = Vector2(home.hob.pos.x - hc.x, home.hob.pos.z - hc.z).length()
	ok(is_instance_valid(home.hob.node) and hd > 3.0 and hd < 8.0,
			"while the house goes up he works beside it, not on it (%.1f m)" % hd)
	home.hob.node.position = home.hob.pos      # (he walks over from the stall)
	var w: World = home.world
	ok(not w.is_void(home.hob.pos.x, home.hob.pos.z), "on solid ground")
	# talking
	home.ppos = home.hob.pos + Vector3(1.0, 0, 0)
	var it: Dictionary = home.hob.find(Vector2(home.ppos.x, home.ppos.z))
	ok(String(it.get("kind", "")) == "hob" and home._label_for(it).begins_with("Talk to Hob"),
			"walking up to him offers to talk: '%s'" % home._label_for(it))
	home.ppos = hc + Vector3(2.0, 0, 2.2)
	it = home.hob.find(Vector2(home.ppos.x, home.ppos.z))
	ok(String(it.get("kind", "")) == "site" and home._label_for(it).begins_with("Needs "),
			"by a site with no materials the prompt says what it needs: '%s'" % home._label_for(it))
	var e := _entry("house")
	Work.add_mat("wood", int(house_cost["wood"]))
	Work.add_mat("stone", int(house_cost["stone"]))
	var prompt: String = home._label_for(it)
	ok(prompt.contains("Hold to hammer") and prompt.contains("0/%d" % int(house_cost["labour"])),
			"with them, you may hold to hammer: '%s'" % home._label_for(it))
	home.hob.use(it)
	home.tw.test_hold = true
	var beats := 2
	for i in int(HunterTool.period("hammer") * 20.0) * beats + 4:
		home.hob.tick(0.05)
	home.tw.test_hold = false
	ok(int(e["site"]["got"]) == beats, "holding the key hammers beat after beat (%d)" % int(e["site"]["got"]))
	# the tracker card sits in the old first-day slot, and the Hob step
	ok(is_instance_valid(home.guide.tracker) and home.guide.tracker.get_parent() == home.root_ui,
			"the Goals card is on screen")
	home.hob.talk()
	ok(home.panel_open == HobTalk.TALK and home.hob.chat.talking() and FarmTutorial.did("hob"),
			"talking opens the talk box face to face")
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
	Work.add_mat("wood", int(house_cost["wood"]))
	Work.add_mat("stone", int(house_cost["stone"]))
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
	ok(FarmTutorial.did("house") and FarmTutorial.did("hob") and not FarmTutorial.did("feed"),
			"after save and load the tutorial is where it was")
	home = await _ready_home()
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
	# two Boki: two crew slots, and no slower than one
	var home2 = await _home(2)
	Work.add_mat("wood", int(house_cost["wood"]))
	Work.add_mat("stone", int(house_cost["stone"]))
	home2.guide.place_house()
	home2.hw.scan_t = 0.0
	home2.hw.scan()
	var slots: int = home2.hw.jobs.filter(func(j): return String(j["kind"]) == "build").size()
	var ticks2: int = await _sim(home2, home2.hw, 400.0, func() -> bool: return not FarmSites.has_site(_entry("house")))
	var finished := not FarmSites.has_site(_entry("house"))
	ok(slots == 2 and finished and float(ticks2) < float(ticks1) * 1.3,
			"two Boki open two crew slots and are no slower (%.0fs against %.0fs)" % [ticks2 * 0.05, ticks1 * 0.05])
	home2.queue_free()
	await main.get_tree().process_frame

# ------------------------------------------------------------------ 5. round 2: Challenge House, water, rivers
func _item_texts(home) -> Array:
	return home.hb._tab_items().map(func(it): return "%s %s" % [it["name"], FarmSites.cost_text(it.get("cost", {}))])

func _farm2() -> void:
	# the Challenge House is no longer given: it is Hob's blueprint after the first expedition
	Save.d = _new_save()
	HomeLayout.ensure(Save.d)
	_stats()
	ok(not Save.has_building("board") and not Save.fresh()["buildings"].has("board"), "a new save has no Challenge House")
	ok(not FarmBuilder.pending().has("board"), "and Hob has no blueprint for it before an expedition")
	Save.d["matches"] = 1
	ok(FarmBuilder.pending().has("board") and not FarmUnlocks.open("board"), "after the first expedition he has one, not yet drawn")
	ok(FarmBuilder.line_for(["board"], false) == String(FarmBuilder.rules()["lines"]["first_run"]) and FarmBuilder.line_for(["board"], false).contains("Challenge House"),
			"and says so in his own words")
	var lc := FarmBuilder.lot_cost("board")
	ok(int(lc.get("wood", 0)) > 0 and int(lc.get("stone", 0)) > 0 and not lc.has("gems"), "it costs wood and stone (%s)" % FarmSites.cost_text(lc))
	var home = await _home(1)
	Save.d["matches"] = 0
	ok(not home._has_b("board") and not _item_texts(home).any(func(t): return t.begins_with("Challenge House")), "not on the farm and not in the build menu at the start")
	Save.d["matches"] = 1
	FarmBuilder.draw_up()
	home.hb.cat = "Buildings"
	ok(_item_texts(home).any(func(t): return t.begins_with("Challenge House") and t.contains("wood")),
			"once Hob has drawn it up it is in the Buildings tab with its price")
	var keep := JSON.stringify(Save.d["buildings"])
	home._open_lot("board")
	var build_btn: Button = null
	for b in home.panel_host.find_children("*", "Button", true, false):
		if String(b.text) == "Build it": build_btn = b
	ok(build_btn != null and build_btn.disabled, "with no wood and stone the Build button is greyed")
	Work.add_mat("wood", int(lc["wood"])); Work.add_mat("stone", int(lc["stone"]))
	home._close_panel()
	home._open_lot("board")
	build_btn = null
	for b in home.panel_host.find_children("*", "Button", true, false):
		if String(b.text) == "Build it": build_btn = b
	var gems_before := int(Save.d["gems"])
	if build_btn: build_btn.pressed.emit()
	ok(Save.has_building("board") and Work.mat("wood") == 0 and Work.mat("stone") == 0 and int(Save.d["gems"]) == gems_before,
			"building it spends the wood and stone and no gems (was %s)" % keep)
	home.queue_free()
	await main.get_tree().process_frame
	var kept := _new_save()
	kept["buildings"].append("board")
	Save.d = kept
	HomeLayout.ensure(Save.d)
	ok(Save.has_building("board"), "a save that already has the Challenge House keeps it")

	# crops by the water water themselves
	home = await _home(1)
	var L := HomeLayout.of(Save.d)
	(L["water"] as Dictionary).clear()      # (the island's own wild water is not wanted here)
	_add_house(L)
	var pe := {"u": HomeLayout._next_uid(L), "id": "crop_patch", "x": 44, "z": 30, "r": 0}
	(L["deco"] as Array).append(pe)
	home._build_plots()
	ok(not FarmWater.near_entry(Save.d, pe), "a patch with no water about is dry")
	L["water"][HomeLayout.key(50, 31)] = 1       # patch is x 44..48: 2 tiles of gap
	ok(FarmWater.near_entry(Save.d, pe), "water two tiles from the patch counts")
	L["water"].erase(HomeLayout.key(50, 31))
	L["water"][HomeLayout.key(51, 31)] = 1
	ok(not FarmWater.near_entry(Save.d, pe), "three tiles away does not")
	Save.d["plots"][0] = {"crop": "tidebloom", "stage": 0, "wt": 0.0}
	home._farm_tick()
	ok(float(Save.d["plots"][0]["wt"]) <= 0.0, "so a dry patch stays dry")
	L["water"][HomeLayout.key(49, 31)] = 1
	home._farm_tick()
	var p0: Dictionary = Save.d["plots"][0]
	ok(float(p0["wt"]) > 0.0 and int(p0["wet"]) == 2, "a patch by the water waters its own plot, as tended")
	var lbl: String = home._label_for({"kind": "plot", "arr": "plots", "i": 0})
	ok(lbl.contains("water nearby"), "the prompt says why: '%s'" % lbl)
	ok(String(HomeLayout.CATALOG["crop_patch"]["desc"]).contains("2 tiles of water"), "and the build menu says it in the patch's tooltip")
	ok(home._dry_plot().is_empty(), "the farmhand has nothing to water there")
	# the preview in build mode
	L["water"].clear()
	Save.d["plot_cap"] = 8
	home.hb.toggle()
	home.hb.take("crop_patch")
	var psz := HomeLayout.size_of("crop_patch", 0)
	var cs: Array = _free_cells(home.hb, psz)
	ok(not cs.is_empty(), "found open ground for a patch")
	home.hb.debug_m = Vector2(cs[0].x + psz.x * 0.5, cs[0].y + psz.y * 0.5)
	home.hb.tick(0.0)
	var note := _note_text(home.hb)
	ok(note.contains("No water"), "the preview of a patch away from water says so: '%s'" % note)
	L["water"][HomeLayout.key(cs[0].x + psz.x + 1, cs[0].y)] = 1
	home.hb.ghost_cells.set_meta("sig", "")
	home.hb.tick(0.0)
	note = _note_text(home.hb)
	ok(note.to_lower().contains("near water") and _note_col(home.hb).g > 0.8 and _note_col(home.hb).r < 0.5, "by the water it says 'near water' in green: '%s'" % note)
	# a river brush: cheap, and it counts as water
	ok(HomeLayout.CATALOG.has("river") and int(HomeLayout.CATALOG["river"]["gems"]) < int(HomeLayout.CATALOG["water"]["gems"]),
			"a River brush costs less than a pond tile")
	L["water"].clear()
	Save.d["gems"] = 100
	home.hb.take("river")
	var line := _free_row(home.hb, 6)
	ok(not line.is_empty(), "found an open row for a channel")
	home.hb.cells = line
	home.hb._check_cells()
	var placed: bool = home.hb.place_held()
	ok(placed and (L["water"] as Dictionary).size() == line.size() and int(Save.d["gems"]) == 100 - 2 * line.size(),
			"dragging a river puts water on every tile of the channel for %d gems" % (2 * line.size()))
	var mid: Vector2i = line[2] if line.size() > 2 else Vector2i.ZERO
	var beside := FarmWater.near_cells(Save.d, [mid + Vector2i(0, 2)])
	ok(beside and not FarmWater.near_cells(Save.d, [mid + Vector2i(0, 8)]), "and a patch beside it is near water")
	home.hb.toggle()
	home.queue_free()
	await main.get_tree().process_frame

func _note_label(hb) -> Label3D:
	for c in hb.ghost_cells.get_children():
		if c is Label3D and c.get_meta("fbui", "") == "note" and not c.is_queued_for_deletion(): return c
	return null

func _note_text(hb) -> String:
	var l := _note_label(hb)
	return l.text if l else ""

func _note_col(hb) -> Color:
	var l := _note_label(hb)
	return l.modulate if l else Color.WHITE

## `n` tiles in a row that can all be built on (the wild land comes from the save's random island seed, so
## no fixed row is open every run).
func _free_row(hb, n: int) -> Array:
	var p := HomeLayout.LANDING
	for dz in range(-12, 13):
		for dx in range(-12, 13):
			var row: Array = []
			for i in n:
				row.append(Vector2i(int(p.x) + dx + i, int(p.z) + dz))
			if row.all(func(c): return hb.cell_reason(c) == "") and hb.keeps_paths([], row):
				return row
	return []

func _free_cells(hb, sz: Vector2i) -> Array:
	var p := HomeLayout.LANDING
	for rad in range(3, 24):
		for k in 48:
			var a := float(k) / 48.0 * TAU
			var x := int(round(p.x + cos(a) * rad - sz.x * 0.5)); var z := int(round(p.z + sin(a) * rad - sz.y * 0.5))
			var cs := HomeLayout.cells_of([x, z, x + sz.x - 1, z + sz.y - 1])
			if hb.fits(hb.held, cs): return cs
	return []
