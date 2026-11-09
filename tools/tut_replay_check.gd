extends RefCounted
## --tut-replay-check: the pause menu's More replays the match and the garden tutorial in a sandbox.
##   1. the two links are under More on the farm's Esc menu, not in a match and not while replaying
##   2. the match tutorial, played through by the headless driver, ends back on the farm
##   3. the garden tutorial, finished, ends back on the farm; leaving from the menu does too
##   4. each time the save file's bytes and the live save are identical to before, and the sandbox did
##      change its own copy (so the comparison means something)
## Writes a save file, so it only runs with XDG_DATA_HOME set (a temp dir), never on the shared save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("TUTREPLAY %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	main = m
	if OS.get_environment("XDG_DATA_HOME") == "":
		print("TUTREPLAY FAIL set XDG_DATA_HOME to a temp dir: this check writes a save file")
		main.get_tree().quit(1)
		return
	Save.no_write = false
	Save.d = _veteran_save()
	Save.save_game()
	await _menu()
	await _match()
	await _garden(false)
	await _garden(true)
	print("TUTREPLAY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _veteran_save() -> Dictionary:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	Care.ensure(k)
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["arch"] = String(ClassUnlock.starters()[0])
	ClassUnlock.choose_starters([d["arch"]])
	HomeLayout.new_fs(d, 4242)
	d["tutorial"] = {"home": true, "day1_done": true, "match": true, "hatched": true}
	d["matches"] = 7
	d["gems"] = 321
	d["items"] = {"tonic": 3}
	return d

func _wait(cond: Callable, secs := 90.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < secs * 1000.0:
		await main.get_tree().process_frame
	return cond.call()

func _is_home(n: Node) -> bool:
	return n != null and n.get_script() != null and String(n.get_script().resource_path).ends_with("home/home.gd")

func _farm_up(n: Node) -> bool:
	return _is_home(n) and n.guide != null and n.panel_host != null

func _match_up(n: Node) -> bool:
	return n is Match and n.tut != null and n.player != null and n.hud != null

func _bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(Save.path_for(Save.slot))

func _links(where: String) -> Array:
	Overlay.open_pause(where)
	var out: Array = []
	for b in Overlay.root.find_children("*", "Button", true, false):
		out.append(String(b.text).strip_edges())
	return out

## Right after the hand-back (the farm that loads next is free to tick the real save on its own).
func _handed_back(before_json: String, what: String) -> void:
	ok(JSON.stringify(Save.d) == before_json, "%s: the live save is identical" % what)
	ok(not TutReplay.active() and not Save.no_write, "%s: the sandbox is closed and saving is back on" % what)

func _same(before_bytes: PackedByteArray, what: String) -> void:
	ok(_bytes() == before_bytes, "%s: the save file is byte-identical" % what)

# ------------------------------------------------------------------ 1. the menu
func _menu() -> void:
	Game.goto("home")
	await _wait(func(): return _is_home(main.current), 120.0)
	var home := _links("home")
	ok(home.has("Replay match tutorial") and home.has("Replay garden tutorial"), "the farm's Esc menu has both replays")
	ok(not home.has("Leave the tutorial"), "and no leave-the-tutorial line outside a replay")
	Overlay.close()
	await main.get_tree().process_frame
	var town := _links("town")
	ok(not town.has("Replay match tutorial") and not town.has("Replay garden tutorial"),
			"other places don't offer them")
	Overlay.close()

# ------------------------------------------------------------------ 2. the match tutorial
func _match() -> void:
	var b := _bytes()
	var j := JSON.stringify(Save.d)
	var real := Save.d
	TutReplay.match_tutorial()
	ok(TutReplay.active() and not is_same(Save.d, real) and Save.no_write,
			"the match replay runs on a copy with saving off")
	await _wait(func(): return _match_up(main.current))
	var m := main.current as Match
	ok(m != null and m.opts.get("replay", false), "the real match tutorial is up, flagged as a replay")
	if m == null:
		return
	m.set_process(false)
	var t := 0.0
	while TutReplay.active() and t < 900.0:
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
		if int(t * 60.0) % 600 == 0:
			await main.get_tree().process_frame
	ok(not TutReplay.active(), "finishing the course hands the real save back (%.0fs of play)" % t)
	_handed_back(j, "match replay")
	await _wait(func(): return _is_home(main.current), 120.0)
	ok(_is_home(main.current), "and you are back on the farm")
	_same(b, "match replay")

# ------------------------------------------------------------------ 3. the garden tutorial
func _garden(from_menu: bool) -> void:
	var b := _bytes()
	var j := JSON.stringify(Save.d)
	var real := Save.d
	var tag := "garden replay (%s)" % ("left from the menu" if from_menu else "finished")
	TutReplay.garden_tutorial()
	ok(TutReplay.active() and not is_same(Save.d, real) and FarmTutorial.active(),
			"%s: runs on a fresh farm and the tutorial is on" % tag)
	await _wait(func(): return _farm_up(main.current), 120.0)
	var home = main.current
	ok(home != null and Save.d["roster"][0]["uid"] == real["roster"][0]["uid"], "%s: your own Boki is on it" % tag)
	if from_menu:
		ok(not _links("home").has("Replay garden tutorial"), "%s: no replay links while replaying" % tag)
		for btn in Overlay.root.find_children("*", "Button", true, false):
			if String(btn.text).strip_edges() == "Leave the tutorial":
				btn.pressed.emit()
				break
	else:
		for s in FarmTutorial.steps():
			FarmTutorial.mark(String(s["id"]))
		ok(JSON.stringify(Save.d) != j, "%s: the sandbox changed its own copy" % tag)
		home.guide._poll()
	await _wait(func(): return not TutReplay.active(), 10.0)
	_handed_back(j, tag)
	await _wait(func(): return _is_home(main.current) and main.current != home, 120.0)
	ok(_is_home(main.current) and main.current != home, "%s: back on a rebuilt farm" % tag)
	_same(b, tag)
