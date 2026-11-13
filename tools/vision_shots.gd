extends RefCounted
## --vision-shots --shots-dir=<dir> [--fixed-fps 30]: the sight wedge at the match camera with the HUD. You stand
## aiming (a rival ahead with a plate, a crouched rival ahead with none, a rival behind you hidden), sweep your aim
## so the wedge turns over the one behind, then crouch: <dir>/f0000.jpg... every frame from SHOOT_FROM, plus
## stand.png and crouch.png. Run on a real GPU (jobq --needs gpu); docs/specs/VISION_LOOK.md.

const SPAWN_WAIT := 30   # frames before placing anyone (the match puts you on the map)
const SETTLE := 45        # frames before the first one kept (the match fades in, the camera settles)
const STAND := 60         # frames standing still
const SWEEP := 90         # frames turning the aim 100 degrees and back
const CROUCH := 75        # frames crouched (the camera eases out)
const SWEEP_DEG := 100.0
const AIM_M := 6.0        # m: where your aim (and the reticle) sits ahead of you
## Rivals round you: [degrees off your aim, metres, crouched]
const RIVALS := [[40.0, 5.0, false], [-35.0, 5.0, true], [165.0, 4.5, false]]

var main: Node
var dir := "user://vision_shots"

func _save(file: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	if file.ends_with(".jpg"): img.save_jpg(dir.path_join(file), 0.88)
	else: img.save_png(dir.path_join(file))

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Save.d["first_guide"] = 99          # a clean HUD: no first-match lines, no kit card, no tips
	Settings.set_v("tips", false, false)
	Game.god = true                     # nobody knocks the shot out
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 1, "tier": 0, "length": 1500.0, "seed": 5101, "no_drop": true, "raid": "clear",
		"tut_test": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P := m.player
	for i in SPAWN_WAIT:
		await main.get_tree().process_frame
	var spot := _open_spot(m, P.pos)
	P.teleport(spot[0])
	var a: float = spot[1]
	var rivals := m.hunters.filter(func(h): return h != P)
	for i in mini(rivals.size(), RIVALS.size()):
		var r: Hunter = rivals[i]
		var spec: Array = RIVALS[i]
		var b := a + deg_to_rad(float(spec[0]))
		r.ctrl = "idle"
		r.inp["aim"] = P.pos
		r.inp["crouch"] = bool(spec[2])
	var at := rivals.map(func(r): return r.pos)
	for i in mini(rivals.size(), RIVALS.size()):
		var b := a + deg_to_rad(float(RIVALS[i][0]))
		at[i] = P.pos + Vector3(cos(b), 0, sin(b)) * float(RIVALS[i][1])
	var total := SETTLE + STAND + SWEEP + CROUCH
	for f in total:
		var k := clampf(float(f - SETTLE - STAND) / SWEEP, 0.0, 1.0)
		var t := a + deg_to_rad(SWEEP_DEG) * sin(PI * k)
		P.inp["move"] = Vector2.ZERO
		for i in mini(rivals.size(), RIVALS.size()):
			var r: Hunter = rivals[i]
			r.teleport(at[i])      # held where they stand, not firing (firing would reveal them)
			r.inp["fire"] = false
			r.reveal_t = 0.0
		P.inp["aim"] = P.pos + Vector3(cos(t) * AIM_M, 0.9, sin(t) * AIM_M)
		P.inp["crouch"] = f >= SETTLE + STAND + SWEEP
		main.get_viewport().warp_mouse(m.cam.unproject_position(P.inp["aim"]))     # the reticle on your aim
		await main.get_tree().process_frame
		if f >= SETTLE:
			_save("f%04d.jpg" % (f - SETTLE))
		if f == SETTLE + STAND - 1: _save("stand.png")
		if f == total - 1: _save("crouch.png")
	Game.god = false
	print("VISIONSHOT DONE %d frames" % (total - SETTLE))
	main.get_tree().quit()

## A place near `from` and an aim (radians) with open, level ground under you and every rival: [position, aim].
func _open_spot(m: Match, from: Vector3) -> Array:
	for r in range(0, 80, 4):
		for j in 12:
			var p := from + Vector3(cos(TAU * j / 12.0), 0, sin(TAU * j / 12.0)) * r
			if not _open(m, p, p): continue
			p.y = m.world.ground_at(p.x, p.z)
			for i in 16:
				var a := TAU * i / 16.0
				var clear := func(spec):
					var b := a + deg_to_rad(spec[0])
					return _open(m, p, p + Vector3(cos(b), 0, sin(b)) * (float(spec[1]) + 3.0))
				if RIVALS.all(clear):
					return [p, a]
	return [from, 0.0]

func _open(m: Match, p: Vector3, q: Vector3) -> bool:
	var y := m.world.ground_at(p.x, p.z)
	var W := m.world
	return not (W.is_void(q.x, q.z) or W.is_block(q.x, q.z) or W.in_bush(q.x, q.z)
		or absf(W.ground_at(q.x, q.z) - y) > 0.5)
