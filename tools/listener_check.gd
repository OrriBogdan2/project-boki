extends RefCounted
## --listener-check: where the ears are. Top-down games put the listener on the Hunter, turned with the
## camera, so a shot left of the Hunter on screen pans left (not on the cursor-led camera focus). In spectate
## it follows the watched teammate. Also the distance curve: a fight 25 m off screen is heard, quieter.

var main: Node
var fails := 0
var n := 0
const SIDE := 6.0              # m: a sound this far to one side of the Hunter
const ON_SCREEN := 10.0        # m: well inside the view
const OFF_SCREEN := 25.0       # m: a fight past the screen edge

func ok(cond: bool, what: String) -> void:
	n += 1
	print("LISTENER %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Game.goto("match", {"autoplay": true, "teams": 2, "squad": 2, "tier": 0, "length": 1e9,
		"seed": 77, "no_drop": true})
	for i in 6:
		await main.get_tree().process_frame
	var m: Match = main.current
	m.set_process(false)
	var P: Hunter = m.player
	ok(is_instance_valid(Sfx.ears) and Sfx.ears.is_current(), "the match has a current AudioListener3D")
	m.cam.pan = Vector3(5, 0, 0)      # the cursor has led the view away from you
	_follow(m, P.pos)
	_ears_on(P.pos, "the Hunter, not the cursor-led camera focus")
	var lead := m.cam.focus.distance_to(P.pos)
	ok(lead > 1.0, "setup: the camera focus is off the Hunter (%.1f m)" % lead)
	for yaw in [0.0, 1.2, -2.5]:
		m.cam.yaw = yaw
		m.cam.yaw_to = yaw
		_follow(m, P.pos)
		_pan_sides(m, P.pos, "camera yaw %.1f" % yaw)
	var mates: Array = m.hunters.filter(func(h): return h != P and h.team == P.team)
	ok(not mates.is_empty(), "setup: a teammate to watch")
	if not mates.is_empty():
		var mate: Hunter = mates[0]
		P.out = true
		P.set_meta("died_at", -10.0)
		m.time = 10.0
		ok(m.spectating() != null, "setup: the dead player is spectating")
		m._process(0.016)
		var watched: Hunter = m.spectating()
		var off := Sfx.ears.global_position.distance_to(watched.pos) if watched else INF
		ok(off < 1.0, "spectating, the ears follow the watched teammate (%.2f m off)" % off)
		_pan_sides(m, watched.pos, "spectating")
	_curve()
	print("LISTENER DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _follow(m: Match, at: Vector3) -> void:
	for i in 3:
		m.cam.follow(at, 0.016, false)

func _ears_on(at: Vector3, what: String) -> void:
	var off := Sfx.ears.global_position.distance_to(at)
	ok(off < 0.01, "the ears sit on %s (%.2f m off)" % [what, off])

## A sound to the screen's left of the Hunter pans left and one to the right pans right: the screen side
## (unprojected through the camera) and the voice's side in the listener's frame (negative x = left) agree.
func _pan_sides(m: Match, hunter: Vector3, what: String) -> void:
	var across := Vector3(m.cam.global_transform.basis.x.x, 0, m.cam.global_transform.basis.x.z).normalized()
	var mid := m.cam.unproject_position(hunter).x
	for sgn in [-1.0, 1.0]:
		var at: Vector3 = hunter + across * SIDE * sgn
		var on_screen_side := signf(m.cam.unproject_position(at).x - mid)
		var voice: AudioStreamPlayer3D = Sfx._voice(at)
		var heard := signf((Sfx.ears.global_transform.affine_inverse() * voice.global_position).x)
		var side := "left" if sgn < 0.0 else "right"
		ok(on_screen_side == sgn and heard == sgn, "%s: a sound %s of the Hunter pans %s (screen %+d, ears %+d)" % [
			what, side, side, int(on_screen_side), int(heard)])
	var centred := Sfx._voice(null)
	var x := (Sfx.ears.global_transform.affine_inverse() * centred.global_position).x
	ok(absf(x) < 0.01, "%s: a UI sound is centred" % what)

func _curve() -> void:
	var near := Sfx._distance_db(Vector3(ON_SCREEN, 0, 0) + Sfx.listener)
	var far := Sfx._distance_db(Vector3(OFF_SCREEN, 0, 0) + Sfx.listener)
	ok(not is_nan(far), "a fight %d m off screen is audible" % int(OFF_SCREEN))
	ok(far < near - 3.0, "...and quieter than one on screen (%.1f dB vs %.1f dB)" % [far, near])
	ok(far > -30.0, "...but not buried (%.1f dB)" % far)
	var gone := Sfx._distance_db(Vector3(Sfx.hear_range + 1.0, 0, 0) + Sfx.listener)
	ok(is_nan(gone), "past hear_range it is silent")
