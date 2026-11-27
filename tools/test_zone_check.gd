extends RefCounted
## --test-zone-check: the admin lock (AdminGate) and the owner's Test Zone (TestZone).
##   1. a release build (not debug, not the web owner) without the dev key gets no admin; a wrong key, an empty
##      file or a key with only the hash's text get none either; the right key (here a made-up one against its own
##      hash) opens it, with a trailing newline too; a debug build or the web owner always may.
##      With BOKI_DEV_KEY_FILE set (the owner's real key), that file at user://dev.key matches the hash in the code.
##   2. the Test Zone starts the sandbox map; Admin tools there lead to its page, which lists every Hunter and
##      monster kind and a searchable Boki list; every Hunter can be picked, every monster spawns in front of you
##      (and lives a few frames), a Boki partner of another species comes along, god mode toggles, the dummies
##      reset. Run headless; grep the output for SCRIPT ERROR as well.
##   3. a clean HUD (the owner's "UI overload" report): on entering, and with the Practice tools switched on, at
##      1920x1080 and 2560x1440, no HUD element overlaps another and none covers your Hunter (TestZoneShots);
##      the tools (key line, DPS meter, bottom bar, drills, guide banner) start off and come on from the page.

const OPTS_SEED := 4242
const Shots := preload("res://tools/test_zone_shots.gd")

var bad := 0
var main: Node
var tree: SceneTree


func ok(cond: bool, what: String) -> void:
	print("TESTZONE %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(mn: Node) -> void:
	main = mn
	tree = mn.get_tree()
	_gate()
	await _zone()
	print("TESTZONE DONE, failures: ", bad)
	tree.quit(1 if bad > 0 else 0)


func _gate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = OPTS_SEED
	var key := "%016x%016x" % [rng.randi(), rng.randi()]
	var sha := key.sha256_text()
	ok(not AdminGate.allows(false, false, ""), "release build, no key file: no admin")
	ok(not AdminGate.allows(false, false, "not-the-key"), "release build, a wrong key: no admin")
	ok(not AdminGate.allows(false, false, "  \n"), "release build, an empty key file: no admin")
	ok(not AdminGate.allows(false, false, AdminGate.KEY_SHA256), "the hash itself is not a key")
	ok(not AdminGate.allows(false, false, "wrong", sha), "a made-up key's hash refuses another key")
	ok(AdminGate.allows(false, false, key, sha), "release build with the matching key: admin")
	ok(AdminGate.allows(false, false, key + "\n", sha), "the key file may end in a newline")
	ok(AdminGate.allows(true, false, ""), "a debug build (editor, dev runs): admin")
	ok(AdminGate.allows(false, true, ""), "the web artifact's owner: admin")
	var real := OS.get_environment("BOKI_DEV_KEY_FILE")
	if real == "":
		print("TESTZONE SKIP the owner's real key (set BOKI_DEV_KEY_FILE to its path)")
		return
	var f := FileAccess.open(AdminGate.KEY_PATH, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(real))
	f.close()
	var stored := FileAccess.get_file_as_string(AdminGate.KEY_PATH)
	var said := "the owner's key at %s opens admin in a release build" % AdminGate.KEY_PATH
	ok(AdminGate.allows(false, false, stored), said)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AdminGate.KEY_PATH))


