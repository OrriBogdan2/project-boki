extends RefCounted
## The ultimates on X of Sable (Encore, ThiefUlt) and Kael (Gilded Riposte, JuggernautUlt), run inside
## --dancer-combo-check / --juggernaut-combo-check / --kit-combo-check (tools/dancer_jug_check.gd) with the
## helpers of tools/archetype_check.gd passed in as A. Each asserts the cast, the telegraph, the payoff, the
## cooldown, the level gate (no cast below 6), the bond paid only on a land, the small mechanics, the merge
## hold, and (combos) the burst cap: an ultimate followed straight by a merge never knocks a full-health hunter.

const CC := preload("res://tools/cc_probe.gd")

var A

## What the bond meter owes the current ult cast (KinBond.from_ult keeps the best event per cast id).
func _owed(P: Hunter) -> float:
	var c: Dictionary = P.get_meta("bond_cast", {})
	return float(c.get("got", 0.0)) if String(c.get("id", "")) == HeroUlt.cast_id(P.ak) else 0.0

## Opens the ultimate the way a run does: level 6 (main's gate in HunterKeys.ult_pressed, Hunter.ULT_AT).
func _open(P: Hunter) -> void:
	P.lvl = maxi(P.lvl, int(Hunter.ULT_AT[0]))
	P.ak.cd["x"] = 0.0

## The level gate: below 6 nothing casts, a forced point does not open it either, and X stays locked.
func _gate(P: Hunter, who: String) -> void:
	P.lvl = 5
	P.slot_lv["ult"] = 0
	P.ak.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)
	var locked := float(P.ak.cd["x"]) <= 0.0 and not P.ak.ult_running() and not P.can_level("ult")
	P.slot_lv["ult"] = 1
	HunterKeys.ult_pressed(P)
	A.ok("%s X: no cast below level 6 (even with a point forced in)" % who,
			locked and float(P.ak.cd["x"]) <= 0.0 and not P.ak.ult_running() and not P.ak.slot_info("x")["ready"])
	_open(P)

