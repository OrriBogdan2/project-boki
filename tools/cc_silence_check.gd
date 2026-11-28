extends RefCounted
## --cc-silence-check: Silenced (no abilities, gear, belt, base recall or glider; attack, dash and jump stay),
## granted immunity and cleanse, and a slow's own timer against its own strength (reference tuning).
## Never touches the save.

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("CCSILENCE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 78, "no_drop": true, "god": false})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var p: Hunter = m.player
	var foe: Hunter = null
	for o in m.hunters:
		o.ctrl = "idle"
		if o != p and o.team != p.team and foe == null:
			foe = o
	ok(foe != null, "a rival Hunter")
	_slows(foe)
	_silence(m, p, foe)
	_immunity(p, foe)
	print("CCSILENCE DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## A weak slow that outlasts a strong one: the strong k ends with its own timer, the weak one then carries on.
func _slows(f: Hunter) -> void:
	f.cleanse_cc()
	f.add_slow(1.0, 0.6)
	f.add_slow(3.0, 0.2)
	ok(is_equal_approx(f.slow_k, 0.6) and is_equal_approx(f.slow_t, 1.0), "weak and long lends no time to the strong")
	f.tick_status(1.05)
	var took := f.slow_t > 1.8 and is_equal_approx(f.slow_k, 0.2)
	ok(took, "the weak one takes over (%.2f s, k %.2f)" % [f.slow_t, f.slow_k])
	f.tick_status(2.5)
	ok(f.slow_t <= 0.0 and f.slow_k == 0.0 and f.slow2_t <= 0.0, "the weak one runs out on its own time")
	# a stronger slow landing on a longer weak one: the weak one waits for it
	f.add_slow(3.0, 0.2)
	f.add_slow(1.0, 0.5)
	ok(is_equal_approx(f.slow_k, 0.5) and is_equal_approx(f.slow_t, 1.0), "a stronger, shorter slow leads")
	f.tick_status(1.05)
	ok(is_equal_approx(f.slow_k, 0.2) and f.slow_t > 1.8, "the longer weak slow resumes at its remaining time")
	# a same-strength refresh just tops up; a stronger and longer slow replaces both
	f.cleanse_cc()
	f.add_slow(1.0, 0.4)
	f.add_slow(2.0, 0.4)
	ok(is_equal_approx(f.slow_t, 2.0) and f.slow2_t <= 0.0, "the same strength refreshes")
	f.add_slow(3.0, 0.7)
	var leads := is_equal_approx(f.slow_k, 0.7) and is_equal_approx(f.slow_t, 3.0)
	ok(leads and f.slow2_t <= 0.0, "stronger and longer leads")
	f.hurt(1.0, null, {"slow": 4.0, "slow_k": 0.3})
	ok(is_equal_approx(f.slow_k, 0.7), "a hit's weaker slow does not weaken the running one")
	f.cleanse_cc()


func _silence(m: Match, p: Hunter, foe: Hunter) -> void:
	p.cleanse_cc()
	KitStatus.apply(p, "sil", 2.0)
	ok(KitStatus.silenced(p) and KitStatus.silenced_left(p) > 1.9, "Silenced lands")
	for key in ["sig", "sec", "ult", "gear1", "util1"]:
		p.inp[key] = true
	p.inp["fire"] = true
	p.inp["dash"] = true
	p.inp["jump"] = true
	KitStatus.gate_silenced(p)
	var shut := true
	for key in ["sig", "sec", "ult", "gear1", "util1"]:
		shut = shut and not p.inp[key]
	ok(shut, "ability, gear and belt presses are dropped")
	ok(p.inp["fire"] and p.inp["dash"] and p.inp["jump"], "attack, dash and jump stay free")
	p.grounded = false
	p.gliding = false
	p.glide_cd = 0.0
	p.stun_t = 0.0
	p.pos.y = p.ground() + 12.0  # well off the ground, so only silence can shut the glider
	p.vel.y = -2.0
	ok(not AirLimits.glide_shut(p), "high in the air the glider is otherwise free")
	ok(not p.can_glide(), "the glider will not open")
	m.step(Match.DT)
	ok(KitStatus.silenced(p), "a step does not end it early")
	# base recall refused
	var mate: Hunter = null
	for o in m.hunters:
		if o != p and o.team == p.team:
			mate = o
	p.grounded = true
	BaseRecall.start(p, mate if mate != null else foe)
	ok(p.base_t <= 0.0, "base recall will not start")
	# it runs out
	m.time += 2.5
	ok(not KitStatus.silenced(p), "it ends on its own time")
	p.grounded = false
	p.glide_cd = 0.0
	p.pos.y = p.ground() + 12.0
	p.vel.y = -2.0
	ok(p.can_glide(), "the glider opens again")
	# a cleanse ends it
	KitStatus.apply(p, "sil", 5.0)
	p.cleanse_cc()
	ok(not KitStatus.silenced(p), "a cleanse ends it")


func _immunity(p: Hunter, foe: Hunter) -> void:
	foe.cleanse_cc()
	foe.grant_cc_immunity(2.0)
	foe.hurt(1.0, p, {"stun": 1.0, "root": 1.0, "slow": 2.0})
	ok(foe.stun_t <= 0.0 and foe.root_t <= 0.0 and foe.slow_t <= 0.0, "granted immunity: no stun, root or slow lands")
	KitStatus.apply(foe, "sil", 2.0)
	ok(not KitStatus.silenced(foe), "granted immunity: no silence lands")
	foe.tick_status(2.1)
	foe.hurt(1.0, p, {"stun": 1.0})
	ok(foe.stun_t > 0.9, "after it ends a stun lands again")
	foe.cleanse_cc()
	foe.cleanse_cc()
	KitStatus.apply(foe, "sil", 1.5)
	foe.stun_t = 1.0
	foe.add_slow(2.0, 0.5)
	foe.cleanse_cc()
	ok(foe.stun_t <= 0.0 and foe.slow_t <= 0.0 and not KitStatus.silenced(foe), "cleanse clears stun, slow, silence")
