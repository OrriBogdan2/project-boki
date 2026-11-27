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
	var P: Hunter = m.player
	var foe: Hunter = null
	for o in m.hunters:
		o.ctrl = "idle"
		if o != P and o.team != P.team and foe == null:
			foe = o
	ok(foe != null, "a rival Hunter")
	_slows(foe)
	_silence(m, P, foe)
	_immunity(m, P, foe)
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


func _silence(m: Match, P: Hunter, foe: Hunter) -> void:
	P.cleanse_cc()
	KitStatus.apply(P, "sil", 2.0)
	ok(KitStatus.silenced(P) and KitStatus.silenced_left(P) > 1.9, "Silenced lands")
	for key in ["sig", "sec", "ult", "gear1", "util1"]:
		P.inp[key] = true
	P.inp["fire"] = true
	P.inp["dash"] = true
	P.inp["jump"] = true
	KitStatus.gate_silenced(P)
	var shut := true
	for key in ["sig", "sec", "ult", "gear1", "util1"]:
		shut = shut and not P.inp[key]
	ok(shut, "ability, gear and belt presses are dropped")
	ok(P.inp["fire"] and P.inp["dash"] and P.inp["jump"], "attack, dash and jump stay free")
	P.grounded = false
	P.gliding = false
	P.glide_cd = 0.0
	P.stun_t = 0.0
	ok(not P.can_glide(), "the glider will not open")
	m.step(Match.DT)
	ok(KitStatus.silenced(P), "a step does not end it early")
	# base recall refused
	var mate: Hunter = null
	for o in m.hunters:
		if o != P and o.team == P.team:
			mate = o
	P.grounded = true
	BaseRecall.start(P, mate if mate != null else foe)
	ok(P.base_t <= 0.0, "base recall will not start")
	# it runs out
	m.time += 2.5
	ok(not KitStatus.silenced(P), "it ends on its own time")
	P.grounded = false
	ok(P.can_glide(), "the glider opens again")
	# a cleanse ends it
	KitStatus.apply(P, "sil", 5.0)
	P.cleanse_cc()
	ok(not KitStatus.silenced(P), "a cleanse ends it")


func _immunity(m: Match, P: Hunter, foe: Hunter) -> void:
	foe.cleanse_cc()
	foe.grant_cc_immunity(2.0)
	foe.hurt(1.0, P, {"stun": 1.0, "root": 1.0, "slow": 2.0})
	ok(foe.stun_t <= 0.0 and foe.root_t <= 0.0 and foe.slow_t <= 0.0, "granted immunity: no stun, root or slow lands")
	KitStatus.apply(foe, "sil", 2.0)
	ok(not KitStatus.silenced(foe), "granted immunity: no silence lands")
	foe.tick_status(2.1)
	foe.hurt(1.0, P, {"stun": 1.0})
	ok(foe.stun_t > 0.9, "after it ends a stun lands again")
	foe.cleanse_cc()
	foe.cleanse_cc()
	KitStatus.apply(foe, "sil", 1.5)
	foe.stun_t = 1.0
	foe.add_slow(2.0, 0.5)
	foe.cleanse_cc()
	ok(foe.stun_t <= 0.0 and foe.slow_t <= 0.0 and not KitStatus.silenced(foe), "cleanse clears stun, slow, silence")
