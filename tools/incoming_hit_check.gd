extends RefCounted
## --incoming-hit-check [--shots-dir=<dir>]: the incoming-hit cue (IncomingHitSfx, docs/AUDIO.md). A rival hits
## you from 8 directions round the screen: the cue's placed voice sits on the rival and its pan (the voice in the
## camera's space, as Godot pans it) follows: right of you pans right, left pans left, straight up or down the
## screen stays in the middle. Also: chip damage is quiet and a heavy hit loud; a shotgun volley in one frame is
## one voice at the volley's level, a chip hit inside the flurry folds into it and a heavy one moves it; a real
## shot from 30 m plays from where it was fired after the shooter moved; your own hits, your own damage and hits
## with no attacker play none; downed, the cue goes through the muffled world bus; on a full near lane it still
## plays and the lane stays at its cap. With --shots-dir (a GPU worker, jobq) it records 8 real shots from the 8
## directions as <dir>/incoming_hit.avi with the game's own stereo mix, one INCOMINGHIT mark per hit.
## Never writes the save.

const DIRS := ["right", "up-right", "up", "up-left", "left", "down-left", "down", "down-right"]
const R := 12.0              # m from you the rival stands for each direction
const NEAR_M := 5.0          # m: a near hit (inside Sfx.FAR)
const LONG_M := 30.0         # m: the long shot's range
const SHOT_SPEED := 45.0     # m/s
const STEP := 1.0 / 30.0     # s per shot step (the movie's frame)

var bad := 0
var main: Node
var m: Match
var P: Hunter
var foe: Hunter
var right := Vector3.RIGHT   # the screen's right and up, on the ground
var up := Vector3.FORWARD

