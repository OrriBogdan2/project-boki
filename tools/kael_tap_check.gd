extends RefCounted
## Kael's tap strike, live RMB aim during E, tether break, and the ult's kept momentum.
## Run as --kael-tap-check (tools/check_registry.gd).

const AKCheck := preload("res://tools/archetype_check.gd")
var A: AKCheck

func run(main_node: Node, _who := "") -> void:
	A = AKCheck.new()
	A.main = main_node
	var r = A.setup("juggernaut", 6.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: JuggernautKit = P.ak
	var tn := Tuning.of("kael")
	# tap with the Smash resting: a lighter overhead strike still goes off, once, on its own cooldown
	P.teleport(home)
	A.fresh(T)
	T.teleport(home + Vector3(1.0, 0, 0))
	A.aim_at(P, T.pos)
	K.ch_rmb = 0.0
	K.cd["rmb"] = 99.0
	K.cd["tap"] = 0.0
	A.tap(m, P)
	A.step(m, 0.7)
	var full := float(K.rmb_def()["slam"]["dmg"])
	A.ok("kael tap with the Smash resting: a lighter strike lands",
			A.dmg(T) > 1.0 and A.dmg(T) < full * 0.95, "took %.0f of %.0f" % [A.dmg(T), full])
	A.tap(m, P)
	A.step(m, 0.1)
	A.ok("kael tap strike: its cooldown holds a second tap", K.slam_w.is_empty() and float(K.cd["tap"]) > 0.0)
	# RMB aim is live during E: wind up, throw E, turn 90 deg: the strike goes where the cursor is at the blow
	A.step(m, float(tn["tap_cooldown_s"]))
	A.fresh(T)
	T.teleport(home + Vector3(2.5, 0, 0))
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	K.cd["e"] = 0.0
	A.aim_at(P, home + Vector3(0, 0, -6.0))
	A.tap(m, P)
	A.step(m, 0.1)
	P.ak.use_e()
	A.aim_at(P, T.pos)
	A.step(m, 1.0)
	A.ok("kael RMB aim follows the cursor live during E (90 deg off the throw)", A.dmg(T) >= 20.0,
			"took %.0f" % A.dmg(T))
	# the ult keeps momentum
	K.warchain.snap("")
	P.teleport(home)
	P.vel = Vector3(6.0, 0, 0)
	K.cd["x"] = 0.0
	K.riposte.start()
	var sp := Vector2(P.vel.x, P.vel.z).length()
	A.ok("kael ult keeps horizontal momentum", absf(sp - 6.0 * float(tn["ult_carry_k"])) < 0.1,
			"before %s after %s" % [K.riposte.vel_before, K.riposte.vel_after])
	A.step(m, 0.1)
	A.ok("kael ult: still moving 0.1s in", Vector2(P.vel.x, P.vel.z).length() > 1.0)
	K.riposte.drop()
	P.vel = Vector3(0, 3.0, 4.0)
	K.riposte.start()
	A.ok("kael ult adds a vertical bonus on upward speed", absf(P.vel.y - (3.0 + float(tn["ult_up_bonus_mps"]))) < 0.05,
			"vy %.2f" % P.vel.y)
	K.riposte.drop()
	# tether: a Lunge aimed away past the length breaks it; sideways within range keeps it
	A.fresh(T)
	P.teleport(home)
	T.teleport(home + Vector3(5.0, 0, 0))
	K.cd["e"] = 0.0
	K.e_def()["tether_max"] = 7.5      # (short, so one Lunge can outrun it)
	A.aim_at(P, T.pos)
	P.ak.use_e()
	A.step(m, 0.4)
	K.warchain.tether_t = 5.0
	var hooked := K.warchain.hooked()
	A.aim_at(P, home + Vector3(0, 0, 6.0))
	K._lunge(0.3, false)
	A.step(m, 0.3)
	A.ok("kael lunge sideways within range keeps the tether", hooked and K.warchain.hooked())
	K.lunge = {}
	A.aim_at(P, home + Vector3(-9.0, 0, 6.0))
	K._lunge(1.0, false)
	A.step(m, 0.8)
	A.ok("kael lunge backward past the length breaks the tether", not K.warchain.hooked() and K.warchain.breaks >= 1,
			"breaks %d" % K.warchain.breaks)
	print("AKCHECK DONE, %d checks, failures: %d" % [A.n, A.fails])
	main_node.get_tree().quit(1 if A.fails > 0 else 0)
