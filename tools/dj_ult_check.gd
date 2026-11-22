extends RefCounted
## The ultimates on X of Sable (Encore, ThiefUlt) and Kael (Gilded Riposte, JuggernautUlt), run inside
## --dancer-combo-check / --juggernaut-combo-check / --kit-combo-check (tools/dancer_jug_check.gd) with the
## helpers of tools/archetype_check.gd passed in as A. Each asserts the cast, the telegraph, the payoff, the
## cooldown, the level gate (no cast below 6), the bond paid only on a land, the small mechanics, the merge
## hold, and (combos) the burst cap: an ultimate followed straight by a merge never knocks a full-health hunter.

const AimkitCheck := preload("res://tools/aimkit_check.gd")

const EXIT := preload("res://tools/ult_exit.gd")
const CLEAVE_TALL := 2.4        # m: the crescent tops a Hunter (about 1.9 m)

var a_x

## What the bond meter owes the current ult cast (KinBond.from_ult keeps the best event per cast id).
func _owed(p: Hunter) -> float:
	var c: Dictionary = p.get_meta("bond_cast", {})
	return float(c.get("got", 0.0)) if String(c.get("id", "")) == HeroUlt.cast_id(p.ak) else 0.0

## Opens the ultimate the way a run does: level 6 (main's gate in HunterKeys.ult_pressed, Hunter.ULT_AT).
func _open(p: Hunter) -> void:
	p.lvl = maxi(p.lvl, int(Hunter.ULT_AT[0]))
	p.ak.cd["x"] = 0.0

## The level gate: below 6 nothing casts, a forced point does not open it either, and X stays locked.
func _gate(p: Hunter, who: String) -> void:
	p.lvl = 5
	p.slot_lv["ult"] = 0
	p.ak.cd["x"] = 0.0
	HunterKeys.ult_pressed(p)
	var locked := float(p.ak.cd["x"]) <= 0.0 and not p.ak.ult_running() and not p.can_level("ult")
	p.slot_lv["ult"] = 1
	HunterKeys.ult_pressed(p)
	a_x.ok("%s X: no cast below level 6 (even with a point forced in)" % who,
			locked and float(p.ak.cd["x"]) <= 0.0 and not p.ak.ult_running() and not p.ak.slot_info("x")["ready"])
	_open(p)

