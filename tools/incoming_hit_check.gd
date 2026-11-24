extends RefCounted
## --incoming-hit-check: the incoming-hit cue (IncomingHitSfx, docs/AUDIO.md). A rival hits you: the cue plays,
## panned toward where it came from (right of you pans right, left pans left); chip damage is quiet and a heavy hit
## loud; a shotgun volley in one frame is one voice at the volley's level and a heavy hit inside the flurry moves
## it; a shot plays from where it was fired; your own hits, your own Boki and hits with no attacker play none.
## Never writes the save.

const R := 12.0              # m from you the rival stands

var bad := 0
var m: Match
var P: Hunter
var foe: Hunter

func ok(cond: bool, what: String) -> void:
	print("INCOMINGHIT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	await main.fade.reveal(0.01)
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 5, "no_drop": true})
	for i in 30:
		await main.get_tree().process_frame
	m.set_process(false)
	P = m.player
	P.max_hp = 1e6
	P.hp = 1e6
	foe = m.hunters.filter(func(x): return x.team != P.team)[0]
	Sfx.listener = P.pos
	_pan()
	_level_and_flurry()
	_origin_and_none()
	print("INCOMINGHIT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _hit(from: Vector3, dmg: float, o := {}) -> AudioStreamPlayer:
	IncomingHitSfx._t0 = -1000000
	foe.pos = from
	m.on_damage(P, foe, dmg, o)
	return IncomingHitSfx.voice()

func _pan() -> void:
	var cam := m.get_viewport().get_camera_3d()
	var right := Vector3(cam.global_basis.x.x, 0.0, cam.global_basis.x.z).normalized()
	var bus := AudioServer.get_bus_index("SFXPan")
	var panner := AudioServer.get_bus_effect(bus, 1) as AudioEffectPanner
	_hit(P.pos + right * R, 20.0)
	var to_right := panner.pan
	_hit(P.pos - right * R, 20.0)
	ok(to_right > 0.5 and panner.pan < -0.5, "a hit from the right pans right (%.2f), from the left left (%.2f)" % [
		to_right, panner.pan])

func _level_and_flurry() -> void:
	var chip := _hit(P.pos + Vector3(5, 0, 0), 3.0)
	var chip_db: float = chip.volume_db if chip else 0.0
	var heavy := _hit(P.pos + Vector3(5, 0, 0), 40.0)
	var heavy_db: float = heavy.volume_db if heavy else -80.0
	ok(is_equal_approx(chip_db, IncomingHitSfx.CHIP_DB) and is_equal_approx(heavy_db, IncomingHitSfx.HEAVY_DB),
		"chip damage plays the cue quiet (%.1f dB), a heavy hit loud (%.1f dB)" % [chip_db, heavy_db])
	IncomingHitSfx._t0 = -1000000
	IncomingHitSfx._p = null
	foe.pos = P.pos + Vector3(5, 0, 0)
	for i in 7:
		m.on_damage(P, foe, 2.0, {"src": "shot"})       # a shotgun volley: seven pellets in one frame
	var v := IncomingHitSfx.voice()
	var volley_db: float = v.volume_db if v else -80.0
	ok(is_equal_approx(volley_db, IncomingHitSfx.level(14.0)), "a 7-pellet volley is one voice at its total's level")
	m.on_damage(P, foe, 30.0, {})
	ok(IncomingHitSfx.voice().volume_db > volley_db + 1.0, "a heavy hit inside the flurry raises the one voice")

func _origin_and_none() -> void:
	var at := P.pos + Vector3(0, 0, 40)
	ok(IncomingHitSfx.source(P, foe, {"from": at}) == at, "a shot's cue sits where it was fired")
	ok(IncomingHitSfx.source(P, foe, {}) == foe.pos, "any other hit's cue sits on the attacker")
	ok(IncomingHitSfx.source(P, P, {}) == null and IncomingHitSfx.source(P, null, {}) == null,
		"your own damage and a hit with no attacker play none")