# ------------------------------------------------------------------ Sable: Encore
func dancer(a) -> void:
	A = a
	var r = A.setup("thief", 4.6, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: ThiefKit = P.ak
	var U: ThiefUlt = K.encore
	var d := K.x_def()
	_gate(P, "dancer")
	# T stands in the outer band (past 75% of 5.4m), T2 inside it
	T.teleport(home + Vector3(4.6, 0, 0))
	T2.teleport(home + Vector3(0, 0, 2.0))
	A.aim_at(P, T.pos)
	P.ult = 0.0
	P.dashes = 0.0
	K.add_mark(T, 2, true)
	var used0 := int(P.used.get("x", 0))
	HunterKeys.ult_pressed(P)
	m.step(A.DT)
	A.ok("dancer X: one press, one cast (main's X path only)", U.casts == 1 and int(P.used.get("x", 0)) == used0 + 1,
			"casts %d used +%d" % [U.casts, int(P.used.get("x", 0)) - used0])
	var ring: Dictionary = AimKit.entry(P, "ult")
	A.ok("dancer X: Encore casts; the ring everyone sees starts small and grows; the Vault comes back",
			U.running() and AimKit.shown(P, "ult") and bool(ring.get("all", false))
			and float(ring.get("r", 0.0)) < float(d["reach"]) * 0.6 and P.dashes >= P.max_dashes() - 0.01,
			"r %.2f dashes %.2f" % [float(ring.get("r", 0.0)), P.dashes])
	A.ok("dancer X: its cooldown runs from the cast (24s)", absf(float(K.cd["x"]) - float(d["cooldown"])) < 0.1,
			"%.1f" % float(K.cd["x"]))
	A.step(m, 0.36)
	A.ok("dancer X: the ring reaches 3 bh at 0.4s, with the outer band dashed; no blade before it",
			absf(float(AimKit.entry(P, "ult")["r"]) - float(d["reach"])) < 0.15 and AimKit.shown(P, "ult_rim")
			and U.blades == 0 and _owed(P) == 0.0, "r %.2f" % float(AimKit.entry(P, "ult")["r"]))
	var beat := {"at": [], "n": U.beat, "pulse": 0.0, "danced": true}
	A.step(m, 1.9, func():
		if U.beat > int(beat["n"]):
			beat["n"] = U.beat
			(beat["at"] as Array).append(m.time)
			beat["pulse"] = maxf(float(beat["pulse"]), float(AimKit.entry(P, "ult").get("alpha", 0.0)))
		if float(U.st.get("t", 0.0)) > 0.45:
			beat["danced"] = bool(beat["danced"]) and K.anim_id == ThiefUlt.DANCE)
	var gaps: Array = beat["at"]
	var even := true
	for i in range(1, gaps.size()):
		even = even and absf(float(gaps[i]) - float(gaps[i - 1]) - 0.2) < 0.03
	A.ok("dancer X: a blade at each foe every 0.2s, the ring pulsing on the beat",
			gaps.size() >= 9 and even and float(beat["pulse"]) > 1.6,
			"%d beats, pulse %.2f" % [gaps.size(), beat["pulse"]])
	A.ok("dancer X: she dances from the first beat on", bool(beat["danced"]))
	A.ok("dancer X: still running at 2.3s", U.running())
	A.step(m, 0.5)
	A.ok("dancer X: 2s of blades, 10 at most on each foe; ends with a plain fade and the dance stops",
			U.blades == 20 and not U.running() and not AimKit.shown(P, "ult") and K.anim_id != ThiefUlt.DANCE,
			"blades %d" % U.blades)
	A.ok("dancer X small mechanic: the outer band hits harder and blights 6s; the inside doesn't blight",
			U.rim_blades == 10 and A.dmg(T) > A.dmg(T2) * 1.3 and T.blight_t > 4.0 and T2.blight_t <= 0.0,
			"rim %.0f inner %.0f blight %.1f" % [A.dmg(T), A.dmg(T2), T.blight_t])
	var total := float(d["dmg"]) * float(d["shots"])
	A.ok("dancer X: the faster blades keep the old totals (40 inside, 60 from the outer band)", total == 40.0
			and (float(d["dmg"]) + float(d["rim_dmg"])) * float(d["shots"]) == 60.0, "%.0f" % total)
	A.ok("dancer X small mechanic: every blade refreshes her Marks", K.marks_on(T) >= 2
			and float(T.get_meta("marks")[P.nid][1]) > 3.0)
	A.ok("dancer X: blades landing on a hunter fill the bond once a cast (a hit: 60% of the bar, KinBond.from_ult)",
			absf(_owed(P) - 0.6) < 0.001, "owed %.2f" % _owed(P))
	HunterKeys.ult_pressed(P)
	A.ok("dancer X: on cooldown it doesn't cast again", not U.running())
	# a cast with nobody in reach: no bond (never on the cast alone); she walks and shoots through it
	T.teleport(home + Vector3(12.0, 0, 0))
	T2.teleport(home + Vector3(12.0, 0, 3.0))
	K.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)
	A.step(m, 0.4)
	var p0 := P.pos
	var b0 := K.bolts
	var kept := {"dance": true}
	A.step(m, 0.5, func():
		P.inp["move"] = Vector2(-1, 0)
		P.inp["fire"] = true
		kept["dance"] = bool(kept["dance"]) and (K.anim_id == ThiefUlt.DANCE or float(U.st.get("t", 0.0)) < 0.45))
	P.inp["move"] = Vector2.ZERO
	P.inp["fire"] = false
	var at: Vector2 = AimKit.entry(P, "ult")["at"]
	A.ok("dancer X small mechanic: she walks and fires freely, the ring moves with her",
			P.pos.distance_to(p0) > 1.0 and K.bolts > b0 and at.distance_to(Vector2(P.pos.x, P.pos.z)) < 0.2
			and K.move_k() >= 1.0, "moved %.2f bolts +%d" % [P.pos.distance_to(p0), K.bolts - b0])
	A.ok("dancer X: the dance plays on through her walking and her plain bolts (a stance: the legs keep walking)",
			bool(kept["dance"]) and bool(KMovesDJ.MOVES[ThiefUlt.DANCE]["stance"]))
	var into := float(U.st["t"]) - float(d["grow"])
	P.dashes = P.max_dashes()
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	var flip := K.anim_id
	A.step(m, 0.55)
	P.inp["move"] = Vector2.ZERO
	var off_beat := fmod(m.time - K.anim_at - into - 0.55 + 0.8, 0.8)
	A.ok("dancer X: a Vault flips out of the dance and it picks up again on the beat", flip in ThiefKit.CARTWHEELS
			and K.anim_id == ThiefUlt.DANCE and minf(off_beat, 0.8 - off_beat) < 0.05,
			"%s, off %.3f" % [flip, off_beat])
	A.step(m, 1.1)
	A.ok("dancer X: no foe in the ring, no bond (never on the cast alone)", U.casts == 2 and not U.running()
			and _owed(P) == 0.0, "owed %.2f" % _owed(P))
	A.ok("dancer X: its moves are keyed (cast, throws)", ["thf_encore", ThiefUlt.DANCE]
			.all(func(mv): return not HunterAnim.km_sample(mv, 0.05).is_empty()))
	await A.done(m)

