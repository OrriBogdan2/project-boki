extends RefCounted
## --sfx-fight-bench: voices and audio cost in a big bot fight, for before/after numbers on the voice cap
## (docs/AUDIO.md). A 30-player match (10 squads of 3, bots) with every squad and a monster pack brought
## around you, then FIGHT_SECS of it. Each frame samples the pool's sounding voices; the run prints the mean
## and peak voices per bus, the steals and drops, the ms per frame Sfx.play took and the CPU the audio
## threads used (/proc, Linux). Frame time is --perf-bench's job.
##   godot --audio-driver Dummy -- --sfx-fight-bench [--bench-secs=30]

const DT := 1.0 / 60.0
const MOBS := ["skitter", "brute", "spitter", "skitter", "bomber", "skitter", "spitter", "brute"]
const RING_M := Vector2(6.0, 16.0)      # metres from you the squads are brought to (min, max)
const TICK_HZ := 100.0                  # Linux clock ticks per second in /proc/<pid>/task/<tid>/stat

var main: Node
var secs := 30.0
var voices := {"SFX": [], "SFXFar": []}      # per frame voice counts per bus

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bench-secs="): secs = float(a.substr(13))
	Save.no_write = true
	var o := Match.demo_opts()
	o.merge({"teams": 10, "squad": 3, "total": 30, "no_drop": true, "god": true, "autoplay": true,
		"demo_kin": "cindle", "seed": 4101}, true)
	o.erase("demo_match")
	o.erase("fresh_t")
	Game.goto("match", o)
	var m: Match = null
	while m == null:
		await main.get_tree().process_frame
		if main.current is Match and (main.current as Match).is_processing() and (main.current as Match).hud != null:
			m = main.current
	m.set_process(false)
	var P: Hunter = m.player
	P.max_hp *= 20.0
	_bring_fight(m)
	var cpu0 := _audio_cpu_s()
	var wall0 := Time.get_ticks_usec()
	var play_us := 0
	var frames := 0
	while is_instance_valid(m) and m.time < secs:
		P.hp = P.max_hp
		Sfx.listener = P.pos
		m.step(DT)
		m._process(DT)
		await main.get_tree().process_frame
		frames += 1
		for bus in voices:
			voices[bus].append(Sfx.voices_on(bus))
	var wall_s := (Time.get_ticks_usec() - wall0) / 1e6
	for bus in voices:
		var v: Array = voices[bus]
		print("SFXBENCH %s voices: mean %.1f, peak %d (cap %d)" % [bus, v.reduce(func(a, b): return a + b, 0) / float(v.size()),
			v.max(), SfxVoices.cap(bus)])
	print("SFXBENCH steals %d, drops %d over %d frames" % [Sfx.stolen, Sfx.dropped, frames])
	print("SFXBENCH audio-thread cpu %.1f%% of one core (%.2f s over %.1f s)" % [100.0 * (_audio_cpu_s() - cpu0) / wall_s,
		_audio_cpu_s() - cpu0, wall_s])
	main.get_tree().quit()

## Every other squad's Hunters are put on a ring around you, and a monster pack joins.
func _bring_fight(m: Match) -> void:
	var P: Hunter = m.player
	var n := 0
	for h in m.hunters:
		if h == P:
			continue
		var a := TAU * n / float(m.hunters.size())
		var r := lerpf(RING_M.x, RING_M.y, fmod(n * 0.37, 1.0))
		h.teleport(P.pos + Vector3(cos(a), 0, sin(a)) * r)
		n += 1
	for i in MOBS.size():
		var a := TAU * i / MOBS.size()
		var at: Vector3 = m.world.free_spot_near(P.pos + Vector3(cos(a), 0, sin(a)) * 8.0, [], 1.0, 0.5, 6.0)
		m.spawn_mob(MOBS[i], Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))

## CPU seconds the process's audio threads have used (threads whose name mentions audio or mix).
func _audio_cpu_s() -> float:
	var ticks := 0
	for tid in DirAccess.get_directories_at("/proc/self/task"):
		var comm := FileAccess.get_file_as_string("/proc/self/task/%s/comm" % tid).to_lower()
		if not (comm.contains("audio") or comm.contains("mix")):
			continue
		var f := FileAccess.get_file_as_string("/proc/self/task/%s/stat" % tid).rsplit(")", true, 1)[1].split(" ", false)
		ticks += int(f[11]) + int(f[12])      # utime + stime (fields 14 and 15 of the stat line)
	return ticks / TICK_HZ