# ------------------------------------------------------------------ Sable: Encore
func dancer(a) -> void:
	a_x = a
	var r = a_x.setup("thief", 4.6, "", true)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var t2: Hunter = r[3]
	var home: Vector3 = r[4]
	var k: ThiefKit = p.ak
	var u: ThiefUlt = k.encore
	var d := k.x_def()
	_gate(p, "dancer")
	# T stands in the outer band (past 75% of 5.4m), T2 inside it
	t.teleport(home + Vector3(4.6, 0, 0))
	t2.teleport(home + Vector3(0, 0, 2.0))
	a_x.aim_at(p, t.pos)
	p.ult = 0.0
	p.dashes = 0.0
	k.add_mark(t, 2, true)
	var used0 := int(p.used.get("x", 0))
	HunterKeys.ult_pressed(p)
	m.step(a_x.DT)
	a_x.ok("dancer X: one press, one cast (main's X path only)", u.casts == 1 and int(p.used.get("x", 0)) == used0 + 1,
			"casts %d used +%d" % [u.casts, int(p.used.get("x", 0)) - used0])
	var ring: Dictionary = AimKit.entry(p, "ult")
	a_x.ok("dancer X: Encore casts; the ring everyone sees starts small and grows; the Vault comes back",
			u.running() and AimKit.shown(p, "ult") and bool(ring.get("all", false))
			and float(ring.get("r", 0.0)) < float(d["reach"]) * 0.6 and p.dashes >= p.max_dashes() - 0.01,
			"r %.2f dashes %.2f" % [float(ring.get("r", 0.0)), p.dashes])
	a_x.ok("dancer X: its cooldown runs from the cast (24s)", absf(float(k.cd["x"]) - float(d["cooldown"])) < 0.1,
			"%.1f" % float(k.cd["x"]))
	a_x.step(m, 0.36)
	var thin: Dictionary = AimKit.entry(p, "ult")
	a_x.ok("dancer X: the ring is near 3 bh just before 0.4s, the outer band marked; no blade before it",
			absf(float(thin["r"]) - float(d["reach"])) < 0.25 and AimKit.shown(p, "ult_rim")
			and u.blades == 0 and _owed(p) == 0.0, "r %.2f" % float(thin["r"]))
	a_x.ok("dancer X: the area is a thin ring (a band under 0.5m, no disc fill) whose outer edge is the blades' reach",
			float(thin["band"]) > 0.0 and float(thin["band"]) < 0.5 and float(thin["fill"]) <= 0.0
			and float(thin["r"]) == u.radius(), "band %.2f r %.3f radius %.3f" % [thin["band"], thin["r"], u.radius()])
	_soft_ring(a_x, p, thin, 1.2)
	var beat := {"at": [], "n": u.beat, "pulse": 0.0, "danced": true, "r_off": 0.0}
	a_x.step(m, 1.9, func():
		if u.beat > int(beat["n"]):
			beat["n"] = u.beat
			(beat["at"] as Array).append(m.time)
			beat["pulse"] = maxf(float(beat["pulse"]), float(AimKit.entry(p, "ult").get("alpha", 0.0)))
			beat["on_beat"] = AimKit.entry(p, "ult").duplicate()
			beat["r_off"] = maxf(float(beat["r_off"]), absf(float(AimKit.entry(p, "ult")["r"]) - u.radius()))
			var rim_off := absf(float(AimKit.entry(p, "ult_rim")["r"]) - u.radius() * float(d["rim"]))
			beat["r_off"] = maxf(float(beat["r_off"]), rim_off)
		if float(u.st.get("t", 0.0)) > 0.45:
			beat["danced"] = bool(beat["danced"]) and k.anim_id == ThiefUlt.DANCE)
	a_x.ok("dancer X: the ring and its dashed outer band are drawn at exactly the hit radius on every beat",
			(beat["at"] as Array).size() > 0 and float(beat["r_off"]) < 0.001, "off %.4f" % float(beat["r_off"]))
	var gaps: Array = beat["at"]
	var even := true
	for i in range(1, gaps.size()):
		even = even and absf(float(gaps[i]) - float(gaps[i - 1]) - 0.2) < 0.03
	a_x.ok("dancer X: a blade at each foe every 0.2s, the ring pulsing on the beat",
			gaps.size() >= 9 and even and float(beat["pulse"]) > 1.6,
			"%d beats, pulse %.2f" % [gaps.size(), beat["pulse"]])
	_soft_ring(a_x, p, beat.get("on_beat", {}), 2.0)
	a_x.ok("dancer X: she dances from the first beat on", bool(beat["danced"]))
	a_x.ok("dancer X: still running at 2.3s", u.running())
	a_x.step(m, 0.5)
	a_x.ok("dancer X: 2s of blades, 10 at most on each foe; ends with a plain fade and the dance stops",
			u.blades == 20 and not u.running() and not AimKit.shown(p, "ult") and k.anim_id != ThiefUlt.DANCE,
			"blades %d" % u.blades)
	a_x.ok("dancer X small mechanic: the outer band hits harder and blights 6s; the inside doesn't blight",
			u.rim_blades == 10 and a_x.dmg(t) > a_x.dmg(t2) * 1.3 and t.blight_t > 4.0 and t2.blight_t <= 0.0,
			"rim %.0f inner %.0f blight %.1f" % [a_x.dmg(t), a_x.dmg(t2), t.blight_t])
	var total := float(d["dmg"]) * float(d["shots"])
	var rim_total := (float(d["dmg"]) + float(d["rim_dmg"])) * float(d["shots"])
	a_x.ok("dancer X: the blades keep the sourced totals (45 inside, 76 from the outer band)",
			is_equal_approx(total, 45.0) and is_equal_approx(rim_total, 76.0), "%.0f" % total)
	a_x.ok("dancer X small mechanic: every blade refreshes her Marks", k.marks_on(t) >= 2
			and float(t.get_meta("marks")[p.nid][1]) > 3.0)
	a_x.ok("dancer X: blades landing on a hunter fill the bond once a cast (a hit: 60% of the bar, KinBond.from_ult)",
			absf(_owed(p) - 0.6) < 0.001, "owed %.2f" % _owed(p))
	HunterKeys.ult_pressed(p)
	a_x.ok("dancer X: on cooldown it doesn't cast again", not u.running())
	# a cast with nobody in reach: no bond (never on the cast alone); she walks and shoots through it
	t.teleport(home + Vector3(12.0, 0, 0))
	t2.teleport(home + Vector3(12.0, 0, 3.0))
	k.cd["x"] = 0.0
	HunterKeys.ult_pressed(p)
	a_x.step(m, 0.4)
	var p0 := p.pos
	var b0 := k.bolts
	var kept := {"dance": true}
	a_x.step(m, 0.5, func():
		p.inp["move"] = Vector2(-1, 0)
		p.inp["fire"] = true
		kept["dance"] = bool(kept["dance"]) and (k.anim_id == ThiefUlt.DANCE or float(u.st.get("t", 0.0)) < 0.45))
	p.inp["move"] = Vector2.ZERO
	p.inp["fire"] = false
	var at: Vector2 = AimKit.entry(p, "ult")["at"]
	a_x.ok("dancer X small mechanic: she walks and fires freely, the ring moves with her",
			p.pos.distance_to(p0) > 1.0 and k.bolts > b0 and at.distance_to(Vector2(p.pos.x, p.pos.z)) < 0.2
			and k.move_k() >= 1.0, "moved %.2f bolts +%d" % [p.pos.distance_to(p0), k.bolts - b0])
	a_x.ok("dancer X: the dance plays on through her walking and her plain bolts (a stance: the legs keep walking)",
			bool(kept["dance"]) and bool(KMovesDJ.MOVES[ThiefUlt.DANCE]["stance"]))
	var into := float(u.st["t"]) - float(d["grow"])
	p.dashes = p.max_dashes()
	p.inp["move"] = Vector2(0, 1)
	p.do_dash()
	var flip := k.anim_id
	a_x.step(m, 0.55)
	p.inp["move"] = Vector2.ZERO
	var off_beat := fmod(m.time - k.anim_at - into - 0.55 + 0.8, 0.8)
	a_x.ok("dancer X: a Vault flips out of the dance and it picks up again on the beat", flip in ThiefKit.CARTWHEELS
			and k.anim_id == ThiefUlt.DANCE and minf(off_beat, 0.8 - off_beat) < 0.05,
			"%s, off %.3f" % [flip, off_beat])
	a_x.step(m, 1.1)
	a_x.ok("dancer X: no foe in the ring, no bond (never on the cast alone)", u.casts == 2 and not u.running()
			and _owed(p) == 0.0, "owed %.2f" % _owed(p))
	a_x.ok("dancer X: its moves are keyed (cast, throws)", ["thf_encore", ThiefUlt.DANCE]
			.all(func(mv): return not HunterAnim.km_sample(mv, 0.05).is_empty()))
	await a_x.done(m)

