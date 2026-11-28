extends "res://tools/pin_bjorn_owner_check.gd"
## --lace-needle-anim-check: needles in Lace's draw hand are animation, not a prop on her sheet.
## They spin out of a twist of red thread at the nock anchor when a draw or wind-up starts, leave as the shot,
## and wind back into thread when the move is cancelled: the Heavy Shot's big needle, the bow draw's arrow,
## Hemline's fan of five (gone as the rain fires), Finishing Touch's three (one gone per arrow).
## Prints AKCHECK lines like --archetype-check.


func run(main_node: Node) -> void:
	main = main_node
	main_node.set_meta("lace_needle_anim_check", self)
	await needles()
	print("AKCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)


func visible_count(K: ArcherKit) -> int:
	return K.fan.needles.filter(func(nd): return nd.visible).size()


func needles() -> void:
	var r := setup("archer", 7.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: ArcherKit = P.ak
	P.equip("longbow", 0)
	step(m, 0.3)
	T.teleport(home + Vector3(7.0, 0, 0))
	_heavy(m, P, T, K)
	_bow_draw(m, P, T, K)
	_hemline(m, P, T, K)
	_finishing_touch(m, P, T, K)
	await done(m)


## RMB: the big needle spins out of the thread over APPEAR_T; a stun winds it back into thread over UNRAVEL_T.
func _heavy(m: Match, P: Hunter, T: Hunter, K: ArcherKit) -> void:
	var nd := K.needle
	var sc := float(P.cdat.get("scale", 1.0))
	var hold := rmb_at.bind(P, T.pos)
	K.cd["rmb"] = 0.0
	P.inp["sec_hold"] = true
	K.press_rmb()
	step(m, 0.05, hold)
	ok("heavy appear: still spinning out of the thread at 0.05 s, a thread twist round the eye",
		nd.visible and nd.grow > 0.0 and nd.grow < 1.0 and nd.scale.z < sc * 0.9, "grow %.2f" % nd.grow)
	var twist: float = (nd.shown[2] as Vector3).distance_to(nd.eye)
	ok("heavy appear: the thread is a tight twist at the eye, not trailing", twist < 0.3, "%.2f m" % twist)
	step(m, 0.15, hold)
	ok("heavy appear: full size by 0.2 s", nd.grow >= 1.0 and absf(nd.scale.z - sc) < 0.001,
		"grow %.2f scale %.2f" % [nd.grow, nd.scale.z])
	P.stun_t = 0.5
	step(m, 0.05, hold)
	ok("heavy cancel: a stun winds it back into thread, still showing 0.05 s on", nd.visible and nd.leaving
		and nd.grow < 1.0, "visible %s grow %.2f" % [nd.visible, nd.grow])
	step(m, 0.2, hold)
	ok("heavy cancel: gone within UNRAVEL_T, no pop", not nd.visible, "visible %s" % nd.visible)
	P.inp["sec_hold"] = false
	P.stun_t = 0.0
	step(m, 1.0)


## LMB: a normal-size needle-arrow in the draw hand from the draw's start; loosed, it leaves with the shot; a
## cancelled draw winds it back into thread.
func _bow_draw(m: Match, P: Hunter, T: Hunter, K: ArcherKit) -> void:
	var a := K.arrow
	ready_bow(P)
	var aim := press_at.bind(P, T.pos)
	ok("draw: no needle in the hand before the draw", not a.visible)
	step(m, 0.3, aim)
	var nock := HeroVfx.of(m).anchor_pos(P, "nock")
	var len_ := a.eye.distance_to(a.tip)
	ok("draw: a needle-arrow at the nock anchor, a normal arrow's length (not the Heavy Shot's)",
		a.visible and a.eye.distance_to(nock) < 0.01 and len_ > 0.5 and len_ < 1.2, "len %.2f" % len_)
	P.inp["fire"] = false
	m.step(DT)
	m.step(DT)
	ok("draw: loosed, it's gone at once (the shot is the needle)", not a.visible)
	step(m, 0.5)
	ready_bow(P)
	step(m, 0.4, aim)
	K.drop_draw()
	P.inp["fire"] = false
	step(m, 0.05)
	ok("draw: a cancelled draw winds it back into thread", a.visible and a.leaving)
	step(m, 0.2)
	ok("draw: gone within UNRAVEL_T", not a.visible)
	step(m, 0.5)


## E: five small needles between her fingers from the cast until the rain fires, then none.
func _hemline(m: Match, P: Hunter, T: Hunter, K: ArcherKit) -> void:
	ready_bow(P)
	K.cd["e"] = 0.0
	P.inp["aim"] = T.pos
	P.ak.use_e()
	step(m, 0.05, func(): aim_at(P, T.pos))
	var tell := float(K.e_def()["tell"])
	var nock := HeroVfx.of(m).anchor_pos(P, "nock")
	var fan := K.fan.needles
	ok("Hemline: five needles spin out in her hand at the cast", visible_count(K) == 5 and fan[2].grow < 1.0,
		"%d showing" % visible_count(K))
	step(m, 0.2, func(): aim_at(P, T.pos))
	var spread := (fan[0].tip - fan[0].eye).normalized().dot((fan[4].tip - fan[4].eye).normalized())
	var small := fan[2].eye.distance_to(fan[2].tip)
	ok("Hemline: a fan of small needles around the nock anchor, fingers apart",
		visible_count(K) == 5 and fan[2].eye.distance_to(nock) < 0.01 and fan[0].grow >= 1.0
			and spread < 0.95 and small < 0.8,
		"spread dot %.2f len %.2f" % [spread, small])
	step(m, tell + 0.15, func(): aim_at(P, T.pos))
	ok("Hemline: gone as the rain fires", visible_count(K) == 0 and not K.rain.is_empty(),
		"%d showing" % visible_count(K))
	step(m, float(K.e_def()["time"]) + 0.5)


## X: three needles fanned; one vanishes per arrow; the last arrow clears the hand.
func _finishing_touch(m: Match, P: Hunter, T: Hunter, K: ArcherKit) -> void:
	P.lvl = 6
	P.ult = 0.0
	fresh(T)
	aim_at(P, T.pos)
	HunterKeys.ult_pressed(P)
	m.step(DT)
	ok("Finishing Touch: three needles fanned on the cast frame, the first leaving as the shot",
		visible_count(K) == 3 and K.fan.needles[2].flying > 0.0,
		"showing %d flying %.2f" % [visible_count(K), K.fan.needles[2].flying])
	step(m, 0.3, func(): aim_at(P, T.pos))
	ok("Finishing Touch: the first arrow left with the cast, two needles still fanned",
		K.ult.left == 2 and visible_count(K) == 2 and K.fan.needles[2].visible == false,
		"left %d showing %d" % [K.ult.left, visible_count(K)])
	beam(m, P, K, T.pos)
	step(m, 0.2, func(): aim_at(P, T.pos))
	ok("Finishing Touch: a loosed needle is gone within LEAVE_T", not K.fan.needles[1].visible)
	ok("Finishing Touch: one needle gone per arrow", K.ult.left == 1 and visible_count(K) == 1,
		"left %d showing %d" % [K.ult.left, visible_count(K)])
	beam(m, P, K, T.pos)
	step(m, 0.2)
	ok("Finishing Touch: the last arrow clears the hand", K.ult.left == 0 and visible_count(K) == 0,
		"left %d showing %d" % [K.ult.left, visible_count(K)])
