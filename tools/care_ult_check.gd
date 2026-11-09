extends RefCounted
## The support pair's ultimates on X, run by tools/support_check.gd inside --tender-combo-check,
## --rimewright-combo-check and --support-check: the level gate, the aim telegraph, the cast, the
## payoff, the cooldown, the small mechanics, the bond paid only when it lands, the merge-start drop,
## and (burst_cap) that the ult followed straight by a merge never knocks a full-health hunter.

const CC := preload("res://tools/cc_probe.gd")

var sc        # the SupportCheck running us (setup, step, ok, aim_at, down)


func ok(what: String, cond: bool, info := "") -> void:
	sc.ok(what, cond, info)


func step(m: Match, secs: float) -> void:
	sc.step(m, secs)


func _free(m: Match) -> void:
	m.queue_free()
	await sc.main.get_tree().process_frame


## Presses X the way the match does (main's HunterKeys.ult_pressed: the level gate, then the kit's cast_ult).
func _press(P: Hunter, m: Match) -> void:
	HunterKeys.ult_pressed(P)
	step(m, 1.0 / 60.0)


## What the bond meter owes the current ult cast (KinBond.from_ult keeps the best event per cast id).
func _owed(K: ArchKit) -> float:
	var c: Dictionary = K.h.get_meta("bond_cast", {})
	return float(c.get("got", 0.0)) if String(c.get("id", "")) == HeroUlt.cast_id(K) else 0.0


## The bond event the kit's current X cast paid for (boki_system.json bond_from_ult: hit, knock, kill), "" for none.
func _bond_kind(K: ArchKit) -> String:
	var got := _owed(K)
	var rules := KinBond.rules()
	for kind in KinBond.KINDS:
		if got > 0.0 and absf(float(rules.get(kind, -1.0)) - got) < 0.001:
			return kind
	return ""


