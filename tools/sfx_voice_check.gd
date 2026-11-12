extends RefCounted
## --sfx-voice-check: a 30-Hunter fight stays under the voice cap with your own cues intact (docs/AUDIO.md, voice
## priority). One seeded bot match of trios at full size (Data.MATCH_PLAYERS: you on autoplay, two squadmates and
## nine rival squads, the 13 kit Hunters round the lobby), everyone within RING_M of you, for SECS of match time.
## Every frame counts the voices sounding (pool and loops, SfxVoices.sounding); every lost sound is tallied by
## whose it was (yours, your squad's, else the enemy's) and why (stolen, full, gap, stack: SfxVoices.cut).
## Asserts: the voices never pass Sfx.POOL + SfxVoices.LOOP_CAP, the pool was full at times (enemy sounds were
## cut), and none of your sounds lost its voice or was refused one. A "gap" or "stack" is the same sound again
## inside Sfx.MIN_GAP or the stacking window (merged, by design): counted, not failed; so is a squad sound losing
## its voice to yours, or refused one, with the pool full of the two of you (an enemy's never takes theirs).
## Then, the match stopped: one loop of yours and LOOP_CAP + 4 enemy ones; yours sounds and takes a place, the 5
## farthest pause, and once the 5 nearest stop the paused ones sound again.
## Headless on the Dummy driver; the match runs at 60 fps on its own clock, so voices end as in a real game.
##   godot --headless -- --sfx-voice-check [--voice-secs=40]

const SECS := 40.0
const SEED := 3011
const RING_M := 11.0                 # m: the squads stand round you this far out, so it is one brawl
const WHYS := [&"stolen", &"full", &"gap", &"stack"]
const POOL_LOST := [&"stolen", &"full"]   # what the priority decides (gap and stack merge a repeat)

var main: Node
var bad := 0
var lost := {"you": {}, "squad": {}, "enemy": {}}   # whose -> why -> count
var names := {}                     # "whose why sound" -> count
var peak := 0
var sum := 0
var frame_ms := PackedFloat32Array()   # wall ms per frame of the fight, for the frame-time line

