extends RefCounted
## --first-objective-shots --shots-dir=<dir> [--size=WxH]: one picture per step of the first expedition's
## objective (FirstObjective): find (the wild Boki off screen: an arrow; on screen: a pin), knock it out, scan it,
## go to the outpost, start the uplink, hold the yard, step into the lift. Each shows the card and the marker.
## Needs a real renderer. Never writes the save.

var main: Node
var tree: SceneTree
var m: Match
var dir := "/tmp/fobj"
var n := 0

func run(mn: Node) -> void:
	main = mn
	tree = main.get_tree()
	var win := Vector2i(1920, 1080)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--size="):
			var p := String(a).substr(7).split("x")
			win = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Save.d["tutorial"]["move"] = true
	tree.root.size = win
	m = Match.new()
	main.add_child(m)
	main.current = m
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4243, "no_drop": true, "weapon": "rifle",
			"cls": "medium", "demo_kin": "cindle"})
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)
	m.player.riding = false
	_clear_field()
	await _find_shots()
	await _leave_shots()
	print("FOBJ shots in %s (%dx%d)" % [dir, win.x, win.y])
	tree.quit(0)

func _clear_field() -> void:
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		if h.team != m.player.team:
			h.ctrl = "idle"
			h.teleport(m.player.pos + Vector3(300.0, 0, 300.0))
	var keep := _pick_wild()
	m.kins = m.kins.filter(func(k: Kin) -> bool: return k.owner_h != null or k == keep)

## The one wild Boki the shots use: the first real one on the ground.
func _pick_wild() -> Kin:
	for k: Kin in m.kins:
		if k.owner_h == null and not m.world.is_void(k.pos.x, k.pos.z):
			return k
	return null

## A spot on the ground `dist` metres from `at` (the first direction that has ground).
func _ground_near(at: Vector3, dist: float) -> Vector3:
	for i in 16:
		var a := TAU * i / 16.0
		var q := at + Vector3(cos(a), 0.0, sin(a)) * dist
		if not m.world.is_void(q.x, q.z):
			return Vector3(q.x, m.world.ground_at(q.x, q.z) + 0.1, q.z)
	return at

func _settle(secs: float) -> void:
	m.cam.snap(m.player.pos)
	for i in int(secs / Match.DT):
		m.step(Match.DT)
		if i % 4 == 0:
			await tree.process_frame
	m.cam.snap(m.player.pos)
	m.objective._look = 0.0
	m.objective.tick(Match.DT)
	await tree.process_frame

func _shot(what: String) -> void:
	await tree.process_frame
	await tree.process_frame
	await RenderingServer.frame_post_draw
	n += 1
	main.get_viewport().get_texture().get_image().save_jpg(dir.path_join("%02d_%s.jpg" % [n, what]), 0.9)

func _find_shots() -> void:
	var P := m.player
	var k := _pick_wild()
	P.teleport(_ground_near(k.pos, 60.0))
	await _settle(1.0)
	await _shot("1_find_arrow")
	P.teleport(_ground_near(k.pos, 30.0))
	await _settle(1.0)
	await _shot("1_find_pin")
	P.teleport(_ground_near(k.pos, 6.0))
	await _settle(1.0)
	await _shot("2_knock")
	k.state = "dazed"
	k.dazed_t = 30.0
	P.teleport(_ground_near(k.pos, 2.5))
	await _settle(0.6)
	await _shot("3_scan")
	P.caught.append({"uid": "x", "species": "puddlet"})
	k.queue_free()
	m.kins.erase(k)
	await _settle(0.6)
	await _shot("4_leave_go")

func _leave_shots() -> void:
	var P := m.player
	var o := m.objective
	var x := o.exit_spot()
	x["open_at"] = 0.0
	var spot: Vector3 = x["pos"]
	P.teleport(_ground_near(spot, 12.0))
	await _settle(1.0)
	await _shot("4_leave_pin")
	P.teleport(_ground_near(spot, 2.0))
	await _settle(1.0)
	await _shot("5_start_uplink")
	x["state"] = "charging"
	x["team"] = P.team
	x["contested"] = false
	x["prog"] = 0.42
	await _settle(0.6)
	await _shot("6_hold_yard")
	x["state"] = "open"
	x["t"] = 12.0
	await _settle(0.6)
	await _shot("7_lift")
