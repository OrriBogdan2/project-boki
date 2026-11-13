extends RefCounted
## The ultimates on X of Sable (Encore, ThiefUlt) and Kael (Gilded Riposte, JuggernautUlt), run inside
## --dancer-combo-check / --juggernaut-combo-check / --kit-combo-check (tools/dancer_jug_check.gd) with the
## helpers of tools/archetype_check.gd passed in as A. Each asserts the cast, the telegraph, the payoff, the
## cooldown, the level gate (no cast below 6), the bond paid only on a land, the small mechanics, the merge
## hold, and (combos) the burst cap: an ultimate followed straight by a merge never knocks a full-health hunter.

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
	var thin: Dictionary = AimKit.entry(P, "ult")
	A.ok("dancer X: the ring reaches 3 bh at 0.4s, with the outer band marked; no blade before it",
			absf(float(thin["r"]) - float(d["reach"])) < 0.15 and AimKit.shown(P, "ult_rim")
			and U.blades == 0 and _owed(P) == 0.0, "r %.2f" % float(thin["r"]))
	A.ok("dancer X: the area is a thin ring (a band under 0.5m, no disc fill) whose outer edge is the blades' reach",
			float(thin["band"]) > 0.0 and float(thin["band"]) < 0.5 and float(thin["fill"]) <= 0.0
			and float(thin["r"]) == U.radius(), "band %.2f r %.3f radius %.3f" % [thin["band"], thin["r"], U.radius()])
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
	var rim_total := (float(d["dmg"]) + float(d["rim_dmg"])) * float(d["shots"])
	A.ok("dancer X: the blades keep the sourced totals (45 inside, 76 from the outer band)",
			is_equal_approx(total, 45.0) and is_equal_approx(rim_total, 76.0), "%.0f" % total)
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

## One cast of Encore against dummies that stand still while Sable stands or walks (`walk` m/s along +x).
## Returns each foe's landings: {foe id: [[seconds since the cast, hp lost], ...]}; `rings` is the ring's radius
## and the foe's distance at every beat, so a check can say which volleys a foe was in reach of.
func _cast_log(m: Match, P: Hunter, foes: Dictionary, walk: float, rings: Array) -> Dictionary:
	var U: ThiefUlt = (P.ak as ThiefKit).encore
	var log := {}
	var hp := {}
	for id in foes:
		log[id] = []
		hp[id] = (foes[id] as Hunter).hp
	P.ak.cd["x"] = 0.0
	var t0: float = m.time
	HunterKeys.ult_pressed(P)
	var beats := U.beat
	while U.running() or m.time - t0 < 2.7:
		P.inp["move"] = Vector2(1, 0) if walk > 0.0 else Vector2.ZERO
		A.step(m, A.DT)
		if U.beat > beats:
			beats = U.beat
			var row := {"t": m.time - t0, "r": U.radius()}
			for id in foes:
				row[id] = P.pos.distance_to((foes[id] as Hunter).pos)
			rings.append(row)
		for id in foes:
			var f: Hunter = foes[id]
			if f.hp < float(hp[id]) - 0.001:
				(log[id] as Array).append([m.time - t0, float(hp[id]) - f.hp])
				hp[id] = f.hp
	P.inp["move"] = Vector2.ZERO
	return log