# ------------------------------------------------------------------ Kael: Gilded Riposte
func zedran(a) -> void:
	A = a
	var r = A.setup("juggernaut", 2.6, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: JuggernautKit = P.ak
	var U: JuggernautUlt = K.riposte
	var d := K.x_def()
	_gate(P, "juggernaut")
	T.teleport(home + Vector3(2.6, 0, 0))
	T2.teleport(home + Vector3(-6.0, 0, 3.0))
	A.aim_at(P, T.pos)
	P.hp = P.max_hp * 0.5
	K.res = 0.0
	HunterKeys.ult_pressed(P)
	m.step(A.DT)
	var lane: Dictionary = AimKit.entry(P, "ult")
	A.ok("juggernaut X: the guard goes up: gold glow, the strip ahead everyone sees (1 x 2 bh), planted",
			U.guarding() and U.glow != null and U.glow.visible and bool(lane.get("all", false))
			and absf(float(lane.get("len", 0.0)) - 3.6) < 0.05 and absf(float(lane.get("width", 0.0)) - 1.8) < 0.05
			and K.move_k() <= 0.0, "len %.2f width %.2f" % [float(lane.get("len", 0.0)), float(lane.get("width", 0.0))])
	A.ok("juggernaut X: its cooldown runs from the cast (22s)", absf(float(K.cd["x"]) - float(d["cooldown"])) < 0.1)
	# planted: no walking, no jumping, no other buttons
	var p0 := P.pos
	P.inp["jump"] = true
	A.step(m, 0.2, func(): P.inp["move"] = Vector2(0, 1))
	P.inp["move"] = Vector2.ZERO
	A.ok("juggernaut X small mechanic: planted through the guard (no walk, no jump, no Smash)",
			P.pos.distance_to(p0) < 0.1 and K.busy(), "moved %.2f" % P.pos.distance_to(p0))
	# invulnerable: hits do nothing and can't stun; each one blocked (two at most) makes the answer harder
	var hp0 := P.hp
	P.hurt(30.0, T2, {"src": "shot", "stun": 1.0})
	A.step(m, 0.1)
	P.hurt(30.0, T2, {"src": "shot"})
	P.hurt(30.0, T2, {"src": "shot"})
	A.step(m, 0.1)
	P.hurt(30.0, T2, {"src": "shot"})
	A.ok("juggernaut X small mechanic: the guard blocks every hit and its stun; blocks count (two at most)",
			P.hp == hp0 and P.stun_t <= 0.0 and U.blocked == 3 and int(U.st["blocks"]) == 2,
			"hp %.0f -> %.0f blocked %d" % [hp0, P.hp, U.blocked])
	var took := CC.landed(m, P, T2)
	A.ok("juggernaut X parity: the guard is Invulnerable, a pull, a knock and a slow take no hold either",
			took == "" and K.cc_proof(), "took hold: " + took)
	A.ok("juggernaut X: no bond before the strike lands (blocking pays nothing)", _owed(P) == 0.0)
	A.step(m, 0.5)
	var dealt_blocked := U.last_dealt
	A.ok("juggernaut X: the cleave lands after 0.65s, he lunges about 1 bh into it",
			U.strikes == 1 and A.dmg(T) > 0.0 and P.pos.distance_to(p0) > 1.3, "took %.0f moved %.2f" % [A.dmg(T),
					P.pos.distance_to(p0)])
	A.ok("juggernaut X: he heals 80% of what it deals",
			absf(U.last_healed - 0.8 * U.last_dealt) < 1.0, "dealt %.0f healed %.0f" % [U.last_dealt, U.last_healed])
	A.ok("juggernaut X: landing it on a hunter fills the bond (a hit: 60% of the bar, KinBond.from_ult)",
			absf(_owed(P) - 0.6) < 0.001, "owed %.2f" % _owed(P))
	A.step(m, 0.5)
	A.ok("juggernaut X: about 1.1s in all, then he walks again", not U.running() and K.move_k() >= 1.0)
	# the same cleave with nothing blocked: two blocks made it 40% harder
	A.fresh(T)
	T.teleport(home + Vector3(2.6, 0, 0))
	P.teleport(home)
	A.aim_at(P, T.pos)
	K.res = 0.0
	K.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)
	A.step(m, 0.9)
	A.ok("juggernaut X small mechanic: two hits blocked make the answer 40% harder",
			absf(dealt_blocked / maxf(0.01, U.last_dealt) - 1.4) < 0.03, "%.1f vs %.1f" % [dealt_blocked, U.last_dealt])
	# blighted, the heal barely takes
	A.step(m, 0.4)
	A.fresh(T)
	T.teleport(home + Vector3(2.6, 0, 0))
	P.teleport(home)
	P.hp = P.max_hp * 0.5
	P.blight_t = 3.0
	K.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)
	A.step(m, 0.9)
	A.ok("juggernaut X small mechanic: blighted, the heal barely takes",
			U.last_healed < 0.5 * 0.8 * U.last_dealt, "healed %.0f of %.0f" % [U.last_healed, U.last_dealt])
	P.blight_t = 0.0
	A.step(m, 0.4)
	# a miss: nothing hit, no heal and no bond
	T.teleport(home + Vector3(0, 0, 6.0))
	P.teleport(home)
	K.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)
	A.step(m, 1.3)
	A.ok("juggernaut X: a miss pays no bond and heals nothing", _owed(P) == 0.0
			and U.last_dealt == 0.0)
	# a knock with it makes it ready again at once
	A.fresh(T)
	T.teleport(home + Vector3(2.6, 0, 0))
	P.teleport(home)
	A.aim_at(P, T.pos)
	T.hp = 10.0
	K.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)
	A.step(m, 0.9)
	var knock_paid := _owed(P)
	A.ok("juggernaut X small mechanic: knocking a hunter with it resets it; the bond counts the knock (0.7)",
			T.downed and U.resets == 1 and float(K.cd["x"]) <= 0.0 and absf(knock_paid - 0.7) < 0.001,
			"cd %.1f bond %.2f" % [float(K.cd["x"]), knock_paid])
	A.ok("juggernaut X: its moves are keyed (guard, cleave)", ["jug_guard", "jug_riposte"]
			.all(func(mv): return not HunterAnim.km_sample(mv, 0.05).is_empty()))
	await A.done(m)