## One cast of Encore against dummies that stand still while Sable stands or walks (`walk` m/s along +x).
## Returns each foe's landings: {foe id: [[seconds since the cast, hp lost], ...]}; `rings` is the ring's radius
## and the foe's distance at every beat, so a check can say which volleys a foe was in reach of.
func _cast_log(m: Match, p: Hunter, foes: Dictionary, walk: float, rings: Array) -> Dictionary:
	var u: ThiefUlt = (p.ak as ThiefKit).encore
	var log := {}
	var hp := {}
	for id in foes:
		log[id] = []
		hp[id] = (foes[id] as Hunter).hp
	p.ak.cd["x"] = 0.0
	var t0: float = m.time
	HunterKeys.ult_pressed(p)
	var beats := u.beat
	while u.running() or m.time - t0 < 2.7:
		p.inp["move"] = Vector2(1, 0) if walk > 0.0 else Vector2.ZERO
		a_x.step(m, a_x.DT)
		if u.beat > beats:
			beats = u.beat
			var row := {"t": m.time - t0, "r": u.radius()}
			for id in foes:
				row[id] = p.pos.distance_to((foes[id] as Hunter).pos)
			rings.append(row)
		for id in foes:
			var f: Hunter = foes[id]
			if f.hp < float(hp[id]) - 0.001:
				(log[id] as Array).append([m.time - t0, float(hp[id]) - f.hp])
				hp[id] = f.hp
	p.inp["move"] = Vector2.ZERO
	return log

## The ring against the source's Death Blossom rows (docs/heroes/thief.md "Death Blossom: source vs ours"):
## a dummy standing still in the band, in the middle and just out of reach, then one the ring passes over
## while she walks past it.
func dancer_ring(a) -> void:
	a_x = a
	var r = a_x.setup("thief", 4.6, "", true)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var t2: Hunter = r[3]
	var home: Vector3 = r[4]
	var d := (p.ak as ThiefKit).x_def()
	var reach := float(d["reach"])
	_open(p)
	t.teleport(home + Vector3(reach * float(d["rim"]) + 0.3, 0, 0))   # in the outer band
	t2.teleport(home + Vector3(0, 0, 2.0))                            # in the middle
	var out_at := home + Vector3(0, 0, -(reach + t.r + 0.3))
	var far: Hunter = m.make_hunter("T3", 5, "medium", "Target3", "idle", {}, out_at, {"arch": "none"})
	far.max_hp = 10000.0
	far.hp = far.max_hp
	far.armor = 0.0
	far.max_armor = 0.0
	var rings := []
	var still := _cast_log(m, p, {"rim": t, "mid": t2, "far": far}, 0.0, rings)
	var rim_hits: Array = still["rim"]
	var mid_hits: Array = still["mid"]
	var gap_max := 0.0
	var gap_min := 9.0
	for i in range(1, rim_hits.size()):
		var gap: float = float(rim_hits[i][0]) - float(rim_hits[i - 1][0])
		gap_max = maxf(gap_max, gap)
		gap_min = minf(gap_min, gap)
	var power: float = (p.ak as ThiefKit).power("x")
	a_x.ok("dancer ring: a standing dummy takes a blade every 0.2s for 2s (10, the first at 0.4s plus the flight)",
			rim_hits.size() == 10 and mid_hits.size() == 10 and absf(float(rim_hits[0][0]) - 0.4) < 0.2
			and gap_max < 0.25 and gap_min > 0.15, "%d hits, first %.2fs, gaps %.2f..%.2f" % [
			rim_hits.size(), float(rim_hits[0][0]), gap_min, gap_max])
	var grow_bh := float(d["r0"]) / AimKit.BH
	var reach_bh := reach / AimKit.BH
	var cadence := float(d["time"]) / float(d["shots"])
	a_x.ok("dancer ring: 0.17 to 3 bh in 0.4s, 2s of blades 0.2s apart, the band hits harder, a 6s blight",
			absf(grow_bh - 0.17) < 0.03 and absf(reach_bh - 3.0) < 0.05 and float(d["grow"]) == 0.4
			and float(d["time"]) == 2.0 and absf(cadence - 0.2) < 0.001
			and float(d["rim_dmg"]) > 0.0 and float(d["rim_blight"]) == 6.0,
			"%.2f bh -> %.2f bh" % [grow_bh, reach_bh])
	a_x.ok("dancer ring: 4 a blade in the middle, 6 from the band (x power); none past the radius",
			absf(float(mid_hits[0][1]) - float(d["dmg"]) * power) < 0.01
			and absf(float(rim_hits[0][1]) - (float(d["dmg"]) + float(d["rim_dmg"])) * power) < 0.01
			and (still["far"] as Array).is_empty(), "mid %.2f rim %.2f power %.2f" % [
			float(mid_hits[0][1]), float(rim_hits[0][1]), power])
	# the ring passes over a dummy while she walks: every beat's blade follows where the foe is then
	t2.teleport(home + Vector3(0, 0, 9.0))
	far.teleport(home + Vector3(0, 0, -9.0))
	p.teleport(home)
	t.teleport(home + Vector3(8.0, 0, 0))
	t.hp = t.max_hp
	rings.clear()
	var walked := _cast_log(m, p, {"foe": t}, 1.0, rings)
	var hits: Array = walked["foe"]
	var in_reach := 0
	var in_band := 0
	var want := 0.0
	for row in rings:
		if float(row["foe"]) < float(row["r"]) + t.r:
			in_reach += 1
			var band: bool = float(row["foe"]) > float(row["r"]) * float(d["rim"])
			in_band += 1 if band else 0
			want += (float(d["dmg"]) + (float(d["rim_dmg"]) if band else 0.0)) * power
	var got := 0.0
	for h in hits:
		got += float(h[1])
	a_x.ok("dancer ring: walking, a blade lands for every beat the foe is inside, 6 in the band, 4 inside it",
			hits.size() == in_reach and in_band > 0 and in_band < in_reach and absf(got - want) < 0.01,
			"%d of %d beats (%d in the band), %.0f damage (%.0f by the beats), she walked %.1fm" % [
			hits.size(), rings.size(), in_band, got, want, p.pos.x - home.x])
	await a_x.done(m)