## The ring against the source's Death Blossom rows (docs/heroes/thief.md "Death Blossom: source vs ours"):
## a dummy standing still in the band, in the middle and just out of reach, then one the ring passes over
## while she walks past it.
func dancer_ring(a) -> void:
	A = a
	var r = A.setup("thief", 4.6, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var d := (P.ak as ThiefKit).x_def()
	var reach := float(d["reach"])
	_open(P)
	T.teleport(home + Vector3(reach * float(d["rim"]) + 0.3, 0, 0))   # in the outer band
	T2.teleport(home + Vector3(0, 0, 2.0))                            # in the middle
	var out_at := home + Vector3(0, 0, -(reach + T.r + 0.3))
	var far: Hunter = m.make_hunter("T3", 5, "medium", "Target3", "idle", {}, out_at, {"arch": "none"})
	far.max_hp = 10000.0
	far.hp = far.max_hp
	far.armor = 0.0
	far.max_armor = 0.0
	var rings := []
	var still := _cast_log(m, P, {"rim": T, "mid": T2, "far": far}, 0.0, rings)
	var rim_hits: Array = still["rim"]
	var mid_hits: Array = still["mid"]
	var gap_max := 0.0
	var gap_min := 9.0
	for i in range(1, rim_hits.size()):
		var gap: float = float(rim_hits[i][0]) - float(rim_hits[i - 1][0])
		gap_max = maxf(gap_max, gap)
		gap_min = minf(gap_min, gap)
	var power: float = (P.ak as ThiefKit).power("x")
	A.ok("dancer ring: a standing dummy takes a blade every 0.2s for 2s (10, the first at 0.4s plus the flight)",
			rim_hits.size() == 10 and mid_hits.size() == 10 and absf(float(rim_hits[0][0]) - 0.4) < 0.2
			and gap_max < 0.25 and gap_min > 0.15, "%d hits, first %.2fs, gaps %.2f..%.2f" % [
			rim_hits.size(), float(rim_hits[0][0]), gap_min, gap_max])
	var grow_bh := float(d["r0"]) / AimKit.BH
	var reach_bh := reach / AimKit.BH
	var cadence := float(d["time"]) / float(d["shots"])
	A.ok("dancer ring: 1.3 to 3 bh in 0.4s, 2s of blades 0.2s apart, the band +50%, a 6s blight",
			absf(grow_bh - 1.3) < 0.05 and absf(reach_bh - 3.0) < 0.05 and float(d["grow"]) == 0.4
			and float(d["time"]) == 2.0 and absf(cadence - 0.2) < 0.001
			and float(d["rim_dmg"]) == float(d["dmg"]) * 0.5 and float(d["rim_blight"]) == 6.0,
			"%.2f bh -> %.2f bh" % [grow_bh, reach_bh])
	A.ok("dancer ring: 4 a blade in the middle, 6 from the band (x power); none past the radius",
			absf(float(mid_hits[0][1]) - float(d["dmg"]) * power) < 0.01
			and absf(float(rim_hits[0][1]) - (float(d["dmg"]) + float(d["rim_dmg"])) * power) < 0.01
			and (still["far"] as Array).is_empty(), "mid %.2f rim %.2f power %.2f" % [
			float(mid_hits[0][1]), float(rim_hits[0][1]), power])
	# the ring passes over a dummy while she walks: every beat's blade follows where the foe is then
	T2.teleport(home + Vector3(0, 0, 9.0))
	far.teleport(home + Vector3(0, 0, -9.0))
	P.teleport(home)
	T.teleport(home + Vector3(8.0, 0, 0))
	T.hp = T.max_hp
	rings.clear()
	var walked := _cast_log(m, P, {"foe": T}, 1.0, rings)
	var hits: Array = walked["foe"]
	var in_reach := 0
	var in_band := 0
	var want := 0.0
	for row in rings:
		if float(row["foe"]) < float(row["r"]) + T.r:
			in_reach += 1
			var band: bool = float(row["foe"]) > float(row["r"]) * float(d["rim"])
			in_band += 1 if band else 0
			want += (float(d["dmg"]) + (float(d["rim_dmg"]) if band else 0.0)) * power
	var got := 0.0
	for h in hits:
		got += float(h[1])
	A.ok("dancer ring: walking, a blade lands for every beat the foe is inside, 6 in the band, 4 inside it",
			hits.size() == in_reach and in_band > 0 and in_band < in_reach and absf(got - want) < 0.01,
			"%d of %d beats (%d in the band), %.0f damage (%.0f by the beats), she walked %.1fm" % [
			hits.size(), rings.size(), in_band, got, want, P.pos.x - home.x])
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
	# the reset is for taking a hunter down: a hunter already down takes nothing from it, a plain hit resets nothing
	A.step(m, 0.5)
	A.fresh(T)
	T.teleport(home + Vector3(2.6, 0, 0))
	P.teleport(home)
	A.aim_at(P, T.pos)
	T.downed = true
	T.hp = 0.0
	T.down_hp = 500.0
	K.cd["x"] = 0.0
	var resets0 := U.resets
	HunterKeys.ult_pressed(P)
	A.step(m, 0.9)
	A.ok("juggernaut X small mechanic: a hunter already knocked takes nothing, no kill, the cooldown keeps running",
			U.last_dealt == 0.0 and U.resets == resets0 and float(K.cd["x"]) > 1.0,
			"dealt %.0f resets %d cd %.1f" % [U.last_dealt, U.resets - resets0, float(K.cd["x"])])
	A.step(m, 0.5)
	A.fresh(T)
	T.downed = false
	T.teleport(home + Vector3(2.6, 0, 0))
	P.teleport(home)
	A.aim_at(P, T.pos)
	K.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)
	A.step(m, 0.9)
	A.ok("juggernaut X small mechanic: a hit that leaves the hunter up resets nothing",
			not T.downed and U.resets == resets0 and float(K.cd["x"]) > 1.0, "resets %d cd %.1f" % [U.resets - resets0,
					float(K.cd["x"])])
	A.ok("juggernaut X: its moves are keyed (guard, cleave)", ["jug_guard", "jug_riposte"]
			.all(func(mv): return not HunterAnim.km_sample(mv, 0.05).is_empty()))
	_cleave_fits(U.data())
	await _recovery_exits()
	await A.done(m)

