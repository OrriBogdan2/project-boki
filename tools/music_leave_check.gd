extends RefCounted
## --music-leave-check: the music and ambience follow the screen. Training area -> duel room -> back
## out, a normal match -> title, and the farm -> title: after each change only that place's score is
## audible (no stem of the match's layered score, no abyss / ruins bed, and no stray player on the
## Music or Ambience bus left playing above silence). Inspects Sfx's players' `playing` and volume_db.

var main: Node
var fails := 0
var n := 0
const DT := 1.0 / 60.0
const AUDIBLE_DB := -45.0      # a player quieter than this (and fading) isn't heard
const SETTLE_SPEED := 4.0      # time scale while settling
const SETTLE := 6.0            # seconds: longer than the slowest crossfade (home 2.5s, layers 3s)

func ok(name: String, cond: bool, info := "") -> void:
	n += 1
	printerr("MUSICLEAVE %-52s %s  %s" % [name, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

## Every AudioStreamPlayer Sfx owns on the Music / Ambience buses that is playing above AUDIBLE_DB:
## {label: volume_db}. Labels: "music[i]" (the two crossfading single tracks), "layer:stem", "amb",
## "amb_layer:name", "stray" for anything else (a player no field points at).
func audible() -> Dictionary:
	var out := {}
	var known := {}
	for i in Sfx.music.size(): known[Sfx.music[i]] = "music[%d]" % i
	known[Sfx.amb] = "amb"
	for st in Sfx.layers: known[Sfx.layers[st]] = "layer:%s" % st
	for nm in Sfx.amb_layers: known[Sfx.amb_layers[nm]["p"]] = "amb_layer:%s" % nm
	for c in Sfx.get_children():
		if not (c is AudioStreamPlayer):
			continue
		var p: AudioStreamPlayer = c
		if String(p.bus) != "Music" and String(p.bus) != "Ambience":
			continue
		if not p.playing or p.volume_db <= AUDIBLE_DB or p.is_queued_for_deletion():
			continue
		out[known.get(p, "stray:%s" % p.name)] = snappedf(p.volume_db, 0.1)
	return out

func settle(secs := SETTLE) -> void:
	Engine.time_scale = SETTLE_SPEED      # the fades are tweens on game time: the same game seconds in less wall time
	await main.get_tree().create_timer(secs).timeout
	Engine.time_scale = 1.0

func step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT); t += DT

func run(main_node: Node) -> void:
	main = main_node
	Save.d["music"] = Save.d.get("music", [])
	await _training_duel_leave()
	await _match_to_title()
	await _farm_to_title()
	print("MUSICLEAVE DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Opens a screen the way the game does (Game.goto) and waits for it to be up.
func go(screen: String, opts := {}) -> Node:
	Game.goto(screen, opts)
	for i in 6:
		await main.get_tree().process_frame
	return main.current

func start_match(opts: Dictionary, live := false) -> Match:
	if live:
		# the real way in: the loading screen, then the match running on its own for a while
		var m0: Match = await go("match", opts)
		while not is_instance_valid(m0) or not m0.is_inside_tree() or m0.player == null or main.get("_ld") != null and is_instance_valid(main.get("_ld")):
			await main.get_tree().process_frame
			m0 = main.current
		return m0
	opts["autoplay"] = true
	var m: Match = await go("match", opts)
	m.set_process(false)
	return m

func _training_duel_leave() -> void:
	var m := await start_match({"training": true, "practice": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	step(m, 3.0)
	await settle(4.0)
	var a := audible()
	var tag := str(a)
	ok("training: the layered score plays, nothing else", Sfx.music_name == "match" and Sfx.layers.size() > 0 and not a.is_empty() and a.keys().all(func(k): return String(k).begins_with("layer:") or String(k).begins_with("amb")), tag)
	var training_music := a.keys().filter(func(k): return String(k).begins_with("layer:") or String(k).begins_with("music"))
	# into the duel room (what the pad does), and a short duel
	var d: Match = await start_match(Match.duel_opts(), true)
	ok("duel: a duel match is up", d.duel != null and d.duel.bot != null and d != m)
	await settle(8.0)
	a = audible()
	ok("duel: the score is the training area's, one set of stems", a.keys().filter(func(k): return String(k).begins_with("layer:") or String(k).begins_with("music")).size() == training_music.size(), str(a))
	# leaving the room (Esc > Leave: the match finishes and the game goes on to the farm)
	d.result = {"extracted": true, "why": "left"}
	d._finish()
	for i in 6: await main.get_tree().process_frame
	await settle()
	a = audible()
	ok("leave duel: no stem of the match score is left", Sfx.layers.is_empty() and a.keys().all(func(k): return not String(k).begins_with("layer:")), str(a))
	ok("leave duel: only the farm's own music + ambience", Sfx.music_name.begins_with("home") or Sfx.music_name in ["orchard", "meadow", "summit"], "music '%s' %s" % [Sfx.music_name, str(a)])
	ok("leave duel: no match ambience beds (abyss / ruins)", Sfx.amb_layers.is_empty() and a.keys().all(func(k): return not String(k).begins_with("amb_layer")), str(a))
	ok("leave duel: nothing stray on the Music bus", a.keys().all(func(k): return not String(k).begins_with("stray")), str(a))
	await go("title")
	await settle()
	_title_clean("duel -> farm -> title")

func _title_clean(what: String) -> void:
	var a := audible()
	ok("%s: music is the title track" % what, Sfx.music_name == "title" and Sfx.layers.is_empty(), "music '%s' layers %d" % [Sfx.music_name, Sfx.layers.size()])
	ok("%s: no match layers, no amb layers" % what, Sfx.layers.is_empty() and Sfx.amb_layers.is_empty() and a.keys().all(func(k): return not String(k).begins_with("layer:") and not String(k).begins_with("amb_layer")), str(a))
	var music_players := a.keys().filter(func(k): return String(k).begins_with("music") or String(k).begins_with("stray") or String(k).begins_with("layer:"))
	ok("%s: exactly one music player is audible" % what, music_players.size() == 1, str(a))

func _match_to_title() -> void:
	var m := await start_match({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	# stand at an edge so the abyss bed and a fight stem come up
	var P: Hunter = m.player
	var edge := Vector3.INF
	for r in 40:
		for k in 24:
			var q: Vector3 = P.pos + Vector3(cos(TAU * k / 24.0), 0, sin(TAU * k / 24.0)) * (r + 2.0)
			if m.world.is_void(q.x, q.z):
				edge = q; break
		if edge != Vector3.INF: break
	P.dmg_done += 10.0
	step(m, 8.0)
	Sfx.amb_layer("abyss", 1.0)     # (as music_dir does at an edge)
	Sfx.amb_layer("ruins", 1.0)
	step(m, 4.0)
	await settle(5.0)
	var a := audible()
	ok("match: layers and ambience beds are up (setup sane)", Sfx.layers.size() > 0 and Sfx.amb_layers.size() > 0 and a.size() >= 3, str(a))
	await go("title")
	# a fade, not a cut: a moment after the change the old score is still ringing out, softly
	ok("match -> title: the score fades out rather than cutting", audible().size() >= 3, str(audible()))
	await settle()
	_title_clean("match -> title")

func _farm_to_title() -> void:
	await go("home")
	await settle(3.0)
	await go("title")
	await settle()
	_title_clean("farm -> title")
