extends RefCounted
## --knock-reset-check: every reset or refund a knock (or a kill) earns, played on a dummy pair (the hero,
## a rival dummy) with the helpers of tools/archetype_check.gd. The rules and their sources are listed in
## docs/KNOCK_RESETS.md. Covered here: the game-wide dash back (DashReset: the knocker whole or one charge
## of several, a teammate who hit the foe in the last 5s too, no heal for them, nothing for a third team);
## Vex's Burr Charge at rank 3; Cinder's Furnace Cloak and heal; Kael's heal, the Finishing Slam's Riposte
## reset and the Riposte's own takedown reset; Sable's heals (her own, an assist) and the Encore's Vault;
## Sparkle's Blowout; Grimble's Salvage stack on an assist; Meeko's carry refresh at rank 3. Hem's wall-stun
## charge and Mossy's dash refund need walls and run in --archer-combo-check / --bulwark-combo-check.
## Never touches the save.

var A
var cues: Array = []

func run(main: Node) -> void:
	Save.no_write = true
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	CombatBus.dash_reset_cue.connect(func(h, src): cues.append([h, src]))
	await _global()
	await _vex()
	await _cinder()
	await _kael()
	await _sable()
	await _sparkle()
	await _grimble()
	await _meeko()
	print("KNOCKRESET DONE, %d checks, failures: %d" % [A.n, A.fails])
	main.get_tree().quit(1 if A.fails > 0 else 0)

## A hunter with no kit (an ally of `team`, or one more rival), at `at`.
func _dummy(m: Match, id: String, team: int, at: Vector3) -> Hunter:
	var d: Hunter = m.make_hunter(id, team, "medium", id, "idle", {}, at, {"arch": "none"})
	d.max_hp = 200.0
	d.hp = d.max_hp
	d.armor = 0.0
	d.max_armor = 0.0
	return d

## `by` lands the knocking blow on `t` (a real hit, so last_hit_by and the kits' notes are set).
func _knock(m: Match, t: Hunter, by: Hunter) -> void:
	t.hp = 1.0
	t.hurt(50.0, by, {"src": "test"})
	A.step(m, 0.05)

## `by` has hit `t` (what Match.on_damage records: the game-wide assist note and the kit's 5 s memory).
func _touch(by: Hunter, t: Hunter) -> void:
	DashReset.note(t, by)
	by.ak.note_hit(t)

func _cues_for(h: Hunter, since: int) -> Array:
	return cues.slice(since).filter(func(c): return c[0] == h).map(func(c): return c[1])

## Every dash charge is there.
func _full(P: Hunter) -> bool:
	return P.dashes >= P.max_dashes() - 0.001

## Health as a share of max.
func _hp_k(P: Hunter) -> float:
	return P.hp / P.max_hp

## Health set to `hp_k` of max, every dash charge and the long dash spent.
func _spend(P: Hunter, hp_k: float) -> void:
	P.hp = P.max_hp * hp_k
	P.dashes = 0.0
	P.ex_cd = 5.0

func _rank3(P: Hunter, slot: String) -> void:
	P.slot_lv[String(Hunter.SLOT_ALIAS.get(slot, slot))] = 3

