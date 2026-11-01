extends RefCounted
## --airheal-check: heals and abilities in the air, and the cost of drinking.
##  1. In the opening drop, pressing a heal breaks out of it: the glider folds, you fall free with
##     your speed, and the tonic finishes and heals while you're still airborne.
##  2. Pressing an ability mid-drop breaks out of it too (a human's; bots never do).
##  3. Gliding normally, a heal folds the glider and the drink keeps going.
##  4. Drinking leaves you vulnerable: a hit does CONSUME_VULN times the damage and spills the
##     drink (the tonic is kept); the same for an armor kit.
## Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("AHCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _steps(m: Match, n: int) -> void:
	for i in n: m.step(Match.DT)

## Puts the hunter high over solid ground, in the opening drop with the glider open.
func _start_drop(m: Match, P: Hunter, at: Vector3) -> void:
	P.teleport(Vector3(at.x, at.y + 70.0, at.z))
	P.vel = Vector3(4.0, -2.0, 0.0)
	P.grounded = false
	P.dropping = true
	P.diving = false
	P.gliding = true
	for k in ["sec", "sig", "ult", "tonic", "kit", "gear1", "gear2", "glide", "jump", "dash", "fire"]:
		P.inp[k] = false
	_steps(m, 3)

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 41, "no_drop": true, "god": false})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		h.lives = 1
	var P: Hunter = m.player
	var Q: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	var g0: Vector3 = m.world.random_ground()
	Q.teleport(g0 + Vector3(60, 0, 60))
	# ---- 1. a tonic mid-drop
	_start_drop(m, P, g0)
	ok(P.dropping and P.gliding, "in the opening drop with the glider open")
	P.hp = P.max_hp * 0.5
	P.tonics = 2
	var hp0 := P.hp
	P.inp["tonic"] = true
	_steps(m, 1)
	ok(not P.dropping and not P.gliding, "a heal mid-drop breaks out of it and folds the glider")
	ok(P.drink_t > 0.0, "and the drink starts in the air")
	ok(not P.grounded, "still airborne")
	var frames := int(ceil(Hunter.DRINK_TIME / Match.DT)) + 3
	_steps(m, frames)
	ok(P.hp > hp0 + 1.0 and P.tonics == 1, "the tonic finishes and heals in the air (hp %.0f -> %.0f, tonics left %d)" % [hp0, P.hp, P.tonics])
	ok(not P.grounded, "it finished before landing (%.1fm up)" % (P.pos.y - m.world.ground_at(P.pos.x, P.pos.z)))
	# ---- 2. an ability mid-drop
	_start_drop(m, P, g0)
	P.inp["sec"] = true
	_steps(m, 1)
	ok(not P.dropping, "an ability press mid-drop breaks out of it too")
	# ---- 3. gliding normally: a heal folds the glider and keeps drinking
	for k in ["sec", "sig", "ult", "tonic", "kit", "gear1", "gear2", "glide", "jump", "dash", "fire"]:
		P.inp[k] = false
	P.teleport(g0 + Vector3(0, 30, 0))
	P.fly_t = 0.0; P.roll_t = 0.0; P.knock_t = 0.0; P.vel = Vector3.ZERO
	P.dropping = false
	P.grounded = false
	P.gliding = true
	P.glide_fuel = 1.0
	P.glide_cd = 0.0
	# (a clean glide: section 2's ability may still be carrying you, e.g. an archetype's leap sets
	# fly_t, and nothing opens or holds a glider mid-launch)
	P.fly_t = 0.0; P.roll_t = 0.0; P.knock_t = 0.0; P.vel = Vector3.ZERO
	for k in ["sec", "sec_hold", "sig", "dash", "jump"]: P.inp[k] = false
	P.inp["glide"] = true
	P.hp = P.max_hp * 0.5
	P.drink_t = 0.0
	_steps(m, 2)
	ok(P.gliding, "gliding (normal, not the drop)")
	P.inp["tonic"] = true
	_steps(m, 5)
	ok(not P.gliding and P.drink_t > 0.0, "a heal while gliding folds the glider and drinks")
	P.inp["glide"] = false
	# ---- 4. vulnerable while drinking: more damage, and a hit spills it
	P.teleport(g0)
	P.vel = Vector3.ZERO
	P.grounded = true
	P.drink_t = 0.0
	P.kit_t = 0.0
	_steps(m, 30)
	P.inv_t = 0.0
	P.armor = 0.0
	P.shield = 0.0
	P.hp = P.max_hp * 0.6
	var h1 := P.hp
	P.hurt(10.0, Q, {"src": "abil"})
	var plain := h1 - P.hp
	P.hp = P.max_hp * 0.6
	P.armor = 0.0
	P.tonics = 2
	P.inp["tonic"] = true
	_steps(m, 2)
	ok(P.drink_t > 0.0, "drinking on the ground")
	var h2 := P.hp
	P.hurt(10.0, Q, {"src": "abil"})
	var while_drink := h2 - P.hp
	ok(plain > 0.0 and absf(while_drink / plain - Hunter.CONSUME_VULN) < 0.02, "a hit while drinking does %.2fx the damage (%.1f vs %.1f)" % [while_drink / maxf(plain, 0.001), while_drink, plain])
	ok(P.drink_t <= 0.0, "and spills the drink")
	ok(P.tonics == 2, "the spilled tonic is kept")
	# the armor kit too
	P.armor = 0.0
	P.armor_kits = 1
	P.hp = P.max_hp * 0.6
	_steps(m, 2)
	P.inp["kit"] = true
	_steps(m, 2)
	ok(P.kit_t > 0.0, "repairing armor")
	P.hurt(6.0, Q, {"src": "abil"})
	ok(P.kit_t <= 0.0 and P.armor_kits == 1, "a hit spills the repair and keeps the kit")
	print("AIRHEAL CHECK DONE, failures: ", bad)
	main.get_tree().quit()
