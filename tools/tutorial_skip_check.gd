extends RefCounted
## --tutorial-skip-check: both tutorials always have a visible Skip, and a skipped player loses nothing they
## need (the shorter-tutorials decision). On a fresh save each tutorial is skipped at every step in turn:
##   1. the match tutorial: the Skip button is on screen, inside the safe area and clear of the tutorial
##      lanes at every step; pressing it ends the run, and the save then matches a full playthrough
##      (Boki owned, first Hunter, the Relics that open, the tutorial marked played)
##   2. the farm tutorial: the same for the goal line's Skip (then Yes); afterwards the house is placed
##      (a site with its materials, or already there), the axe and pickaxe are in hand, the starter food
##      is given, the Boki is owned, and the tutorial is gone
## Never touches the real save.

const SAFE_PX := 8.0        # the Skip button keeps this far from every screen edge
# seeded: an unseeded tutorial now and then left the scripted driver short of the extraction
const MATCH_OPTS := {"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "seed": 4242}

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("TUTSKIP %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	var full := await _match_run(-1)
	var n := Tutorial.steps().size()
	for i in n:
		var id := String(Tutorial.steps()[i][0])
		var got := await _match_run(i)
		if got.is_empty():
			continue
		var shown := "" if got == full else str(got)
		ok(got == full, "match: skipping at '%s' leaves the save as a full run does %s" % [id, shown])
	await _farm()
	print("TUTSKIP DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kin_save() -> Dictionary:
	var d := Save.fresh()
	var k := Save.new_kin("cindle", "Ash")
	k["starter"] = true
	d["roster"] = [k]
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true}
	return d

# ------------------------------------------------------------------ 1. the match tutorial
## What a finished tutorial match leaves that the player needs.
func _match_snap() -> Dictionary:
	var d := Save.d
	var roster: Array = d["roster"]
	return {
		"played": bool(d["tutorial"].get("match", false)),
		"boki": roster.size(),
		"starter": bool(roster[0].get("starter", false)),
		"active": String(d["active"]) == String(roster[0]["uid"]),
		"hunters": ClassUnlock.open_ids(),
		"matches": int(d["matches"]),
	}

## Plays the tutorial and ends it at step `skip_at` with the Skip button (-1: plays it out). Returns what
## the save looks like afterwards ({} when the step never came).
func _match_run(skip_at: int) -> Dictionary:
	Save.d = _kin_save()
	ClassUnlock.choose_starters([ClassUnlock.starters()[0]])
	TutorialDrive.last_step = -1
	TutorialDrive.still_t = 0.0
	TutorialDrive.last_pos = Vector3.INF
	var m := Match.new()
	main.add_child(m)
	m.start(MATCH_OPTS)
	m.set_process(false)
	var tu: Tutorial = m.tut
	var t := 0.0
	var last := -2
	while t < 600.0 and not m.player.extracted:
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
		if tu.step == last or tu.step < 0:
			continue
		last = tu.step
		await _frames()
		_skip_on_screen(m, "step %d '%s'" % [last, tu.id()])
		if last == skip_at:
			break
	var reached := skip_at < 0 or last == skip_at
	var out := {}
	if reached:
		_end_and_apply(m, skip_at)
		out = _match_snap()
	m.queue_free()
	await _frames()
	return out

## Presses the Skip button (or, after a full run, lets the match finish) and writes the result into the save.
func _end_and_apply(m: Match, skip_at: int) -> void:
	var game_main = Game.main
	Game.main = null      # (no results screen: the result is applied by hand)
	if skip_at < 0:
		ok(m.player.extracted, "match: the full playthrough reaches the extraction")
		m._finish()
	else:
		(Practice.of(m).bar_btns["leave"] as Button).pressed.emit()
	Game.main = game_main
	var extracted := bool(Game.last_result.get("extracted", false))
	ok(extracted, "match: the run ends as an extraction, so no Boki is left behind (step %d)" % skip_at)
	Game.apply_result(Game.last_result)

## The Skip button is shown, says Skip, sits inside the safe area and clear of the tutorial's lanes.
func _skip_on_screen(m: Match, tag: String) -> void:
	var btn := Practice.of(m).bar_btns.get("leave") as Button
	var vp := main.get_viewport().get_visible_rect().size
	var r := btn.get_global_rect() if btn else Rect2()
	var inside := btn != null and btn.is_visible_in_tree() and Rect2(Vector2.ZERO, vp).grow(-SAFE_PX).encloses(r)
	var clear := true
	for lane: Rect2 in TutorialHud.lanes(vp).values():
		clear = clear and not lane.intersects(r)
	var named := btn != null and btn.tooltip_text.begins_with("Skip")
	ok(inside and clear and named, "match %s: Skip is in the safe area, clear of the lanes %s" % [tag, str(r)])

# ------------------------------------------------------------------ 2. the farm tutorial
func _farm_save() -> Dictionary:
	var d := _kin_save()
	d["tutorial"]["intro"] = true
	return d

func _home():
	Save.d = _farm_save()
	HomeLayout.ensure(Save.d)
	Save.d["stats"] = {"extracts": 0, "bosses": 0, "caught": 0, "harvested": 0, "hatched": 0, "fb_built": 0}
	Save.d["extracts"] = 0
	var home = await main._hb_home()
	var t0 := Time.get_ticks_msec()
	while home.panel_host == null and Time.get_ticks_msec() - t0 < 60000:
		await _frames()
	home._close_panel()
	return home

## What a finished farm tutorial leaves that the player needs.
func _farm_snap() -> Dictionary:
	var d := Save.d
	var kibble := int(FarmTutorial.rules()["start_food"]["kibble"])
	return {
		"done": not FarmTutorial.active(),
		"axe": HomeGather.has_tool("axe"),
		"pickaxe": HomeGather.has_tool("pickaxe"),
		"house": not FarmHob.house_entry().is_empty(),
		"food": int(d["items"].get("kibble", 0)) >= kibble,
		"boki": (d["roster"] as Array).size(),
		"hunters": ClassUnlock.open_ids().size() > 0 or ClassUnlock.all_open(),
	}

## A farm tutorial played to its end: every step done, its tool and food handed over, the house up.
func _farm_full() -> Dictionary:
	var home = await _home()
	for s in FarmTutorial.steps():
		FarmTutorial.give_step_tool(String(s["id"]))
		FarmTutorial.mark(String(s["id"]))
	FarmTutorial.give_food()
	home.guide.place_house()
	var snap := _farm_snap()
	home.queue_free()
	await _frames()
	return snap

func _farm() -> void:
	var full := await _farm_full()
	ok(full["done"] and full["axe"] and full["pickaxe"] and full["house"] and full["food"] and full["boki"] == 1,
			"farm: a full playthrough ends with the house, both tools, the food and the Boki (%s)" % str(full))
	var steps := FarmTutorial.steps()
	var cost := FarmSites.build_cost("house")
	for i in steps.size():
		var id := String(steps[i]["id"])
		var home = await _home()
		_bring_to(home, i)
		home.guide.refresh()
		await _frames()
		var now := FarmTutorial.current()
		ok(FarmTutorial.active() and now == id, "farm '%s': the tutorial is on that step (now '%s')" % [id, now])
		var yes := await _press_skip(home, id)
		ok(yes, "farm '%s': Skip is visible in the safe area, and asks before it skips" % id)
		var wood0 := FarmSites.have("wood")
		var stone0 := FarmSites.have("stone")
		var had_house := not FarmHob.house_entry().is_empty()
		if yes:
			_press(home.guide.skip_row, "Yes")
		var snap := _farm_snap()
		ok(snap == full, "farm '%s': skipping leaves what a full run does %s" % [id, "" if snap == full else str(snap)])
		if not had_house:
			var wood_ok: bool = FarmSites.have("wood") >= wood0 + int(cost.get("wood", 0))
			var mats: bool = wood_ok and FarmSites.have("stone") >= stone0 + int(cost.get("stone", 0))
			ok(mats, "farm '%s': the house site comes with its wood and stone" % id)
		var hint: Control = home.guide.hint_box
		ok(not is_instance_valid(hint) or hint.is_queued_for_deletion(), "farm '%s': the prompt is gone" % id)
		home.queue_free()
		await _frames()

## Puts the farm where a player is when step `i` comes up: the steps before it done (Hob first), their tools
## in hand, the house down once its step is done and standing once the hammer's is.
func _bring_to(home, i: int) -> void:
	var steps := FarmTutorial.steps()
	var did: Dictionary = FarmTutorial.state()["did"]
	var todo: Array = steps.slice(0, i).map(func(s): return String(s["id"]))
	if String(steps[i]["id"]) != "hob":
		todo.append("hob")      # (he calls you over first, whatever the list order)
	for id in todo:
		FarmTutorial.give_step_tool(String(id))
		did[String(id)] = true
	if did.get("house", false):
		home.guide.place_house()
	if did.get("hammer", false):
		FarmHob.house_entry().erase("site")

## Clicks Skip on the goal line (not yet Yes) after checking it is on screen; true when the question shows.
func _press_skip(home, id: String) -> bool:
	var box: Control = home.guide.hint_box
	var btn := _find(home.guide.skip_row, String(FarmTutorial.rules()["skip_label"]))
	if not is_instance_valid(box) or btn == null:
		return false
	var vp := main.get_viewport().get_visible_rect().size
	var r := btn.get_global_rect()
	var safe := Rect2(Vector2.ZERO, vp).grow(-SAFE_PX)
	var inside: bool = btn.is_visible_in_tree() and safe.encloses(r) and box.get_global_rect().size.x > 0.0
	btn.pressed.emit()
	await _frames()
	return inside and _find(home.guide.skip_row, "Yes") != null

func _press(row: Control, text: String) -> void:
	var b := _find(row, text)
	if b != null:
		b.pressed.emit()

func _find(row: Control, text: String) -> Button:
	for c in row.get_children():
		if c is Button and not c.is_queued_for_deletion() and (c as Button).text == text:
			return c
	return null

func _frames() -> void:
	await main.get_tree().process_frame
	await main.get_tree().process_frame
