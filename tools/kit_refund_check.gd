extends "res://tools/hero_pair_check.gd"
## --kit-refund-check: the cooldown refund and reset loops the 11-27 reference pass added, one scene per hunter:
## Tenzo's Quakefall comes back on a knock of his (not an assist); Albert's raised aegis feeds the 360 Smash
## by the damage it blocks (a whole aegis's worth = a charge) and plays the dash cue when that makes it ready;
## Meeko's Relay Step past a teammate gives half the dash back and winds Hearthlight back 1s, once per dash.


func run(main_node: Node) -> void:
	main = main_node
	await _tenzo()
	await _albert()
	await _meeko()
	print("KITREFUND DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)


func _tenzo() -> void:
	var r := setup("dolm", 5.0)
	var m: Match = r[0]
	var hunter: Hunter = r[1]
	var target: Hunter = r[2]
	var kit: DolmKit = hunter.ak
	kit.cd["rmb"] = 6.0
	kit.on_knock(target, false)
	ok(
		"Tenzo: an assist leaves Quakefall cooling",
		float(kit.cd["rmb"]) > 5.9 and kit.slam_resets == 0,
		"cd %.1f resets %d" % [float(kit.cd["rmb"]), kit.slam_resets]
	)
	kit.on_knock(target, true)
	ok(
		"Tenzo: a knock of his makes Quakefall ready at once",
		float(kit.cd["rmb"]) <= 0.0 and kit.slam_resets == 1,
		"cd %.1f resets %d" % [float(kit.cd["rmb"]), kit.slam_resets]
	)
	kit.on_knock(target, true)
	ok("Tenzo: a knock with Quakefall already up resets nothing", kit.slam_resets == 1, "resets %d" % kit.slam_resets)
	await done(m)


func _albert() -> void:
	var r := setup("bulwark", 5.0)
	var m: Match = r[0]
	var hunter: Hunter = r[1]
	var kit: BulwarkKit = hunter.ak
	var hp: float = kit.rmb_def()["shield"]["hp"]
	hunter.dashes = 0.0
	kit.on_block(hp * 0.5, null)
	ok("Albert: a block with the aegis down feeds nothing", hunter.dashes == 0.0, "dashes %.2f" % hunter.dashes)
	hunter.inp["sec_hold"] = true
	kit.press_rmb()
	step(m, 0.4, func(): hunter.inp["sec_hold"] = true)
	ok("Albert: the aegis is raised", not kit.wall.is_empty(), "")
	hunter.dashes = 0.0
	kit.on_block(hp * 0.5, null)
	ok(
		"Albert: blocking half an aegis's worth gives half the 360 Smash back",
		absf(hunter.dashes - 0.5) < 0.01,
		"dashes %.2f" % hunter.dashes
	)
	var cues := []
	CombatBus.dash_reset_cue.connect(func(_h, src): cues.append(src))
	kit.on_block(hp * 0.5, null)
	ok(
		"Albert: the block that makes it ready plays the dash cue",
		absf(hunter.dashes - 1.0) < 0.01 and cues == ["dash_hit"],
		"dashes %.2f cues %s" % [hunter.dashes, str(cues)]
	)
	kit.on_block(hp, null)
	ok(
		"Albert: a full dash takes no more",
		hunter.dashes == hunter.max_dashes() and absf(kit.block_dash - 1.0) < 0.01,
		"dashes %.2f fed %.2f" % [hunter.dashes, kit.block_dash]
	)
	await done(m)


func _meeko() -> void:
	var r := setup("tender", 2.0)
	var m: Match = r[0]
	var hunter: Hunter = r[1]
	var target: Hunter = r[2]
	var kit: TenderKit = hunter.ak
	target.team = hunter.team
	var most := hunter.max_dashes()
	kit.cd["e"] = 8.0
	hunter.inp["move"] = Vector2(1, 0)
	aim_at(hunter, hunter.pos + Vector3(5, 0, 0))
	hunter.inp["dash"] = true
	step(m, 0.05)
	hunter.inp["dash"] = false
	ok(
		"Meeko: Relay Step past a teammate gives half the hop back and 1s of Hearthlight",
		absf(hunter.dashes - (most - 0.5)) < 0.05 and absf(float(kit.cd["e"]) - 7.0) < 0.1 and kit.stats["relays"] == 1,
		"dashes %.2f (max %.0f) e %.1f relays %d" % [hunter.dashes, most, float(kit.cd["e"]), kit.stats["relays"]]
	)
	step(m, 0.5)
	target.teleport(hunter.pos + Vector3(0, 0, 6.0))
	step(m, 0.05)
	hunter.dashes = most
	kit.cd["e"] = 8.0
	hunter.inp["dash"] = true
	step(m, 0.05)
	hunter.inp["dash"] = false
	ok(
		"Meeko: a hop past nobody refunds nothing",
		hunter.dashes < most - 0.9 and float(kit.cd["e"]) > 7.9 and kit.stats["relays"] == 1,
		"dashes %.2f (max %.0f) e %.1f" % [hunter.dashes, most, float(kit.cd["e"])]
	)
	target.teleport(hunter.pos + Vector3(1.5, 0, 0))
	step(m, 0.05)
	hunter.ex_cd = 10.0
	kit._relay_pass(true, 10.0)
	ok(
		"Meeko: the glide past a teammate halves its cooldown",
		absf(hunter.ex_cd - 5.0) < 0.01 and kit.stats["relays"] == 2,
		"ex_cd %.1f relays %d" % [hunter.ex_cd, kit.stats["relays"]]
	)
	await done(m)