# ------------------------------------------------------------------ combos, merge holds, the burst cap
func combos(a) -> void:
	A = a
	await _bola_encore()
	await _chain_riposte()
	await _merge_holds()
	await _burst_cap()

## The sheet's natural combo: Bola grounds a foe, then Encore: Grounded, they can't leave the ring.
func _bola_encore() -> void:
	var r = A.setup("thief", 3.5)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: ThiefKit = P.ak
	_open(P)
	A.aim_at(P, T.pos)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	A.tap(m, P)
	A.step(m, 0.7)
	var grounded := KitStatus.grounded(T)
	HunterKeys.ult_pressed(P)
	A.step(m, 2.5)
	A.ok("combo dancer: Bola > X = the Grounded foe takes every blade", grounded and K.encore.blades == 10,
			"grounded %s blades %d" % [grounded, K.encore.blades])
	await A.done(m)

## The sheet's combo for Kael: chain in, eat their answer in the guard, cleave back.
func _chain_riposte() -> void:
	var r = A.setup("juggernaut", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: JuggernautKit = P.ak
	_open(P)
	A.aim_at(P, T.pos)
	K.cd["e"] = 0.0
	K.use_e()
	A.step(m, 0.4)
	K.use_e()
	A.step(m, 0.5)
	A.aim_at(P, T.pos)
	HunterKeys.ult_pressed(P)
	P.hurt(25.0, T, {"src": "shot"})
	A.step(m, 0.9)
	A.ok("combo jug: E > E > X = pulled in, a hit blocked, the cleave lands",
			K.warchain.reels >= 1 and K.riposte.blocked == 1 and K.riposte.strikes == 1 and A.dmg(T) > 20.0,
			"reels %d blocked %d took %.0f" % [K.warchain.reels, K.riposte.blocked, A.dmg(T)])
	await A.done(m)

## A merge starting mid-ultimate ends it: no blade or cleave fires after, the telegraphs go.
func _merge_holds() -> void:
	var r = A.setup("thief", 3.0, "cindle")
	var m: Match = r[0]
	var P: Hunter = r[1]
	var TK: ThiefKit = P.ak
	_open(P)
	HunterKeys.ult_pressed(P)
	A.step(m, 0.5)
	P.ult = 1.0
	P.merge_cd = 0.0
	KinMerge.cast(P)
	var b0 := TK.encore.blades
	A.step(m, 1.6)
	A.ok("merge hold dancer: Encore's blades stop and its ring goes (hold field encore.st)",
			not TK.encore.running() and TK.encore.blades == b0 and not AimKit.shown(P, "ult") and KinMerge.active(P),
			"blades after %d" % (TK.encore.blades - b0))
	await A.done(m)
	r = A.setup("juggernaut", 2.6, "cindle")
	m = r[0]
	P = r[1]
	var T: Hunter = r[2]
	var JK: JuggernautKit = P.ak
	_open(P)
	A.aim_at(P, T.pos)
	HunterKeys.ult_pressed(P)
	A.step(m, 0.2)
	P.ult = 1.0
	P.merge_cd = 0.0
	KinMerge.cast(P)
	A.step(m, 1.0)
	A.ok("merge hold jug: the Riposte's guard drops, no cleave (hold field riposte.st)",
			not JK.riposte.running() and JK.riposte.strikes == 0 and not JK.riposte.glow.visible
			and KinMerge.active(P), "running %s strikes %d merged %s" % [JK.riposte.running(), JK.riposte.strikes,
					KinMerge.active(P)])
	await A.done(m)

## An ultimate that lands in full, then a merge at once and the form's own ultimate as soon as it is live:
## the full-health target is never knocked (every merge form, both heroes).
func _burst_cap() -> void:
	var worst := 1.0
	var knocked := []
	for sp in ["puddlet", "zephyrak", "pebbit", "cindle"]:
		for hero in ["thief", "juggernaut"]:
			var left: float = await _burst(hero, sp)
			worst = minf(worst, left)
			if left <= 0.0: knocked.append("%s+%s" % [hero, sp])
	A.ok("burst cap: X then a merge (and its ultimate) never one-shots a full-health hunter",
			knocked.is_empty(), "least health left %.0f%% %s" % [worst * 100.0, str(knocked)])

## One burst run: the share of the target's health left (0 when knocked).
func _burst(hero: String, sp: String) -> float:
	var r = A.setup(hero, 4.6 if hero == "thief" else 2.6, sp)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	_open(P)
	P.lvl = 10
	A.fresh(T)
	A.aim_at(P, T.pos)
	HunterKeys.ult_pressed(P)
	if hero == "juggernaut":
		P.hurt(10.0, T, {"src": "shot"})
		A.step(m, 0.1)
		P.hurt(10.0, T, {"src": "shot"})
	A.step(m, 2.5 if hero == "thief" else 0.85)
	A.merge_now(P)
	A.step(m, float(MergeForm.data()["xform_s"]) + 0.12)
	var mk := MergeKit.of(P)
	if mk != null:
		mk.age = 99.0
	A.aim_at(P, T.pos)
	P.inp["ult"] = true
	A.step(m, 2.0, func(): A.aim_at(P, T.pos))
	var left := 0.0 if T.downed or T.hp <= 0.0 else T.hp / T.max_hp
	await A.done(m)
	return left
