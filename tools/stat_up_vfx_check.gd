extends RefCounted
## --stat-up-vfx-check: the glint over a Boki at home when Power, Guard, Speed or Focus rises (StatGlint).
##   1. a Boki seen for the first time shows nothing
##   2. each stat fires one glint with its own icon and colour (the four colours differ)
##   3. two stats within StatGlint.MERGE_S share one glint; a gain after it starts a second one
##   4. a capped stat (the gain clamps to 0) shows nothing; a sleeping Boki shows nothing and waking
##      doesn't replay it
##   5. clicking a glint's icon opens that Boki's Training tab with the risen stats marked old -> new for
##      StatGlint.LIT_S; with two glints up each opens its own Boki; a click away from the icons opens nothing
## Also (StatMeaning): the first rise of each stat on a save puts its one line on the tip strip, once, at most
## one a minute, never during a garden game; a line held back shows at that stat's next rise.
## --stat-up-vfx-shots --shots-dir=<dir>: two Boki at the Training post, one striking the dummy (+2 Power),
## one spinning beside it (+1 Speed and +1 Focus, merged), three frames as the glints rise. Never touches the
## real save.

class FakeGame:
	var run := 1      # a garden game under way

	func tick(_dt: float) -> void:
		pass

var bad := 0
var main: Node
var home