func ok(cond: bool, what: String) -> void:
	print("INCOMINGHIT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main_node: Node) -> void:
	main = main_node
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	var child := "--incoming-child" in OS.get_cmdline_user_args()
	if dir != "" and not child:
		return _record(dir)
	await _rig()
	if child:
		await _reel()
	else:
		_directions()
		_level_and_flurry()
		_long_shot()
		_none()
		await _downed()
		_cap()
	print("INCOMINGHIT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A frozen match: you, one rival, everyone else far away (out of every shot's path).
func _rig() -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	await main.fade.reveal(0.01)
	m = Match.new()
	main.add_child(m)
	var opts := HudRefDemo.opts("--hudref-demo=fight")
	opts.merge({"tier": 0, "length": 1e9, "seed": 5, "arch": "gunslinger", "cls": Arch.weight("gunslinger"),
		"weapon": Arch.signature("gunslinger")})
	m.start(opts)
	for i in 30:
		await main.get_tree().process_frame
	m.set_process(false)
	P = m.player
	foe = m.hunters.filter(func(x): return x.team != P.team)[0]
	for h in m.hunters:
		if h != P and h != foe:
			h.pos = P.pos + Vector3(0, 0, 400)
	var cam := m.get_viewport().get_camera_3d()
	right = _flat(cam.global_basis.x)
	up = _flat(-cam.global_basis.z)
	Sfx.listener = P.pos

func _directions() -> void:
	var cam := m.get_viewport().get_camera_3d()
	var pans := []
	for k in DIRS.size():
		var d := _dir(k)
		var v = _hit_from(P.pos + d * R, 20.0)
		if not v is AudioStreamPlayer3D:
			ok(false, "a hit from the %s plays a placed cue" % DIRS[k])
			continue
		var at: Vector3 = (v as AudioStreamPlayer3D).global_position
		var off := rad_to_deg(_flat(at - P.pos).angle_to(d))
		var pan := (cam.global_transform.affine_inverse() * at).normalized().x
		ok(at.distance_to(foe.pos) < 0.01 and off < 1.0 and _follows(k, pan),
			"a hit from the %s: the cue is on the rival (%.2f deg off) and pans %+.2f" % [DIRS[k], off, pan])
		pans.append("%s %+.2f" % [DIRS[k], pan])
	print("INCOMINGHIT pan by direction: %s" % ", ".join(pans))

func _level_and_flurry() -> void:
	var chip = _hit_from(P.pos + right * NEAR_M, 3.0)
	var chip_db: float = chip.volume_db if chip else 0.0
	var heavy = _hit_from(P.pos + right * NEAR_M, 40.0)
	var heavy_db: float = heavy.volume_db if heavy else -80.0
	ok(is_equal_approx(chip_db, IncomingHitSfx.CHIP_DB) and is_equal_approx(heavy_db, IncomingHitSfx.HEAVY_DB),
		"chip damage plays the cue quiet (%.1f dB), a heavy hit loud (%.1f dB)" % [chip_db, heavy_db])
	_hush()
	for i in 7:
		m.on_damage(P, foe, 2.0, {"src": "shot"})       # a shotgun volley: seven pellets in one frame
	var v = IncomingHitSfx.voice()
	var volley_db: float = v.volume_db if v else -80.0
	ok(_cues() == 1 and is_equal_approx(volley_db, IncomingHitSfx.level(14.0)),
		"a 7-pellet volley is one voice at the volley's level (%d voices, %.1f dB)" % [_cues(), volley_db])
	var was: Vector3 = foe.pos
	foe.pos = P.pos - right * NEAR_M
	m.on_damage(P, foe, 2.0, {})
	ok(_cues() == 1 and _cue_at().distance_to(was) < 0.01, "a chip hit inside the flurry folds into its one voice")
	m.on_damage(P, foe, 30.0, {})
	v = IncomingHitSfx.voice()
	ok(_cues() == 1 and _cue_at().distance_to(foe.pos) < 0.01 and v.volume_db > volley_db + 1.0,
		"a heavy hit inside the flurry moves the one voice to it, louder (%d voices)" % _cues())

## A real shot from LONG_M away: the shooter steps aside before it lands, and the cue plays where it was fired.
func _long_shot() -> void:
	_hush()
	var origin := P.pos + right * LONG_M + Vector3(0, 1.0, 0)
	_fire(origin)
	foe.pos = P.pos + up * 6.0
	for i in 120:
		m._update_shots(STEP)
		if IncomingHitSfx.voice() != null:
			break
	var off := _cue_at().distance_to(origin)
	ok(off < 0.01, "a shot from %d m plays where it was fired, not where the shooter went (%.1f m off)" % [LONG_M, off])

func _none() -> void:
	_hush()
	m.on_damage(foe, P, 20.0, {})
	m.on_damage(P, P, 20.0, {"src": "boom"})
	m.on_damage(P, null, 20.0, {"src": "blight"})
	ok(_cues() == 0, "your own hit, your own blast and a hit with no attacker play no cue")

func _downed() -> void:
	P.downed = true
	m.music_dir.tick(m, 0.0)
	var near := _bus_of(_hit_from(P.pos + right * NEAR_M, 20.0))
	var far := _bus_of(_hit_from(P.pos + right * R, 20.0))
	var far_into := AudioServer.get_bus_send(AudioServer.get_bus_index("SFXFar"))
	var dulled := near == "SFXWorld" and far == "SFXFar" and far_into == "SFXWorld"
	ok(Sfx.muffle_state().fx and dulled,
		"downed: the cue goes through the muffled world bus (near %s, far %s into %s)" % [near, far, far_into])
	P.downed = false
	m.music_dir.tick(m, 0.0)
	await main.get_tree().create_timer(Sfx.MUFFLE_S + 0.1).timeout

func _cap() -> void:
	_hush()
	var cap := SfxVoices.cap("SFX")
	for i in cap + 2:
		Sfx.last_played.clear()
		Sfx.recent.clear()
		Sfx.play("rifle", P.pos + up * NEAR_M, 0.0, 0.0)
	var full := Sfx.voices_on("SFX")
	foe.pos = P.pos + right * NEAR_M
	m.on_damage(P, foe, 20.0, {})
	var after := Sfx.voices_on("SFX")
	ok(full == cap and IncomingHitSfx.voice() != null and after <= cap,
		"a full near lane (%d of %d): the cue still plays and the lane stays at its cap (%d)" % [full, cap, after])

## The GPU recording (the child under the movie writer): one real shot from each of the 8 directions.
func _reel() -> void:
	var cam := m.get_viewport().get_camera_3d()
	for k in DIRS.size():
		foe.pos = P.pos + _dir(k) * R
		await _frames(12)
		P.hp = P.max_hp    # eight 30-damage shots would down you by the fourth, and a downed you takes no hits
		_hush()
		_fire(foe.pos + Vector3(0, 1.0, 0))
		var f := 0
		while IncomingHitSfx.voice() == null and f < 60:
			m._update_shots(STEP)
			await _frames(1)
			f += 1
		var v = IncomingHitSfx.voice()
		var pan: float = (cam.global_transform.affine_inverse() * v.global_position).normalized().x if v else 0.0
		print("INCOMINGHIT mark %s frame=%d pan=%+.2f" % [DIRS[k], Engine.get_process_frames(), pan])
		ok(v != null and _follows(k, pan), "the shot from the %s plays the cue, panned %+.2f" % [DIRS[k], pan])
		await _frames(18)

## The movie writer's flags are engine arguments and jobq passes its job's after "--", so the recording runs
## this check again as a child Godot under the movie writer (as tools/gameplay_media.gd does).
func _record(dir: String) -> void:
	var out_dir := dir if dir.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(dir)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var args := ["--path", ProjectSettings.globalize_path("res://"), "--rendering-driver", "opengl3",
		"--audio-driver", "Dummy", "--position", "30000,30000", "--fixed-fps", "30",
		"--write-movie", out_dir.path_join("incoming_hit.avi"), "--", "--incoming-hit-check", "--incoming-child"]
	var out: Array = []
	var rc := OS.execute(OS.get_executable_path(), args, out, true)
	for line in (String(out[0]) if out.size() > 0 else "").split("\n"):
		if line.begins_with("INCOMINGHIT") or line.contains("ERROR"):
			print(line)
	print("INCOMINGHIT child rc=%d" % rc)
	main.get_tree().quit(rc)

func _fire(origin: Vector3) -> void:
	var aim := _flat(P.pos - origin)
	foe.inp.erase("aim_y")          # a level shot, not one climbing to the rival's last aim
	var v2 := Vector2(aim.x, aim.z) * SHOT_SPEED
	m.spawn_shot(foe, origin, v2, 30.0, 2.0, 0.25, Color("ffb070"), {"pierce_terrain": true})

func _hit_from(at: Vector3, dmg: float):
	_hush()
	foe.pos = at
	m.on_damage(P, foe, dmg, {})
	return IncomingHitSfx.voice()

func _bus_of(v) -> String:
	return String(v.bus) if v != null else "none"

func _hush() -> void:
	for p in Sfx.voices():
		p.stop()

func _cues() -> int:
	var takes: Array = Sfx.streams.get(IncomingHitSfx.SOUND, [])
	return Sfx.voices().filter(func(p): return p.playing and p.stream in takes).size()

func _cue_at() -> Vector3:
	var v = IncomingHitSfx.voice()
	return (v as AudioStreamPlayer3D).global_position if v is AudioStreamPlayer3D else Vector3.INF

## The pan for direction k: right of you pans right, left pans left, straight up or down stays in the middle.
func _follows(k: int, pan: float) -> bool:
	var side := cos(TAU * k / DIRS.size())
	if absf(side) <= 0.1:
		return absf(pan) < 0.05
	return signf(pan) == signf(side) and absf(pan) > 0.15

func _dir(k: int) -> Vector3:
	var a := TAU * k / DIRS.size()
	return right * cos(a) + up * sin(a)

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame
