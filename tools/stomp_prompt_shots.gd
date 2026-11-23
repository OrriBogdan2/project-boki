extends RefCounted
## --stomp-prompt-shots --shots-dir=<dir>: HUD screenshots of a 2v2 knock under xvfb with a renderer.
## Your teammate and one rival are knocked side by side with you standing in reach of both Wisps; one frame
## with the stomp prompt up (the rival's, inside reach) and one stepped out of reach. Run it on two trees
## (main and the branch) for before/after. Never touches the save.

const DT := 1.0 / 60.0

var main: Node
var m: Match
var hu: Hunter
var dir := ""


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	await _setup()
	var mate: Hunter = m.hunters.filter(func(x): return x.team == hu.team and x != hu)[0]
	var foes: Array = m.hunters.filter(func(x): return x.team != hu.team)
	var near: Hunter = foes[0]
	var far: Hunter = foes[1]
	hu.teleport(_at(0.0, 0.0))  # (random_ground can be a roof: stand on the ground the Wisps lie on)
	far.teleport(_at(6.0, -3.0))
	await _go(1.0)
	m.knock(mate, far, {})
	m.knock(near, hu, {})
	await _go(1.0)  # (a knock throws the Wisp: set them down by you once it has settled)
	hu.teleport(near.pos + Vector3(-0.8, 0.0, 0.0))
	mate.teleport(near.pos + Vector3(-2.4, 0.0, 0.6))
	await _go(0.03)
	for o: Hunter in [mate, near]:
		print("STOMPSHOTS %s downed=%s d=%.2f dy=%.2f" % [o.pname, o.downed, hu.flat_dist(o), hu.pos.y - o.pos.y])
	await _shot("a_in_reach")
	hu.teleport(near.pos + Vector3(0.0, 0.0, 6.0))
	await _go(0.5)
	await _shot("b_out_of_reach")
	print("STOMPSHOTS prompt=%s" % [m.interact.get("label", "")])
	main.get_tree().quit(0)


func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	hu = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	main.get_viewport().warp_mouse(Vector2(4, 4))
	hu.teleport(m.world.random_ground())
	for h in m.hunters:
		if h != hu:
			h.teleport(m.world.free_spot_near(hu.pos + Vector3(30, 0, 0), [], 1.0, 0.4, 8.0))


## `dx`, `dz` metres from you, on the ground there.
func _at(dx: float, dz: float) -> Vector3:
	var x := hu.pos.x + dx
	var z := hu.pos.z + dz
	return Vector3(x, m.world.ground_at(x, z), z)


func _go(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		m.cam.snap(hu.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame


func _shot(tag: String) -> void:
	await main.get_tree().process_frame
	print("STOMPSHOTS %s prompt=%s" % [tag, m.interact.get("label", "")])
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(tag + ".png"))
