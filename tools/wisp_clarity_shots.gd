extends RefCounted
## --wisp-clarity-shots --shots-dir=<dir>: a short frame sequence (30 fps PNGs, for ffmpeg) of the downed
## picture from the game camera, in a live 2v2 under xvfb with a renderer:
##   ally view   your teammate is knocked with their Boki out beside them; you walk over and stand on
##               their Wisp until they are back up
##   enemy view  a rival is knocked with their Boki out; you stand on their Wisp until it is stomped out
## Never touches the save.

const DT := 1.0 / 60.0
const SAVE_EVERY := 2          # sim steps per saved frame: 30 fps

var main: Node
var m: Match
var P: Hunter
var dir := ""
var frame := 0
var step_n := 0

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
	var mate: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	var foes: Array = m.hunters.filter(func(x): return x.team != P.team)
	var foe: Hunter = foes[0]
	# ---- ally view: the teammate goes down with their Boki out a few metres off
	mate.teleport(P.pos + Vector3(4.5, 0, -1.0))
	_pet_out(mate, Vector3(-3.0, 0, 3.5))
	await _go(0.8)
	m.knock(mate, foe, {})
	await _go(2.0)
	await _walk_to(mate, 3.0)
	await _go(5.0)
	# ---- enemy view: a rival goes down with their Boki out, and you stomp them out
	print("WISPCLARITY enemy view from frame %d" % frame)
	var rival: Hunter = foes[1]
	rival.teleport(P.pos + Vector3(-4.0, 0, -2.0))
	_pet_out(rival, Vector3(4.0, 0, 2.5))
	await _go(0.8)
	m.knock(rival, P, {})
	await _go(1.5)
	await _walk_to(rival, 3.0)
	await _go(7.0)
	print("WISPCLARITY %d frames in %s" % [frame, dir])
	main.get_tree().quit(0)

func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	main.get_viewport().warp_mouse(Vector2(4, 4))     # (no hover cards in the frames)
	P.teleport(m.world.random_ground())
	for h in m.hunters:
		if h != P:
			h.teleport(m.world.free_spot_near(P.pos + Vector3(30, 0, 0), [], 1.0, 0.4, 8.0))

## Gives the hunter a Boki if they have none, and sets it down on foot `off` metres from them.
func _pet_out(h: Hunter, off: Vector3) -> void:
	if h.kin == null:
		m.give_kin(h, m.bot_kin_record())
	var k: Kin = h.kin
	k.cmd = "follow"
	k.state = "active"
	k.teleport(m.world.free_spot_near(h.pos + off, [], 0.6, 0.4, 4.0))

## You walk onto the hunter (at most `secs`).
func _walk_to(o: Hunter, secs: float) -> void:
	var t := 0.0
	while t < secs and P.flat_dist(o) > 0.6:
		var to := Vector2(o.pos.x - P.pos.x, o.pos.z - P.pos.z).normalized()
		P.inp["move"] = to
		await _go(DT)
		t += DT
	P.inp["move"] = Vector2.ZERO

func _go(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		for k in m.kins:
			k.render(DT, 1.0)
		await main.get_tree().process_frame
		step_n += 1
		if step_n % SAVE_EVERY == 0:
			var img := main.get_viewport().get_texture().get_image()
			img.save_jpg(dir.path_join("f%04d.jpg" % frame), 0.9)
			frame += 1