# ------------------------------------------------------------------ Kael: Gilded Riposte
func zedran(a) -> void:
	a_x = a
	var r = a_x.setup("juggernaut", 2.6, "", true)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var t2: Hunter = r[3]
	var home: Vector3 = r[4]
	var k: JuggernautKit = p.ak
	var u: JuggernautUlt = k.riposte
	var d := k.x_def()
	_gate(p, "juggernaut")
	t.teleport(home + Vector3(2.6, 0, 0))
	t2.teleport(home + Vector3(-6.0, 0, 3.0))
	a_x.aim_at(p, t.pos)
	p.hp = p.max_hp * 0.5
	k.res = 0.0
	HunterKeys.ult_pressed(p)
	m.step(a_x.DT)
	var lane: Dictionary = AimKit.entry(p, "ult")
	a_x.ok("juggernaut X: the guard goes up: gold glow, the strip ahead everyone sees (1 x 2 bh), planted",
			u.guarding() and u.glow != null and u.glow.visible and bool(lane.get("all", false))
			and absf(float(lane.get("len", 0.0)) - 3.6) < 0.05 and absf(float(lane.get("width", 0.0)) - 1.8) < 0.05
			and k.move_k() <= 0.0, "len %.2f width %.2f" % [float(lane.get("len", 0.0)), float(lane.get("width", 0.0))])
	a_x.ok("juggernaut X: its cooldown runs from the cast (22s)", absf(float(k.cd["x"]) - float(d["cooldown"])) < 0.1)
	# planted: no walking, no jumping, no other buttons
	var p0 := p.pos
	p.inp["jump"] = true
	a_x.step(m, 0.2, func(): p.inp["move"] = Vector2(0, 1))
	p.inp["move"] = Vector2.ZERO
	a_x.ok("juggernaut X small mechanic: planted through the guard (no walk, no jump, no Smash)",
			p.pos.distance_to(p0) < 0.1 and k.busy(), "moved %.2f" % p.pos.distance_to(p0))
	# invulnerable: hits do nothing and can't stun; each one blocked (two at most) makes the answer harder
	var hp0 := p.hp
	p.hurt(30.0, t2, {"src": "shot", "stun": 1.0})
	a_x.step(m, 0.1)
	p.hurt(30.0, t2, {"src": "shot"})
	p.hurt(30.0, t2, {"src": "shot"})
	a_x.step(m, 0.1)
	p.hurt(30.0, t2, {"src": "shot"})
	a_x.ok("juggernaut X small mechanic: the guard blocks every hit and its stun; blocks count (two at most)",
			p.hp == hp0 and p.stun_t <= 0.0 and u.blocked == 3 and int(u.st["blocks"]) == 2,
			"hp %.0f -> %.0f blocked %d" % [hp0, p.hp, u.blocked])
	a_x.ok("juggernaut X: no bond before the strike lands (blocking pays nothing)", _owed(p) == 0.0)
	a_x.step(m, 0.5)
	var dealt_blocked := u.last_dealt
	a_x.ok("juggernaut X: the cleave lands after 0.65s, he lunges about 1 bh into it",
			u.strikes == 1 and a_x.dmg(t) > 0.0 and p.pos.distance_to(p0) > 1.3, "took %.0f moved %.2f" % [a_x.dmg(t),
					p.pos.distance_to(p0)])
	a_x.ok("juggernaut X: he heals 80% of what it deals",
			absf(u.last_healed - 0.8 * u.last_dealt) < 1.0, "dealt %.0f healed %.0f" % [u.last_dealt, u.last_healed])
	a_x.ok("juggernaut X: landing it on a hunter fills the bond (a hit: 60% of the bar, KinBond.from_ult)",
			absf(_owed(p) - 0.6) < 0.001, "owed %.2f" % _owed(p))
	a_x.step(m, 0.5)
	a_x.ok("juggernaut X: about 1.1s in all, then he walks again", not u.running() and k.move_k() >= 1.0)
	# the same cleave with nothing blocked: two blocks made it 40% harder
	a_x.fresh(t)
	t.teleport(home + Vector3(2.6, 0, 0))
	p.teleport(home)
	a_x.aim_at(p, t.pos)
	k.res = 0.0
	k.cd["x"] = 0.0
	HunterKeys.ult_pressed(p)
	a_x.step(m, 0.9)
	a_x.ok("juggernaut X small mechanic: two hits blocked make the answer 40% harder",
			absf(dealt_blocked / maxf(0.01, u.last_dealt) - 1.4) < 0.03, "%.1f vs %.1f" % [dealt_blocked, u.last_dealt])
	# blighted, the heal barely takes
	a_x.step(m, 0.4)
	a_x.fresh(t)
	t.teleport(home + Vector3(2.6, 0, 0))
	p.teleport(home)
	p.hp = p.max_hp * 0.5
	p.blight_t = 3.0
	k.cd["x"] = 0.0
	HunterKeys.ult_pressed(p)
	a_x.step(m, 0.9)
	a_x.ok("juggernaut X small mechanic: blighted, the heal barely takes",
			u.last_healed < 0.5 * 0.8 * u.last_dealt, "healed %.0f of %.0f" % [u.last_healed, u.last_dealt])
	p.blight_t = 0.0
	a_x.step(m, 0.4)
	# a miss: nothing hit, no heal and no bond
	t.teleport(home + Vector3(0, 0, 6.0))
	p.teleport(home)
	k.cd["x"] = 0.0
	HunterKeys.ult_pressed(p)
	a_x.step(m, 1.3)
	a_x.ok("juggernaut X: a miss pays no bond and heals nothing", _owed(p) == 0.0
			and u.last_dealt == 0.0)
	# a knock with it makes it ready again at once
	a_x.fresh(t)
	t.teleport(home + Vector3(2.6, 0, 0))
	p.teleport(home)
	a_x.aim_at(p, t.pos)
	t.hp = 10.0
	k.cd["x"] = 0.0
	HunterKeys.ult_pressed(p)
	a_x.step(m, 0.9)
	var knock_paid := _owed(p)
	a_x.ok("juggernaut X small mechanic: knocking a hunter with it resets it; the bond counts the knock (0.7)",
			t.downed and u.resets == 1 and float(k.cd["x"]) <= 0.0 and absf(knock_paid - 0.7) < 0.001,
			"cd %.1f bond %.2f" % [float(k.cd["x"]), knock_paid])
	# the reset is for taking a hunter down: a hunter already down takes nothing from it, a plain hit resets nothing
	a_x.step(m, 0.5)
	a_x.fresh(t)
	t.teleport(home + Vector3(2.6, 0, 0))
	p.teleport(home)
	a_x.aim_at(p, t.pos)
	t.downed = true
	t.hp = 0.0
	t.down_hp = 500.0
	k.cd["x"] = 0.0
	var resets0 := u.resets
	HunterKeys.ult_pressed(p)
	a_x.step(m, 0.9)
	a_x.ok("juggernaut X small mechanic: a hunter already knocked takes nothing, no kill, the cooldown keeps running",
			u.last_dealt == 0.0 and u.resets == resets0 and float(k.cd["x"]) > 1.0,
			"dealt %.0f resets %d cd %.1f" % [u.last_dealt, u.resets - resets0, float(k.cd["x"])])
	a_x.step(m, 0.5)
	a_x.fresh(t)
	t.downed = false
	t.teleport(home + Vector3(2.6, 0, 0))
	p.teleport(home)
	a_x.aim_at(p, t.pos)
	k.cd["x"] = 0.0
	HunterKeys.ult_pressed(p)
	a_x.step(m, 0.9)
	a_x.ok("juggernaut X small mechanic: a hit that leaves the hunter up resets nothing",
			not t.downed and u.resets == resets0 and float(k.cd["x"]) > 1.0, "resets %d cd %.1f" % [u.resets - resets0,
					float(k.cd["x"])])
	# the data's "killing a living enemy" counts a monster too (the footage resets on a dummy kill, f99-f101)
	a_x.step(m, 0.5)
	a_x.fresh(t)
	t.teleport(home + Vector3(-2.5, 0, 0))     # behind him, out of the strip (and on the floor)
	p.teleport(home)
	var mob: Mob = m.spawn_mob("skitter", home + Vector3(2.6, 0, 0))
	mob.held = true           # a standing dummy, as in the footage
	mob.hp = 5.0
	a_x.aim_at(p, mob.pos)
	k.cd["x"] = 0.0
	HunterKeys.ult_pressed(p)
	for _i in int(0.9 / a_x.DT):     # m.step, not A.step: A.step clears every monster each tick
		m.step(a_x.DT)
	a_x.ok("juggernaut X small mechanic: killing a monster with it resets it (the source's living enemy)",
			mob.dead and u.resets > resets0 and float(k.cd["x"]) <= 0.0,
			"dead %s resets %d cd %.1f at %s" % [mob.dead, u.resets - resets0, float(k.cd["x"]), mob.pos - p.pos])
	if not mob.dead:
		mob.die()
	a_x.ok("juggernaut X: its moves are keyed (guard, cleave)", ["jug_guard", "jug_riposte"]
			.all(func(mv): return not HunterAnim.km_sample(mv, 0.05).is_empty()))
	_cleave_fits(u.data())
	_guard_attacks(m, p, t, t2, home)
	await _recovery_exits()
	_recovery(m, p, t, home)
	await a_x.done(m)
	var got: Dictionary = await EXIT.run(a_x, "juggernaut")
	a_x.ok("juggernaut X exit: Shift, LMB and jump pressed 0.1s before the cleave lands go on its first free step",
			EXIT.on_time(got), EXIT.said(got))

