extends RefCounted
## --edge-pulse-shots --shots-dir=<dir> (GPU, jobq submit --needs gpu): the hit's edge pulse (Ent.pulse_edge,
## hero_toon rim_pulse) at match camera, 1920x1080, in a 4v4: rest.png (before: no pulse), light.png and heavy.png
## (the four rivals each mid-pulse, as a light poke and a heavy hit leave them a few frames after the white flash),
## then the frame time of the fight with no pulse and with all 8 bodies pulsing every frame (the worst a team fight
## asks; EDGE rows, p95 and mean in ms, off/on blocks alternated). The check is --impact-weight-check.

const DT := 1.0 / 60.0
const WARM := 30  # frames dropped before timing
const TIMED := 120  # frames timed per block
const ROUNDS := 4  # off/on blocks alternated, so a drifting box loads both sides alike
const PX := Vector2i(1920, 1080)

var main: Node
var m: Match
var pl: Hunter
var dir := "user://edge_pulse_shots"
var pulse_all := false


func run(root: Node) -> void:
	main = root
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	main.get_window().size = PX
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 4, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	pl = m.player
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	DirAccess.make_dir_recursive_absolute(dir)
	for h in m.hunters:
		h.ctrl = "idle"
	var foes: Array = m.hunters.filter(func(x): return x.team != pl.team)
	for i in foes.size():
		foes[i].teleport(pl.pos + Vector3(6.0 + 2.0 * (i % 2), 0.0, -4.0 + 2.5 * i))
	await _go(30)
	for shot in [["rest", ""], ["light", "light"], ["heavy", "heavy"]]:
		await _go(20)
		for f in foes:
			f.pulse_edge(shot[1])
		await _go(4)  # past the white flash's full frames, early in the pulse
		main.get_viewport().get_texture().get_image().save_png(dir.path_join(shot[0] + ".png"))
		print("EDGE shot %s %s" % [shot[0], dir.path_join(shot[0] + ".png")])
	var off: Array = []
	var on: Array = []
	for r in ROUNDS:
		pulse_all = false
		off.append_array(await _frame_ms())
		pulse_all = true
		on.append_array(await _frame_ms())
	var row := "EDGE frame ms (%d frames each) off p95 %.2f mean %.2f | on p95 %.2f mean %.2f | delta p95 %.2f"
	print(row % [off.size(), _p95(off), _mean(off), _p95(on), _mean(on), _p95(on) - _p95(off)])
	print("EDGE DONE")
	main.get_tree().quit(0)


## The wall time between frames over TIMED frames of the fight, in ms.
func _frame_ms() -> Array:
	await _go(WARM)
	var ts: Array = []
	var last := Time.get_ticks_usec()
	for i in TIMED:
		await _go(1)
		var now := Time.get_ticks_usec()
		ts.append(float(now - last) / 1000.0)
		last = now
	return ts


func _p95(ts: Array) -> float:
	var s := ts.duplicate()
	s.sort()
	return s[int(s.size() * 0.95)]


func _mean(ts: Array) -> float:
	var sum := 0.0
	for t in ts:
		sum += t
	return sum / ts.size()


func _go(frames: int) -> void:
	for i in frames:
		m.step(DT)
		m.cam.snap(pl.pos)
		for h in m.hunters:
			if pulse_all and h.outline_t < 0.25:
				h.pulse_edge("heavy")  # restarts at full: the per-frame material sets never stop
			h.render(DT, 1.0)
		await main.get_tree().process_frame