# ------------------------------------------------------------------ the game-wide dash back
func _global() -> void:
	var r = A.setup("gunslinger", 3.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var al := _dummy(m, "Ally", P.team, home + Vector3(0, 0, 2))
	var third := _dummy(m, "Third", 7, home + Vector3(0, 0, -3))
	# an assist: P hit T, the ally knocks T: P's dash is back, P is not healed, the softer cue
	P.max_hp = 200.0
	_spend(P, 0.5)
	_touch(P, T)
	var c0 := cues.size()
	_knock(m, T, al)
	A.ok("global: an assist (a hit in the last 5s, a teammate's knock) gives the dash back",
			T.downed and _full(P) and P.ex_cd == 0.0, "dashes %.2f ex %.1f" % [P.dashes, P.ex_cd])
	A.ok("global: an assist heals nothing and cues once as an assist", absf(P.hp - 100.0) < 0.01
			and _cues_for(P, c0) == ["assist"], "hp %.1f cues %s" % [P.hp, str(_cues_for(P, c0))])
	# a third team's knock on a foe P hit is no assist
	P.dashes = 0.0
	_touch(P, T2)
	_knock(m, T2, third)
	A.ok("global: a third team's knock gives nothing", T2.downed and P.dashes < 0.1, "dashes %.2f" % P.dashes)
	await A.done(m)

# ------------------------------------------------------------------ Vex (Ghost)
func _vex() -> void:
	var r = A.setup("gunslinger", 3.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: GunslingerKit = P.ak
	_rank3(P, "sec")
	_spend(P, 1.0)
	K.cd["rmb"] = 6.0
	var c0 := cues.size()
	_knock(m, T, P)
	A.ok("vex: his knock gives Combat Slide back whole (one charge)",
			P.max_dashes() <= 1.0 and _full(P), "dashes %.2f / %.0f" % [P.dashes, P.max_dashes()])
	A.ok("vex: rank 3 Burr Charge resets on the knock", float(K.cd["rmb"]) <= 0.0, "cd %.1f" % float(K.cd["rmb"]))
	A.ok("vex: one cue, not two (the kit no longer repeats DashReset)", _cues_for(P, c0) == ["takedown"],
			str(_cues_for(P, c0)))
	await A.done(m)

# ------------------------------------------------------------------ Cinder (Felix)
func _cinder() -> void:
	var r = A.setup("ashwick", 3.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var K: ArchKit = P.ak
	var al := _dummy(m, "Ally", P.team, r[4] + Vector3(0, 0, 2))
	_spend(P, 0.5)
	K.cd["e"] = 6.0
	_knock(m, T, P)
	A.ok("cinder: a knock gives one Soot Ram charge of two, not both", P.max_dashes() >= 2.0
			and P.dashes >= 1.0 and P.dashes < 1.5, "dashes %.2f / %.0f" % [P.dashes, P.max_dashes()])
	A.ok("cinder: her knock resets the Furnace Cloak", float(K.cd["e"]) <= 0.0, "cd %.1f" % float(K.cd["e"]))
	var want: float = 0.5 + float(K.res_def()["heal_knock"]) + DashReset.HEAL
	A.ok("cinder: her knock heals 16% (+5% takedown)", absf(_hp_k(P) - want) < 0.01,
			"%.3f want %.3f" % [_hp_k(P), want])
	# an assist gives the charge back but not the Cloak or the heal
	_spend(P, 0.5)
	K.cd["e"] = 6.0
	_touch(K.h, T2)
	_knock(m, T2, al)
	A.ok("cinder: an assist: one charge, no Cloak reset, no heal", P.dashes >= 1.0 and P.dashes < 1.5
			and float(K.cd["e"]) > 5.0 and absf(_hp_k(P) - 0.5) < 0.01,
			"dashes %.2f cd %.1f hp %.2f" % [P.dashes, float(K.cd["e"]), _hp_k(P)])
	await A.done(m)

# ------------------------------------------------------------------ Kael (Brall)
func _kael() -> void:
	var r = A.setup("juggernaut", 2.6, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: JuggernautKit = P.ak
	T.max_hp = 200.0
	P.hp = P.max_hp * 0.3
	var hp0 := P.hp
	K.slam_hit[T.get_instance_id()] = m.time
	K.cd["x"] = 20.0
	_knock(m, T, P)
	var want := T.max_hp * float(K.res_def().get("heal_knock", 0.2)) + P.max_hp * DashReset.HEAL
	A.ok("kael: his knock heals 20% of the foe's health (+5% takedown)", absf(P.hp - hp0 - want) < 0.5,
			"+%.1f want %.1f" % [P.hp - hp0, want])
	A.ok("kael: a knock within 2s of the Finishing Slam readies the Riposte", float(K.cd["x"]) <= 0.0,
			"cd %.1f" % float(K.cd["x"]))
	# the Riposte's own reset: a hunter who was up and goes down to the cleave
	T.teleport(home + Vector3(0, 0, 9))
	T2.teleport(home + Vector3(2.6, 0, 0))
	A.aim_at(P, T2.pos)
	T2.hp = 10.0
	K.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)
	A.step(m, 0.9)
	A.ok("kael: the Riposte that knocks a hunter is ready again (the source's kill reset)",
			T2.downed and float(K.cd["x"]) <= 0.0, "down %s cd %.1f" % [T2.downed, float(K.cd["x"])])
	await A.done(m)

# ------------------------------------------------------------------ Sable (Shiv)
func _sable() -> void:
	var r = A.setup("thief", 3.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var K: ThiefKit = P.ak
	var al := _dummy(m, "Ally", P.team, r[4] + Vector3(0, 0, 2))
	var rd := K.res_def()
	P.hp = P.max_hp * 0.4
	_knock(m, T, P)
	var want: float = 0.4 + float(rd["heal_knock"]) + DashReset.HEAL
	A.ok("sable: her knock heals her (+5% takedown)", absf(_hp_k(P) - want) < 0.01,
			"%.3f want %.3f" % [_hp_k(P), want])
	_spend(P, 0.4)
	_touch(K.h, T2)
	_knock(m, T2, al)
	want = 0.4 + float(rd["heal_assist"])
	A.ok("sable: an assist heals her and gives the Vault back", absf(_hp_k(P) - want) < 0.01
			and _full(P), "%.3f want %.3f dashes %.2f" % [_hp_k(P), want, P.dashes])
	P.dashes = 0.0
	K.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)
	m.step(A.DT)
	A.ok("sable: the Encore gives the Vault back", K.encore.running() and _full(P), "dashes %.2f" % P.dashes)
	await A.done(m)

# ------------------------------------------------------------------ Sparkle (Joule)
func _sparkle() -> void:
	var r = A.setup("mage", 3.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: MageKit = P.ak
	K.add_spark(T, int(K.res_def()["max"]))
	P.dashes = 0.0
	var c0 := cues.size()
	K._blowout(T)
	A.ok("sparkle: a Blowout (through a foe at 4 Static) gives the Wirerun back", K.blowouts == 1
			and _full(P) and _cues_for(P, c0) == ["hero"],
			"dashes %.2f cues %s" % [P.dashes, str(_cues_for(P, c0))])
	await A.done(m)

# ------------------------------------------------------------------ Grimble (Kingpin)
func _grimble() -> void:
	var r = A.setup("dredge", 3.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: ArchKit = P.ak
	var al := _dummy(m, "Ally", P.team, r[4] + Vector3(0, 0, 2))
	var res0 := K.res
	P.dashes = 0.0
	_touch(K.h, T)
	_knock(m, T, al)
	A.ok("grimble: an assist adds a Salvage stack", is_equal_approx(K.res, res0 + 1.0), "%.0f -> %.0f" % [res0, K.res])
	A.ok("grimble: an assist gives one barge charge of three", P.max_dashes() >= 2.0
			and P.dashes >= 1.0 and P.dashes < 1.5, "dashes %.2f / %.0f" % [P.dashes, P.max_dashes()])
	await A.done(m)

# ------------------------------------------------------------------ Meeko (Elluna)
func _meeko() -> void:
	var r = A.setup("tender", 3.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: TenderKit = P.ak
	var al := _dummy(m, "Ally", P.team, P.pos + Vector3(0.8, 0, 0))
	_rank3(P, "dash")
	P.ex_cd = 9.0
	K.pick_up(al)
	A.ok("meeko: rank 3, picking up a teammate refreshes the long air dash", P.ex_cd == 0.0, "ex %.1f" % P.ex_cd)
	K.drop_all(false)
	await A.done(m)