## The recovery plays its own clip (jug_ult_recover) for exactly the 0.35 s at half speed, then he is free; a jump or
## Shift cuts it on the press frame. Timing and speed are the ult's own (recover 0.35, move_k 0.5), unchanged.
func _recovery(m: Match, p: Hunter, t: Hunter, home: Vector3) -> void:
	var k: JuggernautKit = p.ak
	var u: JuggernautUlt = k.riposte
	var recover := float(u.data()["recover"])
	var rows := []
	a_x.step(m, 0.5)           # (the scenario before this one is still recovering)
	for cut in ["none", "jump", "dash"]:
		a_x.fresh(t)
		t.teleport(home + Vector3(2.6, 0, 0))
		p.teleport(home)
		a_x.aim_at(p, t.pos)
		k.cd["x"] = 0.0
		HunterKeys.ult_pressed(p)
		a_x.step(m, 0.65 + float(u.data()["strike_t"]) + 0.03)     # (the guard, the cleave, a frame into the recovery)
		var played: bool = String(u.st.get("phase", "")) == "recover" and k.anim_id == "jug_ult_recover" \
				and k.move_k() == 0.5
		a_x.step(m, 0.1)
		var mid: bool = k.anim_id == "jug_ult_recover"
		if cut == "jump":
			p.do_jump()
		elif cut == "dash":
			p.do_dash()
		m.step(a_x.DT)
		var cut_now: bool = cut == "none" or (k.anim_id != "jug_ult_recover" and not u.running())
		a_x.step(m, recover)
		rows.append([cut, played, mid, cut_now, k.anim_id != "jug_ult_recover" and not u.running()])
		a_x.step(m, 0.3)
	a_x.ok("juggernaut X: the recovery plays its own clip at half speed (the 0.35 s unchanged)",
			rows.all(func(r): return r[1] and r[2]), str(rows))
	a_x.ok("juggernaut X: a jump or Shift cuts the recovery clip on the press frame, and it ends on time",
			rows.all(func(r): return r[3] and r[4]), str(rows))