## The cleave's crescent is the strip's leading edge: its tip at the strip's end, as wide as the strip (+20% at most).
func _cleave_fits(d: Dictionary) -> void:
	var sweep: Dictionary = HeroVfx.data("juggernaut")["moves"]["riposte_land"]["fx"][0]
	var ln := float(d["len"])
	var radius := float(sweep["size_x"]) * ln
	var tip := float(sweep["fwd_x"]) * ln + radius
	var half := radius * sin(deg_to_rad(float(sweep["arc"])) * 0.5)
	var w := float(d["width"])
	A.ok("juggernaut X: the cleave's crescent fits its strip", absf(tip - ln) < 0.1 and half >= w * 0.5
			and half <= w * 0.6, "tip %.2f / %.1f, half-width %.2f / %.2f" % [tip, ln, half, w * 0.5])

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

# ------------------------------------------------------------------ Kael: leaving the recovery
const TRACE := 12                # physics frames traced from the press

## One fresh cast, then `key` ("jump" or "dash") held for one physics step on recovery frame `frame` (1 = the
## first step after the cleave landed; 0: no ult, the control from rest). Walks forward throughout. Returns the
## recovery's state at the press (`phase`), whether it was over after that same step (`left`), the first traced
## frame the jump or dash showed (`moved`, 1 = the press frame), the frames with no travel (`still`), the travel
## (`reach`) and the top speed (`top`) over the trace, and with no key how many steps the recovery lasts (`n`).
func _exit_trial(frame: int, key: String) -> Dictionary:
	var r = A.setup("juggernaut", 9.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: JuggernautKit = P.ak
	var U: JuggernautUlt = K.riposte
	_open(P)
	P.inp["move"] = Vector2(0, 1)
	var seen := {"n": 0, "phase": "", "left": false, "moved": 0, "still": 0, "reach": 0.0, "top": 0.0}
	if frame > 0:
		HunterKeys.ult_pressed(P)
		while String(U.st.get("phase", "")) != "recover":
			m.step(A.DT)
		if key == "":
			while U.running():
				m.step(A.DT)
				seen["n"] += 1
		for i in frame - 1:
			m.step(A.DT)
	seen["phase"] = String(U.st.get("phase", ""))
	var y0 := P.pos.y
	var d0 := P.dashes
	for i in TRACE:
		var from := P.pos
		P.inp[key] = key != "" and i == 0
		m.step(A.DT)
		P.inp[key] = false
		var dx := Vector2(P.pos.x - from.x, P.pos.z - from.z).length()
		seen["reach"] += dx
		seen["still"] += 1 if dx < 0.001 else 0
		seen["top"] = maxf(float(seen["top"]), Vector2(P.vel.x, P.vel.z).length())
		var went := P.pos.y > y0 + 0.01 if key == "jump" else P.dashes < d0 - 0.01
		if went and int(seen["moved"]) == 0:
			seen["moved"] = i + 1
		if i == 0:
			seen["left"] = not U.running()
	await A.done(m)
	return seen

## The recovery (0.35s, half speed) is left by a jump or Shift on the very physics frame it is pressed, from its
## first frame to its last: it is over that frame, and nothing of the 50% walk goes into the jump (it reaches full
## run speed) or the dash (its travel and stops are the plain dash's, the control from rest).
func _recovery_exits() -> void:
	var n: int = (await _exit_trial(1, ""))["n"]
	A.ok("juggernaut X recovery: 0.35s is %d physics frames" % n, n == roundi(0.35 / A.DT), "%d frames" % n)
	for key in ["jump", "dash"]:
		var control: Dictionary = await _exit_trial(0, key)
		for frame in [1, 10, n]:
			var got: Dictionary = await _exit_trial(frame, key)
			var same: bool = int(got["moved"]) == 1 and bool(got["left"]) and got["phase"] == "recover"
			var plain: bool
			if key == "jump":
				plain = int(got["still"]) == 0 and float(got["top"]) >= float(control["top"]) - 0.01
			else:
				plain = int(got["still"]) == int(control["still"]) and _near(got["reach"], control["reach"])
			var info := "phase %s, moved on frame %d, left %s, still %d (control %d)" % [got["phase"], got["moved"],
					got["left"], got["still"], control["still"]]
			A.ok("juggernaut X recovery: %s on frame %d of %d goes that frame, no stop, no 50%% cap" % [key, frame, n],
					same and plain, info + ", reach %.2f (%.2f), top %.2f (%.2f)" % [got["reach"], control["reach"],
							got["top"], control["top"]])

func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.02
