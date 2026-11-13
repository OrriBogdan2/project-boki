extends RefCounted
## --last-alive-shots --shots-dir=<dir>: game-camera frames (<dir>/frames/NNNNN.jpg, every 2nd step of the
## 60 Hz match, so 30 fps) of the last-alive aura (LastAlive). The player's squad of three loses one hunter,
## then another: the aura comes on the last one up, whose speed is shown by a run past a rival squad that
## has also been cut to one (a red aura on them). Then a teammate is revived and the aura ends.
## Run under jobq --needs gpu; cut with:
## ffmpeg -framerate 30 -i <dir>/frames/%05d.jpg -c:v libx264 -pix_fmt yuv420p out.mp4

const DT := 1.0 / 60.0
const FRAME_W := 960             # px wide, each saved frame
const RUN_SPEED := 0.075         # m per step the player jogs along +X (the camera follows)

var main: Node
var m: Match
var P: Hunter
var dir := ""
var frames := 0
var run_x := false

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir.path_join("frames"))
	await _setup()
	var mates := m.hunters.filter(func(x): return x.team == P.team and x != P)
	var foes := m.hunters.filter(func(x): return x.team != P.team)
	await _go(1.5)
	m.knock(mates[0], foes[0], {})
	mates[0].down_hp = 1e6
	await _go(1.5)
	run_x = true
	m.knock(mates[1], foes[0], {})
	mates[1].down_hp = 1e6
	for i in range(1, foes.size()):
		m.knock(foes[i], P, {})
		foes[i].down_hp = 1e6
	await _go(4.5)
	m.revive_hunter(mates[0], P)
	await _go(2.5)
	print("LASTALIVESHOTS %d frames in %s" % [frames, dir])
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
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var spot := m.world.random_ground()
	P.teleport(spot)
	var around := 0
	for h in m.hunters:
		if h == P:
			continue
		var off := Vector3(3.0 + 2.0 * around, 0, -2.5)
		if h.team != P.team:
			off = Vector3(10.0 + 2.5 * around, 0, 1.0 - around)
		h.teleport(m.world.free_spot_near(spot + off, [], 1.0, 0.4, 6.0))
		around += 1

func _go(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		if run_x:
			P.pos += Vector3(RUN_SPEED, 0, 0)
			P.prev = P.pos
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame
		if int(round(t / DT)) % 2 == 0:
			_save()

func _save() -> void:
	var img := main.get_viewport().get_texture().get_image()
	img.resize(FRAME_W, FRAME_W * img.get_height() / img.get_width(), Image.INTERPOLATE_BILINEAR)
	img.save_jpg(dir.path_join("frames/%05d.jpg" % frames), 0.88)
	frames += 1