# ================================================================== Pip: Hearth Call
func tender() -> void:
	var r: Array = sc.setup("tender", 14.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var A: Hunter = r[2]
	var K: TenderKit = P.ak
	var xd: Dictionary = K.x_def()
	ok("mm X: Hearth Call is in the kit data, sounds load", String(xd.get("name", "")) == "Hearth Call"
		and Sfx.streams.has("tend_call") and Sfx.streams.has("tend_arrive"))
	sc.aim_at(P, A.pos)
	# --- the level gate: nothing below level 6
	P.lvl = 5
	_press(P, m)
	ok("mm X: below level 6 it does nothing", K.hearth_call.is_empty() and float(K.cd["x"]) <= 0.0)
	P.lvl = 6
	# --- the aim telegraph: ready, the cursor on a teammate in reach: the reach ring, a line, a pick ring
	A.hp = A.max_hp * 0.4
	var a_hp0 := A.hp
	step(m, 0.1)
	var ring: Dictionary = AimKit.entry(P, "x")
	var aiming := K.hearth_call.is_empty() and AimKit.shown(P, "x_line") and AimKit.shown(P, "x_pick")
	ok("mm X: with the cursor on a teammate, the 7 bh reach ring and a line onto them", aiming
		and absf(float(ring.get("r", 0.0)) - 12.6) < 0.05)
	# --- X: the tether starts, cooldown runs, the cast move; no bond for the cast alone
	var calls0 := int(K.stats["calls"])
	_press(P, m)
	ok("mm X: one X press is one cast (main's X path only)", int(K.stats["calls"]) == calls0 + 1,
		"calls +%d" % (int(K.stats["calls"]) - calls0))
	ok("mm X: X starts the tether on that teammate with the cast move", not K.hearth_call.is_empty()
		and K.hearth_call["who"] == A and K.anim_id == "mm_call", K.anim_id)
	ok("mm X: its own cooldown (46 s) starts on the cast", absf(float(K.cd["x"]) - HeroUlt.cooldown(K)) < 0.2
		and HeroUlt.cooldown(K) == 46.0, "cd %.1f" % float(K.cd["x"]))
	ok("mm X: no bond is paid for the cast alone", _bond_kind(K) == "", _bond_kind(K))
	# --- the channel: she walks, the tether shows, the ring is shown to everyone, the teammate heals
	var p0 := P.pos
	P.inp["move"] = Vector2(-1, 0)
	step(m, 1.5)
	P.inp["move"] = Vector2.ZERO
	var walked := Vector2(P.pos.x - p0.x, P.pos.z - p0.z).length()
	ok("mm X: she walks while it channels (small mechanic)", walked > 2.0 and not K.hearth_call.is_empty(),
		"%.1f m" % walked)
	ok("mm X: the tether and the reach ring show for everyone", K.ulk().showing("tether")
		and bool(AimKit.entry(P, "x").get("all", false)) and K.anim_id == "mm_call_hold", K.anim_id)
	ok("mm X: the tether heals the teammate", A.hp > a_hp0 + 5.0, "%.0f -> %.0f" % [a_hp0, A.hp])
	# --- she can cast other things while it runs (wiki): Hearthlight goes up
	P.inp["sig"] = true
	step(m, 0.05)
	P.inp["sig"] = false
	var both_up := K.in_e() and not K.hearth_call.is_empty()
	ok("mm X: other abilities still cast during the channel (small mechanic)", both_up)
	K.cd["e"] = 0.0
	# --- X again while it runs is swallowed
	_press(P, m)
	ok("mm X: X again does not end or restart it", not K.hearth_call.is_empty())
	# --- the end: completed, the bond pays the complete share, the teammate's own meter a little
	step(m, 3.6)
	ok("mm X: a completed channel pays the bond as a hit (KinBond.from_ult)",
		K.hearth_call.is_empty() and _bond_kind(K) == "hit",
		_bond_kind(K))
	ok("mm X: the end plays its own move", K.anim_id == "mm_call_end", K.anim_id)
	# --- on cooldown: X does nothing
	_press(P, m)
	ok("mm X: on cooldown it does nothing", K.hearth_call.is_empty() and float(K.cd["x"]) > 30.0)
	await _free(m)
	await _tender_rescue()
	await _tender_breaks()


## A downed teammate: the tether heals them while they are down, and at the end they are pulled to
## her side and stood up (the bond's top event).
func _tender_rescue() -> void:
	var r: Array = sc.setup("tender", 14.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var A: Hunter = r[2]
	var K: TenderKit = P.ak
	A.teleport(P.pos + Vector3(-8.0, 0, 3.0))
	sc.down(m, A)
	step(m, 0.1)
	P.hp = P.max_hp * 0.5
	var p_hp0 := P.hp
	A.down_hp = float(Data.MATCH["down_hp"]) * 0.4
	var a_down0 := A.down_hp
	sc.aim_at(P, A.pos)
	_press(P, m)
	ok("mm X: it can be cast on a downed teammate", not K.hearth_call.is_empty() and A.downed)
	step(m, 2.0)
	ok(
		"mm X: the tether heals the downed teammate (game data: an ally or Wisp), not her",
		A.down_hp > a_down0 + 5.0 and P.hp <= p_hp0 + 0.01, "ally %.0f -> %.0f, her %.0f -> %.0f" % [
			a_down0, A.down_hp, p_hp0, P.hp])
	step(m, 3.2)
	var gap := P.flat_dist(A)
	ok("mm X: at the end a downed teammate is pulled to her side and stood up", not A.downed and gap < 1.6
		and int(K.stats["rescues"]) == 1, "downed %s gap %.1f" % [str(A.downed), gap])
	ok("mm X: a rescue pays the bond's top event (kill)", _bond_kind(K) == "kill", _bond_kind(K))
	await _free(m)


## Breaks: the teammate leaves the ring, or a merge starts. A broken channel pays nothing. A cursor on
## nobody casts nothing and keeps the cooldown.
func _tender_breaks() -> void:
	var r: Array = sc.setup("tender", 14.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var A: Hunter = r[2]
	var K: TenderKit = P.ak
	sc.aim_at(P, P.pos + Vector3(6.0, 0, -6.0))
	_press(P, m)
	ok("mm X: with nobody under the cursor nothing is cast and the cooldown is kept", K.hearth_call.is_empty()
		and float(K.cd["x"]) <= 0.0)
	sc.aim_at(P, A.pos)
	_press(P, m)
	step(m, 0.5)
	A.teleport(P.pos + Vector3(-16.0, 0, 0))
	step(m, 0.1)
	ok("mm X: it breaks when the teammate leaves the ring, and pays nothing", K.hearth_call.is_empty()
		and int(K.stats["broken"]) == 1 and _bond_kind(K) == "", _bond_kind(K))
	K.cd["x"] = 0.0
	A.teleport(P.pos + Vector3(-2.5, 0, 1.5))
	sc.aim_at(P, A.pos)
	step(m, 0.05)
	_press(P, m)
	step(m, 0.3)
	var up := not K.hearth_call.is_empty()
	K.drop_holds()
	step(m, 0.1)
	ok("mm merge: drop_holds ends Hearth Call (no pull, no bond)", up and K.hearth_call.is_empty()
		and not K.ulk().showing("tether") and not AimKit.shown(P, "x") and _bond_kind(K) == "")
	await _free(m)


# ================================================================== Claire: Rimelock
func rimewright() -> void:
	var r: Array = sc.setup("rimewright", 4.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[3]
	var K: RimewrightKit = P.ak
	var xd: Dictionary = K.x_def()
	ok("tm X: Rimelock is in the kit data, sounds load", String(xd.get("name", "")) == "Rimelock"
		and Sfx.streams.has("rime_lock") and Sfx.streams.has("rime_crash"))
	P.lvl = 5
	_press(P, m)
	ok("tm X: below level 6 it does nothing", K.rime.is_empty() and float(K.cd["x"]) <= 0.0)
	P.lvl = 6
	var meter0 := P.ult
	var h0 := T.hp
	var rimes0 := int(K.stats["rimes"])
	_press(P, m)
	ok("tm X: one X press is one cast (main's X path only)", int(K.stats["rimes"]) == rimes0 + 1,
		"rimes +%d" % (int(K.stats["rimes"]) - rimes0))
	step(m, 0.25)
	var ring: Dictionary = AimKit.entry(P, "x")
	ok("tm X: sealed in, the 4 bh rink shown to everyone, the cast move", not K.rime.is_empty()
		and bool(ring.get("all", false)) and absf(float(ring.get("r", 0.0)) - 7.2) < 0.05
		and K.ulk().showing("rink") and K.ulk().showing("bud") and K.anim_id in ["tm_rime", "tm_rime_hold"], K.anim_id)
	ok("tm X: its own cooldown (80 s, game data) starts on the cast, no bond for the cast",
		absf(float(K.cd["x"]) - 80.0) < 0.5
		and _bond_kind(K) == "")
	var php := P.hp
	P.hurt(30.0, T, {"src": "shot"})
	var p0 := P.pos
	P.inp["move"] = Vector2(1, 0)
	P.inp["fire"] = true
	var n_shots := m.shots.size()
	step(m, 0.5)
	P.inp["move"] = Vector2.ZERO
	P.inp["fire"] = false
	ok("tm X: inside the shell she is invulnerable and rooted, and nothing fires", P.hp >= php - 0.01
		and _moved(P, p0) < 0.2 and m.shots.size() == n_shots, "hp %.0f moved %.2f" % [P.hp - php, _moved(P, p0)])
	ok("tm X parity: sealed in she is Invulnerable, a pull, a knock and a slow take no hold either",
		CC.landed(m, P, T) == "" and K.cc_proof())
	var slow1 := T.slow_k
	var fill1 := float(AimKit.entry(P, "x").get("fill", 0.0))
	step(m, 1.6)
	ok("tm X: the slow on a foe in the rink stacks the longer they stay (small mechanic)", T.slow_k > slow1 + 0.15
		and T.slow_k <= float(xd["slow_max"]) + 0.001 and K.chilled(T), "%.2f -> %.2f" % [slow1, T.slow_k])
	ok(
			"tm X: the countdown fill (and the cracks) brighten as it builds",
			float(AimKit.entry(P, "x").get("fill", 0.0)) > fill1 + 0.3)
	ok("tm X: no damage before the crash", T.hp >= h0 - 6.0, "-%.0f" % (h0 - T.hp))
	step(m, 1.3)
	ok("tm X: it cracks open by itself at 3.5 s: damage and an ice-block stun", K.rime.is_empty()
		and int(K.stats["crashes"]) == 1 and h0 - T.hp > float(xd["dmg"]) * K.power("ult") * 0.95 and T.stun_t > 0.4,
		"dmg %.0f stun %.2f" % [h0 - T.hp, T.stun_t])
	ok("tm X: the crash plays its own move", K.anim_id == "tm_rime_crash", K.anim_id)
	ok("tm X: the crash pays the bond as a hit and the meter fills by 0.6",
		_bond_kind(K) == "hit" and P.ult - meter0 > 0.59,
		"%s +%.2f" % [_bond_kind(K), P.ult - meter0])
	_press(P, m)
	ok("tm X: on cooldown it does nothing", K.rime.is_empty() and int(K.stats["rimes"]) == 1)
	await _free(m)
	await _rime_recasts()
	await _rime_sight_and_cap()


## X again: early (before the last 0.75 s) just breaks the shell; late cracks it open at two thirds.
func _rime_recasts() -> void:
	var r: Array = sc.setup("rimewright", 4.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[3]
	var K: RimewrightKit = P.ak
	var h0 := T.hp
	_press(P, m)
	step(m, 1.0)
	_press(P, m)
	step(m, 0.1)
	ok("tm X: X early ends it with no damage, no stun and no bond (small mechanic)", K.rime.is_empty()
		and int(K.stats["cancels"]) == 1 and T.hp >= h0 - 6.0 and T.stun_t <= 0.0 and _bond_kind(K) == ""
		and K.anim_id == "tm_rime_break")
	ok("tm X: after the early break she is free (not rooted or invulnerable)", P.root_t <= 0.0 and P.inv_t <= 0.06)
	K.cd["x"] = 0.0
	step(m, 1.0)
	T.hp = T.max_hp
	h0 = T.hp
	_press(P, m)
	step(m, 3.0)
	_press(P, m)
	var dealt := h0 - T.hp
	var full := float(K.x_def()["dmg"]) * K.power("ult")
	ok("tm X: X in the last 0.75 s cracks it open early at two thirds (small mechanic)", K.rime.is_empty()
		and dealt > full * 0.55 and dealt < full * 0.8 and T.stun_t > 0.3 and T.stun_t < 0.6,
		"dealt %.0f of %.0f stun %.2f" % [dealt, full, T.stun_t])
	K.cd["x"] = 0.0
	step(m, 1.0)
	_press(P, m)
	step(m, 0.3)
	var up := not K.rime.is_empty()
	K.drop_holds()
	step(m, 0.1)
	ok("tm merge: drop_holds ends Rimelock with no crash and frees her", up and K.rime.is_empty()
		and not K.ulk().showing("rink") and P.root_t <= 0.0 and int(K.stats["crashes"]) == 1)
	await _free(m)


## Line of sight blocks the crash; the bond is capped at 0.8 however many it stuns.
func _rime_sight_and_cap() -> void:
	var r: Array = sc.setup("rimewright", 4.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[3]
	var K: RimewrightKit = P.ak
	var W = m.world
	var hidden: Hunter = _dummy(m, T.team, P.pos + Vector3(0, 0, 5.0), "Hidden")
	for dx in range(-1, 2):
		W.kind[W.idx(int(floor(P.pos.x)) + dx, int(floor(P.pos.z)) + 3)] = World.T_BLOCK
	var others: Array = [
			_dummy(m, T.team, P.pos + Vector3(-3.0, 0, 0), "B"), _dummy(m, T.team, P.pos + Vector3(0, 0, -3.0), "C")]
	step(m, 0.05)
	_press(P, m)
	step(m, 3.7)
	ok("tm X: a foe behind a rock is not hit (line of sight)",
		hidden.hp >= hidden.max_hp - 0.01 and hidden.stun_t <= 0.0
		and K.last_stunned == 3, "stunned %d" % K.last_stunned)
	var paid := _owed(K)
	ok("tm X: three hunters stunned pay one event for the cast (the best one)", _bond_kind(K) == "hit"
		and absf(paid - 0.6) < 0.001 and others.size() == 2, "%s %.2f" % [_bond_kind(K), paid])
	await _free(m)


func _moved(P: Hunter, p0: Vector3) -> float:
	return Vector2(P.pos.x - p0.x, P.pos.z - p0.z).length()


func _dummy(m: Match, team: int, at: Vector3, label: String) -> Hunter:
	var d: Hunter = m.make_hunter(label, team, "medium", label, "idle", {}, at, {"arch": "none"})
	d.max_hp = 10000.0
	d.hp = d.max_hp
	d.armor = 0.0
	d.max_armor = 0.0
	return d


# ================================================================== burst cap
## One combined check: Rimelock's crash straight into a merge and the merge's ultimate as soon as it
## unlocks never knocks a full-health medium hunter (no armor, so the margin is the health bar alone).
func burst_cap() -> void:
	# pebbit merges into Titan, the hardest-hitting form ultimate
	var r: Array = sc.setup("rimewright", 3.0, "pebbit")
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[3]
	var K: RimewrightKit = P.ak
	T.max_hp = float(Data.CLASSES["medium"]["hp"])
	T.hp = T.max_hp
	var start_hp := T.hp
	P.kin.stow()      # the Boki rides on you until the merge: only the ult and the merge count
	sc.aim_at(P, T.pos)
	_press(P, m)
	step(m, 3.6)
	var after_ult := start_hp - T.hp
	P.ult = 1.0
	var merged := KinMerge.press(P)
	var waited := 0.0
	while waited < 5.0 and not _merge_ult_ready(P):
		step(m, 0.05)
		waited += 0.05
	sc.aim_at(P, T.pos)
	var ulted := KinMerge.press(P)
	step(m, 2.0)
	var total := start_hp - T.hp
	ok("burst: Rimelock straight into a merge and its ultimate does not one-shot a full-health hunter",
		merged and ulted and int(K.stats["crashes"]) == 1 and not T.downed and T.hp > 0.0,
		"ult %.0f, ult+merge %.0f of %.0f hp (merge %s, its ult %s)" % [
				after_ult, total, start_hp, str(merged), str(ulted)])
	await _free(m)


func _merge_ult_ready(P: Hunter) -> bool:
	if not KinMerge.active(P) or P.merge_st.get("kit") == null:
		return false
	var mk: MergeKit = P.merge_st["kit"]
	return mk.live and mk.lock_left() <= 0.0
