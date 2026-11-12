extends RefCounted
## --wisp-clarity-shots --shots-dir=<dir>: a short frame sequence (30 fps JPGs, for ffmpeg) of the downed
## picture from the game camera, in a live 3v3 under xvfb with a renderer. Prints the frame each part
## starts on (video captions):
##   side by side  you (in the glitch skin), a teammate and a rival are knocked in a row: three Wisps,
##                 plumes in the you / ally / rival colours
##   jump revive   your other teammate runs in and jumps onto your Wisp until you are back up
##   ally revive   you walk to your teammate's Wisp (its plate says JUMP TO REVIVE, the rival's does not)
##                 and jump onto it until they are up
## Their Boki ride as wisps but hold off their own pull, so the revives in the clip are the jumps. Never
## touches the save.

const DT := 1.0 / 60.0
const SAVE_EVERY := 2          # sim steps per saved frame: 30 fps
const ZOOM := 0.7              # closer than the match's own zoom so the Wisps read in the clip
const GAP := 3.8               # m between the Wisps in the row (more than the revive reach)

var main: Node
var m: Match
var P: Hunter
var dir := ""
var frame := 0
var step_n := 0
var focus := Vector3.ZERO      # where the camera looks

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	WispLook.equip("glitch")
	await _setup()
	var mates: Array = m.hunters.filter(func(x): return x.team == P.team and x != P)
	var mate: Hunter = mates[0]
	var runner: Hunter = mates[1]
	var foe: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	mate.teleport(m.world.free_spot_near(P.pos + Vector3(GAP, 0, 0), [], 0.5, 0.4, 3.0))
	foe.teleport(m.world.free_spot_near(P.pos + Vector3(GAP * 2.0, 0, 0), [], 0.5, 0.4, 3.0))
	runner.teleport(m.world.free_spot_near(P.pos + Vector3(-9.0, 0, 3.0), [], 0.5, 0.4, 3.0))
	focus = mate.pos + Vector3(1.0, 0, 0)    # (the row clears the kit panel on the right)
	await _go(0.6)
	print("WISPCLARITY side by side from frame %d" % frame)
	for h in [P, mate, foe]:
		m.knock(h, null, {})
		h.reveal_t = 60.0
	await _go(DT)
	for k in m.kins:
		k.revive_wait = 1e6        # (their own pull would bring them up mid-clip)
	await _go(3.5)
	print("WISPCLARITY jump revive from frame %d" % frame)
	await _walk(runner, P, 4.0)
	await _jump_until_up(runner, P)
	await _go(1.0)
	print("WISPCLARITY ally revive from frame %d" % frame)
	await _walk(P, mate, 4.0, 1.6)
	await _go(1.2)
	await _walk(P, mate, 2.0)
	await _jump_until_up(P, mate)
	await _go(2.0)
	print("WISPCLARITY %d frames in %s" % [frame, dir])
	main.get_tree().quit(0)

func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
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

## `h` walks toward `o` until within `stop` metres (at most `secs`).
func _walk(h: Hunter, o: Hunter, secs: float, stop := 0.5) -> void:
	var t := 0.0
	while t < secs and h.flat_dist(o) > stop:
		h.inp["move"] = Vector2(o.pos.x - h.pos.x, o.pos.z - h.pos.z).normalized()
		await _go(DT)
		t += DT
	h.inp["move"] = Vector2.ZERO

## `h` hops onto downed `o` again and again until `o` is back up (at most 8 s), steering back over it
## each frame (a hop keeps the walk's speed, so without the steer it bounces off and away).
func _jump_until_up(h: Hunter, o: Hunter) -> void:
	var t := 0.0
	while o.downed and t < 8.0:
		var to := Vector2(o.pos.x - h.pos.x, o.pos.z - h.pos.z)
		h.inp["move"] = to.normalized() if to.length() > 0.35 else Vector2.ZERO
		if h.grounded and to.length() < 0.8:
			h.do_jump()
		await _go(DT)
		t += DT
	h.inp["move"] = Vector2.ZERO

func _go(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		for h in m.hunters:
			if h.downed:
				h.down_hp = Data.MATCH["down_hp"]     # (no bleed-out mid-clip; the timer reads full)
		t += DT
		m.cam.zoom = ZOOM
		m.cam.zoom_to = ZOOM
		m.cam.snap(focus)
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