## The cleave is a tall crescent standing along the aim (tilt 90, leaning toward the camera so it never shows
## edge-on): its tip at the strip's far end, its back edge inside the strip, at full lean no wider than the strip
## (+20%) and still taller than a Hunter.


## One cast with a bot attacker landing `at` s into the guard: "rifle" is a stream of three 6-damage shots 0.13s
## apart (the rifle's own rate), "stun" one hit with a 1.5s stun and a knock, "none" nothing. The foe is
## `foe_at` m ahead.
## Returns what the guard let through and what the strike did.
func _guard_case(m: Match, p: Hunter, t: Hunter, t2: Hunter, home: Vector3, kind: String, at: float,
		foe_at := 2.6) -> Dictionary:
	var k: JuggernautKit = p.ak
	var u: JuggernautUlt = k.riposte
	a_x.step(m, 1.5)
	a_x.fresh(t)
	a_x.fresh(p)
	t.teleport(home + Vector3(foe_at, 0, 0))
	t2.teleport(home + Vector3(-6.0, 0, 3.0))
	p.teleport(home)
	p.vel = Vector3.ZERO
	p.hp = p.max_hp
	a_x.aim_at(p, t.pos)
	k.cd["x"] = 0.0
	k.res = 0.0               # (the last strike's Rage would add its +15% to this one)
	k.enraged_t = 0.0
	var t0 := m.time
	var strikes0 := u.strikes
	HunterKeys.ult_pressed(p)
	var shots := []
	if kind == "stun":
		shots = [at]
	elif kind == "rifle":
		shots = [at, at + 0.13, at + 0.26]
	var out := {"in_guard": 0.0, "after": 0.0, "stun": 0.0, "kb": 0.0}
	for st in shots:
		while m.time - t0 < float(st):
			m.step(a_x.DT)
		var hp0 := p.hp
		var in_guard := u.guarding()
		if kind == "stun":
			p.hurt(8.0, t2, {"src": "abil", "stun": 1.5, "kb": Vector2(6.0, 0.0), "dr": true})
			out["stun"] = maxf(float(out["stun"]), p.stun_t)
			out["kb"] = maxf(float(out["kb"]), Vector2(p.vel.x, p.vel.z).length())
		else:
			p.hurt(6.0, t2, {"src": "shot"})
		var slot := "in_guard" if in_guard else "after"
		out[slot] = float(out[slot]) + hp0 - p.hp
	while m.time - t0 < 0.9:         # the strike has landed (0.75s)
		m.step(a_x.DT)
	out["strikes"] = u.strikes - strikes0
	out["dealt"] = u.last_dealt
	return out

## Kael's guard against two bot attackers (the source's Retaliation: no damage and no crowd control for 0.65s, then
## the strike): a rifle stream and a stun, each landed 0.2s and 0.5s into the guard, then the strike's damage and reach.
func _guard_attacks(m: Match, p: Hunter, t: Hunter, t2: Hunter, home: Vector3) -> void:
	var base := float(p.ak.x_def()["dmg"])
	for at in [0.2, 0.5]:
		var r := _guard_case(m, p, t, t2, home, "rifle", at)
		a_x.ok("juggernaut X guard: a rifle stream from %.1fs in takes nothing, the strike lands" % at,
				float(r["in_guard"]) == 0.0 and int(r["strikes"]) == 1,
				"in guard %.0f, after %.0f, strike %.1f (base %.0f)" % [r["in_guard"], r["after"], r["dealt"], base])
		r = _guard_case(m, p, t, t2, home, "stun", at)
		a_x.ok("juggernaut X guard: a stun and knock landed %.1fs in does not apply, the strike lands" % at,
				float(r["in_guard"]) == 0.0 and float(r["stun"]) == 0.0 and float(r["kb"]) < 0.5
				and int(r["strikes"]) == 1,
				"damage %.0f stun %.2f push %.2f strike %.1f" % [r["in_guard"], r["stun"], r["kb"], r["dealt"]])
	var one := _guard_case(m, p, t, t2, home, "stun", 0.5)
	a_x.ok("juggernaut X guard: the strike with one hit blocked does %.0f x 1.2" % base,
			absf(float(one["dealt"]) - base * 1.2) < 0.5, "dealt %.1f" % float(one["dealt"]))
	var near := _guard_case(m, p, t, t2, home, "none", 0.0, 3.4)
	var far := _guard_case(m, p, t, t2, home, "none", 0.0, 4.6)
	a_x.ok("juggernaut X guard: the strike hits a foe 3.4m ahead and misses one 4.6m ahead",
			float(near["dealt"]) > 0.0 and float(far["dealt"]) == 0.0,
			"3.4m %.1f, 4.6m %.1f" % [near["dealt"], far["dealt"]])

