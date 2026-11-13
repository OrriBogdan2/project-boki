extends RefCounted
## --soundtrack-check: the music settings (Soundtrack, content/music/soundtracks.json). Classic Adventure
## is the default and every style has a track that exists for every place; the first score hands each
## place its own music back (the garden's islands, the layered stems); a hand-picked track wins over the
## style; Shuffle keeps one style through a scene and rolls again on the next; a pick in the settings
## switches the title's music at once. In headless matches the classic tracks follow the moment (calm,
## fight, boss, last moments; training has its own), and the garden plays the classic garden track.

var main: Node
var fails := 0
var n := 0
const DT := 1.0 / 60.0
const SHUFFLE_ROLLS := 40      # scene changes: with three styles, every style turns up long before this

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	printerr("SOUNDTRACK %-58s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	_data()
	_picks()
	_shuffle()
	await _title()
	await _match()
	await _training()
	await _garden()
	print("SOUNDTRACK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func pick(style: String, hand := {}) -> void:
	Settings.set_v("soundtrack", style, false)
	Settings.set_v("music_shuffle", false, false)
	for pl in Soundtrack.places():
		Settings.set_v(Soundtrack.HAND_PICK[pl["id"]], String(hand.get(pl["id"], "")), false)

func _data() -> void:
	ok("Classic Adventure is the default", String(Settings.DEFAULTS["soundtrack"]) == "classic"
		and String(Soundtrack.data()["default"]) == "classic")
	var missing := []
	for sid in Soundtrack.styles():
		for pl in Soundtrack.places():
			var t: Array = Soundtrack.styles()[sid]["tracks"].get(pl["id"], ["", ""])
			if not ResourceLoader.exists("res://audio/music_%s.ogg" % t[0]) or String(t[1]) == "":
				missing.append("%s/%s" % [sid, pl["id"]])
	ok("every style names an existing track for every place", missing.is_empty(), str(missing))
	ok("three styles to pick from", Soundtrack.styles().size() >= 3, str(Soundtrack.styles().keys()))
	var opts := Soundtrack.options("boss")
	ok("a place's picker: the soundtrack's own, then one track per style",
		opts.size() == Soundtrack.styles().size() + 1 and opts[0][0] == "", str(opts))

func _picks() -> void:
	pick("classic")
	ok("classic: the menu plays Hearthlight", Soundtrack.track("menu", "title") == "classic_menu")
	ok("classic: the garden plays its one track on any island", Soundtrack.track("base", "orchard") == "classic_base")
	ok("classic: an expedition runs single tracks", not Soundtrack.layered())
	pick("isles")
	ok("first score: places keep their own music", Soundtrack.track("menu", "title") == "title"
		and Soundtrack.track("base", "home_night") == "home_night" and Soundtrack.track("victory", "title") == "title")
	ok("first score: an expedition keeps its layered stems", Soundtrack.layered())
	pick("isles", {"boss": "lofi_boss"})
	ok("a hand pick wins over the style", Soundtrack.picked("boss") == "lofi_boss" and not Soundtrack.layered())
	pick("classic", {"menu": "no_such_track"})
	ok("a hand pick with no file falls back to the style", Soundtrack.track("menu", "title") == "classic_menu")
	pick("no_such_style")
	ok("an unknown style plays the default", Soundtrack.track("menu", "title") == "classic_menu")
	var had: Array = Save.d.get("music", []).duplicate()
	Sfx.play_music("classic_menu", 0.1)
	ok("a soundtrack track doesn't join the house's record list", Save.d.get("music", []) == had)

func _shuffle() -> void:
	pick("classic")
	Settings.set_v("music_shuffle", true, false)
	var seen := {}
	var steady := true
	for i in SHUFFLE_ROLLS:
		Soundtrack.track("menu", "title")      # another scene in between: the next match rolls again
		var s := Soundtrack.style_for("calm")
		steady = steady and Soundtrack.style_for("boss") == s and Soundtrack.style_for("final") == s
		seen[s] = true
	ok("shuffle: one expedition keeps one style", steady)
	ok("shuffle: every style turns up", seen.size() == Soundtrack.styles().size(), str(seen.keys()))
	pick("classic", {"calm": "lofi_calm"})
	Settings.set_v("music_shuffle", true, false)
	ok("shuffle: a hand pick still wins", Soundtrack.picked("calm") == "lofi_calm")
	pick("classic")

func go(screen: String, opts := {}) -> Node:
	Game.goto(screen, opts)
	for i in 6:
		await main.get_tree().process_frame
	return main.current

func _title() -> void:
	await go("title")
	ok("title: Hearthlight plays", Sfx.music_name == "classic_menu", Sfx.music_name)
	Settings.set_v("soundtrack", "lofi", false)
	Soundtrack.replay()
	ok("title: a new soundtrack is heard at once", Sfx.music_name == "lofi_menu", Sfx.music_name)
	pick("classic")

func start_match(opts: Dictionary) -> Match:
	opts["autoplay"] = true
	var m: Match = await go("match", opts)
	m.set_process(false)
	return m

## Runs the match and its music for `secs`; with `music_only` just the music reads it (a state the
## match itself would undo, like a boss fight with the player outside any arena, holds).
func tick(m: Match, secs: float, music_only := false) -> void:
	var t := 0.0
	while t < secs:
		if not music_only: m.step(DT)
		m.music_dir.tick(m, DT)
		t += DT

func _match() -> void:
	var m := await start_match({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	ok("match: single tracks, no stems", m.music_dir.single and Sfx.layers.is_empty())
	ok("match: exploring plays Wayfarer's Road", Sfx.music_name == "classic_calm", Sfx.music_name)
	m.player.dmg_done += 10.0
	tick(m, 1.5)
	ok("match: a fight brings Steel at Dusk", Sfx.music_name == "classic_tense", Sfx.music_name)
	if m.lairs:
		m.lairs.music_on = true
		tick(m, 1.0, true)
		ok("match: a woken boss brings its track", Sfx.music_name == "classic_boss", Sfx.music_name)
		m.lairs.music_on = false
	m.player.extract_prog = 0.5
	tick(m, 1.0)
	ok("match: getting out brings the last-moments track", Sfx.music_name == "classic_final", Sfx.music_name)
	Settings.set_v("track_final", "lofi_final", false)
	tick(m, 1.0)
	ok("match: a pick made mid-run is heard on the next check", Sfx.music_name == "lofi_final", Sfx.music_name)
	pick("classic")
	m.player.extract_prog = 0.0

func _training() -> void:
	var opts := {"training": true, "practice": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242,
		"no_drop": true}
	var m := await start_match(opts.duplicate())
	tick(m, 1.0)
	ok("training: Practice Yard plays", Sfx.music_name == "classic_training", Sfx.music_name)
	pick("isles")
	m = await start_match(opts.duplicate())
	ok("training, first score: the layered stems as before", not m.music_dir.single and Sfx.layers.size() > 0)
	pick("classic")

func _garden() -> void:
	await go("home")
	for i in 90:
		await main.get_tree().process_frame
	ok("garden: Furrow and Hearth plays", Sfx.music_name == "classic_base", Sfx.music_name)
	ok("victory: a run that got out plays Homeward Bells", Soundtrack.track("victory", "title") == "classic_victory")