func _zone() -> void:
	Save.no_write = true
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	m.start(TestZone.opts())
	for i in 5:
		await tree.process_frame
	var was: Node = main.get("current")
	main.set("current", m)
	ok(TestZone.current() == m and m.arena != null, "the Test Zone runs on the sandbox map with its practice tools")
	await _clean_hud(m)
	Overlay.open_admin()
	ok(_buttons().has("Test Zone tools"), "Admin tools in the zone lead to its page")
	Overlay.open_test_zone()
	await tree.process_frame
	var labels := _buttons()
	var all_heroes: bool = Arch.ids().all(func(a): return labels.has(HeroTitle.base_name(a)))
	ok(Arch.ids().size() >= 13 and all_heroes, "every Hunter is on the page (%d)" % Arch.ids().size())
	var all_mobs: bool = Data.MOBS.values().all(func(mb): return labels.has(String(mb["name"])))
	ok(all_mobs, "every monster kind is on the page (%d)" % Data.MOBS.size())
	var search: LineEdit = Overlay.host.find_children("*", "LineEdit", true, false)[0]
	search.text_changed.emit("zapp")
	await tree.process_frame
	var found := _buttons()
	ok(found.has(String(Data.KIN["zapple"]["name"])) and not found.has("None"), "the Boki search narrows the list")
	for a in Arch.ids():
		m.arena.set_arch(String(a))
		await tree.process_frame
		if m.player.arch != a:
			ok(false, "picking %s" % a)
	ok(true, "picked each of the %d Hunters in turn" % Arch.ids().size())
	var spawned: Array = []
	for kind in Data.MOBS:
		spawned.append(TestZone.spawn_mob(m, String(kind)))
	for i in 10:
		await tree.process_frame
	var ahead: bool = spawned.all(func(mb): return is_instance_valid(mb) and mb.pos.distance_to(m.player.pos) < 14.0)
	ok(spawned.size() == Data.MOBS.size() and ahead, "every monster kind spawns near you (%d)" % spawned.size())
	var sp := "cindle" if Data.KIN.has("cindle") else String(Data.KIN.keys()[0])
	m.arena.set_kin(sp)
	ok(m.player.kin != null and String(m.player.kin.species) == sp, "a %s partner comes along" % sp)
	var god: CheckButton = Overlay.host.find_children("*", "CheckButton", true, false)[0]
	god.button_pressed = true
	ok(Game.god, "god mode turns on from the page")
	god.button_pressed = false
	var dm: Hunter = m.arena.dummies[0]["h"]
	dm.hp = 1.0
	m.arena.reset()
	ok(dm.hp == Arena.DUMMY_HP, "reset heals the dummies")
	Overlay.close()
	await _reserved(m, true)  # (last: the Drills run moves you)
	m.queue_free()
	await tree.process_frame
	var grounds := Match.new()
	main.add_child(grounds)
	grounds.start(Match.arena_opts())
	main.set("current", grounds)
	await _reserved(grounds, false)
	grounds.queue_free()
	main.set("current", was)
	await tree.process_frame


## The Test Zone's HUD at the owner's two screen sizes: tools off (as entered) and on, nothing crowded.
func _clean_hud(m: Match) -> void:
	var pr := Practice.of(m)
	var shown: bool = m.arena.tools or pr.bar.visible or m.arena.hint.visible or m.arena.meter.visible
	ok(not shown, "the practice tools start off")
	var drill_or_pad: bool = pr.get_node_or_null(KitDrill.NAME) != null or m.duel_pad != Vector3.INF
	ok(not drill_or_pad, "no kit drill banner and no duel pad on entering")
	for size: Vector2i in Shots.SIZES:
		main.get_window().size = size
		for on in [false, true]:
			m.arena.set_tools(on)
			var found: Array = await Shots.judge(tree, m)
			for f in found:
				print("TESTZONE   overlap %s: %s" % [size, f])
			ok(found.is_empty(), "no HUD overlap at %dx%d, practice tools %s" % [size.x, size.y, "on" if on else "off"])
			var label := "the tools are %s at %dx%d" % ["shown" if on else "hidden", size.x, size.y]
			ok(pr.bar.visible == on and m.arena.hint.visible == on, label)
	m.arena.set_tools(false)


## The owner's 11-26 reports: with the frame-rate readout on, no popup, panel or toast of the practice stations covers
## it or the minimap (and the pairs were really scanned: both rects and the popup were on screen).
func _reserved(m: Match, test_zone: bool) -> void:
	Settings.set_v("show_fps", Shots.FPS_MODE, false)
	var where := "Test Zone" if test_zone else "Training Grounds"
	for size: Vector2i in Shots.SIZES:
		main.get_window().size = size
		m.arena.set_tools(true)
		for id: String in Shots.STATIONS:
			if id == "drills" and Practice.of(m).drills == null:
				continue
			Shots.station(m, id, true)
			await Shots.judge(tree, m)
			var gs := Shots.groups(m)
			var what := "%s, %s popup, %dx%d" % [where, id, size.x, size.y]
			var scanned: bool = gs.has(Shots.FPS) and gs.has("drawn minimap")
			var popup: Array = Shots.popups(gs).filter(func(g: String): return g.begins_with(Shots.STATION_GROUP[id]))
			ok(scanned and not popup.is_empty(), "scanned: fps counter, minimap and the popup (%s)" % what)
			for pr: Array in Shots.pairs(gs):
				if pr[2]:
					print("TESTZONE   overlap %s vs %s" % [pr[0], pr[1]])
				ok(not pr[2], "%s keeps clear of %s (%s)" % [pr[1], pr[0], what])
			Shots.station(m, id, false)


func _buttons() -> Array:
	var out: Array = []
	for b in Overlay.host.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion():
			out.append(String(b.text).strip_edges())
	return out
