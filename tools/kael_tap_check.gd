extends RefCounted
## Kael's tap strike, live RMB aim during E, tether break, and the ult's kept momentum.
## Run as --kael-tap-check (tools/check_registry.gd).

const AKCheck := preload("res://tools/archetype_check.gd")
var chk: AKCheck


func run(main_node: Node, _who := "") -> void:
	chk = AKCheck.new()
	chk.main = main_node
	var r = chk.setup("juggernaut", 6.0, "", true)
	var m: Match = r[0]
	var pl: Hunter = r[1]
	var tgt: Hunter = r[2]
	var home: Vector3 = r[4]
	var kt: JuggernautKit = pl.ak
	var tn := Tuning.of("kael")
	# tap with the Smash resting: a lighter overhead strike still goes off, once, on its own cooldown
	pl.teleport(home)
	chk.fresh(tgt)
	tgt.teleport(home + Vector3(1.0, 0, 0))
	chk.aim_at(pl, tgt.pos)
	kt.ch_rmb = 0.0
	kt.cd["rmb"] = 99.0
	kt.cd["tap"] = 0.0
	chk.tap(m, pl)
	chk.step(m, 0.7)
	var full := float(kt.rmb_def()["slam"]["dmg"])
	chk.ok(
		"kael tap with the Smash resting: a lighter strike lands",
		chk.dmg(tgt) > 1.0 and chk.dmg(tgt) < full * 0.95,
		"took %.0f of %.0f" % [chk.dmg(tgt), full]
	)
	chk.tap(m, pl)
	chk.step(m, 0.1)
	chk.ok("kael tap strike: its cooldown holds a second tap", kt.slam_w.is_empty() and float(kt.cd["tap"]) > 0.0)
	# RMB aim is live during E: wind up, throw E, turn 90 deg: the strike goes where the cursor is at the blow
	chk.step(m, float(tn["tap_cooldown_s"]))
	chk.fresh(tgt)
	tgt.teleport(home + Vector3(2.5, 0, 0))
	kt.ch_rmb = 1.0
	kt.cd["rmb"] = 0.0
	kt.cd["e"] = 0.0
	chk.aim_at(pl, home + Vector3(0, 0, -6.0))
	chk.tap(m, pl)
	chk.step(m, 0.1)
	pl.ak.use_e()
	chk.aim_at(pl, tgt.pos)
	chk.step(m, 1.0)
	chk.ok(
		"kael RMB aim follows the cursor live during E (90 deg off the throw)",
		chk.dmg(tgt) >= 20.0,
		"took %.0f" % chk.dmg(tgt)
	)
	# 180 deg off the throw (behind him): the strike goes there too
	kt.warchain.snap()
	chk.fresh(tgt)
	tgt.teleport(home + Vector3(-2.5, 0, 0))
	kt.cd["rmb"] = 0.0
	kt.cd["e"] = 0.0
	chk.aim_at(pl, home + Vector3(6.0, 0, 0))
	chk.tap(m, pl)
	chk.step(m, 0.1)
	pl.ak.use_e()
	chk.aim_at(pl, tgt.pos)
	chk.step(m, 1.0)
	chk.ok(
		"kael RMB aim follows the cursor live during E (180 deg, behind him)",
		chk.dmg(tgt) >= 20.0,
		"took %.0f" % chk.dmg(tgt)
	)
	# the ult keeps momentum
	kt.warchain.snap()
	pl.teleport(home)
	pl.vel = Vector3(6.0, 0, 0)
	kt.cd["x"] = 0.0
	kt.riposte.start()
	var sp := Vector2(pl.vel.x, pl.vel.z).length()
	chk.ok(
		"kael ult keeps horizontal momentum",
		absf(sp - 6.0 * float(tn["ult_carry_k"])) < 0.1,
		"before %s after %s" % [kt.riposte.vel_before, kt.riposte.vel_after]
	)
	chk.step(m, 0.1)
	chk.ok("kael ult: still moving 0.1s in", Vector2(pl.vel.x, pl.vel.z).length() > 1.0)
	kt.riposte.drop()
	pl.vel = Vector3(0, 3.0, 4.0)
	kt.riposte.start()
	chk.ok(
		"kael ult adds a vertical bonus on upward speed",
		absf(pl.vel.y - (3.0 + float(tn["ult_up_bonus_mps"]))) < 0.05,
		"vy %.2f" % pl.vel.y
	)
	kt.riposte.drop()
	pl.vel = Vector3(0, 3.0, 4.0)
	pl.lfloat = {"t": 0.0}  # (mid-mantle: a ledge rise is running)
	kt.riposte.start()
	chk.step(m, 0.05)
	chk.ok(
		"kael ult mid-mantle: the ledge rise hands over, the bonus stays",
		pl.lfloat.is_empty() and pl.vel.y > 3.0,
		"vy %.2f" % pl.vel.y
	)
	kt.riposte.drop()
	# tether: a Lunge aimed away past the length breaks it; sideways within range keeps it
	chk.fresh(tgt)
	pl.teleport(home)
	tgt.teleport(home + Vector3(5.0, 0, 0))
	kt.cd["e"] = 0.0
	kt.e_def()["tether_max"] = 7.5  # (short, so one Lunge can outrun it)
	chk.aim_at(pl, tgt.pos)
	pl.ak.use_e()
	chk.step(m, 0.4)
	kt.warchain.tether_t = 5.0
	var hooked := kt.warchain.hooked()
	chk.aim_at(pl, home + Vector3(0, 0, 6.0))
	kt._lunge(0.3, false)
	chk.step(m, 0.3)
	chk.ok("kael lunge sideways within range keeps the tether", hooked and kt.warchain.hooked())
	kt.lunge = {}
	chk.aim_at(pl, home + Vector3(-9.0, 0, 6.0))
	kt._lunge(1.0, false)
	chk.step(m, 0.8)
	chk.ok(
		"kael lunge backward past the length breaks the tether",
		not kt.warchain.hooked() and kt.warchain.breaks >= 1,
		"breaks %d" % kt.warchain.breaks
	)
	print("AKCHECK DONE, %d checks, failures: %d" % [chk.n, chk.fails])
	main_node.get_tree().quit(1 if chk.fails > 0 else 0)
