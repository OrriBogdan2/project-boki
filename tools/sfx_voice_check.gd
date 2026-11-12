extends RefCounted
## --sfx-voice-check: a 30-Hunter fight stays under the voice cap with your own cues intact (docs/AUDIO.md, voice
## priority). One seeded bot match of trios at full size (Data.MATCH_PLAYERS: you on autoplay, two squadmates and
## nine rival squads, the 13 kit Hunters round the lobby), everyone within RING_M of you, for SECS of match time.
## Every frame counts the voices sounding (pool and loops, SfxVoices.sounding); every lost sound is tallied by
## whose it was (own: yours or your squad's, else the enemy's) and why (stolen, full, gap, stack: SfxVoices.cut).
## Asserts: the voices never pass Sfx.POOL + SfxVoices.LOOP_CAP, the pool was full at times (enemy sounds were
## cut), and no own sound lost its voice or was refused one. A "gap" or "stack" is the same sound again inside
## Sfx.MIN_GAP or the stacking window (merged, by design): counted, not failed.
## Headless on the Dummy driver; the match runs at 60 fps on its own clock, so voices end as in a real game.
##   godot --headless -- --sfx-voice-check [--voice-secs=40]

const SECS := 40.0
const SEED := 3011
const RING_M := 11.0                 # m: the squads stand round you this far out, so it is one brawl
const WHYS := [&"stolen", &"full", &"gap", &"stack"]
const POOL_LOST := [&"stolen", &"full"]   # what the priority decides (gap and stack merge a repeat)

var main: Node
var bad := 0
var lost := {"own": {}, "enemy": {}}   # whose -> why -> count
var names := {}                     # "whose why sound" -> count
var peak := 0
var sum := 0
var frames := 0

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
	while is_instance_valid(m) and m.time - start < secs:
		P.hp = P.max_hp
		await main.get_tree().process_frame
		var n := SfxVoices.sounding(Sfx.players, Sfx.loops)
		peak = maxi(peak, n)
		sum += n
		frames += 1
	var cap := Sfx.POOL + SfxVoices.LOOP_CAP
	print("SFXVOICE %d Hunters, %d frames: voices peak %d, mean %.1f (cap %d), %d loops at the end" % [
		m.hunters.size(), frames, peak, float(sum) / maxi(frames, 1), cap, Sfx.loops.size()])
	for whose: String in lost:
		var line := "SFXVOICE lost %-5s" % whose
		for why: StringName in WHYS:
			line += "  %s %4d" % [why, int(lost[whose].get(why, 0))]
		print(line)
	var top := names.keys()
	top.sort_custom(func(a, b): return names[a] > names[b])
	for k: String in top.slice(0, 12):
		print("SFXVOICE   %s x%d" % [k, names[k]])
	ok(m.hunters.size() == Data.MATCH_PLAYERS, "the fight has %d Hunters" % m.hunters.size())
	ok(peak <= cap, "voices stay under the cap: peak %d of %d" % [peak, cap])
	var enemy_lost := 0
	var own_lost := 0
	for why in POOL_LOST:
		enemy_lost += int(lost["enemy"].get(why, 0))
		own_lost += int(lost["own"].get(why, 0))
	ok(enemy_lost > 0, "the fight fills the pool: %d enemy sounds cut or refused" % enemy_lost)
	ok(own_lost == 0, "own and squad sounds keep their voices: %d cut or refused" % own_lost)
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

func _on_cut(sname: String, rank: float, why: StringName) -> void:
	var whose := "own" if rank == SfxVoices.OWN else "enemy"
	lost[whose][why] = int(lost[whose].get(why, 0)) + 1
	var k := "%s %s %s" % [whose, why, sname]
	names[k] = int(names.get(k, 0)) + 1