## The cleave's crescent is the strip's leading edge: its tip at the strip's end, as wide as the strip (+20% at most).
func _cleave_fits(d: Dictionary) -> void:
	var ln := float(d["len"])
	var w := float(d["width"])
	var fits := true
	var tall := INF
	for layer: Dictionary in HeroVfx.data("juggernaut")["moves"]["riposte_land"]["fx"]:
		if layer["p"] != "sweep":
			continue
		var radius := float(layer["size"])
		var half := deg_to_rad(float(layer["arc"])) * 0.5
		var lean := deg_to_rad(float(layer.get("lean", 0.0)))
		var mid := float(layer["fwd_x"]) * ln
		tall = minf(tall, float(layer["y"]) + radius * sin(half) * cos(lean))
		var side := radius * sin(half) * sin(lean)
		fits = fits and float(layer["tilt"]) == 90.0 and lean > 0.0 and mid + radius < ln + 0.4 \
				and mid - radius * cos(half) > 0.0 and mid + radius > ln - 0.1 and side <= w * 0.6
	a_x.ok("juggernaut X: the cleave's crescent stands tall inside its strip", fits and tall >= CLEAVE_TALL,
			"top %.2f m at full lean (at least %.1f), strip %.1f x %.1f m" % [tall, CLEAVE_TALL, ln, w])

# ------------------------------------------------------------------ combos, merge holds, the burst cap
func combos(a) -> void:
	a_x = a
	await _bola_encore()
	await _chain_riposte()
	await _merge_holds()
	await _burst_cap()

## The sheet's natural combo: Bola grounds a foe, then Encore: Grounded, they can't leave the ring.
func _bola_encore() -> void:
	var r = a_x.setup("thief", 3.5)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var k: ThiefKit = p.ak
	_open(p)
	a_x.aim_at(p, t.pos)
	k.ch_rmb = 1.0
	k.cd["rmb"] = 0.0
	a_x.tap(m, p)
	a_x.step(m, 0.7)
	var grounded := KitStatus.grounded(t)
	HunterKeys.ult_pressed(p)
	a_x.step(m, 2.5)
	a_x.ok("combo dancer: Bola > X = the Grounded foe takes every blade", grounded and k.encore.blades == 10,
			"grounded %s blades %d" % [grounded, k.encore.blades])
	await a_x.done(m)

## The sheet's combo for Kael: chain in, eat their answer in the guard, cleave back.
func _chain_riposte() -> void:
	var r = a_x.setup("juggernaut", 6.0)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var k: JuggernautKit = p.ak
	_open(p)
	a_x.aim_at(p, t.pos)
	k.cd["e"] = 0.0
	k.use_e()
	a_x.step(m, 0.4)
	k.use_e()
	a_x.step(m, 0.5)
	a_x.aim_at(p, t.pos)
	HunterKeys.ult_pressed(p)
	p.hurt(25.0, t, {"src": "shot"})
	a_x.step(m, 0.9)
	a_x.ok("combo jug: E > E > X = pulled in, a hit blocked, the cleave lands",
			k.warchain.reels >= 1 and k.riposte.blocked == 1 and k.riposte.strikes == 1 and a_x.dmg(t) > 20.0,
			"reels %d blocked %d took %.0f" % [k.warchain.reels, k.riposte.blocked, a_x.dmg(t)])
	await a_x.done(m)

## A merge starting mid-ultimate ends it: no blade or cleave fires after, the telegraphs go.
func _merge_holds() -> void:
	var r = a_x.setup("thief", 3.0, "cindle")
	var m: Match = r[0]
	var p: Hunter = r[1]
	var tk: ThiefKit = p.ak
	_open(p)
	HunterKeys.ult_pressed(p)
	a_x.step(m, 0.5)
	p.ult = 1.0
	p.merge_cd = 0.0
	KinMerge.cast(p)
	var b0 := tk.encore.blades
	a_x.step(m, 1.6)
	a_x.ok("merge hold dancer: Encore's blades stop and its ring goes (hold field encore.st)",
			not tk.encore.running() and tk.encore.blades == b0 and not AimKit.shown(p, "ult") and KinMerge.active(p),
			"blades after %d" % (tk.encore.blades - b0))
	await a_x.done(m)
	r = a_x.setup("juggernaut", 2.6, "cindle")
	m = r[0]
	p = r[1]
	var t: Hunter = r[2]
	var jk: JuggernautKit = p.ak
	_open(p)
	a_x.aim_at(p, t.pos)
	HunterKeys.ult_pressed(p)
	a_x.step(m, 0.2)
	p.ult = 1.0
	p.merge_cd = 0.0
	KinMerge.cast(p)
	a_x.step(m, 1.0)
	a_x.ok("merge hold jug: the Riposte's guard drops, no cleave (hold field riposte.st)",
			not jk.riposte.running() and jk.riposte.strikes == 0 and not jk.riposte.glow.visible
			and KinMerge.active(p), "running %s strikes %d merged %s" % [jk.riposte.running(), jk.riposte.strikes,
					KinMerge.active(p)])
	await a_x.done(m)

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
	a_x.ok("burst cap: X then a merge (and its ultimate) never one-shots a full-health hunter",
			knocked.is_empty(), "least health left %.0f%% %s" % [worst * 100.0, str(knocked)])