func ok(cond: bool, what: String) -> void:
	print("SFXVOICE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	main = main_node
	var secs := SECS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--voice-secs="): secs = float(a.substr(13))
	Save.no_write = true
	Engine.max_fps = 60
	Sfx.voices.cut.connect(_on_cut)
	var m := await _brawl()
	var P: Hunter = m.player
	var start := m.time
	var t := Time.get_ticks_usec()
	while is_instance_valid(m) and m.time - start < secs:
		P.hp = P.max_hp
		await main.get_tree().process_frame
		frame_ms.append((Time.get_ticks_usec() - t) / 1000.0)
		t = Time.get_ticks_usec()
		var n := SfxVoices.sounding(Sfx.players, Sfx.loops)
		peak = maxi(peak, n)
		sum += n
	var cap := Sfx.POOL + SfxVoices.LOOP_CAP
	print("SFXVOICE %d Hunters, %d frames: voices peak %d, mean %.1f (cap %d), %d loops at the end" % [
		m.hunters.size(), frame_ms.size(), peak, float(sum) / maxi(frame_ms.size(), 1), cap, Sfx.loops.size()])
	frame_ms.sort()
	var ms_sum := 0.0
	for x in frame_ms: ms_sum += x
	print("SFXVOICE frame ms: mean %.2f, p99 %.2f" % [ms_sum / maxi(frame_ms.size(), 1),
		frame_ms[int(frame_ms.size() * 0.99)] if not frame_ms.is_empty() else 0.0])
	for whose: String in lost:
		var line := "SFXVOICE lost %-5s" % whose
		for why: StringName in WHYS:
			line += "  %s %4d" % [why, int(lost[whose].get(why, 0))]
		print(line)
	var top := names.keys()
	top.sort_custom(func(a, b): return names[a] > names[b])
	for whose: String in lost:
		for k: String in top.filter(func(x: String): return x.begins_with(whose)).slice(0, 4):
			print("SFXVOICE   %s x%d" % [k, names[k]])
	ok(m.hunters.size() == Data.MATCH_PLAYERS, "the fight has %d Hunters" % m.hunters.size())
	ok(peak <= cap, "voices stay under the cap: peak %d of %d" % [peak, cap])
	var enemy_lost := 0
	var yours_lost := 0
	for why in POOL_LOST:
		enemy_lost += int(lost["enemy"].get(why, 0))
		yours_lost += int(lost["you"].get(why, 0))
	ok(enemy_lost > 0, "the fight fills the pool: %d enemy sounds cut or refused" % enemy_lost)
	ok(yours_lost == 0, "your own sounds keep their voices: %d cut or refused" % yours_lost)
	m.set_process(false)
	await _far_loops()
	print("SFXVOICE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## You and two squadmates against nine rival trios, every Hunter on a kit, all round you.
func _brawl() -> Match:
	var archs: Array = Arch.ids()
	var o := Match.demo_opts()
	o.merge({"teams": 1, "squad": 3, "total": 3, "no_drop": true, "autoplay": true, "sim_keep": true, "seed": SEED,
		"arch": archs[0], "cls": Arch.weight(archs[0]), "weapon": Arch.signature(archs[0]),
		"mates": [1, 2].map(func(i): return {"name": Arch.name_of(archs[i], true), "arch": archs[i]})}, true)
	o.erase("demo_match")
	o.erase("fresh_t")
	var old = main.current
	Game.goto("match", o)
	var m: Match = null
	while m == null:
		await main.get_tree().process_frame
		var c = main.current
		if c != old and c is Match and (c as Match).is_processing() and (c as Match).hud != null:
			m = c
	m.player.max_hp *= 20.0
	var at := m.player.pos
	for i in range(3, Data.MATCH_PLAYERS):
		var arch: String = archs[i % archs.size()]
		m.make_bot(i / 3, at, [], {"name": Arch.name_of(arch, true), "arch": arch})
	for h: Hunter in m.hunters:
		var ang := TAU * float(h.team) / 10.0 + 0.3 * float(m.hunters.find(h) % 3)
		var spot := at if h.team == 0 else at + Vector3(cos(ang), 0, sin(ang)) * RING_M
		if h.team == 0 and h != m.player: spot += Vector3(1.5 * (m.hunters.find(h) % 3), 0, 1.0)
		h.teleport(Vector3(spot.x, m.world.ground_at(spot.x, spot.z), spot.z))
		if h.kin: (h.kin as Kin).teleport(h.pos + Vector3(1.0, 0, 0.7))
	return m

func _far_loops() -> void:
	Sfx.reset_scene_audio(0.0)
	Sfx.loop_start("voicecheck_you", "revive_hum")
	var keys := []
	for i in SfxVoices.LOOP_CAP + 4:
		keys.append("voicecheck%d" % i)
		Sfx.loop_start(keys[i], "revive_hum", Sfx.listener + Vector3(3.0 + i, 0, 0))
	var paused := func(k): return (Sfx.loops[k]["p"] as AudioStreamPlayer).stream_paused
	var far_paused := keys.filter(paused)
	ok(far_paused == keys.slice(SfxVoices.LOOP_CAP - 1), "the farthest loops pause first: %s" % [far_paused])
	ok(not paused.call("voicecheck_you"), "your loop sounds past the cap")
	for k in keys.slice(0, 5):
		Sfx.loop_stop(k)
	await main.get_tree().create_timer(0.3).timeout
	ok(keys.slice(5).filter(paused).is_empty(), "with room again the paused loops sound")
	Sfx.reset_scene_audio(0.0)

func _on_cut(sname: String, rank: float, why: StringName) -> void:
	var whose := "enemy"
	if rank == SfxVoices.YOU:
		whose = "you"
	elif rank == SfxVoices.SQUAD:
		whose = "squad"
	lost[whose][why] = int(lost[whose].get(why, 0)) + 1
	var k := "%s %s %s" % [whose, why, sname]
	names[k] = int(names.get(k, 0)) + 1
