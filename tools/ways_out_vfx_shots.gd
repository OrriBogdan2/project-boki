extends RefCounted
## --ways-out-vfx-shots --shots-dir=<dir>: the five looks of a way-out seat at match zoom (run under xvfb with a
## renderer). One outpost's uplink goes locked, open, in use, taken, lost (files seat_<n>_<state>.png), then the
## Heart's ring open and held (heart_<state>.png). Each shot centres the seat (the *_far ones look from
## across the island, the seat near the frame's edge); the hunters stand well away.

var main: Node
var m: Match
var dir := ""
var focus := Vector3.ZERO
const FAR := Vector3(-11.0, 1.5, 9.0)    # the far-read shots: the seat sits at the frame's top-right, across the island

func _frames(n: int) -> void:
	for i in n:
		m.step(Match.DT)
		m.cam.snap(focus)
		for h in m.hunters:
			h.render(Match.DT, 1.0)
		await main.get_tree().process_frame

func _grab(file: String) -> void:
	await _frames(45)
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("%s.png" % file))
	print("WAYSSHOT ", file)

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 3, "squad": 1, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true, "heart": true,
		"god": true, "length": 1e9})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var x: Dictionary = m.exits.of_kind("outpost")[0]
	for h in m.hunters:
		h.ctrl = "idle"
		h.max_hp = 5000.0
		h.hp = 5000.0
		h.teleport(m.world.random_ground())
	m.time = 100.0
	focus = x["pos"] + Vector3(0, 1.5, 3.0)
	P.teleport(m.world.free_spot_near(x["pos"] + Vector3(14, 0, 10), [], 1.0, 0.45, 6.0))
	x["open_at"] = m.time + 95.0
	await _grab("seat_1_locked")
	x["open_at"] = 0.0
	await _grab("seat_2_open")
	focus = x["pos"] + FAR
	await _grab("seat_2b_open_far")
	focus = x["pos"] + Vector3(0, 1.5, 3.0)
	x["state"] = "charging"
	x["team"] = 1
	x["prog"] = 0.6
	await _grab("seat_3_in_use")
	focus = x["pos"] + FAR
	await _grab("seat_3b_in_use_far")
	focus = x["pos"] + Vector3(0, 1.5, 3.0)
	x["taken"] = true
	await _frames(60)
	await _grab("seat_4_taken")
	x["taken"] = false
	x["state"] = "idle"
	x["shut_at"] = m.time - 1.0
	await _grab("seat_5_lost")
	var H: Heart = m.heart
	focus = H.site + Vector3(0, 1.5, 3.0)
	P.teleport(m.world.free_spot_near(H.site + Vector3(14, 0, 10), [], 1.0, 0.45, 6.0))
	H._force(Heart.S.FINAL, "shots")
	await _grab("heart_1_final_open")
	H.final_team = P.team
	H.final_prog = 0.5
	await _grab("heart_2_final_held")
	main.get_tree().quit(0)