## One burst run: the share of the target's health left (0 when knocked).
func _burst(hero: String, sp: String) -> float:
	var r = a_x.setup(hero, 4.6 if hero == "thief" else 2.6, sp)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	_open(p)
	p.lvl = 10
	a_x.fresh(t)
	a_x.aim_at(p, t.pos)
	HunterKeys.ult_pressed(p)
	if hero == "juggernaut":
		p.hurt(10.0, t, {"src": "shot"})
		a_x.step(m, 0.1)
		p.hurt(10.0, t, {"src": "shot"})
	a_x.step(m, 2.5 if hero == "thief" else 0.85)
	a_x.merge_now(p)
	a_x.step(m, float(MergeForm.data()["xform_s"]) + 0.12)
	var mk := MergeKit.of(p)
	if mk != null:
		mk.age = 99.0
	a_x.aim_at(p, t.pos)
	p.inp["ult"] = true
	a_x.step(m, 2.0, func(): a_x.aim_at(p, t.pos))
	var left := 0.0 if t.downed or t.hp <= 0.0 else t.hp / t.max_hp
	await a_x.done(m)
	return left

# ------------------------------------------------------------------ Kael: leaving the recovery
const TRACE := 12                # physics frames traced from the press

## One fresh cast, then `key` ("jump" or "dash") held for one physics step on recovery frame `frame` (1 = the
## first step after the cleave landed; 0: no ult, the control from rest). Walks forward throughout. Returns the
## recovery's state at the press (`phase`), whether it was over after that same step (`left`), the first traced
## frame the jump or dash showed (`moved`, 1 = the press frame), the frames with no travel (`still`), the travel
## (`reach`) and the top speed (`top`) over the trace, and with no key how many steps the recovery lasts (`n`).
func _exit_trial(frame: int, key: String) -> Dictionary:
	var r = a_x.setup("juggernaut", 9.0)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var k: JuggernautKit = p.ak
	var u: JuggernautUlt = k.riposte
	_open(p)
	p.inp["move"] = Vector2(0, 1)
	var seen := {"n": 0, "phase": "", "left": false, "moved": 0, "still": 0, "reach": 0.0, "top": 0.0}
	if frame > 0:
		HunterKeys.ult_pressed(p)
		while String(u.st.get("phase", "")) != "recover":
			m.step(a_x.DT)
		if key == "":
			while u.running():
				m.step(a_x.DT)
				seen["n"] += 1
		for i in frame - 1:
			m.step(a_x.DT)
	seen["phase"] = String(u.st.get("phase", ""))
	var y0 := p.pos.y
	var d0 := p.dashes
	for i in TRACE:
		var from := p.pos
		p.inp[key] = key != "" and i == 0
		m.step(a_x.DT)
		p.inp[key] = false
		var dx := Vector2(p.pos.x - from.x, p.pos.z - from.z).length()
		seen["reach"] += dx
		seen["still"] += 1 if dx < 0.001 else 0
		seen["top"] = maxf(float(seen["top"]), Vector2(p.vel.x, p.vel.z).length())
		var went := p.pos.y > y0 + 0.01 if key == "jump" else p.dashes < d0 - 0.01
		if went and int(seen["moved"]) == 0:
			seen["moved"] = i + 1
		if i == 0:
			seen["left"] = not u.running()
	await a_x.done(m)
	return seen

## The recovery (0.35s, half speed) is left by a jump or Shift on the very physics frame it is pressed, from its
## first frame to its last: it is over that frame, and nothing of the 50% walk goes into the jump (it reaches full
## run speed) or the dash (its travel and stops are the plain dash's, the control from rest).
func _recovery_exits() -> void:
	var n: int = (await _exit_trial(1, ""))["n"]
	a_x.ok("juggernaut X recovery: 0.35s is %d physics frames" % n, n == roundi(0.35 / a_x.DT), "%d frames" % n)
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
			a_x.ok("juggernaut X recovery: %s on frame %d of %d goes that frame, no stop, no 50%% cap" % [key, frame,
					n],
					same and plain, info + ", reach %.2f (%.2f), top %.2f (%.2f)" % [got["reach"], control["reach"],
							got["top"], control["top"]])

func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.02

## VFX_QUALITY zone rule on Encore's ring as drawn (AimShapes, not the data): her signature violet, a lit rim, the
## centre at most AimShapes.SOFT_A, also at a beat's pulse (`alpha`).
static func _soft_ring(a_v, p: Hunter, e: Dictionary, alpha: float) -> void:
	var got: Array = load("res://tools/aimkit_check.gd").measure(e, 0.0, float(e.get("r", 0.0)) - 0.05)
	a_v.ok("dancer X: the ring is a lit %s rim over a faint inside at alpha %.1f (centre %.2f <= %.2f, rim %.2f)"
			% [AimKit.hero_col(p).to_html(false), alpha, got[0], AimShapes.SOFT_A, got[1]],
			bool(e.get("soft", false)) and (e.get("col", Color.BLACK) as Color).is_equal_approx(AimKit.hero_col(p))
			and float(e.get("alpha", 0.0)) >= alpha - 0.05 and got[0] > 0.0
			and got[0] <= AimShapes.SOFT_A + 0.001 and got[1] >= 0.5, str(e.get("col")))