func ok(cond: bool, what: String) -> void:
	print("STATUP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node, mode: String = "check") -> void:
	main = m
	Save.no_write = true
	Save.d = _new_save()
	FarmTutorial.skip()
	home = await main._hb_home()
	for i in 600:
		if home.player != null and home.stat_glint != null and home.kins.size() == 2:
			break
		await main.get_tree().process_frame
	home.day_t = 0.5
	for k in home.kins:
		k["busy"] = true      # (held by the check: no wandering off, napping or going indoors)
	await _frames(2)
	if mode == "shots":
		await _shots()
		return
	var glint: StatGlint = home.stat_glint
	var a: Dictionary = home.kins[0]
	var rec: Dictionary = a["rec"]
	ok(glint != null and glint.glints.is_empty(), "two Boki arrive and nothing glints")
	# 2. each stat on its own
	var cols := {}
	for s in Care.STATS:
		await _settle(glint)
		Care.add_stat(rec, s, 1)
		await _frames(2)
		var g: Dictionary = _only(glint)
		var shown: Array = g.get("stats", [])
		var col: Color = Care.STATS[s]["col"]
		ok(shown == [s] and is_same(g["k"], a) and StatGlint.ICON.has(s),
			"+1 %s: one glint on that Boki, icon %s in %s" % [s, StatGlint.ICON.get(s, "?"), col.to_html(false)])
		cols[col.to_html()] = true
	ok(cols.size() == 4, "the four stats glint in four different colours")
	await _tips(glint, rec)
	# 3. merging
	await _settle(glint)
	Care.add_stat(rec, "power", 1)
	Care.add_stat(rec, "guard", 2)
	await _frames(2)
	ok(glint.glints.size() == 1 and _only(glint)["stats"] == ["power", "guard"],
		"two stats in one frame: one glint, two icons")
	await main.get_tree().create_timer(StatGlint.MERGE_S * 0.6).timeout
	Care.add_stat(rec, "speed", 1)
	await _frames(2)
	ok(glint.glints.size() == 1 and _only(glint)["stats"] == ["power", "guard", "speed"],
		"a gain %.1f s later joins it" % (StatGlint.MERGE_S * 0.6))
	await main.get_tree().create_timer(StatGlint.MERGE_S * 0.6).timeout
	Care.add_stat(rec, "focus", 1)
	await _frames(2)
	ok(glint.glints.size() == 2 and glint.glints[1]["stats"] == ["focus"],
		"a gain past %.1f s starts a second glint" % StatGlint.MERGE_S)
	# 4. capped, asleep
	await _settle(glint)
	rec["stats"]["power"] = Care.stat_cap(rec)
	await _frames(2)
	await _settle(glint)
	var gained := Care.add_stat(rec, "power", 3)
	await _frames(2)
	ok(gained == 0 and glint.glints.is_empty(),
		"Power at its cap (%d): the gain is 0 and nothing glints" % Care.stat_cap(rec))
	a["nap_t"] = 30.0
	Care.add_stat(rec, "guard", 1)
	await _frames(2)
	ok(glint.glints.is_empty(), "asleep: +1 Guard shows nothing")
	a["nap_t"] = 0.0
	await _frames(2)
	ok(glint.glints.is_empty(), "and it doesn't show when it wakes")
	a["nap_t"] = 0.0
	await _clicks(glint)
	print("STATUP DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## StatMeaning: the tip strip says what a stat does at its first rise on the save, and only then.
func _tips(glint: StatGlint, rec: Dictionary) -> void:
	var lane := MsgLane.of(home.root_ui)
	var seen: Dictionary = Save.d["tutorial"].get_or_add("stat_tips", {})
	var want: Array = []
	for s in Care.STATS:
		ok(String(Care.STATS[s]["means"]).begins_with(String(Care.STATS[s]["name"]) + ":"), "%s has its line" % s)
		want.append(Care.STATS[s]["means"])
	ok(seen == {"power": true} and lane.texts() == [want[0]], "the first rise (Power) said its line, and only that one")
	await _settle(glint)
	Care.add_stat(rec, "power", 1)
	await _frames(2)
	ok(lane.texts() == [want[0]], "Power again: not told twice")
	Care.add_stat(rec, "guard", 1)
	await _frames(2)
	ok(not seen.has("guard") and lane.texts() == [want[0]], "Guard within a minute of the last tip: held back")
	await _settle(glint)
	StatMeaning.last_s -= StatMeaning.GAP_S
	home.games = [FakeGame.new()]
	Care.add_stat(rec, "guard", 1)
	await _frames(2)
	ok(not seen.has("guard"), "a garden game under way: held back")
	home.games = []
	await _settle(glint)
	Care.add_stat(rec, "guard", 1)
	await _frames(2)
	ok(seen.has("guard") and lane.texts().has(want[1]), "a minute on and no game: the Guard line shows")
	for s in ["speed", "focus"]:
		await _settle(glint)
		StatMeaning.last_s -= StatMeaning.GAP_S
		Care.add_stat(rec, s, 1)
		await _frames(2)
		ok(seen.has(s) and lane.texts().has(Care.STATS[s]["means"]), "%s: its line shows at its first rise" % s)
	ok(seen.size() == 4, "each stat's line is marked seen: four in all")

## 5. a click on each Boki's glint icon opens its own card on the Training tab, the risen stat marked.
func _clicks(glint: StatGlint) -> void:
	await _settle(glint)
	var b: Dictionary = home.kins[1]
	Care.add_stat(home.kins[0]["rec"], "guard", 1)
	Care.add_stat(b["rec"], "speed", 2)
	await _frames(2)
	ok(glint.glints.size() == 2, "a glint over each Boki")
	var cam: Camera3D = home.get_viewport().get_camera_3d()
	ok(not glint.open_card(Vector2(-500, -500)) and home.panel_open == "", "a click away from the icons opens nothing")
	for k in [b, home.kins[0]]:
		var rec: Dictionary = k["rec"]
		var g: Dictionary = glint.glints.filter(func(x): return is_same(x["k"], k))[0]
		var stat: String = g["stats"][0]
		var spot: Vector2 = glint._spots(g, cam)[0]
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = spot
		home._unhandled_input(ev)
		var lit: Dictionary = glint.lit_for(rec)
		var now := int(rec["stats"][stat])
		ok(home.panel_open.begins_with(String(rec["name"])) and home.kin_tab == "Training",
			"%s: clicking its %s glint opens its Training tab" % [rec["name"], stat])
		var was: int = lit.get("from", {}).get(stat, -1)
		ok(was == now - (2 if stat == "speed" else 1) and float(lit.get("left", 0.0)) <= StatGlint.LIT_S,
			"%s: %s is marked %d -> %d" % [rec["name"], stat, was, now])
		var rows: Array = home.panel_host.find_children("Lit_*", "PanelContainer", true, false)
		ok(rows.map(func(n): return String(n.name)) == ["Lit_" + stat],
			"%s: exactly the %s row is marked on the card" % [rec["name"], stat])
		home._close_panel()
		await _frames(2)
	await main.get_tree().create_timer(StatGlint.LIT_S + 0.1).timeout
	var none: bool = glint.lit_for(home.kins[0]["rec"]).is_empty() and glint.lit_for(b["rec"]).is_empty()
	ok(none, "the marks end after %.0f s" % StatGlint.LIT_S)

func _new_save() -> Dictionary:
	var d := Save.fresh()
	for i in 2:
		var k := Save.new_kin(["zapple", "puddlet"][i], ["Pip", "Fen"][i])
		k["level"] = 5
		Care.ensure(k)
		for n in ["food", "energy", "clean", "joy"]: k["needs"][n] = 80.0
		d["roster"].append(k)
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	var lay := HomeLayout.ensure(d)
	var at := HomeLayout.LANDING
	var post := {"u": HomeLayout._next_uid(lay), "id": "training_post", "x": int(at.x) - 4, "z": int(at.z) - 7, "r": 0}
	lay["deco"].append(post)
	d["tutorial"]["home"] = true      # (after the island is made: no Welcome home panel over the shots)
	return d

## n frames. Two after a gain: a timer resumes after the frame's _process, so StatGlint sees it the next one.
func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

## Until every glint has run out.
func _settle(glint: StatGlint) -> void:
	for i in 600:
		if glint.glints.is_empty():
			return
		await main.get_tree().process_frame

func _only(glint: StatGlint) -> Dictionary:
	return glint.glints[0] if glint.glints.size() == 1 else {}

# ------------------------------------------------------------------ shots
func _shots() -> void:
	var dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots-dir="): dir = arg.substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	if main.fade:
		main.fade.reveal(0.05)
	var at: Vector3 = home.YARD_KIN
	var striker: Dictionary = home.kins[0]
	var spinner: Dictionary = home.kins[1]
	_put(striker, at)
	_put(spinner, at + Vector3(1.3, 0, 0.6))
	home.ppos = at + Vector3(3.2, 0, 1.0)      # (the player off to the side, out of the way)
	home.player.position = home.ppos
	home.cam.zoom_to = 0.5
	home.cam.zoom = 0.5
	home.cam.snap(at + Vector3(0.6, 0, 0.4))
	await main.get_tree().create_timer(0.8).timeout
	home._train_anim(striker, "power", "great")
	var spin: Tween = home.create_tween()
	spin.tween_property(spinner["node"], "rotation:y", (spinner["node"] as Node3D).rotation.y + TAU, 0.6)
	await main.get_tree().create_timer(0.15).timeout
	Care.add_stat(striker["rec"], "power", 2)
	Care.add_stat(spinner["rec"], "speed", 1)
	await main.get_tree().create_timer(0.2).timeout
	Care.add_stat(spinner["rec"], "focus", 1)
	for i in 3:
		await main.get_tree().create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		var file := dir.path_join("stat_up_%d.png" % (i + 1))
		main.get_viewport().get_texture().get_image().save_png(file)
		print("STATUP SHOT %s glints=%d" % [file, home.stat_glint.glints.size()])
	main.get_tree().quit(0)

func _put(k: Dictionary, at: Vector3) -> void:
	k["pos"] = at
	k["goal"] = at
	k["t"] = 30.0
	(k["node"] as Node3D).position = at
