extends RefCounted
## --sfx-fight-bench: voices and audio cost in a big bot fight, for before/after numbers on the voice cap
## (docs/AUDIO.md). A 30-player match (10 squads of 3, bots) with every squad and a monster pack brought
## around you, then --bench-secs of it. Each frame samples the pool's sounding voices; the run prints the mean
## and peak voices per bus, the steals and drops (the cap's), the mean frame time and the CPU the helper
## threads (the audio mixer's) used (/proc, Linux). Frame time means something on a GPU box only.
##   godot --audio-driver Dummy -- --sfx-fight-bench [--bench-secs=30]

const DT := 1.0 / 60.0
const MOBS := ["skitter", "brute", "spitter", "skitter", "bomber", "skitter", "spitter", "brute"]
const RING_M := Vector2(6.0, 16.0)      # metres from you the squads are brought to (min, max)
const TICK_HZ := 100.0                  # Linux clock ticks per second in /proc/<pid>/task/<tid>/stat

var main: Node
var secs := 30.0
var voices := {"SFX": [], "SFXFar": [], "SFXMuffled": []}      # per frame voice counts per bus

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
	var frames := 0
	while is_instance_valid(m) and m.time < secs:
		P.hp = P.max_hp
		Sfx.listener = P.pos
		m.step(DT)
		m._process(DT)
		await main.get_tree().process_frame
		frames += 1
		for bus in voices:
			voices[bus].append(_voices_on(bus))
	var wall_s := (Time.get_ticks_usec() - wall0) / 1e6
	for bus in voices:
		var v: Array = voices[bus]
		var mean: float = v.reduce(func(x, y): return x + y, 0) / float(v.size())
		print("SFXBENCH %s voices: mean %.1f, peak %d" % [bus, mean, v.max()])
	print("SFXBENCH frame time mean %.1f ms (%d frames in %.1f s)" % [1000.0 * wall_s / frames, frames, wall_s])
	print("SFXBENCH steals %s, drops %s over %d frames" % [Sfx.get("stolen"), Sfx.get("dropped"), frames])
	var cpu_s := _audio_cpu_s() - cpu0
	print("SFXBENCH audio-thread cpu %.1f%% of one core (%.2f s over %.1f s)" % [100.0 * cpu_s / wall_s, cpu_s, wall_s])
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

func _voices_on(bus: String) -> int:
	return Sfx.players.filter(func(p): return p.playing and p.bus == bus).size()

## CPU seconds the process's helper threads have used: every thread but the main one and the worker pool, so
## the audio mixer (Godot names it like the rest) plus any stray loader. Compare before and after, not absolute.
func _audio_cpu_s() -> float:
	var ticks := 0
	for tid in DirAccess.get_directories_at("/proc/self/task"):
		var comm := _proc_line("/proc/self/task/%s/comm" % tid).to_lower()
		if comm.begins_with("workerthread") or tid == str(OS.get_process_id()):
			continue
		var stat := _proc_line("/proc/self/task/%s/stat" % tid)
		var f := stat.rsplit(")", true, 1)[1].split(" ", false)
		ticks += int(f[11]) + int(f[12])      # utime + stime (fields 14 and 15 of the stat line)
	return ticks / TICK_HZ

## A /proc file's first line (they report length 0, so get_file_as_string reads nothing).
func _proc_line(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_line() if f else ""
